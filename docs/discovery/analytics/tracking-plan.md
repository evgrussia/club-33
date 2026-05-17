---
title: "Tracking Plan — Клуб 33"
created_by: "Analytics Agent"
created_at: "2026-05-15"
version: "1.0"
phase: "Discovery"
---

# Tracking Plan — Клуб 33

Полный реестр событий аналитики для трёх фаз релиза. Каждое событие фиксируется в таблице `events` (PostgreSQL) и/или внешнем продуктовом аналитическом инструменте (если будет подключён). Источник события — `owner`: Bot (Telegram-бот), Mini-app (Telegram WebApp), Backend (Django/DRF, webhook-обработчики), Admin (web-админка).

## Соглашения

- **name**: `snake_case`, в едином namespace.
- **timestamp**: всегда UTC (ISO-8601), на бэкенде дополнительно сохраняем МСК для отчётов.
- **user_id**: внутренний UUID пользователя в Клубе 33. Для анонимных событий до регистрации — `tg_user_id` Telegram.
- **session_id**: id сессии mini-app (для UI-событий).
- **properties**: JSON-объект, валидируется JSON Schema. Поля без префикса — обязательные, помеченные `?` — опциональные.
- **PII**: email, телефон, full_name не отправляем в продуктовую аналитику — только `user_id`.

---

## Фаза 1 — Воронка, заявки, оплаты, доступ

### 1.1 `bot_start`
- **trigger**: пользователь отправил `/start` боту.
- **owner**: Bot
- **phase**: 1
- **properties**:
```json
{
  "tg_user_id": "integer (required)",
  "username": "string?",
  "language_code": "string?",
  "deep_link_payload": "string?",
  "is_returning": "boolean (required)"
}
```

### 1.2 `apply_clicked`
- **trigger**: нажата кнопка «Подать заявку» в презентационном сообщении.
- **owner**: Bot
- **phase**: 1
- **properties**:
```json
{
  "tg_user_id": "integer (required)",
  "source": "string (required, enum: start|menu|deeplink|reminder)"
}
```

### 1.3 `form_submitted`
- **trigger**: получен webhook от Google Forms о новой заявке.
- **owner**: Backend
- **phase**: 1
- **properties**:
```json
{
  "application_id": "string (required, uuid)",
  "tg_user_id": "integer (required)",
  "form_version": "string (required)",
  "fields_filled_count": "integer (required)",
  "submitted_at": "string (required, iso8601)"
}
```

### 1.4 `application_approved`
- **trigger**: модератор/админ одобрил заявку в web-админке.
- **owner**: Admin
- **phase**: 1
- **properties**:
```json
{
  "application_id": "string (required, uuid)",
  "user_id": "string (required, uuid)",
  "admin_id": "string (required, uuid)",
  "decision_time_sec": "integer (required)",
  "notes_len": "integer?"
}
```

### 1.5 `application_rejected`
- **trigger**: модератор отклонил заявку.
- **owner**: Admin
- **phase**: 1
- **properties**:
```json
{
  "application_id": "string (required, uuid)",
  "admin_id": "string (required, uuid)",
  "reason_code": "string (required, enum: not_fit|spam|incomplete|other)",
  "decision_time_sec": "integer (required)"
}
```

### 1.6 `payment_screen_opened`
- **trigger**: пользователь открыл шаг выбора тарифа после одобрения.
- **owner**: Bot
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "entry_point": "string (required, enum: after_approval|renewal|manual)"
}
```

### 1.7 `tariff_selected`
- **trigger**: пользователь выбрал тариф (6м / 12м / lifetime).
- **owner**: Bot
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "tariff_code": "string (required, enum: m6|m12|lifetime)",
  "price_usd": "number (required)",
  "price_rub_snapshot": "number?"
}
```

