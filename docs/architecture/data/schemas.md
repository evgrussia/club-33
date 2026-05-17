---
title: "Схемы таблиц БД — Клуб 33"
created_by: "Data Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# Схемы таблиц — Клуб 33

> Детальные DDL-описания всех таблиц. PostgreSQL 16 + pgvector.
> Все таблицы имеют `created_at TIMESTAMPTZ DEFAULT NOW()` и `updated_at TIMESTAMPTZ` (через trigger `BEFORE UPDATE`).
> Стратегия удаления: soft delete (`deleted_at`) для users/applications/payments; hard delete для логов после ретенции (events 12 мес, audit_log 24 мес, webhook_log 6 мес).
> Партиционирование: `events`, `chat_messages` — PARTITION BY RANGE (ts) по месяцу.

## Общие соглашения

- ID: `BIGSERIAL PRIMARY KEY` (или `BIGINT GENERATED ALWAYS AS IDENTITY`).
- Деньги: `NUMERIC(14,2)` для USD/RUB.
- Время: `TIMESTAMPTZ`, в UTC; отображение Europe/Moscow на уровне приложения.
- JSONB: `jsonb`, индексация — `GIN` по полям-фильтрам.
- Маскирование защищённых полей — на уровне AuditLogService (см. rules/04-logging).
- Enum-поля: текстовые `VARCHAR` + `CHECK` constraint (упрощает миграции; альтернатива — Postgres ENUM).

---

## 1. Identity context

### users
| Поле | Тип | Null | Default | Constraint |
|---|---|---|---|---|
| id | BIGSERIAL | NO | | PK |
| telegram_id | BIGINT | NO | | UNIQUE |
| username | VARCHAR(64) | YES | | |
| first_name | VARCHAR(128) | YES | | |
| last_name | VARCHAR(128) | YES | | |
| language_code | VARCHAR(8) | YES | 'ru' | |
| phone | VARCHAR(32) | YES | | |
| is_blocked | BOOLEAN | NO | FALSE | |
| created_at | TIMESTAMPTZ | NO | NOW() | |
| updated_at | TIMESTAMPTZ | NO | NOW() | |
| deleted_at | TIMESTAMPTZ | YES | | soft delete |

Индексы: `(telegram_id)` UNIQUE, `(username)`, `(deleted_at)` WHERE deleted_at IS NULL.

### sessions
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id ON DELETE CASCADE |
| jwt_jti | VARCHAR(64) | NO | UNIQUE |
| device | VARCHAR(128) | YES | |
| issued_at | TIMESTAMPTZ | NO | NOW() |
| expires_at | TIMESTAMPTZ | NO | |
| revoked_at | TIMESTAMPTZ | YES | |

Индексы: `(user_id)`, `(jwt_jti)` UNIQUE, partial `(expires_at)` WHERE revoked_at IS NULL.

### admin_users
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id, UNIQUE |
| role | VARCHAR(16) | NO | CHECK IN ('super','moderator','support') |
| is_active | BOOLEAN | NO | DEFAULT TRUE |
| created_at | TIMESTAMPTZ | NO | NOW() |
| updated_at | TIMESTAMPTZ | NO | NOW() |

Индексы: partial `(role)` WHERE is_active.

### audit_log
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| actor_type | VARCHAR(16) | NO | CHECK IN ('user','admin','system') |
| actor_id | BIGINT | YES | |
| action | VARCHAR(64) | NO | |
| category | VARCHAR(32) | NO | CHECK IN ('db','event','task','business','security') |
| entity_type | VARCHAR(64) | YES | |
| entity_id | BIGINT | YES | |
| data | JSONB | YES | masked sensitive fields |
| level | VARCHAR(16) | NO | DEFAULT 'INFO' |
| request_id | VARCHAR(64) | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(entity_type, entity_id)`, `(actor_type, actor_id)`, `(category, action)`, `(created_at DESC)`. Ретенция 24 мес.

---

## 2. Applications context

### applications
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id |
| status | VARCHAR(16) | NO | CHECK IN ('submitted','in_review','approved','rejected','expired') |
| source | VARCHAR(32) | NO | DEFAULT 'google_form' |
| form_data | JSONB | NO | Google Form payload |
| utm_source | VARCHAR(64) | YES | |
| utm_medium | VARCHAR(64) | YES | |
| utm_campaign | VARCHAR(64) | YES | |
| rejection_reason | TEXT | YES | |
| reviewed_by | BIGINT | YES | FK admin_users.id |
| submitted_at | TIMESTAMPTZ | NO | |
| reviewed_at | TIMESTAMPTZ | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |
| updated_at | TIMESTAMPTZ | NO | NOW() |
| deleted_at | TIMESTAMPTZ | YES | soft delete |

Индексы: `(user_id)`, `(status)`, partial `(submitted_at)` WHERE status='submitted'; GIN `(form_data)`.

### application_history
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| application_id | BIGINT | NO | FK |
| admin_id | BIGINT | YES | FK admin_users.id |
| from_status | VARCHAR(16) | YES | |
| to_status | VARCHAR(16) | NO | |
| comment | TEXT | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(application_id, created_at)`.

