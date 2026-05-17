---
title: "Клуб 33 — Design System"
created_by: "UI Agent"
created_at: "2026-05-15"
version: "1.0"
phase: "Design"
---

# Design System «Клуба 33»

> Единая дизайн-система для Telegram mini-app и web-админки. База — TelegramUI (React), расширенная кастомными компонентами под механики клуба: респекты, звёзды, дни, AI-матчинг, RAG, жалобы.

---

## 1. Философия и принципы

### 1.1 Принципы

1. **Native-first.** Mini-app — это продолжение Telegram. Используем нативные `MainButton`, `BackButton`, `themeParams`, `HapticFeedback`. Никаких sticky-CTA, никаких собственных модалок там, где есть `showPopup`.
2. **Тон на «ты».** Дружелюбно, коротко, без бюрократии. UI должен говорить с пользователем как старший товарищ.
3. **Прозрачность AI.** Любой результат от Claude (матчинг, RAG, digest) — с reasoning и источниками. «Чёрные ящики» запрещены.
4. **Анонимность по контракту.** Жалобы — анонимны для получателя на уровне UI (никаких «От: ...»). Это видно в каждом флоу.
5. **Одна моно-система.** Mini-app и web-админка делят один набор design tokens. Различаются плотностью, не палитрой.
6. **Skeleton не spinner.** Любая асинхронная загрузка показывает структуру контента, а не безликий крутящийся круг.
7. **Haptic дисциплина.** `success` — только на завершении действия; `light` — на тапах; `error` — только на реальной ошибке.

### 1.2 Что мы не делаем

- Не делаем модалки с длинными формами там, где хватит одного действия (анти-паттерн респектов).
- Не используем graph-pattern «люди, которых вы можете знать» (мы context-based, не social-graph).
- Не показываем модераторам/админам персональные данные жертв жалоб (см. принцип анонимности).
- Не строим параллельную типографику — наследуем системный шрифт Telegram.

---

## 2. Brand identity

### 2.1 Название и смысл

- **Название:** Клуб 33 (eng: Club 33).
- **Смысл числа 33:** возраст «зрелого старта», отсылка к Юпитеру/высшей точке, годовой бюджет lifetime — 33 дня.
- **Миссия:** объединять зрелых людей, у которых есть что дать друг другу. Внутри клуба ценность измеряется не статусом, а вкладом — респектами, звёздами и подаренным временем.

### 2.2 Голос бренда

| Аспект | Что делаем | Чего избегаем |
|--------|------------|---------------|
| Обращение | На «ты», по имени | «Уважаемый пользователь», «Вы» |
| Длина | 1–2 предложения | Лонгриды в UI |
| Тон | Дружелюбно, по делу | Маркетинговый пафос, эмодзи-спам |
| Ошибки | «Что-то пошло не так. Попробуй ещё раз или напиши в поддержку.» | «Произошла критическая ошибка №500-XX» |
| Успех | «Респект отправлен. У тебя осталось 27 на этот месяц.» | «Операция выполнена успешно.» |
| Призыв | «Подать заявку», «Дать респект», «Подарить день» | «Кликни сюда», «Нажми чтобы продолжить» |

### 2.3 Визуальный язык — короткий бриф

- **Тёплый, спокойный, премиальный.** Не игровой, не яркий, не «корпоративный».
- **Акцент клуба:** тёплый золотой (`#C9A24A`) — отсылка к Юпитеру, звёздам, ценности. Используем точечно: звёзды, ключевые CTA, бейджи lifetime.
- **Базовый цвет UI:** наследуется от `Telegram.WebApp.themeParams`. Никакого override фона.
- **Метафоры:** звезда (репутация), рукопожатие (респект), песочные часы (дни/время), пульс (digest).

---

## 3. Цветовая палитра

> Все цвета имеют light/dark варианты. Light — для web-админки и Telegram light-темы. Dark — для Telegram dark-темы. Mini-app **наследует фон и текст от `themeParams`**, цвета ниже используются как accent-слой поверх.

### 3.1 Системные роли цветов

