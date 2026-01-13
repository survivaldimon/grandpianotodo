# SESSION 2026-01-13: Balance Transfer System

## Обзор сессии

Сегодняшняя сессия была посвящена реализации **системы переноса остатка занятий (Balance Transfer)** и сопутствующим улучшениям UI.

---

## 1. Система Balance Transfer (Остаток занятий)

### Концепция

Остаток занятий — это занятия, которые ученик принёс из другой школы или которые были начислены администратором. В отличие от подписок:
- Не имеют срока действия
- Не связаны с оплатой (сумма = 0)
- Списываются **первыми** (до подписок и prepaid)

### Приоритет списания

```
1. Balance Transfer (остаток) — списывается ПЕРВЫМ
2. Subscription (абонемент)
3. Prepaid/Debt (предоплата/долг)
```

### SQL миграции

#### `20260113_add_balance_transfer.sql`
```sql
-- Новые поля в payments
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS is_balance_transfer BOOLEAN NOT NULL DEFAULT FALSE;
ADD COLUMN IF NOT EXISTS transfer_lessons_remaining INT;

-- Индекс для быстрого поиска
CREATE INDEX idx_payments_active_balance_transfers
ON payments(student_id, is_balance_transfer)
WHERE is_balance_transfer = TRUE AND transfer_lessons_remaining > 0;

-- RPC функция списания (FIFO)
CREATE FUNCTION deduct_balance_transfer(p_student_id UUID) RETURNS UUID;

-- RPC функция возврата
CREATE FUNCTION return_balance_transfer_lesson(p_payment_id UUID) RETURNS void;

-- Поле в lessons для отслеживания
ALTER TABLE lessons ADD COLUMN transfer_payment_id UUID REFERENCES payments(id);

-- VIEW student_subscription_summary обновлён с transfer_balance
```

#### `20260113_add_lesson_is_deducted.sql`
```sql
-- Отслеживание списания для отменённых занятий
ALTER TABLE lessons ADD COLUMN is_deducted BOOLEAN DEFAULT FALSE;
```

#### `20260113_add_payment_has_subscription.sql`
```sql
-- Флаг оплат с подпиской (триггер пропускает такие записи)
ALTER TABLE payments ADD COLUMN has_subscription BOOLEAN DEFAULT FALSE;

-- Обновлённый триггер handle_payment_insert()
-- Миграция существующих оплат с тарифами в подписки
```

### Изменения в моделях

**Payment** (`lib/shared/models/payment.dart`):
```dart
final bool isBalanceTransfer;
final int? transferLessonsRemaining;
final bool hasSubscription;

bool get hasActiveTransfer => isBalanceTransfer && (transferLessonsRemaining ?? 0) > 0;
```

**Lesson** (`lib/shared/models/lesson.dart`):
```dart
final String? transferPaymentId;
final bool isDeducted;
```

### Изменения в репозиториях

**PaymentRepository** (`lib/features/payments/repositories/payment_repository.dart`):
```dart
Future<String?> deductBalanceTransfer(String studentId);
Future<void> returnBalanceTransferLesson(String paymentId);
Future<void> createBalanceTransfer({studentId, lessonsCount, comment});
Future<List<Payment>> getActiveBalanceTransfers(String studentId);
```

**LessonRepository** (`lib/features/schedule/repositories/lesson_repository.dart`):
```dart
Future<void> setTransferPaymentId(String lessonId, String transferPaymentId);
Future<void> clearTransferPaymentId(String lessonId);
Future<void> setIsDeducted(String lessonId, bool isDeducted);
```

### Изменения в контроллерах

**LessonController.complete()** — обновлён приоритет списания:
1. Сначала `deductBalanceTransfer()`
2. Затем `deductLessonAndGetId()` (подписка)
3. Затем `decrementPrepaidCount()` (долг)

**LessonController.uncomplete()** — возврат в правильный источник:
1. Проверка `transfer_payment_id` → возврат в balance transfer
2. Проверка `subscription_id` → возврат в подписку
3. Иначе → возврат в prepaid

