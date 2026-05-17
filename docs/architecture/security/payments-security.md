---
title: "Клуб 33 — Payments Security"
created_by: "Security Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# Payments Security

Детальный набор мер для защиты платёжного контура: USDT (TRC20/TON), ЮKassa, СБП. Базируется на `docs/discovery/business/payment-process.md`.

---

## 1. Webhook signature verification

### 1.1 ЮKassa (HMAC)

ЮKassa подписывает webhook заголовком (см. их docs) либо проверяет через идемпотентный ключ + GET-проверка платежа. Гибридная схема:

**Алгоритм:**
1. При получении POST на `/api/v1/webhooks/yookassa/`:
   - Проверить `Content-Type: application/json`.
   - Извлечь raw body (не parsed).
   - Если поставщик прислал заголовок подписи (например, `X-Yookassa-Signature`): вычислить `HMAC-SHA256(body, secret_from_vault)` и сравнить через `hmac.compare_digest` (constant-time).
   - **Дополнительно (defense-in-depth):** перед началом обработки сделать GET `/v3/payments/{payment_id}` в ЮKassa API с Basic Auth (shopId:secret) и проверить статус и сумму на стороне ЮKassa. Только при совпадении — считать платёж валидным.
2. При невалидной подписи: 401, `AuditLogService.log_event('webhook_signature_invalid', data={'provider': 'yookassa', 'ip': ...}, level='CRITICAL')`, алерт в админ-чат.

**IP-whitelist:**
```
allowed_ips = [
  '185.71.76.0/27', '185.71.77.0/27', '77.75.153.0/25',
  '77.75.154.128/25', '77.75.156.11/32', '77.75.156.35/32',
]
```
Проверять `X-Forwarded-For` (от nginx) + `REMOTE_ADDR`. Запрос вне whitelist → 403 + alert.

### 1.2 USDT-провайдер

Провайдер выбирается в Phase 5 (Architect). Требования к интеграции:
- Поддержка signature header (HMAC-SHA256 или EdDSA).
- IP-whitelist у нас и/или mTLS со стороны провайдера.
- Возможность GET-проверки статуса транзакции по хэшу.

**Алгоритм:**
1. Извлечь signature header (имя зависит от провайдера).
2. `HMAC-SHA256(body + nonce + timestamp, secret_from_vault)`.
3. Проверка `|now - timestamp| < 300` сек (5 мин, защита от replay).
4. Сверка через RPC-вызов в blockchain node провайдера: `getTransactionByHash(tx_hash)` — статус, сумма, confirmations.
5. **N confirmations:** для TRC20 ≥ 20, для TON ≥ 32 (финализируется Architect).

### 1.3 СБП — без webhook

СБП в нашей схеме (Phase 1) — ручная сверка Support-админом. Меры безопасности:
- Support-админ авторизуется через 2FA в админке.
- Подтверждение СБП требует ввода суммы и комментария из выписки банка (защита от автоматизации).
- AuditLog `sbp_payment_confirmed` с `actor`, `invoice_id`, `bank_reference`.
- Опционально (Phase 2+): интеграция с банковским API для авто-сверки.

---

## 2. Idempotency

### Структура

```
payments_invoice:
  id BIGSERIAL PK
  external_id VARCHAR(128) UNIQUE NOT NULL  -- USDT-memo / yookassa_payment_id / sbp-comment
  status VARCHAR(32)
  amount_usd NUMERIC(10,2)
  amount_rub NUMERIC(12,2)
  invoice_rate_snapshot NUMERIC(10,4)
  ...

payments_webhook_log:
  id BIGSERIAL PK
  provider VARCHAR(32)
  external_id VARCHAR(128)
  nonce VARCHAR(64)
  body_hash VARCHAR(64)  -- SHA-256 body для точного де-дупа
  received_at TIMESTAMPTZ
  processed BOOLEAN
  UNIQUE(provider, external_id, nonce)
```

### Алгоритм

