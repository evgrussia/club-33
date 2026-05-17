---
title: "ADR-002: Bounded Contexts «Клуба 33»"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# ADR-002: Bounded Contexts

**Status:** Accepted
**Date:** 2026-05-16
**Author:** Architect Agent

## Контекст

В Phase 5.5 (DDD Agent Generation) система генерирует DDD-агентов на основе bounded contexts. Архитектор обязан зафиксировать список контекстов, их сущности, контракты и связи. Preview из `system-adaptation-summary` содержит 10 кандидатов — этот ADR финализирует 13 контекстов.

## Решение — 13 bounded contexts

### 1. Identity & Access (`users`)

- **Цель:** аутентификация, идентификация, базовый RBAC.
- **Сущности:** `User`, `TelegramAccount`, `Session`, `Role` (super/moderator/support), `Permission`, `RefreshToken`.
- **Контракты:**
  - publishes: `UserRegistered`, `UserAuthenticated`
- **Связи:** база для всех контекстов (`allowed_imports: [core]`).

### 2. Applications (`applications`)

- **Цель:** заявки кандидатов, скрининг, статусы.
- **Сущности:** `Application` (FSM-связана), `ScreeningNote`, `RejectionReason`.
- **Контракты:**
  - publishes: `ApplicationSubmitted`, `ApplicationApproved`, `ApplicationRejected`
  - consumes: `InterviewBooked` (из calendar)
- **Связи:** Google Forms webhook → `applications`.

### 3. Payments (`payments`)

- **Цель:** инвойсы, провайдеры, webhook, fx_rate.
- **Сущности:** `Invoice`, `Payment`, `PaymentMethod` (USDT/ЮKassa/СБП), `WebhookEvent`, `FxRateSnapshot`, `LatePaymentReview`.
- **Контракты:**
  - publishes: `InvoiceCreated`, `PaymentConfirmed`, `PaymentFailed`, `UnderpaidDetected`
  - consumes: `RenewalRequested` (subscriptions)
- **Ключевое:** идемпотентность webhook по `external_id`. См. ADR-004.

### 4. Subscriptions (`subscriptions`)

- **Цель:** тарифы 6/12 мес, lifetime, продление, напоминания.
- **Сущности:** `Tariff`, `Subscription`, `RenewalReminder`, `LifetimeAssignment`.
- **Контракты:**
  - publishes: `SubscriptionActivated`, `SubscriptionExpiringSoon`, `SubscriptionExpired`, `LifetimeGranted`
  - consumes: `PaymentConfirmed`, `DaysGifted`, `DaysBurned`

### 5. Access Control (`access_control`)

- **Цель:** invite-ссылки, FSM бота, закон клуба, доступ в канал/чат.
- **Сущности:** `InviteLink` (TTL, limit=1), `FsmState`, `LawAcceptance`.
- **Контракты:**
  - publishes: `LawAccepted`, `InviteLinkIssued`, `AccessRevoked`
  - consumes: `SubscriptionActivated`, `SubscriptionExpired`

### 6. Calendar (`calendar`)

- **Цель:** club33calendar — слоты основателя, бронирование интервью, напоминалки. (DEC-009)
- **Сущности:** `TimeSlot`, `Booking`, `Reminder`.
- **Контракты:**
  - publishes: `InterviewBooked`, `InterviewCancelled`, `InterviewReminder`
- **Связи:** только с `applications` и `users`.

### 7. Social (`social`)

- **Цель:** роли (ниши), респекты, звёзды, жалобы.
- **Сущности:** `Role`, `UserRoleAssignment`, `Respect` (30/мес, 3 на получателя), `ReputationScore`, `StarLevel`, `Complaint` (анонимная).
- **Контракты:**
  - publishes: `RespectGiven`, `ComplaintFiled`, `StarLevelChanged`, `RoleAssigned`
- **Особенности:** монтirly reset 1 числа 00:00 МСК (worker).

### 8. Time Economy (`time_economy`)

