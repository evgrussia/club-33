---
title: "Клуб 33 — Threat Model (STRIDE)"
created_by: "Security Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# Threat Model «Клуб 33» (STRIDE)

STRIDE-моделирование угроз по каждому bounded context. Для каждой угрозы указаны категория, impact, likelihood и конкретные mitigations (actionable, не абстрактные).

**Легенда STRIDE:** S — Spoofing, T — Tampering, R — Repudiation, I — Information Disclosure, D — Denial of Service, E — Elevation of Privilege.

**Шкала:** Impact (high/medium/low) — масштаб ущерба; Likelihood (high/medium/low) — вероятность.

---

## 1. Identity & Access (JWT mini-app, Telegram init_data, sessions)

### T-IA-01 — Подделка Telegram init_data (Spoofing)
- **STRIDE:** S
- **Description:** Атакующий формирует init_data вручную, выдавая себя за другого Telegram-пользователя при логине в mini-app.
- **Impact:** high (захват аккаунта участника, доступ к KYC/чату/респектам).
- **Likelihood:** medium.
- **Mitigation:**
  - Серверная валидация init_data по HMAC-SHA256 от bot_token (Telegram WebApp spec).
  - Проверка `auth_date` — не старше 86400 сек (24 ч); конфиг через env `MINIAPP_INIT_DATA_TTL`.
  - При невалидной подписи — 401 + `AuditLogService.log_event('miniapp_init_data_invalid', ...)`.
  - Бан IP после 10 неудачных попыток за 5 мин (Redis rate limit).

### T-IA-02 — Кража / replay JWT (Tampering + Spoofing)
- **STRIDE:** S, T
- **Impact:** high. **Likelihood:** medium.
- **Mitigation:**
  - Access JWT TTL = 15 мин; refresh — 7 дней, rotation on use.
  - HS512 + секрет в Vault (см. secrets-management.md), длина ≥ 64 байта.
  - Хранение JWT в mini-app — только в памяти (не localStorage), refresh — httpOnly cookie SameSite=Strict (если возможно для WebApp; иначе secure storage Telegram API).
  - `jti` claim + Redis-блэклист на logout/смена пароля админа.

### T-IA-03 — Brute force админ-логина (Elevation of Privilege)
- **STRIDE:** E, S
- **Impact:** critical (доступ к Super-роли).
- **Likelihood:** medium.
- **Mitigation:**
  - Django Axes / rate-limit 5 попыток/15 мин на учётку.
  - Обязательный 2FA (TOTP) для всех админ-ролей (Super/Mod/Support).
  - CAPTCHA после 3 неудачных попыток.
  - Уведомление в админ-чат при подозрительном входе (новый IP/geo).

### T-IA-04 — Session fixation в web-админке (Spoofing)
- **STRIDE:** S
- **Impact:** high. **Likelihood:** low.
- **Mitigation:** регенерация session_id при логине; SESSION_COOKIE_SECURE=True; SESSION_COOKIE_HTTPONLY=True; SESSION_COOKIE_SAMESITE='Lax'.

### T-IA-05 — Отказ в обслуживании на auth-endpoints (DoS)
- **STRIDE:** D
- **Mitigation:** Rate limit 30 req/min на `/api/v1/auth/*` per IP; глобальный 1000 req/min на admin login.

---

## 2. Applications (Google-форма данные, скрининг)

### T-AP-01 — Подделка заявки от чужого Telegram (Spoofing)
- **STRIDE:** S
- **Impact:** medium (заспам скрининг-очереди, попытка обхода модерации).
- **Likelihood:** medium.
- **Mitigation:**
  - Связка `application.telegram_user_id` устанавливается ТОЛЬКО ботом после `/start` (init_data валидирована).
  - Google-форма заполняется по уникальному pre-token, который бот выдаёт на `/start` (одноразовый, TTL 24 ч).
  - При импорте формы webhook от Google Apps Script подписан HMAC; токен сверяется с pre-token.

### T-AP-02 — Изменение данных заявки после подачи (Tampering)
- **STRIDE:** T, R
- **Impact:** medium. **Likelihood:** low.
- **Mitigation:**
  - Иммутабельные `application.raw_data` (JSONField, write-once); правки только через `application.notes` с автором.
  - `AuditLogService.log_db_update(application, old_values=..., actor=...)` на любые изменения статуса/полей.