1. Перед обработкой webhook — `INSERT INTO payments_webhook_log` с UNIQUE constraint. Если violation → `payment_duplicate_webhook`, return 200 OK (idempotent).
2. Внутри транзакции (`SELECT ... FOR UPDATE`):
   - Найти `invoice` по `external_id`.
   - Если `status != 'awaiting_payment'` → return 200 OK без изменений (защита от двойной обработки + race).
   - Иначе — обработать (status → paid, продлить subscription, AuditLog).
3. Outbound side-effects (Telegram notify) — после commit транзакции, через outbox-pattern (для at-least-once без двойных уведомлений).

### API Idempotency-Key (для `/gift`, refund)

- Заголовок `Idempotency-Key: uuid4()` обязателен.
- TTL 24 часа в Redis, value = response_hash + status_code.
- При повторе с тем же ключом — возврат закешированного ответа.

---

## 3. Replay attacks

**Защита:**
- **Timestamp**: для USDT-провайдера — заголовок `X-Timestamp` (если поддерживает); проверка `|now - ts| ≤ 300` сек.
- **Nonce**: одноразовый идентификатор в webhook (если провайдер шлёт). Сохраняется в `payments_webhook_log.nonce` с UNIQUE.
- **External_id**: всегда UNIQUE; повторный webhook с тем же external_id игнорируется.
- **TLS**: всегда HTTPS, никаких HTTP endpoints для webhooks.

---

## 4. Anti-fraud правила

### 4.1 USDT (TRC20 / TON)

| Правило | Значение / Mitigation |
|---|---|
| Допуск по сумме | ±0.5% (BA-decision); вне допуска → underpaid/overpaid review |
| Confirmations TRC20 | ≥ 20 (финализируется Architect) |
| Confirmations TON | ≥ 32 (финализируется Architect) |
| Wrong network | TRC20 на TON address и наоборот → невозможно по адресу, но провайдер должен явно валидировать chain |
| Sanctioned addresses | OFAC-screening (если провайдер поддерживает); опционально Phase 2 |
| Memo обязателен | Если без memo — invoice не сопоставляется; алерт Support |

### 4.2 ЮKassa

| Правило | Mitigation |
|---|---|
| IP-whitelist | См. §1.1 |
| Двойная сверка через API | GET `/v3/payments/{id}` после webhook |
| Превышение rate | Bot rate limit 10 invoices/min на user |
| 3DS | Включено по умолчанию у ЮKassa; не отключаем |

### 4.3 СБП

| Правило | Mitigation |
|---|---|
| Уникальный комментарий | `K33-{invoice_id}-{short_hash}` обязателен |
| Без комментария | Инцидент, ручной разбор Support |
| Подделка скриншота | Запрещено принимать «скрин оплаты» — только реальный приход в банк |

---

## 5. PCI DSS scope

**Мы НЕ храним cardholder data.** Платёж картой:
- ЮKassa hosted payment page (redirect). Карточные данные вводятся на стороне ЮKassa, не у нас.
- Получаем только: `payment_id`, `status`, `amount`, `created_at`, `payment_method` (тип, last4 — опционально).
- **Scope:** SAQ-A (минимальный), если используем только redirect / iframe от ЮKassa.

**Обязательные меры даже для SAQ-A:**
- TLS на всех страницах, ведущих к payment.
- Не логировать `payment_method.card.number` (даже если в payload пришёл).
- HSTS, secure cookies.

---

## 6. Edge cases

### 6.1 Late payment (оплата после `expires_at`)

```
Webhook → проверка expires_at:
  if now > invoice.expires_at:
    invoice.status = 'late_payment_review'
    AuditLog.log_event('late_payment_received', ...)
    Алерт Super-админу
    return 200  # принимаем webhook, но НЕ продлеваем подписку автоматически
```

**Решение Super:**
- Принять → продлить subscription, начислить дни от now (не от старой даты).
- Вернуть → инициировать refund.

### 6.2 Underpaid (сумма < expected − 0.5%)

