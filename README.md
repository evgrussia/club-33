# Клуб 33 — проектная документация

> Telegram-бот + mini-app + web-админка для закрытого клуба с подпиской, социальным слоем и AI-сервисами.

Документация создана мультиагентной системой Claude Code Agent System (CCAS) на основе ТЗ v5 (финал, 2026-05-05). Проект прошёл фазы **Intake → System Adaptation → Discovery → Design → Architecture** и готов к Phase 6 (Development).

---

## Содержание

- [1. Источник истины](#1-источник-истины)
- [2. Коммерческое предложение](#2-коммерческое-предложение)
- [3. Discovery (исследование)](#3-discovery-исследование)
- [4. Design (дизайн)](#4-design-дизайн)
- [5. Architecture (архитектура)](#5-architecture-архитектура)
  - [5.1. AaC — Architecture as Code](#51-aac--architecture-as-code)
  - [5.2. IfaC — Interface as Code](#52-ifac--interface-as-code)
  - [5.3. Документация архитектуры](#53-документация-архитектуры)
  - [5.4. Architecture Decision Records (ADR)](#54-architecture-decision-records-adr)
  - [5.5. Модель данных и API](#55-модель-данных-и-api)
  - [5.6. Безопасность](#56-безопасность)
  - [5.7. AI-подсистема](#57-ai-подсистема)

---

## 1. Источник истины

| Документ | Описание |
|---|---|
| [Club 33 — ТЗ v5.pdf](docs/Club%2033%20%E2%80%94%20%D0%A2%D0%97%20v5%20%28%D1%84%D0%B8%D0%BD%D0%B0%D0%BB%2C%202026-05-05%29.pdf) | Оригинальное техническое задание заказчика (исходник всех требований) |

---

## 2. Коммерческое предложение

| Документ | Описание |
|---|---|
| [commercial-offer.md](docs/commercial-offer.md) | Полное коммерческое предложение: Roadmap, 90+ задач с описанием простым языком, оценка ~2 780 чч на весь продукт |
| [commercial-offer.pdf](docs/commercial-offer.pdf) | PDF-версия (528 КБ) для отправки заказчику |
| [commercial-offer.html](docs/commercial-offer.html) | HTML-версия (для предпросмотра в браузере) |

**Сводка:**
- Фаза 1 (MVP): ≈ 1 060 чч — бот + оплаты + invite + минимальная админка
- Фаза 2 (Социал + AI): ≈ 920 чч — роли, респекты, звёзды, жалобы, AI-матчинг, RAG, digest
- Фаза 3 (Экономика времени): ≈ 280 чч — дары, сжигание, lifetime-бюджет, конвертер
- Сквозные работы: ≈ 520 чч — дизайн, тесты, DevOps, PM

---

## 3. Discovery (исследование)

### Product (видение и требования)

| Документ | Что внутри |
|---|---|
| [docs/discovery/vision.md](docs/discovery/vision.md) | Проблема, решение, 6 целевых аудиторий, KPI, **NSM = Weekly Active Members** |
| [docs/discovery/prd.md](docs/discovery/prd.md) | Полный PRD по §1–§25 ТЗ, **35+ функциональных требований**, NFR, Open Decisions |
| [docs/discovery/user-stories.md](docs/discovery/user-stories.md) | **52 User Stories** в 7 эпиках (Воронка, Платежи, Доступ, Социал, Время, AI, Админка) с Given/When/Then |
| [docs/discovery/personas.md](docs/discovery/personas.md) | **6 персон**: кандидат, участник, lifetime, модератор, админ, основатель |

### Research (исследование рынка)

| Документ | Что внутри |
|---|---|
| [docs/discovery/research/competitive-analysis.md](docs/discovery/research/competitive-analysis.md) | Анализ **10 конкурентов**: Атланты, Эквиум, YPO, EO, Vistage, Lunchclub, TimeRepublik и др. |
| [docs/discovery/research/references-uxui.md](docs/discovery/research/references-uxui.md) | UI-референсы: TelegramUI, Lunchclub-карточки, Perplexity-цитаты, 8 ключевых экранов |
| [docs/discovery/research/findings.md](docs/discovery/research/findings.md) | TOP-5 рекомендаций для PRD (выявлен рыночный gap: AI+RAG+digest+соц в одном продукте) |

### Analytics (метрики и воронки)

| Документ | Что внутри |
|---|---|
| [docs/discovery/analytics/tracking-plan.md](docs/discovery/analytics/tracking-plan.md) | **37 событий** по 3 фазам с JSON-schema, trigger, owner |
| [docs/discovery/analytics/metrics-framework.md](docs/discovery/analytics/metrics-framework.md) | 8 групп метрик (acquisition, revenue, retention, LTV, social, AI, time economy, operational) |
| [docs/discovery/analytics/funnel-definition.md](docs/discovery/analytics/funnel-definition.md) | Главная воронка из 9 шагов + 4 sub-funnels с target-конверсиями |

### Business Analysis (процессы)

| Документ | Что внутри |
|---|---|
| [docs/discovery/business/processes-overview.md](docs/discovery/business/processes-overview.md) | Глоссарий, карта **12 процессов**, **14 FSM-состояний**, RBAC-матрица |
| [docs/discovery/business/funnel-process.md](docs/discovery/business/funnel-process.md) | Воронка приёма (Google-форма → invite) + продление подписки со swim-lane |
| [docs/discovery/business/payment-process.md](docs/discovery/business/payment-process.md) | USDT/ЮKassa/СБП с идемпотентностью и нестандартными ситуациями (§21 ТЗ) |
| [docs/discovery/business/respects-complaints-process.md](docs/discovery/business/respects-complaints-process.md) | Респекты (4 канала), жалобы (анонимность), звёзды, роли, KYC |
| [docs/discovery/business/time-economy-process.md](docs/discovery/business/time-economy-process.md) | Дар, сжигание, lifetime-бюджет, админ-конвертер USD↔дни |

---

## 4. Design (дизайн)

### UX (потоки и wireframes)

| Документ | Что внутри |
|---|---|
| [docs/design/ux/user-flows.md](docs/design/ux/user-flows.md) | **18 user flows** по 7 эпикам с edge cases |
| [docs/design/ux/information-architecture.md](docs/design/ux/information-architecture.md) | Sitemap бота (13 команд + FSM), mini-app (5 tabs), админки (11 разделов с RBAC) |
| [docs/design/ux/wireframes-bot.md](docs/design/ux/wireframes-bot.md) | **17 ASCII-wireframes** dialog-флоу бота |
| [docs/design/ux/wireframes-miniapp.md](docs/design/ux/wireframes-miniapp.md) | **10 экранов** mini-app с native Telegram-элементами |
| [docs/design/ux/wireframes-admin.md](docs/design/ux/wireframes-admin.md) | **13 разделов** web-админки с RBAC-видимостью |
| [docs/design/ux/accessibility-checklist.md](docs/design/ux/accessibility-checklist.md) | WCAG AA, haptic, MainButton/BackButton, theme params, UI-feedback |

### UI (design system)

| Документ | Что внутри |
|---|---|
| [docs/design/ui/design-system.md](docs/design/ui/design-system.md) | Философия, brand identity (золотой `#C9A24A`), палитра, типографика |
| [docs/design/ui/design-tokens.yaml](docs/design/ui/design-tokens.yaml) | Машиночитаемые tokens: 27 цветов light/dark, 12 typography, spacing 4px-grid, animations |
| [docs/design/ui/component-library.md](docs/design/ui/component-library.md) | **38 компонентов** (atomic, cells, composite, specific, layout, admin) с variants/states/props |
| [docs/design/ui/visual-language.md](docs/design/ui/visual-language.md) | Иллюстрации, иконография (Tabler + 10 custom), choreography анимаций |
| [docs/design/component-stories-spec.md](docs/design/component-stories-spec.md) | Спецификация Storybook stories (обязательно по rule 08) |

### Content (UX-copy)

| Документ | Что внутри |
|---|---|
| [docs/design/content/tone-of-voice.md](docs/design/content/tone-of-voice.md) | Голос бренда: 5 атрибутов, Do/Don't, стоп-лист слов, примеры |
| [docs/design/content/bot-messages.md](docs/design/content/bot-messages.md) | **~45 сообщений бота** по FSM воронки, оплат, invite, команд |
| [docs/design/content/miniapp-copy.md](docs/design/content/miniapp-copy.md) | Тексты **12 экранов** mini-app + все empty states |
| [docs/design/content/admin-notifications.md](docs/design/content/admin-notifications.md) | **22 уведомления** в админ-чат |
| [docs/design/content/error-states.md](docs/design/content/error-states.md) | **25 типов ошибок** с экшен-кнопками |
| [docs/design/content/law-of-club-draft.md](docs/design/content/law-of-club-draft.md) | Черновик «Закона клуба» + 3 варианта фразы согласия (DRAFT — ждёт юриста) |

---

## 5. Architecture (архитектура)

### 5.1. AaC — Architecture as Code

Машиночитаемая модель архитектуры. Используется в CI для блокировки нарушений.

| Файл | Что внутри |
|---|---|
| [docs/architecture/workspace.dsl](docs/architecture/workspace.dsl) | **Structurizr DSL (C4 модель)**: 7 persons, 8 containers, 6 external systems |
| [docs/architecture/constraints.yaml](docs/architecture/constraints.yaml) | Архитектурные ограничения: layer rules, dependency, naming, size, security |
| [docs/architecture/dependency-rules.yaml](docs/architecture/dependency-rules.yaml) | Граф allowed_imports для **14 Django apps + 9 frontend модулей** |
| [docs/architecture/fitness-functions.yaml](docs/architecture/fitness-functions.yaml) | **13 fitness functions**: dependency check, layers, openapi, bundle, coverage, secrets, vulns, AI cost |

### 5.2. IfaC — Interface as Code

Контракты UI и API в коде. Защита от регрессий через CI.

| Файл | Что внутри |
|---|---|
| [docs/interface/openapi.yaml](docs/interface/openapi.yaml) | OpenAPI 3.1 — **30 endpoints** (auth, mini-app, admin, webhooks) |
| [docs/interface/interface-rules.yaml](docs/interface/interface-rules.yaml) | 8 API rules + 9 UI rules + workflow изменения контракта |
| [docs/interface/visual-regression-config.yaml](docs/interface/visual-regression-config.yaml) | Playwright config: 19 pages + 15 components, threshold 2% |

### 5.3. Документация архитектуры

| Документ | Что внутри |
|---|---|
| [docs/architecture/overview.md](docs/architecture/overview.md) | Высокоуровневый обзор архитектуры |
| [docs/architecture/c4-diagrams.md](docs/architecture/c4-diagrams.md) | **6 Mermaid-диаграмм**: SystemContext, Container, Component (Payments/AI), State (FSM), Deployment |
| [docs/architecture/tech-stack.md](docs/architecture/tech-stack.md) | Полный tech stack: Django 5 + React 18 + Postgres 16 + pgvector + Redis 7 + aiogram + Telethon + Anthropic |
| [docs/architecture/nfr-specs.md](docs/architecture/nfr-specs.md) | NFR: performance, scalability, availability, security, observability, cost, a11y, i18n |

### 5.4. Architecture Decision Records (ADR)

| ADR | Решение |
|---|---|
| [ADR-001](docs/architecture/adrs/ADR-001-tech-stack.md) | Выбор tech stack (Django, React, Postgres, pgvector, Redis, aiogram, Telethon) |
| [ADR-002](docs/architecture/adrs/ADR-002-bounded-contexts.md) | **13 bounded contexts**: Identity, Applications, Payments, Subscriptions, Access, Calendar, Social, Time Economy, AI, Notifications, Admin, Listener, Audit |
| [ADR-003](docs/architecture/adrs/ADR-003-ai-orchestration.md) | AI Model Router: Haiku 4.5 / Sonnet 4.6 / Opus 4.7 + voyage-3 embeddings |
| [ADR-004](docs/architecture/adrs/ADR-004-payments-architecture.md) | Payments via Adapter pattern, idempotency, fx snapshot, ±0.5% tolerance |
| [ADR-005](docs/architecture/adrs/ADR-005-calendar-module.md) | Собственный модуль club33calendar (TimeSlot, Booking, Reminder) |
| [ADR-006](docs/architecture/adrs/ADR-006-rbac-strategy.md) | RBAC: super / модератор / support; UI скрывает по правам |
| [ADR-007](docs/architecture/adrs/ADR-007-fsm-bot-state.md) | FSM бота: 14 состояний, Redis (hot) + Postgres (cold) |
| [ADR-008](docs/architecture/adrs/ADR-008-nsm-finalization.md) | **NSM = Engaged Active Paid Members** (композитная метрика) |
| [ADR-009](docs/architecture/adrs/ADR-009-phase6-blockers-defaults.md) | Дефолты для Phase 6: Cryptomus (USDT), Selectel (хостинг), refund policy, юр.процесс |

### 5.5. Модель данных и API

| Документ | Что внутри |
|---|---|
| [docs/architecture/data/er-diagram.md](docs/architecture/data/er-diagram.md) | **6 Mermaid ER-диаграмм** по контекстам |
| [docs/architecture/data/schemas.md](docs/architecture/data/schemas.md) | DDL всех **35 таблиц** с индексами/constraints (включая pgvector) |
| [docs/architecture/data/migrations-plan.md](docs/architecture/data/migrations-plan.md) | План миграций Phase 1/2/3 + бэкфилл + ретенция |
| [docs/architecture/data/event-storming.md](docs/architecture/data/event-storming.md) | **35 domain events** с payload + source/consumer контекстами |

### 5.6. Безопасность

| Документ | Что внутри |
|---|---|
| [docs/architecture/security/threat-model.md](docs/architecture/security/threat-model.md) | **STRIDE-модель**: 41 угроза по 10 bounded contexts + Top-5 critical |
| [docs/architecture/security/owasp-top-10-checks.md](docs/architecture/security/owasp-top-10-checks.md) | OWASP Top 10 (2021) с конкретными mitigations для Django+React |
| [docs/architecture/security/payments-security.md](docs/architecture/security/payments-security.md) | Webhook HMAC, idempotency, replay protection, anti-fraud, refund policy |
| [docs/architecture/security/ai-security.md](docs/architecture/security/ai-security.md) | Prompt injection, PII redaction, KB data poisoning, cost cap |
| [docs/architecture/security/privacy-compliance.md](docs/architecture/security/privacy-compliance.md) | **152-ФЗ + GDPR**: согласия, локализация ПДн, right to delete, KYC шифрование |
| [docs/architecture/security/secrets-management.md](docs/architecture/security/secrets-management.md) | **24 секрета**, Vault, ротация, gitleaks, runbooks |

### 5.7. AI-подсистема

| Документ | Что внутри |
|---|---|
| [docs/architecture/ai/ai-architecture.md](docs/architecture/ai/ai-architecture.md) | Обзорная архитектура: стек, слои, диаграммы потоков, кэш-стратегия |
| [docs/architecture/ai/matching-system.md](docs/architecture/ai/matching-system.md) | `/match` pipeline: embedding → pgvector → Sonnet rerank → reasoning + feedback (Lunchclub-pattern) |
| [docs/architecture/ai/rag-system.md](docs/architecture/ai/rag-system.md) | `/ask` RAG-pipeline + Listener-бот + цитаты (Perplexity-pattern) |
| [docs/architecture/ai/digest-system.md](docs/architecture/ai/digest-system.md) | Weekly digest: cron + map-reduce summarization + публикация |
| [docs/architecture/ai/model-router.md](docs/architecture/ai/model-router.md) | Реализация ADR-003: правила выбора моделей, fallback, контракт AIClient |
| [docs/architecture/ai/cost-tracking.md](docs/architecture/ai/cost-tracking.md) | `ai_usage_log`, дашборды, caps (per user $1.5/$2/$3 + per feature daily) |
| [docs/architecture/ai/prompts-library.md](docs/architecture/ai/prompts-library.md) | **7 системных промптов** с защитой от injection и JSON-schemas |

**Бюджет AI:** ≈ **$1.13 на пользователя в месяц** (cap $2) при 100 active users.

---

## Статистика проекта

| Метрика | Значение |
|---|---|
| Всего markdown/yaml/dsl документов | **69** |
| Discovery | 15 артефактов |
| Design | 17 артефактов |
| Architecture | 28 артефактов |
| Architecture Decision Records | 9 |
| Bounded contexts | 13 |
| Таблиц БД | 35 |
| API endpoints | 30 |
| Domain events | 35 |
| UI компонентов | 38 |
| User Stories | 52 |
| Бизнес-процессов | 12 |
| FSM-состояний бота | 14 |
| Системных AI-промптов | 7 |
| STRIDE-угроз | 41 |
| Решений в decisions.yaml | 22 (DEC-001..022) |

---

*README создан: Orchestrator Agent | Дата: 2026-05-17*
*Основано на ТЗ v5 (финал, 2026-05-05) и checkpoints CP-000..003*
