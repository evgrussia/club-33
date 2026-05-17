---
title: "ADR-006: RBAC Strategy"
created_by: "Architect Agent"
created_at: "2026-05-16"
version: "1.0"
phase: "Architecture"
---

# ADR-006: RBAC Strategy

**Status:** Accepted
**Date:** 2026-05-16
**Author:** Architect Agent

## Контекст

DEC-005 фиксирует 3 уровня админ-ролей: super / moderator / support. Плюс пользовательские роли (lifetime/active/expired/blocked). Нужна целостная стратегия проверки прав.

## Решение

### 1. Двухуровневая модель ролей

```
AdminRole (для админ-панели):
  - super
  - moderator
  - support

UserAccessLevel (для участников):
  - candidate          # ещё не оплатил
  - active             # активная подписка
  - lifetime           # бессрочный доступ
  - grace              # истекла, но 7 дней grace
  - expired            # истекла, доступ revoked
  - blocked            # заблокирован модератором
```

Один пользователь может быть одновременно: `active` (доступ участника) + `moderator` (доступ к админке) — независимые роли.

### 2. Permissions (детальная матрица) — DEC-005

| Permission | super | moderator | support |
|---|---|---|---|
| `applications.approve` | ✅ | ✅ | ❌ |
| `applications.reject` | ✅ | ✅ | ❌ |
| `payments.confirm_manual` (СБП) | ✅ | ❌ | ✅ |
| `subscriptions.grant_lifetime` | ✅ | ❌ | ❌ |
| `time_economy.admin_convert` | ✅ | ❌ | ❌ |
| `social.moderate_complaints` | ✅ | ✅ | ❌ |
| `social.adjust_respects` | ✅ | ✅ | ❌ |
| `social.crud_roles` | ✅ | ✅ | ❌ |
| `users.kyc_flag` | ✅ | ✅ | ❌ |
| `payments.view_logs` | ✅ | ✅ | ✅ |
| `users.chat` | ✅ | ✅ | ✅ |
| `finance.export` | ✅ | ❌ | ❌ |
| `admin.dashboard.view_full` | ✅ | partial | partial |

### 3. Технология

**Backend:**
```python
# Django permissions custom check
from django.contrib.auth.decorators import permission_required

@permission_required('payments.confirm_manual', raise_exception=True)
def confirm_sbp(request, invoice_id):
    ...

# DRF
class GrantLifetimeView(APIView):
    permission_classes = [IsAuthenticated, HasAdminPermission('subscriptions.grant_lifetime')]
```

**Frontend (admin):**
```typescript
const { permissions } = useAuth()
{permissions.has('subscriptions.grant_lifetime') && <LifetimeButton />}
```

Sidebar админки **скрывает** пункты по RBAC (DEC-UX-007), не делает disabled.

### 4. RBAC сервис

```python
class RBACService:
    @staticmethod
    def can(user, permission: str, target=None) -> bool:
        # 1. Если user.admin_role == 'super' → True (кроме явных блокировок)
        # 2. Permission лежит в RolePermission(role=user.admin_role)
        # 3. Optional: target-based check (например, не редактировать свою заявку)
```

Кеш в Redis: `rbac:user:{id}` TTL 5 мин, инвалидируется при изменении ролей.

### 5. Bot RBAC

```python
@admin_only(['super', 'moderator'])
async def admin_command_handler(message: Message):
    ...
```

Проверка через `users.is_staff` + `users.admin_role`.

### 6. Audit обязателен

Каждое admin-действие → AuditLog с указанием permission и target.

```python
AuditLogService.log_admin_action(
    action='lifetime_granted',
    permission='subscriptions.grant_lifetime',
    actor=request.user,
    target_user=target,
    data={'reason': ...}
)
```

### 7. Initial roles

- Founder = super (один человек).
- Назначение admin_role — только super-админом.
- Super-роль может быть у нескольких людей (но рекомендация — 1-2 человека).

## Альтернативы

| Альтернатива | Почему отклонена |
|---|---|
| Одна роль "admin" | DEC-005 требует разделения; принцип least privilege |
| Django Groups напрямую | Менее наглядно; кастомная матрица понятнее |
| ABAC (attribute-based) | Сложнее в MVP; RBAC + ad-hoc target check достаточно |
| Open Policy Agent | Overkill для MVP |
| Permissions hardcoded vs DB-driven | Hardcoded — простота; матрица меняется редко |

## Последствия

- Прозрачная матрица для команды.
- Меньше человеческих ошибок (модератор не может выдать lifetime).
- Audit-trail для compliance.
- Расширяемо: добавить новую роль = одна запись в матрице.

## Связанные документы

- DEC-005
- `processes-overview.md` § 3.4 RBAC матрица
- `information-architecture.md` § 3.2 видимость по ролям
- `nfr-specs.md` § Security
- TASK-010 Security Agent — детальный threat model

---

*Документ создан: Architect Agent | Дата: 2026-05-16*
