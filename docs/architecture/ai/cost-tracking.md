---
title: "AI Cost Tracking — ai_usage_log, дашборды, caps"
created_by: "AI-Agents Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# AI Cost Tracking

Учёт расходов на inference. Цель — обеспечить метрику Analytics **Cost per User per Month ≤ $2**, контроль по фичам и алерты при аномалиях.

## 1. `ai_usage_log` структура

```yaml
ai_usage_log:
  id: bigserial
  user_id: FK users nullable     -- NULL для system-задач (digest, listener)
  feature: enum
    - 'match'
    - 'ask'
    - 'digest_map'
    - 'digest_reduce'
    - 'listener_embedding'
    - 'classify'
    - 'law_consent_validation'
    - 'bot_reply'
  model: varchar                  -- API-ID использованной модели
  model_alias: enum (MODEL_FAST|MODEL_SMART|MODEL_DEEP|MODEL_EMBEDDING)
  task_type: varchar              -- TaskType из router
  tokens_in: int not null
  tokens_out: int not null
  cost_usd: decimal(10,6) not null
  latency_ms: int
  request_id: char(32)            -- корреляция с http-запросом
  parent_log_id: bigint nullable  -- для chain'ов (MAP → REDUCE)
  fallback_used: boolean default false
  cache_hit: boolean default false
  error: text nullable
  created_at: timestamptz default now()

indexes:
  - (created_at)
  - (user_id, created_at)
  - (feature, created_at)
  - (model, created_at)
```

## 2. Расчёт `cost_usd`

```python
def calc_cost(model_alias: str, tokens_in: int, tokens_out: int) -> Decimal:
    pricing = config['pricing'][api_id_of(model_alias)]
    cost = (tokens_in * pricing['input'] + tokens_out * pricing['output']) / 1_000_000
    return Decimal(cost).quantize(Decimal('0.000001'))
```

Прайс из `config/ai_models.yaml` (`model-router.md` §5).

## 3. Дашборды (web-админка)

Дашборд `AI Cost` в админке — реализация требования F2.12 (PRD).

### Виджеты

| # | Виджет | Формула / источник |
|---|--------|--------------------|
| 1 | **Inference Cost / Day** (line chart, 30 дней) | `SUM(cost_usd) per day` |
| 2 | **Cost by Feature** (donut, текущий месяц) | `SUM(cost_usd) GROUP BY feature` |
| 3 | **Cost by Model** (donut, текущий месяц) | `SUM(cost_usd) GROUP BY model` |
| 4 | **Cost per Active User** (gauge) | `SUM(cost_usd) / NSM / month`, target ≤ $2 |
| 5 | **Top spenders** (table, 10 строк) | `SUM(cost_usd) GROUP BY user_id ORDER BY DESC LIMIT 10` |
| 6 | **Avg tokens per feature** (table) | `AVG(tokens_in+tokens_out) GROUP BY feature` |
| 7 | **Cache hit rate** (kpi) | `SUM(cache_hit::int) / COUNT(*) per feature` |
| 8 | **Fallback usage** (kpi + log) | `SUM(fallback_used::int) per day` |
| 9 | **Anomaly events** (timeline) | список сработавших alerts |

### SQL для NSM-aware cost-per-user

```sql
WITH active_users AS (
  SELECT COUNT(*) AS n FROM users
  WHERE status = 'active'
    AND subscription_active_until > now()
),
month_cost AS (
  SELECT COALESCE(SUM(cost_usd), 0) AS total
  FROM ai_usage_log
  WHERE created_at >= date_trunc('month', now())
)
SELECT
  month_cost.total AS month_cost_usd,
  active_users.n AS active_users,
  CASE WHEN active_users.n > 0
    THEN month_cost.total / active_users.n
    ELSE 0 END AS cost_per_user_usd
FROM month_cost, active_users;
```

## 4. Caps (cost-кэпы)

### Per user (мягкий→жёсткий)

| Порог | Действие |
|-------|----------|
| **$1.50/мес** | Soft warn — банер в mini-app «ты потратил $1.50 на AI в этом месяце» |
| **$2.00/мес** | Уведомление в чат админам «user X достиг $2, near limit» |
| **$3.00/мес** | **Hard block** AI-фич (`/match`, `/ask`) до 1-го числа след. месяца. UI: «Лимит AI исчерпан, обновится 1-го числа». Audit-log запись. |

