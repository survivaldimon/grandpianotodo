# CLAUDE.md — Инструкции для Claude Code

## О проекте

**Kabinet** — мобильное приложение для управления расписанием кабинетов в частных учебных заведениях (музыкальные школы, языковые курсы, танцевальные студии).

## Технологический стек

| Компонент | Технология |
|-----------|------------|
| Framework | Flutter (Dart) |
| State Management | Riverpod |
| Backend | Supabase (PostgreSQL + Auth + Realtime) |
| Навигация | go_router |
| Локализация | Только русский язык |
| Валюта | Казахстанский тенге (₸) |

---

## ⛔ СТРОГИЕ ПРАВИЛА

### Git — ТОЛЬКО с разрешения пользователя
**ЗАПРЕЩЕНО** без явного запроса: `git push`, `git commit`, `git pull`, `git merge`, `git stash`

**Разрешено** (только чтение): `git status`, `git log`, `git diff`, `git branch`

### НИКОГДА не использовать rebase
- Только `git merge` для объединения веток
- При конфликтах: разрешить вручную → `git add` → `git merge --continue`

---

## Документация

| Файл | Содержание |
|------|------------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Архитектура, паттерны, структура папок |
| [DATABASE.md](./DATABASE.md) | Схема БД, RLS policies, связи таблиц |
| [FEATURES.md](./FEATURES.md) | Описание фич с acceptance criteria |
| [UI_STRUCTURE.md](./UI_STRUCTURE.md) | Экраны, навигация, компоненты |
| [MODELS.md](./MODELS.md) | Dart модели данных |
| SESSION_*.md | История сессий разработки |

---

## Архитектура

### Feature-first структура
```
lib/features/{feature}/
├── models/
├── repositories/
├── providers/
└── screens/
```
Фичи изолированы. Общий код в `core/` и `shared/`.

### Repository Pattern
```
UI (Screen/Widget) → Provider → Repository → Supabase
```
Провайдеры НЕ обращаются к Supabase напрямую.

### Riverpod паттерны
- `StreamProvider` — realtime данные
- `FutureProvider` — одноразовые запросы
- `StateNotifierProvider` — локальное состояние с мутациями
- `.family` — параметризованные провайдеры

### Архивация vs Удаление
- "Удаление" = установка `archived_at` timestamp
- Запросы фильтруют `WHERE archived_at IS NULL`
- **Исключение:** занятия (`lessons`) удаляются полностью

---

## Realtime и соединение

### Гибридный Realtime Pattern
**Всегда** комбинируй Stream + Manual Invalidation:
```dart
// После операции ВСЕГДА инвалидируй провайдеры
_ref.invalidate(entityStreamProvider(id));
```
См. контроллеры в `lib/features/*/providers/`

### ConnectionManager
Централизованное управление соединением.
- Файл: `lib/core/services/connection_manager.dart`
- Автопереподключение при восстановлении сети
- Health check каждые 30 секунд

### valueOrNull — Resilient UI
**НИКОГДА** не показывай ErrorView при потере связи:
```dart
// ✅ ПРАВИЛЬНО
final data = asyncValue.valueOrNull;
if (data == null) return CircularProgressIndicator();
return ListView(data);

// ❌ НЕПРАВИЛЬНО — данные исчезнут при ошибке
asyncValue.when(error: (e, _) => ErrorView(...))
```

---

## Система прав

### Структура permissions
Хранится в JSON поле `institution_members.permissions`:

| Право | Описание |
|-------|----------|
| `createLessons` | Создание занятий |
| `editOwnLessons` | Редактирование своих занятий |
| `deleteOwnLessons` | Удаление своих занятий |
| `deleteAllLessons` | Удаление любых занятий |
| `manageOwnStudents` | Управление своими учениками |
| `manageAllStudents` | Управление всеми учениками |
| `viewOwnStudentsPayments` | Просмотр оплат своих учеников |
| `viewAllPayments` | Просмотр всех оплат |
| `createBookings` | Бронирование кабинетов |

### Проверка прав
```dart
final hasFullAccess = isOwner || isAdmin;
final canDelete = hasFullAccess ||
    (permissions?.deleteAllLessons ?? false) ||
    (isOwnLesson && (permissions?.deleteOwnLessons ?? false));
```

