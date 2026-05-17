---
title: "Клуб 33 — Component Stories Specification"
created_by: "UI Agent"
created_at: "2026-05-15"
version: "1.0"
phase: "Design"
---

# Component Stories Specification

> Спецификация stories для Storybook (обязательно по `.claude/rules/08-interface-compliance.md`).
> Это **источник истины** для `frontend/src/stories/**/*.stories.jsx` в Phase 6.
>
> Для каждого компонента указаны: ВСЕ states которые должны быть покрыты, props с типами,
> usage guidelines, visual contract.

## Общие правила

Каждая story должна:
- Иметь `title` категории: `Design System/{Name}` или `Components/{Name}` или `Domain/{Name}` или `Admin/{Name}`.
- Иметь `component` (импорт компонента).
- Покрывать минимум: **Default, Loading, Error, Empty, Disabled, AllVariants** (если применимо).
- Иметь `argTypes` со всеми props.
- Иметь description компонента.

---

## Категория: Design System (Atomic)

### Button

**Storybook title:** `Design System/Button`

**Required stories:**
- `Default` — `{ variant: 'primary', size: 'md', children: 'Подать заявку' }`
- `Primary` — `{ variant: 'primary' }`
- `Secondary` — `{ variant: 'secondary' }`
- `Ghost` — `{ variant: 'ghost' }`
- `Danger` — `{ variant: 'danger' }`
- `Sizes` — render row of sm/md/lg
- `Loading` — `{ loading: true, children: 'Загрузка...' }`
- `Disabled` — `{ disabled: true }`
- `WithLeftIcon` — `{ leftIcon: <Icon name="plus"/>, children: 'Добавить' }`
- `WithRightIcon` — `{ rightIcon: <Icon name="chevron-right"/> }`
- `FullWidth` — `{ fullWidth: true }`
- `AllVariants` — grid 4×3 (variants × states)

**Props (TS):**
```ts
variant?: 'primary' | 'secondary' | 'ghost' | 'danger'
size?: 'sm' | 'md' | 'lg'
loading?: boolean
disabled?: boolean
fullWidth?: boolean
leftIcon?: ReactNode
rightIcon?: ReactNode
haptic?: 'light' | 'medium' | 'heavy' | 'none'
onClick: (e: MouseEvent) => void
children: ReactNode
```

**Usage:**
- ✅ Использовать для inline-действий в Card / Sheet / Form.
- ✅ `primary` — одна на экран (главный CTA). Для mini-app главный CTA — нативный MainButton.
- ❌ Не использовать `danger` для обратимых действий (выбирай `secondary` + confirm).
- ❌ Не размещать два `primary` подряд.

**Visual contract:**
- Primary: фон `colors.primary`, текст `colors.text_on_primary`, radius `radii.md`.
- Hover (desktop): фон `primary_hover`.
- Loading: spinner 16px + текст становится opacity 0.7.
- Focus-ring: 2px accent.

---

### Input

**Storybook title:** `Design System/Input`

**Required stories:**
- `Default`, `Focused`, `Filled`, `Error`, `Disabled`, `WithLabel`, `WithHint`, `WithPrefix`, `WithClear`, `Search`, `Password`, `AllSizes` (sm/md/lg)

**Props:** см. `component-library.md §1.2`.

**Usage:**
- ✅ Всегда с label или явным placeholder.
- ✅ Error-сообщение под полем, не tooltip.
- ❌ Не использовать как Textarea (для длинных текстов).

**Visual contract:** border `1px solid colors.border`, focus → `colors.accent`, error → `colors.danger` + error-text 13px.

---

### Textarea

**Storybook title:** `Design System/Textarea`

**Required stories:**
- `Default`, `Focused`, `Filled`, `Error`, `Disabled`, `WithCounter`, `MaxLengthReached`

**Usage:**
- ✅ Counter обязателен если есть maxLength.
- ❌ Не более 6 строк по умолчанию.

**Visual contract:** same as Input, `min-height` = 3 rows.

---

### Checkbox

**Storybook title:** `Design System/Checkbox`

**Required stories:**
- `Default`, `Checked`, `Indeterminate`, `Disabled`, `WithLabel`, `WithDescription`

---

### Switch

**Storybook title:** `Design System/Switch`

**Required stories:**
- `Default` (off), `Checked` (on), `Disabled`, `WithLabel`, `WithDescription`

**Visual contract:** iOS-style toggle, accent при on.

---

