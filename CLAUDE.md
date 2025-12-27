# CLAUDE.md — Главный файл инструкций для Claude Code

## О проекте

**Kabinet** — мобильное приложение для управления расписанием кабинетов в частных учебных заведениях (музыкальные школы, языковые курсы, танцевальные студии и т.д.).

## Технологический стек

| Компонент | Технология |
|-----------|------------|
| Framework | Flutter (Dart) |
| State Management | Riverpod |
| Backend | Supabase (PostgreSQL + Auth + Realtime) |
| Навигация | go_router |
| Аутентификация | Supabase Auth (Email, Google, Apple) |
| Локализация | Только русский язык |

## Структура документации

Перед началом работы над любой фичей, **обязательно прочитай**:

1. **[ARCHITECTURE.md](./ARCHITECTURE.md)** — архитектура приложения, паттерны, структура папок
2. **[DATABASE.md](./DATABASE.md)** — схема БД Supabase, RLS policies, связи таблиц
3. **[FEATURES.md](./FEATURES.md)** — описание фич с acceptance criteria
4. **[UI_STRUCTURE.md](./UI_STRUCTURE.md)** — экраны, навигация, компоненты
5. **[MODELS.md](./MODELS.md)** — Dart модели данных

### Логи сессий
Файлы `SESSION_*.md` содержат историю изменений по сессиям:
- `SESSION_2025_12_20_IOS_DEPLOYMENT.md` — деплой iOS на TestFlight
- `SESSION_2025_12_21_FEATURES.md` — улучшения функциональности
- `SESSION_2025_12_23_IMPROVEMENTS.md` — исправления багов, интеграция абонементов, средняя стоимость занятий
- **`SESSION_2025_12_25_FULL_REPORT.md`** — полный отчет о работе 25.12.2025 (29 коммитов):
  - Производительность UI и скролл (билды 10-13)
  - Realtime синхронизация расписания, подписок, прав
  - Паттерн "Гибридный Realtime"
  - Система прав доступа
- `SESSION_2025_12_25_SUBSCRIPTIONS_REALTIME.md` — детальный отчет об исправлении Realtime подписок
- `SESSION_2025_12_25_PERMISSIONS.md` — система прав участников, разделение прав на удаление занятий
- `SESSION_2025_12_26_UI_IMPROVEMENTS.md` — UI улучшения, экран профиля, исправление архивации учеников
- **`SESSION_2025_12_27_PERMISSIONS.md`** — расширение системы прав:
  - Разделение прав на управление учениками (свои/все)
  - Скрытие кода приглашения (только владельцу)
  - Режим "только просмотр" для карточек учеников
  - Исправление ошибки при отметке занятия

## Валюта

Приложение использует **казахстанский тенге (₸)** в качестве валюты. Валюта фиксирована и не настраивается.

## Ключевые принципы разработки

### 1. Feature-first структура
Каждая фича изолирована в своей папке внутри `lib/features/`. Не создавай зависимости между фичами напрямую — используй `core/` и `shared/`.

### 2. Riverpod паттерны
- Используй `StreamProvider` для realtime данных из Supabase
- Используй `FutureProvider` для одноразовых запросов
- Используй `StateNotifierProvider` для локального состояния с мутациями
- Все провайдеры должны быть в файле `providers/` соответствующей фичи

### 3. Repository Pattern
```
UI (Screen/Widget) → Provider → Repository → Supabase
```
Провайдеры не должны напрямую обращаться к Supabase. Создавай репозитории в `lib/features/{feature}/repositories/`.

### 4. Обработка ошибок
- Все репозитории возвращают `Either<Failure, T>` или используют try-catch с кастомными exceptions
- UI показывает user-friendly сообщения на русском языке
- Логируй ошибки для отладки

### 5. Realtime
- Подписки на Supabase Realtime создаются через `StreamProvider`
- При уходе с экрана подписки автоматически отменяются (Riverpod это делает)
- Используй `.family` модификатор для параметризованных провайдеров

### 5a. Гибридный Realtime Pattern (ВАЖНО!)
**Всегда комбинируй Realtime Stream + Manual Invalidation для надежности:**

```dart
// В контроллере ВСЕГДА инвалидируй StreamProvider после операций
void _invalidateForEntity(String entityId) {
  _ref.invalidate(entityStreamProvider(entityId));  // ← ОБЯЗАТЕЛЬНО!
  _ref.invalidate(entityFutureProvider(entityId));
  _ref.invalidate(relatedDataProvider(entityId));
}

Future<Entity?> updateEntity(String id) async {
  final entity = await _repo.update(id);
  _invalidateForEntity(id);  // ← Принудительное обновление
  return entity;
}
```

**Зачем нужна ручная инвалидация:**
- ✅ UI обновляется **всегда** — даже если Realtime не настроен
- ✅ Работает **между пользователями** — когда Realtime активен
- ✅ Гарантия обновления — после операций через контроллер
- ✅ Работает при pull-to-refresh