---

## 3. Payments context

### payment_methods
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| code | VARCHAR(32) | NO | UNIQUE CHECK IN ('usdt_trc20','usdt_ton','sbp','yookassa_card') |
| name | VARCHAR(64) | NO | |
| currency | VARCHAR(8) | NO | 'USD' or 'RUB' |
| is_active | BOOLEAN | NO | DEFAULT TRUE |
| config | JSONB | YES | provider настройки |

### fx_rate_snapshot
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| base_currency | VARCHAR(8) | NO | 'USD' |
| quote_currency | VARCHAR(8) | NO | 'RUB' |
| rate | NUMERIC(14,6) | NO | CHECK rate > 0 |
| source | VARCHAR(32) | NO | DEFAULT 'cbr' (DEC-010) |
| fetched_at | TIMESTAMPTZ | NO | момент запроса у провайдера |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(fetched_at DESC)`, `(base_currency, quote_currency, fetched_at DESC)`.

### payments
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id |
| method_id | BIGINT | NO | FK payment_methods.id |
| fx_snapshot_id | BIGINT | YES | FK fx_rate_snapshot.id (только RUB) |
| status | VARCHAR(16) | NO | CHECK IN ('pending','processing','completed','failed','refunded','expired') |
| tariff | VARCHAR(16) | NO | CHECK IN ('p6m','p12m','lifetime','custom') |
| amount_usd | NUMERIC(14,2) | NO | базовая цена |
| amount_rub | NUMERIC(14,2) | YES | рассчитано по fx_snapshot |
| amount_charged | NUMERIC(14,2) | NO | фактически выставлено |
| currency_charged | VARCHAR(8) | NO | |
| external_id | VARCHAR(128) | YES | UNIQUE (provider id) |
| provider_invoice_url | TEXT | YES | |
| provider_payload | JSONB | YES | |
| invoice_created_at | TIMESTAMPTZ | NO | NOW() |
| paid_at | TIMESTAMPTZ | YES | |
| expired_at | TIMESTAMPTZ | YES | TTL 24ч на pending |
| created_at | TIMESTAMPTZ | NO | NOW() |
| updated_at | TIMESTAMPTZ | NO | NOW() |
| deleted_at | TIMESTAMPTZ | YES | soft delete |

Индексы: `(user_id, status)`, `(external_id)` UNIQUE, partial `(status, invoice_created_at)` WHERE status IN ('pending','processing'), `(paid_at DESC)` WHERE status='completed'.

### webhook_log
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| payment_id | BIGINT | YES | FK payments.id |
| provider | VARCHAR(32) | NO | 'yookassa'/'usdt_trc20'/'usdt_ton' |
| external_id | VARCHAR(128) | NO | UNIQUE — идемпотентность |
| event_type | VARCHAR(64) | NO | |
| raw_payload | JSONB | NO | |
| signature | TEXT | YES | |
| signature_valid | BOOLEAN | NO | DEFAULT FALSE |
| processed | BOOLEAN | NO | DEFAULT FALSE |
| error | TEXT | YES | |
| received_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(external_id)` UNIQUE, `(provider, received_at DESC)`, partial `(processed)` WHERE processed=FALSE. Ретенция 6 мес.

### late_payment_review
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| payment_id | BIGINT | NO | FK, UNIQUE |
| reason | VARCHAR(32) | NO | CHECK IN ('sbp_no_confirmation','usdt_delay','other') |
| assigned_admin | BIGINT | YES | FK admin_users.id |
| resolution | VARCHAR(16) | YES | CHECK IN ('confirmed','refunded','abandoned') |
| notes | TEXT | YES | |
| flagged_at | TIMESTAMPTZ | NO | NOW() |
| resolved_at | TIMESTAMPTZ | YES | |

