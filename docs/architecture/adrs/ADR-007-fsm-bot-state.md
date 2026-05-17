---
title: "ADR-007: FSM Bot State"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# ADR-007: FSM Bot State

**Status:** Accepted
**Date:** 2026-05-16
**Author:** Architect Agent

## Контекст

Воронка кандидата (ТЗ §17 + Business-Analyst) предполагает 14 FSM-состояний бота. Состояние нужно сохранять между сессиями и переживать рестарты. aiogram 3.x предлагает Redis storage.

## Решение

### 1. 14 состояний (источник истины — `processes-overview.md` § 4)

```
applied → screening → approved → awaiting_payment → paid →
awaiting_interview → interview_done → awaiting_law →
onboarding_video → active

Параллельные / terminal:
  rejected, expired_unpaid, grace_period, inactive, lifetime_active
```

### 2. Storage стратегия (двойная)

**Hot (Redis) — aiogram FSM storage:**
- Ключ: `aiogram:fsm:{user_id}` — текущее состояние + temporary data (например, выбранный тариф до оплаты).
- TTL: 7 дней (если пользователь молчит).
- Используется dispatcher'ом aiogram для маршрутизации хендлеров.

**Cold (Postgres) — `users.fsm_state`:**
- Поле `users.fsm_state` (CharField, choices = 14 states).
- Обновляется атомарно с Redis при transition.
- Источник истины при рестарте Redis и для долгосрочной аналитики (воронка).

### 3. Transition pattern

```python
async def transition(user_id, from_state, to_state, event_data=None):
    # 1. Verify current state matches from_state (optimistic concurrency)
    user = await User.objects.aget(id=user_id)
    if user.fsm_state != from_state:
        raise InvalidStateTransition(...)

    # 2. Update Postgres (transaction)
    await User.objects.filter(id=user_id, fsm_state=from_state).aupdate(
        fsm_state=to_state,
        fsm_updated_at=now()
    )

    # 3. Update Redis (aiogram storage)
    await fsm_storage.set_state(user_id, to_state)

    # 4. Audit + publish event
    AuditLogService.log_event('fsm_transition', data={
        'from': from_state, 'to': to_state, 'event_data': event_data
    }, actor=user)
    publish_event(FsmTransitioned(user_id, from_state, to_state))
```

### 4. Allowed transitions table

Декларативно описано (`access_control/fsm_rules.py`):

```python
ALLOWED_TRANSITIONS = {
    'applied':            ['screening', 'rejected'],
    'screening':          ['approved', 'rejected'],
    'approved':           ['awaiting_payment', 'rejected'],
    'awaiting_payment':   ['paid', 'expired_unpaid'],
    'paid':               ['awaiting_interview'],
    'awaiting_interview': ['interview_done', 'rejected'],
    'interview_done':     ['awaiting_law', 'rejected'],
    'awaiting_law':       ['onboarding_video', 'rejected'],
    'onboarding_video':   ['active'],
    'active':             ['grace_period', 'lifetime_active'],
    'grace_period':       ['active', 'inactive'],
    'inactive':           ['active'],  # после повторной оплаты
    'lifetime_active':    [],  # terminal-ish (можно blocked)
    'expired_unpaid':     ['awaiting_payment', 'rejected'],
    'rejected':           [],  # terminal
}
```

Любая попытка перехода вне списка → `InvalidStateTransition` + log.

### 5. Cold-restart procedure

При рестарте Redis (потеря FSM hot-state):
```
1. Worker job: rebuild_fsm_cache
2. Для каждого user с fsm_state in [active states list]:
   restore aiogram state from users.fsm_state
```

### 6. Audit

Каждый transition → AuditLog (для воронки и debugging).

### 7. Phase 2+: расширения

- Substates (например, `active.idle`, `active.engaged`) для NSM Engaged Active Paid Members (ADR-008) — реализуется отдельным полем `engagement_state`, не FSM.
- Возврат из `inactive` через повторную оплату — допустимо (см. таблицу).

## Альтернативы

| Альтернатива | Почему отклонена |
|---|---|
| Только Redis | Потеря FSM при рестарте; нет аналитики воронки |
| Только Postgres | aiogram нативно работает с Redis; lookup на каждом message — медленно |
| FSM как state machine library (transitions, django-fsm) | django-fsm устарел; aiogram FSM достаточно |
| Event sourcing | Overkill для MVP; будущая опция |

## Последствия

- Production-grade FSM, переживает рестарты.
- Прозрачная воронка через AuditLog + users.fsm_state.
- Атомарность через optimistic concurrency.
- Простое добавление новых состояний.

## Связанные документы

- `processes-overview.md` § 4 (карта 14 состояний)
- `information-architecture.md` § 1.3 FSM
- `dependency-rules.yaml` — `access_control` имеет FsmState

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