**Настройка Realtime в Supabase:**
```sql
-- Добавляй таблицы в публикацию сразу при создании
ALTER PUBLICATION supabase_realtime ADD TABLE table_name;
```

**Проверка:** Все таблицы должны быть в DATABASE.md → секция Realtime

### 6. Архивация vs Удаление
- "Удаление" сущностей = установка `archived_at` timestamp
- Полное удаление доступно только для архивированных записей
- Все запросы по умолчанию фильтруют `WHERE archived_at IS NULL`
- **Исключение: занятия (lessons)** — могут быть удалены полностью (сначала удаляется `lesson_history`, затем сам `lesson`)

### 7. История изменений
- Только для занятий (lessons)
- При любом изменении создаётся запись в `lesson_history`
- Храним: кто изменил, когда, что было до, что стало после

### 8. Диалоги с локальным состоянием
Для модальных окон (BottomSheet), где нужно обновлять UI без закрытия:
- Используй `ConsumerStatefulWidget` вместо `ConsumerWidget`
- Храни состояние в локальных переменных (`_currentStatus`, `_isPaid`)
- Обновляй UI через `setState()`, сохраняй данные асинхронно
- Вызывай `onUpdated()` callback при закрытии диалога

### 9. Редактирование повторяющихся занятий
При редактировании занятия с `repeat_group_id`:
- Проверяй, изменилось ли время (`timeChanged`)
- Показывай диалог с опциями: "Только это" / "Это и последующие"
- Используй `updateFollowingLessons` для массового обновления
- Подсчитывай количество будущих занятий через `getFollowingCount`

### 10. Параллельные операции
Для ускорения сохранения нескольких независимых операций:
```dart
await Future.wait([
  operation1(),
  operation2(),
  operation3(),
]);
```

### 11. Синхронизация ScrollController
При необходимости синхронного скролла нескольких списков:
- Создавай отдельные `ScrollController` для каждого списка
- Используй флаг `_isSyncing` для предотвращения рекурсии
- Синхронизируй через `jumpTo()` в слушателе главного контроллера

### 12. Привязка занятий к подпискам (subscription_id)
Занятия привязываются к подпискам для точного расчёта стоимости:
- При завершении занятия (`complete`) — списывается занятие с активной подписки, `subscription_id` сохраняется в занятии
- При отмене завершения (`uncomplete`) — занятие возвращается на подписку, `subscription_id` очищается
- При создании новой подписки — автоматически привязываются "долговые" занятия (без subscription_id)
- Это позволяет точно рассчитать стоимость каждого занятия

### 13. Расчёт средней стоимости занятия
Средняя стоимость рассчитывается двумя способами:

**Точный расчёт** (без символа ≈):
```
занятие.subscription_id → подписка.payment_id → оплата.amount / оплата.lessons_count
```

**Приблизительный расчёт** (с символом ≈):
```
сумма_всех_оплат / количество_завершённых_занятий
```

Приблизительный расчёт используется когда:
- Миграция `subscription_id` не выполнена
- У занятий нет привязки к подпискам

### 14. Права участников (Permissions)
Права хранятся в JSON поле `permissions` таблицы `institution_members`.

**Структура прав удаления занятий:**
```dart
deleteOwnLessons: bool  // Удаление только своих занятий
deleteAllLessons: bool  // Удаление занятий любого преподавателя
```

**Структура прав управления учениками:**
```dart
manageOwnStudents: bool  // Управление своими учениками (привязанными)
manageAllStudents: bool  // Управление всеми учениками заведения
```

**Проверка прав на удаление занятий:**
```dart
final canDelete = isOwner ||
                  (permissions?.deleteAllLessons ?? false) ||
                  (isOwnLesson && (permissions?.deleteOwnLessons ?? false));
```

**Проверка прав на редактирование ученика:**
```dart
final isMyStudent = isMyStudentProvider(IsMyStudentParams(studentId, institutionId));
final canEditStudent = isOwner ||
                       (permissions?.manageAllStudents ?? false) ||
                       (isMyStudent && (permissions?.manageOwnStudents ?? false));
```

**Realtime обновление прав:**
- `myMembershipProvider` — StreamProvider для отслеживания изменений прав
- `myPermissionsProvider` — извлекает права из membership
- При открытии деталей занятия вызывается `ref.invalidate(myMembershipProvider)` для гарантированного обновления

**Обратная совместимость с RLS:**
В `toJson()` добавляются поля для совместимости с RLS политикой в Supabase:
- `delete_lessons: deleteOwnLessons || deleteAllLessons`
- `manage_students: manageOwnStudents || manageAllStudents`

**Базовые права для новых участников (по умолчанию):**
- `createLessons: true`
- `editOwnLessons: true`
- `viewAllSchedule: true`
- `manageOwnStudents: true`
- `manageGroups: true`
- `deleteOwnLessons: true`
- `viewPayments: true`
- `addPaymentsForOwnStudents: true`

**Роль администратора (isAdmin):**
- Администратор имеет все права владельца, **кроме удаления заведения**
- Поле `is_admin` хранится в таблице `institution_members`
- Только владелец может назначать/снимать роль администратора
- Проверка прав: `isOwner || isAdmin` (используется `hasFullAccess`)