Индексы: partial `(flagged_at)` WHERE resolution IS NULL.

---

## 4. Subscriptions context

### subscriptions
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id |
| activating_payment | BIGINT | YES | FK payments.id (null для admin grant) |
| tariff | VARCHAR(16) | NO | CHECK IN ('p6m','p12m','lifetime') |
| status | VARCHAR(16) | NO | CHECK IN ('active','expired','cancelled') |
| start_date | DATE | NO | |
| end_date | DATE | YES | NULL = lifetime |
| days_total | INT | YES | |
| days_remaining | INT | YES | пересчёт на дату |
| is_lifetime | BOOLEAN | NO | DEFAULT FALSE |
| created_at | TIMESTAMPTZ | NO | NOW() |
| updated_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(user_id, status)`, partial UNIQUE `(user_id)` WHERE status='active', `(end_date)` WHERE status='active'.
CHECK: `(is_lifetime=TRUE AND end_date IS NULL) OR (is_lifetime=FALSE AND end_date IS NOT NULL)`.

### subscription_history
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| subscription_id | BIGINT | NO | FK |
| actor_id | BIGINT | YES | |
| actor_type | VARCHAR(16) | NO | 'user'/'admin'/'system' |
| action | VARCHAR(32) | NO | CHECK IN ('activated','extended','cancelled','granted_lifetime','days_adjusted') |
| days_delta | INT | YES | |
| from_end_date | DATE | YES | |
| to_end_date | DATE | YES | |
| comment | TEXT | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(subscription_id, created_at DESC)`.

### renewal_reminders
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| subscription_id | BIGINT | NO | FK |
| days_before | INT | NO | DEFAULT 10 |
| status | VARCHAR(16) | NO | CHECK IN ('scheduled','sent','cancelled') |
| scheduled_at | TIMESTAMPTZ | NO | |
| sent_at | TIMESTAMPTZ | YES | |

Индексы: partial `(scheduled_at)` WHERE status='scheduled'.

---

## 5. Access context

### invite_links
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id |
| target | VARCHAR(16) | NO | CHECK IN ('channel','chat') |
| telegram_invite_link | TEXT | NO | |
| max_uses | INT | NO | DEFAULT 1 |
| ttl_hours | INT | NO | DEFAULT 24 |
| expires_at | TIMESTAMPTZ | NO | |
| used_at | TIMESTAMPTZ | YES | |
| revoked_at | TIMESTAMPTZ | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(user_id, target)`, partial `(expires_at)` WHERE used_at IS NULL AND revoked_at IS NULL.

### law_acceptances
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id |
| phrase_entered | TEXT | NO | хранится для аудита (не маскируется) |
| phrase_expected_hash | VARCHAR(64) | NO | SHA-256 эталонной фразы на момент принятия |
| accepted_kb_indexing | BOOLEAN | NO | DEFAULT TRUE (часть закона) |
| accepted_at | TIMESTAMPTZ | NO | NOW() |
| ip_hash | VARCHAR(64) | YES | для anti-bot |

Индексы: `(user_id)`, UNIQUE `(user_id)` WHERE accepted_at IS NOT NULL.

### fsm_states
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id, UNIQUE |
| state | VARCHAR(64) | NO | напр. 'awaiting_interview','law_pending','onboarded' |
| context | JSONB | NO | DEFAULT '{}' |
| updated_at | TIMESTAMPTZ | NO | NOW() |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(state)`, `(updated_at)`.

---

## 6. Calendar context

### time_slots
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| host_user_id | BIGINT | NO | FK users.id (основатель) |
| start_at | TIMESTAMPTZ | NO | |
| end_at | TIMESTAMPTZ | NO | CHECK end_at > start_at |
| status | VARCHAR(16) | NO | CHECK IN ('open','reserved','completed','cancelled') |
| capacity | INT | NO | DEFAULT 1 |
| metadata | JSONB | YES | |
| created_at, updated_at | TIMESTAMPTZ | NO | |

Индексы: `(start_at)` WHERE status='open', GiST EXCLUDE для пересечений по host_user_id (опционально).

