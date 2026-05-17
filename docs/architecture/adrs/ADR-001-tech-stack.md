---
title: "ADR-001: Tech Stack"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# ADR-001: Tech Stack «Клуба 33»

**Status:** Accepted
**Date:** 2026-05-16
**Author:** Architect Agent

## Контекст

«Клуб 33» — Telegram-бот + mini-app + web-админка для закрытого клуба с подпиской, социальным слоем и AI-сервисами. Команда — небольшая, релиз поэтапный (3 фазы). Архитектура должна поддержать ~1-5 тыс. участников в Y1 и масштабироваться позже.

## Решение

| Слой | Технология |
|---|---|
| Backend API | **Django 5 + DRF** |
| Database | **PostgreSQL 16 + pgvector** |
| Cache / FSM state | **Redis 7** |
| Frontend (mini-app + admin) | **React 18 + Vite 6 + TypeScript + TelegramUI** |
| Bot | **Python 3.12 + aiogram 3.x** |
| Listener Bot | **Python 3.12 + Telethon (MTProto)** |
| Scheduler | **APScheduler** |
| AI | **Anthropic Claude (haiku/sonnet/opus) + embeddings 1536** |
| Payments | **ЮKassa SDK + USDT (TRC20/TON) + СБП (ручная сверка)** |
| Forex | **ЦБ РФ XML API** (DEC-010) |
| Infra | **Docker + docker compose + Nginx + Ubuntu 24.04 LTS** |
| CI/CD | **GitHub Actions** |
| Auth mini-app | **JWT + Telegram init_data HMAC verify** |

## Обоснование

1. **Django 5 + DRF** — зрелый, продуктивный для CRUD-heavy системы (заявки, платежи, админка). Огромная экосистема: admin, ORM, миграции, drf-spectacular для OpenAPI. Команда знакома со стеком.
2. **PostgreSQL 16 + pgvector** — единая БД для OLTP и AI embeddings, минимум инфраструктуры. pgvector с ivfflat достаточно для 100k embeddings (масштаб MVP).
3. **Redis 7** — обязателен для FSM aiogram (state-storage) + cache + idempotency keys.
4. **React 18 + Vite 6** — заданы в CLAUDE.md как целевой стек, DEC-006 фиксирует mini-app на React.
5. **aiogram 3.x** — современный async-фреймворк для Telegram Bot API, нативная поддержка FSM.
6. **Telethon** для listener — единственный способ читать сообщения в группе как пользователь (MTProto). Bot API ограничен.
7. **APScheduler** — простой scheduler без брокера. Достаточно для MVP. Celery — overkill.
8. **Anthropic only (DEC-008)** — стратегическое решение. Один провайдер, контроль качества и стоимости через model router.
9. **Docker + docker compose** на VPS — минимальная инфраструктура. Kubernetes — оверкилл для MVP.

## Альтернативы

| Альтернатива | Почему отклонена |
|---|---|
| FastAPI вместо Django | Меньше batteries-included (нет admin, миграций, ORM из коробки) — потребуется больше кода для админки |
| Node.js + Nest.js | Команда сильнее в Python; AI-экосистема Python зрелее |
| MongoDB | Реляционная природа домена (платежи, подписки, респекты) — Postgres подходит лучше |
| Pinecone / Weaviate | Дополнительная инфра, отдельный provider; pgvector закрывает потребности MVP |
| OpenAI вместо Anthropic | Решение пользователя (DEC-008) — только Anthropic |
| Telegraf.js (Node) для бота | Python aiogram интегрируется в один runtime с API |
| Celery + Redis для задач | Избыточно; APScheduler достаточно. Переход к Celery — открытая опция на Y2 |
| Kubernetes | Overkill для 1-5k users; docker compose проще |

## Последствия

**Положительные:**
- Единый Python runtime для api/bot/worker/listener — общие пакеты и утилиты.
- Django admin "из коробки" ускоряет MVP.
- pgvector — нулевая дополнительная инфраструктура для AI.
- React monorepo (mini-app + admin) — переиспользование design system (DEC-UI-005).

**Отрицательные / риски:**
- Django sync-by-default — для AI/webhook нужен async где критично (через `asgiref.sync` или Django 5 async views).
- pgvector ограничен ~1M векторов на single-node — план B: миграция в Weaviate если вырастем.
- aiogram 3 — относительно новый API, миграция между minor-версиями требует внимания.

## Связанные документы

- `tech-stack.md` — детальные версии и обоснования
- `workspace.dsl` — C4 модель
- DEC-006, DEC-008, DEC-010 в `context/decisions.yaml`

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
