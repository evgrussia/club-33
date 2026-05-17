---
title: "Funnel Definition — Клуб 33"
created_by: "Analytics Agent"
created_at: "2026-05-15"
version: "1.0"
phase: "Discovery"
---

# Funnel Definition — Клуб 33

Структурированное описание главной воронки клуба и вспомогательных под-воронок. Для каждого шага указаны: триггер-событие, метрики, целевая конверсия в следующий шаг, среднее время прохождения и типичные причины drop-off.

---

## 1. Главная воронка (Acquisition → Active Member)

```
[1] bot_start
    ↓
[2] apply_clicked
    ↓
[3] form_submitted             (Google Form)
    ↓
[4] application_approved       (модератор/админ)
    ↓
[5] payment_completed          (USDT / СБП / ЮKassa)
    ↓
[6] interview_booked           (club33calendar)
    ↓
[7] interview_attended         (verdict: accepted)
    ↓
[8] law_accepted               (ручной ввод фразы)
    ↓
[9] invite_used                (target=channel)
    ↓
   ACTIVE MEMBER
```

### Расширенный вид с под-этапами оплаты

```
[4] application_approved
    ↓
    payment_screen_opened
    ↓
    tariff_selected
    ↓
    payment_method_selected
    ↓
    invoice_created
    ↓
[5] payment_completed
```

### Таблица конверсий и параметров

| # | Шаг | Триггер-событие | Target conv. → next | Avg time → next | Ключевые drop-off |
|---|-----|-----------------|---------------------|-----------------|-------------------|
| 1 | Start | `bot_start` | 40% → apply | <5 min | не интересно, спам-трафик, не понял оффер |
| 2 | Apply intent | `apply_clicked` | 60% → form | <30 min | страх длинной формы, не открыл ссылку |
| 3 | Application | `form_submitted` | 30% → approved | 12–48h (модерация) | модераторская очередь, медленный ручной разбор |
| 4 | Approval | `application_approved` | 70% → payment | <72h | сомнения, цена, поиск способа оплаты |
| 5 | Payment | `payment_completed` | 95% → interview | <24h | webhook задержка, забыл записаться |
| 6 | Interview booked | `interview_booked` | 85% → attended | 0–14 days до слота | no-show, перенос, забыл напоминание |
| 7 | Interview done | `interview_attended` (accepted) | 95% → law | <1h | основатель отклонил после интервью |
| 8 | Law accepted | `law_accepted` | 98% → invite | <5 min | непонимание фразы, опечатки |
| 9 | Channel joined | `invite_used` | — | <10 min | TTL invite истёк, не успел нажать |

### End-to-end target conversion

> **bot_start → ACTIVE MEMBER** ≈ `0.40 * 0.60 * 0.30 * 0.70 * 0.95 * 0.85 * 0.95 * 0.98 * 1.0 ≈ 3.8%`
>
> При апсайде по апруву (35%) и удержании всех остальных конверсий — до **~4.5%**.

### Метрики каждого этапа

| Этап | Метрика | Расчёт |
|------|---------|--------|
| 1→2 | Apply Rate | `apply_clicked / bot_start` |
| 2→3 | Form Submit Rate | `form_submitted / apply_clicked` |
| 3→4 | Approval Rate | `approved / submitted` |
| 4→5 | Payment Conversion | `payment_completed / approved` |
| 5→6 | Booking Rate | `interview_booked / payment_completed` |
| 6→7 | Show Rate | `interview_attended / interview_booked` |
| 7→8 | Law Acceptance | `law_accepted / accepted_interview` |
| 8→9 | Invite Activation | `invite_used / invite_received` |

### Причины drop-off — детально

| Этап | Причина | Действие команды |
|------|---------|------------------|
| 1→2 | Бот не объясняет ценность | Перепроверить welcome-копию (Content Agent) |
| 2→3 | Длинная форма Google | Сократить поля, заранее показать сколько займёт |
| 3→4 | Очередь модерации | Уведомить админов, SLA <48h |
| 4→5 | Высокая цена, нет нужного способа | Reminder-сообщение через 24h, поддержка |
| 5→6 | Не пришло уведомление о бронировании | Авто-напоминание после `payment_completed` |
| 6→7 | No-show | Reminder за 24h и 1h до слота |
| 7→8 | Сомнения после интервью | Personal follow-up основателя |
| 8→9 | TTL invite истёк | Recovery-flow: запросить новый invite |

---

## 2. Sub-funnel: Renewal (Продление)

```
[R1] subscription approaching (days_left ≤ 10)
     ↓ (auto reminder в боте)
[R2] renewal_started           (нажал «Продлить»)
     ↓
     tariff_selected
     ↓
     payment_method_selected
     ↓
     invoice_created
     ↓
[R3] renewal_completed         (payment_completed, is_renewal=true)
```

