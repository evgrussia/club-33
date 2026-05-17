---
title: "Клуб 33 — OWASP Top 10 (2021) Checks"
created_by: "Security Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# OWASP Top 10 (2021) — чеклист для «Клуба 33»

Для каждого пункта — конкретные mitigations для нашего стека (Django 5 + DRF + React 18 + PostgreSQL 16 + Redis + Telegram WebApp).

---

## A01:2021 — Broken Access Control

**Риски в проекте:** RBAC Super/Mod/Support (DEC-005), IDOR на `/users/{id}`, `/invoices/{id}`, `/complaints/{id}`.

**Mitigations:**
- DRF `permission_classes` на каждом ViewSet: `IsAuthenticated`, `IsSuperAdmin`, `IsModerator`, `IsSupport`, `IsOwner` (комбинации).
- Object-level permissions: пользователь видит ТОЛЬКО свои `invoices`, `respects_received`, `gifts`. Тест: `test_user_cannot_access_other_user_invoice`.
- Запрет mass-assignment: использовать `serializer.Meta.fields` whitelist, никогда `__all__`.
- Server-side фильтрация: `Invoice.objects.filter(user=request.user)` всегда. Никогда не доверять `?user_id=` из query.
- Default deny: новые endpoints получают `IsAuthenticated` минимум.
- Запрет на UPDATE критичных полей через API: `is_staff`, `is_superuser`, `role`, `subscription.end_date`, `invoice.invoice_rate_snapshot`.
- **Тесты:** обязательный модуль `tests/test_permissions.py` с матрицей (24 теста минимум: 4 роли × 6 endpoints).

---

## A02:2021 — Cryptographic Failures

**Риски:** TLS, хранение JWT secret, AES для KYC данных, password hashing для админов.

**Mitigations:**
- TLS 1.2+ обязателен (Nginx: `ssl_protocols TLSv1.2 TLSv1.3;`); HSTS `max-age=31536000; includeSubDomains; preload`.
- Let's Encrypt сертификат, авто-rotation через certbot.
- Django: `SECURE_SSL_REDIRECT = True`, `SESSION_COOKIE_SECURE = True`, `CSRF_COOKIE_SECURE = True`.
- Password hashing: `PBKDF2PasswordHasher` (default Django, 600k iterations) или Argon2 (рекомендую).
- KYC данные (если хранятся): AES-256-GCM с ключом из Vault; в БД хранить `(ciphertext, nonce, tag)` в JSONField. Никогда — plaintext.
- JWT signing key: 64+ байта random, отдельный для access/refresh.
- Не использовать MD5, SHA-1, ECB. Не реализовывать crypto вручную — только `cryptography` lib.

---

## A03:2021 — Injection

**Риски:** SQL, NoSQL (нет), Command (subprocess?), LDAP (нет), Prompt injection (см. ai-security.md), XSS.

**Mitigations:**
- **SQL:** Только Django ORM или параметризованные queries (`.raw()` с `params=[]`). Запрет на `f"SELECT ... {var}"`. ESLint/import-linter правило: `cursor.execute(` с f-string → fail.
- **XSS:**
  - React: использовать только JSX; запрет `dangerouslySetInnerHTML` (ESLint rule `react/no-danger`).
  - Bot output: вся подстановка пользовательского текста в Markdown — через `escape_markdown_v2`.
  - CSP: `Content-Security-Policy: default-src 'self'; script-src 'self'; img-src 'self' https://t.me data:; connect-src 'self' https://api.anthropic.com`.
- **Command injection:** не вызывать `os.system`, `subprocess.call(shell=True)` с пользовательским input.
- **Header injection:** Django по умолчанию защищён; не использовать raw `HttpResponse` с user-controlled headers.
- **ORM injection:** не использовать `extra(where=[user_input])`.

---

## A04:2021 — Insecure Design