### Avatar

**Storybook title:** `Design System/Avatar`

**Required stories:**
- `Default` (image), `Initials` (без фото), `Placeholder` (silhouette), `AllSizes` (xs/sm/md/lg/xl), `WithStarsBadge` (показ 0/1/2/3/4), `WithLifetimeBadge`, `WithOnlineBadge`, `WithVerifiedBadge`

**Visual contract:** circle, кольцо-обводка для lifetime (золотой gradient).

---

### Badge

**Storybook title:** `Design System/Badge`

**Required stories:**
- `Default`, `Primary`, `Accent`, `Success`, `Warning`, `Danger`, `Neutral`, `Lifetime` (gradient), `WithIcon`, `Removable`, `AllVariants`

---

### Tag

**Storybook title:** `Design System/Tag`

**Required stories:**
- `Default`, `Selected`, `Removable`, `Disabled`, `AllNiches` (демо ролей: «Маркетинг», «AI/ML», «Финансы»...)

---

### Star

**Storybook title:** `Design System/Star`

**Required stories:**
- `Level0` (все пустые), `Level1`, `Level2`, `Level3`, `Level4`, `WithLabel` («3★»), `AllSizes`, `Animated` (демо повышения)

**Visual contract:** filled = `colors.star_filled`, empty = `colors.star_empty`, 16/20/24px.

---

### Icon

**Storybook title:** `Design System/Icon`

**Required stories:**
- `Default`, `AllSizes` (16/20/24/28), `CustomColor`, `TablerIcons` (выборка), `ClubIcons` (все кастомные: respect, day, gift-day, lifetime, pulse, complaint, match, kb-quote)

---

### Spinner

**Storybook title:** `Design System/Spinner`

**Required stories:**
- `Default`, `Small`, `Medium`, `Large`, `WithLabel`, `CurrentColor`

---

## Категория: Cells & Sections

### Cell

**Storybook title:** `Design System/Cell`

**Required stories:**
- `Default`, `WithBefore` (Avatar/Icon), `WithAfter` (Badge/chevron), `Multiline` (title+subtitle+description), `Pressed`, `Disabled`, `Destructive` («Выйти из клуба»), `AsLink` (с onClick + chevron)

**Visual contract:** min-height 48px, hover-bg `bg.tertiary`, separator снизу `1px solid border`.

---

### Section

**Storybook title:** `Design System/Section`

**Required stories:**
- `Default` (без header/footer), `WithHeader`, `WithFooter`, `WithBoth`, `MultipleCells` (3-5 cells внутри)

---

### ListItem / MenuItem

**Storybook title:** `Design System/ListItem`, `Design System/MenuItem`

**Required stories:**
- `Default`, `Selected` (для MenuItem), `WithCount` (badge с числом), `Disabled`

---

## Категория: Composite

### Card

**Storybook title:** `Components/Card`

**Required stories:**
- `Compact`, `Default`, `Feature` (с золотой обводкой), `Loading` (skeleton inside), `Error` (внутри inline error), `Clickable` (hover/press), `AllVariants`

---

### Sheet

**Storybook title:** `Components/Sheet`

**Required stories:**
- `Default`, `Fullscreen`, `Confirm` (короткий), `WithLongContent` (scroll), `WithoutHandle`, `Loading` (skeleton inside)

**Visual contract:** rounded-top 16px, handle 4×40px серый, overlay `colors.overlay`.

---

### Modal

**Storybook title:** `Components/Modal`

**Required stories:**
- `Default`, `Small`, `Medium`, `Large`, `WithFooter` (actions), `Loading`, `WithoutCloseButton`

---

### Toast

**Storybook title:** `Components/Toast`

**Required stories:**
- `Success`, `Error`, `Info`, `Warning`, `WithAction`, `LongMessage`, `Stack` (несколько подряд)

---

### Alert

**Storybook title:** `Components/Alert`

**Required stories:**
- `Info`, `Warning`, `Danger`, `Success`, `WithTitle`, `WithAction`, `Dismissible`, `AllVariants`

---

## Категория: Domain (механики клуба)

### RespectButton

**Storybook title:** `Domain/RespectButton`