### bookings
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| slot_id | BIGINT | NO | FK time_slots.id |
| user_id | BIGINT | NO | FK users.id |
| status | VARCHAR(16) | NO | CHECK IN ('booked','attended','no_show','cancelled') |
| meeting_url | TEXT | YES | |
| notes | TEXT | YES | |
| booked_at | TIMESTAMPTZ | NO | NOW() |
| cancelled_at | TIMESTAMPTZ | YES | |
| created_at, updated_at | TIMESTAMPTZ | NO | |

Индексы: UNIQUE `(slot_id)` WHERE status IN ('booked','attended') AND capacity=1; `(user_id, status)`.

### calendar_reminders
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| booking_id | BIGINT | NO | FK |
| hours_before | INT | NO | напр. 24, 1 |
| status | VARCHAR(16) | NO | CHECK IN ('scheduled','sent','cancelled') |
| scheduled_at | TIMESTAMPTZ | NO | |
| sent_at | TIMESTAMPTZ | YES | |

Индексы: partial `(scheduled_at)` WHERE status='scheduled'.

---

## 7. Events (аналитика)

### events
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| event_name | VARCHAR(64) | NO | snake_case из tracking-plan.md |
| user_id | BIGINT | YES | |
| session_id | VARCHAR(64) | YES | |
| properties | JSONB | NO | DEFAULT '{}' |
| ts | TIMESTAMPTZ | NO | NOW() — partition key |
| created_at | TIMESTAMPTZ | NO | NOW() |

**Партиционирование:** `PARTITION BY RANGE (ts)` — месячные партиции (events_2026_05 и т.д.), создаются через pg_partman.
Индексы (на каждой партиции): `(event_name, ts DESC)`, `(user_id, ts DESC)`, GIN `(properties)`.
Ретенция 12 месяцев (старые партиции DROP).

---

## 8. Notifications

### notification_queue
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | YES | NULL = admin_chat broadcast |
| channel | VARCHAR(16) | NO | CHECK IN ('bot','admin_chat','email','miniapp_push') |
| template | VARCHAR(64) | NO | |
| payload | JSONB | NO | |
| status | VARCHAR(16) | NO | CHECK IN ('queued','sent','failed','cancelled') |
| scheduled_at | TIMESTAMPTZ | NO | |
| sent_at | TIMESTAMPTZ | YES | |
| error | TEXT | YES | |

Индексы: partial `(scheduled_at, status)` WHERE status='queued'.

### notification_history
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | YES | |
| channel | VARCHAR(16) | NO | |
| template | VARCHAR(64) | NO | |
| payload | JSONB | NO | |
| sent_at | TIMESTAMPTZ | NO | |

Индексы: `(user_id, sent_at DESC)`. Ретенция 12 мес.

---

## 9. Social (Phase 2)

### roles
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| code | VARCHAR(64) | NO | UNIQUE (slug) |
| name | VARCHAR(128) | NO | |
| description | TEXT | YES | |
| kyc_required | BOOLEAN | NO | DEFAULT FALSE |
| is_archived | BOOLEAN | NO | DEFAULT FALSE |
| created_at, updated_at | TIMESTAMPTZ | NO | |

### user_roles
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id |
| role_id | BIGINT | NO | FK roles.id |
| stars | INT | NO | DEFAULT 0 CHECK 0..4 |
| reputation_score | INT | NO | DEFAULT 0 |
| kyc_status | VARCHAR(16) | NO | DEFAULT 'none' CHECK IN ('none','pending','verified','rejected') |
| kyc_verified_at | TIMESTAMPTZ | YES | |
| kyc_verified_by | BIGINT | YES | FK admin_users.id |
| assigned_at | TIMESTAMPTZ | NO | NOW() |
| last_activity_at | TIMESTAMPTZ | YES | для inactivity decay |

Индексы: UNIQUE `(user_id, role_id)`, `(role_id, stars DESC)`, `(last_activity_at)`.

### respects
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| giver_id | BIGINT | NO | FK users.id |
| receiver_id | BIGINT | NO | FK users.id |
| role_id | BIGINT | YES | FK roles.id (роль, за которую) |
| source | VARCHAR(32) | NO | CHECK IN ('miniapp','chat_command','sticker_reaction') |
| month_key | CHAR(7) | NO | YYYY-MM |
| comment | TEXT | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |

