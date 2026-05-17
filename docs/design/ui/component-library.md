---
title: "Клуб 33 — Component Library"
created_by: "UI Agent"
created_at: "2026-05-15"
version: "1.0"
phase: "Design"
---

# Component Library «Клуба 33»

> Каталог UI-компонентов для mini-app и web-админки. База — TelegramUI (React).
> Каждый компонент указан с variants, states, props, примером использования.
>
> Источник истины для Storybook — `component-stories-spec.md` (rule 08-interface-compliance).

---

## Структура категорий

1. **Atomic** — базовые примитивы.
2. **Cells & Sections** — TelegramUI-обёртки для списков.
3. **Composite** — карточки, sheets, modals.
4. **Specific** — кастомные компоненты под механики клуба.
5. **Layout** — header, tabs, состояния (empty/error/loading).
6. **Admin** — компоненты web-админки.

---

## 1. Atomic

### 1.1 Button

**Назначение:** Основной CTA, вторичные действия. В mini-app предпочитаем нативный MainButton для главного CTA, Button — для inline-действий.

**Variants:**
- `primary` — золотой фон, белый текст (главное действие)
- `secondary` — прозрачный фон, accent border, accent текст
- `ghost` — без фона, accent текст (link-style)
- `danger` — красный фон, белый текст (необратимые действия)

**Sizes:** `sm` (32px), `md` (40px), `lg` (48px)

**States:** default, hover (desktop), active/pressed, loading (spinner внутри, disabled), disabled, focus-ring.

**Props:**
```ts
type ButtonProps = {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';  // default 'primary'
  size?: 'sm' | 'md' | 'lg';                                // default 'md'
  loading?: boolean;
  disabled?: boolean;
  fullWidth?: boolean;
  leftIcon?: ReactNode;
  rightIcon?: ReactNode;
  haptic?: 'light' | 'medium' | 'heavy' | 'none';           // default 'light'
  onClick: (e: MouseEvent) => void;
  children: ReactNode;
};
```

**Когда использовать:**
- Inline-действия внутри Card/Sheet («Поделиться», «Подробнее»).
- В админке — везде (там нет MainButton).
- **Не** использовать вместо MainButton/BackButton в mini-app.

---

### 1.2 Input / TextField

**Variants:** `default`, `with-prefix` (например, `@`), `with-clear` (× для очистки), `password` (toggle visibility), `search` (lupa слева).

**States:** default, focus, filled, error (border `danger`, hint снизу), disabled.

**Props:**
```ts
type InputProps = {
  type?: 'text' | 'email' | 'password' | 'search' | 'tel' | 'url';
  label?: string;
  placeholder?: string;
  value: string;
  onChange: (v: string) => void;
  error?: string;
  hint?: string;
  prefix?: string;
  suffix?: ReactNode;
  clearable?: boolean;
  disabled?: boolean;
  size?: 'sm' | 'md' | 'lg';
  maxLength?: number;
};
```

---

### 1.3 Textarea

Для длинных вводов (описание профиля, контекст матчинга, комментарий к жалобе).

**States:** default, focus, filled, error, disabled, **with-counter** (показывает `{length}/{maxLength}`).

**Props:**
```ts
type TextareaProps = {
  label?: string;
  value: string;
  onChange: (v: string) => void;
  rows?: number;             // default 3
  maxLength?: number;
  showCounter?: boolean;
  error?: string;
  disabled?: boolean;
};
```

---

### 1.4 Checkbox / Switch

**Checkbox:** галка в форме (соглашения, фильтры).
**Switch:** toggle в настройках (notifications on/off).

**States:** default, checked, indeterminate (только checkbox), disabled, focus.

**Props:**
```ts
type ToggleProps = {
  checked: boolean;
  onChange: (v: boolean) => void;
  label?: string;
  description?: string;
  disabled?: boolean;
  haptic?: boolean;          // Switch — default true
};
```

---

### 1.5 Avatar

**Variants:** `image` (фото из Telegram), `initials` (буквы при отсутствии фото), `placeholder` (silhouette).

**Sizes:** `xs` (24), `sm` (32), `md` (40), `lg` (56), `xl` (80).

**States:** default, with-badge (звёзды/lifetime/online).

**Props:**
```ts
type AvatarProps = {
  src?: string;
  name?: string;             // для initials
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  badge?: 'lifetime' | 'verified' | 'online' | { stars: 0|1|2|3|4 };
  ringColor?: string;        // для золотой обводки lifetime
};
```

---

