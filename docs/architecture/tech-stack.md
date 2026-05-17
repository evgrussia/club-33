---
title: "Tech Stack «Клуба 33»"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# Tech Stack «Клуба 33»

Все версии — на момент проектирования (2026-05-16). Обновления зависимостей — через DevOps с обоснованием.

## Backend (API)

| Технология | Версия | Назначение | Обоснование |
|---|---|---|---|
| Python | 3.12.x | Runtime | LTS, актуальный для Django 5 |
| Django | 5.0.x | Web framework | LTS, ORM, admin, миграции |
| Django REST Framework | 3.15.x | REST API | Стандарт для DRF в проекте |
| drf-spectacular | latest | OpenAPI 3.1 schema | IfaC (rule 08), API contract |
| psycopg | 3.x | PostgreSQL driver | Современный, async-ready |
| pgvector (django-pgvector) | latest | Embeddings 1536-dim | AI RAG, матчинг |
| redis-py | 5.x | Redis client | Cache, FSM, idempotency |
| celery — **НЕТ** | — | — | Используем APScheduler (проще для MVP) |
| APScheduler | 3.10.x | Cron-задачи | Digest, баланс респектов, напоминания |
| pydantic | 2.x | Валидация DTO | Внутренние контракты |
| python-jose / PyJWT | latest | JWT | Auth mini-app (Telegram init_data) |
| gunicorn | latest | WSGI server | Production-grade |
| sentry-sdk | latest | Error tracking | Observability |

## Bot

| Технология | Версия | Назначение |
|---|---|---|
| aiogram | 3.x | Telegram Bot API + FSM |
| aiogram-fsm-storage-redis | latest | FSM state в Redis |
| httpx | latest | HTTP client к API |

## Listener Bot

| Технология | Версия | Назначение |
|---|---|---|
| Telethon | 1.x | MTProto-клиент (индексация чата клуба) |
| anthropic | latest | Embeddings (через model router в api) |

## Frontend (mini-app + web-admin, monorepo)

| Технология | Версия | Назначение | Обоснование |
|---|---|---|---|
| React | 18.x | UI library | DEC-006, целевой стек |
| Vite | 6.x | Bundler | Быстрая разработка |
| TypeScript | 5.x | Типизация | Обязательная для пуска |
| TelegramUI | latest | UI-kit для mini-app | DEC-UI-002 |
| Zustand | 4.x | State management | Лёгкий, без бойлерплейта |
| React Router | 6.x | Routing | Стандарт |
| TanStack Query | 5.x | Server state, кэширование | Кэш запросов к API |
| axios | 1.x | HTTP client | Интерсепторы JWT |
| openapi-typescript-codegen | latest | Генерация типов из openapi.yaml | IfaC sync |
| Vitest | 1.x | Unit-тесты | Замена Jest для Vite-проектов |
| Storybook | 8.x | Component docs + tests | IfaC (rule 08) |
| Playwright | 1.x | E2E + visual regression | IfaC |
| ESLint + Prettier | latest | Линтинг | Стандарт |
| eslint-plugin-boundaries | latest | Frontend dependency rules | AaC FF-005 |

## Database

| Технология | Версия | Назначение |
|---|---|---|
| PostgreSQL | 16 | OLTP, основная БД |
| pgvector | latest | Embeddings 1536 dim, ANN search |
| PgBouncer | latest (опционально) | Connection pooling |

**Размерность embeddings:** 1536 (voyage-3 или Anthropic embeddings — DEC-008).

## Cache

| Технология | Версия | Назначение |
|---|---|---|
| Redis | 7 | FSM state, sessions, idempotency keys, rate-limits, locks |

## AI

| Технология | Назначение | Обоснование |
|---|---|---|
| Anthropic Python SDK | Claude haiku/sonnet/opus | DEC-008 |
| Model router (custom) | Маршрут модели под задачу | См. ADR-003 |
| voyage-3 (или anthropic.embeddings) | Embeddings 1536 dim | DEC-008 |
| LangChain (опционально) | RAG-pipeline | Только если упростит, не обязателен |

**Cost guardrail:** ≤ $2 USD/user/мес (DEC-A-002, FF-012).

## Payments

| Провайдер | SDK | Тип | Обоснование |
|---|---|---|---|
| ЮKassa | yookassa-sdk-python | RUB, банковские карты, СБП | Стандарт для RU |
| USDT (TRC20) | прямая интеграция через провайдера | Крипто | Уточняется в Phase 5 (Data + Security) |
| USDT (TON) | TON Center / TonAPI | Крипто | Альтернатива TRC20 |
| СБП | ручная сверка через ЮKassa-инвойс | RUB | Support-админ подтверждает |
| Forex (ЦБ РФ) | exchangerate-host или ЦБ РФ XML | Курс USD→RUB | DEC-010, бесплатно, надёжно |

**Идемпотентность webhook:** `external_id` от провайдера + Redis key с TTL. См. ADR-004.

## Infrastructure

| Технология | Версия | Назначение |
|---|---|---|
| Docker | latest | Контейнеризация |
| docker compose | latest | Локальная и prod-оркестрация (MVP) |
| Nginx | latest | Reverse proxy, TLS termination |
| Ubuntu Server | 24.04 LTS | OS |
| Let's Encrypt (certbot) | latest | TLS-сертификаты |
| Cloudflare (опционально) | — | CDN, DDoS-защита |

## CI/CD

| Технология | Назначение |
|---|---|
| GitHub Actions | CI/CD pipeline |
| import-linter | Проверка dependency-rules.yaml (FF-001/002/003) |
| pytest + pytest-cov | Backend тесты + coverage |
| ruff + black + mypy | Backend lint/format/types |
| openapi-diff | Detect breaking API changes |
| gitleaks / trufflehog | Поиск секретов |
| pip-audit / npm audit | Security audit зависимостей |

## Observability

| Технология | Назначение |
|---|---|
| AuditLog (rule 04) | Структурированный аудит-лог в БД |
| Sentry | Error tracking |
| Prometheus (опционально, Phase 8) | Метрики |
| Grafana (опционально, Phase 8) | Дашборды |
| Loki (опционально, Phase 8) | Лог-агрегация |

## Что отложено / не используется

- **Celery + RabbitMQ** — избыточно для MVP, выбран APScheduler.
- **Kubernetes** — не требуется на старте (1 VPS, docker compose).
- **GraphQL** — REST + OpenAPI достаточно.
- **WebSocket** — push-уведомления идут через Telegram (нет своего канала).
- **LangChain как обязательный** — опционально, не закрепляем.

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
