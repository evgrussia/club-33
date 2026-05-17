---
title: "ADR-005: club33calendar — собственный модуль"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# ADR-005: club33calendar

**Status:** Accepted
**Date:** 2026-05-16
**Author:** Architect Agent

## Контекст

DEC-009 фиксирует: разрабатываем своё решение `club33calendar` в Phase 1. Календарь нужен только для одной поверхности — запись на интервью с Основателем. Не нужен полнофункциональный календарь (нет series-events, нет sharing, нет invite-managers).

## Решение

### 1. Минимальный domain

```python
TimeSlot:
    id, founder_user_id, start_at (UTC), duration_min (default 30),
    status: open | reserved | done | cancelled,
    created_by_admin, notes

Booking:
    id, slot_id (FK), candidate_user_id (FK users), application_id (FK),
    status: confirmed | cancelled | no_show | done,
    created_at, cancelled_reason, no_show_marked_by

Reminder:
    id, booking_id (FK), scheduled_at, channel (bot/email),
    sent_at, status: pending | sent | failed
```

### 2. Source of slots

- Super-админ / основатель создаёт слоты в admin UI (Phase 1).
- Слоты — конкретные времена (не правила recurrence в MVP).
- Phase 2 опционально: правила (например, "каждый вторник 19:00-21:00").

### 3. Flow брони

```
Application.status = approved + payment_confirmed
  ↓
Bot: "Выбери слот интервью" → /book команда
  ↓
Mini-app экран "Выбор слота" (или inline-кнопки в боте)
  ↓
POST /api/v1/calendar/bookings → создаёт Booking, slot.status=reserved
  ↓
Worker: создаёт Reminder за 24ч, 1ч, 15мин до слота
  ↓
В назначенное время основатель проводит интервью
  ↓
Founder/Admin отмечает: done | no_show | cancelled
  ↓
Если done → событие InterviewCompleted (в FSM applications → interview_done)
```

### 4. Cron-напоминалки (worker)

```
job: send_interview_reminders
schedule: каждые 15 минут
logic: SELECT reminders WHERE scheduled_at <= now AND status='pending'
         → отправляем через notifications context
         → mark sent
```

### 5. Timezone

- Слоты хранятся в UTC.
- Отображение пользователю — в его TZ (с Telegram getMe нет TZ, fallback МСК для MVP).
- Phase 2: запросить TZ при онбординге.

### 6. Fallback на Calendly

Если разработка не успевает к Phase 1 deadline (определит Coder в Phase 6) — временно интеграция через Calendly webhook → создание Booking. Архитектурно адаптер `CalendarAdapter` (как payments).

## Альтернативы

| Альтернатива | Почему отклонена |
|---|---|
| Calendly как primary | DEC-009 предпочитает свой модуль; меньше внешних зависимостей |
| Google Calendar API | Сложная OAuth-схема для одного основателя; не нужно |
| cal.com (open source) | Деплой + поддержка отдельного приложения — overhead для MVP |
| iCal генерация | Только для экспорта, не для booking flow |

## Последствия

- Полный контроль UX (вписывается в стиль mini-app).
- Минимум функциональности — минимум багов.
- Расширяемо: легко добавить интервью с модераторами в Phase 2+.
- Адаптер позволяет fallback на Calendly без рефакторинга.

## Связанные документы

- DEC-009
- `dependency-rules.yaml` (calendar → core, users, applications)
- `funnel-process.md` (Business-Analyst)

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