### 1.6 Badge / Tag

**Badge:** статус (lifetime / KYC / новенький / модератор).
**Tag:** ниша/роль («Founder», «Маркетинг», «AI/ML»).

**Variants:** `primary` (золотой), `accent` (синий), `success`, `warning`, `danger`, `neutral` (серый), `lifetime` (gradient).

**Sizes:** `sm` (height 20px, caption_small), `md` (height 24px, caption).

**States:** default, removable (с ×), disabled.

**Props:**
```ts
type BadgeProps = {
  variant?: 'primary' | 'accent' | 'success' | 'warning' | 'danger' | 'neutral' | 'lifetime';
  size?: 'sm' | 'md';
  leftIcon?: ReactNode;
  removable?: boolean;
  onRemove?: () => void;
  children: ReactNode;
};
```

---

### 1.7 Star (0–4)

**Назначение:** визуализация уровня репутации.

**Variants:** `filled`, `half`, `empty`.

**Sizes:** `sm` (16), `md` (20), `lg` (24).

**Props:**
```ts
type StarProps = {
  level: 0 | 1 | 2 | 3 | 4;        // 0 — все пустые, 4 — все заполнены
  size?: 'sm' | 'md' | 'lg';
  showLabel?: boolean;             // подпись «3★»
  animated?: boolean;              // pulse при повышении
};
```

**Композиция:** 4 SVG в ряд. Level=3 → 3 filled + 1 empty. Half — не используется в текущей формуле репутации (только целые уровни).

---

### 1.8 Icon

Обёртка для Tabler Icons + кастомных.

**Props:**
```ts
type IconProps = {
  name: TablerIconName | ClubIconName;
  size?: 16 | 20 | 24 | 28;
  color?: string;            // default currentColor
  strokeWidth?: number;      // default 2
  'aria-label'?: string;
};
```

---

### 1.9 Spinner

**Sizes:** `sm` (16), `md` (24), `lg` (32).

**Variants:** `accent` (наследует accent), `current` (currentColor).

**Состояния:** только default + (опц) с label «Загрузка...».

**Когда использовать:** только если skeleton невозможен (например, кнопка в loading-state).

---

## 2. Cells & Sections (TelegramUI-style)

### 2.1 Cell

Стандартная строка в списке (TelegramUI Cell). Используется везде в mini-app.

**Variants:** `default`, `with-before` (иконка/Avatar слева), `with-after` (иконка/Badge справа), `multiline` (title + subtitle).

**States:** default, pressed (background highlight), disabled.

**Props:**
```ts
type CellProps = {
  before?: ReactNode;        // Avatar / Icon
  after?: ReactNode;         // Badge / Icon / chevron
  title: string;
  subtitle?: string;
  description?: string;      // 3-я строка
  onClick?: () => void;
  disabled?: boolean;
  destructive?: boolean;     // для actions «Выйти», «Удалить»
};
```

---

### 2.2 Section

Контейнер группы Cell с заголовком и подписью снизу.

**Props:**
```ts
type SectionProps = {
  header?: string;           // верхний subhead
  footer?: string;           // нижний caption (часто — подсказка)
  children: ReactNode;       // Cell[]
};
```

---

### 2.3 ListItem / MenuItem

Те же Cell, но с акцентом на иконку слева (для меню-навигации, чаще в админке).

---

## 3. Composite

### 3.1 Card

**Variants:**
- `compact` — padding 12px, для лент digest.
- `default` — padding 16px, основной.
- `feature` — padding 24px + золотая обводка (для lifetime/специальных карточек).

**States:** default, hover (desktop), pressed, loading (skeleton inside), error.

**Props:**
```ts
type CardProps = {
  variant?: 'compact' | 'default' | 'feature';
  padding?: keyof Spacing;
  onClick?: () => void;
  children: ReactNode;
};
```

---

### 3.2 Sheet (Bottom Sheet)

Mini-app предпочитает Sheet вместо Modal (mobile-native).

**Variants:** `default`, `fullscreen`, `confirm` (короткое подтверждение).

**States:** opening, open, closing, closed.

**Props:**
```ts
type SheetProps = {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  variant?: 'default' | 'fullscreen' | 'confirm';
  showHandle?: boolean;      // default true
  closeOnOverlayClick?: boolean;
  children: ReactNode;
};
```

---

### 3.3 Modal

В админке (desktop) — стандартное модальное окно. В mini-app — заменяем на Sheet или Telegram `showPopup`.

**Props:** аналогично Sheet, но с size: `sm | md | lg`.

