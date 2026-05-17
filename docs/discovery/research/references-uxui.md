---
title: "UX/UI референсы для mini-app «Клуба 33»"
created_by: "Research Agent"
created_at: "2026-05-15"
version: "1.0"
phase: "Discovery"
---

# UX/UI референсы для mini-app «Клуба 33»

> Подбор референсов для Telegram WebApp mini-app: социальный слой (профиль, респекты, звёзды, дар, матчинг, digest, жалобы) и общий visual language.

## 1. Combat-бот (запрошенный референс) — статус исследования

Запрос: «Combat-бот в Telegram, паттерны UX для механики респектов».

**Результат веб-поиска:** в открытых источниках при запросах `Combat Telegram bot респекты`, `Combat бот клуб звёзды`, `Комбат Telegram` не удалось однозначно идентифицировать публичный бот. Найденные похожие сущности:

- **Combot** (`@combot`) — крупный community-management бот; даёт команды `!me` (уровень, репутация, XP), модерацию, антиспам, простую gamification. Скорее всего, это **не** «Combat», но это ближайший аналог по функциям. См. [Combot новости](https://t.me/s/combotnews_ru) и [обзор альтернатив](https://metricgram.com/alternatives/combot).
- **Hamster Kombat** — игровой бот; механики «тапалка» и сезоны, не репутационная система.
- **Iris** (бот для VK/Telegram) — есть iriska-валюта, репутация, кланы, ранги — структурно ближе к нашему scope.

**Действие:** ⚠️ **Требуется уточнение у заказчика:**
- Точное юзернейм Combat-бота (`@?...`) или скриншоты
- Это публичный продукт или внутренний бот другого клуба?
- Какие конкретно экраны/механики служат референсом?

Без этой информации детальный разбор Combat-бота невозможен. Ниже приведены ближайшие альтернативные референсы.

## 2. Принципы UX Telegram Mini Apps (2025)

На основе официальной документации Telegram и анализа лучших практик 2025 года:

### 2.1 «App-in-App» принцип

Mini App должен ощущаться как **продолжение Telegram**, а не как сторонний сайт. Иначе срабатывает «phishing effect» — пользователь подсознательно теряет доверие.

Источник: [Turumburum — Telegram Mini App UX Guide](https://turumburum.com/blog/telegram-mini-app-beyond-the-standard-ui-designing-a-truly-native-experience).

### 2.2 Обязательные технические практики

| Практика | Что делать | Почему |
|---------|------------|--------|
| `WebApp.ready()` сразу при загрузке | Вызвать `Telegram.WebApp.ready()` в первом тике | Убирает белый flash, mini-app сразу отрисовывается |
| Haptic Feedback | `HapticFeedback.impactOccurred('light' \| 'medium')` при тапах, `notificationOccurred('success' \| 'error')` на критичных действиях | Премиальное ощущение, ниже когнитивная нагрузка |
| Theme params | Использовать `Telegram.WebApp.themeParams` (bg_color, text_color, button_color) | Mini-app переключается с dark/light темой Telegram |
| MainButton / BackButton | Использовать нативные кнопки Telegram вместо своих «sticky» CTA | Меньше визуального шума, привычное место |
| `BackButton` управление | Открывать вложенные экраны → показать BackButton, закрывать → спрятать | Естественная навигация |
| Closing confirmation | `enableClosingConfirmation()` на формах с несохранёнными данными | Защита от случайной потери ввода |
| Fullscreen / Landscape (2025) | Поддерживается через новый API | Для геймификации и видео-контента |

Источник: [core.telegram.org/bots/webapps](https://core.telegram.org/bots/webapps), [EJAW Telegram Mini App Development 2025](https://ejaw.net/telegram-mini-app-development-2025/).

### 2.3 Performance

В мессенджере любая задержка >300ms = «сломанный продукт». Цели:
- TTI <1.5s на 4G
- Skeleton screens на всех асинхронных загрузках
- Pre-fetch следующего экрана при наведении/тапе

## 3. Готовые UI-kits и библиотеки (для скорости старта)

| Ресурс | Тип | Применение для «Клуба 33» |
|--------|-----|---------------------------|
| [TelegramUI (React components)](https://github.com/telegram-mini-apps-dev/TelegramUI) | React-библиотека компонентов, повторяющая Telegram | Идеальный fit: Cell, Section, Button, Avatar, Tabbar — всё нативное; матчит наш стек React+Vite |
| [Telegram Mini Apps UI Kit (Figma)](https://www.figma.com/community/file/1348989725141777736/telegram-mini-apps-ui-kit) | Figma community-файл | Передать UI-агенту как starting point дизайн-системы |
| [TON Connect SDK](https://github.com/ton-connect) | Кошельки для USDT(TON) | Прямой fit с нашей оплатой USDT через TON |
| [@twa-dev/sdk](https://www.npmjs.com/package/@twa-dev/sdk) | Type-safe обёртка над `window.Telegram.WebApp` | Рекомендуется к использованию в Coder-фазе |

**Рекомендация:** для миниапа использовать **React + Vite + TelegramUI**. Это решает open question из project-brief о стеке mini-app.

## 4. Референсы экранов по фичам «Клуба 33»

### 4.1 Профиль участника

**Что показывать:**
- Аватар, имя, ник, ниши (роли)
- Звёзды (визуально — 0/1/2/3/4 как у iOS App Store)
- Баланс респектов на отдачу (текущий/30, прогресс-бар)
- Баланс дней (для дарения)
- Дата вступления, дни до окончания подписки
- CTA: «Продлить», «Дать респект», «Подарить день»

**Референсы:**
- **Telegram нативный профиль** — Cell с avatar + verified-badge для звёзд
- **Discord user profile cards** (через [Karma Reborn](https://discord.bots.gg/bots/943726478233841675)) — компактный leaderboard + ранг + точки
- **Patreon tier badges** — визуализация ранга через цветной бейдж
- **Strava badge wall** — стена достижений (для фазы 3+)

**Паттерн:** одна вертикальная карточка-скролл, без табов. Все блоки — `Section + Cell` (TelegramUI). Звёзды и респекты — два главных KPI вверху.

### 4.2 Дать респект

**Flow:**
1. Открыть профиль участника (тап на сообщение → mini-app deep-link) **или** выбрать из списка чата
2. Кнопка «Дать респект» (MainButton)
3. Подтверждение (Telegram confirm) с указанием: «3/3 этому участнику в этом месяце»
4. Haptic `success` + toast «Респект отправлен»
5. Анимация: +1 у получателя, −1 у отправителя

**Референсы:**
- **Discord reactions с кастомным эмодзи** — однотап
- **GitHub reactions** — выбор из палитры
- **Twitter ❤** — мгновенный отклик, haptic feedback

**Антипаттерн:** не показывать модалки с длинной формой «за что респект». В фазе 1 — только клик; в фазе 2+ — опциональный комментарий (200 символов).

### 4.3 Дар времени / `/gift`

**Flow:**
1. Команда `/gift @user` в чате **или** кнопка «Подарить день» в профиле
2. Mini-app открывается на экране подтверждения
3. Показано: остаток у дарителя, что после дара останется ≥30 дней (валидация)
4. Slider: 1–N дней (макс. = баланс - 30; для lifetime — макс. 33/год)
5. MainButton «Подарить N дней»
6. Подтверждение → haptic `success` + сообщение в чат от бота с поздравлением

**Референсы:**
- **TimeRepublik exchange flow** ([timerepublik.com](https://timerepublik.com/)) — простой счётчик часов и кнопка «передать»
- **Telegram Stars gifting** — нативный UX «подарить звёзды», 2 экрана
- **Patreon tier gift** — выбор уровня + получатель

### 4.4 AI-матчинг `/match`

**Flow:**
1. Команда `/match` в чате с ботом **или** кнопка в mini-app
2. Mini-app открывается на «Что ищу?» — короткая форма (1 вопрос, dropdown ниши + textarea «контекст»)
3. Loading state (Claude обрабатывает) — animation 3–5 секунд
4. Результат: список из 3 кандидатов, для каждого — карточка с обоснованием от AI («Почему совпадение»)
5. Кнопка «Связаться» → открывает чат с участником
6. После встречи — push «Как прошла встреча?» с rating 1–5 + опциональный комментарий (для improvement матчинга)

**Референсы:**
- **Lunchclub weekly suggestion** ([medium.com/lunchclub](https://medium.com/lightspeed-venture-partners/lunchclub-the-future-of-professional-networking-429b25d82bb1)) — карточка с reasoning
- **LinkedIn «People you may know»** — но мы избегаем graph-pattern, у нас context-based
- **Tinder swipe** — *не подходит*, у нас не binary и не масштабная база

**Критично:** показывать **reasoning от AI** для каждого матча. Это снимает «black-box» эффект и повышает доверие.

### 4.5 База знаний `/ask` (RAG)

**Flow:**
1. Команда `/ask <вопрос>` в чате с ботом **или** поле ввода в mini-app
2. Loading state
3. Ответ от Claude с цитатами (ссылка → сообщение в чате клуба)
4. Кнопки: 👍 / 👎 / «Уточнить»

**Референсы:**
- **Perplexity** — ответ + footnotes-источники, кликабельные
- **Question Base for Slack](https://www.questionbase.com/resources/blog/rag-bot-slack) — embed в чат
- **n8n RAG chatbot template** ([community.n8n.io](https://community.n8n.io/t/build-a-multichannel-rag-based-ai-chatbot-with-custom-knowledge-base-in-20-mins/70912)) — архитектурный референс

**Критично:** всегда показывать **источники** (timestamp + автор сообщения в чате клуба, если согласие получено через закон клуба). Без атрибуции — недоверие.

### 4.6 Жалоба

**Flow:**
1. Из профиля или сообщения → меню «...» → «Пожаловаться»
2. Mini-app: выбор причины (radio: «спам», «оскорбление», «вне темы», «другое») + textarea
3. Submit → подтверждение, что **получатель не узнает имя отправителя**
4. Уведомление админу в админ-чат

**Референсы:**
- **Telegram native report flow** — 2 экрана, минимум полей
- **Reddit anonymous report** — radio + optional text

### 4.7 Digest (еженедельный)

**Flow:**
1. Каждый понедельник 10:00 МСК → бот шлёт пользователю сообщение с кнопкой «Открыть digest»
2. Mini-app: лента карточек — топ-обсуждения, новые участники, моя статистика, AI-инсайты
3. Опционально: «Возможно вам интересно» — матчи и события

**Референсы:**
- **Notion daily digest emails** — структура карточек
- **GitHub weekly digest** — секции с типизацией («Top discussions», «Your activity»)
- **Substack newsletter view** — длинная лента + табы

### 4.8 Onboarding (после оплаты + интервью + закона клуба)

**Flow:**
1. Welcome screen с именем основателя и ключевыми правилами
2. Заполнить ниши (1–3 из списка) → влияет на матчинг
3. Опционально: краткое «обо мне» (для RAG-контекста при матчинге)
4. CTA: «Перейти в чат клуба» (deep-link на invite)

**Референсы:**
- **Slack workspace onboarding** — 3 экрана, prepopulated
- **Notion onboarding** — minimal, прогресс-индикатор
- **Telegram Premium activation** — celebration screen + features

## 5. Visual language

### 5.1 Цвета и стиль

- **Базовый:** наследовать `Telegram.WebApp.themeParams` (без override). Светлая/тёмная — автоматически.
- **Акцент клуба:** один primary-цвет (предложить UI-агенту: тёплый золотой/оранжевый под «Клуб 33», как отсылка к Юпитеру/33 — *согласовать с заказчиком*).
- **Звёзды:** золотой (#F5A623), деградация — серый.
- **Респект:** зелёный (#0F9D58) или акцент клуба.
- **Тревога / жалобы / cooldown:** красный, но мягкий (#E84F4F).

### 5.2 Типографика

- **Системный шрифт Telegram** — `-apple-system, BlinkMacSystemFont, "SF Pro Text", ...`
- Размеры: 17px body, 22px title, 13px caption (повторяет iOS Telegram)

### 5.3 Иконки

- **Tabler Icons** или **Lucide** (line-style, хорошо смотрятся и в light, и в dark)
- Звёзды — заполненная/полузаполненная для уровней 0–4

### 5.4 Анимации

- 200–250 ms на переходы; cubic-bezier(0.25, 0.1, 0.25, 1)
- На респект — confetti или короткая пульсация (не более 600ms)
- На матч — fade-in карточек поочерёдно (stagger 80ms)

## 6. Что переиспользовать для «Клуба 33» — итоговая таблица

| Элемент | Источник | Использование |
|---------|----------|---------------|
| Архитектура UI компонентов | TelegramUI (React) | Базовый kit для mini-app |
| Стартовая палитра | Telegram themeParams + 1 accent | Visual identity |
| Паттерн профиля | Telegram-native Cell/Section + Discord karma cards | Профиль участника |
| Reasoning-карточки матчинга | Lunchclub | `/match` результаты |
| Footnotes-источники в ответах | Perplexity | `/ask` RAG-ответы |
| Anonymous report flow | Telegram native + Reddit | Жалобы |
| Time-banking exchange UI | TimeRepublik | Дар времени |
| Daily digest карточки | Notion / GitHub digest | `/digest` |
| Haptic & MainButton дисциплина | Telegram Mini App Guide 2025 | Все экраны |
| Skeleton-screens | Best practice | Все async-загрузки |

## 7. Открытые UX-вопросы для UI-agent / заказчика

1. **Combat-бот:** запросить точную ссылку/скриншоты у заказчика. Без этого ключевой референс остаётся непроверенным.
2. **Accent-цвет клуба:** золотой как у звёзд, или собственный (бренд-цвет)?
3. **Confetti на респект:** уместно ли? Альтернатива — мягкая пульсация.
4. **Reasoning от AI в матчинге:** показывать всем или только премиум-тарифу? (Сейчас в scope только один тариф 6/12mo + lifetime.)
5. **Mini-app vs deep-link из чата для дара/респекта:** для скорости — на старте всё через mini-app; в фазе 3 добавляем реакцию-стикер как fast-path для респекта.

## 8. Источники

- [core.telegram.org/bots/webapps — официальная документация](https://core.telegram.org/bots/webapps)
- [Turumburum — Telegram Mini App UX Guide 2025](https://turumburum.com/blog/telegram-mini-app-beyond-the-standard-ui-designing-a-truly-native-experience)
- [BAZU — Best practices for UI/UX in Telegram Mini Apps](https://bazucompany.com/blog/best-practices-for-ui-ux-in-telegram-mini-apps/)
- [Merge — How to build a Telegram mini app](https://merge.rocks/blog/how-to-build-a-telegram-mini-app-your-telegram-mini-apps-guide)
- [DEV.to — Telegram Mini App Template 2025](https://dev.to/victorgold/telegram-mini-app-template-how-to-build-and-launch-faster-in-2025-gbc)
- [Figma — Telegram Mini Apps UI Kit](https://www.figma.com/community/file/1348989725141777736/telegram-mini-apps-ui-kit)
- [GitHub — TelegramUI React Library](https://github.com/telegram-mini-apps-dev/TelegramUI)
- [Createbytes — Telegram UI/UX Deep Dive](https://createbytes.com/insights/telegram-ui-ux-review-design-analysis)
- [EJAW — Telegram Mini App Development Guide 2025](https://ejaw.net/telegram-mini-app-development-2025/)
- [Combot новости (RU)](https://t.me/s/combotnews_ru)
- [Metricgram — Combot alternatives](https://metricgram.com/alternatives/combot)
- [Lunchclub overview by Lightspeed](https://medium.com/lightspeed-venture-partners/lunchclub-the-future-of-professional-networking-429b25d82bb1)
- [Question Base — RAG bot for Slack](https://www.questionbase.com/resources/blog/rag-bot-slack)
- [n8n community — Multichannel RAG chatbot template](https://community.n8n.io/t/build-a-multichannel-rag-based-ai-chatbot-with-custom-knowledge-base-in-20-mins/70912)
- [Karma Reborn — Discord bot](https://discord.bots.gg/bots/943726478233841675)
- [TimeRepublik](https://timerepublik.com/)

---

*Документ создан: Research Agent | Дата: 2026-05-15*