- **Цель:** дар времени, сжигание, lifetime-бюджет, конвертер USD→дни.
- **Сущности:** `GiftTransaction`, `BurnTransaction`, `LifetimeBudget` (33 дня/год), `AdminConversion`.
- **Контракты:**
  - publishes: `DaysGifted`, `DaysBurned`, `LifetimeBudgetUsed`
  - consumes: ничего (но читает `subscriptions`)
- **Условие:** даритель имеет ≥30 дней после дарения.

### 9. AI Services (`ai_services`)

- **Цель:** матчинг, RAG (KB), digest, embeddings, model router.
- **Сущности:** `Embedding`, `KbDocument`, `MatchResult`, `KbAnswer`, `DigestRecord`, `AiUsageLog`, `MatchFeedback`, `KbFeedback`.
- **Контракты:**
  - publishes: `DigestGenerated`, `MatchProduced`
  - consumes: `RespectGiven` (сигнал для quality), `MessageIndexed` (от listener)
- **Связи:** только READ от других контекстов; WRITE только в свои таблицы (DR-005).

### 10. Notifications (`notifications`)

- **Цель:** отправка уведомлений (bot, admin chat, email опц.).
- **Сущности:** `NotificationTemplate`, `NotificationLog`, `Channel` (bot/admin_chat/email).
- **Контракты:**
  - consumes: почти все события из других контекстов

### 11. Admin & Finance (`admin_dashboard`)

- **Цель:** CRUD-агрегатор, финансы, воронка, экспорт, дашборды.
- **Сущности:** Views + DTO над сущностями других контекстов; `Export` (record), `DashboardSnapshot`.
- **Связи:** допустимый импорт почти всех контекстов (см. dependency-rules.yaml).
- **Особенность:** RBAC-обусловленный доступ (DEC-005).

### 12. Listener (`listener`)

- **Цель:** индексация сообщений чата клуба → embeddings.
- **Сущности:** `MessageIndex`, `IndexCheckpoint`.
- **Контракты:**
  - publishes: `MessageIndexed`
- **Связи:** только пишет в `ai_services` (DR-004).

### 13. Audit (`audit`)

- **Цель:** AuditLog (rule 04).
- **Сущности:** `AuditLog` (action, category, actor, entity, data_masked, request_id, timestamp).
- **Связи:** базовый сервис, импортируется всеми (через core).

## Mapping → Django apps

13 контекстов = 13 Django apps + общий `core` + `audit`. Список:

```
backend/
  core/
  audit/
  users/                 # Identity & Access
  applications/
  payments/
  subscriptions/
  access_control/
  calendar/              # club33calendar
  social/                # roles, respects, stars, complaints
  time_economy/
  ai_services/
  notifications/
  admin_dashboard/
  listener/
```

## Альтернативы

| Альтернатива | Почему отклонена |
|---|---|
| 1 монолитный app | Нет границ для DDD-агентов (Phase 5.5); хаос на масштабе |
| Микросервисы | Команда мала, latency, операционная сложность — overkill для MVP |
| Объединить Social + Time Economy | Разные жизненные циклы и лимиты; намеренно разделены |
| Calendar внутри Applications | DEC-009 явно фиксирует club33calendar как отдельный модуль |
| Audit как часть core | Отдельный app для миграций/индексов и retention policy (rule 04) |
| Admin Dashboard как frontend-only | Нужны серверные агрегации, экспорт, RBAC — отдельный app |

## Последствия

- Каждый контекст получит свой Container CLAUDE.md в Phase 5.5.
- Контракты между контекстами реализуются через события (publish/subscribe внутри API — Django signals или custom event bus).
- Listener изолирован — переезд в отдельный процесс не ломает остальное.

## Связанные документы

- `dependency-rules.yaml` — граф allowed_imports
- `workspace.dsl` — C4 модель
- `.claude/rules/09-ddd-agent-generation.md` — будущая Phase 5.5

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
