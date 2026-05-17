---
title: "Клуб 33 — User Flows (7 эпиков)"
created_by: "UX Agent"
created_at: "2026-05-15"
version: "1.0"
phase: "Design"
---

# User Flows: Клуб 33

User flows для всех 7 эпиков. Тон — на «ты». Каналы: Telegram-бот, mini-app (React+Vite, Telegram WebApp), web-админка.

Легенда:
- `[Actor]` — кто инициирует шаг
- `→` — действие/переход
- `◆` — decision point
- `✕` — выход / drop-off
- `▶` — happy path
- `↺` — повтор / retry

---

## Эпик 1: Воронка (E-FUNNEL) — Phase 1

### Flow F1.1: Подача заявки и модерация

**Акторы:** Кандидат, Бот, Модератор (web-админка), Основатель.
**Entry point:** Telegram `/start` либо deep-link `t.me/club33bot?start=...`.

```
[Кандидат] /start в боте
   ▶ Бот: welcome + кнопки [Подать заявку] [Мой статус] [Поддержка]
   ◆ Кандидат уже подавал заявку?
       ├─ Да  → [Где моя заявка] (вместо «Подать заявку»)
       └─ Нет → ▶
   [Кандидат] нажимает «Подать заявку»
   ▶ Бот: ссылка на Google-форму (внешний URL)
   [Кандидат] заполняет форму (имя, профессия, соцсети, кто пригласил, ожидания)
   ▶ Google → webhook → backend создаёт Application(state=applied)
   ▶ Бот пишет: «Получили твою заявку, на модерации»
   ▶ Уведомление в админ-чат: «Новая заявка от @username, ссылка в админку»
   FSM: applied → screening
   [Модератор/Основатель] открывает заявку в web-админке
   ◆ Решение:
       ├─ Одобрить    → FSM: approved   → Flow F1.2 (интервью)
       ├─ Отказать    → FSM: rejected   → Бот: мягкий отказ (см. US-007)
       └─ В waitlist  → ожидание ручного действия
```

**Edge cases:**
- Повторная подача после rejected: запрещена N месяцев (open decision).
- Незаполненная форма: webhook не приходит — статус остаётся `applied` с пустыми полями; в админке помечается «Форма не заполнена».
- Telegram-username отсутствует — бот просит указать @ для связи.

---

### Flow F1.2: Запись на интервью и интервью

**Акторы:** Кандидат, Бот, Основатель, club33calendar.
**Entry point:** заявка одобрена (FSM=approved).

```
▶ Бот шлёт кандидату: «Прошёл первый фильтр, выбери слот для интервью»
   [Кнопка «Записаться»] → открывает mini-app экран «Слоты»
[Кандидат] выбирает слот в club33calendar
   ▶ Booking создаётся, FSM: approved → awaiting_interview
   ▶ Бот подтверждает: «Записан на DD.MM HH:MM МСК»
   ▶ Cron: напоминание за 24 ч и за 1 ч
   ◆ Перенос / отмена через бот → возврат к выбору слота
[Основатель] проводит интервью
[Основатель] в админке: «Одобрить → к оплате» / «Отказать» / «Lifetime»
   ├─ Approve   → FSM: interview_done → Flow F2.1 (оплата)
   ├─ Reject    → FSM: rejected       → US-007
   └─ Lifetime  → FSM: lifetime_active (минует оплату) → Flow F3.1 (закон + invite)
```

**Edge cases:**
- No-show на интервью → Основатель отмечает «no-show» → reject c пометкой.
- Слотов нет → бот пишет «новые слоты появятся в течение N дней, мы напомним».

---

## Эпик 2: Платежи (E-PAY) — Phase 1

### Flow F2.1: Выбор тарифа и метода оплаты

**Акторы:** Кандидат, Бот, ЮKassa / USDT-провайдер / Support-админ (СБП).
**Entry point:** FSM=interview_done.

```
▶ Бот: «Готов вступить — выбери тариф»
   Карточки: [6 мес — 1000 USD]  [12 мес — 1500 USD]
[Кандидат] выбирает тариф → FSM: → awaiting_payment
▶ Бот: «Как удобно оплатить?»
   Кнопки: [USDT (TRC20/TON)] [ЮKassa (RUB)] [СБП]
◆ Метод:
   ├─ USDT
   │    ▶ Бот: «Сеть?» [TRC20] [TON]
   │    ▶ Backend: создаёт Invoice → возвращает адрес + memo + сумму
   │    ▶ Бот показывает экран инвойса (см. wireframes-bot)
   │    ◆ Webhook от провайдера через ≤10 мин?
   │        ├─ Да  → ▶ Flow F2.2 (подтверждение)
   │        └─ Нет → ▶ через 10 мин показывает [Поддержка]
   │
   ├─ ЮKassa
   │    ▶ Backend: forex API → фиксирует курс USD→RUB → создаёт invoice
   │    ▶ Бот: ссылка на ЮKassa
   │    ▶ После оплаты webhook → Flow F2.2
   │
   └─ СБП
        ▶ Бот: реквизиты + QR + сумма в RUB
        [Кандидат] жмёт «Я оплатил»
        ▶ Уведомление Support-админу в админ-чат
        [Support] подтверждает вручную → Flow F2.2
        ◆ Не подтверждено >24 ч → escalation в админ-чат
```

