# ARCHITECTURE.md — Архитектура приложения Kabinet

## Обзор

Kabinet использует **Feature-first** архитектуру с **Riverpod** для state management и **Repository Pattern** для работы с данными.

## Структура папок

```
lib/
├── main.dart                      # Точка входа
├── app.dart                       # MaterialApp, ProviderScope, тема
│
├── core/                          # Общие утилиты и конфигурация
│   ├── config/
│   │   ├── supabase_config.dart   # Инициализация Supabase
│   │   └── app_config.dart        # Конфигурация приложения
│   ├── router/
│   │   └── app_router.dart        # go_router конфигурация
│   ├── theme/
│   │   ├── app_theme.dart         # ThemeData
│   │   └── app_colors.dart        # Цветовая палитра
│   ├── constants/
│   │   ├── app_strings.dart       # Строковые константы (русский)
│   │   ├── app_sizes.dart         # Размеры, отступы
│   │   └── lesson_durations.dart  # Стандартные длительности занятий
│   ├── utils/
│   │   ├── date_utils.dart        # Работа с датами
│   │   ├── validators.dart        # Валидаторы форм
│   │   └── extensions.dart        # Extension methods
│   ├── exceptions/
│   │   └── app_exceptions.dart    # Кастомные исключения
│   └── widgets/                   # Переиспользуемые виджеты
│       ├── loading_overlay.dart
│       ├── error_view.dart
│       ├── empty_state.dart
│       ├── confirmation_dialog.dart
│       └── custom_app_bar.dart
│
├── features/                      # Функциональные модули
│   ├── auth/                      # Аутентификация
│   ├── institution/               # Заведения + участники (members)
│   ├── rooms/                     # Кабинеты
│   ├── subjects/                  # Предметы/направления
│   ├── schedule/                  # Расписание и занятия
│   ├── students/                  # Ученики и группы
│   ├── payments/                  # Оплаты
│   ├── statistics/                # Статистика
│   └── dashboard/                 # Главный экран
│
└── shared/                        # Общие модели и сервисы
    ├── models/
    │   └── base_model.dart        # Базовый класс с archived_at, created_at
    ├── providers/
    │   └── supabase_provider.dart # Провайдер Supabase клиента
    └── repositories/
        └── base_repository.dart   # Базовый репозиторий
```

## Структура фичи

Каждая фича следует одинаковой структуре:

```
features/
└── {feature_name}/
    ├── models/                    # Модели данных
    │   └── {entity}_model.dart
    ├── repositories/              # Работа с Supabase
    │   └── {entity}_repository.dart
    ├── providers/                 # Riverpod провайдеры
    │   └── {entity}_provider.dart
    ├── screens/                   # Полноэкранные виджеты
    │   └── {screen}_screen.dart
    └── widgets/                   # Компоненты экранов
        └── {widget}.dart
```

## Архитектурные паттерны

### 1. Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Screen    │  │   Screen    │  │   Widget    │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                │                │                 │
│         └────────────────┼────────────────┘                 │
│                          │ ref.watch / ref.read             │
└──────────────────────────┼──────────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                      Provider Layer                          │
│  ┌──────────────────┐  ┌──────────────────┐                 │
│  │  StreamProvider  │  │ StateNotifier    │                 │
│  │  (realtime data) │  │ Provider         │                 │
│  └────────┬─────────┘  └────────┬─────────┘                 │
│           │                     │                            │
│           └──────────┬──────────┘                            │
│                      │ repository methods                    │
└──────────────────────┼───────────────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                    Repository Layer                          │
│  ┌──────────────────────────────────────────┐               │
│  │            EntityRepository              │               │
│  │  - getAll(), getById(), create(),        │               │
│  │  - update(), archive(), delete()         │               │
│  │  - stream() для realtime                 │               │
│  └────────────────────┬─────────────────────┘               │
│                       │ Supabase client                      │
└───────────────────────┼──────────────────────────────────────┘
                        ▼
┌──────────────────────────────────────────────────────────────┐
│                    Supabase (Backend)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  PostgreSQL │  │   Auth      │  │  Realtime   │          │
│  │  + RLS      │  │             │  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└──────────────────────────────────────────────────────────────┘
```

### 2. Riverpod Providers

**StreamProvider** — для realtime данных:
```dart
final lessonsStreamProvider = StreamProvider.family<List<Lesson>, String>((ref, roomId) {
  final repository = ref.watch(lessonRepositoryProvider);
  return repository.streamByRoom(roomId);
});
```

**ВАЖНО: Гибридный Realtime подход**

Всегда комбинируй StreamProvider + ручную инвалидацию для надежности:

```dart
// В контроллере
class EntityController extends StateNotifier<AsyncValue<void>> {
  final EntityRepository _repo;
  final Ref _ref;

