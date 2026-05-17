---
title: "ADR-008: NSM Finalization — Engaged Active Paid Members"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# ADR-008: NSM Finalization

**Status:** Accepted
**Date:** 2026-05-16
**Author:** Architect Agent
**Stakeholders:** Product, Analytics, Founder

## Контекст

Расхождение между двумя источниками:

- **Product (PRD)** определяет North Star: «Weekly Active Members с осмысленным действием в mini-app или чате» (WAM с действием).
- **Analytics (metrics-framework)** определяет NSM: «Active Paid Members» (активная подписка + lifetime + присоединились по invite).

Оба определения имеют смысл:
- APM — отражает **финансовое здоровье** (платят и в системе).
- WAM-с-действием — отражает **product engagement** (живут в продукте).

В клубе с подпиской "просто платящий, но молчащий" пользователь — риск (вероятная отписка, низкая ценность). Поэтому корректная NSM должна объединять оба сигнала.

## Решение — композитная NSM

**NSM = Engaged Active Paid Members (EAPM)**

Формула:

```sql
EAPM = COUNT(DISTINCT user) WHERE
   access_status IN ('active', 'lifetime_active')
   AND joined_channel_at IS NOT NULL
   AND has_meaningful_action_in_last_7_days = TRUE
```

### Что такое "meaningful action" (за последние 7 дней)

Хотя бы одно из следующих событий:

1. Дал или получил `Respect` (в боте, mini-app или через реакцию-стикер).
2. Запросил `/match` (AI-матчинг).
3. Задал вопрос через `/ask` (RAG).
4. Открыл еженедельный `/digest` (event `digest_opened`).
5. Написал ≥1 сообщение в чате клуба (от listener).
6. Бронирование интервью (для онбординга — первая неделя).
7. Использовал `/gift` или `/burn` (Phase 3).
8. Открыл mini-app (event `miniapp_opened` с длительностью сессии ≥ 30 сек).

Прокси-метрики (не входят): `bot_command_run` без полезной нагрузки (например, /help), пассивный просмотр уведомления.

### Период: 7-day rolling

Окно 7 дней — соответствует "weekly active" в PRD. Возможные альтернативы (4 недели для smoother, 30 дней) — для дополнительных метрик "Monthly Active".

### Дополнительные dashboard metrics

- **APM** (Analytics старое определение) — продолжает считаться как **финансовая** метрика (используется в ARPU, MRR).
- **EAPM / APM ratio** — health-индикатор: цель ≥ 60% (большинство платящих — живые).
- **WAM** (без paid-фильтра) — суммарная активность (включая lifetime).

### Целевые значения (Year 1)

| Метрика | Y1 цель |
|---|---|
| APM (Active Paid Members) | 1 000 |
| EAPM | 600 (60% APM) |
| EAPM growth m/m | + 8% |
| ARPU (по APM) | $25-30 / мес |

## Обоснование выбора

1. **Учитывает обе перспективы:** платежи + использование.
2. **Защищает от "зомби-подписок":** платит, но не возвращается = риск, метрика это сигналит.
3. **Простота расчёта:** требует только `ai_usage_log`, `social.respects`, `listener.messages`, `notifications.digest_opened`, `auth.miniapp_session` — всё в БД.
4. **Соответствует природе клуба:** клуб — про осмысленные связи, а не CDN-доступ к контенту.

## Реализация

- **Source events:** все 8 типов событий уже в tracking plan (Analytics) или будут (Listener — Phase 2).
- **Materialized view / table:** `analytics.user_engagement_7d` обновляется ежедневно (worker job `compute_engagement`).
- **Dashboard:** Founder и Community команда видят EAPM, APM, ratio.

## Альтернативы

| Альтернатива | Почему отклонена |
|---|---|
| Чистый APM (Analytics) | Игнорирует engagement, "зомби-подписки" не видны |
| Чистый WAM с действием (Product) | Не учитывает финансовую сторону; неактивные платящие не сигналят |
| DAU (daily active) | Слишком волатильно; клуб — не игра |
| MAU 30d | Слишком мягко; неделя лучше отражает темп клуба |

## Последствия

- Один основной показатель здоровья для команды и founder.
- APM остаётся как финансовая метрика (не отменён).
- Нужна реализация event-tracking для всех 8 meaningful actions (Analytics Agent уже планировал большинство).
- Phase 6: tracking-таблицы + worker job + admin dashboard карточка.

## Связанные документы

- `docs/discovery/analytics/metrics-framework.md`
- `docs/discovery/prd.md` § 1
- `docs/discovery/vision.md` § 6
- `docs/discovery/analytics/funnel-definition.md` § 8

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