**Edge cases:**
- Сумма не совпала (USDT/СБП) → late_payment_review → support вручную.
- Webhook задержался >10 мин → кнопка «Поддержка» → диалог.
- Оплата дублём → backend идемпотентность по txid.
- Кандидат >7 дней не оплатил → FSM: expired_unpaid (drop-off).

---

### Flow F2.2: Подтверждение оплаты

```
▶ Backend: Payment(status=completed), Subscription(end_date=now+6m/12m)
▶ AuditLog: payment_completed
▶ Бот: «Платёж получен ✓. Срок подписки — до DD.MM.YYYY»
▶ FSM: awaiting_payment → paid → awaiting_law
▶ Переход к Flow F3.1 (закон клуба)
```

---

### Flow F2.3: Продление подписки

**Акторы:** Участник, Бот, Cron.
**Entry point:** Cron <10 дней до конца subscription / Участник в «Мой доступ → Продлить».

```
[Cron] subscription.end - 10/3/1 day
   ▶ Бот: «До конца подписки X дней» + [Продлить] [Не сейчас]
[Участник] → [Продлить]
   ▶ Шаги F2.1 (выбор тарифа + метод) → F2.2
   ▶ Новая end_date = max(текущая, now) + N месяцев
   ▶ AuditLog: subscription_extended
```

**Edge cases:**
- Lifetime → cron не шлёт напоминания.
- Subscription уже истекла → бот предлагает «Восстановить доступ» (та же оплата).

---

## Эпик 3: Доступ (E-ACCESS) — Phase 1

### Flow F3.1: Закон клуба + Invite

**Акторы:** Участник, Бот.
**Entry point:** FSM=awaiting_law (после оплаты или Lifetime).

```
▶ Бот: текст «Закон клуба» (versioned) + плейсхолдер фразы
▶ Бот: «Чтобы принять, введи фразу: «{phrase_template}» (без кнопки!)»
[Участник] вводит текстом фразу
◆ Точное совпадение (case-insensitive, trim)?
   ├─ Да  → FSM: awaiting_law → onboarding_video
   │       ▶ Бот: «Закон принят ✓. Вот ссылки:»
   │       ▶ Backend: генерирует 2 invite-link (TTL 24ч, limit=1) — канал + чат
   │       ▶ Бот: [Вступить в канал] [Вступить в чат]
   │       ▶ AuditLog: law_accepted, invite_generated
   └─ Нет → ▶ Бот: «попробуй ещё раз» (мягко); attempts++
            ◆ attempts >= 5 → уведомление модератору
```

**Edge cases:**
- Invite истёк (24ч) и не использован → кнопка «Получить ссылку заново» → новая ссылка.
- Кандидат уже в канале/чате → бот пишет «уже в клубе» и показывает «Мой доступ».

---

### Flow F3.2: «Мой доступ» и напоминания

```
[Участник] в боте «Мой доступ» / mini-app «Профиль»
   ▶ Отображается: тариф / срок до DD.MM / [Продлить] / [Поддержка]
   ▶ Lifetime: плашка «Lifetime — без срока», без [Продлить]
[Cron] daily 09:00 МСК
   ▶ Если subscription.end ∈ {-10, -3, -1 day} → push (см. F2.3)
   ▶ Если subscription.end < now → выгнать из канала+чата, FSM: active → grace_period → inactive
```

---

## Эпик 4: Социал (E-SOCIAL) — Phase 2

### Flow F4.1: Дать респект (4 канала)

**Акторы:** Участник, Бот, mini-app.

```
Канал 1: mini-app «Респекты → Дать»
   [Участник] поиск получателя → карточка → [Дать респект] + поле «причина»
   ▶ Backend проверяет: balance ≥ 1 && to_this_user_this_month < 3
   ◆ Лимит OK?
       ├─ Да  → ✓ +1 receiver, -1 sender; tост «Спасибо»; haptic.success
       └─ Нет → disabled кнопка + тост «Баланс 0, вернётся 1 числа» / «Уже 3 в этом месяце»

Канал 2: Бот /respect (reply)
   [Участник] reply на сообщение → /respect [причина]
   ▶ Бот: «✓ Респект отправлен @author»
   ▶ В чат: тихо (без публичного объявления) — анонимность

Канал 3: Карточка в mini-app
   [Участник] открывает чужой профиль → [Дать респект] → как канал 1

Канал 4 (Phase 3): Реакция-стикер 🎩 (или особый emoji)
   [Участник] ставит стикер на сообщение в чате
   ▶ Listener-бот ловит → создаёт Respect → ack-реакция от бота
```