  void _invalidateForEntity(String entityId) {
    // ОБЯЗАТЕЛЬНО инвалидируй StreamProvider!
    _ref.invalidate(entityStreamProvider(entityId));
    _ref.invalidate(entityDataProvider(entityId));
  }

  Future<Entity?> update(String id) async {
    final entity = await _repo.update(id);
    _invalidateForEntity(id);  // Гарантирует обновление UI
    return entity;
  }
}
```

Это обеспечивает:
- ✅ Обновление UI всегда (даже если Realtime не настроен)
- ✅ Синхронизацию между пользователями (когда Realtime работает)
- ✅ Pull-to-refresh работает корректно

**FutureProvider** — для одноразовых запросов:
```dart
final studentProvider = FutureProvider.family<Student?, String>((ref, studentId) {
  final repository = ref.watch(studentRepositoryProvider);
  return repository.getById(studentId);
});
```

**StateNotifierProvider** — для состояния с мутациями:
```dart
final lessonFormProvider = StateNotifierProvider<LessonFormNotifier, LessonFormState>((ref) {
  return LessonFormNotifier(ref.watch(lessonRepositoryProvider));
});
```

### 3. Repository Pattern

```dart
abstract class BaseRepository<T> {
  Future<List<T>> getAll({bool includeArchived = false});
  Future<T?> getById(String id);
  Future<T> create(T entity);
  Future<T> update(T entity);
  Future<void> archive(String id);
  Future<void> restore(String id);
  Future<void> delete(String id);
  Stream<List<T>> stream({bool includeArchived = false});
}
```

### 4. Обработка ошибок

```dart
// В репозитории
Future<Either<AppException, Student>> createStudent(Student student) async {
  try {
    final data = await _supabase.from('students').insert(student.toJson()).select().single();
    return Right(Student.fromJson(data));
  } on PostgrestException catch (e) {
    return Left(DatabaseException(e.message));
  } catch (e) {
    return Left(UnknownException(e.toString()));
  }
}

// В провайдере/UI
final result = await repository.createStudent(student);
result.fold(
  (error) => showError(error.userMessage),
  (student) => navigateToStudent(student.id),
);
```

## Правила именования

| Тип | Паттерн | Пример |
|-----|---------|--------|
| Модель | `{Entity}Model` | `StudentModel` |
| Репозиторий | `{Entity}Repository` | `StudentRepository` |
| Provider (stream) | `{entities}StreamProvider` | `studentsStreamProvider` |
| Provider (future) | `{entity}Provider` | `studentProvider` |
| Provider (state) | `{entity}StateProvider` | `lessonFormStateProvider` |
| Screen | `{Name}Screen` | `StudentsListScreen` |
| Widget | `{Name}Widget` или `{Name}Card` | `StudentCard` |

## Зависимости (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  
  # Backend
  supabase_flutter: ^2.3.0
  
  # Navigation
  go_router: ^13.0.0
  
  # Utils
  intl: ^0.18.0              # Форматирование дат
  uuid: ^4.2.0               # Генерация UUID
  equatable: ^2.0.5          # Сравнение объектов
  fpdart: ^1.1.0             # Either для обработки ошибок
  
  # UI
  flutter_svg: ^2.0.9
  cached_network_image: ^3.3.0
  shimmer: ^3.0.0            # Skeleton loading

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
  json_serializable: ^6.7.0
  go_router_builder: ^2.4.0
```

## Навигация (go_router)

Иерархия роутов:

```
/                           → Redirect на /auth или /institutions
├── /auth
│   ├── /login
│   └── /register
│
├── /institutions
│   ├── /create
│   └── /join/:code
│
└── /institution/:institutionId
    ├── /dashboard          → DashboardScreen (главный)
    ├── /rooms
    │   └── /:roomId
    │       └── /schedule   → ScheduleScreen
    ├── /students
    │   ├── /               → StudentsListScreen
    │   └── /:studentId     → StudentDetailScreen
    ├── /groups
    │   ├── /               → GroupsListScreen
    │   └── /:groupId       → GroupDetailScreen
    ├── /payments
    │   ├── /               → PaymentsScreen
    │   └── /add            → AddPaymentScreen
    ├── /statistics         → StatisticsScreen
    └── /settings
        ├── /               → SettingsScreen
        ├── /members        → MembersScreen
        ├── /lesson-types   → LessonTypesScreen
        ├── /payment-plans  → PaymentPlansScreen
        └── /rooms          → RoomsManagementScreen
```

## Контекст заведения

После входа в заведение, его ID сохраняется в провайдере:

```dart
final currentInstitutionProvider = StateProvider<String?>((ref) => null);
```

Все запросы данных автоматически фильтруются по текущему заведению через RLS в Supabase.