```
invoice.status = 'payment_underpaid'
AuditLog.log_event('payment_underpaid', data={'received': x, 'expected': y})
Notify плательщика: "Получено X, нужно Y. Доплати или напиши в поддержку."
```
Решение Support: закрыть, попросить доплату, частичный refund.

### 6.3 Overpaid (сумма > expected + 0.5%)

```
invoice.status = 'payment_overpaid'
Super-decision:
  - Зачесть избыток в дни (1 день = 2.5 USD)
  - Вернуть разницу
```

### 6.4 Дубликат платежа (двойной webhook)

Сработает UNIQUE constraint в `payments_webhook_log` → 200 OK + лог.

### 6.5 Webhook invalid signature

```
401/403 ответ провайдеру.
AuditLog.log_event('webhook_signature_invalid', level='CRITICAL')
Alert админ-чат.
Increment Prometheus counter `webhook_signature_invalid_total{provider=...}`.
Если >10 за 5 мин → блокировка IP в Nginx + page Security.
```

---

## 7. Refund policy

**Phase 1 — не определена бизнесом.** Рекомендация Security:
- Default: non-refundable после подтверждения оплаты (стандарт закрытых клубов).
- Исключения: техническая ошибка (overpaid, late_payment) — refund по решению Super.
- Refund инициируется только Super-админом из админки.
- Logging: `log_business('refund_initiated', actor, target_user, amount, reason, provider_refund_id)`.
- USDT-refund: ручной обратный перевод; Super вводит tx_hash после отправки.
- ЮKassa-refund: API `/v3/refunds` с idempotency-key.
- Все refund > $500 — обязательное согласование с Founder (двойной confirm в админке).

**Recommendation to Product:** оформить refund policy до Phase 6 (юридическое требование 152-ФЗ ст. 18.1 и ЗоЗПП).

---

## 8. RBAC матрица (из payment-process.md §6)

| Действие | Super | Mod | Support |
|---|---|---|---|
| Видеть все инвойсы | ✅ | ✅ | ✅ |
| Подтвердить СБП | ✅ | ❌ | ✅ |
| Подтвердить late_payment | ✅ | ❌ | ❌ |
| Подтвердить overpaid | ✅ | ❌ | ❌ |
| Подтвердить underpaid | ✅ | ❌ | ✅ |
| Инициировать возврат | ✅ | ❌ | ❌ |
| Изменить курс | ❌ | ❌ | ❌ |
| Видеть `webhook_log` raw | ✅ | ❌ | ❌ |

Реализация: DRF `permission_classes` + Django `permissions` framework. Тесты — `tests/test_payments_rbac.py` (минимум 8×3 = 24 теста).

---

## 9. Логирование

Обязательные события:
- `payment_invoice_created` (Invoice CRUD)
- `webhook_received` (provider, external_id, hash)
- `webhook_signature_invalid` (CRITICAL)
- `payment_completed`
- `payment_underpaid` / `payment_overpaid`
- `late_payment_received`
- `payment_duplicate_webhook`
- `refund_initiated` / `refund_completed`
- `sbp_payment_confirmed` (manual)
- `admin_payment_override` (любое ручное изменение Super)

Маскируются: `signature`, `webhook_token`, `yookassa_secret`, `card_number`, `cvv`, `usdt_provider_api_key`.

---

## 10. Чеклист для Coder Agent

При реализации payments:
- [ ] Webhook view проверяет HMAC через `hmac.compare_digest`.
- [ ] IP-whitelist (для ЮKassa).
- [ ] `payments_webhook_log` UNIQUE check перед обработкой.
- [ ] `SELECT FOR UPDATE` на invoice внутри транзакции.
- [ ] Допуск ±0.5% по сумме.
- [ ] Late/under/overpaid — разные ветки.
- [ ] AuditLog на каждый шаг.
- [ ] Маскирование секретов.
- [ ] Тесты: replay, double-spend, invalid signature, race, edge cases.
- [ ] Outbound notify через outbox pattern (после commit).

---

*Документ создан: Security Agent | Дата: 2026-05-16*
