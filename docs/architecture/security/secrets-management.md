---
title: "Клуб 33 — Secrets Management"
created_by: "Security Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# Secrets Management

Управление секретами: хранение, доступ, ротация. Принцип — **secrets никогда не в git, не в коде, не в plaintext-логах.**

---

## 1. Инвентаризация секретов

| Секрет | Назначение | Уровень критичности | Где используется |
|---|---|---|---|
| `TELEGRAM_BOT_TOKEN` | Telegram Bot API | critical | Бот, mini-app init_data validation |
| `TELEGRAM_LISTENER_API_ID` | MTProto Listener | high | Listener service |
| `TELEGRAM_LISTENER_API_HASH` | MTProto Listener | high | Listener service |
| `TELEGRAM_LISTENER_SESSION` | MTProto session string | critical | Listener service |
| `ANTHROPIC_API_KEY` | Anthropic Claude API | critical (cost-impact) | AI service |
| `VOYAGE_API_KEY` (если voyage-3) | Embeddings | high | AI service |
| `YOOKASSA_SHOP_ID` | ЮKassa identification | medium | Payments service |
| `YOOKASSA_SECRET_KEY` | ЮKassa API auth | critical | Payments service |
| `YOOKASSA_WEBHOOK_SECRET` | HMAC verification | critical | Webhook handler |
| `USDT_PROVIDER_API_KEY` | USDT-провайдер API | critical | Payments service |
| `USDT_PROVIDER_WEBHOOK_SECRET` | USDT webhook HMAC | critical | Webhook handler |
| `FOREX_API_KEY` (если платный) | USD→RUB rate | low | Payments service |
| `DJANGO_SECRET_KEY` | Django sessions/CSRF | critical | Django backend |
| `JWT_SECRET_ACCESS` | JWT access token signing | critical | Auth service |
| `JWT_SECRET_REFRESH` | JWT refresh token signing | critical | Auth service |
| `POSTGRES_PASSWORD` | DB access | critical | Backend + migrations |
| `POSTGRES_REPLICATION_PASSWORD` | Replica auth | high | Replication setup |
| `REDIS_PASSWORD` | Redis access | high | Backend + cache |
| `AES_KEY_KYC` | KYC field encryption | critical | KYC service |
| `AES_KEY_AUDIT` | Audit log dump encryption | high | Backup service |
| `SENTRY_DSN` | Error tracking | medium | All services |
| `EMAIL_SMTP_PASSWORD` | Notifications | medium | Notification service |
| `S3_ACCESS_KEY` / `S3_SECRET` | Backup WORM storage | high | Backup service |
| `ADMIN_DEFAULT_PASSWORD` (initial) | Bootstrap | high | Setup only, удалить после first login |

**Итого: 24 секрета.**

---

## 2. Хранение

### 2.1 Production

**Рекомендация Security:** **HashiCorp Vault** (или альтернатива — Doppler / AWS Secrets Manager / Yandex Lockbox для РФ-хостинга).

**Минимальный fallback для Phase 1 (MVP):** dotenv в `/opt/club33/.env`:
- `chmod 600 /opt/club33/.env`
- `chown club33:club33 /opt/club33/.env`
- Файл вне git (.gitignore проверяется в CI).
- Backup .env шифрованным GPG в отдельном хранилище (1Password Business, Bitwarden).

**Docker secrets** (если Docker Swarm):
```yaml
secrets:
  django_secret_key:
    external: true
  anthropic_api_key:
    external: true
```

**Phase 2+: миграция в Vault** обязательна. Vault даёт:
- Audit log доступа к секретам.
- Dynamic secrets (короткоживущие credentials).
- Automatic rotation.

### 2.2 Local development

- `.env.local` — НЕ в git (gitignore).
- `.env.example` — в git, без значений, с описанием каждой переменной.
- Local-секреты — фейковые / sandbox-ключи провайдеров.
- ЮKassa sandbox, Anthropic dev-key с лимитом $5/мес.

### 2.3 CI/CD (GitHub Actions)

- Все секреты в GitHub Actions Secrets (encrypted at rest).
- Раздельные секреты для `staging` и `production` environments.
- Запрет echo secrets в логах (`::add-mask::` в workflow для динамических secrets).
- Деплой через SSH с ключом из GitHub Secrets; на VPS — секреты через Vault/Docker.

---

## 3. Доступ к секретам

### 3.1 Кто имеет доступ

| Роль | Production | Staging | Dev |
|---|---|---|---|
| Founder | read (через Vault audit) | ❌ | ❌ |
| Lead Developer | read/write (Vault) | read/write | read/write |
| Backend Developer | ❌ | read | read/write (local) |
| DevOps | read/write | read/write | read |
| SRE | read | read | ❌ |
| Все остальные | ❌ | ❌ | ❌ |

### 3.2 Принципы

- **Least privilege:** developer не имеет прямого доступа к prod-секретам.
- **Audit:** Vault логирует каждый доступ; раз в неделю review.
- **No secrets in tickets/Slack/Telegram:** запрет на отправку секретов в чатах.
- **Onboarding:** новый developer получает доступ только к dev-секретам; staging — после 1 мес и code review; prod — только с Lead.
- **Offboarding:** revoke всех ключей в течение 24ч после ухода.

---

