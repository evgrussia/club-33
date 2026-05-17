---
title: "Клуб 33 — Accessibility Checklist"
created_by: "UX Agent"
created_at: "2026-05-15"
version: "1.0"
phase: "Design"
---

# Accessibility Checklist

Чеклист доступности для трёх поверхностей: Telegram-бот, mini-app (React+Vite, Telegram WebApp), web-админка. Базовый стандарт — **WCAG 2.1 AA**.

---

## 1. Контрастность (WCAG AA)

| Контекст | Минимум | Заметки |
|---|---|---|
| Обычный текст (≤18px) | 4.5 : 1 | Bot inline-кнопки, mini-app body, admin table cells |
| Крупный текст (≥24px / ≥19px bold) | 3.0 : 1 | Заголовки экранов, KPI цифры |
| UI-компоненты, иконки, фокус-кольцо | 3.0 : 1 | Borders инпутов, иконки в tab bar, focus ring |
| Декоративные элементы | — | Не требуется (но избегать введения в заблуждение) |

Для mini-app цвета берутся из `themeParams` Telegram (см. ниже) — у пользователя может быть кастомная тема. UI Agent (TASK-006) обязан зафиксировать tokens, проходящие AA в обеих темах.

**Проверка:** UI Agent даёт design tokens с уже проверенными контрастами; в Storybook добавляется addon-a11y; Playwright + axe-core в CI (см. DevOps Phase 8).

---

## 2. Touch targets

| Поверхность | Минимум | Где особенно важно |
|---|---|---|
| Telegram-бот (inline keyboard) | Telegram сам отдаёт ≥44pt | — (контроль системой) |
| Mini-app (mobile) | **44 × 44 pt** | Кнопки в форме респекта/дара, иконки в tab bar, чипы тегов, источники [1][2] в /ask |
| Web-админка (desktop) | **32 × 32 px** для иконок, **40 px высота** для row actions | Кнопки в таблицах |

- Между интерактивными элементами — gap **≥ 8 pt**.
- Tab bar mini-app — высота **≥ 56 pt** (нативный Telegram стандарт).

---

## 3. Haptic Feedback (Telegram WebApp)

Используем `tg.HapticFeedback`:

| Событие | Тип | Где |
|---|---|---|
| Успешное отправление респекта/дара/жалобы | `notificationOccurred('success')` | mini-app форма после API 200 |
| Превышен лимит / ошибка валидации | `notificationOccurred('warning')` | mini-app inline error |
| Серверная ошибка / отказ | `notificationOccurred('error')` | mini-app toast/alert |
| Тап на быстрое действие, на источник [1][2] | `impactOccurred('light')` | Home, /ask answer |
| Тап на MainButton перед загрузкой | `impactOccurred('medium')` | Все формы |
| Переключение tab bar | `selectionChanged()` | Главная нав |

Запрещено: вызывать haptic чаще раза в 200мс (anti-spam). Не использовать `heavy` (раздражает в коротких UI-операциях).

---

## 4. Native Telegram UI (MainButton / BackButton)

Правила использования:

- **MainButton** — используется для **основного действия** экрана (Сохранить, Отправить, Подтвердить). На экранах без действия (Home, History) — скрыт.
- **BackButton** — обязателен на **всех вложенных** экранах (не Home, не root). Обработчик возвращает на предыдущий экран, на root — `tg.close()` с `closingConfirmation` если есть несохранённые данные.
- Не использовать **кастомные** sticky footer-кнопки, дублирующие MainButton — приводит к double-tap-багам.
- **Tab bar** mini-app не дублируется в MainButton.
- На экранах с длинными формами MainButton может **disable** до валидности.

---

## 5. Theme parameters (light/dark)

Mini-app должен корректно работать в обеих темах Telegram. Цвета берутся ТОЛЬКО из `themeParams`:

| themeParams key | Использование |
|---|---|
| `bg_color` | Основной фон экранов |
| `secondary_bg_color` | Фон карточек, инпутов |
| `text_color` | Основной текст |
| `hint_color` | Вторичный текст, плейсхолдеры |
| `link_color` | Ссылки, [1][2] источники |
| `button_color` | Primary button (если кастомный) |
| `button_text_color` | Текст на primary button |
| `destructive_text_color` | Удалить, отменить, ошибка |

Обработчик `themeChanged` обновляет CSS-vars в `:root` без перезагрузки.

