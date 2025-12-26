# SESSION 2025-12-27: Расширение системы прав доступа

## Обзор

Сессия посвящена расширению системы прав доступа участников заведения:
- Разделение прав на управление учениками
- Улучшение безопасности кода приглашения
- Режим "только просмотр" для карточек учеников
- Исправление багов

## Коммиты

### 1. `72bd24d` - feat: update default permissions for new members + fix lesson complete error

**Изменения:**
- Обновлены базовые права для новых участников (добавлены manageStudents, manageGroups, deleteOwnLessons, viewPayments)
- `joinByCode` теперь использует `MemberPermissions().toJson()` вместо хардкода
- Исправлена ошибка при отметке занятия как "Проведено" - ошибки списания с подписки больше не блокируют изменение статуса

**Файлы:**
- `lib/shared/models/institution_member.dart`
- `lib/features/institution/repositories/institution_repository.dart`
- `lib/features/schedule/providers/lesson_provider.dart`

### 2. `eca920b` - feat: split student management permissions + hide invite code + read-only mode

**Изменения:**

#### Разделение прав на управление учениками
- `manageStudents` разделён на `manageOwnStudents` и `manageAllStudents`
- `manageOwnStudents` = управление учениками, привязанными к текущему преподавателю
- `manageAllStudents` = управление всеми учениками заведения
- Обратная совместимость: старое `manage_students` мигрируется в `manageOwnStudents`

#### Скрытие кода приглашения
- Код приглашения убран с экрана списка заведений (был виден всем)
- В настройках код виден только владельцу заведения
- Кнопка обновления кода доступна только владельцу

#### Режим "только просмотр" для карточек учеников
- Добавлен провайдер `isMyStudentProvider` для проверки привязки ученика к преподавателю
- При отсутствии прав скрываются:
  - Кнопка редактирования (карандаш в AppBar)
  - Кнопка добавления оплаты
  - Кнопки управления абонементами (заморозить/разморозить/продлить)
  - Кнопки добавления/удаления преподавателей
  - Кнопки добавления/удаления предметов
- Кнопка добавления ученика в списке тоже скрывается при отсутствии прав

**Файлы:**
- `lib/shared/models/institution_member.dart`
- `lib/features/institution/screens/member_permissions_screen.dart`
- `lib/features/institution/screens/settings_screen.dart`
- `lib/features/institution/screens/institutions_list_screen.dart`
- `lib/features/students/providers/student_provider.dart`
- `lib/features/students/screens/student_detail_screen.dart`
- `lib/features/students/screens/students_list_screen.dart`

## Структура прав MemberPermissions

### До изменений
```dart
manageStudents: bool  // Общее право на управление учениками
```

### После изменений
```dart
manageOwnStudents: bool   // Управление своими учениками (default: true)
manageAllStudents: bool   // Управление всеми учениками (default: false)
```

## Логика проверки прав на редактирование ученика

```dart
// Получаем данные
final permissions = ref.watch(myPermissionsProvider(institutionId));
final institutionAsync = ref.watch(currentInstitutionProvider(institutionId));
final isMyStudentAsync = ref.watch(isMyStudentProvider(
  IsMyStudentParams(studentId, institutionId),
));

// Проверяем владельца
final isOwner = institutionAsync.maybeWhen(
  data: (inst) => inst.ownerId == ref.watch(currentUserIdProvider),
  orElse: () => false,
);

// Проверяем привязку ученика
final isMyStudent = isMyStudentAsync.maybeWhen(
  data: (v) => v,
  orElse: () => false,
);

// Итоговое право на редактирование
final canEditStudent = isOwner ||
    (permissions?.manageAllStudents ?? false) ||
    (isMyStudent && (permissions?.manageOwnStudents ?? false));
```

## Провайдер isMyStudentProvider

Новый провайдер для проверки, является ли ученик "своим" (привязан к текущему пользователю через `student_teachers`):

```dart
class IsMyStudentParams {
  final String studentId;
  final String institutionId;
  // ...
}

final isMyStudentProvider =
    FutureProvider.family<bool, IsMyStudentParams>((ref, params) async {
  final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
  if (currentUserId == null) return false;

  final bindingsRepo = ref.read(studentBindingsRepositoryProvider);
  final myStudentIds = await bindingsRepo.getTeacherStudentIds(
    currentUserId,
    params.institutionId,
  );

  return myStudentIds.contains(params.studentId);
});
```

## Базовые права для новых участников

При присоединении по коду приглашения участник получает:

| Право | Значение |
|-------|----------|
| createLessons | true |
| editOwnLessons | true |
| viewAllSchedule | true |
| manageOwnStudents | true |
| manageGroups | true |
| deleteOwnLessons | true |
| viewPayments | true |

## Обратная совместимость

### fromJson
```dart
// Старое manage_students мигрируется в manageOwnStudents
manageOwnStudents: json['manage_own_students'] as bool? ??
                   json['manage_students'] as bool? ?? false,
manageAllStudents: json['manage_all_students'] as bool? ?? false,
```

### toJson
```dart
// Для RLS политики в Supabase
'manage_students': manageOwnStudents || manageAllStudents,
'manage_own_students': manageOwnStudents,
'manage_all_students': manageAllStudents,
```

## Исправление ошибки при отметке занятия

### Проблема
При нажатии "Проведено" появлялась ошибка, хотя занятие успешно отмечалось. Причина: ошибка при списании с подписки блокировала весь метод.

### Решение
Операции с подпиской обёрнуты в отдельный try-catch:

```dart
Future<bool> complete(String id, String roomId, DateTime date) async {
  try {
    await _repo.complete(id);  // Изменение статуса

    // Списание с подписки - не критичная операция
    if (lesson.studentId != null) {
      try {
        final subscriptionId = await _subscriptionRepo.deductLessonAndGetId(...);
        if (subscriptionId != null) {
          await _repo.setSubscriptionId(id, subscriptionId);
        }
      } catch (e) {
        debugPrint('Error deducting subscription: $e');
        // Ошибка игнорируется - занятие всё равно проведено
      }
    }

    return true;
  } catch (e, st) {
    return false;
  }
}
```

## UI изменения

### Экран настроек прав (member_permissions_screen.dart)
Секция "Ученики и группы" теперь содержит:
- "Управление своими учениками" - добавление, редактирование своих учеников
- "Управление всеми учениками" - редактирование учеников любого преподавателя
- "Управление группами" - создание групп, управление составом

### Экран списка заведений (institutions_list_screen.dart)
- Убрано отображение кода приглашения под названием заведения

### Экран настроек заведения (settings_screen.dart)
- Секция с кодом приглашения видна только владельцу (`if (isOwner)`)

### Экран деталей ученика (student_detail_screen.dart)
- Все интерактивные элементы скрываются при `canEditStudent == false`
- `_TeachersSection` и `_SubjectsSection` получили параметр `canEdit`
- `_BalanceAndCostCard` и `_SubscriptionCard` получили nullable callbacks

## Итоги

- Улучшена безопасность: код приглашения скрыт от обычных участников
- Гибкая система прав: преподаватели могут управлять только своими учениками
- Лучший UX: режим "только просмотр" без лишних кнопок
- Исправлен баг с ошибкой при отметке занятия
