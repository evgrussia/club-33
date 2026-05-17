---
title: "Metrics Framework — Клуб 33"
created_by: "Analytics Agent"
created_at: "2026-05-15"
version: "1.0"
phase: "Discovery"
---

# Metrics Framework — Клуб 33

Структура метрик по группам с привязкой к фазам релиза. Метрики делятся на:

- **North Star Metric (NSM)** — главная метрика здоровья продукта.
- **Operational metrics** — оперативные (дашборд админки, real-time).
- **Strategic metrics** — стратегические (ежемесячный/квартальный отчёт).

**North Star Metric проекта**: **Active Paid Members** — количество участников, у которых на текущий момент активная оплаченная подписка ИЛИ статус lifetime, и которые присоединились по invite-ссылке к каналу и чату.

> Формула NSM:
> `NSM = COUNT(users WHERE access_status='active' AND joined_channel_at IS NOT NULL)`

---

## Группа 1 — Acquisition & Funnel (Фаза 1)

Метрики приёма заявок и прохождения воронки.

| Метрика | Определение | Формула | Owner | Target | Частота |
|---------|-------------|---------|-------|--------|---------|
| **Funnel Entry** | Уникальные `bot_start` (новые) | `COUNT(DISTINCT tg_user_id WHERE is_returning=false)` | Analytics | — | day / week |
| **Apply Rate** | % `apply_clicked` от `bot_start` | `apply_clicked / bot_start` | Product | ≥40% | week |
| **Form Submit Rate** | % `form_submitted` от `apply_clicked` | `form_submitted / apply_clicked` | Product | ≥60% | week |
| **Approval Rate** | % `application_approved` от `form_submitted` | `approved / submitted` | Founder | 20–40% | week |
| **Approval Time (avg)** | Среднее время от `form_submitted` до `application_approved` | `AVG(decision_time)` | Admin team | <48h | week |
| **Payment Conversion** | % `payment_completed` от `application_approved` | `payment_completed / approved` | Product | ≥70% | week |
| **Payment Confirmation Time (avg)** | Среднее от `invoice_created` до `payment_completed` | `AVG(confirmation_seconds)` | Backend | <10 min (USDT/ЮKassa) | week |
| **Payment Failure Rate** | % `payment_failed` от `invoice_created` | `failed / created` | DevOps | <10% | week |
| **Interview Show Rate** | % `interview_attended` от `interview_booked` | `attended / booked` | Founder | ≥85% | week |
| **Law Acceptance Rate** | % `law_accepted` от `interview_attended` (accepted) | `law_accepted / accepted_interview` | Product | ≥95% | week |
| **Invite Activation Rate** | % `invite_used` (target=channel) от `invite_received` | `invite_used / received` | Bot | ≥90% | week |
| **Drop-off per Step** | % пользователей, не перешедших на следующий шаг | `1 - conv_rate(step_i, step_i+1)` | Analytics | — | week |
| **Avg Time Between Steps** | Среднее время на каждом шаге воронки | `AVG(t_step_i+1 - t_step_i)` | Analytics | — | week |

---

## Группа 2 — Revenue & Financial (Фаза 1+)

Финансовые показатели и выручка.

| Метрика | Определение | Формула | Owner | Target | Частота |
|---------|-------------|---------|-------|--------|---------|
| **Total Revenue** | Сумма всех `amount_usd` оплат | `SUM(payment_completed.amount_usd)` | Founder | — | day / month |
| **Revenue by Month** | Выручка по календарным месяцам | `SUM(amount_usd) GROUP BY month` | Founder | — | month |
| **Revenue by Tariff** | Доля по тарифам m6 / m12 / lifetime | `SUM(amount_usd) GROUP BY tariff_code` | Product | — | month |
| **Revenue by Method** | Доля USDT / СБП / ЮKassa | `SUM(amount_usd) GROUP BY method` | DevOps | — | month |
| **Average Order Value (AOV)** | Средний чек платежа | `AVG(amount_usd)` | Product | — | month |
| **MRR (Monthly Recurring Revenue)** | Нормализованный месячный доход от подписок (без lifetime) | `SUM(tariff_monthly_value WHERE active)` | Founder | растёт m/m | month |
| **ARPU** | Средний доход на активного участника | `Total Revenue / Active Paid Members` | Founder | — | month |
| **New Revenue** | Выручка от новых платящих (`is_renewal=false`) | `SUM WHERE is_renewal=false` | Marketing | — | month |
| **Renewal Revenue** | Выручка от продлений (`is_renewal=true`) | `SUM WHERE is_renewal=true` | Product | — | month |
| **Refund Rate** | % возвратов (если реализуется) | `refunded / completed` | DevOps | <2% | month |
| **FX Spread** | Расхождение курса USD→RUB на момент оплаты vs текущий | `(now_rate - snapshot_rate) / snapshot_rate` | Backend | мониторинг | month |

---

## Группа 3 — Retention & Renewal (Фаза 1+)

Удержание и продления подписок.