### Модель и провайдеры
- `lib/shared/models/member_permissions.dart`
- `lib/features/institution/providers/member_provider.dart`

---

## UI паттерны

### Тёмная тема
**НИКОГДА** не используй hardcoded цвета:
```dart
// ✅ Theme.of(context).colorScheme.surface
// ❌ AppColors.surface или Colors.grey[50]
```
Провайдер: `lib/core/theme/theme_provider.dart`

### DraggableScrollableSheet
Используй для больших форм. Паттерн двухэтапного закрытия:
- См. `_QuickAddLessonSheet` в `all_rooms_schedule_screen.dart`

### Диалоги с локальным состоянием
- `ConsumerStatefulWidget` + `setState()` для UI
- `onUpdated()` callback при закрытии

---

## Бизнес-сущности

### Занятия (Lessons)
| Статус | Описание |
|--------|----------|
| `scheduled` | Запланировано |
| `completed` | Проведено |
| `cancelled` | Отменено |

- `repeat_group_id` — связь повторяющихся занятий
- `lesson_history` — история изменений
- `lesson_students` — участники групповых занятий

Файлы:
- `lib/features/schedule/repositories/lesson_repository.dart`
- `lib/features/schedule/providers/lesson_provider.dart`

### Оплаты (Payments)
- `payment_method`: `'card'` | `'cash'`
- `lessons_count` — количество занятий
- Триггер `handle_payment_insert` добавляет занятия в `prepaid_lessons_count`

Файлы:
- `lib/shared/models/payment.dart`
- `lib/features/payments/repositories/payment_repository.dart`

### Подписки (Subscriptions)
- `is_family` — семейный абонемент (общий пул занятий)
- `subscription_members` — участники семейного абонемента
- VIEW `student_subscription_summary` — расчёт баланса

Файлы:
- `lib/shared/models/subscription.dart`
- `lib/features/subscriptions/repositories/subscription_repository.dart`

### Бронирования (Bookings)
Объединённая система точечных и повторяющихся бронирований:

| recurrence_type | Описание |
|-----------------|----------|
| `once` | Разовое бронирование |
| `weekly` | Еженедельное (постоянное расписание) |

- `student_id` + `teacher_id` — для постоянного расписания ученика
- Занятия НЕ создаются автоматически — только вручную из слота

Файлы:
- `lib/features/bookings/models/booking.dart`
- `lib/features/bookings/repositories/booking_repository.dart`

---

## Расписание

### Рабочее время
- Поля `work_start_hour`, `work_end_hour` в таблице `institutions`
- Сетка автоматически расширяется для занятий вне рабочего времени

### Отображение
- Shimmer-скелетон при загрузке (`lib/core/widgets/shimmer_loading.dart`)
- Предзагрузка ±3 дня для мгновенного переключения
- Слоты скрываются при наличии занятия

### Главный экран
`lib/features/schedule/screens/all_rooms_schedule_screen.dart`

---

## CI/CD

| Платформа | Распространение | CI |
|-----------|-----------------|-----|
| iOS | TestFlight | Codemagic |
| Android | APK/AAB | Codemagic |

### iOS сборки
- **ВСЕГДА Release mode** — Debug крашится на iOS 18.x
- Минимальная версия: iOS 15.0
- Bundle ID: `com.kabinet.kabinet`

Конфигурация: `ci/codemagic/codemagic.yaml`

---

## Команды

```bash
flutter run                    # Запуск
flutter pub run build_runner build --delete-conflicting-outputs  # Генерация кода
flutter test                   # Тесты
flutter analyze                # Анализ
flutter clean && flutter pub get  # Очистка
```

---

## Ограничения

- **НЕ** используй `setState` в обычных виджетах — только Riverpod
- **НЕ** обращайся к Supabase из виджетов напрямую
- **НЕ** хардкодь строки — используй `lib/core/constants/`
- **НЕ** создавай виджеты > 200 строк — декомпозируй
- **НЕ** игнорируй RLS — данные фильтруются на уровне БД

---

## Порядок работы

1. Прочитай документацию (ARCHITECTURE, DATABASE, FEATURES)
2. Определи файлы для изменения
3. Модель → Репозиторий → Провайдер → UI
4. Протестируй на реальных данных
