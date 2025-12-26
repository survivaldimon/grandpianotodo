# SESSION 2025-12-25: Система прав участников

## Обзор сессии

Сессия посвящена улучшению системы прав доступа участников заведения:
- Реализация realtime обновления прав
- Разделение права на удаление занятий на два отдельных права
- Исправление багов с отображением кнопки удаления

## Выполненные задачи

### 1. Realtime обновление прав участников

**Проблема:** Права, выданные админом участнику, не применялись на устройстве участника до перезапуска приложения.

**Причина:** `myMembershipProvider` был `FutureProvider`, который кэширует результат.

**Решение:**
- Изменён на `StreamProvider` с realtime обновлениями
- Добавлен метод `watchMyMembership()` в `InstitutionRepository`
- Стрим фильтрует изменения по `institution_id`
- При открытии деталей занятия вызывается принудительная инвалидация провайдера

**Файлы:**
- `lib/features/institution/repositories/institution_repository.dart`
- `lib/features/institution/providers/institution_provider.dart`

### 2. Разделение права на удаление занятий

**Было:** Одно право `deleteLessons`

**Стало:** Два права:
- `deleteOwnLessons` — удаление только своих занятий
- `deleteAllLessons` — удаление занятий любого преподавателя

**Логика проверки:**
```dart
final canDelete = isOwner ||
                  (permissions?.deleteAllLessons ?? false) ||
                  (isOwnLesson && (permissions?.deleteOwnLessons ?? false));
```

**Файлы:**
- `lib/shared/models/institution_member.dart` — модель с новыми полями
- `lib/features/institution/screens/member_permissions_screen.dart` — UI с двумя переключателями
- `lib/features/schedule/screens/schedule_screen.dart` — проверка прав
- `lib/features/schedule/screens/all_rooms_schedule_screen.dart` — проверка прав

### 3. Обратная совместимость с RLS

**Проблема:** RLS политика в Supabase проверяла старое поле `delete_lessons`.

**Решение:** В `toJson()` добавлено поле для совместимости:
```dart
'delete_lessons': deleteOwnLessons || deleteAllLessons,
```

### 4. Исправление проверки прав

**Проблема:** `currentUserIdProvider` мог возвращать `null` пока стрим не загрузился.

**Решение:** Использование прямого доступа к Supabase:
```dart
final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
```

### 5. Принудительное обновление прав

**Проблема:** После изменения прав админом, у участника кнопка удаления не исчезала.

**Решение:** При открытии `_LessonDetailSheet` вызывается:
```dart
Future.microtask(() {
  ref.invalidate(myMembershipProvider(widget.institutionId));
});
```

## Изменённые файлы

| Файл | Изменения |
|------|-----------|
| `lib/shared/models/institution_member.dart` | Новые поля `deleteOwnLessons`, `deleteAllLessons`, обратная совместимость |
| `lib/features/institution/repositories/institution_repository.dart` | Метод `watchMyMembership()` для realtime |
| `lib/features/institution/providers/institution_provider.dart` | `myMembershipProvider` как StreamProvider |
| `lib/features/institution/screens/member_permissions_screen.dart` | Два переключателя для удаления |
| `lib/features/institution/screens/members_screen.dart` | Проверка `manageMembers` права |
| `lib/features/institution/screens/settings_screen.dart` | Проверка `manageInstitution` права |
| `lib/features/schedule/screens/schedule_screen.dart` | Проверка прав на удаление, инвалидация |
| `lib/features/schedule/screens/all_rooms_schedule_screen.dart` | Проверка прав на удаление, инвалидация |
| `lib/features/students/screens/student_detail_screen.dart` | Проверка `archiveData` права |

## Технические заметки

### Supabase Stream ограничения
- `SupabaseStreamBuilder` поддерживает только **один** `.eq()` фильтр
- Дополнительная фильтрация выполняется в коде Dart

### Структура прав в JSON
```json
{
  "delete_own_lessons": true,
  "delete_all_lessons": false,
  "delete_lessons": true,  // для RLS совместимости
  // ... остальные права
}
```

### Требования к Supabase
Для работы realtime обновлений необходимо:
1. Включить Realtime для таблицы `institution_members` в Dashboard → Database → Replication

## Коммиты

1. `fix: implement realtime member permissions updates`
2. `feat: split delete lessons permission into own/all`
3. `fix: allow owner to delete any lesson`
4. `fix: emit initial membership value before listening to changes`
5. `fix: use direct Supabase access for currentUserId in permission checks`
6. `fix: add backwards compatibility for delete_lessons RLS policy`
7. `fix: improve realtime membership stream with proper filtering`
8. `fix: use single eq filter for Supabase stream`
9. `fix: force refresh permissions when opening lesson details`

## Известные ограничения

1. **Supabase Realtime** должен быть включен для таблицы `institution_members`
2. **RLS политика** в Supabase всё ещё использует старое поле `delete_lessons` — нужно обновить для полной поддержки раздельных прав