| Метрика | Определение | Формула | Owner | Target | Частота |
|---------|-------------|---------|-------|--------|---------|
| **Renewals Count** | Общее число `renewal_completed` за период | `COUNT(renewal_completed)` | Product | — | month |
| **Renewal Rate (overall)** | % продливших от тех, у кого истёк период | `renewed / (renewed + expired)` | Product | ≥60% | month |
| **Renewal Rate by Tariff** | Отдельно для m6 и m12 | разрез по `current_tariff` | Product | m6:≥55%, m12:≥70% | month |
| **Churn Rate** | % `subscription_expired` без `renewal_completed` в окне 7 дней после | `expired_no_renew / total_expiring` | Founder | ≤40% | month |
| **Time to Renewal** | Среднее время от `renewal_started` до `renewal_completed` | `AVG(t_completed - t_started)` | Bot | <1 day | month |
| **Reminder CTR** | % кликнувших «Продлить» из reminder-сообщения | `renewal_started{trigger=reminder} / reminder_sent` | Bot | ≥50% | month |
| **Active Paid Members** | NSM — активные платящие + lifetime | формула NSM выше | Founder | растёт m/m | week |
| **Lifetime Members** | Кол-во пользователей с тарифом lifetime | `COUNT WHERE tariff=lifetime` | Founder | — | month |

---

## Группа 4 — LTV (Фаза 1+)

Долгосрочная ценность участника.

| Метрика | Определение | Формула | Owner | Target | Частота |
|---------|-------------|---------|-------|--------|---------|
| **Total Revenue per User** | Сумма оплат пользователя за всё время | `users.total_revenue` (поле в БД) | Backend | — | per user |
| **Avg LTV** | Средний LTV по всем активным | `AVG(total_revenue)` | Founder | растёт q/q | quarter |
| **LTV by Acquisition Cohort** | LTV по месяцу первой оплаты | `AVG(total_revenue) GROUP BY first_payment_month` | Marketing | — | quarter |
| **LTV by Tariff (entry)** | LTV в разрезе первоначального тарифа | `AVG(total_revenue) GROUP BY first_tariff` | Product | lifetime >> m12 >> m6 | quarter |
| **LTV/CAC** | LTV к стоимости привлечения (когда появится CAC) | `Avg LTV / Avg CAC` | Marketing | >3 | quarter |
| **Months to Payback** | Среднее число месяцев до окупаемости CAC | `CAC / (ARPU * margin)` | Marketing | <12 | quarter |

---

## Группа 5 — Social (Фаза 2)

Социальный слой: респекты, жалобы, репутация, активность.

| Метрика | Определение | Формула | Owner | Target | Частота |
|---------|-------------|---------|-------|--------|---------|
| **Respects per User per Month** | Среднее число выданных респектов на активного участника | `SUM(respect_given.amount) / active_members / month` | Community | ≥10 | month |
| **Respect Distribution** | Кол-во получателей у среднего пользователя в месяц | `AVG(DISTINCT to_user GROUP BY from_user, month)` | Community | ≥5 | month |
| **Respect Balance Utilization** | % использованного лимита 30/мес | `given_total / 30` | Product | 40–80% | month |
| **Complaints per Month** | Жалобы поданные | `COUNT(complaint_filed) per month` | Moderation | — | month |
| **Complaints Resolution Time** | Среднее время от подачи до закрытия | `AVG(time_to_resolve_hours)` | Moderation | <72h | month |
| **Confirmed Complaint Rate** | % `complaint_resolved` с `resolution IN (confirmed, warning, ban)` | `confirmed / total` | Moderation | мониторинг | month |
| **Avg Stars** | Средние звёзды по активным | `AVG(user_roles.stars WHERE active)` | Founder | ≥2.5 | month |
| **Stars Distribution** | Распределение по 0/1/2/3/4★ | `COUNT GROUP BY stars` | Founder | — | month |
| **Star Drops by Inactivity** | Кол-во `stars_changed` с `trigger=inactivity` | `COUNT WHERE trigger=inactivity` | Product | — | month |
| **Active Social Members** | Участники с ≥1 респектом за месяц (выдали или получили) | `COUNT(DISTINCT user WHERE has_respect_in_month)` | Community | ≥70% от NSM | month |
| **Roles Coverage** | % участников с назначенной ролью | `COUNT(WHERE role_id IS NOT NULL) / NSM` | Founder | ≥80% | month |

---

## Группа 6 — AI (Фаза 2)

Метрики AI-сервисов: матчинг, KB, digest, расходы на inference.