### T-AP-03 — Раскрытие персональных данных кандидата (Info Disclosure)
- **STRIDE:** I
- **Impact:** high (152-ФЗ). **Likelihood:** medium.
- **Mitigation:**
  - RBAC: только модератор+ видит заявки (DEC-005).
  - Логирование доступа: `AuditLogService.log_event('application_viewed', ...)`.
  - Маскирование email/phone в списках, полное раскрытие — только на детальной карточке.
  - При экспорте CSV — отдельный лог `application_exported` с perimeter.

### T-AP-04 — Отказ модератора от факта решения (Repudiation)
- **STRIDE:** R
- **Mitigation:** все `screening_decision` логируются с actor_id, IP, user-agent. Read-only AuditLog.

---

## 3. Payments (USDT, ЮKassa, СБП — детально в payments-security.md)

### T-PM-01 — Webhook spoofing (USDT/ЮKassa) — Spoofing/Tampering
- **STRIDE:** S, T
- **Impact:** critical (бесплатная подписка).
- **Likelihood:** high (без mitigation).
- **Mitigation:** HMAC проверка подписи на каждом webhook; IP-whitelist для ЮKassa; см. payments-security.md.

### T-PM-02 — Replay webhook (Tampering/EoP)
- **STRIDE:** T, E
- **Impact:** high. **Likelihood:** medium.
- **Mitigation:** idempotency через `payment.external_id UNIQUE` + nonce + timestamp ±5 мин.

### T-PM-03 — Underpaid / Overpaid фрод
- **STRIDE:** T, E
- **Mitigation:** допуск ±0.5% по сумме; underpaid → не зачисляется, очередь review; overpaid → Super-decision.

### T-PM-04 — Late payment (оплата после expired)
- **STRIDE:** T, E
- **Mitigation:** автоматический отказ при `now > invoice.expires_at`; ручное review Super-админом.

### T-PM-05 — Отказ от факта оплаты / возврата (Repudiation)
- **STRIDE:** R
- **Mitigation:** AuditLog на все статусы invoice, payment, refund; раз в день — резервная выгрузка журнала в immutable storage (S3 + Object Lock).

### T-PM-06 — Курсовая манипуляция (Tampering)
- **STRIDE:** T
- **Impact:** medium (платит меньше).
- **Mitigation:** `invoice.invoice_rate_snapshot` write-once; источник — ЦБ РФ; нельзя изменить никому (см. RBAC матрицу `payment-process.md` §6).

### T-PM-07 — Логирование секретов в открытом виде (Info Disclosure)
- **STRIDE:** I
- **Mitigation:** `AUDIT_MASKED_FIELDS` включает `yookassa_secret`, `signature`, `webhook_token`. Тест: snapshot AuditLog не содержит масок-полей.

---

## 4. Subscriptions (продление, lifetime)

### T-SB-01 — Бесконечное продление через подделанный webhook
- **STRIDE:** S, E
- **Mitigation:** см. T-PM-01..03.

### T-SB-02 — Изменение `subscription.end_date` напрямую (EoP)
- **STRIDE:** E, T
- **Mitigation:** запрет UPDATE на `end_date` через DRF; только через `SubscriptionService.extend(invoice)` или Super-конвертер с AuditLog.

### T-SB-03 — Выдача lifetime не-Super (EoP)
- **STRIDE:** E
- **Mitigation:** permission_class `IsSuperAdmin` на endpoint; двойной confirm в админке (textual confirm "ВЫДАТЬ LIFETIME @username"); AuditLog.

---

## 5. Access Control (invite-ссылки, закон клуба)

### T-AC-01 — Утечка invite-ссылки (Info Disclosure / EoP)
- **STRIDE:** I, E
- **Impact:** high (посторонний в чате).
- **Likelihood:** medium.
- **Mitigation:**
  - TTL 24 ч (настраивается, не больше 72 ч).
  - `member_limit=1` в Telegram createChatInviteLink.
  - При первой активации — revoke немедленно (Telegram API revokeChatInviteLink).
  - Привязка ссылки к user_id; если зашёл другой Telegram ID — kick из чата, alert.