### 1.8 `payment_method_selected`
- **trigger**: выбран способ оплаты.
- **owner**: Bot
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "tariff_code": "string (required)",
  "method": "string (required, enum: usdt_trc20|usdt_ton|sbp|yookassa)"
}
```

### 1.9 `invoice_created`
- **trigger**: создан инвойс (USDT-адрес, ЮKassa platform_id, СБП-реквизиты).
- **owner**: Backend
- **phase**: 1
- **properties**:
```json
{
  "invoice_id": "string (required, uuid)",
  "user_id": "string (required, uuid)",
  "method": "string (required)",
  "amount_usd": "number (required)",
  "amount_rub": "number?",
  "fx_rate_snapshot": "number?",
  "expires_at": "string (required, iso8601)"
}
```

### 1.10 `payment_completed`
- **trigger**: подтверждена оплата (webhook USDT/ЮKassa, ручная сверка СБП).
- **owner**: Backend
- **phase**: 1
- **properties**:
```json
{
  "invoice_id": "string (required, uuid)",
  "user_id": "string (required, uuid)",
  "tariff_code": "string (required)",
  "method": "string (required)",
  "amount_usd": "number (required)",
  "amount_rub": "number?",
  "confirmation_seconds": "integer (required)",
  "is_renewal": "boolean (required)"
}
```

### 1.11 `payment_failed`
- **trigger**: оплата отменена/недостаточно/ошибка провайдера.
- **owner**: Backend
- **phase**: 1
- **properties**:
```json
{
  "invoice_id": "string (required, uuid)",
  "user_id": "string (required, uuid)",
  "method": "string (required)",
  "error_code": "string (required)",
  "error_message": "string?"
}
```

### 1.12 `payment_pending_10min`
- **trigger**: с момента `invoice_created` прошло 10 минут, оплата не подтверждена.
- **owner**: Backend
- **phase**: 1
- **properties**:
```json
{
  "invoice_id": "string (required, uuid)",
  "user_id": "string (required, uuid)",
  "method": "string (required)",
  "support_button_shown": "boolean (required)"
}
```

### 1.13 `interview_booked`
- **trigger**: пользователь забронировал слот в club33calendar.
- **owner**: Backend
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "slot_id": "string (required, uuid)",
  "slot_start": "string (required, iso8601)",
  "lead_time_hours": "number (required)"
}
```

### 1.14 `interview_attended`
- **trigger**: основатель отметил «состоялось» после интервью.
- **owner**: Admin
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "slot_id": "string (required, uuid)",
  "duration_minutes": "integer?",
  "verdict": "string (required, enum: accepted|rejected|deferred)"
}
```

### 1.15 `interview_no_show`
- **trigger**: автоматический job по истечении слота — пользователь не пришёл и не отметился.
- **owner**: Backend
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "slot_id": "string (required, uuid)"
}
```

### 1.16 `law_accepted`
- **trigger**: пользователь ввёл ручную фразу принятия «Закона клуба».
- **owner**: Bot
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "law_version": "string (required)",
  "attempts": "integer (required)",
  "time_to_accept_sec": "integer (required)"
}
```

### 1.17 `invite_received`
- **trigger**: бот выдал инвайт-ссылки (канал + чат).
- **owner**: Bot
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "channel_invite_id": "string (required)",
  "chat_invite_id": "string (required)",
  "ttl_hours": "integer (required)"
}
```

### 1.18 `invite_used`
- **trigger**: Telegram-событие `chat_member`: новый участник присоединился по инвайту.
- **owner**: Backend
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "invite_id": "string (required)",
  "target": "string (required, enum: channel|chat)",
  "time_from_issue_min": "integer (required)"
}
```

### 1.19 `renewal_started`
- **trigger**: пользователь нажал «Продлить» из раздела «Мой доступ» или из напоминания.
- **owner**: Bot
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "days_left": "integer (required)",
  "current_tariff": "string (required)",
  "trigger_source": "string (required, enum: reminder|menu|expired)"
}
```

