---
title: "Digest System — еженедельный обзор клуба"
created_by: "AI-Agents Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# Digest System (`/digest`)

Еженедельный обзор активности клуба. UX-референс — Notion/GitHub digest. Цель — ритуал чтения по понедельникам, поддержка вовлечения.

## 1. Расписание

| Параметр | Значение |
|----------|----------|
| Триггер | APScheduler cron `0 9 * * MON` (Europe/Moscow, **09:00 МСК понедельник**) |
| Окно сборки | предыдущая ISO-неделя (пн 00:00 — вс 23:59 МСК) |
| Worker | Django management command `generate_weekly_digest` |
| Идемпотентность | по `(week_iso_year, week_iso_num)` UNIQUE в `daily_summaries` |

> Имя таблицы исторически `daily_summaries` (см. данные Data Agent), но физически хранит weekly digest. Поле `period_type` = `'weekly'`.

## 2. Pipeline (map-reduce)

```mermaid
flowchart TD
    A[Cron trigger Mon 09:00 MSK] --> B[Загрузить chat_messages<br/>за прошлую ISO-неделю<br/>где consent=true]
    B --> C{Messages > 0?}
    C -->|no| Z[Пропустить, post в чат:<br/>"Тихая неделька"]
    C -->|yes| D[Группировка по дням<br/>+ темам]
    D --> E[MAP phase<br/>Sonnet 4.6<br/>на каждый день: mini-summary]
    E --> F[REDUCE phase<br/>Sonnet 4.6 default<br/>или Opus 4.7 если impact>порог]
    F --> G[Структурированный digest<br/>JSON по 4 секциям]
    G --> H[Сохранить daily_summaries]
    H --> I[Пост в отдельную ветку<br/>чата клуба]
    H --> J[Push notification<br/>в mini-app /digest]
```

## 3. Структура digest (4 секции)

```json
{
  "week_iso": "2026-W19",
  "period_start": "2026-05-04",
  "period_end": "2026-05-10",
  "sections": {
    "discussed": [
      "Обсуждали unit-экономику SaaS — Аня поделилась шаблоном",
      "..."
    ],
    "open_requests": [
      "Иван ищет co-founder в HealthTech",
      "..."
    ],
    "key_decisions": [
      "Решили перенести оффлайн-встречу на 25 мая",
      "..."
    ],
    "events": [
      "В клубе 3 новых участника: Маша, Петя, Лена",
      "..."
    ]
  },
  "stats": {
    "messages_count": 412,
    "active_users": 18,
    "new_members": 3
  }
}
```

## 4. MAP prompt (per-day)

См. `prompts-library.md` → `DIGEST_MAP_PROMPT`. Input — все сообщения дня (concat до 8k токенов; если больше — несколько подряд `MAP` с overlap).

Output (JSON): `{ discussed: [], open_requests: [], key_decisions: [], events: [] }` — массивы строк ≤120 символов на «ты».

## 5. REDUCE prompt

См. `prompts-library.md` → `DIGEST_REDUCE_PROMPT`. Input — 7 day-summaries.

**Выбор модели для REDUCE**:

```python
def pick_reduce_model(day_summaries):
    total_items = sum(len(s.get(k, [])) for s in day_summaries for k in s)
    if total_items > 50 or week_has_impact_event(day_summaries):
        return "claude-opus-4-7"   # сложный синтез
    return "claude-sonnet-4-6"      # обычный случай
```

`week_has_impact_event` = есть ли в `events` ключевые слова `[«lifetime», «бан», «жалоба» (агрегат), «новый раунд», «релиз»]`.

## 6. Публикация

### В чат клуба

Сообщение в **отдельной топик-ветке** «📰 Дайджесты» (создать вручную на старте, либо запинить):

```
📰 Дайджест недели 2026-W19 (4–10 мая)

🗣 Что обсуждали
• Unit-экономика SaaS — Аня поделилась шаблоном
• ...

❓ Открытые запросы
• Иван ищет co-founder в HealthTech
• ...

✅ Ключевые решения
• Перенесли оффлайн на 25 мая

🎉 События
• 3 новых участника

→ Открыть полностью в мини-приложении
[кнопка → /digest]
```

### В mini-app

`/digest` экран (см. `wireframes-miniapp.md` §8) — карточки по 4 секциям. Тап на пункт «открытые запросы» → может вести к `/match` с предзаполненным запросом (Phase 3, опционально).

## 7. Cost

| Шаг | Модель | Tokens (avg) | Cost (avg) |
|-----|--------|-------------|------------|
| 7× MAP (по дню) | Sonnet 4.6 | 4k in + 0.5k out | ~$0.07 × 7 = $0.49 |
| 1× REDUCE (sonnet) | Sonnet 4.6 | 3k in + 1k out | ~$0.025 |
| 1× REDUCE (opus, при impact) | Opus 4.7 | 3k in + 1k out | ~$0.10 |
| **Итого / неделя (sonnet path)** | | | **~$0.50** |
| **Итого / неделя (opus path)** | | | **~$0.60** |
| **/ месяц на клуб** | | | **~$2.5** |

Не нагружает per-user cap.

## 8. `daily_summaries` структура

```yaml
daily_summaries:
  id: bigserial
  period_type: enum (daily|weekly|monthly)  -- сейчас всегда 'weekly'
  period_start: date
  period_end: date
  week_iso: char(8)              -- '2026-W19' (UNIQUE для weekly)
  sections: jsonb                -- {discussed, open_requests, key_decisions, events}
  stats: jsonb
  generation_model_map: varchar
  generation_model_reduce: varchar
  tokens_in: int
  tokens_out: int
  cost_usd: decimal(10,6)
  posted_to_chat_at: timestamptz nullable
  message_id_in_chat: bigint nullable
  created_at: timestamptz
```

## 9. Идемпотентность и повторные запуски

- UNIQUE `(period_type, week_iso)` → повторный run в тот же понедельник не создаст дубль.
- Админ может вручную перегенерировать через CLI `regenerate_digest --week 2026-W19 --force` — старая запись soft-archive в `daily_summaries_archive`.

## 10. Failure modes

| Сценарий | Поведение |
|----------|-----------|
| 0 consent-сообщений | Postнуть «Тихая неделька, отдыхаем 🌿» |
| Anthropic API down | Retry 3× с экспоненциальным backoff, потом — постпонить на +2ч, alert SRE |
| MAP вернул невалидный JSON | Retry 1× с принудительным `response_format=json_schema`; иначе пропустить день |
| Сообщения за неделю > 10k токенов | Иерархический MAP: чанки по 4 часа → день → неделя |
| Тред «Дайджесты» удалён | Postнуть в общий чат + alert админу |

---
*Документ создан: AI-Agents Agent | Дата: 2026-05-16*