**Edge cases:**
- Сам себе → запрещено, тост «нельзя».
- Получатель — бот / system user → запрещено.
- Сброс 1 числа 00:00 МСК — cron `reset_respect_balances`.

---

### Flow F4.2: Жалоба (анонимная) + модерация

```
[Участник] в mini-app карточка получателя → [Пожаловаться]
   ▶ Форма: причина (select: tone / spam / личное / другое) + текст + «отправить»
   ▶ Backend: Complaint(target_user=X, anonymous_for_target=true)
   ▶ Уведомление модератору в админ-чат: «Новая жалоба, ссылка»
[Модератор] в web-админке «Жалобы → очередь»
   ▶ Карточка: причина, история обоих, кнопки [Подтвердить] [Отклонить] [Эскалировать]
   ◆ Решение → лог + (если confirmed) понижение репутации target
   ▶ Заявителю: «Жалоба рассмотрена» (без раскрытия деталей)
   ▶ Получателю: НИЧЕГО не показываем (анонимность)
```

---

### Flow F4.3: Звёзды (Phase 2)

```
[Cron] еженощно
   ▶ Пересчёт reputation_score по формуле (open decision)
   ▶ Применить деградацию (open decision)
   ▶ Пересчитать stars (0–4) по порогам
   ▶ AuditLog: stars_recalculated
[Участник] открывает профиль → видит ★★★★ + score + tooltip как считать
```

---

## Эпик 5: Время (E-TIME) — Phase 3

### Flow F5.1: Дар времени `/gift`

```
[Даритель] mini-app «Дары → Подарить»
   ▶ Поиск получателя → slider дней (1..max_giftable)
   ▶ max_giftable = subscription.days_left - 30 (для обычных) ИЛИ lifetime_budget_remaining
   ◆ Lifetime?
       ├─ Да   → используется lifetime_yearly_budget (33 дня)
       └─ Нет  → списывается с subscription
   [Подтверждение] → backend: TimeGift(from, to, days)
   ▶ Sender: end_date -= N OR lifetime_used += N
   ▶ Receiver: end_date += N
   ▶ AuditLog: time_gifted

Альтернатива: `/gift @user N` в чате/боте → тот же flow.
```

**Edge cases:**
- subscription.days_left после дарения < 30 → блок, тост «Останется меньше 30 дней».
- Lifetime превысил 33 дня → блок, «Бюджет исчерпан, обнулится 1 января».
- Получатель неактивен/без подписки — нельзя.

---

### Flow F5.2: Сжигание `/burn`

```
[Участник] /burn N или mini-app «Сжечь дни»
   ▶ Подтверждение: «Подарить N дней клубу? Это уменьшит твою подписку»
   [Да] → TimeBurn(user, days), subscription.end_date -= N
   ▶ AuditLog: time_burned
   ▶ Бот: «Спасибо, ты огонь 🔥»
```

---

### Flow F5.3: Админ-конвертер USD ↔ дни (Super)

```
[Super-админ] карточка пользователя в админке → «Начислить / Списать дни»
   ▶ Поле N дней, авто-расчёт USD-эквивалента (1 день = 2.5 USD)
   ▶ Поле комментарий (обязательно)
   [Применить] → AdminDayAdjustment(user, delta, usd, comment, actor)
   ▶ subscription.end_date ± N
   ▶ AuditLog: admin_day_adjustment
```

---

## Эпик 6: AI (E-AI) — Phase 2

### Flow F6.1: `/match`

```
[Участник] /match <запрос> в боте ИЛИ mini-app «Матчинг → Найти»
◆ Профиль (bio, role) заполнен?
   ├─ Нет → подсказка «Заполни bio, чтобы тебя находили» + кнопка [Заполнить]
   └─ Да  → ▶ продолжаем
▶ Backend: embedding запроса (voyage-3) → pgvector top-K → Claude rerank+reasoning
▶ Возврат: 3 карточки участников + объяснение (1-2 предложения)
   Карточка: avatar / имя / роль / ★ / reasoning / [Написать в TG]
▶ Через 1 час: cron → mini-app предлагает оценку (1–5 + комментарий)
   ▶ MatchFeedback сохраняется → метрика match_quality
   ◆ Без downvote (DEC-R-005): только положительная шкала «не пригодилось / нейтрально / помогло»
```

