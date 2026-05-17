---
title: "ER-диаграмма — Клуб 33"
created_by: "Data Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# ER-диаграмма — Клуб 33

> Полная модель данных для трёх фаз релиза. Группировка по bounded contexts из §23 ТЗ + расширения (events для воронки, fx_rate_snapshot, late_payment_review, calendar, AI feedback).
> СУБД: PostgreSQL 16 + pgvector (embeddings 1536 dim).

## Обзор bounded contexts

| Контекст | Таблицы | Фаза |
|---|---|---|
| Identity | users, sessions, admin_users, audit_log | 1 |
| Applications | applications, application_history | 1 |
| Payments | payments, payment_methods, fx_rate_snapshot, late_payment_review, webhook_log | 1 |
| Subscriptions | subscriptions, subscription_history, renewal_reminders | 1 |
| Access | invite_links, law_acceptances, fsm_states | 1 |
| Calendar | time_slots, bookings, calendar_reminders | 1 |
| Events | events | 1 |
| Notifications | notification_queue, notification_history | 1 |
| Social | roles, user_roles, respects, user_monthly_balance, complaints, stars_history | 2 |
| AI | member_profiles, chat_messages, kb_chunks, daily_summaries, ai_usage_log, match_feedback, kb_feedback | 2 |
| Time Economy | time_gifts, day_burns, admin_day_adjustments, lifetime_budgets | 3 |

---

## 1. Identity + Applications + Access (Phase 1)

```mermaid
erDiagram
    users ||--o{ sessions : has
    users ||--o{ applications : submits
    users ||--o{ law_acceptances : accepts
    users ||--o{ fsm_states : owns
    users ||--o{ invite_links : receives
    admin_users ||--o{ audit_log : actor
    admin_users ||--o{ application_history : modifies
    applications ||--o{ application_history : has

    users {
        bigint id PK
        bigint telegram_id UK
        string username
        string first_name
        string last_name
        string language_code
        string phone
        boolean is_blocked
        timestamp created_at
        timestamp updated_at
        timestamp deleted_at
    }
    sessions {
        bigint id PK
        bigint user_id FK
        string jwt_jti UK
        string device
        timestamp issued_at
        timestamp expires_at
        timestamp revoked_at
    }
    admin_users {
        bigint id PK
        bigint user_id FK
        enum role "super|moderator|support"
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }
    audit_log {
        bigint id PK
        string actor_type "user|admin|system"
        bigint actor_id
        string action
        string category
        string entity_type
        bigint entity_id
        jsonb data
        string level
        string request_id
        timestamp created_at
    }
    applications {
        bigint id PK
        bigint user_id FK
        enum status "submitted|in_review|approved|rejected|expired"
        string source "google_form|admin_manual"
        jsonb form_data
        string utm_source
        string utm_medium
        string utm_campaign
        text rejection_reason
        bigint reviewed_by FK
        timestamp submitted_at
        timestamp reviewed_at
        timestamp created_at
        timestamp updated_at
    }
    application_history {
        bigint id PK
        bigint application_id FK
        bigint admin_id FK
        enum from_status
        enum to_status
        text comment
        timestamp created_at
    }
    invite_links {
        bigint id PK
        bigint user_id FK
        enum target "channel|chat"
        string telegram_invite_link
        int max_uses
        int ttl_hours
        timestamp expires_at
        timestamp used_at
        timestamp revoked_at
        timestamp created_at
    }
    law_acceptances {
        bigint id PK
        bigint user_id FK
        text phrase_entered
        text phrase_expected_hash
        boolean accepted_kb_indexing
        timestamp accepted_at
        string ip_hash
    }
    fsm_states {
        bigint id PK
        bigint user_id FK,UK
        string state
        jsonb context
        timestamp updated_at
        timestamp created_at
    }
```

---

## 2. Payments + Subscriptions (Phase 1)