CHECK: `giver_id <> receiver_id`.
Индексы: `(giver_id, month_key)`, `(receiver_id, month_key)`, `(month_key)`.

### user_monthly_balance
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| user_id | BIGINT | NO | FK users.id, PK |
| month | CHAR(7) | NO | YYYY-MM, PK |
| respects_total | INT | NO | DEFAULT 30 |
| respects_used | INT | NO | DEFAULT 0 |
| received_from_counts | JSONB | NO | DEFAULT '{}' — `{user_id: count}` для лимита 3/получателя |
| updated_at | TIMESTAMPTZ | NO | NOW() |

PRIMARY KEY `(user_id, month)`. CHECK `respects_used <= respects_total`.

### complaints
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| complainant_id | BIGINT | NO | FK users.id |
| target_id | BIGINT | NO | FK users.id |
| status | VARCHAR(16) | NO | CHECK IN ('submitted','in_review','confirmed','rejected','escalated') |
| reason | TEXT | NO | |
| evidence | JSONB | YES | ссылки, скрины |
| reviewed_by | BIGINT | YES | FK admin_users.id |
| resolution_comment | TEXT | YES | |
| submitted_at | TIMESTAMPTZ | NO | NOW() |
| reviewed_at | TIMESTAMPTZ | YES | |
| created_at, updated_at | TIMESTAMPTZ | NO | |

Индексы: `(target_id, status)`, `(status, submitted_at DESC)`. Анонимность — на уровне сервиса/API.

### stars_history
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_role_id | BIGINT | NO | FK user_roles.id |
| from_stars | INT | NO | |
| to_stars | INT | NO | |
| from_score | INT | NO | |
| to_score | INT | NO | |
| reason | VARCHAR(32) | NO | CHECK IN ('respect','degradation','inactivity','manual_admin','complaint_resolved') |
| actor_id | BIGINT | YES | |
| comment | TEXT | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(user_role_id, created_at DESC)`.

---

## 10. AI (Phase 2)

### member_profiles
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| user_id | BIGINT | NO | PK, FK users.id |
| bio | TEXT | YES | |
| competencies | TEXT | YES | |
| interests | TEXT | YES | |
| embedding | VECTOR(1536) | YES | pgvector |
| embedding_model | VARCHAR(64) | YES | 'voyage-3' и т.д. |
| embedding_updated_at | TIMESTAMPTZ | YES | |
| updated_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `ivfflat (embedding vector_cosine_ops) WITH (lists=100)` ИЛИ `hnsw (embedding vector_cosine_ops)` (для >50k записей).

### chat_messages
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| telegram_msg_id | BIGINT | NO | |
| chat_id | BIGINT | NO | |
| user_id | BIGINT | YES | FK users.id |
| text | TEXT | YES | |
| media_meta | JSONB | YES | |
| posted_at | TIMESTAMPTZ | NO | partition key |
| indexed | BOOLEAN | NO | DEFAULT FALSE |
| created_at | TIMESTAMPTZ | NO | NOW() |

**Партиционирование:** `PARTITION BY RANGE (posted_at)` — месячные партиции.
UNIQUE `(chat_id, telegram_msg_id)`. Индексы: partial `(posted_at)` WHERE indexed=FALSE.

### kb_chunks
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| source_message_id | BIGINT | YES | FK chat_messages.id |
| text | TEXT | NO | |
| chunk_index | INT | NO | |
| embedding | VECTOR(1536) | NO | |
| embedding_model | VARCHAR(64) | NO | |
| metadata | JSONB | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: HNSW `(embedding vector_cosine_ops)`, `(source_message_id)`.

### daily_summaries
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| period_start | DATE | NO | |
| period_end | DATE | NO | |
| kind | VARCHAR(16) | NO | CHECK IN ('weekly_digest','daily') |
| content | TEXT | NO | |
| top_topics | JSONB | YES | |
| stats | JSONB | YES | |
| generated_by_model_log_id | BIGINT | YES | FK ai_usage_log.id |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(kind, period_end DESC)`.