**LessonController.delete()** — возврат перед удалением:
- Проверяет `transfer_payment_id` и возвращает занятие перед удалением

### Изменения в UI

**_LessonDetailSheet** (`all_rooms_schedule_screen.dart`):
- Добавлена переменная `_currentTransferPaymentId`
- Метод `_handleDeductionToggle()` переписан для работы с balance transfer

---

## 2. Обновление диалога редактирования ученика

### Что было
- Старый `AlertDialog` с базовыми полями

### Что стало
- Новый `_EditStudentSheet` — современный BottomSheet
- Секция "Основная информация": имя, телефон, комментарий
- Секция "Остаток занятий": текущий баланс + кнопка "Изменить" (+ и -)

### Файл
`lib/features/students/screens/student_detail_screen.dart`

---

## 3. Улучшение экрана учеников

### Строка поиска
- **Было:** Поиск в AppBar (неудобно)
- **Стало:** TextField под фильтрами с real-time фильтрацией

### Имена преподавателей
- **Проблема:** Имена не отображались под учениками
- **Решение:** Добавлена инвалидация `_studentTeacherNamesProvider` при refresh

### Файл
`lib/features/students/screens/students_list_screen.dart`

---

## 4. Исправления компактной сетки расписания

### Проблема
Нужно было нажимать несколько раз на ячейку для открытия диалога создания занятия (особенно на iOS).

### Решение
- Добавлен `HitTestBehavior.opaque` ко всем `GestureDetector`
- Вся свободная область ячейки теперь кликабельна (не только иконка +)
- Расширена область клика до размера свободного промежутка

### Затронутые виджеты
- `_CompactDayGrid._buildAddIconOverlays()`
- `_CompactDayGrid._buildRoomHeaders()`
- `_WeekTimeGrid._buildRoomHeaders()`
- `_WeekTimeGrid._buildDayCells()`

### Файл
`lib/features/schedule/screens/all_rooms_schedule_screen.dart`

---

## 5. Добавление даты и времени в форму создания занятия

### Проблема
При быстром создании занятия через FAB нельзя было изменить дату и время.

### Решение
Добавлены поля в `_QuickAddLessonSheet`:
- Выбор даты (DatePicker)
- Выбор времени начала и окончания (IosTimePicker)

---

## Изменённые файлы

| Файл | Изменения |
|------|-----------|
| `supabase/migrations/20260113_add_balance_transfer.sql` | Новая миграция |
| `supabase/migrations/20260113_add_lesson_is_deducted.sql` | Новая миграция |
| `supabase/migrations/20260113_add_payment_has_subscription.sql` | Новая миграция |
| `lib/shared/models/payment.dart` | +3 поля |
| `lib/shared/models/lesson.dart` | +2 поля |
| `lib/features/payments/repositories/payment_repository.dart` | +4 метода |
| `lib/features/schedule/repositories/lesson_repository.dart` | +3 метода |
| `lib/features/schedule/providers/lesson_provider.dart` | Логика списания |
| `lib/features/schedule/screens/all_rooms_schedule_screen.dart` | Toggle + tap fix |
| `lib/features/students/screens/student_detail_screen.dart` | Новый диалог |
| `lib/features/students/screens/students_list_screen.dart` | Поиск + имена |
| `lib/core/widgets/ios_time_picker.dart` | Минорные улучшения |

---

## Статистика изменений

```
15 files changed, 2359 insertions(+), 834 deletions(-)
```

---

## Известные проблемы / TODO

1. **Тестирование balance transfer** — требуется полное тестирование flow:
   - Создание ученика с остатком
   - Списание при проведении занятия
   - Возврат при отмене
   - Корректная работа тумблера в истории

2. **UI balance transfer в истории оплат** — отображение записей переноса

---

## Команды для применения миграций

```bash
# Применить миграции (в порядке)
psql -f supabase/migrations/20260113_add_payment_has_subscription.sql
psql -f supabase/migrations/20260113_add_lesson_is_deducted.sql
psql -f supabase/migrations/20260113_add_balance_transfer.sql
```

---

## Билд

Изменения готовы к коммиту под билд **1.0.0+23**.
