---
title: "Архитектура «Клуба 33» — обзор"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# Архитектура «Клуба 33» — обзор

## 1. Контекст

«Клуб 33» — закрытое сообщество с поэтапным релизом (3 фазы). Архитектура обслуживает три пользовательских поверхности:

- **Telegram-бот** (aiogram 3.x, FSM из 14 состояний) — точка входа кандидата, основной канал участника.
- **Mini-app** (Telegram WebApp, React 18 + Vite 6 + TelegramUI) — социальный слой, AI-сервисы, профиль.
- **Web-админка** (React 18 + Vite 6) — управление заявками, финансы, воронка, дашборды, экспорт.

Бэкенд — единый Django 5 + DRF (моно-API), что упрощает разработку малой командой и при этом не мешает выделить bounded contexts на уровне Django apps и DDD-агентов (Phase 5.5).

## 2. Стратегические решения (ADR-001..008)

| ADR | Решение |
|---|---|
| ADR-001 | Tech stack: Django 5 + DRF + React 18 + PostgreSQL 16 + pgvector + Redis 7 |
| ADR-002 | 13 bounded contexts (Identity, Applications, Payments, Subscriptions, Access Control, Calendar, Social, Time Economy, AI Services, Notifications, Admin & Finance, Listener, Audit) |
| ADR-003 | AI: model router haiku/sonnet/opus + embeddings, cost ≤ $2/user/мес |
| ADR-004 | Payments: 3 шлюза (USDT, ЮKassa, СБП), webhook-идемпотентность по external_id, fx_rate_snapshot при создании инвойса |
| ADR-005 | Calendar: собственный модуль club33calendar (DEC-009) |
| ADR-006 | RBAC: 3 админ-роли (super / moderator / support) + RBAC участников |
| ADR-007 | FSM бота: 14 состояний, state в Redis + persist в users.fsm_state |
| ADR-008 | NSM: композитная **Engaged Active Paid Members** (активная подписка + ≥1 осмысленное действие за 7 дней) |

## 3. Контейнерный обзор (C4 уровень 2)

```
Telegram ────► Telegram Bot (aiogram)
                       │
                       ▼
                     API (Django + DRF) ──► PostgreSQL 16 + pgvector
Mini-app SPA ────────► │                ──► Redis 7
Web Admin SPA ───────► │                ──► Anthropic / ЮKassa / USDT / Forex
                       ▲
                       │
Worker (APScheduler) ──┘
Listener Bot (Telethon) → pgvector
```

Полная модель: `workspace.dsl`. Диаграммы (Mermaid): `c4-diagrams.md`.

## 4. Bounded contexts (резюме)

13 контекстов сгруппированы по жизненным циклам пользователя:

- **Воронка**: Identity & Access · Applications · Calendar · Payments · Subscriptions · Access Control
- **Жизнь в клубе**: Social · Time Economy · AI Services · Notifications
- **Управление**: Admin & Finance · Listener · Audit

Контекстные контракты (events): `ApplicationApproved`, `PaymentConfirmed`, `LawAccepted`, `RespectGiven`, `DigestGenerated` и др. — см. `dependency-rules.yaml`.

## 5. Architecture as Code (rule 05)

| Артефакт | Назначение |
|---|---|
| `workspace.dsl` | C4 модель — единый источник истины |
| `constraints.yaml` | Layer rules, dependency rules, naming, size, security |
| `dependency-rules.yaml` | Граф allowed_imports для backend, frontend, bot, worker, listener |
| `fitness-functions.yaml` | 13 автоматических проверок в CI (import-linter, openapi-diff, coverage, visual regression, secrets) |

## 6. Interface as Code (rule 08)

| Артефакт | Назначение |
|---|---|
| `docs/design/component-stories-spec.md` | Спецификации компонентов (UI Agent, Phase 4) |
| `docs/interface/openapi.yaml` | API-контракт (drf-spectacular, Data Agent в TASK-009) |
| `docs/interface/interface-rules.yaml` | Правила изменения интерфейса |
| `docs/interface/visual-regression-config.yaml` | Конфигурация Playwright snapshot-тестов |
| `frontend/src/stories/**/*.stories.jsx` | Source of truth компонентов (Phase 6) |
| `frontend/tests/visual/__snapshots__/` | Baseline скриншоты (committed) |

## 7. NFR (highlight)

- **Performance**: mini-app TTI < 300 мс; API p95 < 500 мс; AI-матчинг < 5 с end-to-end.
- **Availability**: 99% (без 24/7), graceful degradation AI (fallback на кэшированные результаты).
- **Cost**: AI ≤ $2 USD/user/мес (DEC-A-002).
- **Security**: webhook idempotency, RBAC, секреты в env, JWT через Telegram init_data, маскирование защищённых полей в логах.
- **Observability**: rule 04 (structured AuditLog), Sentry, Prometheus-метрики, Grafana, ai_usage_log.

Подробно: `nfr-specs.md`.

## 8. Что дальше

| Phase | Что делается |
|---|---|
| 5 (parallel) | Data Agent → ER + OpenAPI; Security Agent → STRIDE; AI-Agents → model router |
| 5.5 | DDD Agent Generation на основе ADR-002 |
| 6 | Coder реализует, Review проверяет compliance с этой архитектурой |
| 8 | DevOps добавляет CI jobs из `fitness-functions.yaml` |

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
