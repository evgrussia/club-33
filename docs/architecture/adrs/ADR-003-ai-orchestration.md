---
title: "ADR-003: AI Orchestration — Model Router"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# ADR-003: AI Orchestration — Model Router (стратегия)

**Status:** Accepted (стратегия). Реализация — AI-Agents Agent (TASK-011).
**Date:** 2026-05-16
**Author:** Architect Agent

## Контекст

DEC-008 фиксирует: AI-провайдер — только Anthropic, с оркестрацией моделей haiku/sonnet/opus + embeddings. Кост-ограничение DEC-A-002: ≤ $2 USD/user/мес. Этот ADR — стратегический уровень. Конкретные prompts и pipelines — `docs/architecture/ai/model-router.md` (AI-Agents Agent).

## Решение — стратегия

### 1. Три уровня моделей

| Уровень | Модель | Use cases |
|---|---|---|
| **fast** | `claude-haiku-4-5` | Короткие ответы бота, классификация заявок, простой /digest, валидация фразы согласия в законе клуба |
| **smart** | `claude-sonnet-4-6` | /match (rerank + объяснения), /ask (RAG-ответы), сложный /digest |
| **deep** | `claude-opus-4-7` | Эскалация при низкой confidence; разбор сложных жалоб (read-only support) |
| **embedding** | `voyage-3` (или anthropic.embeddings) | KB-индекс, профили, сообщения чата — 1536 dim в pgvector |

### 2. Маршрутизация — правила

```yaml
match_request:
  default: smart
  fallback_on_error: fast (с предупреждением "качество ниже обычного")

ask_rag:
  default: smart
  if retrieved_docs == 0: fast (отвечать "не нашёл в базе")
  if user_confidence_complaint: deep (один раз, помечено)

digest_weekly:
  if message_count < 50: fast
  else: smart

bot_text_reply:
  default: fast (короткие, structured outputs)

classification (заявка вспомогательная):
  default: fast

embedding (indexing):
  always: embedding-model
```

### 3. Cost guardrails

- `ai_usage_log` фиксирует каждый вызов: model, tokens_in, tokens_out, cost_usd, request_id, user_id, task_type.
- Daily aggregation в worker: cost / NSM. Алерт при > $1.5 / user/мес (80% бюджета).
- Кэширование ответов /ask: TTL 24 ч по hash(prompt + context_ids).
- Pre-flight token estimate: если оценка > N токенов → downgrade модели или ошибка пользователю.

### 4. Graceful degradation

- Anthropic недоступен → возврат кэша (если есть) или сообщение "AI временно недоступен".
- 5xx > 3 раз за минуту → circuit breaker на 5 минут.
- Embeddings провайдер недоступен → пометить запись `embedding_pending`, retry в worker.

### 5. Quality feedback loop

- `MatchFeedback`, `KbFeedback` (3-значный feedback DEC-UX-005: полезно/нейтрально/мимо).
- Еженедельный отчёт качества → AI-Agents Agent корректирует prompts.

### 6. Безопасность данных

- В prompt НЕ попадают: пароли, токены, секреты (rule 04 masking).
- В KB: только public сообщения чата (после согласия — закон клуба).
- Telegram user_id → анонимизирован hash для системных prompts (по возможности).

## Альтернативы

| Альтернатива | Почему отклонена |
|---|---|
| Один уровень (только sonnet) | Дорого; не нужна "глубокая" модель для коротких ответов |
| OpenAI / Mixtral | DEC-008 фиксирует Anthropic only |
| LangChain как обязательный | Опционально; добавляет зависимость, не нужен в MVP |
| Внешний vector DB (Pinecone) | pgvector закрывает потребности, минус инфра |
| Embedding в самом Anthropic | Voyage-3 — рекомендация Anthropic для качества |

## Последствия

- Простая стратегия, прозрачные правила маршрутизации.
- ai_usage_log = единый источник истины по cost и качеству.
- AI-Agents Agent имеет чёткий каркас для конкретных prompts/pipelines.

## Связанные документы

- `docs/architecture/ai/model-router.md` (создаст AI-Agents в TASK-011)
- `nfr-specs.md` (cost section)
- DEC-008, DEC-A-002

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