**Mitigations:**
- Threat model создан (threat-model.md).
- Defense in depth: каждое критичное действие — несколько слоёв (auth + permission + business rule + audit log).
- Принцип least privilege: Support не видит финансовые дашборды, Mod не видит reporter_id.
- Rate-limiting на чувствительных endpoints (auth, payments, AI).
- FSM (`finite_state_machine`) с явными переходами; запрет «прыгать» через состояния (нельзя из `applied` → `active`).
- Idempotency для платежей и /gift.
- Audit-by-default: каждое DB write — `AuditLogService` (rule 04-logging.md).
- Архитектурное правило: Application layer не зависит от Infrastructure (DDD); проверяется `import-linter`.

---

## A05:2021 — Security Misconfiguration

**Django Security Checklist (`python manage.py check --deploy`):**
- `DEBUG = False` в prod (обязательно; проверка startup).
- `ALLOWED_HOSTS = ['club33.example.com']` (явный список).
- `SECRET_KEY` из Vault, 50+ chars, не в git.
- `SECURE_BROWSER_XSS_FILTER = True`.
- `SECURE_CONTENT_TYPE_NOSNIFF = True`.
- `X_FRAME_OPTIONS = 'DENY'` (mini-app разрешён через CSP `frame-ancestors`).
- `SECURE_REFERRER_POLICY = 'same-origin'`.
- `SECURE_HSTS_SECONDS = 31536000`.
- `SECURE_HSTS_INCLUDE_SUBDOMAINS = True`.
- `SECURE_HSTS_PRELOAD = True`.

**Nginx headers:**
```
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "same-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
add_header Content-Security-Policy "default-src 'self'; ..." always;
```

**Прочее:**
- Дефолтные пароли — нет. Django admin создаётся вручную с TOTP.
- Не открывать админку на тот же домен, что и API/mini-app; отдельный subdomain `admin.club33.example.com` с IP-whitelist.
- Docker: non-root user в контейнерах; read-only filesystem где возможно.
- PostgreSQL: не слушает 0.0.0.0; только localhost / private network.
- Redis: requirepass обязателен; не открывать наружу.

---

## A06:2021 — Vulnerable and Outdated Components

**Mitigations:**
- **Python:** `pip-audit` в CI на каждый PR (`pip install pip-audit && pip-audit -r requirements.txt`); блокирует merge при critical CVE.
- **Node:** `npm audit --audit-level=high` в CI; блокирует merge.
- **Dependabot** включён в репозитории (auto-PRs на security updates еженедельно).
- Lockfile (poetry.lock / package-lock.json) коммитится в git.
- Базовый Docker-образ: `python:3.12-slim` (актуальный patch), `node:20-alpine`; auto-rebuild раз в неделю.
- Запрет на установку библиотек из непроверенных источников (только PyPI/npm-registry, не git-URL).
- Раз в квартал — ручной аудит зависимостей (Architect + Security).

---

## A07:2021 — Identification and Authentication Failures

**Mitigations:**
- **Mini-app:** Telegram init_data + HMAC валидация + TTL 24ч (см. threat-model.md T-IA-01).
- **Админка:** username/password + TOTP 2FA обязателен для всех ролей. Django + `django-otp`.
- **Bot commands:** проверка `telegram_user_id` из Telegram update (нельзя подделать через бота).
- **Rate limiting:** `/auth/login` — 5 попыток/15 мин, `/auth/refresh` — 30 req/мин.
- **JWT:**
  - Access TTL 15 мин, refresh 7 дней с rotation on use.
  - `jti` + Redis-блэклист на logout.
  - Refresh — httpOnly cookie (где возможно).
- **Password policy для админов:** min 12 chars, complexity check (django-password-validators); запрет на 100 топ-паролей.
- **Account lockout:** django-axes, lockout 1 час после 5 fail.
- **Session timeout:** admin — 8 часов inactive logout.
- **Логирование:** все login attempts (success + fail) → AuditLog `admin_login_success` / `admin_login_failed` с IP + UA.

---

## A08:2021 — Software and Data Integrity Failures

**Mitigations:**
- **Webhook signatures:**
  - ЮKassa: HMAC-SHA256 от body с секретом из Vault; сравнение через `hmac.compare_digest` (constant-time).
  - USDT-провайдер: signature/HMAC по их спецификации.
  - Подробно — payments-security.md.
