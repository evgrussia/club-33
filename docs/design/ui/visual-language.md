---
title: "Клуб 33 — Visual Language"
created_by: "UI Agent"
created_at: "2026-05-15"
version: "1.0"
phase: "Design"
---

# Visual Language «Клуба 33»

> Иллюстрации, иконография, фото, анимации, состояния — единый визуальный язык для mini-app и web-админки.

---

## 1. Общий принцип

**Тёплый минимализм.** Клуб 33 — для зрелых людей. Визуал не должен быть игровым (Hamster Kombat), не должен быть «корпоративным» (Notion для бизнеса), не должен быть холодным (LinkedIn).

Опорные слова: **тепло, спокойствие, признание, ценность времени, человечность**.

Опорные цвета: золотой акцент `#C9A24A` + нейтральная Telegram-палитра (через `themeParams`).

Опорные метафоры: **звезда**, **рукопожатие**, **песочные часы**, **пульс**.

---

## 2. Иллюстрации

### 2.1 Стиль

- **Геометрический line-style.** Иллюстрации = «увеличенные иконки»: один stroke 2-3px, минимум заливки, currentColor + один акцент (золотой).
- **Изометрия / плоские.** Никаких 3D-рендеров, никаких пастельных персонажей (анти-Notion).
- **Без лиц.** Силуэты, абстракции, объекты. Снижает «шум» и расовый/гендерный bias.

### 2.2 Где используются

| Место | Иллюстрация | Метафора |
|-------|-------------|----------|
| Welcome onboarding | Открытая дверь + золотая звезда внутри | «Тебя ждут» |
| Empty State «Нет матчей» | Две стрелки, расходящиеся | «Пока не сошлись» |
| Empty State «Нет жалоб» | Спокойное озеро / линия горизонта | «Тишина — это хорошо» |
| Empty State «Нет респектов получено» | Пустые ладони / открытая ладонь | «Скоро придут» |
| Error 500 | Сломанная цепь / разорванная линия | «Связь потеряна» |
| Error Network | Облако с молнией | «Нет сети» |
| Payment Pending | Песочные часы в кругу | «Идёт подтверждение» |
| Payment Success | Звезда с галочкой | «Готово» |
| Subscription Expired | Закрытая дверь + ключ рядом | «Можно открыть снова» |
| Onboarding «Закон клуба» | Свиток + перо | Старшинство договорённости |

### 2.3 Спецификация SVG

- ViewBox: 200×160 (4:3) или 200×200 (1:1) — фиксированные размеры для предсказуемости.
- Stroke: 2px, `round` join, `round` cap.
- Цвет: `currentColor` (наследует) + опционально `var(--accent)` для одной выделенной детали.
- Без растровой графики.
- Файлы — в `frontend/src/assets/illustrations/*.svg`, импорт как React-компонент через vite-plugin-svgr.

### 2.4 Do / Don't

- ✅ Один акцентный цвет на иллюстрацию (золото).
- ✅ Простая, читаемая на 200×200.
- ❌ Реалистичные люди / лица.
- ❌ Сложные градиенты (только золотой gradient lifetime).
- ❌ Эмодзи как замена иллюстрациям в крупных empty-state.

---

## 3. Фотография

**В фазе 1–3 фотография не используется.**

Причины:
- Mini-app — функциональный инструмент, фото = шум.
- Закрытый клуб ≠ публичный продукт, маркетинговые фото неуместны.
- Только пользовательские аватары (приходят из Telegram).

**Исключения (опц., вне MVP):**
- Лендинг клуба (если появится) — может использовать абстрактные фото природы / архитектуры (тёплая палитра, размытие).

---

## 4. Иконография — детально

### 4.1 База: Tabler Icons