Реализация — middleware `check_ai_cost_cap(user_id)` перед каждым AI-вызовом:

```python
def check_ai_cost_cap(user_id: int) -> CapDecision:
    cost_this_month = AIUsageLog.objects.filter(
        user_id=user_id,
        created_at__gte=month_start(),
    ).aggregate(s=Sum('cost_usd'))['s'] or 0

    if cost_this_month >= 3.00:
        return CapDecision(allowed=False, reason="hard_cap_reached")
    if cost_this_month >= 2.00:
        notify_admin_once(user_id, threshold=2.00)
    return CapDecision(allowed=True, warn_user=cost_this_month >= 1.50)
```

### Per feature (daily cap)

| Feature | Soft warn | Hard cap |
|---------|-----------|----------|
| `match` (день) | $40 | $50 → блок до полуночи |
| `ask` (день) | $80 | $100 → блок до полуночи |
| `digest_*` (неделя) | $0.80 | $2 → fallback на Sonnet-only |
| `listener_embedding` (день) | $1 | $3 → пауза индексации, alert |

## 5. Alerts

Источник — Prometheus + Grafana (или Sentry для бизнес-метрик; конкретный стек DevOps решит в Phase 8). Триггеры:

| Alert | Условие | Severity |
|-------|---------|----------|
| `ai_cost_spike` | daily cost > 2× rolling 7-day avg | High |
| `ai_user_near_cap` | любой user > $2/мес | Medium |
| `ai_user_hit_hard_cap` | любой user >= $3/мес | High |
| `ai_feature_daily_cap` | любая фича достигла hard cap | High |
| `ai_error_rate_high` | error_rate > 10% за 15 минут | Critical |
| `ai_fallback_active_long` | fallback_active > 30 минут | High |
| `ai_anomaly_2sigma` | `today_cost > weekly_mean + 2*stddev` | Medium |

Канал: админ-чат в Telegram (через бота) + email founder для Critical.

## 6. Anomaly detection (упрощённая)

```sql
WITH weekly AS (
  SELECT
    AVG(daily_cost) AS mean,
    STDDEV(daily_cost) AS std
  FROM (
    SELECT date_trunc('day', created_at) AS d, SUM(cost_usd) AS daily_cost
    FROM ai_usage_log
    WHERE created_at >= now() - INTERVAL '7 days'
      AND created_at < date_trunc('day', now())
    GROUP BY 1
  ) t
),
today AS (
  SELECT COALESCE(SUM(cost_usd), 0) AS c
  FROM ai_usage_log
  WHERE created_at >= date_trunc('day', now())
)
SELECT today.c AS today_cost,
       weekly.mean,
       weekly.std,
       today.c > weekly.mean + 2 * weekly.std AS is_anomaly
FROM today, weekly;
```

Запуск каждый час через APScheduler.

## 7. Retention

- `ai_usage_log` — 24 месяца, потом агрегирование в `ai_usage_monthly` (per user+feature+model) и удаление детальных строк.
- `match_log.query_text` / `kb_log.query_text` — 90 дней (Privacy).

## 8. API эндпоинты (для админки)

| Method | Path | Описание |
|--------|------|----------|
| `GET` | `/api/admin/ai/cost/summary?period=month` | Сводка по месяцу |
| `GET` | `/api/admin/ai/cost/timeseries?from&to&group_by` | timeseries для графиков |
| `GET` | `/api/admin/ai/cost/users?limit=10` | top spenders |
| `GET` | `/api/admin/ai/cost/anomalies` | список сработавших алертов |
| `POST` | `/api/admin/ai/cost/cap-override` | временное снятие cap для user (с reason) |

Все эндпоинты требуют роль `admin.super` (DEC-005).

## 9. Тестовая прогонка (canary)

DevOps настраивает canary-suite — 5 типичных запросов на каждую фичу, прогоняется ежедневно. Цель — обнаружить дрейф цен/токенизации/качества раньше пользователей. Результат — отдельный отчёт в дашборде «Canary diff vs baseline».

---
*Документ создан: AI-Agents Agent | Дата: 2026-05-16*
