---
title: "ADR-004: Payments Architecture"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# ADR-004: Payments Architecture

**Status:** Accepted
**Date:** 2026-05-16
**Author:** Architect Agent

## Контекст

Платежи — критический модуль. Три способа: USDT (TRC20/TON), ЮKassa (RUB карта), СБП (RUB, ручная сверка). Курс USD→RUB фиксируется на момент создания инвойса (DEC-010). SLA подтверждения 5-10 мин. Возможны underpaid/overpaid (особенно USDT).

## Решение

### 1. Унифицированный InvoiceService с адаптерами

```
                  ┌─────────────────────┐
                  │   InvoiceService    │
                  └──────────┬──────────┘
       ┌─────────────────────┼─────────────────────┐
       ▼                     ▼                     ▼
  YooKassaAdapter      USDTAdapter         SBPManualHandler
       │                     │                     │
       ▼                     ▼                     ▼
   ЮKassa API     USDT TRC20/TON провайдер   Ручная сверка support
```

Каждый адаптер реализует общий интерфейс:
```python
class PaymentAdapter(Protocol):
    def create_invoice(amount_usd: Decimal, currency: str) -> InvoiceCreated: ...
    def verify_webhook(payload, signature) -> bool: ...
    def parse_webhook(payload) -> WebhookEvent: ...
```

### 2. Идемпотентность webhook (КРИТИЧНО)

```
1. Webhook приходит → router извлекает external_id
2. Redis SETNX idempotency:{provider}:{external_id} = locked, TTL 24h
3. Если уже locked → возвращаем 200 OK без обработки (защита от ретраев)
4. Если новый → транзакционно обрабатываем + записываем WebhookEvent
5. На каждом этапе AuditLog
```

### 3. Forex rate snapshot (DEC-010)

```
Создание инвойса (RUB):
  rate = ForexRateService.get_usd_to_rub()  # с кэшем 1ч в Redis
  invoice.fx_rate_snapshot = rate
  invoice.amount_rub = round(amount_usd * rate, 2)
  invoice.fx_source = "cbr_rf"
  invoice.fx_timestamp = now()

При повторном создании инвойса (продление) → новый snapshot.
Сравнение/отчётность — всегда против snapshot, не "сегодняшнего" курса.
```

### 4. Underpaid / Overpaid (USDT) — ±0.5% tolerance

```
expected = invoice.amount_usd
received = webhook.amount_usd
delta = (received - expected) / expected

if abs(delta) <= 0.005:  # 0.5%
    accept_as_paid()
elif delta > 0.005:
    create_overpaid_record()  # уведомление, ручная разбор
    accept_as_paid() (с пометкой)
else:  # underpaid
    create_underpaid_record()
    notify_user("оплата меньше ожидаемой, разница X$")
    create_late_payment_review()  # support принимает решение
```

### 5. Late payment review

Если оплата приходит после `awaiting_payment` истёк (FSM expired_unpaid) — НЕ автоматически активируем. Создаём `LatePaymentReview` для support-админа: восстановить или вернуть.

### 6. Status machine

```
Invoice.status: created → pending → confirmed | failed | expired | underpaid | overpaid
Payment.status: pending → confirmed | failed | refunded
```

### 7. Безопасность

- Webhook signature verification обязательна (HMAC). Без подписи → 401, не обрабатываем.
- Все секреты (API keys, webhook secrets) — env vars (FF-010).
- AuditLog для каждого: invoice_created, payment_confirmed, payment_failed, manual_override.

### 8. Manual SBP confirmation flow

```
User → выбирает СБП → InvoiceService.create_invoice(method=SBP)
                       → отображает реквизиты + сумму RUB (по snapshot)
                       → invoice.status = pending
User делает перевод (вне системы)
User → "я оплатил" в боте → invoice.user_marked_paid = True + admin notification
Support-админ → admin UI → подтверждает → invoice.status = confirmed
                                       → PaymentConfirmed event
```

## Альтернативы

| Альтернатива | Почему отклонена |
|---|---|
| Один общий webhook endpoint без adapter pattern | Сложно расширять; нет инкапсуляции провайдерных особенностей |
| Сохранять курс на момент платежа (а не инвойса) | DEC-10 явно требует на момент инвойса; справедливо для пользователя |
| Tolerance 1% | Слишком много — стоит $10+ на каждом инвойсе |
| Auto-refund overpaid | На MVP — ручная разборка; auto — позже |
| Stripe / PayPal | Не в скоупе MVP (out: оплата зарубежной картой) |

## Последствия

- Расширение: добавить нового провайдера = новый Adapter + конфигурация.
- Тестируемость: каждый адаптер мокается отдельно.
- Безопасность: централизованная идемпотентность и подписи.
- Аудит: каждая операция в AuditLog.

## Связанные документы

- `docs/architecture/c4-diagrams.md` § Payments
- `dependency-rules.yaml` (payments → core, users)
- DEC-010 (USD→RUB rate)

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
