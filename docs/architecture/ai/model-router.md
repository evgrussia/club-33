---
title: "Model Router — оркестрация Anthropic-моделей"
created_by: "AI-Agents Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# Model Router

Реализация решения **DEC-008** — оркестрация моделей Anthropic под задачи: быстрая / умная / эмбеддинги. Цель — баланс качества и стоимости.

## 1. Реестр моделей

| Алиас в коде | API-ID | Назначение | Cost/1M in | Cost/1M out |
|--------------|--------|------------|------------|-------------|
| `MODEL_FAST` | `claude-haiku-4-5` | Короткие ответы бота, классификация, валидация фраз | низкий | низкий |
| `MODEL_SMART` | `claude-sonnet-4-6` | Rerank, RAG answers, digest MAP, default reasoning | средний | средний |
| `MODEL_DEEP` | `claude-opus-4-7` | Digest REDUCE (impact), сложные edge-cases, важная аналитика | высокий | высокий |
| `MODEL_EMBEDDING` | `voyage-3` (или Anthropic emb TBD) | Embeddings 1536d → pgvector | очень низкий | — |

> Точные цены поддерживаются в `ai_model_pricing.yaml` (DevOps) и пересчитываются при изменении прайса. `ai_usage_log.cost_usd` рассчитывается на момент запроса.

## 2. Router (псевдокод)

```python
from enum import Enum
from dataclasses import dataclass

class TaskType(str, Enum):
    EMBEDDING = "embedding"
    BOT_REPLY = "bot_reply"
    CLASSIFICATION = "classification"
    LAW_CONSENT_VALIDATION = "law_consent_validation"
    MATCHING_RERANK = "matching_rerank"
    KB_ANSWER = "kb_answer"
    DIGEST_MAP = "digest_map"
    DIGEST_REDUCE = "digest_reduce"
    DEEP_REASONING = "deep_reasoning"

@dataclass
class RouterContext:
    task: TaskType
    high_impact: bool = False     # для digest REDUCE
    fallback_active: bool = False  # SRE может перевести в degraded mode

def route(ctx: RouterContext) -> str:
    if ctx.task == TaskType.EMBEDDING:
        return "MODEL_EMBEDDING"

    if ctx.task in {
        TaskType.BOT_REPLY,
        TaskType.CLASSIFICATION,
        TaskType.LAW_CONSENT_VALIDATION,
    }:
        return "MODEL_FAST"

    if ctx.task in {
        TaskType.MATCHING_RERANK,
        TaskType.KB_ANSWER,
        TaskType.DIGEST_MAP,
    }:
        if ctx.fallback_active:
            return "MODEL_FAST"      # деградация
        return "MODEL_SMART"

    if ctx.task == TaskType.DIGEST_REDUCE:
        return "MODEL_DEEP" if ctx.high_impact else "MODEL_SMART"

    if ctx.task == TaskType.DEEP_REASONING:
        return "MODEL_DEEP"

    return "MODEL_SMART"  # safe default
```

## 3. Правила выбора (нарративно)

### Haiku 4.5 — `MODEL_FAST`
- Короткие ответы бота (`/start`, FAQ, error-explanations).
- **Валидация фразы согласия с законом клуба** — нужно классифицировать «является ли это валидным согласием» (см. `prompts-library.md` → `LAW_CONSENT_VALIDATION_PROMPT`).
- Классификация: severity жалобы, intent сообщения.
- Парсинг короткого ввода в структурированный формат.

### Sonnet 4.6 — `MODEL_SMART` (default)
- **Matching rerank** + reasoning.
- **KB / RAG answers** с цитатами.
- **Digest MAP** (per-day summaries).
- Любая generation, где нужна структура и связность, но не deep reasoning.

### Opus 4.7 — `MODEL_DEEP`
- **Digest REDUCE** при высоком impact недели (правило `high_impact` см. `digest-system.md`).
- Сложные edge-cases (conflict resolution в админке — Phase 3, опционально).
- Запасной канал для перегенерации digest по требованию founder.

### Embeddings
- `voyage-3` (или Anthropic emb): 1536 dim → pgvector. См. `ai-architecture.md` §2.

## 4. Fallback и деградация

```mermaid
flowchart LR
    A[Request] --> B[Router pick model]
    B --> C[Call Anthropic API]
    C -->|200 ok| D[Return]
    C -->|429 rate-limit| E[Retry 3× exp backoff]
    C -->|5xx| F{Critical?}
    F -->|yes| G[Switch to MODEL_FAST<br/>warn в response: "упрощённый ответ"]
    F -->|no| H[Error to user "попробуй позже"]
    E -->|still fails| F
    G --> I[SRE alert]
```

**Деградация (`fallback_active=true`)** активируется вручную SRE или автоматически при error_rate > 30% за 5 минут. В этом режиме:
- `MODEL_SMART` → `MODEL_FAST` для matching/KB.
- Digest откладывается до восстановления.
- В UI показывается баннер «AI работает в упрощённом режиме».

## 5. Конфигурация

```yaml
# config/ai_models.yaml
models:
  MODEL_FAST:
    api_id: claude-haiku-4-5
    max_output_tokens: 1024
    default_temperature: 0.2
  MODEL_SMART:
    api_id: claude-sonnet-4-6
    max_output_tokens: 2048
    default_temperature: 0.3
  MODEL_DEEP:
    api_id: claude-opus-4-7
    max_output_tokens: 4096
    default_temperature: 0.4
  MODEL_EMBEDDING:
    api_id: voyage-3              # TBD на Phase 5
    dim: 1536

pricing:    # USD per 1M tokens, обновляется по факту
  claude-haiku-4-5: { input: 1.00, output: 5.00 }
  claude-sonnet-4-6: { input: 3.00, output: 15.00 }
  claude-opus-4-7: { input: 15.00, output: 75.00 }
  voyage-3: { input: 0.06, output: 0 }

fallback:
  enabled: false
  reason: ""
  activated_at: null
```

## 6. Контракт `AIClient`

```python
class AIClient:
    def chat(
        self,
        task: TaskType,
        messages: list[dict],
        *,
        high_impact: bool = False,
        response_format: dict | None = None,  # JSON schema
        stream: bool = False,
    ) -> AIResponse: ...

    def embed(self, texts: list[str]) -> list[list[float]]: ...

@dataclass
class AIResponse:
    text: str | None
    parsed: dict | None       # если был response_format
    model_used: str           # API-ID реально использованной модели
    tokens_in: int
    tokens_out: int
    cost_usd: float
    latency_ms: int
    fallback_used: bool
```

Каждый вызов автоматически:
- проходит через router,
- логируется в `ai_usage_log` (`cost-tracking.md`),
- проверяет per-user cost-cap и feature daily cap.

## 7. Тестирование

- **Unit**: router выбирает корректную модель для каждого `TaskType` + `high_impact`.
- **Contract**: mock Anthropic SDK — проверка передачи параметров.
- **Cost-test**: набор «эталонных» запросов прогоняется ежедневно (canary) — проверка что real-cost ≤ expected по фиче.

---
*Документ создан: AI-Agents Agent | Дата: 2026-05-16*
