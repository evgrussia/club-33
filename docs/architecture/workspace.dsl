/*
 * Клуб 33 — Structurizr DSL (C4 модель)
 * Created by: Architect Agent
 * Created at: 2026-05-16
 * Version: 1.0
 * Phase: Architecture
 */

workspace "Клуб 33" "Telegram-бот + mini-app + web-админка для закрытого клуба с подпиской, социальным слоем и AI-сервисами" {

    model {
        # === Persons ===
        candidate     = person "Кандидат" "Подал заявку через Google-форму, проходит воронку"
        member        = person "Участник" "Имеет активную платную подписку (6/12 мес)"
        lifetime      = person "Lifetime-участник" "Бессрочный доступ + годовой бюджет 33 дня на дарение"
        moderator     = person "Модератор" "Обработка заявок, жалоб, респектов, ролей"
        support       = person "Support-админ" "Поддержка, СБП-сверка, разбор incident'ов"
        superadmin    = person "Super-админ" "Финансы, lifetime, конвертер USD→дни"
        founder       = person "Основатель" "Интервью, финальное одобрение, lifetime-выдача"

        # === Main Software System ===
        club33 = softwareSystem "Клуб 33" "Платформа закрытого клуба" {

            # --- Containers ---
            botApi = container "Telegram Bot" "FSM-бот, 14 состояний, команды /start/respect/gift/burn/ask/match/digest" "Python 3.12 + aiogram 3.x" "Bot"
            listener = container "Listener Bot" "Индексация чата клуба для AI (с согласия)" "Python 3.12 + Telethon (MTProto)" "Bot"
            miniapp = container "Mini-app SPA" "Telegram WebApp: профиль, респекты, дары, /match, /ask, digest, жалобы" "React 18 + Vite 6 + TelegramUI" "Web Browser"
            admin   = container "Web Admin SPA" "Пользователи, заявки, финансы, воронка, экспорт, дашборды" "React 18 + Vite 6" "Web Browser"
            api     = container "API" "REST API + бизнес-логика всех bounded contexts" "Django 5 + DRF + Python 3.12" "Application"
            worker  = container "Worker" "APScheduler: digest, баланс респектов, напоминания, cron-задачи" "Python 3.12 + APScheduler" "Background Jobs"
            db      = container "Database" "OLTP + pgvector для embeddings 1536-dim" "PostgreSQL 16 + pgvector" "Database"
            cache   = container "Cache" "Сессии, FSM-state, idempotency, rate-limits" "Redis 7" "Cache"
        }

        # === External Systems ===
        telegram     = softwareSystem "Telegram" "Мессенджер, Bot API + Mini-App + MTProto" "External"
        yookassa     = softwareSystem "ЮKassa" "Платёжный шлюз для RUB и СБП-инвойсов" "External"
        usdtProvider = softwareSystem "USDT-провайдер" "TRC20/TON-шлюз для крипто-платежей" "External"
        forexApi     = softwareSystem "Forex API (ЦБ РФ)" "Курс USD→RUB на момент создания инвойса" "External"
        anthropic    = softwareSystem "Anthropic API" "Claude (haiku/sonnet/opus) + embeddings для матчинга, RAG, digest" "External"
        googleForm   = softwareSystem "Google Forms" "Форма подачи заявки кандидата" "External"

        # === Relationships: Users → Surfaces ===
        candidate    -> telegram "Заполняет заявку, общается с ботом" "HTTPS"
        member       -> telegram "Использует бот и mini-app" "HTTPS"
        lifetime     -> telegram "Использует бот и mini-app" "HTTPS"
        founder      -> telegram "Проводит интервью, выдаёт одобрение" "HTTPS"
        moderator    -> admin "Управляет заявками, жалобами, респектами" "HTTPS"
        support      -> admin "Поддержка, ручная сверка СБП" "HTTPS"
        superadmin   -> admin "Финансы, lifetime, конвертер" "HTTPS"

        # === Telegram → Internal ===
        telegram -> botApi   "Webhook обновлений Bot API" "HTTPS"
        telegram -> miniapp  "Открывает WebApp с init_data" "HTTPS"
        telegram -> listener "Поток сообщений из чата клуба" "MTProto"
        candidate -> googleForm "Заполняет заявку" "HTTPS"
        googleForm -> api "Webhook + ручной импорт заявок" "HTTPS"

        # === Frontend → API ===
        miniapp -> api "REST API + JWT (Telegram init_data)" "JSON/HTTPS"
        admin   -> api "REST API + JWT (логин/пароль + RBAC)" "JSON/HTTPS"
        botApi  -> api "Внутренние вызовы бизнес-логики" "HTTP/internal"

        # === API → Data ===
        api    -> db    "Читает/пишет данные, embeddings (pgvector)" "SQL"
        api    -> cache "FSM-state, sessions, rate-limits, idempotency keys" "Redis Protocol"
        worker -> db    "Cron-задачи: digest, баланс, напоминания" "SQL"
        worker -> cache "Locks, schedules" "Redis Protocol"
        worker -> api   "Внутренние вызовы (опционально)" "HTTP/internal"
        listener -> db  "Индексирует сообщения, эмбеддинги в pgvector" "SQL"

        # === API → External ===
        api -> telegram     "Отправка сообщений, invite-ссылок, FSM-управление" "HTTPS"
        api -> yookassa     "Создание платежей (RUB/СБП), webhook" "HTTPS"
        api -> usdtProvider "Создание адресов, проверка транзакций, webhook" "HTTPS"
        api -> forexApi     "Запрос курса USD→RUB при создании инвойса" "HTTPS"
        api -> anthropic    "Claude haiku/sonnet/opus + embeddings" "HTTPS"

        worker -> telegram  "Cron-уведомления (напоминания, digest)" "HTTPS"
        worker -> anthropic "Генерация digest, переиндексация KB" "HTTPS"

        # === Webhooks ===
        yookassa     -> api "Webhook оплаты" "HTTPS"
        usdtProvider -> api "Webhook транзакции" "HTTPS"
    }

    views {
        systemContext club33 "SystemContext" {
            include *
            autoLayout lr
            description "Контекст системы «Клуб 33» с внешними участниками и провайдерами"
        }

        container club33 "Containers" {
            include *
            autoLayout tb
            description "Контейнерная диаграмма: bot, listener, mini-app, admin, api, worker, db, cache"
        }

        theme default
    }
}

# Документ создан: Architect Agent | Дата: 2026-05-16
