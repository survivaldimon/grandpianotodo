# Отчёт о работе 11.01.2026 — Полный отчёт

## Обзор

Сессия включала несколько крупных улучшений: настройка кабинетов по умолчанию, компактный режим расписания, история занятий в карточке ученика, оптимизация проверки конфликтов, RLS политики и исправления.

---

## 1. Настройка кабинетов по умолчанию (Default Rooms)

### Описание
Новая функция позволяет участникам выбрать, какие кабинеты они хотят видеть по умолчанию в расписании. При первом входе показывается промпт для настройки.

### Изменения в модели

**Файл:** `lib/shared/models/institution_member.dart`

```dart
/// Кабинеты по умолчанию для расписания
/// null = не настроено (показать промпт)
/// [] = пропущено (показывать все кабинеты)
/// ['id1', 'id2'] = выбранные кабинеты
final List<String>? defaultRoomIds;

/// Настроены ли кабинеты по умолчанию
bool get hasRoomPreference => defaultRoomIds != null;

/// Показывать ли все кабинеты (пусто или не настроено)
bool get showAllRooms => defaultRoomIds == null || defaultRoomIds!.isEmpty;
```

### Провайдеры

**Файл:** `lib/features/institution/providers/member_provider.dart`

```dart
/// Провайдер проверки необходимости настройки кабинетов
final needsRoomSetupProvider = Provider.family<bool, String>((ref, institutionId) {
  final membership = ref.watch(myMembershipProvider(institutionId)).valueOrNull;
  if (membership == null) return false;
  return membership.defaultRoomIds == null;
});

/// Обновить кабинеты по умолчанию
Future<bool> updateDefaultRooms(String memberId, String institutionId, List<String>? roomIds)
```

### Репозиторий

**Файл:** `lib/features/institution/repositories/institution_repository.dart`

```dart
/// Обновить кабинеты по умолчанию для участника
Future<void> updateMemberDefaultRooms(String memberId, List<String>? roomIds)
```

### UI компоненты

**Файл:** `lib/features/schedule/screens/all_rooms_schedule_screen.dart`

- `_RoomSetupSheet` — BottomSheet с чекбоксами кабинетов
- `_checkRoomSetup()` — проверка необходимости настройки
- `_showRoomSetupSheet()` — показ промпта

### SQL миграция

**Файл:** `supabase/migrations/add_default_room_ids.sql`

```sql
ALTER TABLE institution_members
ADD COLUMN IF NOT EXISTS default_room_ids JSONB DEFAULT NULL;
```

---

## 2. Компактный режим расписания (Compact Day Grid)

### Описание
Новый виджет `_CompactDayGrid` для компактного отображения расписания на день, аналогичный недельному виду.

### Особенности
- Горизонтальная прокрутка кабинетов
- Вертикальная прокрутка по часам
- Синхронизация скролла заголовков и сетки
- Позиционированные блоки занятий/броней/слотов

**Файл:** `lib/features/schedule/screens/all_rooms_schedule_screen.dart`

```dart
class _CompactDayGrid extends StatefulWidget {
  final List<Room> rooms;
  final List<Lesson> lessons;
  final List<Booking> bookings;
  final List<StudentSchedule> scheduleSlots;
  // ...
}
```

---

## 3. История занятий в карточке ученика

### Описание
Секция "История занятий" в конце карточки ученика показывает проведённые и отменённые занятия с группировкой по месяцам и пагинацией.

### Метод репозитория

**Файл:** `lib/features/schedule/repositories/lesson_repository.dart`

```dart
/// Получить историю занятий ученика (проведённые и отменённые)
Future<List<Lesson>> getLessonHistoryForStudent(
  String studentId, {
  int limit = 20,
  int offset = 0,
}) async {
  // Индивидуальные занятия (student_id)
  // + Групповые занятия (через lesson_students)
  // Объединяем, убираем дубликаты, сортируем по дате (убывание)
}
```

### UI компоненты

**Файл:** `lib/features/students/screens/student_detail_screen.dart`

- `_LessonHistorySection` — секция с пагинацией и группировкой по месяцам
- `_LessonHistoryItem` — компактная карточка занятия

### Публичная функция

**Файл:** `lib/features/schedule/screens/all_rooms_schedule_screen.dart`

```dart
/// Показать детали занятия в модальном окне
/// Может быть вызвана из любого места приложения
void showLessonDetailSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Lesson lesson,
  required String institutionId,
  VoidCallback? onUpdated,
});
```

---

## 4. Оптимизация проверки конфликтов

### Описание
Оптимизирован метод `checkReassignmentConflicts()` — теперь выполняется 2 запроса вместо 2*N.

**Файл:** `lib/features/schedule/repositories/lesson_repository.dart`

