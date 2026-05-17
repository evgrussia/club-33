---
title: "Event Storming — Клуб 33"
created_by: "Data Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# Event Storming — Domain Events

> Domain Events для будущей event-driven архитектуры. Для каждого события: payload, source context (кто публикует), consumer contexts (кто потребляет). Все события — версии `v1`, semver на уровне событий.

## Соглашения

- Имя события: `{Aggregate}{PastVerb}` (например, `PaymentCompleted`).
- Каждое событие имеет: `event_id (uuid)`, `event_name`, `version`, `occurred_at`, `aggregate_id`, `producer`, `payload`.
- Транспорт: на старте — внутрипроцессные signals (Django) + запись в `events` таблицу для analytics. После Phase 2 — Redis Streams / NATS (опционально).
- Идемпотентность consumer'ов — обязательна (event_id + processed flag).

---

## 1. Applications context

### ApplicationSubmitted
- **Source:** Applications
- **Trigger:** Google-форма webhook принят / админ создал заявку вручную
- **Payload:**
  ```json
  {
    "application_id": 123,
    "user_id": 456,
    "source": "google_form",
    "form_data_summary": {"name": "...", "city": "..."},
    "utm": {"source": "...", "medium": "...", "campaign": "..."}
  }
  ```
- **Consumers:** Notifications (admin_chat alert), Analytics (events.application_submitted), Calendar (предложить слоты после одобрения)

### ApplicationApproved
- **Source:** Applications
- **Trigger:** Админ одобрил
- **Payload:** `{application_id, user_id, reviewed_by, role_hint?}`
- **Consumers:** Notifications (бот пишет кандидату), Calendar (открывает запись на интервью), Analytics, Access (FSM → awaiting_interview)

### ApplicationRejected
- **Source:** Applications
- **Payload:** `{application_id, user_id, reason}`
- **Consumers:** Notifications, Analytics

---

## 2. Payments context

### PaymentInvoiceCreated
- **Source:** Payments
- **Trigger:** Пользователь выбрал тариф и метод
- **Payload:** `{payment_id, user_id, tariff, method, amount_usd, amount_charged, currency_charged, fx_rate?, provider_invoice_url, expires_at}`
- **Consumers:** Notifications (бот → ссылка/реквизиты), Analytics

### PaymentCompleted
- **Source:** Payments
- **Trigger:** Webhook подтвердил оплату ИЛИ админ ручная сверка СБП
- **Payload:** `{payment_id, user_id, tariff, amount_usd, amount_charged, paid_at, method}`
- **Consumers:** Subscriptions (активация), Notifications (бот → подтверждение, admin_chat), Access (FSM → law_pending), Analytics

### PaymentFailed
- **Payload:** `{payment_id, user_id, reason, provider_error}`
- **Consumers:** Notifications, Analytics

### LatePaymentDetected
- **Source:** Payments (scheduler)
- **Trigger:** Pending payment > 10 минут
- **Payload:** `{payment_id, user_id, method, age_minutes}`
- **Consumers:** Notifications (бот → кнопка «Поддержка», admin_chat), late_payment_review (создание записи)

### PaymentRefunded
- **Payload:** `{payment_id, user_id, amount, reason}`
- **Consumers:** Subscriptions (возможный revoke), Notifications, Analytics

---

## 3. Subscriptions context

### SubscriptionActivated
- **Source:** Subscriptions
- **Trigger:** PaymentCompleted consumed
- **Payload:** `{subscription_id, user_id, tariff, start_date, end_date, is_lifetime}`
- **Consumers:** Access (генерация invite после закона), Notifications, Analytics, TimeEconomy (lifetime_budget init если lifetime)

### SubscriptionExpired
- **Source:** Subscriptions (scheduler ежедневный)
- **Payload:** `{subscription_id, user_id, expired_on}`
- **Consumers:** Notifications, Access (revoke?), Analytics

### SubscriptionRenewed
- **Payload:** `{subscription_id, user_id, prev_end_date, new_end_date, payment_id}`
- **Consumers:** Notifications, Analytics

### SubscriptionExtendedByAdmin
- **Payload:** `{subscription_id, user_id, admin_id, days_delta, comment}`
- **Consumers:** Notifications, Analytics, audit_log