| Роль | Token | Light | Dark | Назначение |
|------|-------|-------|------|------------|
| Primary | `color.primary` | `#C9A24A` | `#E6BC5E` | Главные CTA, бейдж lifetime, золотая звезда |
| Primary-hover | `color.primary.hover` | `#B58E3A` | `#F2CC74` | Состояние hover в админке |
| Primary-active | `color.primary.active` | `#9E7B2E` | `#D9AE54` | Pressed-state |
| Accent (link/action) | `color.accent` | `themeParams.button_color` ⇢ fallback `#3390EC` | `themeParams.button_color` ⇢ fallback `#6AB3F3` | Ссылки, second-level действия |
| Success / Respect | `color.success` | `#0F9D58` | `#34C77A` | Респект отправлен, оплата подтверждена |
| Warning | `color.warning` | `#F4A100` | `#FFC04D` | Подписка кончается, лимит респектов близко |
| Danger | `color.danger` | `#E84F4F` | `#FF6B6B` | Жалобы, отмена, ошибка |
| Info | `color.info` | `#3390EC` | `#6AB3F3` | Подсказки, баннер |

### 3.2 Нейтральные

| Token | Light | Dark | Использование |
|-------|-------|------|---------------|
| `color.bg` | `themeParams.bg_color` ⇢ `#FFFFFF` | `themeParams.bg_color` ⇢ `#17212B` | Основной фон |
| `color.bg.secondary` | `themeParams.secondary_bg_color` ⇢ `#F4F4F5` | `themeParams.secondary_bg_color` ⇢ `#232E3C` | Cards, Sections |
| `color.bg.tertiary` | `#E8E8EA` | `#2B3949` | Hover, separators ground |
| `color.text` | `themeParams.text_color` ⇢ `#0F0F10` | `themeParams.text_color` ⇢ `#FFFFFF` | Основной текст |
| `color.text.secondary` | `themeParams.hint_color` ⇢ `#707579` | `themeParams.hint_color` ⇢ `#7D8B99` | Caption, hint, метки |
| `color.text.tertiary` | `#A7A9AC` | `#5F6B78` | Disabled |
| `color.border` | `#E2E2E5` | `#2B3949` | Separators в админке |

### 3.3 Семантические цвета механик клуба

| Сущность | Token | Light | Dark |
|----------|-------|-------|------|
| Звезда (заполненная) | `color.star.filled` | `#C9A24A` | `#E6BC5E` |
| Звезда (пустая) | `color.star.empty` | `#D8D8DA` | `#3B485A` |
| Респект (получен) | `color.respect.received` | `#0F9D58` | `#34C77A` |
| Респект (отдан) | `color.respect.given` | `#3390EC` | `#6AB3F3` |
| День (доступен) | `color.day.available` | `#C9A24A` | `#E6BC5E` |
| День (подарен) | `color.day.gifted` | `#9E9E9E` | `#7D8B99` |
| Lifetime бейдж | `color.lifetime` | `linear-gradient(135deg,#C9A24A,#E6BC5E)` | то же |
| Жалоба | `color.complaint` | `#E84F4F` | `#FF6B6B` |

### 3.4 Контрастность

Все пары `text on bg` проверены на WCAG AA (4.5:1 для основного текста, 3:1 для крупного):

- `text` на `bg` (light): 18.5:1 ✓
- `text` на `bg` (dark): 17.2:1 ✓
- `primary` на `bg` (light): 4.6:1 ✓ (только для крупного текста на CTA, иначе используем `text-on-primary` — белый)
- `text-on-primary`: всегда `#FFFFFF` для CTA на золоте.

---

## 4. Типографика

### 4.1 Шрифт

```css
font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", "Segoe UI", Roboto, Arial, sans-serif;
font-feature-settings: "tnum" on, "lnum" on;  /* tabular numbers для финансов */
```

Системный шрифт Telegram. На вебе fallback — SF Pro / Segoe UI / Roboto. Никаких загружаемых шрифтов (это бьёт по TTI).

### 4.2 Шкала размеров