---

### 3.4 Toast

Краткое уведомление 2–3 сек.

**Variants:** `success`, `error`, `info`, `warning`.

**Props:**
```ts
type ToastProps = {
  variant: 'success' | 'error' | 'info' | 'warning';
  message: string;
  action?: { label: string; onClick: () => void };
  duration?: number;         // default 3000ms
};
```

В mini-app может дублироваться HapticFeedback (`notificationOccurred`).

---

### 3.5 Alert (Inline)

Инлайн-предупреждение (в карточке, не floating).

**Variants:** `info`, `warning`, `danger`, `success`.

**Props:**
```ts
type AlertProps = {
  variant: 'info' | 'warning' | 'danger' | 'success';
  title?: string;
  description: string;
  icon?: ReactNode;
  action?: { label: string; onClick: () => void };
  dismissible?: boolean;
};
```

---

## 4. Specific (домен «Клуба 33»)

### 4.1 RespectButton

**Назначение:** дать респект участнику.

**Variants:** `default` (в профиле), `compact` (в сообщении/Cell).

**States:**
- `available` — можно дать (показывает «Дать респект»)
- `limit-on-user` — уже отдано 3/3 этому участнику в этом месяце (disabled + tooltip)
- `limit-total` — закончились 30 респектов на месяц (disabled + alert)
- `pending` — отправка (loading)
- `given` — дан в этой сессии (анимация pulse, текст «+1 респект»)
- `cooldown` — ожидание следующего 1-го числа

**Props:**
```ts
type RespectButtonProps = {
  recipientId: string;
  givenToThisUser: 0 | 1 | 2 | 3;       // 3 = лимит
  balance: number;                      // 0–30 на месяц
  onSubmit: () => Promise<void>;
  variant?: 'default' | 'compact';
};
```

**Haptic:** `medium` на тапе, `success` после подтверждения.

---

### 4.2 GiftSlider

**Назначение:** выбрать количество дней для дарения.

**States:** default, at-min (1 день), at-max (баланс − 30 или 33 для lifetime), invalid (если базы не хватит).

**Props:**
```ts
type GiftSliderProps = {
  balance: number;                      // дни доступные
  minRemainder: number;                 // 30 для обычного, 0 для lifetime
  maxGift?: number;                     // 33 годовой лимит для lifetime
  value: number;
  onChange: (v: number) => void;
  costPreviewUsd?: number;              // показать «≈ X $»
};
```

Визуал: горизонтальный slider + label «X дней (≈ Y $)» + caption «У тебя останется Z дней».

---

### 4.3 MatchCard

**Назначение:** карточка результата AI-матчинга.

**States:** default, loading (skeleton), favorited, contacted (уже написал).

**Props:**
```ts
type MatchCardProps = {
  user: { id: string; name: string; avatar?: string; roles: string[]; stars: 0|1|2|3|4 };
  reasoning: string;                    // объяснение от Claude (3–5 предложений)
  matchScore?: number;                  // 0..100 — опционально
  onContact: () => void;
  onRate?: (rating: 1|2|3|4|5) => void;
  contacted?: boolean;
};
```

Структура: Avatar + name + stars вверху → теги-ниши → reasoning (с border-left accent) → CTA «Связаться».

---

### 4.4 KBAnswerCard

**Назначение:** ответ от RAG (`/ask`) с источниками.

**States:** loading (skeleton с пульсацией), default, rated (👍/👎 выбран), needs-clarification.

**Props:**
```ts
type KBAnswerCardProps = {
  question: string;
  answer: string;                       // markdown
  citations: Array<{
    id: string;
    snippet: string;                    // 1-2 предложения из чата
    author: string;
    timestamp: string;
    deepLink: string;                   // ссылка на сообщение
  }>;
  onRate: (vote: 'up' | 'down') => void;
  onClarify: () => void;
};
```

Цитаты — нумерованные сноски `[1]`, кликабельные → раскрывается список снизу.

---

### 4.5 ComplaintForm

**Назначение:** форма анонимной жалобы.

**States:** default, validating, submitting, success (confirmation), error.

**Props:**
```ts
type ComplaintFormProps = {
  targetUserId: string;
  reasons: Array<'spam' | 'insult' | 'off-topic' | 'other'>;
  onSubmit: (data: { reason: string; comment?: string }) => Promise<void>;
};
```

Внутри: radio-group причин + textarea (max 500) + alert «Получатель не узнает твоё имя» + CTA «Отправить жалобу» (`danger` variant).