### T-AC-02 — Обход «закона клуба» через прямой API-вызов
- **STRIDE:** E
- **Mitigation:** FSM-валидация на сервере: invite генерируется только при `fsm_state == 'onboarding_video'` после `law_accepted_at IS NOT NULL`. AuditLog `law_accepted` с raw текстом фразы и timestamp.

### T-AC-03 — Подделка фразы согласия (Tampering)
- **STRIDE:** T
- **Mitigation:** сервер хранит эталонную фразу (env `LAW_ACCEPTANCE_PHRASE`); сравнение точное (с normalize whitespace + lowercase). Эталон неизменен без миграции.

---

## 6. Social (респекты, жалобы, анонимность)

### T-SC-01 — Накрутка респектов через несколько аккаунтов (EoP)
- **STRIDE:** E
- **Mitigation:**
  - Лимиты: 30/мес отправителю, 3 на одного получателя.
  - Server-side проверка через `RespectService.give(from, to)`.
  - Anti-collusion: alert если 2 аккаунта взаимно дают max-лимит респектов (graph cycle detection еженедельно).

### T-SC-02 — Деанонимизация жалобы (Info Disclosure)
- **STRIDE:** I
- **Impact:** high (раскрытие жалобщика).
- **Likelihood:** medium.
- **Mitigation:**
  - `complaint.reporter_id` доступен ТОЛЬКО Super-админу; модератор видит `reporter_id IS NULL` в выдаче.
  - Отдельный API serializer `ComplaintAnonymizedSerializer` для модератора.
  - В уведомлении получателю жалобы — только тема и решение, без атрибуции.
  - AuditLog `complaint_reporter_disclosed` при любом доступе Super к reporter_id.

### T-SC-03 — Spam-жалобы для дискредитации участника (Tampering / DoS)
- **STRIDE:** T, D
- **Mitigation:** rate-limit 3 жалобы/день на reporter; auto-flag при >5 жалоб на одного receiver за 7 дней.

### T-SC-04 — XSS в респект-комментарии (Tampering)
- **STRIDE:** T
- **Mitigation:** DOMPurify в mini-app; на сервере — `bleach.clean` со whitelist (только текст, без HTML); CSP `default-src 'self'`.

---

## 7. Time Economy (дары, конвертер админа)

### T-TE-01 — Дар отрицательного / fractional количества дней (Tampering/EoP)
- **STRIDE:** T, E
- **Mitigation:** валидация `amount_days > 0 AND amount_days == int(amount_days) AND amount_days <= sender.remaining_days - 30` на server-side.

### T-TE-02 — Race condition в `/gift` (двойное списание)
- **STRIDE:** T
- **Impact:** medium. **Likelihood:** medium.
- **Mitigation:** транзакция `SELECT FOR UPDATE` на `subscription` отправителя; idempotency-key в API (`Idempotency-Key` header, TTL 24 ч).

### T-TE-03 — Админ-конвертер: фрод (Super произвольно начисляет дни)
- **STRIDE:** E, R
- **Mitigation:**
  - Каждое начисление через конвертер — обязательный комментарий `reason`.
  - AuditLog `admin_convert_usd_to_days` с `actor`, `target_user`, `amount`, `reason`.
  - Алерт в админ-чат при сумме > $500 эквивалент.
  - Ежемесячный отчёт Founder по всем операциям Super.

---

## 8. AI Services (промпты, KB, embeddings, чат-индексация) — детально в ai-security.md

### T-AI-01 — Prompt injection через профиль/жалобу/чат-сообщение
- **STRIDE:** T
- **Impact:** high (утечка system-prompt, кросс-юзер data).
- **Likelihood:** high.
- **Mitigation:** см. ai-security.md §Prompt injection.

### T-AI-02 — Утечка PII в RAG-ответах
- **STRIDE:** I
- **Mitigation:** PII redaction перед embedding (см. ai-security.md).

### T-AI-03 — Cost-DoS (атакующий тратит inference-бюджет)
- **STRIDE:** D
- **Mitigation:** rate-limit `/match`, `/ask` (5/час на user); per-user daily cost cap (USD).

### T-AI-04 — Data poisoning KB через индексацию чата
- **STRIDE:** T
- **Mitigation:** индексация только после `law_accepted_at`; opt-out флаг; модератор может удалить chunks.