### ai_usage_log
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | YES | |
| feature | VARCHAR(32) | NO | CHECK IN ('match','ask','digest','profile_embedding','classify') |
| model | VARCHAR(64) | NO | |
| tokens_in | INT | NO | DEFAULT 0 |
| tokens_out | INT | NO | DEFAULT 0 |
| embedding_tokens | INT | NO | DEFAULT 0 |
| cost_usd | NUMERIC(10,4) | NO | DEFAULT 0 |
| latency_ms | INT | YES | |
| success | BOOLEAN | NO | DEFAULT TRUE |
| error | TEXT | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(feature, created_at DESC)`, `(model, created_at)`, `(user_id, created_at DESC)`.

### match_feedback
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id |
| match_request_id | BIGINT | NO | ссылка на ai_usage_log.id (или сессионный uuid) |
| suggested_user_id | BIGINT | NO | FK users.id |
| rating | VARCHAR(16) | NO | CHECK IN ('useful','neutral','miss') |
| comment | TEXT | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(match_request_id)`, `(rating, created_at)`.

### kb_feedback
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id |
| query_id | BIGINT | NO | ссылка на ai_usage_log.id |
| rating | VARCHAR(16) | NO | CHECK IN ('useful','miss') |
| comment | TEXT | YES | |
| sources | JSONB | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(query_id)`, `(rating, created_at)`.

---

## 11. Time Economy (Phase 3)

### time_gifts
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| giver_id | BIGINT | NO | FK users.id |
| receiver_id | BIGINT | NO | FK users.id |
| source_subscription_id | BIGINT | YES | FK subscriptions.id (NULL для lifetime annual budget) |
| days | INT | NO | CHECK days > 0 |
| usd_equivalent | NUMERIC(10,2) | NO | days * 2.5 |
| is_anonymous | BOOLEAN | NO | DEFAULT FALSE |
| message | TEXT | YES | |
| status | VARCHAR(16) | NO | CHECK IN ('applied','reverted') |
| created_at | TIMESTAMPTZ | NO | NOW() |

CHECK `giver_id <> receiver_id`.
Индексы: `(giver_id, created_at DESC)`, `(receiver_id, created_at DESC)`.

### day_burns
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK |
| days | INT | NO | CHECK days > 0 |
| usd_equivalent | NUMERIC(10,2) | NO | |
| reason | TEXT | YES | |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(user_id, created_at DESC)`.

### admin_day_adjustments
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| admin_id | BIGINT | NO | FK admin_users.id (super only) |
| user_id | BIGINT | NO | FK users.id |
| days_delta | INT | NO | (положительный=credit, отрицательный=debit) |
| usd_equivalent | NUMERIC(10,2) | NO | |
| comment | TEXT | NO | NOT NULL — обязателен |
| direction | VARCHAR(16) | NO | CHECK IN ('credit','debit') |
| created_at | TIMESTAMPTZ | NO | NOW() |

Индексы: `(user_id, created_at DESC)`, `(admin_id, created_at DESC)`.

### lifetime_budgets
| Поле | Тип | Null | Constraint |
|---|---|---|---|
| id | BIGSERIAL | NO | PK |
| user_id | BIGINT | NO | FK users.id |
| year | INT | NO | |
| budget_total | INT | NO | DEFAULT 33 |
| budget_used | INT | NO | DEFAULT 0 |
| reset_at | TIMESTAMPTZ | NO | 1 января 00:00 МСК следующего года |
| updated_at | TIMESTAMPTZ | NO | NOW() |

UNIQUE `(user_id, year)`. CHECK `budget_used <= budget_total`.

---

## Сводка стратегий

| Аспект | Решение |
|---|---|
| Soft delete | users, applications, payments — `deleted_at` |
| Hard delete | events, audit_log, webhook_log, notification_history — по ретенции |
| Партиционирование | `events`, `chat_messages` — `RANGE (ts/posted_at)` по месяцу, pg_partman |
| Идемпотентность | webhook_log.external_id UNIQUE; payments.external_id UNIQUE |
| Аудит | audit_log + per-context history (subscription_history, application_history, stars_history) |
| pgvector | `member_profiles.embedding`, `kb_chunks.embedding` — VECTOR(1536), ivfflat/hnsw cosine |
| Money | NUMERIC(14,2) для USD/RUB, NUMERIC(14,6) для FX rate |
| Time | TIMESTAMPTZ UTC; MSK на UI |
| Enum | VARCHAR + CHECK (миграционная гибкость) |
| FK | ON DELETE CASCADE для sessions/balances; ON DELETE RESTRICT для payments/subscriptions |

---

*Документ создан: Data Agent | Дата: 2026-05-16*