### 1.20 `renewal_completed`
- **trigger**: `payment_completed` с флагом `is_renewal=true`.
- **owner**: Backend
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "new_tariff": "string (required)",
  "renewals_count": "integer (required)",
  "days_extended": "integer (required)"
}
```

### 1.21 `subscription_expired`
- **trigger**: scheduler — `last_payment_at + period < now`, пользователь не продлил.
- **owner**: Backend
- **phase**: 1
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "tariff_at_expiry": "string (required)",
  "renewals_count": "integer (required)",
  "ltv_usd": "number (required)"
}
```

---

## Фаза 2 — Социальный слой и AI

### 2.1 `respect_given`
- **trigger**: пользователь отправил респект через mini-app или команду.
- **owner**: Mini-app / Bot
- **phase**: 2
- **properties**:
```json
{
  "from_user_id": "string (required, uuid)",
  "to_user_id": "string (required, uuid)",
  "amount": "integer (required, min:1, max:3)",
  "reason": "string?",
  "source": "string (required, enum: miniapp|chat_command|sticker_reaction)",
  "monthly_balance_left": "integer (required)"
}
```

### 2.2 `complaint_filed`
- **trigger**: подана жалоба через mini-app.
- **owner**: Mini-app
- **phase**: 2
- **properties**:
```json
{
  "complaint_id": "string (required, uuid)",
  "target_user_id": "string (required, uuid)",
  "category": "string (required, enum: rules|spam|harm|other)",
  "anonymous": "boolean (required, const:true)"
}
```

### 2.3 `complaint_resolved`
- **trigger**: модератор закрыл жалобу.
- **owner**: Admin
- **phase**: 2
- **properties**:
```json
{
  "complaint_id": "string (required, uuid)",
  "admin_id": "string (required, uuid)",
  "resolution": "string (required, enum: confirmed|rejected|warning|ban)",
  "time_to_resolve_hours": "number (required)"
}
```

### 2.4 `stars_changed`
- **trigger**: пересчёт репутации по формуле (cron) либо явное действие модератора.
- **owner**: Backend
- **phase**: 2
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "old_stars": "integer (required)",
  "new_stars": "integer (required)",
  "reputation_score": "number (required)",
  "trigger": "string (required, enum: monthly_recalc|respect|complaint|inactivity|admin_action)"
}
```

### 2.5 `role_assigned`
- **trigger**: основатель/админ назначил роль/нишу пользователю.
- **owner**: Admin
- **phase**: 2
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "role_id": "string (required, uuid)",
  "role_name": "string (required)",
  "kyc_required": "boolean (required)",
  "admin_id": "string (required, uuid)"
}
```

### 2.6 `match_requested`
- **trigger**: пользователь вызвал `/match` или открыл вкладку «Матчинг» в mini-app.
- **owner**: Mini-app / Bot
- **phase**: 2
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "query_text_len": "integer (required)",
  "filters": "object?",
  "results_count": "integer (required)",
  "model_used": "string (required, enum: smart|fast)"
}
```

### 2.7 `match_clicked`
- **trigger**: пользователь открыл профиль матча из выдачи.
- **owner**: Mini-app
- **phase**: 2
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "match_user_id": "string (required, uuid)",
  "rank": "integer (required)",
  "match_score": "number (required)"
}
```