| # | Шаг | Триггер | Target conv. → next | Avg time |
|---|-----|---------|---------------------|----------|
| R1 | Reminder shown | reminder scheduler | 50% → renewal_started | <72h |
| R2 | Renewal started | `renewal_started` | 80% → completed | <1 day |
| R3 | Renewal done | `renewal_completed` | — | — |

> **Overall renewal rate target**: `0.50 * 0.80 = 40%` от всех подписок, у которых ≤10 дней до конца. С учётом запасных reminders и продлений в день истечения — фактический target **≥60%**.

### Drop-off renewal

| Этап | Причина |
|------|---------|
| R1→R2 | Reminder не доставлен / прочитан, нет финансов сейчас |
| R2→R3 | Передумал, отвлёкся, проблема с оплатой |

### Метрика истёкших без продления

`subscription_expired` без последующего `renewal_completed` в окне +7 дней → Churn.

---

## 3. Sub-funnel: AI Engagement (Фаза 2)

### 3.1 Matching funnel

```
mini-app open → match_requested → results shown → match_clicked → contact action
```

| # | Шаг | Метрика | Target |
|---|-----|---------|--------|
| 1 | Открыл вкладку «Матчинг» | mini-app session event | — |
| 2 | Запросил матч | `match_requested` | — |
| 3 | Открыл матч | `match_clicked` | CTR ≥15% |
| 4 | Связался с матчем | tracking через chat (опционально, P3) | мониторинг |

### 3.2 KB funnel

```
kb_query → answer shown → kb_answer_useful (useful=true / false)
```

| # | Шаг | Метрика | Target |
|---|-----|---------|--------|
| 1 | Задал вопрос | `kb_query` | — |
| 2 | Получил ответ с chunks | `retrieved_chunks > 0` | ≥90% |
| 3 | Отметил полезность | `kb_answer_useful` | rate marking ≥30% |
| 4 | Положительная оценка | `useful=true` | recall ≥70% |

### 3.3 Digest funnel

```
digest_sent → digest_opened → click on item
```

| # | Шаг | Метрика | Target |
|---|-----|---------|--------|
| 1 | Отправлен | `digest_sent` | — |
| 2 | Открыт | `digest_opened` (unique users) | open rate ≥50% |
| 3 | Клик внутри | `digest_opened.click_target` not null | CTR ≥30% |

---

## 4. Sub-funnel: Time Economy (Фаза 3)

### 4.1 Gift funnel

```
профиль другого участника → "Подарить дни" → выбор количества → подтверждение → gift_sent
```

| Шаг | Метрика |
|-----|---------|
| Открытие диалога дарения | mini-app event |
| Подтверждение | `gift_sent` |
| Reciprocal action | следующий `gift_sent` от получателя в течение 30 дней (опционально) |

### 4.2 Burn funnel

```
"Сжечь дни" → подтверждение → days_burned
```

Простая транзакционная воронка, ключевая метрика — общий объём `burns_volume`.

---

## 5. Inverse funnel: Churn / Inactivity

Обратная воронка — сигналы оттока:

```
last_activity > 30 days
    ↓
stars_changed (trigger=inactivity)
    ↓
subscription_expired (без renewal)
    ↓
left_channel (опц., если можем отследить)
```

### Метрики раннего предупреждения

| Сигнал | Окно | Действие |
|--------|------|----------|
| 0 сообщений в чате за 14 дней | в реал-тайме | мягкий reminder бот |
| 0 респектов выдано за месяц | месяц | reminder про активность |
| 0 открытий digest за 4 недели | 4 недели | personal follow-up community |
| `subscription_expired` без renewal | 7 дней после | win-back сообщение |

---

## 6. Визуализация в админке

Раздел **Финансы / Воронка** в web-админке должен отображать:

1. **Sankey diagram** главной воронки за выбранный период (день / неделя / месяц).
2. **Таблица конверсий** с подсветкой шагов, где conversion < target.
3. **Time-series** для NSM (Active Paid Members) и Revenue по дням.
4. **Cohort analysis**: процент renewals по когортам первой оплаты.
5. **Drop-off heatmap**: по дням недели и часам — где теряем больше всего.

CSV/Excel экспорт по каждому слою (ТЗ §22.11).

---

## 7. Соответствие ТЗ §22.8

ТЗ требует трекать три ключевые конверсии:

| ТЗ требование | Реализация в плане |
|---------------|---------------------|
| `bot_start → payment_completed` | Шаги 1→5 главной воронки (multiplikativ) |
| `approved → payment_completed` | Шаг 4→5 (Payment Conversion) |
| `payment_completed → invite_used` | Шаги 5→9 главной воронки |

Все три значения должны быть на главном дашборде Founder.

---

*Документ создан: Analytics Agent | Дата: 2026-05-15*