**Required stories:**
- `Available` — `{ givenToThisUser: 0, balance: 27 }`
- `OneGiven` — `{ givenToThisUser: 1 }`
- `TwoGiven` — `{ givenToThisUser: 2 }`
- `LimitOnUser` — `{ givenToThisUser: 3 }` (disabled + tooltip «лимит 3/3 этому участнику в этом месяце»)
- `LimitTotal` — `{ balance: 0 }` (disabled + alert «закончились респекты на месяц»)
- `Pending` — `{ submitting: true }`
- `Given` — после успеха (pulse-анимация + «+1 респект»)
- `Cooldown` — между месяцами (показывает время до сброса)
- `Compact` — `{ variant: 'compact' }`

**Props:**
```ts
recipientId: string
givenToThisUser: 0 | 1 | 2 | 3
balance: number               // 0-30
onSubmit: () => Promise<void>
variant?: 'default' | 'compact'
```

**Usage:**
- ✅ Главный способ дать респект в mini-app.
- ✅ Haptic medium на тап, success на подтверждение.
- ❌ Не показывать модалку «за что респект» в фазе 1 (только однотап).

**Visual contract:** primary variant, иконка рукопожатия слева, при `given` — pulse 300ms.

---

### GiftSlider

**Storybook title:** `Domain/GiftSlider`

**Required stories:**
- `Default` — `{ balance: 90, value: 1 }`
- `AtMin` — `{ value: 1 }`
- `AtMax` — `{ value: 60, balance: 90 }` (60 = 90-30)
- `Invalid` — `{ value: 70, balance: 90 }` (нарушение остатка ≥30)
- `Lifetime` — `{ maxGift: 33, value: 5 }` (другая логика)
- `WithCostPreview` — `{ costPreviewUsd: 12.5 }`

---

### MatchCard

**Storybook title:** `Domain/MatchCard`

**Required stories:**
- `Default` — полная карточка с reasoning
- `Loading` — skeleton (Avatar circle + 3 lines text)
- `WithMatchScore` — `{ matchScore: 87 }`
- `Contacted` — `{ contacted: true }` (CTA становится `secondary`)
- `WithRating` — после контакта показывает rating 1-5
- `LongReasoning` — текст 6+ предложений (truncate + «Подробнее»)
- `Empty` — общий EmptyState когда нет матчей

**Props:** см. `component-library.md §4.3`.

**Usage:**
- ✅ Reasoning от Claude **обязателен** (правило прозрачности AI).
- ❌ Не показывать reasoning короче 30 символов (значит, AI не справился — show retry).

**Visual contract:** Avatar (md) + name + Star уровень → теги-ниши → reasoning внутри блока с `border-left: 3px solid accent` → CTA «Связаться» fullWidth.

---

### KBAnswerCard

**Storybook title:** `Domain/KBAnswerCard`

**Required stories:**
- `Loading` — skeleton с пульсацией (важно: пользователь ждёт ответ Claude)
- `Default` — answer + 2-3 цитаты
- `LongAnswer` — markdown с заголовками и списком
- `WithCitations` — 5+ цитат (раскрытие списка)
- `Rated` — после клика 👍 или 👎
- `NeedsClarification` — компактный fallback «Нужно уточнить вопрос»
- `Empty` — Claude не нашёл ответа (suggest /match)
- `Error` — ошибка inference

**Usage:**
- ✅ Источники **обязательны** (даже если 1).
- ❌ Не показывать ответ без citations (доверие).

**Visual contract:** answer markdown + блок «Источники» снизу с нумерованными ссылками `[1]`, `[2]`. Клик → раскрывает snippet + deep-link в чат.

---

### ComplaintForm

**Storybook title:** `Domain/ComplaintForm`

**Required stories:**
- `Default` — пустая форма
- `WithReasonSelected` — выбран spam
- `WithComment` — заполнен textarea
- `Validating` — submit нажат, идёт проверка
- `Submitting` — отправляется
- `Success` — confirmation screen «Жалоба отправлена, получатель не узнает»
- `Error` — ошибка отправки
- `MaxLength` — counter 500/500

**Usage:**
- ✅ Обязательный alert «Получатель не узнает твоё имя» **до** submit.
- ❌ Submit-CTA — `danger` variant.

---

### BookingSlot

**Storybook title:** `Domain/BookingSlot`

**Required stories:**
- `Available`, `Selected`, `BookedByMe`, `Taken`, `Past`, `LoadingList` (skeleton 5 slots), `EmptyList` (нет слотов на неделю)

---

### FunnelChart

**Storybook title:** `Domain/FunnelChart`

