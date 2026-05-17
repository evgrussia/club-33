---
title: "ADR-009: Дефолты для blockers Phase 6 (юридические + tech-выборы)"
created_by: "Orchestrator Agent"
created_at: "2026-05-17"
version: "1.0"
status: "accepted"
accepted_at: "2026-05-17"
accepted_by: "User"
phase: "Architecture (Gap-closing)"
---

# ADR-009 — Дефолты для blockers Phase 6

## Контекст

После Phase 5 (Architecture) обнаружено 5 blockers перед Phase 6 (Development):
3 юридических + 2 технических. Пользователь поручил Orchestrator предложить
разумные дефолты для утверждения.

## Решения (DRAFT — требуют утверждения)

### 1. Юр. согласование «Закона клуба» + Privacy Policy (HIGH)

**Дефолт:** Использовать черновик `docs/design/content/law-of-club-draft.md`
(Content Agent) как working draft. До запуска Phase 1 в production:

- Phase 6 Development: реализуем механику принятия закона, текст подгружается
  из БД (`law_versions` table → `law_acceptances.version`)
- Юр. согласование частей III (KB consent) и IV (AI consent) — параллельно
  с Phase 6, привлечь юриста РФ со специализацией 152-ФЗ + GDPR
- Минимальный privacy policy создаст Product Agent на основе шаблона Роскомнадзора
- Финальные тексты блокируют **production deploy**, а не разработку

**Юрист:** Заказчик находит самостоятельно (≤ 2 недели). Бюджет ~50k₽ за
консультацию + согласование.

### 2. Refund Policy (HIGH)

**Дефолт (рекомендация Orchestrator):**

| Случай | Политика |
|--------|----------|
| Оплата прошла, доступ ещё не выдан (до интервью / закона клуба) | **Полный возврат** в течение 7 дней |
| Доступ выдан, использовано <14 дней | **Pro-rated возврат** = (оставшиеся дни / общий период) × сумма |
| Доступ выдан, использовано ≥14 дней | **Невозвратно** (соответствует ЗоЗПП ст. 32 для услуг) |
| Lifetime | **Невозвратно** после получения invite (явное согласие при оплате) |
| Бан по жалобе / нарушение закона клуба | **Невозвратно** (вина участника) |

Возвраты обрабатывает **Super-админ** в админке (action: «Refund»). Логирование
в `payment_refunds` (новая таблица — расширение Data модели).

**Согласие с политикой** — чекбокс на экране оплаты + строка в законе клуба.

### 3. Уведомление Роскомнадзора об обработке ПДн (HIGH)

**Дефолт:** Подаём уведомление **до production deploy** (заказчик через
портал Роскомнадзора, форма Р). Указываем:
- Цели: членство в закрытом клубе, оплата подписки, AI-матчинг, индексация
  чата для базы знаний
- Категории ПДн: ФИО, телефон, email, telegram_id, фото профиля, данные
  Google-формы, KYC (если включён), embedding вектора профиля и сообщений
- Срок хранения: до удаления аккаунта или явного запроса /delete
- Локализация: PostgreSQL primary в РФ (см. блокер 5)

Заказчик подаёт. Orchestrator готовит шаблон заявления в Phase 6.

### 4. USDT-провайдер (MEDIUM)

**Дефолт (рекомендация Orchestrator):** **Cryptomus** (или **NowPayments**).

Обоснование:
- Cryptomus: поддержка TRC20 + TON, white-label invoice, webhook с HMAC,
  fee ~0.4%, есть RU локализация, статичные адреса на инвойс
- NowPayments: альтернатива, fee ~0.5%, шире выбор сетей
- Прямая интеграция через ноды (своя нода TRC20 + TonCenter API) — отвергаем
  для MVP: сложность, безопасность, отсутствие compliance

**Альтернатива на оценку Architect+DevOps в Phase 6:** Plisio, BTCPay (только
если нужна полная децентрализация).

**N confirmations:**
- TRC20: 19 confirmations (~1 минута) — стандарт провайдера
- TON: 1 confirmation (финальность ≤ 5 секунд)

Подписи webhook: HMAC-SHA256 (Cryptomus) — реализация в `payments/adapters/cryptomus.py`.

### 5. Хостинг РФ vs зарубежный (MEDIUM)

**Дефолт:** **Selectel** (РФ) для production:
- Соответствие 152-ФЗ ст. 18 п.5 (локализация ПДн граждан РФ)
- Поддержка Docker, managed PostgreSQL, S3-compat
- Подключение ЦБ РФ XML, ЮKassa, СБП без VPN
- Цена ~12-15k₽/мес для MVP инфры (VPS 4vCPU/8GB + managed PG)

**Backup/DR:** Backups в Selectel S3 (cross-region), runbook DR на отдельный
регион Selectel.

**Listener-бот** (MTProto) — отдельный VPS того же провайдера, чтобы не
смешивать процессы. Анти-fingerprint: residential IP (если потребуется,
через прокси).

**Anthropic API** — через прямые запросы (US endpoint), PII redaction перед
отправкой (DEC-SEC-003 уже учитывает).

## Последствия

### Плюсы дефолтов
- Phase 6 разблокирована: можно сразу начинать backend skeleton + core context
- USDT-провайдер выбран → Data может уточнить webhook_log.provider enum
  ('cryptomus','yookassa','sbp_manual')
- Хостинг определён → DevOps может начать терраформ-инфру (Phase 8)
- Юр. вопросы оставлены параллельным треком, не блокируют разработку

### Минусы / риски
- Юр. договорённости могут потребовать переписывания UI закона клуба и
  privacy policy — Phase 6 закладывает версионирование `law_versions`
- Если Cryptomus не подойдёт (compliance, регион) — переключение через
  Adapter pattern (≤ 1 неделя)
- Refund policy может вызвать конфликты с клиентами на ранней стадии —
  явное согласие на экране оплаты и в законе клуба критично

## Метрики после утверждения

- Снимется 5 blockers HIGH/MEDIUM из CP-003
- Pohozhe Phase 6 готова к старту в течение 1 дня после ответов:
  «Phase 1 MVP» / «Phase 1 + Phase 2 параллельно» / «Все 3 фазы как единый план»
- Если что-то отвергнуто — Orchestrator предлагает альтернативу

## Действия после утверждения

1. Обновить `context/decisions.yaml` (DEC-018..022 — по одному на блокер)
2. Если ADR утверждён — статус: `accepted` + Architect Agent дополняет
   `payments-architecture.md` provider-specific детали
3. Data Agent добавляет `payment_refunds` таблицу в schemas.md
4. Создаётся `docs/legal/` директория с шаблоном уведомления Роскомнадзора
5. Старт Phase 6: Dev Agent → technical specs для Phase 1 контекстов

---
*Документ создан: Orchestrator Agent | Дата: 2026-05-17*
