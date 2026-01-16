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

**Последние сессии:**
- `SESSION_2026_01_16_CACHE_PERFORMANCE.md` — cache-first, compute(), sync emit в watch-методах
- `SESSION_2026_01_15_LESSON_SCHEDULES.md` — виртуальные занятия, отмена и списание
- `SESSION_2026_01_13_BALANCE_TRANSFER.md` — система остатка занятий, улучшения UI

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
UI (Screen/Widget) → Provider → Repository → Cache (Hive) → Supabase
                                    ↑              ↓
                                    └── Realtime обновляет кэш
```
Провайдеры НЕ обращаются к Supabase напрямую.
Репозитории используют **cache-first** паттерн (см. секцию "Кэширование и Performance").

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

## Кэширование и Performance

### Персистентный кэш (Hive)

Приложение использует **cache-first** паттерн для мгновенного отображения данных.

**Файлы:**
- `lib/core/cache/cache_service.dart` — инициализация, TTL, JSON storage
- `lib/core/cache/cache_keys.dart` — типобезопасные ключи

**TTL-политика:**
| Данные | TTL | Ключ |
|--------|-----|------|
| Справочники (rooms, subjects, lesson_types) | 60 мин | `CacheKeys.rooms(institutionId)` |
| Ученики | 30 мин | `CacheKeys.students(institutionId)` |
| Занятия | 15 мин | `CacheKeys.lessons(institutionId, date)` |

**Паттерн cache-first + stale-while-revalidate:**
```dart
Future<List<Entity>> getByInstitution(String id, {bool skipCache = false}) async {
  final cacheKey = CacheKeys.entities(id);

  // 1. Мгновенно из кэша
  if (!skipCache) {
    final cached = CacheService.get<List<dynamic>>(cacheKey);
    if (cached != null) {
      _refreshInBackground(id, cacheKey); // Обновление в фоне
      return _parseFromCache(cached);
    }
  }

  // 2. Из сети если кэш пуст
  final data = await _fetchFromNetwork(id);
  await CacheService.put(cacheKey, data.map(_toCache).toList(), ttlMinutes: 60);
  return data;
}
```

**ОБЯЗАТЕЛЬНО** для новых репозиториев с методами загрузки списков:
1. Добавить ключ в `CacheKeys`
2. Реализовать cache-first паттерн
3. Добавить метод `invalidateCache()`

---

### Isolates (compute())

Парсинг больших списков выполняется в изоляте чтобы не блокировать UI.

**Пороговые значения:**
| Сущность | Порог |
|----------|-------|
| Students | >50 |
| Lessons | >30 |
| Payments | >50 |

**Правила:**
```dart
// 1. Top-level функция (НЕ метод класса!)
const int _entityComputeThreshold = 50;

List<Entity> _parseEntitiesIsolate(List<Map<String, dynamic>> jsonList) {
  return jsonList.map((item) => Entity.fromJson(item)).toList();
}

// 2. Проверка порога в методе загрузки
if (dataList.length >= _entityComputeThreshold) {
  debugPrint('[Repository] Using compute() for ${dataList.length} items');
  return compute(
    _parseEntitiesIsolate,
    dataList.map((e) => Map<String, dynamic>.from(e)).toList(),
  );
}
return dataList.map((item) => Entity.fromJson(item)).toList();
```

**ОБЯЗАТЕЛЬНО** для новых методов загрузки списков:
1. Определить порог (обычно 30-50)
2. Добавить top-level функцию парсинга
3. Проверять длину списка перед парсингом

---

### StreamProvider и watch-методы (КРИТИЧНО!)

При возврате из background **все StreamProvider'ы пересоздаются**. Если watch-метод не эмитит данные синхронно — UI покажет shimmer вместо данных.

**⚠️ ОБЯЗАТЕЛЬНЫЙ паттерн для watch-методов:**
```dart
Stream<List<Entity>> watchByInstitution(String institutionId) {
  final controller = StreamController<List<Entity>>.broadcast();
  final cacheKey = CacheKeys.entities(institutionId);

  Future<void> loadAndEmit() async {
    final data = await getByInstitution(institutionId);
    if (!controller.isClosed) controller.add(data);
  }

  // 1. СИНХРОННО эмитим из кэша — UI получает данные МГНОВЕННО
  final cached = CacheService.get<List<dynamic>>(cacheKey);
  if (cached != null) {
    try {
      final entities = _parseFromCache(cached);
      controller.add(entities);  // ← СИНХРОННЫЙ эмит!
      loadAndEmit();  // Обновляем в фоне
    } catch (e) {
      loadAndEmit();  // При ошибке парсинга — из сети
    }
  } else {
    loadAndEmit();  // Нет кэша — из сети
  }

  // 2. Подписка на Realtime
  final subscription = _client.from('table').stream(primaryKey: ['id']).listen(
    (_) => loadAndEmit(),
  );

  controller.onCancel = () => subscription.cancel();
  return controller.stream;
}
```

**Почему это важно:**
- При возврате из background Supabase Realtime переподключается
- StreamProvider'ы пересоздаются и получают новые stream'ы
- Без синхронного эмита UI видит `AsyncValue.loading()` → shimmer
- С синхронным эмитом UI сразу получает данные из кэша

**Файлы с реализацией:**
- `lib/features/schedule/repositories/lesson_repository.dart` → `watchByInstitution()`
- `lib/features/payments/repositories/payment_repository.dart` → `watchByInstitution()`

---

### App Lifecycle (Background/Foreground)

**Файлы:**
- `lib/core/services/app_lifecycle_service.dart` — обработка lifecycle событий
- `lib/core/services/connection_manager.dart` — управление соединением

**Что происходит при возврате из background:**
1. `AppLifecycleService._handleResume()` вызывается
2. `ConnectionManager.reconnectRealtime()` переподключает Realtime
3. Supabase Realtime триггерит события → StreamProvider'ы обновляются
4. Watch-методы эмитят кэшированные данные **синхронно** → UI мгновенный

**Паттерн resilient refresh (в MainShell):**
```dart
void _refreshAllData(String institutionId) {
  // Только критичные провайдеры — НЕ все 26!
  ref.invalidate(currentInstitutionStreamProvider(institutionId));
  ref.invalidate(myMembershipProvider(institutionId));
  // Остальные обновятся через Realtime автоматически
}
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
- `subscription_id` — привязка к подписке (для возврата)
- `transfer_payment_id` — привязка к balance transfer (для возврата)
- `is_deducted` — флаг списания (для отменённых занятий)