---

### Flow F6.2: `/ask` (KB / RAG)

```
[Участник] /ask <вопрос> в боте ИЛИ mini-app «Спросить»
▶ Backend: embedding → top-K чанков из kb_chunks → Claude генерирует ответ
▶ Возврат: текст ответа + footnotes-источники (ссылки на сообщения)
   [Pattern Perplexity: цифры [1] [2] [3] кликабельны → раскрытие источника]
◆ Релевантных чанков нет?
   └─ «Не нашёл, попробуй переформулировать» + примеры
▶ После ответа: кнопки [Полезно] [Не полезно] (без downvote — нейтрально)
   ▶ KbFeedback → метрика kb_usefulness
```

---

### Flow F6.3: Digest (еженедельный)

```
[Cron] понедельник 09:00 МСК
   ▶ Backend: подготовка корпуса за неделю → Claude summary
   ▶ DailySummary сохраняется
   ▶ Рассылка по подписке (бот) + доступно /digest
[Участник] /digest → последний summary + ссылки на источники
```

---

## Эпик 7: Админка (E-ADMIN) — Phase 1+

### Flow F7.1: Модерация заявок (роль: модератор)

```
[Модератор] /admin/applications
   ▶ Список с фильтрами (status, дата, source)
   ▶ Карточка: данные Google-формы + telegram_id + ссылки соцсетей
   ◆ Кнопки [Одобрить] / [Отказать] / [Waitlist]
   ▶ Каждое действие → FSM-переход → уведомление кандидату
```

### Flow F7.2: Очередь интервью (роль: основатель)

```
[Основатель] /admin/interviews
   ▶ Список booking'ов: дата/время, кандидат, заметки модератора
   ▶ После интервью: [Approve→Pay] [Reject] [Lifetime]
```

### Flow F7.3: Роли / CRUD (модератор)

```
[Модератор] /admin/roles
   ▶ Список ролей + [+ Создать]
   ▶ Форма: name, description, kyc_required (checkbox)
   ▶ В карточке user: dropdown «Роль» — applied на интервью
```

### Flow F7.4: Жалобы (модератор)

```
[Модератор] /admin/complaints?status=open
   ▶ Карточка: причина, текст, target_user (видим модератору), reporter
   ▶ История обоих участников: респекты, прошлые жалобы, активность
   ▶ [Подтвердить] [Отклонить] [Эскалировать super] + комментарий
```

### Flow F7.5: Финансы (super)

```
[Super] /admin/finance
   ▶ Tabs: «Сводка» «Платежи» «Подтверждение СБП» «Возвраты»
   ▶ Сводка: выручка / тарифы / методы / средний чек / LTV / графики
   ▶ Платежи: фильтры по статусу/методу/периоду, [Подтвердить СБП]
   ▶ Late payment review — отдельный таб
```

### Flow F7.6: Воронка (super/модератор)

```
[Admin] /admin/funnel
   ▶ Sankey / bar: bot_start → application → approved → paid → invite_used
   ▶ Drop-off % на каждом шаге, фильтры (период, source)
   ▶ Экспорт CSV
```

### Flow F7.7: AI-дашборд (super)

```
[Super] /admin/ai
   ▶ Виджеты: match_quality (CSAT), kb_usefulness, requests/week, cost USD/week
   ▶ Топ-запросы /match и /ask (агрегированно, без PII)
   ▶ Графики по моделям (haiku/sonnet/opus): tokens, $
```

### Flow F7.8: Конвертер USD↔дни (super only)

```
[Super] карточка user → [Конвертер]
   ▶ Поля: N дней (±), auto USD = N * 2.5, комментарий
   ▶ [Применить] → AdminDayAdjustment
```

### Flow F7.9: Экспорт CSV/Excel

```
[Admin] в любом list-view → [Экспорт ▼] (CSV / Excel)
   ▶ Учитывается текущий фильтр
   ▶ ExportLog запись (actor, dataset, filters, rows)
   ▶ Скачивание файла
```

---

## Сквозные edge cases (все эпики)

| Случай | Поведение |
|---|---|
| Пользователь забанен в Telegram | Бот ловит TelegramAPIError → меток `user_blocked_bot`, админу нотификация |
| Mini-app open без auth | redirect «Открой через бот» (Telegram init_data invalid) |
| Backend down | Бот retry 3x → «Технические работы, попробуй позже» + админу алёрт |
| Двойной клик | Idempotency-key на критичных endpoints (payment, gift, respect) |
| Время сервера vs МСК | Все cron'ы в МСК (Europe/Moscow), хранение UTC |
| Дабл-аккаунт | Detection по telegram_id; модератор может объединить |

---

*Документ создан: UX Agent | Дата: 2026-05-15*