**Запрещено:** хардкод цветов (#FFFFFF, #000000) для текста/фона.

Web-админка: автоопределение `prefers-color-scheme` + переключатель в профиле админа. Те же требования к контрасту.

---

## 6. UI-feedback (требование Analytics)

| Метрика | Где собираем | Тип control |
|---|---|---|
| `match_quality` | Через 1 час после /match — push в бот + экран в mini-app | 5-балльная шкала ⭐ + label «полезно / нейтрально / мимо» |
| `kb_usefulness` | Сразу под ответом /ask | Бинарный «👍 Полезно / 🤔 Так себе» |
| `respect_understandability` | Раз в неделю в digest | Опц., 1 раз — короткий вопрос |
| `match_csat_comment` | Опциональное поле в feedback /match | textarea, max 500 |

**DEC-R-005:** жёсткого «downvote» нет. Везде минимум 3-значная шкала или нейтральная формулировка («так себе» вместо «плохо»). Это снижает страх соц-наказания и улучшает honest feedback.

UI всех feedback-форм:
- доступны через `aria-label` / role в админке;
- размер touch target ≥44pt;
- сохраняются локально на случай оффлайна (idempotency-key).

---

## 7. Reduced motion

Поддержка `prefers-reduced-motion: reduce`:

- Анимации появления карточек (fade/slide) **отключаются** — заменяются мгновенным появлением.
- Loading-spinner — упрощается до статичной точки с aria-live.
- Typewriter-эффект в /ask и /match → текст показывается **сразу целиком**.
- Skeleton-pulse — отключается, фон карточки просто залит `secondary_bg_color`.

Web-админка: то же; графики — без entry-анимаций при `reduce`.

---

## 8. Error messages

Все ошибки — на «ты», коротко, с экшеном (что сделать).

| Контекст | Плохо | Хорошо |
|---|---|---|
| Сеть | «Network error 500» | «Не достучались до сервера. [Повторить]» |
| Валидация | «Field required» | «Заполни «причина», пожалуйста» |
| Лимит респектов | «Limit reached» | «Ты уже дал @ivan 3 респекта. Баланс обновится 1 числа» |
| Платёж не подтверждён | «Pending» | «Платёж ещё не подтверждён. [Поддержка]» |
| Закон не принят | «Mismatch» | «Не сходится. Попробуй ещё раз. Точная фраза: «…»» |

**Запрещено:**
- технический жаргон без перевода;
- error без call-to-action;
- модалки без кнопки «закрыть».

---

## 9. Клавиатура и фокус (web-админка)

- **Tab order** строго логичен: sidebar → search → filters → table → pagination.
- **Focus ring** виден всегда (контраст ≥3:1, не только outline:none).
- **Cmd+K** — глобальный поиск.
- **Esc** — закрывает модалки и сбрасывает поиск.
- **Enter** в фильтрах — применяет; **Tab** не перепрыгивает скрытые элементы.
- В таблицах — **arrow keys** для навигации между rows (опц.), Enter = открыть карточку.
- Все интерактивные элементы — `<button>` или `<a>` (не `<div onclick>`).

---

## 10. Скриншот-ридеры и семантика

| Поверхность | Требования |
|---|---|
| Mini-app | Семантические теги: `<button>`, `<nav>`, `<main>`, `<form>`. Все интерактивные — с `aria-label` если иконка без текста. Карточки в /match — `<article>` с `aria-labelledby`. |
| Web-админка | `<table>` с `<th scope>`. Sidebar — `<nav role="navigation" aria-label="Main">`. Модалки — `role="dialog" aria-modal="true"` + focus-trap. Toast — `role="status" aria-live="polite"`, errors — `aria-live="assertive"`. |
| Telegram-бот | Текст всегда читается ботом. Каждая inline-кнопка имеет осмысленный label (не «✓» одиночный — лучше «✓ Подарить»). |

---

## 11. Локализация и i18n

MVP — только **русский**. Тем не менее:
- Все строки выносятся в i18n-словарь (RU только на MVP, заготовка под EN).
- Даты — формат «15.05.2026» / «15 мая, 14:00 МСК».
- Числа — пробельный разделитель тысяч (138 450 ₽).
- Время — МСК (Europe/Moscow), отображается явно («14:00 МСК»).

---

## 12. Производительность как часть accessibility

- Mini-app First Contentful Paint **< 1.5s** на 4G.
- Bundle size **< 250 KB gzipped** для первого экрана.
- Lazy-load для разделов «Дары» (Ф3), «AI» (Ф2) — динамический import.
- Skeleton-loading начинается **сразу**, без задержки 200мс.
- Pull-to-refresh с дебаунсом 500мс.

---

## 13. Чеклист готовности экрана (для UI Agent / Coder)

Перед merge экран должен пройти:

- [ ] Контрастность всех текстов ≥ AA (axe-core)
- [ ] Touch targets ≥44pt (mini-app), ≥32px (admin)
- [ ] Light + Dark тема — оба читаются
- [ ] BackButton настроен (mini-app, не root)
- [ ] MainButton на основное действие (или явно скрыт)
- [ ] Haptic feedback на success/warning/error
- [ ] Состояния: default / loading (skeleton) / error / empty
- [ ] Reduced motion поддержан
- [ ] Все error messages на «ты», с action
- [ ] Скрин-ридер: каждый control имеет label
- [ ] Keyboard navigation работает (admin)
- [ ] Идемпотентность критичных action (нет double-submit)

---

*Документ создан: UX Agent | Дата: 2026-05-15*