Файлы:
- `lib/features/schedule/repositories/lesson_repository.dart`
- `lib/features/schedule/providers/lesson_provider.dart`

### Оплаты (Payments)
- `payment_method`: `'card'` | `'cash'`
- `lessons_count` — количество занятий
- `has_subscription` — флаг: оплата создаёт подписку

**Механизм учёта занятий:**
- Если `has_subscription = false` → триггер `handle_payment_insert` добавляет занятия в `prepaid_lessons_count`
- Если `has_subscription = true` → триггер пропускает (занятия через `subscription.lessons_remaining`)

**Унифицированный экран добавления оплаты:**
```dart
import 'package:kabinet/features/payments/screens/payments_screen.dart' show showAddPaymentSheet;

showAddPaymentSheet(
  context: context,
  ref: ref,
  institutionId: institutionId,
  canAddForAllStudents: true,       // Выбор любого ученика
  preselectedStudentId: studentId,  // Предвыбор ученика (опционально)
  onSuccess: () { ... },
);
```
**ВСЕГДА** использовать `showAddPaymentSheet()` — **НЕ** создавать локальные формы оплаты в других экранах!

**Поведение при выборе тарифа:**
- Сумма, занятия и срок действия **блокируются** (read-only)
- При сохранении автоматически создаётся подписка (subscription)
- Иконка замка показывает заблокированные поля

Файлы:
- `lib/shared/models/payment.dart`
- `lib/features/payments/repositories/payment_repository.dart`
- `lib/features/payments/screens/payments_screen.dart` — `showAddPaymentSheet()`, `_AddPaymentSheet`, `_EditPaymentSheet`

### Balance Transfer (Остаток занятий)
Система переноса остатка занятий из другой школы или начисления администратором.

**Приоритет списания:**
```
1. Balance Transfer (остаток) — ПЕРВЫЙ
2. Subscription (абонемент)
3. Prepaid/Debt (долг)
```

**Поля в payments:**
- `is_balance_transfer` — флаг записи переноса
- `transfer_lessons_remaining` — остаток занятий (уменьшается при списании)

**Поля в lessons:**
- `transfer_payment_id` — ID записи переноса (для возврата)
- `is_deducted` — списано ли занятие (для отменённых)

**RPC функции:**
```sql
deduct_balance_transfer(p_student_id UUID) RETURNS UUID  -- Списание (FIFO)
return_balance_transfer_lesson(p_payment_id UUID)        -- Возврат
```

**Методы PaymentRepository:**
```dart
Future<String?> deductBalanceTransfer(String studentId);
Future<void> returnBalanceTransferLesson(String paymentId);
Future<void> createBalanceTransfer({studentId, lessonsCount, comment});
```

Миграция: `supabase/migrations/20260113_add_balance_transfer.sql`

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

### Виртуальные занятия (Lesson Schedules)
Система бесконечно повторяющихся занятий. Одна запись в БД = занятия на все подходящие даты.

**Концепция:**
- `lesson_schedules` — постоянное расписание (день недели, время, кабинет, ученик)
- При отображении генерируются "виртуальные" занятия через `toVirtualLesson(date)`
- Реальная запись в `lessons` создаётся только при проведении/отмене

**Ключевые поля lesson_schedules:**
- `day_of_week` — день недели (1=Пн, 7=Вс по ISO 8601)
- `valid_from` / `valid_until` — период действия
- `is_paused` / `pause_until` — приостановка
- `replacement_room_id` / `replacement_until` — временная замена кабинета

**RPC функция:**
```sql
create_lesson_from_schedule(p_schedule_id UUID, p_date DATE, p_status TEXT)
RETURNS UUID  -- ID созданного занятия
```

**Фильтрация виртуальных занятий:**
Виртуальное занятие скрывается если есть реальное занятие с тем же `schedule_id` на эту дату:
```dart
// Проверяем и обычные, и отменённые занятия
final hasRealLesson = lessonsList.any((l) => l.scheduleId == schedule.id);
final hasCancelled = cancelledScheduleIds.contains(schedule.id);
return !hasRealLesson && !hasCancelled;
```

**Провайдер отменённых schedule_id:**
```dart
final cancelledScheduleIdsProvider = FutureProvider.family<Set<String>, InstitutionDateParams>(...);
```

Файлы:
- `lib/features/lesson_schedules/models/lesson_schedule.dart`
- `lib/features/lesson_schedules/repositories/lesson_schedule_repository.dart`
- `lib/features/lesson_schedules/providers/lesson_schedule_provider.dart`

Миграции:
- `supabase/migrations/20260115_add_lesson_schedules.sql`
- `supabase/migrations/20260115_fix_lesson_from_schedule_status.sql`

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