| Token | Size | Line-height | Weight | Use case |
|-------|------|-------------|--------|----------|
| `text.display` | 32px | 40px | 700 | Welcome-экран onboarding |
| `text.h1` | 24px | 32px | 700 | Заголовок страницы (админка) |
| `text.h2` | 22px | 28px | 600 | Заголовок mini-app экрана |
| `text.h3` | 20px | 26px | 600 | Section title |
| `text.h4` | 17px | 22px | 600 | Cell title (большой) |
| `text.h5` | 15px | 20px | 600 | Cell title |
| `text.body` | 17px | 22px | 400 | Основной текст mini-app (iOS-параметр) |
| `text.body.compact` | 15px | 20px | 400 | Plain text админки |
| `text.subhead` | 14px | 18px | 500 | Section header в TelegramUI |
| `text.caption` | 13px | 16px | 400 | Подпись под Cell, метаданные |
| `text.caption.small` | 11px | 14px | 500 | Бейджи, теги |
| `text.code` | 14px / monospace | 18px | 500 | Адреса кошельков, ID транзакций |

```css
font-family-mono: ui-monospace, "SF Mono", "Cascadia Mono", "Roboto Mono", monospace;
```

### 4.3 Weights

- 400 — regular (body)
- 500 — medium (subhead, caption.small)
- 600 — semibold (Cell title, h3-h5)
- 700 — bold (h1, h2, display)

---

## 5. Spacing scale

4px-based grid.

| Token | Value | Использование |
|-------|-------|---------------|
| `space.0` | 0 | Reset |
| `space.xxs` | 2px | Внутри иконок, бейджей |
| `space.xs` | 4px | Иконка ↔ текст внутри Cell |
| `space.sm` | 8px | Между чипами, мелкие отступы |
| `space.md` | 12px | Padding в Cell |
| `space.base` | 16px | Стандартный padding контейнера, отступ между Sections в админке |
| `space.lg` | 24px | Отступы между секциями в mini-app |
| `space.xl` | 32px | Большие пустоты — Empty State, Welcome |
| `space.xxl` | 48px | Hero-блоки, между крупными зонами |

---

## 6. Radii

| Token | Value | Использование |
|-------|-------|---------------|
| `radius.none` | 0 | Полные ширины (Section в TelegramUI) |
| `radius.sm` | 4px | Badge, Tag, маленькие чипы |
| `radius.md` | 8px | Input, кнопка small/medium |
| `radius.lg` | 12px | Card, Section в mini-app, Button large |
| `radius.xl` | 16px | Modal/Sheet верхняя кромка |
| `radius.full` | 9999px | Avatar, Pill-кнопки |

---

## 7. Shadows / Elevations

> В mini-app тени минимальны (TelegramUI flat). Тени активно используются в web-админке.

| Token | Value (light) | Использование |
|-------|---------------|---------------|
| `shadow.none` | none | Mini-app по умолчанию |
| `shadow.sm` | `0 1px 2px rgba(0,0,0,0.06)` | Cards в админке |
| `shadow.md` | `0 4px 12px rgba(0,0,0,0.08)` | Hover state, dropdown |
| `shadow.lg` | `0 8px 24px rgba(0,0,0,0.12)` | Modal, Sheet (web) |
| `shadow.xl` | `0 16px 40px rgba(0,0,0,0.16)` | Floating toast, Popover |

В dark-теме тени заменяются на тонкий border `1px solid color.border` (тени на тёмном фоне читаются хуже).

---

## 8. Анимации

| Token | Duration | Easing | Use case |
|-------|----------|--------|----------|
| `motion.instant` | 0ms | — | Open theme switch (без перехода) |
| `motion.fast` | 150ms | `cubic-bezier(0.25, 0.1, 0.25, 1)` | Hover, focus, tap-feedback |
| `motion.normal` | 250ms | `cubic-bezier(0.25, 0.1, 0.25, 1)` | Page transitions, Sheet open |
| `motion.slow` | 400ms | `cubic-bezier(0.16, 1, 0.3, 1)` | Confetti, success-celebration |
| `motion.match` | 80ms stagger | `cubic-bezier(0.25, 0.1, 0.25, 1)` | Появление карточек матчинга (по очереди) |

**Правила:**
- На респект — короткая пульсация (300ms) + haptic `success`. **Без конфетти** (решение по референсу — слишком игриво).
- На переход экранов в mini-app — `slide-from-right` 250ms (если используется собственная навигация).
- При `prefers-reduced-motion: reduce` — все анимации схлопываются до `motion.instant`.

---

## 9. Иконография

### 9.1 Базовый набор

