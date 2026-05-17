---
title: "C4 диаграммы «Клуба 33»"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# C4 диаграммы «Клуба 33»

Источник истины — `workspace.dsl` (Structurizr DSL). Диаграммы ниже — Mermaid-эквиваленты для быстрого просмотра в Git.

---

## 1. System Context (C4 Level 1)

```mermaid
flowchart LR
    candidate([Кандидат])
    member([Участник])
    lifetime([Lifetime])
    founder([Основатель])
    mod([Модератор])
    support([Support])
    super_a([Super-админ])

    subgraph Club33["Клуб 33"]
        sys[(Клуб 33 — платформа)]
    end

    telegram[Telegram]
    yk[ЮKassa]
    usdt[USDT-провайдер]
    forex[Forex API ЦБ РФ]
    anthropic[Anthropic Claude]
    gforms[Google Forms]

    candidate --> telegram
    member --> telegram
    lifetime --> telegram
    founder --> telegram
    mod --> sys
    support --> sys
    super_a --> sys

    candidate --> gforms
    gforms -.webhook.-> sys
    telegram <--> sys
    sys --> yk
    yk -.webhook.-> sys
    sys --> usdt
    usdt -.webhook.-> sys
    sys --> forex
    sys --> anthropic
```

---

## 2. Container Diagram (C4 Level 2)

```mermaid
flowchart TB
    subgraph Users
        u_member([Участник])
        u_admin([Админ])
    end

    subgraph Telegram
        tg[Telegram Bot API + WebApp + MTProto]
    end

    subgraph Club33["Клуб 33 (Software System)"]
        bot[Telegram Bot<br/>Python aiogram 3.x]
        listener[Listener Bot<br/>Telethon MTProto]
        miniapp[Mini-app SPA<br/>React 18 + Vite 6]
        admin[Web Admin SPA<br/>React 18 + Vite 6]
        api[API<br/>Django 5 + DRF]
        worker[Worker<br/>APScheduler]
        db[(PostgreSQL 16<br/>+ pgvector)]
        cache[(Redis 7)]
    end

    subgraph External
        yk[ЮKassa]
        usdt[USDT Provider]
        forex[Forex API]
        ant[Anthropic API]
    end

    u_member --> tg
    u_admin --> admin
    tg --> bot
    tg --> miniapp
    tg --> listener

    miniapp -- JWT/REST --> api
    admin   -- JWT/REST --> api
    bot     -- internal HTTP --> api

    api --> db
    api --> cache
    worker --> db
    worker --> cache
    worker --> api
    listener --> db

    api --> tg
    api --> yk
    api --> usdt
    api --> forex
    api --> ant
    worker --> tg
    worker --> ant
    yk -.webhook.-> api
    usdt -.webhook.-> api
```

---

## 3. Component Diagram — Payments (C4 Level 3)

```mermaid
flowchart LR
    subgraph Payments[Bounded Context: Payments]
        invoice[InvoiceService]
        yk_adapter[YooKassaAdapter]
        usdt_adapter[USDTAdapter]
        sbp_handler[SBPManualHandler]
        webhook_router[WebhookRouter<br/>idempotency by external_id]
        forex_service[ForexRateService]
        payment_repo[(PaymentRepository)]
    end

    subgraph External
        yk[ЮKassa API]
        usdt_ext[USDT TRC20/TON]
        cbr[ЦБ РФ Forex]
    end

    subgraph Subscriptions
        sub_service[SubscriptionService]
    end

    invoice --> forex_service
    forex_service --> cbr
    invoice --> yk_adapter
    invoice --> usdt_adapter
    invoice --> sbp_handler
    yk_adapter --> yk
    usdt_adapter --> usdt_ext

    yk -.webhook.-> webhook_router
    usdt_ext -.webhook.-> webhook_router
    webhook_router --> payment_repo
    webhook_router -- PaymentConfirmed event --> sub_service
```

---

## 4. Component Diagram — AI Services (C4 Level 3)

```mermaid
flowchart LR
    subgraph AI[Bounded Context: AI Services]
        router[ModelRouter<br/>haiku/sonnet/opus]
        match[MatchingService]
        rag[RAGService /ask]
        digest[DigestService /digest]
        embed[EmbeddingService]
        usage[(ai_usage_log)]
        kb[(KB pgvector)]
        feedback[(MatchFeedback / KBFeedback)]
    end

    subgraph External
        anthropic[Anthropic Claude]
    end

    subgraph Listener
        l[Listener Bot]
    end

    l --> embed
    embed --> kb
    embed --> anthropic

    match --> router
    rag --> router
    digest --> router
    router --> anthropic
    router --> usage

    rag --> kb
    match --> kb
    rag --> feedback
    match --> feedback
```

---

## 5. Component Diagram — Access Control / FSM Bot (C4 Level 3)

```mermaid
stateDiagram-v2
    [*] --> applied : /start
    applied --> screening : модератор смотрит
    applied --> rejected : отклонено
    screening --> approved : одобрено
    approved --> awaiting_payment : выбран тариф
    approved --> rejected : отказ
    awaiting_payment --> paid : PaymentConfirmed
    awaiting_payment --> expired_unpaid : timeout
    paid --> awaiting_interview : InterviewBooked
    awaiting_interview --> interview_done : проведено
    awaiting_interview --> rejected : no-show
    interview_done --> awaiting_law : Основатель одобрил
    awaiting_law --> onboarding_video : LawAccepted
    awaiting_law --> rejected : отказ
    onboarding_video --> active : просмотр завершён
    active --> grace_period : подписка истекла
    grace_period --> inactive : окончание grace
    active --> lifetime_active : Super-админ выдал lifetime
```

14 состояний. Хранение: Redis (горячее) + persist в `users.fsm_state` (на случай рестарта Redis). См. ADR-007.

---

## 6. Deployment Diagram (упрощённый)

```mermaid
flowchart TB
    subgraph VPS[Ubuntu 24.04 LTS VPS]
        nginx[Nginx<br/>:443 TLS]
        subgraph Docker
            api_c[api container<br/>gunicorn + django]
            bot_c[bot container<br/>aiogram]
            worker_c[worker container<br/>APScheduler]
            listener_c[listener container<br/>Telethon]
            pg[postgres:16<br/>+ pgvector]
            redis[redis:7]
        end
    end

    cf[CDN / Cloudflare] --> nginx
    nginx --> api_c
    api_c <--> pg
    api_c <--> redis
    bot_c <--> redis
    worker_c <--> pg
    worker_c <--> redis
    listener_c <--> pg
```

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
