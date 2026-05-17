---
title: "Non-Functional Requirements (NFR) «Клуба 33»"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# NFR «Клуба 33»

## 1. Performance

| Метрика | Цель | Способ измерения |
|---|---|---|
| API p50 latency | < 150 ms | Prometheus histogram |
| API p95 latency | < 500 ms | Prometheus histogram |
| API p99 latency | < 1500 ms | Prometheus histogram |
| Mini-app TTI (Time-to-Interactive) | < 300 ms (cold) | Lighthouse / web-vitals |
| Mini-app initial JS bundle | < 500 KB gzipped | FF-006 |
| Bot reply latency | < 1 s для синхронных ответов | Bot middleware metric |
| AI matching end-to-end | < 5 s | ai_usage_log |
| /ask RAG-ответ | < 3 s | ai_usage_log |
| /digest (weekly) — generation per user | < 10 s | worker metric |
| Webhook processing (ЮKassa/USDT) | < 1 s ack, < 5 s полная обработка | Sentry transaction |
| PostgreSQL query p95 | < 50 ms | pg_stat_statements |
| pgvector kNN search (top-10) | < 200 ms | benchmark |

## 2. Scalability

| Параметр | Цель Year 1 | Архитектурный путь |
|---|---|---|
| Активные участники | 1 000 – 5 000 | Single-node Postgres, single VPS |
| Concurrent mini-app sessions | ~ 300 | gunicorn workers = CPU * 2 |
| Daily messages в чате клуба | ~ 5 000 | Listener batch-индексация |
| Daily AI requests | ~ 2 000 (digest + match + /ask) | Model router + кэш |
| Embeddings в KB | ~ 100 000 | pgvector + ivfflat индекс |

**Scale-out план (Y2+):**
- Postgres → read replicas для Admin Dashboard
- Redis → cluster
- API → горизонтально (stateless, JWT, FSM state в Redis)
- Worker → Celery (если APScheduler не справится)

## 3. Availability & Reliability

| Аспект | Цель |
|---|---|
| Uptime | 99.0% (≤ 7.2 ч downtime/мес — приемлемо без 24/7 саппорта) |
| RPO (data loss tolerance) | 1 час (daily backup + WAL) |
| RTO (recovery time) | 4 часа (manual restore) |
| Graceful degradation AI | При недоступности Anthropic — кэш предыдущих matchings, fallback в /ask "сейчас не могу ответить, попробуй позже" |
| Webhook retry | Idempotency + Redis lock, 3 попытки с экспоненциальным backoff |
| Payment SLA | подтверждение USDT/ЮKassa ≤ 10 мин (по webhook), > 10 мин → ручная проверка support |
| FSM persistence | Hot: Redis, cold: users.fsm_state в Postgres |

## 4. Security

Полная модель угроз — TASK-010 (Security Agent). Здесь — высокоуровневые требования.

| Аспект | Требование |
|---|---|
| Transport | TLS 1.2+ обязательно (Nginx + Let's Encrypt) |
| Auth mini-app | JWT через Telegram init_data (HMAC verify) |
| Auth admin | JWT + RBAC (super/moderator/support, DEC-005) |
| Secrets | Только через env vars; gitleaks в CI (FF-010) |
| Webhook security | HMAC signature verify + idempotency by external_id |
| Logging | Маскирование защищённых полей (rule 04) |
| PII storage | Минимизация: храним то, что нужно. KYC-флаг — ручной |
| Rate limiting | Redis-based: API 60 rpm/IP, бот 10 cmd/min/user |
| CSRF | Django default + SameSite cookies для admin |
| XSS | React auto-escape + CSP-заголовки |
| SQL Injection | ORM only, raw SQL — только review-approved |
| Dependency scanning | pip-audit, npm audit (FF-011) |

## 5. Observability

| Слой | Инструмент |
|---|---|
| Application errors | Sentry (api, bot, worker, listener) |
| Audit log | `AuditLog` модель в Postgres + admin UI (rule 04) |
| Metrics | Prometheus + Grafana (Phase 8) |
| Logs | structlog → stdout → Loki / журнал |
| AI cost tracking | `ai_usage_log` (tokens_in, tokens_out, cost_usd, model) |
| Payment tracking | `payments.invoice` + Sentry transactions |

**SLO дашборд (Phase 8):**
- Payment confirmation < 10 min: 95%
- API uptime: 99.0%
- AI cost / NSM-user / month: ≤ $2

## 6. Cost

| Категория | Бюджет (Year 1) | Контроль |
|---|---|---|
| VPS | $40-80 / мес | Один сервер |
| AI inference (Anthropic) | ≤ $2 / user / мес (DEC-A-002) | FF-012, model router, кэш ответов |
| Payments fees | ЮKassa 2.8%, USDT ~1% | По провайдеру |
| Forex API | $0 (ЦБ РФ) | DEC-010 |
| Sentry | free tier до 5k events | Аларм при approach |
| Backups (S3-совместимый) | $5-10 / мес | Daily |

## 7. Maintainability

| Аспект | Требование |
|---|---|
| Test coverage | Domain ≥ 90%, Application ≥ 80%, Infra ≥ 70%, Frontend ≥ 70% (FF-007) |
| Линт | ruff/black/mypy backend, ESLint/Prettier frontend |
| Architecture compliance | import-linter в CI (FF-001/002/003) |
| Размер файлов | ≤ 500 строк (SR-001) |
| Сложность функций | ≤ 10 CC (SR-005) |
| ADR | Каждое архитектурное решение фиксируется как ADR |
| Документация | OpenAPI auto-generated, Storybook auto-published |

## 8. Privacy & Compliance

| Аспект | Подход |
|---|---|
| Telegram-данные | Только публичный профиль + username + user_id |
| Чат-индексация (Listener) | Только с согласия (закон клуба, ОТКРЫТЫЙ вопрос — реализация согласия) |
| Анонимность жалоб | Ник дарителя не показывается получателю; админ видит (rule UX) |
| Right to be forgotten | Endpoint анонимизации (Phase 2+) |
| Data retention | AuditLog 90 дней (rule 04); embeddings — пока пользователь активен |

## 9. Internationalisation

- Phase 1-3: только RU (тон «на ты»).
- Архитектурно: все тексты в i18n-файлах (Django: `gettext`, Frontend: `i18next` или `react-intl`) — Phase 6.
- Будущее: EN, возможно UA — не в скоупе MVP.

## 10. Accessibility (a11y)

- Mini-app + admin: WCAG 2.1 AA (см. UX accessibility-checklist).
- Контраст ≥ 4.5:1, hit-area ≥ 44px на mobile.
- Keyboard navigation в admin SPA.

## 11. Резерв на будущее (Phase 4+)

Архитектурно заложено, но не реализуется в MVP:
- Оплата зарубежной картой (PayPal/Stripe-совместимый шлюз).
- Маркетплейс услуг с расчётом днями.
- Партнёрские/реферальные программы.
- Native mobile app (нет в скоупе).

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