### LifetimeGranted
- **Source:** Subscriptions
- **Trigger:** Admin (super) выдал lifetime
- **Payload:** `{subscription_id, user_id, admin_id, comment}`
- **Consumers:** Notifications, TimeEconomy (lifetime_budget init), Analytics

---

## 4. Access context

### LawAccepted
- **Source:** Access
- **Trigger:** Кандидат ввёл фразу корректно
- **Payload:** `{user_id, accepted_at, phrase_hash, accepted_kb_indexing}`
- **Consumers:** Access (выдача invite), AI (разрешение на индексацию его сообщений), Analytics

### InviteIssued
- **Source:** Access
- **Payload:** `{invite_link_id, user_id, target, telegram_invite_link, expires_at}`
- **Consumers:** Notifications, Analytics

### InviteUsed
- **Source:** Access (Telegram update / scheduler check)
- **Payload:** `{invite_link_id, user_id, target, used_at}`
- **Consumers:** Notifications (admin_chat), Analytics, Access (закрыть остальные?)

### InviteExpired
- **Payload:** `{invite_link_id, user_id, expired_at}`
- **Consumers:** Notifications (кнопка «Получить новый»), Analytics

---

## 5. Calendar context

### BookingCreated
- **Source:** Calendar
- **Payload:** `{booking_id, user_id, slot_id, start_at}`
- **Consumers:** Notifications (пользователю + основателю), Reminders (запланировать -24ч и -1ч)

### BookingNoShow
- **Source:** Calendar (scheduler после слота)
- **Payload:** `{booking_id, user_id, slot_id}`
- **Consumers:** Notifications (admin_chat), Analytics, Applications (возможный flag)

### BookingCancelled
- **Payload:** `{booking_id, user_id, slot_id, cancelled_by}`
- **Consumers:** Notifications, Calendar (slot → open)

---

## 6. Social context (Phase 2)

### RespectGiven
- **Source:** Social
- **Payload:** `{respect_id, giver_id, receiver_id, role_id, source, month_key}`
- **Consumers:** Social (обновление stars_history), AI (сигнал для матчинга), Notifications (получателю — анонимно: «вам дали респект»), Analytics

### StarsChanged
- **Source:** Social
- **Payload:** `{user_role_id, user_id, role_id, from_stars, to_stars, from_score, to_score, reason}`
- **Consumers:** Notifications (если повышение), Analytics

### ComplaintFiled
- **Source:** Social
- **Payload:** `{complaint_id, target_id, has_evidence}` — complainant_id скрыт от target
- **Consumers:** Notifications (admin_chat — модератор), Analytics

### ComplaintResolved
- **Source:** Social
- **Payload:** `{complaint_id, target_id, resolution, reviewed_by}`
- **Consumers:** Notifications (стороны), Social (stars_history если impact), Analytics

### RoleAssigned
- **Source:** Social
- **Trigger:** Основатель на интервью / админ в админке
- **Payload:** `{user_role_id, user_id, role_id, assigned_by, kyc_required}`
- **Consumers:** Notifications, AI (профиль обновлён → перерасчёт embedding), Analytics

### MonthlyBalanceReset
- **Source:** Social (scheduler 1-го числа 00:00 МСК)
- **Payload:** `{month_key, users_count}`
- **Consumers:** Analytics

---

## 7. AI context (Phase 2)

### ProfileEmbeddingUpdated
- **Source:** AI
- **Trigger:** Пользователь обновил bio/competencies/role
- **Payload:** `{user_id, embedding_model, tokens, cost_usd}`
- **Consumers:** Analytics, ai_usage_log

### MatchRequested
- **Source:** AI
- **Payload:** `{match_request_id, user_id, query, suggested_user_ids[], model, cost_usd, latency_ms}`
- **Consumers:** Analytics, ai_usage_log, match_feedback (ожидание feedback)

### MatchFeedbackLeft
- **Source:** AI
- **Payload:** `{match_request_id, user_id, suggested_user_id, rating}`
- **Consumers:** Analytics (CSAT матчинга)

### KBQueried
- **Source:** AI
- **Payload:** `{query_id, user_id, query, sources[], model, cost_usd, latency_ms}`
- **Consumers:** Analytics, ai_usage_log

### KBFeedbackLeft
- **Source:** AI
- **Payload:** `{query_id, user_id, rating}`
- **Consumers:** Analytics