## 4. Ротация

| Секрет | Период ротации | Триггер немедленной ротации |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | по запросу | Утечка / смена ответственного |
| `TELEGRAM_LISTENER_SESSION` | каждые 90 дней | Подозрение на компрометацию |
| `ANTHROPIC_API_KEY` | каждые 6 месяцев | Cost-аномалия, утечка |
| `YOOKASSA_SECRET_KEY` | каждые 12 месяцев | Утечка |
| `USDT_PROVIDER_API_KEY` | каждые 6 месяцев | Утечка |
| `DJANGO_SECRET_KEY` | **никогда** (требует invalidate всех sessions) | Утечка → exit план |
| `JWT_SECRET_ACCESS/REFRESH` | каждые 12 месяцев (с graceful rollover) | Утечка → revoke all JWT |
| `POSTGRES_PASSWORD` | каждые 12 месяцев | Утечка |
| `REDIS_PASSWORD` | каждые 12 месяцев | Утечка |
| `AES_KEY_KYC` | **никогда без миграции данных** (требуется re-encryption всех KYC) | Утечка → emergency re-encryption |
| `S3_*` | каждые 12 месяцев | Утечка |
| `SENTRY_DSN` | каждые 24 месяца | Утечка |

**Процесс ротации (пример Anthropic API Key):**
1. Создать новый key в Anthropic console.
2. Установить в Vault (новая версия secret).
3. Rolling restart pods/контейнеров (читают свежую версию).
4. Проверить, что новый key работает (health check).
5. Revoke старый key в Anthropic console.
6. AuditLog `secret_rotated` с актором, типом, timestamp.

**Graceful rollover для JWT_SECRET:**
- Хранить два секрета: `JWT_SECRET_CURRENT` + `JWT_SECRET_PREVIOUS`.
- Подписывать — текущим, валидировать — оба.
- Через TTL refresh tokens (7 дней) удалить PREVIOUS.

---

## 5. Шифрование at rest

### 5.1 Disk encryption

VPS Ubuntu 24.04: LUKS на data-разделе (либо BitLocker-аналог у провайдера).

### 5.2 Database

- PostgreSQL TDE — нет встроенного; используем disk encryption + selective field encryption.
- `django-encrypted-model-fields` для KYC, специальных категорий.
- Connection: `sslmode=require` обязательно.

### 5.3 Backups

- PG dump → gzip → GPG encrypt → upload в S3-compatible (с Object Lock 90 дней).
- Encryption key для GPG — отдельный от Vault, hardcopy в сейфе Founder.

### 5.4 Logs

- `logs/*` локально — disk encryption.
- При экспорте в централизованный лог (Sentry / ELK Phase 2) — TLS, не логируем secrets (rule 04 + `AUDIT_MASKED_FIELDS`).

---

## 6. Запрет на коммит секретов

**Pre-commit hook** (рекомендую) + **CI check**:

`.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/zricethezav/gitleaks
    rev: v8.x
    hooks:
      - id: gitleaks
```

В CI (GitHub Actions):
```yaml
- name: Gitleaks scan
  uses: gitleaks/gitleaks-action@v2
```

**При случайном commit-leak:**
1. Revoke секрет немедленно.
2. Rotate.
3. `git filter-repo` (или BFG) → force-push (только если ещё не было pull другими).
4. Если был pull — секрет считать compromised навсегда.
5. AuditLog `secret_leak_detected` + post-mortem.

---

## 7. Bootstrap (первый запуск)

1. DevOps создаёт VPS, устанавливает Docker.
2. Генерирует все секреты локально:
   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(64))"
   ```
3. Заполняет `/opt/club33/.env` (chmod 600).
4. Создаёт первого Django superuser:
   - Через `manage.py createsuperuser --no-input` с временным паролем (env var `ADMIN_DEFAULT_PASSWORD`).
   - Первый вход → принудительная смена пароля + setup TOTP.
   - `ADMIN_DEFAULT_PASSWORD` удаляется из .env сразу после.
5. AuditLog `bootstrap_completed`.

---

## 8. Чеклист для DevOps Agent (Phase 8)

- [ ] `.env.example` создан и закоммичен (без значений).
- [ ] `.gitignore` включает `.env`, `.env.local`, `.env.production`.
- [ ] Gitleaks pre-commit hook + CI check настроены.
- [ ] `manage.py check --deploy` зелёный.
- [ ] Vault настроен (Phase 2+) или /opt/club33/.env chmod 600 (Phase 1).
- [ ] Docker secrets или env_file в docker-compose.
- [ ] GitHub Actions Secrets для CI/CD заданы.
- [ ] LUKS на VPS data-разделе.
- [ ] PG `sslmode=require` в connection string.
- [ ] Backup pipeline: dump → gzip → GPG → S3 Object Lock.
- [ ] Ротационный план в runbook `docs/runbooks/secret-rotation.md`.

---

## 9. Runbooks

DevOps/SRE Phase 8 создаёт runbooks:
- `docs/runbooks/secret-rotation.md` — пошаговая ротация каждого секрета.
- `docs/runbooks/secret-leak-response.md` — действия при утечке.
- `docs/runbooks/bootstrap.md` — первый запуск с нуля.

---

*Документ создан: Security Agent | Дата: 2026-05-16*