---

## 9. Calendar (бронирование интервью)

### T-CA-01 — Бронь слота без права (EoP)
- **STRIDE:** E
- **Mitigation:** permission: только `fsm_state == 'paid'`; не более 1 активной brони на user.

### T-CA-02 — Двойное бронирование одного слота (Race / Tampering)
- **STRIDE:** T
- **Mitigation:** UNIQUE constraint на `(slot_id, status='active')`; транзакция с `SELECT FOR UPDATE`.

### T-CA-03 — Спам отмена/перебронь (DoS)
- **STRIDE:** D
- **Mitigation:** максимум 2 reschedule на user.

---

## 10. Admin & Finance (RBAC по DEC-005)

### T-AD-01 — Превышение полномочий: модератор инициирует возврат (EoP)
- **STRIDE:** E
- **Mitigation:** permission_class `IsSuperAdmin` на refund endpoint; см. RBAC матрицу.

### T-AD-02 — Утечка финансовых данных (Info Disclosure)
- **STRIDE:** I
- **Mitigation:** Finance dashboard скрыт за `IsSuperAdmin`; AuditLog `finance_dashboard_viewed`.

### T-AD-03 — Modификация AuditLog для сокрытия следов (Tampering/R)
- **STRIDE:** T, R
- **Mitigation:**
  - AuditLog — read-only в Django Admin (рул 04-logging.md), удаление только superuser БД.
  - Ежедневный дамп AuditLog в WORM-хранилище (S3 Object Lock 90 дней или MinIO с retention).
  - Сравнение PG-журнала с резервной копией еженедельно.

### T-AD-04 — CSV/Excel экспорт всех данных (Info Disclosure)
- **STRIDE:** I
- **Mitigation:** ограничение объёма экспорта в одну операцию (1000 rows), AuditLog `data_exported` с filters, alert в админ-чат.

### T-AD-05 — Атака на CRUD ролей (изменение прав Super) — EoP
- **STRIDE:** E
- **Mitigation:**
  - Запрет на изменение `is_superuser` / `role='super'` через API; только через Django shell с двойным confirm.
  - Алерт при любой попытке UPDATE на admin role/permissions.

---

## Сводная таблица: количество угроз

| Bounded Context | Spoofing | Tampering | Repudiation | InfoDisclosure | DoS | EoP | Всего |
|---|---|---|---|---|---|---|---|
| Identity & Access | 3 | 1 | 0 | 0 | 1 | 1 | 5 |
| Applications | 1 | 1 | 1 | 1 | 0 | 0 | 4 |
| Payments | 2 | 5 | 1 | 1 | 0 | 3 | 7 |
| Subscriptions | 1 | 1 | 0 | 0 | 0 | 2 | 3 |
| Access Control | 0 | 1 | 0 | 1 | 0 | 2 | 3 |
| Social | 0 | 2 | 0 | 1 | 1 | 1 | 4 |
| Time Economy | 0 | 2 | 1 | 0 | 0 | 2 | 3 |
| AI Services | 0 | 2 | 0 | 1 | 1 | 0 | 4 |
| Calendar | 0 | 1 | 0 | 0 | 1 | 1 | 3 |
| Admin & Finance | 0 | 1 | 1 | 2 | 0 | 2 | 5 |
| **Итого** | **7** | **17** | **3** | **7** | **3** | **14** | **41** |

(угрозы посчитаны с учётом множественной классификации; реальное число записей — 41)

---

## Top-5 Critical Risks (требуют блокирующего mitigation до Phase 6)

1. **T-PM-01 Webhook spoofing** — без HMAC проверки возможна бесплатная подписка. Без mitigation Phase 6 не стартует.
2. **T-AI-01 Prompt injection** — system-prompt отделить от user-input; output filter обязателен.
3. **T-SC-02 Деанонимизация жалобы** — нарушение базового социального контракта клуба.
4. **T-IA-03 Brute force админа** — захват Super-роли = доступ ко всему. 2FA обязателен.
5. **T-AC-01 Утечка invite-ссылки** — посторонний в закрытом чате. Bind to user_id + revoke after first use.

---

*Документ создан: Security Agent | Дата: 2026-05-16*