- **CI/CD integrity:**
  - GitHub Actions workflow только из защищённой `main` ветки.
  - Signed commits для prod-deploy (опционально, рекомендация).
  - Деплой только из CI, не вручную с локальной машины.
- **Frontend SRI (Subresource Integrity):** для всех external scripts (telegram-web-app.js) — `integrity="sha384-..."`.
- **Docker:** pin digest для базовых образов (`python:3.12-slim@sha256:...`); проверка в CI.
- **DB integrity:**
  - `AuditLog` — read-only в Django Admin (rule 04).
  - Ежедневный dump audit log → WORM (S3 Object Lock 90 дней).
  - PG WAL-архивирование для PITR.

---

## A09:2021 — Security Logging and Monitoring Failures

**Mitigations:**
- **AuditLogService** обязателен на всех CRUD + events + scheduled tasks (rule 04-logging.md).
- Защищённые поля (`AUDIT_MASKED_FIELDS`) маскируются автоматически.
- Файлы: `logs/app.log`, `logs/audit.log`, `logs/scheduler.log`, `logs/errors.log` с ротацией.
- DB: `AuditLog` модель с retention 90 дней (`AUDIT_LOG_RETENTION_DAYS`).
- **Alerting:**
  - Критические события в админ-чат: failed webhook signature, brute-force lockout, 5xx > N/мин, payment exception, prompt-injection detection.
  - Канал: Telegram (бот пишет в админ-чат) + email на security@.
- **Monitoring stack (SRE Phase 8):** Prometheus + Grafana или Sentry для exception tracking.
- **Запрет на логирование секретов:** ESLint/flake8 правило `flake8-logging-format` + custom check `no .info(password)`.
- **Тесты:** при изменении модели — тест что AuditLog создан (fixture-based).

---

## A10:2021 — Server-Side Request Forgery (SSRF)

**Риски:** AI inference (Anthropic), Forex API, USDT-провайдер, ЮKassa, Listener bot к Telegram MTProto, потенциальные user-controlled URL (avatar upload?).

**Mitigations:**
- **Outbound whitelist** на уровне приложения и/или firewall:
  - `https://api.anthropic.com`
  - `https://api.cbr-xml-daily.ru` (или ЦБ РФ конкретный домен)
  - `https://api.yookassa.ru`
  - USDT-провайдер (определяется в Phase 5)
  - `https://api.telegram.org`
- Запрет на user-controlled URL в server-side requests. Если нужен (например, аватар) — валидация:
  - Domain whitelist (telegram CDN: `t.me`, `*.cdn-telegram.org`).
  - Запрет IP-литералов (`10.*`, `192.168.*`, `127.*`, `169.254.*`).
  - DNS-rebinding protection: resolve один раз, проверить IP, передать `socket._connect_to_resolved_ip`.
- Использовать `requests` с явным `proxies={}` (не наследовать env), `allow_redirects=False` или ограничить (max 3).
- Внутренняя сеть: Django/Redis/PostgreSQL — отдельный Docker network; outbound через прокси-контейнер с ACL.
- Timeout на все outbound: 10 сек default, 30 сек для AI.

---

## Чеклист готовности (Quality Gate Architecture)

- [ ] A01: RBAC permission_classes на всех ViewSets + matrix tests.
- [ ] A02: TLS 1.2+, HSTS, secrets в Vault, AES для KYC.
- [ ] A03: ORM only, no f-string SQL, CSP, escape_markdown.
- [ ] A04: Threat model + FSM + idempotency + audit.
- [ ] A05: `manage.py check --deploy` clean; security headers в Nginx.
- [ ] A06: pip-audit + npm audit в CI; Dependabot включён.
- [ ] A07: 2FA для админов; rate limit auth; init_data HMAC.
- [ ] A08: HMAC webhook; SRI; signed commits (опционально); WORM audit dump.
- [ ] A09: AuditLogService на CRUD + events; alert в админ-чат.
- [ ] A10: Outbound whitelist; нет user-controlled URL.

---

*Документ создан: Security Agent | Дата: 2026-05-16*