**Required stories:**
- `Default` — 5 stages
- `Loading` — skeleton bars
- `Empty` — нет данных за период
- `Error` — ошибка загрузки
- `WithDropoffHighlight` — где-то >50% drop
- `Clickable` — каждый stage — onClick → drill-down

---

### LifetimeBadge

**Storybook title:** `Domain/LifetimeBadge`

**Required stories:**
- `Simple`, `WithBudget` («8/33 дней»), `AllUsed` («0/33 — обновится 1 января»), `Small`, `Large`

---

## Категория: Layout

### Header

**Storybook title:** `Layout/Header`

**Required stories:**
- `MiniApp` — без back, с title
- `MiniAppWithBack` — `{ back: { onClick }}` (Telegram BackButton API)
- `AdminWithBreadcrumbs`
- `AdminWithActions` — title + actions справа (ExportButton)
- `WithSubtitle`

---

### Tabs

**Storybook title:** `Layout/Tabs`

**Required stories:**
- `Pills` (mini-app), `Underline` (admin), `WithCount` («Заявки 12»), `WithDisabled`, `MobileScroll` (5+ табов)

---

### EmptyState

**Storybook title:** `Layout/EmptyState`

**Required stories:**
- `NoData` (например, «Респектов пока не было»), `NoResults` («По фильтру ничего не найдено»), `Error`, `WithAction` (кнопка), `WithIllustration`

**Usage:**
- ✅ Всегда понятный текст + (если возможно) action.
- ❌ Не «No items» — пиши на «ты»: «Здесь пока пусто».

---

### ErrorState

**Storybook title:** `Layout/ErrorState`

**Required stories:**
- `404`, `500`, `Network` (нет интернета), `Permission` («Доступ ограничен»), `WithRetry`, `WithSupport`

---

### LoadingState / Skeleton

**Storybook title:** `Layout/Skeleton`

**Required stories:**
- `Text` (одна строка), `MultiLineText` (3 строки), `Circle` (Avatar placeholder), `Rect` (Card), `CellList` (5 cells), `MatchCardSkeleton`, `KBAnswerSkeleton`, `TableRows`

**Visual contract:** pulse-анимация 1500ms, цвет `bg.tertiary` ↔ `bg.secondary`.

---

## Категория: Admin

### DataTable

**Storybook title:** `Admin/DataTable`

**Required stories:**
- `Default` (10 строк)
- `Loading` (skeleton rows)
- `Empty`
- `Error`
- `WithPagination`
- `Selectable` (с чекбоксами + bulk-action toolbar)
- `Sortable`
- `CompactDensity`
- `WithCustomCells` (Avatar, Badge, кнопки внутри)
- `LongRows` (100 rows — pagination demo)

---

### FilterBar

**Storybook title:** `Admin/FilterBar`

**Required stories:**
- `Default` (3 фильтра), `WithDateRange`, `WithSearch`, `Active` (применены значения), `Reset`

---

### ExportButton

**Storybook title:** `Admin/ExportButton`

**Required stories:**
- `Default`, `Exporting` (loading), `Error`, `OnlyCSV`, `OnlyExcel`, `WithRecordCount`

---

### KPICard

**Storybook title:** `Admin/KPICard`

**Required stories:**
- `Default` (просто value), `WithTrend` (+15%), `WithTarget`, `Loading` (skeleton), `Error`, `WithIcon`, `Negative` (trend −10%)

---

### ChartCard

**Storybook title:** `Admin/ChartCard`

**Required stories:**
- `Line`, `Bar`, `Funnel`, `Donut`, `Loading`, `Empty`, `Error`, `WithPeriodPicker`

---

## Сводный чек-лист (для Coder Agent в Phase 6)

При реализации каждого компонента создать файл `frontend/src/stories/{category}/{Name}.stories.jsx` с:
- [ ] `title` соответствует спецификации выше
- [ ] `component` импорт
- [ ] `argTypes` для всех props с типами из спецификации
- [ ] **Все required stories** реализованы
- [ ] Description (markdown в `parameters.docs.description.component`)
- [ ] Покрытие минимум: Default, Loading (если асинхронен), Error, Empty (если контейнер), Disabled (если применимо), AllVariants

**Без этих stories Review Agent блокирует merge** (rule 08, Step 3.5).

---

## Связанные документы

- `design-system.md` — философия.
- `design-tokens.yaml` — токены.
- `component-library.md` — каталог.
- `.claude/rules/08-interface-compliance.md` — правило IfaC.

---

*Документ создан: UI Agent | Дата: 2026-05-15*
