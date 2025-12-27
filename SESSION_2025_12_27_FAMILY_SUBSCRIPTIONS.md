# Сессия 27.12.2025 — Семейные абонементы

## Обзор

Реализована система семейных абонементов (shared subscriptions), позволяющая нескольким ученикам (братьям/сёстрам) делить один абонемент с общим пулом занятий.

## Бизнес-логика

- **Общий пул занятий:** 10 занятий на семью = 10 посещений любым участником
- При завершении занятия ЛЮБОГО участника — списывается 1 занятие из общего пула
- **Приоритет списания:** сначала личные подписки, потом семейные (FIFO по дате истечения)
- Создаётся при оплате: пользователь выбирает несколько учеников (минимум 2)
- Отображается в карточке каждого участника

---

## Изменения в базе данных

### Новая таблица `subscription_members`

```sql
CREATE TABLE subscription_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(subscription_id, student_id)
);
```

### Новое поле в `subscriptions`

```sql
ALTER TABLE subscriptions ADD COLUMN is_family BOOLEAN NOT NULL DEFAULT FALSE;
```

### VIEW `student_subscription_summary`

Вычисляет баланс с учётом семейных подписок:
- `active_balance` — занятия из активных подписок (личных + семейных)
- `expired_balance` — занятия из истёкших подписок
- `nearest_expiration` — ближайшая дата истечения
- `has_frozen_subscription` — есть ли замороженные

### Обновлённые SQL функции

- `get_student_active_balance(p_student_id)` — учитывает семейные
- `deduct_lesson_from_subscription(p_student_id)` — приоритет личных, потом семейные

**Файл миграции:** `supabase/migrations/add_family_subscriptions.sql`

---

## Изменения в коде

### Модели

**`lib/shared/models/subscription.dart`**
- Добавлен класс `SubscriptionMember`
- Поля: `isFamily`, `members: List<SubscriptionMember>?`
- Геттеры: `isFamilySubscription`, `memberStudents`, `displayMemberNames`, `memberCount`

**`lib/shared/models/payment.dart`**
- Поле `subscription: Subscription?` (для отображения участников)
- Геттеры: `isFamilySubscription`, `displayMemberNames`

### Репозитории

**`lib/features/subscriptions/repositories/subscription_repository.dart`**
- `createFamily()` — создание семейного абонемента
- `deductLesson()` — обновлён для поиска семейных подписок
- `getByStudentIncludingFamily()` — личные + семейные подписки
- `addFamilyMember()`, `removeFamilyMember()` — управление участниками

**`lib/features/students/repositories/student_repository.dart`**
- `getByInstitution()` — баланс из VIEW `student_subscription_summary`
- `getById()` — аналогично

**`lib/features/payments/repositories/payment_repository.dart`**
- `getByPeriod()` — включает `subscriptions(*, subscription_members(*, students(*)))`

### Провайдеры

**`lib/features/subscriptions/providers/subscription_provider.dart`**
- `studentAllSubscriptionsProvider` — личные + семейные
- `allSubscriptionsStreamProvider` — realtime для всех подписок
- `SubscriptionController.createFamily()`, `addMember()`, `removeMember()`

**`lib/features/payments/providers/payment_provider.dart`**
- `PaymentController.createFamilyPayment()` — создание семейной оплаты

### UI

**`lib/features/payments/screens/payments_screen.dart`**
- `_AddPaymentSheet` — переключатель "Семейный абонемент"
- Список учеников с чекбоксами (минимум 2)
- `_PaymentCard` — показывает всех участников + иконка семьи

**`lib/features/students/screens/student_detail_screen.dart`**
- `_SubscriptionCard` — бейдж "Семейный" (фиолетовый)
- Chips с именами всех участников
- Текущий ученик выделен в списке

---

## Исправленные баги

1. **Dropdown assertion error** — при выборе учеников для семейного абонемента
   - Решение: заменён dropdown на список с чекбоксами

2. **Баланс в списке учеников** — показывал 0 для участников семейного абонемента
   - Причина: `prepaid_lessons_count` обновлялся только для первого ученика
   - Решение: баланс теперь из VIEW `student_subscription_summary`

3. **JOIN с VIEW** — Supabase не поддерживает JOIN с VIEW через PostgREST
   - Решение: два отдельных запроса + merge в Dart

4. **Карточка оплаты** — показывала только первого ученика
   - Решение: загрузка `subscription.members` и `payment.displayMemberNames`

---

## Критические файлы

| Файл | Назначение |
|------|------------|
| `supabase/migrations/add_family_subscriptions.sql` | Миграция БД |
| `lib/shared/models/subscription.dart` | Модель + SubscriptionMember |
| `lib/features/subscriptions/repositories/subscription_repository.dart` | CRUD семейных |
| `lib/features/students/repositories/student_repository.dart` | Баланс из VIEW |
| `lib/features/payments/screens/payments_screen.dart` | UI создания |
| `lib/features/students/screens/student_detail_screen.dart` | Отображение |

---

## Тестирование

1. Создать оплату → включить "Семейный абонемент" → выбрать 2+ учеников
2. Проверить список учеников — все показывают одинаковый баланс
3. Проверить карточку ученика — виджет абонемента с участниками
4. Завершить занятие одного участника — баланс уменьшается у всех
5. Проверить экран оплат — имена всех участников + иконка семьи