### DigestPublished
- **Source:** AI (scheduler понедельник утром)
- **Payload:** `{summary_id, period_start, period_end, top_topics[], cost_usd}`
- **Consumers:** Notifications (рассылка участникам), Analytics

### ChatMessageIndexed
- **Source:** AI (listener-бот)
- **Payload:** `{chat_message_id, kb_chunks_count, embedding_tokens, cost_usd}`
- **Consumers:** Analytics, ai_usage_log

---

## 8. Time Economy context (Phase 3)

### TimeGifted
- **Source:** TimeEconomy
- **Payload:** `{gift_id, giver_id, receiver_id, days, usd_equivalent, is_anonymous, source_subscription_id}`
- **Consumers:** Subscriptions (giver: end_date - days; receiver: end_date + days), Notifications (стороны), Analytics

### DaysBurned
- **Source:** TimeEconomy
- **Payload:** `{burn_id, user_id, days, usd_equivalent, reason}`
- **Consumers:** Subscriptions (списание дней), Notifications, Analytics

### LifetimeBudgetUsed
- **Source:** TimeEconomy
- **Trigger:** lifetime user дарит дни
- **Payload:** `{user_id, year, days_used_now, budget_remaining}`
- **Consumers:** Notifications (счётчик в «Мой доступ»), Analytics

### LifetimeBudgetReset
- **Source:** TimeEconomy (scheduler 1 января)
- **Payload:** `{year, users_count}`
- **Consumers:** Notifications, Analytics

### AdminDayAdjustmentApplied
- **Source:** TimeEconomy
- **Payload:** `{adjustment_id, admin_id, user_id, days_delta, direction, comment, usd_equivalent}`
- **Consumers:** Subscriptions (применить delta), Notifications (пользователю), audit_log, Analytics

---

## 9. Identity / Notifications / Cross-cutting

### UserRegistered
- **Source:** Identity (первое /start в боте)
- **Payload:** `{user_id, telegram_id, username, language_code}`
- **Consumers:** Analytics (events.bot_start)

### UserBlocked / UserUnblocked
- **Source:** Identity (admin action)
- **Payload:** `{user_id, admin_id, reason}`
- **Consumers:** Access (revoke sessions, invite), Notifications, Analytics

### NotificationSent
- **Source:** Notifications
- **Payload:** `{user_id?, channel, template, status, error?}`
- **Consumers:** Analytics, notification_history

---

## Маппинг событий → analytics events таблица

| Domain Event | events.event_name |
|---|---|
| ApplicationSubmitted | `form_submitted` |
| ApplicationApproved | `application_approved` |
| ApplicationRejected | `application_rejected` |
| PaymentInvoiceCreated | `invoice_created` |
| PaymentCompleted | `payment_completed` |
| PaymentFailed | `payment_failed` |
| LatePaymentDetected | `payment_pending_10min` |
| BookingCreated | `interview_booked` |
| BookingNoShow | `interview_no_show` |
| LawAccepted | `law_accepted` |
| InviteIssued | `invite_received` |
| InviteUsed | `invite_used` |
| SubscriptionRenewed | `renewal_completed` |
| RespectGiven | `respect_given` |
| ComplaintFiled | `complaint_filed` |
| MatchRequested | `match_requested` |
| KBQueried | `kb_queried` |
| DigestPublished | `digest_published` |
| TimeGifted | `time_gifted` |
| DaysBurned | `days_burned` |

---

## Контракты consumer'ов (краткий чек-лист)

| Consumer | Подписан на |
|---|---|
| Notifications | Большинство событий — на все «пользовательские» уведомления + admin_chat alerts |
| Analytics (events таблица) | Все domain events → запись в `events` |
| Subscriptions | PaymentCompleted, TimeGifted, DaysBurned, AdminDayAdjustmentApplied, LifetimeGranted, PaymentRefunded |
| Access | ApplicationApproved (FSM), LawAccepted (invite), SubscriptionActivated (invite), UserBlocked (revoke) |
| Calendar | ApplicationApproved (предложить слоты), BookingCancelled (slot → open) |
| AI | RoleAssigned (re-embed), profile updates, ChatMessageIndexed |
| Social | RespectGiven (stars_history), ComplaintResolved |
| TimeEconomy | LifetimeGranted (init budget), SubscriptionRenewed (revalidate gift rules) |

---

*Документ создан: Data Agent | Дата: 2026-05-16*