| Метрика | Определение | Формула | Owner | Target | Частота |
|---------|-------------|---------|-------|--------|---------|
| **Match Requests** | Кол-во `match_requested` | `COUNT(match_requested)` | AI | — | week |
| **Match CTR** | % `match_clicked` от показанных результатов | `match_clicked / (match_requested * AVG(results_count))` | AI | ≥15% | week |
| **Match Quality (subjective)** | Доля положительных отметок «полезно» после клика | через follow-up опрос или флаг в UI | AI | ≥60% | month |
| **KB Queries** | Кол-во `kb_query` | `COUNT` | AI | — | week |
| **KB Recall (useful rate)** | % `kb_answer_useful` с `useful=true` от всех отметок | `useful_true / total_marked` | AI | ≥70% | month |
| **KB Coverage** | Доля запросов с ненулевым `retrieved_chunks` | `COUNT WHERE retrieved_chunks>0 / total` | AI | ≥90% | month |
| **KB Latency p95** | 95-й перцентиль latency | `PERCENTILE(latency_ms, 0.95)` | AI / DevOps | <5s | week |
| **Digest Open Rate** | % `digest_opened` от audience | `unique_openers / audience_size` | Product | ≥50% | week |
| **Digest CTR** | % кликов внутри digest | `clicks / opens` | Product | ≥30% | week |
| **Inference Cost / Day** | Сумма `cost_usd` из `ai_usage_log` | `SUM(cost_usd)` | DevOps | budget-cap | day |
| **Cost per User per Month** | Расход на AI на активного участника | `SUM(cost_usd) / NSM / month` | Founder | ≤$2 | month |
| **Cost per Feature** | Разрез расходов по `feature` | `SUM(cost_usd) GROUP BY feature` | AI | match≤40%, kb≤30%, digest≤20% | month |
| **Cost per Model** | По `model` (haiku / sonnet / opus / embedding) | `SUM(cost_usd) GROUP BY model` | AI | оптимизация | month |
| **Avg Tokens per Request** | По feature | `AVG(tokens_in+tokens_out) GROUP BY feature` | AI | — | week |

---

## Группа 7 — Time Economy (Фаза 3)

Дары, сжигание, lifetime-бюджет.

| Метрика | Определение | Формула | Owner | Target | Частота |
|---------|-------------|---------|-------|--------|---------|
| **Gifts Volume (days)** | Сумма подаренных дней | `SUM(gift_sent.days)` | Community | — | month |
| **Gifts Count** | Кол-во операций дарения | `COUNT(gift_sent)` | Community | — | month |
| **Unique Gift Donors** | Уникальные `from_user_id` | `COUNT(DISTINCT from_user_id)` | Community | ≥20% NSM | month |
| **Avg Gift Size** | Средний размер подарка в днях | `AVG(days)` | Community | — | month |
| **Burns Volume (days)** | Сумма сожжённых дней | `SUM(days_burned.days)` | Community | — | month |
| **Burn Reasons Distribution** | Категории `reason` | `COUNT GROUP BY reason` | Community | — | month |
| **Lifetime Budget Utilization** | % использования годового бюджета 33 дня по lifetime-пользователям | `AVG(budget_used / 33)` | Founder | мониторинг | quarter |
| **Reaction Respect Volume** | Респекты, выданные через стикер-реакцию | `COUNT(reaction_respect)` | Community | — | month |
| **Admin Day Adjustments** | Ручные корректировки конвертера | `SUM(days_delta)`, `SUM(usd_equivalent)` | Super-admin | мониторинг | month |
| **Days→USD Equivalent Flow** | USD-эквивалент всего движения дней | `SUM(days * 2.5)` | Founder | — | month |

---

## Группа 8 — Operational Health (все фазы)

Технические метрики, не для роста, но для здоровья системы.

| Метрика | Определение | Owner | Target |
|---------|-------------|-------|--------|
| **Bot Errors / Hour** | Кол-во ошибок в логах бота | DevOps | <10 |
| **API p95 Latency** | 95-й перцентиль API | DevOps | <500ms |
| **Webhook Delivery Success** | % успешных webhook USDT/ЮKassa | DevOps | ≥99% |
| **Manual SBP Reconciliation Lag** | Среднее время ручной сверки СБП | Support | <4h |
| **Scheduler Job Failures** | Кол-во провалившихся job (digest, balance, reminders) | DevOps | 0 |

---

## Дашборды (предложение)

### Founder Dashboard (ежедневно)
- NSM (Active Paid Members)
- Total Revenue (день / месяц)
- Funnel snapshot
- Pending applications, pending interviews
- Pending complaints

### Product Dashboard (еженедельно)
- Воронка с конверсиями и drop-off
- Renewal Rate / Churn
- LTV by cohort

### AI Dashboard (еженедельно, Фаза 2+)
- Match CTR, KB Recall, Digest Open Rate
- Inference Cost / Day / Feature / Model
- Cost per User

### Moderation Dashboard (реал-тайм)
- Очередь жалоб
- SLA по жалобам

---

## Owner-карта

| Команда | Метрики, за которые отвечают |
|---------|------------------------------|
| Founder | NSM, Revenue, MRR, LTV, Active Paid Members, Avg Stars |
| Product | Funnel rates, Renewal Rate, Digest Open Rate, Reminder CTR |
| Community | Respects, Complaints (объём), Gifts, Burns |
| Moderation | Complaints Resolution Time, Confirmed Complaint Rate |
| AI | Match CTR, KB Recall, Inference cost optimization |
| DevOps | Payment Failure Rate, API Latency, Inference Cost cap |
| Marketing | LTV by cohort, LTV/CAC, New Revenue |

---

*Документ создан: Analytics Agent | Дата: 2026-05-15*