[Tabler Icons](https://tabler-icons.io/) — line-style, 24×24 grid, stroke 2, MIT.

Используем стандартные имена: `IconHome`, `IconUser`, `IconBell`, `IconSearch`, `IconChevronRight`, `IconX`, `IconCheck`, `IconPlus`, `IconMinus`, `IconArrowUp`, `IconArrowDown`, `IconCalendar`, `IconCreditCard`, `IconSettings`, `IconLogout`.

### 4.2 Кастомные иконки клуба

Рисуем сами в едином стиле (24×24, stroke 2, currentColor):

#### `icon-star-filled` / `icon-star-half` / `icon-star-empty`

Стандартная 5-конечная звезда. Filled — `fill: currentColor`. Half — `clip-path: inset(0 50% 0 0)`. Используется в `<Star />`.

#### `icon-respect`

Стилизованное рукопожатие — две руки, образующие фигуру в круге. **Метафора:** взаимное признание.

#### `icon-respect-given`

Та же иконка + стрелка ↑ снизу. Используется в счётчике отданных респектов.

#### `icon-day`

Песочные часы (классические). Метафора времени, которое можно подарить.

#### `icon-gift-day`

Песочные часы + стрелка ↗ (передача). Используется в `/gift`.

#### `icon-lifetime`

Звезда внутри кольца (∞-loop). Золотой gradient. Используется в `<LifetimeBadge />`.

#### `icon-pulse`

Линия ЭКГ (3 пика). Метафора живости клуба. Используется в digest.

#### `icon-complaint`

Восклицательный знак в круге, outline. Не агрессивный (не красный треугольник).

#### `icon-match`

Два полукруга, сцепляющиеся в круг (как пазлы). Метафора совпадения.

#### `icon-kb-quote`

Кавычка с подчёркиванием. Метафора цитаты-источника.

### 4.3 Do / Don't (иконы)

- ✅ Один stroke 2px round.
- ✅ Иконка читаема в 16, 20, 24, 28px.
- ✅ `aria-label` обязателен если иконка — единственный child кнопки.
- ❌ Mix filled + outline в одном экране.
- ❌ Цветные иконки (только currentColor + опционально золото).
- ❌ Эмодзи как замена.

---

## 5. Микро-анимации

### 5.1 Принципы

- Анимация подчёркивает действие, не отвлекает.
- Длительность **150–400ms**, easing `cubic-bezier(0.25, 0.1, 0.25, 1)` по умолчанию.
- Уважаем `prefers-reduced-motion: reduce` — все анимации схлопываются до `instant`.

### 5.2 Каталог анимаций

| Событие | Анимация | Duration | Easing | Haptic |
|---------|----------|----------|--------|--------|
| Hover кнопки (desktop) | bg.color | 150ms | standard | — |
| Tap кнопки (mobile) | scale 0.97 | 100ms | standard | light |
| Press Cell | bg.tertiary | 150ms | standard | — |
| Sheet open | translateY from 100%→0, overlay opacity 0→1 | 250ms | decelerate | light |
| Sheet close | reverse | 200ms | standard | — |
| Modal open | scale 0.96→1 + opacity 0→1 | 200ms | decelerate | — |
| Toast appear | translateY −20 → 0 + fade | 250ms | decelerate | — |
| Toast disappear | reverse | 200ms | accelerate | — |
| Респект отправлен | pulse: scale 1→1.08→1 у получателя + текст «+1 респект» fade-in 200ms | 300ms | decelerate | success |
| Звезда повышается (0→1, 1→2...) | scale 1→1.4→1 + glow 200ms | 400ms | decelerate | success |
| Match-карточки появляются | stagger fade-in + slideUp 8px | 250ms × N (80ms gap) | standard | — |
| KB-цитата раскрывается | height 0→auto + fade-in | 200ms | standard | — |
| Skeleton pulse | opacity 0.6 ↔ 1 loop | 1500ms | sinusoidal | — |
| Tab переключение | underline slide + content fade | 200ms | standard | light |
| Onboarding step | slide-right (next), slide-left (back) | 250ms | standard | — |
| Subscription expiring banner | gentle shake 1× при первом показе | 400ms | bouncy | — |

### 5.3 Что мы НЕ делаем

- ❌ **Confetti** на респект — слишком игриво (решение vs reference §5.4).
- ❌ Параллакс / scroll-triggered анимации.
- ❌ Loop-анимации >2 секунд (отвлекают).
- ❌ Анимации длиннее 500ms (кроме skeleton-pulse).
- ❌ Цветные glow-эффекты (кроме одного — звезда повышается).

---

## 6. Состояния и переходы (state choreography)

### 6.1 Async-загрузки

```
Initial → Skeleton (показывается через 150ms если запрос не вернулся) → Content
       └→ Error (если запрос упал) → ErrorState с Retry
```

**Правило 150ms:** если данные приходят быстрее, skeleton не показываем (избегаем мерцания).

### 6.2 Submit-флоу (кнопка с действием)

```
Idle → Pressed (scale 0.97) → Submitting (loading=true, текст «Отправка...»)
     → Success (haptic + Toast + animation) → Idle (через 1s)
     или → Error (haptic + Toast + button shake) → Idle
```

### 6.3 Sheet/Modal flow

```
Closed → Opening (animation 250ms) → Open
       → Closing (animation 200ms) → Closed
```

`enableClosingConfirmation()` если есть несохранённые данные.

### 6.4 RespectButton flow (особо ответственно)

```
Available (default)
  └→ tap (haptic.medium) → Submitting (spinner)
     └→ success → Given (pulse + «+1 респект» fade-in + Toast.success + haptic.success)
        └→ через 1.5s → Returning to "balance −1" state (теперь disabled если 3/3)
     └→ error → shake + Toast.error + haptic.error → Available
```

### 6.5 Match-результат flow

```
Trigger /match → Loading (skeleton 3 карточек, текст «Claude подбирает...»)
  └→ Result (3 MatchCard, stagger appear 80ms gap)
  └→ Empty (нет матчей, EmptyState с suggest «Дополни профиль»)
  └→ Error (ErrorState с Retry)
```

### 6.6 Onboarding (после оплаты)

```
Step 1: Welcome (display-text + иллюстрация двери)
  → swipe/Next →
Step 2: Закон клуба (текст + textarea для ввода фразы)
  → submit «Принять закон» (требует точного ввода) →
Step 3: Выбор ниш (1-3 из списка, multi-select tags)
  → Next →
Step 4: Краткое «обо мне» (textarea, опц., 200 chars)
  → Finish →
Step 5: Celebration (звезда с галочкой + CTA «Перейти в чат клуба»)
```

Между шагами — slide-right 250ms. Progress dots внизу.

---

## 7. Тёмная тема

- Mini-app переключается **автоматически** через `themeParams`.
- Web-админка — toggle в настройках (default = system).
- **Тени в dark заменяются на borders** (тени не читаются).
- Иллюстрации — `currentColor` адаптируется, акцент золотой остаётся.
- Контраст проверяется отдельно для каждой темы.

---

## 8. Брендовые «фирменные» элементы

### 8.1 Золотая звезда

Главный элемент идентичности. Используется:
- В аватарах с высоким уровнем (звёзды-бейдж).
- В лого «Клуб 33» (опц., если будет лого).
- В celebration-моментах (повышение, оплата подтверждена, lifetime выдан).
- На welcome-экране onboarding.

### 8.2 Шеврон золотой обводки lifetime

Аватар lifetime-участника имеет **золотое кольцо** (2px ring, `colors.lifetime_gradient`). Это визуально отличает их без надписи.

### 8.3 «33» в типографике

Число 33 в крупных контекстах (welcome, годовой бюджет lifetime) можно отрисовывать **golden gradient** + bold 700. Используется точечно (не в каждом тексте).

---

## 9. Запреты на визуальном уровне

- ❌ Скевоморфизм (3D-кнопки, тени-как-объём).
- ❌ Neumorphism.
- ❌ Glassmorphism (frosted-glass) — конфликт с Telegram-плоскостью.
- ❌ Яркие неоновые цвета.
- ❌ Большие пастельные иллюстрации (анти-Notion).
- ❌ Stock-фото людей.
- ❌ Анимированные эмодзи в UI (используем Lottie только в иллюстрациях onboarding).

---

## 10. Чек-лист дизайна экрана

При создании/проверке экрана убедиться:

- [ ] Используются ТОЛЬКО токены из `design-tokens.yaml`.
- [ ] Контраст текста ≥4.5:1 (или ≥3:1 для крупного 18px/600).
- [ ] Hit-area ≥44px на mobile.
- [ ] Состояния: default + loading + empty + error реализованы.
- [ ] `aria-label` на icon-only кнопках.
- [ ] Анимации уважают `prefers-reduced-motion`.
- [ ] Skeleton-screens на async, не spinner-страница.
- [ ] Mini-app: использован MainButton / BackButton (не свой sticky).
- [ ] Mini-app: Haptic в нужных местах.
- [ ] Темизация работает в Telegram light и dark.

---

## 11. Связанные документы

- `design-system.md` — философия, brand.
- `design-tokens.yaml` — токены.
- `component-library.md` — каталог.
- `component-stories-spec.md` — спецификация stories.

---

*Документ создан: UI Agent | Дата: 2026-05-15*