```mermaid
erDiagram
    users ||--o{ payments : pays
    users ||--o{ subscriptions : holds
    payments ||--o| subscriptions : activates
    payments ||--o{ webhook_log : confirmed_via
    payments ||--o| fx_rate_snapshot : uses
    payments ||--o| late_payment_review : flagged_by
    subscriptions ||--o{ subscription_history : has
    subscriptions ||--o{ renewal_reminders : triggers

    payment_methods {
        bigint id PK
        string code UK "usdt_trc20|usdt_ton|sbp|yookassa_card"
        string name
        string currency
        boolean is_active
        jsonb config
    }
    fx_rate_snapshot {
        bigint id PK
        string base_currency
        string quote_currency
        decimal rate
        string source "cbr|openexchange"
        timestamp fetched_at
        timestamp created_at
    }
    payments {
        bigint id PK
        bigint user_id FK
        bigint method_id FK
        bigint fx_snapshot_id FK
        enum status "pending|processing|completed|failed|refunded|expired"
        enum tariff "p6m|p12m|lifetime|custom"
        decimal amount_usd
        decimal amount_rub
        decimal amount_charged
        string currency_charged
        string external_id UK
        string provider_invoice_url
        text provider_payload
        timestamp invoice_created_at
        timestamp paid_at
        timestamp expired_at
        timestamp created_at
        timestamp updated_at
    }
    webhook_log {
        bigint id PK
        bigint payment_id FK
        string provider
        string external_id UK
        string event_type
        jsonb raw_payload
        string signature
        boolean signature_valid
        boolean processed
        text error
        timestamp received_at
    }
    late_payment_review {
        bigint id PK
        bigint payment_id FK
        enum reason "sbp_no_confirmation|usdt_delay|other"
        bigint assigned_admin FK
        enum resolution "confirmed|refunded|abandoned"
        text notes
        timestamp flagged_at
        timestamp resolved_at
    }
    subscriptions {
        bigint id PK
        bigint user_id FK
        bigint activating_payment FK
        enum tariff "p6m|p12m|lifetime"
        enum status "active|expired|cancelled"
        date start_date
        date end_date "null=lifetime"
        int days_total
        int days_remaining
        boolean is_lifetime
        timestamp created_at
        timestamp updated_at
    }
    subscription_history {
        bigint id PK
        bigint subscription_id FK
        bigint actor_id
        string actor_type
        enum action "activated|extended|cancelled|granted_lifetime|days_adjusted"
        int days_delta
        date from_end_date
        date to_end_date
        text comment
        timestamp created_at
    }
    renewal_reminders {
        bigint id PK
        bigint subscription_id FK
        int days_before
        enum status "scheduled|sent|cancelled"
        timestamp scheduled_at
        timestamp sent_at
    }
```

---

## 3. Calendar + Events + Notifications (Phase 1)

```mermaid
erDiagram
    users ||--o{ bookings : books
    time_slots ||--o{ bookings : reserved_by
    bookings ||--o{ calendar_reminders : has
    users ||--o{ events : generates
    users ||--o{ notification_queue : receives

    time_slots {
        bigint id PK
        bigint host_user_id FK "основатель"
        timestamp start_at
        timestamp end_at
        enum status "open|reserved|completed|cancelled"
        int capacity
        jsonb metadata
        timestamp created_at
        timestamp updated_at
    }
    bookings {
        bigint id PK
        bigint slot_id FK
        bigint user_id FK
        enum status "booked|attended|no_show|cancelled"
        string meeting_url
        text notes
        timestamp booked_at
        timestamp cancelled_at
        timestamp created_at
        timestamp updated_at
    }
    calendar_reminders {
        bigint id PK
        bigint booking_id FK
        int hours_before
        enum status "scheduled|sent|cancelled"
        timestamp scheduled_at
        timestamp sent_at
    }
    events {
        bigint id PK
        string event_name
        bigint user_id
        string session_id
        jsonb properties
        timestamp ts
        timestamp created_at
    }
    notification_queue {
        bigint id PK
        bigint user_id
        enum channel "bot|admin_chat|email|miniapp_push"
        string template
        jsonb payload
        enum status "queued|sent|failed|cancelled"
        timestamp scheduled_at
        timestamp sent_at
        text error
    }
    notification_history {
        bigint id PK
        bigint user_id
        enum channel
        string template
        jsonb payload
        timestamp sent_at
    }
```

---

## 4. Social (Phase 2)

```mermaid
erDiagram
    users ||--o{ user_roles : holds
    roles ||--o{ user_roles : assigned_to
    users ||--o{ respects : gives
    users ||--o{ respects : receives
    users ||--o{ user_monthly_balance : has
    users ||--o{ complaints : files
    users ||--o{ complaints : target_of
    user_roles ||--o{ stars_history : changes

    roles {
        bigint id PK
        string code UK
        string name
        text description
        boolean kyc_required
        boolean is_archived
        timestamp created_at
        timestamp updated_at
    }
    user_roles {
        bigint id PK
        bigint user_id FK
        bigint role_id FK
        int stars "0..4"
        int reputation_score
        enum kyc_status "none|pending|verified|rejected"
        timestamp kyc_verified_at
        bigint kyc_verified_by FK
        timestamp assigned_at
        timestamp last_activity_at
    }
    respects {
        bigint id PK
        bigint giver_id FK
        bigint receiver_id FK
        bigint role_id FK
        enum source "miniapp|chat_command|sticker_reaction"
        string month_key "YYYY-MM"
        text comment
        timestamp created_at
    }
    user_monthly_balance {
        bigint user_id FK,PK
        string month FK,PK "YYYY-MM"
        int respects_total "30"
        int respects_used
        jsonb received_from_counts
        timestamp updated_at
    }
    stars_history {
        bigint id PK
        bigint user_role_id FK
        int from_stars
        int to_stars
        int from_score
        int to_score
        enum reason "respect|degradation|inactivity|manual_admin|complaint_resolved"
        bigint actor_id
        text comment
        timestamp created_at
    }
    complaints {
        bigint id PK
        bigint complainant_id FK
        bigint target_id FK
        enum status "submitted|in_review|confirmed|rejected|escalated"
        text reason
        jsonb evidence
        bigint reviewed_by FK
        text resolution_comment
        timestamp submitted_at
        timestamp reviewed_at
        timestamp created_at
        timestamp updated_at
    }
```