---

### 4.6 BookingSlot

**Назначение:** карточка слота интервью в календаре основателя.

**States:** available, selected, booked-by-me, taken, past.

**Props:**
```ts
type BookingSlotProps = {
  slot: { start: string; end: string; tzMoscow: boolean };
  state: 'available' | 'selected' | 'booked-by-me' | 'taken' | 'past';
  onSelect?: () => void;
};
```

---

### 4.7 FunnelChart

**Назначение:** воронка в админке.

**States:** loading (skeleton bars), default, empty (нет данных за период), error.

**Props:**
```ts
type FunnelChartProps = {
  stages: Array<{ name: string; count: number; conversionFromPrev?: number }>;
  period?: string;
  onStageClick?: (stageName: string) => void;
};
```

---

### 4.8 LifetimeBadge

**Назначение:** Бейдж lifetime с золотым градиентом + опциональный счётчик годового бюджета.

**Variants:** `simple` (просто «Lifetime»), `with-budget` (с «8/33 дней»).

---

## 5. Layout

### 5.1 Header

**Variants:**
- `mini-app` — компактный, BackButton через нативный API Telegram, центрированный заголовок.
- `admin` — полный, с breadcrumbs, actions справа.

**Props:**
```ts
type HeaderProps = {
  title: string;
  subtitle?: string;
  back?: { onClick: () => void };       // в mini-app использует Telegram.BackButton
  actions?: ReactNode;                  // только для admin
  breadcrumbs?: Array<{ label: string; href?: string }>;
};
```

---

### 5.2 Tabs

**Variants:** `pills` (mini-app), `underline` (admin).

**States:** default, active, disabled.

**Props:**
```ts
type TabsProps = {
  tabs: Array<{ id: string; label: string; count?: number; disabled?: boolean }>;
  active: string;
  onChange: (id: string) => void;
  variant?: 'pills' | 'underline';
};
```

---

### 5.3 EmptyState

**Variants:** `no-data` (никогда не было), `no-results` (фильтр пустой), `error` (запрос упал).

**Props:**
```ts
type EmptyStateProps = {
  variant?: 'no-data' | 'no-results' | 'error';
  icon?: ReactNode;
  title: string;
  description?: string;
  action?: { label: string; onClick: () => void };
};
```

---

### 5.4 ErrorState

**Variants:** `404`, `500`, `network`, `permission`.

**Props:**
```ts
type ErrorStateProps = {
  variant?: '404' | '500' | 'network' | 'permission';
  title: string;
  description?: string;
  onRetry?: () => void;
  onSupport?: () => void;
};
```

---

### 5.5 LoadingState / Skeleton

Skeleton-блоки повторяют структуру контента. Анимация — мягкий pulse (1500ms loop).

**Props:**
```ts
type SkeletonProps = {
  variant?: 'text' | 'circle' | 'rect';
  width?: string | number;
  height?: string | number;
  count?: number;            // повторить N штук
};
```

---

## 6. Admin (только web-админка)

### 6.1 DataTable

**Variants:** `default`, `compact`, `selectable` (с чекбоксами).

**States:** loading (skeleton rows), default, empty, error, with-pagination, with-bulk-actions.

**Props:**
```ts
type DataTableProps<T> = {
  columns: Array<{
    key: keyof T;
    header: string;
    width?: string;
    sortable?: boolean;
    render?: (row: T) => ReactNode;
  }>;
  rows: T[];
  loading?: boolean;
  emptyState?: ReactNode;
  selectable?: boolean;
  onSelectionChange?: (ids: string[]) => void;
  pagination?: { page: number; perPage: number; total: number; onChange: (p: number) => void };
  sort?: { key: keyof T; dir: 'asc' | 'desc' };
  onSortChange?: (s: { key: keyof T; dir: 'asc' | 'desc' }) => void;
};
```

---

### 6.2 FilterBar

**Props:**
```ts
type FilterBarProps = {
  filters: Array<
    | { type: 'select'; key: string; label: string; options: Array<{ value: string; label: string }> }
    | { type: 'date-range'; key: string; label: string }
    | { type: 'search'; key: string; label: string; placeholder?: string }
  >;
  value: Record<string, unknown>;
  onChange: (key: string, value: unknown) => void;
  onReset: () => void;
};
```

---

### 6.3 ExportButton

CTA c dropdown «CSV / Excel».

**States:** default, exporting (loading), error.