**Провайдер:**
```dart
final isAdminProvider = Provider.family<bool, String>((ref, institutionId) {
  final membershipAsync = ref.watch(myMembershipProvider(institutionId));
  return membershipAsync.valueOrNull?.isAdmin ?? false;
});
```

**Использование:**
```dart
final isAdmin = ref.watch(isAdminProvider(institutionId));
final hasFullAccess = isOwner || isAdmin;
```

### 15. Получение текущего пользователя
Для надёжного получения ID текущего пользователя в UI используй прямой доступ:
```dart
final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
```
Это надёжнее, чем `currentUserIdProvider`, который зависит от стрима.

### 16. Экран профиля пользователя
Профиль пользователя доступен из Настроек → Профиль.

**Структура:**
```
lib/features/profile/
├── providers/
│   └── profile_provider.dart
└── screens/
    └── profile_screen.dart
```

**Таблица:** `profiles` (не `user_profiles`!)

**Возможности:**
- Просмотр и редактирование имени (full_name)
- Просмотр email (только чтение)
- Дата регистрации

### 17. Код приглашения (invite_code)
Код приглашения позволяет новым участникам присоединиться к заведению.

**Безопасность:**
- Код виден **только владельцу** заведения
- На экране списка заведений код **не отображается**
- Код доступен только в настройках заведения (для владельца)

**Функции:**
- Копирование кода в буфер обмена
- Генерация нового кода (сбрасывает старый)

### 18. Режим "только просмотр" для учеников
Участники без прав на редактирование ученика видят карточку в режиме только просмотр.

**Скрываются элементы:**
- Кнопка редактирования (карандаш)
- Кнопка добавления оплаты
- Кнопки управления абонементами (заморозить/разморозить/продлить)
- Кнопки добавления/удаления преподавателей
- Кнопки добавления/удаления предметов

**Логика определения прав:**
```dart
final canEditStudent = isOwner ||
    (permissions?.manageAllStudents ?? false) ||
    (isMyStudent && (permissions?.manageOwnStudents ?? false));
```

### 19. Архивация учеников
При архивации/разархивации учеников:
- Активный ученик → меню "Архивировать" (оранжевый)
- Архивированный → меню "Разархивировать" (зелёный)
- Архивированный ученик показывает баннер с датой архивации
- `watchByInstitution` загружает ВСЕХ учеников (includeArchived: true)
- Фильтрация происходит в провайдере `filteredStudentsProvider`

## CI/CD

Проект использует **Codemagic** для сборки iOS и Android.

| Платформа | Распространение | Статус |
|-----------|-----------------|--------|
| iOS | TestFlight | Настроено |
| Android | APK/AAB | Настроено |

### Конфигурация
- `ci/codemagic/codemagic.yaml` — конфигурация CI/CD
- `ci/codemagic/README.md` — инструкция по настройке

### Решённые проблемы iOS

**path_provider_foundation crash (РЕШЕНО)**
- Ошибка: `EXC_BAD_ACCESS` в `swift_getObjectType` при запуске на iOS 18.x
- Причина: Debug mode + старые версии Flutter/Xcode
- **Решение:**
  1. Flutter 3.38.1 (полная поддержка iOS 18)
  2. Xcode 16.2 (не beta!)
  3. **Release mode** (критично — Debug крашится!)
  4. Убрать `dependency_overrides` — использовать актуальные версии

### Важно для iOS сборок

- **ВСЕГДА собирать в Release mode** — Debug билды могут крашиться
- Использовать **Default Workflow** в Codemagic (не YAML) для бесплатного аккаунта
- Интеграция App Store Connect настраивается в User Settings (не Team)

### Настройки iOS
- Минимальная версия: **iOS 15.0**
- Bundle ID: `com.kabinet.kabinet`
- Подпись: через Codemagic + App Store Connect API

## Команды

```bash
# Запуск приложения
flutter run

# Генерация кода (после изменения моделей/роутов)
flutter pub run build_runner build --delete-conflicting-outputs

# Тесты
flutter test

# Анализ кода
flutter analyze

# Очистка проекта
flutter clean && flutter pub get
```

## Порядок работы над задачей

1. Прочитай соответствующие разделы документации
2. Определи, какие файлы нужно создать/изменить
3. Начни с модели данных (если новая сущность)
4. Создай/обнови репозиторий
5. Создай/обнови провайдер
6. Создай/обнови UI
7. Протестируй на реальных данных

## Важные ограничения

- **НЕ** используй `setState` — только Riverpod
- **НЕ** обращайся к Supabase напрямую из виджетов
- **НЕ** хардкодь строки — используй константы в `lib/core/constants/`
- **НЕ** создавай виджеты больше 200 строк — декомпозируй
- **НЕ** игнорируй RLS — все данные фильтруются на уровне БД

## Контакты

При возникновении вопросов по бизнес-логике — спрашивай у пользователя.