### 2.8 `kb_query`
- **trigger**: пользователь задал вопрос боту базе знаний (`/ask`).
- **owner**: Bot
- **phase**: 2
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "query_id": "string (required, uuid)",
  "query_text_len": "integer (required)",
  "retrieved_chunks": "integer (required)",
  "model_used": "string (required)",
  "latency_ms": "integer (required)"
}
```

### 2.9 `kb_answer_useful`
- **trigger**: пользователь отметил «полезно/не полезно» под ответом KB.
- **owner**: Bot
- **phase**: 2
- **properties**:
```json
{
  "query_id": "string (required, uuid)",
  "user_id": "string (required, uuid)",
  "useful": "boolean (required)",
  "comment_len": "integer?"
}
```

### 2.10 `digest_sent`
- **trigger**: scheduler разослал еженедельный digest.
- **owner**: Backend
- **phase**: 2
- **properties**:
```json
{
  "digest_id": "string (required, uuid)",
  "audience_size": "integer (required)",
  "items_count": "integer (required)",
  "tokens_used": "integer (required)",
  "cost_usd": "number (required)"
}
```

### 2.11 `digest_opened`
- **trigger**: пользователь кликнул на любой элемент digest или открыл его в боте.
- **owner**: Bot / Mini-app
- **phase**: 2
- **properties**:
```json
{
  "digest_id": "string (required, uuid)",
  "user_id": "string (required, uuid)",
  "click_target": "string?"
}
```

---

## Фаза 3 — Экономика времени

### 3.1 `gift_sent`
- **trigger**: пользователь подарил дни через `/gift`.
- **owner**: Bot / Mini-app
- **phase**: 3
- **properties**:
```json
{
  "gift_id": "string (required, uuid)",
  "from_user_id": "string (required, uuid)",
  "to_user_id": "string (required, uuid)",
  "days": "integer (required, min:1)",
  "respect_attached": "integer?",
  "source_subscription_id": "string (required, uuid)",
  "from_is_lifetime": "boolean (required)"
}
```

### 3.2 `days_burned`
- **trigger**: пользователь сжёг дни через `/burn` в пользу клуба.
- **owner**: Bot
- **phase**: 3
- **properties**:
```json
{
  "burn_id": "string (required, uuid)",
  "user_id": "string (required, uuid)",
  "days": "integer (required, min:1)",
  "reason": "string?",
  "remaining_days": "integer (required)"
}
```

### 3.3 `lifetime_budget_used`
- **trigger**: lifetime-пользователь использовал часть годового бюджета 33 дня.
- **owner**: Backend
- **phase**: 3
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "days_used_this_event": "integer (required)",
  "budget_used_total": "integer (required)",
  "budget_left": "integer (required)",
  "year": "integer (required)"
}
```

### 3.4 `reaction_respect`
- **trigger**: пользователь поставил особую реакцию-стикер в чате клуба.
- **owner**: Bot (listener)
- **phase**: 3
- **properties**:
```json
{
  "from_user_id": "string (required, uuid)",
  "to_user_id": "string (required, uuid)",
  "message_id": "integer (required)",
  "chat_id": "integer (required)",
  "respect_credited": "integer (required)"
}
```

---

## Системные события (все фазы)

### S.1 `admin_day_adjustment`
- **trigger**: админ вручную начислил/списал дни в конвертере.
- **owner**: Admin
- **phase**: 3
- **properties**:
```json
{
  "user_id": "string (required, uuid)",
  "admin_id": "string (required, uuid)",
  "days_delta": "integer (required)",
  "usd_equivalent": "number (required)",
  "reason": "string (required)"
}
```

### S.2 `ai_usage_logged`
- **trigger**: каждый вызов модели Anthropic — запись в `ai_usage_log`.
- **owner**: Backend
- **phase**: 2
- **properties**:
```json
{
  "user_id": "string?",
  "feature": "string (required, enum: match|kb|digest|moderation|other)",
  "model": "string (required)",
  "tokens_in": "integer (required)",
  "tokens_out": "integer (required)",
  "cost_usd": "number (required)",
  "latency_ms": "integer (required)"
}
```

---

## Глоссарий и owner-маппинг

| Owner | Описание | Транспорт |
|-------|----------|-----------|
| Bot | Telegram-бот (aiogram) | Прямая запись в БД через API + queue |
| Mini-app | Telegram WebApp (React+Vite) | POST `/api/events/` с JWT init_data |
| Backend | Django REST, scheduler, webhook-обработчики | Прямая запись в БД |
| Admin | Web-админка (React+Vite) | POST `/api/events/` с admin JWT |

## Версионирование

- При изменении схемы события — новая версия `event_schema_version` в payload, миграция в analytics-warehouse через ALTER.
- При удалении события — `deprecated_at` в реестре, событие продолжает приниматься 30 дней.

---

*Документ создан: Analytics Agent | Дата: 2026-05-15*