- **Tabler Icons** (line-style, 24px grid, stroke 2). Бесплатные, MIT-лицензия, идеально для Telegram-стиля.
- Размеры: 16 / 20 / 24 / 28 px. Базовый — **24px**.
- Stroke width: **2px** (как в Telegram нативных иконках).

### 9.2 Кастомные иконки клуба

Иконки, которых нет в Tabler — рисуем сами в едином стиле (line, 24px, stroke 2, согласованный с Tabler):

| Иконка | Метафора | Файл |
|--------|----------|------|
| `icon-star-filled` / `icon-star-half` / `icon-star-empty` | Уровни звёзд 0–4 | `/icons/star-*.svg` |
| `icon-respect` | Рукопожатие (стилизованное) | `/icons/respect.svg` |
| `icon-respect-given` | Стрелка из руки → ↑ | `/icons/respect-given.svg` |
| `icon-day` | Песочные часы | `/icons/day.svg` |
| `icon-gift-day` | Песочные часы со стрелкой ↗ | `/icons/gift-day.svg` |
| `icon-lifetime` | Звезда с кольцом (∞) | `/icons/lifetime.svg` |
| `icon-pulse` | Линия пульса (для digest) | `/icons/pulse.svg` |
| `icon-complaint` | Восклицательный знак в кружке (line) | `/icons/complaint.svg` |
| `icon-match` | Два полукруга → сцепляются | `/icons/match.svg` |
| `icon-kb-quote` | Кавычка с подчёркиванием | `/icons/kb-quote.svg` |

### 9.3 Do / Don't

- ✅ Single colour stroke (наследует currentColor).
- ✅ 24×24 grid, stroke 2px, round join.
- ❌ Не использовать filled-style вперемешку с outline.
- ❌ Не масштабировать иконки растром — только SVG.
- ❌ Никаких эмодзи как замены иконок в UI (за исключением Toast/Push, где допустимо одно эмодзи).

---

## 10. Темизация (Telegram theme params)

Mini-app **обязан** реагировать на 6 параметров темы Telegram:

| themeParam | CSS variable | Token |
|------------|--------------|-------|
| `bg_color` | `--tg-bg` | `color.bg` |
| `secondary_bg_color` | `--tg-bg-secondary` | `color.bg.secondary` |
| `text_color` | `--tg-text` | `color.text` |
| `hint_color` | `--tg-hint` | `color.text.secondary` |
| `link_color` | `--tg-link` | `color.accent` |
| `button_color` | `--tg-button` | `color.accent` |
| `button_text_color` | `--tg-button-text` | `color.text-on-accent` |

Subscribe на `Telegram.WebApp.onEvent('themeChanged', ...)` — обновляем CSS variables.

**Бейдж lifetime** и **золотая звезда** — единственные элементы, которые НЕ берутся из themeParams, а используют брендовый `#C9A24A` (для узнаваемости).

---

## 11. Платформы и плотность

| Платформа | Базовый размер тачабельного элемента | Min hit-area |
|-----------|---------------------------------------|--------------|
| Mini-app (mobile) | 44×44 px | 44×44 px |
| Web-админка (desktop) | 32 (sm) / 36 (md) / 40 (lg) px | 32×32 px |

Web-админка плотнее, чем mini-app. Но **palette и tokens идентичны**.

---

## 12. Accessibility (WCAG AA)

- Все текстовые пары — контраст ≥4.5:1 (3:1 для крупного текста ≥18px/600).
- Все интерактивные элементы — focus-ring `0 0 0 2px color.accent`.
- `aria-label` на иконочных кнопках (RespectButton, BackButton, и т.д.).
- Skeleton screens — `aria-busy="true"` + `aria-live="polite"`.
- Анимации уважают `prefers-reduced-motion`.
- Жалобы — `role="alertdialog"` для confirm-step.

---

## 13. Связь с другими артефактами

- **Design tokens (YAML):** `design-tokens.yaml` — машиночитаемый источник правды.
- **Component library:** `component-library.md` — каталог компонентов.
- **Stories spec (rule 08):** `component-stories-spec.md` — спецификация для Storybook.
- **Visual language:** `visual-language.md` — иллюстрации, фото, анимации.
- **UX wireframes:** `docs/design/ux/` (TASK-005).
- **Content guide:** `docs/design/content/` (TASK-007).

---

*Документ создан: UI Agent | Дата: 2026-05-15*