**Props:**
```ts
type ExportButtonProps = {
  formats?: Array<'csv' | 'xlsx'>;       // default ['csv','xlsx']
  onExport: (format: 'csv' | 'xlsx') => Promise<void>;
  recordCount?: number;
};
```

---

### 6.4 KPICard

**States:** default, loading, error, with-trend (+/-%), with-target.

**Props:**
```ts
type KPICardProps = {
  label: string;
  value: string | number;
  unit?: string;                          // '$', '%', 'д.' (дни)
  trend?: { value: number; period: string };
  target?: { value: number; achieved: boolean };
  loading?: boolean;
  icon?: ReactNode;
};
```

---

### 6.5 ChartCard

Обёртка для графиков (Recharts / Chart.js).

**Variants:** `line`, `bar`, `funnel` (использует FunnelChart), `donut`.

**Props:**
```ts
type ChartCardProps = {
  title: string;
  subtitle?: string;
  period?: { from: Date; to: Date; onChange?: (p: { from: Date; to: Date }) => void };
  data: ChartData;
  type: 'line' | 'bar' | 'funnel' | 'donut';
  loading?: boolean;
  emptyState?: ReactNode;
};
```

---

## 7. Сводная таблица компонентов

| # | Компонент | Категория | Mini-app | Admin |
|---|-----------|-----------|----------|-------|
| 1 | Button | atomic | ✅ | ✅ |
| 2 | Input | atomic | ✅ | ✅ |
| 3 | Textarea | atomic | ✅ | ✅ |
| 4 | Checkbox | atomic | ✅ | ✅ |
| 5 | Switch | atomic | ✅ | ✅ |
| 6 | Avatar | atomic | ✅ | ✅ |
| 7 | Badge | atomic | ✅ | ✅ |
| 8 | Tag | atomic | ✅ | ✅ |
| 9 | Star | atomic | ✅ | ✅ |
| 10 | Icon | atomic | ✅ | ✅ |
| 11 | Spinner | atomic | ✅ | ✅ |
| 12 | Cell | cells | ✅ | ⚠️ (списки) |
| 13 | Section | cells | ✅ | ✅ |
| 14 | ListItem | cells | ✅ | ✅ |
| 15 | MenuItem | cells | – | ✅ |
| 16 | Card | composite | ✅ | ✅ |
| 17 | Sheet | composite | ✅ | – |
| 18 | Modal | composite | – | ✅ |
| 19 | Toast | composite | ✅ | ✅ |
| 20 | Alert | composite | ✅ | ✅ |
| 21 | RespectButton | specific | ✅ | ✅ (модератор) |
| 22 | GiftSlider | specific | ✅ | – |
| 23 | MatchCard | specific | ✅ | – |
| 24 | KBAnswerCard | specific | ✅ | – |
| 25 | ComplaintForm | specific | ✅ | – |
| 26 | BookingSlot | specific | ✅ | ✅ (просмотр) |
| 27 | FunnelChart | specific | – | ✅ |
| 28 | LifetimeBadge | specific | ✅ | ✅ |
| 29 | Header | layout | ✅ | ✅ |
| 30 | Tabs | layout | ✅ | ✅ |
| 31 | EmptyState | layout | ✅ | ✅ |
| 32 | ErrorState | layout | ✅ | ✅ |
| 33 | LoadingState/Skeleton | layout | ✅ | ✅ |
| 34 | DataTable | admin | – | ✅ |
| 35 | FilterBar | admin | – | ✅ |
| 36 | ExportButton | admin | – | ✅ |
| 37 | KPICard | admin | – | ✅ |
| 38 | ChartCard | admin | – | ✅ |

**Итого: 38 компонентов.**

---

## 8. Принципы переиспользования

- TelegramUI используется для: Cell, Section, Button (base), Avatar, Input, Switch, Tabbar, IconButton, Modal/Sheet (base). Кастомизируем темой.
- Кастомные обёртки добавляют: брендовый primary (золотой), Star 0–4, RespectButton, MatchCard, KBAnswerCard, GiftSlider, LifetimeBadge.
- Admin-only компоненты — собственная реализация поверх tokens.
- **Все компоненты используют только tokens из `design-tokens.yaml`.** Hardcoded цвета/размеры запрещены.

---

## 9. Связанные документы

- `design-system.md` — философия, brand.
- `design-tokens.yaml` — машиночитаемые токены.
- `component-stories-spec.md` — спецификация stories для Storybook.
- `visual-language.md` — иллюстрации, анимации.

---

*Документ создан: UI Agent | Дата: 2026-05-15*