### До (медленно)
```dart
for (final lesson in lessons) {
  // Запрос 1: проверка занятости преподавателя
  final teacherConflicts = await _client.from('lessons')...
  // Запрос 2: проверка брони кабинета
  final bookingConflicts = await _client.from('bookings')...
}
// Итого: 2*N запросов
```

### После (быстро)
```dart
// ОДИН запрос: все занятия нового преподавателя в диапазоне дат
final teacherLessonsData = await _client
    .from('lessons')
    .select('id, date, start_time, end_time')
    .eq('teacher_id', newTeacherId)
    .gte('date', minDateStr)
    .lte('date', maxDateStr);

// Проверяем конфликты в памяти
for (final lesson in lessons) {
  final hasConflict = teacherLessons.any((tl) => ...);
}
// Итого: 1-2 запроса
```

### Вспомогательный метод
```dart
bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
```

---

## 5. RLS политики для lesson_history

### Описание
Добавлены RLS политики для таблицы `lesson_history`, позволяющие участникам заведения просматривать и добавлять историю занятий.

**Файл:** `supabase/migrations/20260111_lesson_history_rls.sql`

```sql
-- Включаем RLS
ALTER TABLE lesson_history ENABLE ROW LEVEL SECURITY;

-- Политика на SELECT
CREATE POLICY "Members can view lesson history"
ON lesson_history FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM lessons l
    JOIN institution_members im ON im.institution_id = l.institution_id
    WHERE l.id = lesson_history.lesson_id
    AND im.user_id = auth.uid()
    AND im.archived_at IS NULL
  )
);

-- Политика на INSERT
CREATE POLICY "Members can insert lesson history"
ON lesson_history FOR INSERT
WITH CHECK (...);
```

---

## 6. Null-safety для Profile.fromJson

### Описание
Добавлены null-проверки в `Profile.fromJson()` для предотвращения падений при неполных данных.

**Файл:** `lib/shared/models/profile.dart`

```dart
factory Profile.fromJson(Map<String, dynamic> json) => Profile(
  id: json['id'] as String? ?? '',
  createdAt: json['created_at'] != null
      ? DateTime.parse(json['created_at'] as String)
      : DateTime.now(),
  updatedAt: json['updated_at'] != null
      ? DateTime.parse(json['updated_at'] as String)
      : DateTime.now(),
  fullName: json['full_name'] as String? ?? 'Без имени',
  email: json['email'] as String? ?? '',
  avatarUrl: json['avatar_url'] as String?,
);
```

---

## Изменённые файлы

| Файл | +/- строк | Описание |
|------|-----------|----------|
| `lib/shared/models/institution_member.dart` | +17 | Поле `defaultRoomIds` и хелперы |
| `lib/shared/models/profile.dart` | +14/-5 | Null-safety в fromJson |
| `lib/features/institution/providers/member_provider.dart` | +35 | `needsRoomSetupProvider`, `updateDefaultRooms()` |
| `lib/features/institution/repositories/institution_repository.dart` | +18 | `updateMemberDefaultRooms()` |
| `lib/features/institution/screens/members_screen.dart` | +10/-5 | Мелкие правки |
| `lib/features/schedule/repositories/lesson_repository.dart` | +200/-150 | Оптимизация конфликтов, `getLessonHistoryForStudent()` |
| `lib/features/schedule/screens/all_rooms_schedule_screen.dart` | +1354 | `_CompactDayGrid`, `_RoomSetupSheet`, `showLessonDetailSheet()` |
| `lib/features/students/screens/student_detail_screen.dart` | +300/-200 | `_LessonHistorySection`, `_LessonHistoryItem` |
| `CLAUDE.md` | +54 | Секция 49 + лог сессии |

### Новые файлы

| Файл | Описание |
|------|----------|
| `supabase/migrations/add_default_room_ids.sql` | Миграция для `default_room_ids` |
| `supabase/migrations/20260111_lesson_history_rls.sql` | RLS политики для `lesson_history` |
| `SESSION_2026_01_11_LESSON_HISTORY.md` | Этот отчёт |

---

## Итог

### Новые возможности
1. **Настройка кабинетов** — выбор кабинетов по умолчанию для расписания
2. **Компактный режим** — новый виджет `_CompactDayGrid`
3. **История занятий** — секция в карточке ученика с пагинацией

### Оптимизации
4. **Проверка конфликтов** — 2 запроса вместо 2*N

### Инфраструктура
5. **RLS для lesson_history** — политики SELECT/INSERT
6. **Profile null-safety** — защита от падений
7. **showLessonDetailSheet()** — публичная функция для переиспользования

### Миграции для применения
```bash
# В Supabase SQL Editor:
-- 1. Кабинеты по умолчанию
\i supabase/migrations/add_default_room_ids.sql

-- 2. RLS для истории занятий
\i supabase/migrations/20260111_lesson_history_rls.sql
```