---

## 5. AI (Phase 2)

```mermaid
erDiagram
    users ||--|| member_profiles : owns
    users ||--o{ chat_messages : authors
    chat_messages ||--o{ kb_chunks : derives
    daily_summaries }o--|| users : generated_for
    users ||--o{ ai_usage_log : initiates
    users ||--o{ match_feedback : leaves
    users ||--o{ kb_feedback : leaves

    member_profiles {
        bigint user_id FK,PK
        text bio
        text competencies
        text interests
        vector embedding "1536"
        string embedding_model
        timestamp embedding_updated_at
        timestamp updated_at
    }
    chat_messages {
        bigint id PK
        bigint telegram_msg_id
        bigint chat_id
        bigint user_id FK
        text text
        jsonb media_meta
        timestamp posted_at
        boolean indexed
        timestamp created_at
    }
    kb_chunks {
        bigint id PK
        bigint source_message_id FK
        text text
        int chunk_index
        vector embedding "1536"
        string embedding_model
        jsonb metadata
        timestamp created_at
    }
    daily_summaries {
        bigint id PK
        date period_start
        date period_end
        enum kind "weekly_digest|daily"
        text content
        jsonb top_topics
        jsonb stats
        bigint generated_by_model_log_id FK
        timestamp created_at
    }
    ai_usage_log {
        bigint id PK
        bigint user_id
        string feature "match|ask|digest|profile_embedding"
        string model "haiku|sonnet|opus|voyage-3"
        int tokens_in
        int tokens_out
        int embedding_tokens
        decimal cost_usd
        int latency_ms
        boolean success
        text error
        timestamp created_at
    }
    match_feedback {
        bigint id PK
        bigint user_id FK
        bigint match_request_id
        bigint suggested_user_id FK
        enum rating "useful|neutral|miss"
        text comment
        timestamp created_at
    }
    kb_feedback {
        bigint id PK
        bigint user_id FK
        bigint query_id
        enum rating "useful|miss"
        text comment
        jsonb sources
        timestamp created_at
    }
```

---

## 6. Time Economy (Phase 3)

```mermaid
erDiagram
    users ||--o{ time_gifts : gives
    users ||--o{ time_gifts : receives
    users ||--o{ day_burns : burns
    users ||--o{ admin_day_adjustments : affected
    users ||--o{ lifetime_budgets : has
    subscriptions ||--o{ time_gifts : source

    time_gifts {
        bigint id PK
        bigint giver_id FK
        bigint receiver_id FK
        bigint source_subscription_id FK
        int days
        decimal usd_equivalent
        boolean is_anonymous
        text message
        enum status "applied|reverted"
        timestamp created_at
    }
    day_burns {
        bigint id PK
        bigint user_id FK
        int days
        decimal usd_equivalent
        text reason
        timestamp created_at
    }
    admin_day_adjustments {
        bigint id PK
        bigint admin_id FK
        bigint user_id FK
        int days_delta
        decimal usd_equivalent
        text comment
        enum direction "credit|debit"
        timestamp created_at
    }
    lifetime_budgets {
        bigint id PK
        bigint user_id FK
        int year
        int budget_total "33"
        int budget_used
        timestamp reset_at
        timestamp updated_at
    }
```

---

## Связи между контекстами

| Связь | Тип | Описание |
|---|---|---|
| applications.user_id → users.id | FK | Кандидат подаёт заявку |
| applications.reviewed_by → admin_users.id | FK | Модератор рассматривает |
| payments.fx_snapshot_id → fx_rate_snapshot.id | FK | Курс зафиксирован при инвойсе |
| payments → subscriptions | one-to-one (activating) | Успешная оплата = активация |
| subscriptions.activating_payment → payments.id | FK | Источник подписки |
| time_gifts.source_subscription_id → subscriptions.id | FK | Из чьей подписки взяты дни |
| respects → user_monthly_balance | счётчик | Контроль 30/мес и 3 на получателя |
| chat_messages → kb_chunks | one-to-many | Индексация для RAG |
| webhook_log.external_id | UNIQUE | Идемпотентность |
| events.event_name + ts | партиционирование по месяцу | Аналитика воронки |

---

*Документ создан: Data Agent | Дата: 2026-05-16*
