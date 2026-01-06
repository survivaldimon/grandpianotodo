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

## ⛔ СТРОГИЕ ПРАВИЛА (ОБЯЗАТЕЛЬНО!)

### 1. GitHub операции — ТОЛЬКО по запросу
**НИКОГДА** не выполняй операции с GitHub без явного требования пользователя:
- `git push` — только когда пользователь попросит
- `git commit` — только когда пользователь попросит
- Создание PR — только когда пользователь попросит

### 2. НИКОГДА не использовать rebase
**ЗАПРЕЩЕНО** использовать `git rebase`. При конфликтах:
1. Использовать **только `git merge`**
2. При появлении конфликтов — разрешить их вручную
3. После разрешения конфликтов — сделать merge commit
4. Проверить, что все изменения сохранены (не потеряны)

**Причина:** rebase может привести к потере кода при неправильном разрешении конфликтов.

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
- `SESSION_2025_12_27_PERMISSIONS.md` — расширение системы прав:
  - Разделение прав на управление учениками (свои/все)
  - Скрытие кода приглашения (только владельцу)
  - Режим "только просмотр" для карточек учеников
  - Исправление ошибки при отметке занятия
- **`SESSION_2025_12_27_SCHEDULE_FAB.md`** — улучшения расписания:
  - Валидация пароля при регистрации
  - Настройка рабочего времени заведения
  - FAB для быстрого создания занятий
  - Автоматическое расширение сетки для занятий вне рабочего времени
- **`SESSION_2025_12_27_FAMILY_SUBSCRIPTIONS.md`** — семейные абонементы:
  - Общий пул занятий для нескольких учеников
  - Таблица `subscription_members` + VIEW `student_subscription_summary`
  - UI создания семейного абонемента (чекбоксы)
  - Отображение участников в карточках
- **`SESSION_2025_12_28_PAYMENT_FILTERS.md`** — полный отчёт за 28.12.2025:
  - Бронирование кабинетов (Room Bookings) — новая фича
  - Исправление расчёта долга (VIEW student_subscription_summary)
  - Редизайн фильтров оплат: Ученики, Предметы, Преподаватели, Тарифы
  - Восстановление фич расписания после rebase
- **`SESSION_2025_12_28_TAB_ANIMATIONS.md`** — анимация вкладок и исправления:
  - Slide-анимация переключения вкладок в стиле iOS
  - Автопривязка ученика к преподавателю при создании
  - Исправление видимости оплат для участников
- **`SESSION_2026_01_04_PAYMENT_METHODS.md`** — способы оплаты (карта/наличные):
  - Поле `payment_method` в таблице payments
  - Фильтр по способу оплаты
  - Статистика по способам на вкладках "Общие" и "Тарифы"
  - DraggableScrollableSheet для форм
  - FAB прокрутки вниз в форме добавления оплаты
- **`SESSION_2026_01_04_PAYMENTS_FIX.md`** — исправления оплат и realtime:
  - Исправление удвоения занятий при оплате с тарифом
  - Realtime обновление баланса ученика после операций с оплатами
  - Удаление дублирующегося `paymentPlansProvider`
  - Исправление "Итого" для отображения только видимых оплат
- **`SESSION_2026_01_05_CONNECTION_MANAGER.md`** — управление соединением:
  - ConnectionManager — централизованное управление как в топовых приложениях
  - Автоматическое переподключение при восстановлении сети
  - Упрощение репозиториев для быстрой загрузки
  - Исправление кнопки "Сегодня" в расписании
- **`SESSION_2026_01_05_DARK_THEME.md`** — тёмная тема:
  - Полноценная тёмная тема для всего приложения
  - Провайдер темы (SharedPreferences + Riverpod)
  - Выбор темы в настройках (система/тёмная/светлая)
  - Исправление hardcoded цветов во всех экранах
  - Удаление устаревшего экрана расписания кабинета
- **`SESSION_2026_01_05_SHIMMER_PRELOAD.md`** — shimmer-анимация и предзагрузка:
  - Shimmer-скелетон для загрузки расписания (как в Instagram)
  - Предзагрузка соседних дат (±3 дня) для мгновенного переключения
  - Realtime обновления для предзагруженных дат
  - Пустая сетка без фейковых занятий
- **`SESSION_2026_01_05_COLOR_PICKER.md`** — унифицированный выбор цветов:
  - Создан ColorPickerField — единый виджет для выбора цвета
  - Обновлены экраны типов занятий, предметов, тарифов
  - FAB для добавления новых элементов
  - Случайный цвет при создании, редактируемый при изменении
  - Поддержка цвета для тарифов оплаты
- **`SESSION_2026_01_05_NO_CONNECTION_ERROR_FIX.md`** — финальное решение "Нет соединения с сервером":
  - Паттерн valueOrNull для resilient UI
  - Исправлены: Dashboard (неотмеченные занятия), Payments, Students
  - Данные ВСЕГДА видны (даже при потере связи)
  - ConnectionManager переподключается в фоне
  - Как в Instagram/Telegram — соединение НИКОГДА не теряется
- **`SESSION_2026_01_06_GROUP_LESSONS.md`** — групповые занятия (ЧАСТИЧНО, требует доработки):
  - Исправление метки "Ученик" → "Группа" при редактировании
  - Оптимистичные обновления статуса занятия
  - Чекбоксы оплаты для участников группы
  - Кнопка "Оплатить" для групповых занятий
  - Исправление двойного списания при повторном "Проведено"
  - **ВНИМАНИЕ:** Много недочётов и багов, требуется доработка
- **`SESSION_2026_01_06_STUDENT_PICKER.md`** — улучшение выбора ученика:
  - Замена Dropdown на кастомный BottomSheet
  - Кнопка "Показать всех" расширяет список без закрытия
  - Первые 10 учеников видны сразу, остальные по кнопке
- **`SESSION_2026_01_06_TEACHER_ONBOARDING.md`** — онбординг преподавателя:
  - Экран онбординга при присоединении по коду (PageView: цвет + направления)
  - Баннер на Dashboard если онбординг не завершён
  - Редактирование направлений в настройках участника
  - Исправление RLS для обновления цвета
  - Realtime обновления для institution_members

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

### 5b. ConnectionManager — Управление соединением
Централизованный менеджер соединения, работающий как в топовых приложениях (Instagram, Telegram).

**Файл:** `lib/core/services/connection_manager.dart`

```dart
// Состояния соединения
enum AppConnectionState {
  connected,        // Работает
  connecting,       // Подключение
  offline,          // Нет интернета
  serverUnavailable // Сервер недоступен
}

// Инициализация в MainShell
ConnectionManager.instance.initialize();
ConnectionManager.instance.setReconnectCallback(_reconnectAllStreams);

// Callback для переподключения
void _reconnectAllStreams() {
  final institutionId = ref.read(currentInstitutionIdProvider);
  if (institutionId != null) {
    _refreshAllData(institutionId); // Инвалидация всех провайдеров
  }
}
```

**Функции:**
- Мониторинг сети через `connectivity_plus`
- Health check сервера каждые 30 секунд
- Автоматическое переподключение при восстановлении сети
- Callback для инвалидации всех провайдеров

**Зависимости:** `connectivity_plus: ^6.1.0` в pubspec.yaml

### 5c. Resilient UI — паттерн valueOrNull (ВАЖНО!)

**КРИТИЧНОЕ ПРАВИЛО:** НИКОГДА не показывай ErrorView при потере связи с сервером!

**Проблема со стандартным подходом:**
```dart
// ❌ ПЛОХО — при потере связи все данные исчезнут!
paymentsAsync.when(
  loading: () => CircularProgressIndicator(),
  error: (e, _) => ErrorView(...),  // ← Пропадают все данные!
  data: (payments) => ListView(...),
)
```

**Правильный подход — valueOrNull:**
```dart
// ✅ ХОРОШО — данные ВСЕГДА видны
final payments = paymentsAsync.valueOrNull;

// Loading только при ПЕРВОЙ загрузке (когда данных еще нет)
if (payments == null) {
  return CircularProgressIndicator();
}

// ВСЕГДА показываем данные (даже если фоном ошибка)
return ListView(payments);
```

**Как это работает:**
- `valueOrNull` сохраняет последнее успешное значение (кеш Riverpod)
- При потере связи: stream выбрасывает ошибку, НО данные остаются в кеше
- Пользователь **продолжает видеть данные** — не видит ErrorView
- ConnectionManager переподключается в фоне
- При восстановлении связи → данные автоматически обновляются
- Realtime обновления работают корректно

**Преимущества:**
✅ НИКОГДА не показываем "Нет соединения с сервером"
✅ Данные ВСЕГДА видны пользователю
✅ Автоматическое переподключение в фоне
✅ Плавный UX как в Instagram/Telegram
✅ Нет мигания при Realtime обновлениях

**Где применено:**
- `lib/features/dashboard/screens/dashboard_screen.dart` — неотмеченные занятия
- `lib/features/payments/screens/payments_screen.dart` — список оплат
- `lib/features/students/screens/students_list_screen.dart` — список учеников
- `lib/features/schedule/screens/all_rooms_schedule_screen.dart` — расписание (shimmer)

**ВСЕГДА используй этот паттерн** для StreamProvider с данными, которые должны оставаться видимыми при потере связи.

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

**Для групповых занятий:**
- `subscription_id` хранится в таблице `lesson_students` (не в `lessons`)
- Каждый участник группы может иметь свою подписку
- При `complete()` — для каждого присутствующего участника сохраняется его `subscription_id`
- При `uncomplete()` — занятие возвращается на подписку по сохранённому `subscription_id`

**Миграция:**
```sql
ALTER TABLE lesson_students
ADD COLUMN IF NOT EXISTS subscription_id UUID REFERENCES subscriptions(id);
```

**ВАЖНО:** Эта функциональность требует доработки и тестирования (см. SESSION_2026_01_06_GROUP_LESSONS.md)

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

**Структура прав просмотра оплат:**
```dart
viewOwnStudentsPayments: bool  // Просмотр оплат своих учеников (по умолчанию true)
viewAllPayments: bool          // Просмотр всех оплат заведения (по умолчанию false)
```

**Проверка прав на просмотр оплат:**
```dart
final canViewAllPayments = hasFullAccess ||
    (permissions?.viewAllPayments ?? false);
final canViewOwnStudentsPayments = permissions?.viewOwnStudentsPayments ?? true;

// Фильтрация в UI: если !canViewAllPayments — показывать только оплаты своих учеников
```

**Обратная совместимость с RLS:**
В `toJson()` добавляются поля для совместимости с RLS политикой в Supabase:
- `delete_lessons: deleteOwnLessons || deleteAllLessons`
- `manage_students: manageOwnStudents || manageAllStudents`
- `view_payments: viewOwnStudentsPayments || viewAllPayments`

**Базовые права для новых участников (по умолчанию):**
- `createLessons: true`
- `editOwnLessons: true`
- `viewAllSchedule: true`
- `manageOwnStudents: true`
- `manageGroups: true`
- `deleteOwnLessons: true`
- `viewOwnStudentsPayments: true`
- `addPaymentsForOwnStudents: true`
- `createBookings: true` — право на бронирование кабинетов

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

### 20. Валидация пароля при регистрации
При регистрации пароль должен соответствовать требованиям:
- Минимум **8 символов**
- Минимум **1 заглавная буква** (A-Z или А-Я)
- Минимум **1 специальный символ** (!@#$%^&*()_+-=[]{}etc)

**Файлы:**
- `lib/core/utils/validators.dart` — функция `Validators.password()`
- `lib/core/constants/app_strings.dart` — сообщения об ошибках
- `lib/features/auth/screens/register_screen.dart` — подсказка под полем

### 21. Рабочее время заведения
Настройка рабочего времени определяет диапазон часов в сетке расписания.

**Поля в таблице `institutions`:**
```sql
work_start_hour INTEGER DEFAULT 8   -- Начало (0-23)
work_end_hour INTEGER DEFAULT 22    -- Конец (1-24)
```

**Настройка:**
- Находится в Настройки → раздел "Заведение"
- Доступна только владельцу и администраторам
- Значение по умолчанию: 8:00 — 22:00
- Только целые часы (без минут)

**Realtime синхронизация:**
- `currentInstitutionStreamProvider` — StreamProvider для отслеживания изменений
- При изменении рабочего времени все участники видят обновление сразу
- Таблица `institutions` добавлена в Supabase Realtime publication

**Миграция:**
```sql
ALTER TABLE institutions
ADD COLUMN IF NOT EXISTS work_start_hour INTEGER DEFAULT 8,
ADD COLUMN IF NOT EXISTS work_end_hour INTEGER DEFAULT 22;

ALTER PUBLICATION supabase_realtime ADD TABLE institutions;
```

### 22. FAB для быстрого создания занятий
В расписании (дневной и недельный режим) есть FloatingActionButton для быстрого создания занятий.

**Возможности:**
- Выбор кабинета из списка
- Выбор даты (по умолчанию — текущая выбранная)
- Выбор времени начала и окончания
- Выбор ученика (или создание нового)
- Выбор преподавателя (если несколько)
- Выбор предмета и типа занятия

**Доступность:**
- Владелец заведения
- Участники с правом `createLessons`

**Виджет:** `_QuickAddLessonSheet` в `all_rooms_schedule_screen.dart`

### 23. Расширение сетки расписания
Сетка расписания автоматически расширяется для отображения занятий вне рабочего времени.

**Логика:**
- Базовый диапазон — рабочее время заведения (например, 8:00-22:00)
- Если есть занятие в 7:00 — сетка расширится до 7:00
- Если есть занятие до 23:00 — сетка расширится до 23:00

**Особенности:**
- В дневном режиме — расширение работает для конкретного дня
- В недельном режиме — расширение применяется ко всей неделе
- Пустые часы вне рабочего времени НЕ показываются

**Метод:**
```dart
(int, int) _calculateEffectiveHours({
  required List<Lesson> lessons,
  required int workStartHour,
  required int workEndHour,
}) {
  int effectiveStart = workStartHour;
  int effectiveEnd = workEndHour;

  for (final lesson in lessons) {
    if (lesson.startTime.hour < effectiveStart) {
      effectiveStart = lesson.startTime.hour;
    }
    final lessonEndHour = lesson.endTime.minute > 0
        ? lesson.endTime.hour + 1
        : lesson.endTime.hour;
    if (lessonEndHour > effectiveEnd) {
      effectiveEnd = lessonEndHour;
    }
  }
  return (effectiveStart, effectiveEnd);
}
```

### 24. Семейные абонементы (Family Subscriptions)
Несколько учеников (братья/сёстры) могут делить один абонемент.

**Бизнес-логика:**
- **Общий пул занятий:** 10 занятий на семью = 10 посещений любым участником
- При завершении занятия ЛЮБОГО участника — списывается 1 занятие из общего пула
- Приоритет списания: сначала личные подписки, потом семейные

**Структура БД:**
```sql
-- Флаг семейного абонемента
subscriptions.is_family BOOLEAN DEFAULT FALSE

-- Таблица участников
subscription_members (
  subscription_id UUID REFERENCES subscriptions(id),
  student_id UUID REFERENCES students(id),
  UNIQUE(subscription_id, student_id)
)

-- VIEW для расчёта баланса (учитывает семейные)
student_subscription_summary
```

**Создание семейного абонемента:**
```dart
// В форме оплаты — переключатель "Семейный абонемент"
// Список учеников с чекбоксами (минимум 2)
await paymentController.createFamilyPayment(
  institutionId: id,
  studentIds: [student1.id, student2.id, student3.id],
  lessonsCount: 12,
  ...
);
```

**Отображение:**
- В списке учеников — баланс из `student_subscription_summary` VIEW
- В карточке ученика — бейдж "Семейный" + chips с именами участников
- В списке оплат — имена всех участников + иконка семьи

**Ключевые файлы:**
- `lib/shared/models/subscription.dart` — модель + `SubscriptionMember`
- `lib/features/subscriptions/repositories/subscription_repository.dart` — `createFamily`, `deductLesson`
- `lib/features/students/repositories/student_repository.dart` — баланс из VIEW
- `supabase/migrations/add_family_subscriptions.sql` — миграция

### 25. Бронирование кабинетов (Room Bookings)
Кабинеты могут быть забронированы для мероприятий (репетиций, концертов и т.д.).

**Основные принципы:**
- Бронь блокирует создание занятий в выбранных кабинетах на указанное время
- При создании брони можно выбрать **несколько кабинетов сразу**
- Право на создание: `createBookings` (по умолчанию `true` для всех участников)
- Удалить бронь может: владелец, администратор или создатель брони

**Отображение в расписании:**
- Цвет: **оранжевый** (`AppColors.warning`)
- Иконка: `Icons.lock`
- Всегда показывается имя создателя
- Описание опционально

**Структура БД:**
```sql
-- Основная таблица брони
bookings (id, institution_id, created_by, date, start_time, end_time, description)

-- Связь с кабинетами (many-to-many)
booking_rooms (booking_id, room_id)
```

**Проверка конфликтов:**
При создании занятия вызывается `hasTimeConflict()`, который проверяет:
1. Конфликты с другими занятиями
2. Конфликты с бронированиями через `booking_rooms`

**Ключевые файлы:**
- `lib/features/bookings/models/booking.dart` — модель Booking
- `lib/features/bookings/repositories/booking_repository.dart` — CRUD + проверка конфликтов
- `lib/features/bookings/providers/booking_provider.dart` — провайдеры Riverpod
- `lib/features/schedule/screens/all_rooms_schedule_screen.dart` — UI (блоки броней, форма создания)
- `supabase/migrations/add_room_bookings.sql` — SQL миграция

### 26. Фильтры на экране оплат
Экран оплат поддерживает фильтрацию по нескольким критериям.

**Доступные фильтры:**
1. **Ученики** — мультиселект учеников
2. **Предметы** — фильтр по студентам, связанным с предметами
3. **Преподаватели** — фильтр по студентам, привязанным к преподавателям
4. **Тарифы** — фильтр по тарифам оплаты (PaymentPlan)

**UI:**
- Горизонтальные кнопки с возможностью прокрутки
- При нажатии открывается BottomSheet с чекбоксами
- Активный фильтр подсвечивается (синяя рамка)
- Кнопка сброса появляется при наличии активных фильтров

**Логика фильтрации по предметам/преподавателям:**
```dart
// Провайдеры связей (локальные в payments_screen.dart)
_studentSubjectBindingsProvider  // Map: subjectId → Set<studentId>
_studentTeacherBindingsProvider  // Map: userId → Set<studentId>

// При выборе предмета/преподавателя — показываются оплаты
// только тех учеников, которые связаны с выбранными сущностями
```

**Ключевой файл:**
- `lib/features/payments/screens/payments_screen.dart` — экран с фильтрами

### 27. Анимация переключения вкладок
При переключении вкладок нижней навигации используется slide-анимация в стиле iOS.

**Логика:**
- Переход на вкладку с **бо́льшим индексом** (влево→вправо): страница въезжает **справа**
- Переход на вкладку с **меньшим индексом** (вправо→влево): страница въезжает **слева**

**Индексы вкладок:**
| Индекс | Вкладка |
|--------|---------|
| 0 | Главная (Dashboard) |
| 1 | Расписание (Schedule) |
| 2 | Ученики (Students) |
| 3 | Оплаты (Payments) |
| 4 | Настройки (Settings) |

**Важные особенности:**
- Используется `didChangeDependencies` для отслеживания смены GoRouterState
- `addPostFrameCallback` гарантирует запуск анимации после завершения фрейма
- `_lastLocation` предотвращает повторные анимации при rebuild
- `SlideTransition` оборачивает `widget.child` в body Scaffold

**Файл:** `lib/features/dashboard/screens/main_shell.dart`

### 28. Автопривязка ученика к преподавателю
При создании ученика он автоматически привязывается к текущему пользователю (преподавателю).

**Проблема:** Участник создавал ученика, но не видел его в "своих учениках" и не мог добавить оплату.

**Решение:** В `StudentController.create()` добавлена автоматическая привязка созданного ученика к текущему пользователю через `studentBindingsController.addTeacher()`.

**Файл:** `lib/features/students/providers/student_provider.dart`

### 29. Способы оплаты (Payment Methods)
Оплаты разделяются на два способа: **Карта** и **Наличные**.

**Поле в таблице `payments`:**
```sql
payment_method TEXT NOT NULL DEFAULT 'cash'
CHECK (payment_method IN ('cash', 'card'))
```

**Модель Payment:**
```dart
final String paymentMethod; // 'cash' или 'card'

bool get isCash => paymentMethod == 'cash';
bool get isCard => paymentMethod == 'card';
String get paymentMethodLabel => isCard ? 'Карта' : 'Наличные';
```

**UI порядок:** Карта первая, Наличные вторая (default: 'card')

**Форма добавления оплаты:**
```dart
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'card', label: Text('Карта')),
    ButtonSegment(value: 'cash', label: Text('Наличные')),
  ],
  selected: {_paymentMethod},
  onSelectionChanged: (selected) => setState(() => _paymentMethod = selected.first),
)
```

**Фильтр на экране оплат:**
- Кнопка "Способ" в горизонтальном списке фильтров
- BottomSheet с чекбоксами: Все, Карта, Наличные
- Мультиселект (можно выбрать оба)

**Статистика:**
- Вкладка "Общие": общая сумма картой/наличными, количество, проценты
- Вкладка "Тарифы": разбивка по способам для каждого тарифа

**Ключевые файлы:**
- `lib/shared/models/payment.dart` — модель
- `lib/features/payments/repositories/payment_repository.dart` — репозиторий
- `lib/features/payments/screens/payments_screen.dart` — форма и фильтр
- `lib/features/statistics/repositories/statistics_repository.dart` — статистика
- `supabase/migrations/add_payment_method.sql` — миграция

### 30. DraggableScrollableSheet для форм
Большие формы (добавление оплаты) используют `DraggableScrollableSheet` для свайпа закрытия.

**Преимущества:**
- Свайп по любой области закрывает sheet
- Синхронизация скролла контента с размером sheet
- Drag handle отдельно от скроллируемого контента

**Паттерн:**
```dart
return DraggableScrollableSheet(
  initialChildSize: 0.9,
  minChildSize: 0.5,
  maxChildSize: 0.95,
  expand: false,
  builder: (context, scrollController) => Container(
    child: Column(
      children: [
        // Drag handle (вне скролла)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(child: /* handle widget */),
        ),
        // Скроллируемый контент
        Expanded(
          child: ListView(
            controller: scrollController, // Важно!
            children: [/* форма */],
          ),
        ),
      ],
    ),
  ),
);
```

### 31. FAB прокрутки вниз в формах
Для длинных форм добавляется FAB со стрелкой вниз для быстрой прокрутки к кнопке отправки.

**Логика:**
- FAB появляется когда есть куда скроллить
- FAB скрывается когда пользователь почти внизу (< 50px)
- При нажатии — плавная анимация к низу

**Реализация:**
```dart
// State
bool _showScrollDownFab = true;
ScrollController? _currentScrollController;

void _handleScrollNotification(ScrollNotification notification, ScrollController controller) {
  _currentScrollController = controller;
  if (notification is ScrollUpdateNotification) {
    final maxScroll = notification.metrics.maxScrollExtent;
    final currentScroll = notification.metrics.pixels;
    final shouldShow = maxScroll > 50 && currentScroll < maxScroll - 50;
    if (shouldShow != _showScrollDownFab) {
      setState(() => _showScrollDownFab = shouldShow);
    }
  }
}

void _scrollToBottom() {
  _currentScrollController?.animateTo(
    _currentScrollController!.position.maxScrollExtent,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
}

// В Stack
if (_showScrollDownFab)
  Positioned(
    right: 16,
    bottom: 16,
    child: FloatingActionButton.small(
      onPressed: _scrollToBottom,
      child: const Icon(Icons.keyboard_arrow_down),
    ),
  ),
```

### 32. Адаптивность форм для маленьких экранов
Для предотвращения overflow на маленьких экранах:

**Принципы:**
- Убирать `prefixIcon` из полей ввода
- Использовать `isDense: true` для компактности
- Использовать `isExpanded: true` для Dropdown
- Убирать иконки из SegmentedButton
- Уменьшать отступы между элементами

**Пример компактного поля:**
```dart
TextFormField(
  decoration: InputDecoration(
    labelText: 'Занятий',
    isDense: true, // Компактнее
    // Без prefixIcon
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
)
```

### 33. Тарифы — только шаблон для автозаполнения
Тариф (PaymentPlan) используется **только как шаблон** для автозаполнения поля "Занятия" при создании оплаты.

**Логика оплаты:**
1. При выборе тарифа — поле "Занятия" заполняется из `plan.lessonsCount`
2. Создаётся только платёж (Payment)
3. Триггер `handle_payment_insert` в БД добавляет занятия в `prepaid_lessons_count`
4. **Подписка НЕ создаётся** для обычных оплат

**Исключение — семейные абонементы:**
- Для семейных оплат создаётся подписка с общим пулом занятий
- Используется метод `createFamilyPayment()` с параметром `validityDays`

**Единый источник провайдера тарифов:**
```dart
// ПРАВИЛЬНО — использовать только этот провайдер:
import 'package:kabinet/features/payment_plans/providers/payment_plan_provider.dart';
final plansAsync = ref.watch(paymentPlansProvider(institutionId));

// НЕПРАВИЛЬНО — НЕ создавать дубликаты в других файлах!
```

**Ключевые файлы:**
- `lib/features/payment_plans/providers/payment_plan_provider.dart` — единственный источник `paymentPlansProvider`
- `lib/features/payments/providers/payment_provider.dart` — `PaymentController.create()` без создания подписки

### 34. Realtime обновление баланса ученика
После любых операций с оплатами баланс ученика (предоплаченные занятия) обновляется в реальном времени.

**Инвалидируемые провайдеры в `PaymentController`:**
```dart
_ref.invalidate(studentPaymentsProvider(studentId));  // История оплат
_ref.invalidate(studentProvider(studentId));          // Данные ученика (баланс)
_ref.invalidate(paymentsStreamProvider(institutionId)); // Realtime stream
```

**Методы, инвалидирующие `studentProvider`:**
- `create()` — создание оплаты
- `createCorrection()` — создание корректировки
- `updatePayment()` — редактирование оплаты
- `deletePayment()` — удаление оплаты
- `deleteByLessonId()` — удаление оплаты по ID занятия
- `createFamilyPayment()` — создание семейного абонемента (для всех участников)

### 35. Расчёт "Итого" на экране оплат
"Итого" рассчитывается из **видимых** оплат с учётом прав пользователя.

**Логика:**
```dart
// Фильтрация по правам доступа
List<Payment> accessFiltered = allPayments;
if (!canViewAllPayments) {
  accessFiltered = allPayments.where((p) {
    if (myStudentIds.contains(p.studentId)) return true;
    if (p.subscription?.members != null) {
      return p.subscription!.members!.any(
        (m) => myStudentIds.contains(m.studentId),
      );
    }
    return false;
  }).toList();
}

// Сумма только видимых оплат
visibleTotal = accessFiltered.fold<double>(0.0, (sum, p) => sum + p.amount);
```

**Отображение:**
- Владелец/админ: `"Итого:"` — сумма всех оплат за период
- Участник: `"Итого (ваши ученики):"` — сумма только оплат своих учеников

**Файл:** `lib/features/payments/screens/payments_screen.dart`

### 36. Кнопка "Сегодня" в расписании
Кнопка "Сегодня" в AppBar расписания **всегда** прокручивает селектор дат к сегодняшней дате.

**Проблема (исправлено):**
Кнопка работала только если была выбрана другая дата. Если дата уже "сегодня" — прокрутка не происходила.

**Решение:**
Добавлен параметр `scrollToTodayKey` в `_WeekDaySelector`:

```dart
class _WeekDaySelector extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final int scrollToTodayKey; // Ключ для принудительной прокрутки

  // ...
}

// В didUpdateWidget проверяем изменение ключа:
final keyChanged = oldWidget.scrollToTodayKey != widget.scrollToTodayKey;
if (keyChanged || dateChangedToToday) {
  // Прокрутка к сегодня
}
```

**Использование:**
```dart
_WeekDaySelector(
  selectedDate: _selectedDate,
  scrollToTodayKey: _scrollResetKey, // Увеличивается в _goToToday()
  onDateSelected: (date) => setState(() => _selectedDate = date),
)
```

**Файл:** `lib/features/schedule/screens/all_rooms_schedule_screen.dart`

### 37. Тёмная тема (Dark Theme)
Приложение поддерживает тёмную тему с тремя режимами: система, тёмная, светлая.

**Архитектура:**
```
lib/core/theme/
├── app_colors.dart      # Палитра цветов (light + dark)
├── app_theme.dart       # ThemeData (lightTheme + darkTheme)
└── theme_provider.dart  # Riverpod провайдер + SharedPreferences
```

**Выбор темы:**
- Настройки → "Тема оформления"
- По умолчанию: "Как в системе"
- Сохраняется в SharedPreferences

**ВАЖНО: Theme-aware цвета**
При создании UI **НИКОГДА** не используй hardcoded цвета:

```dart
// ❌ НЕПРАВИЛЬНО
fillColor: Colors.grey[50],
color: AppColors.textSecondary,
const BoxDecoration(color: AppColors.surface),

// ✅ ПРАВИЛЬНО
fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
color: Theme.of(context).colorScheme.onSurfaceVariant,
BoxDecoration(color: Theme.of(context).colorScheme.surface),
```

**Справочник ColorScheme:**
| Назначение | Свойство |
|------------|----------|
| Основной фон | `colorScheme.surface` |
| Фон полей ввода | `colorScheme.surfaceContainerLow` |
| Отключённый фон | `colorScheme.surfaceContainerHighest` |
| Основной текст | `colorScheme.onSurface` |
| Вторичный текст | `colorScheme.onSurfaceVariant` |
| Границы | `dividerColor` или `colorScheme.outlineVariant` |
| Hint текст | `colorScheme.outline` |

**Ключевые файлы:**
- `lib/core/theme/theme_provider.dart` — провайдер темы
- `lib/features/institution/screens/settings_screen.dart` — UI выбора темы

### 38. Экран списка кабинетов
Настройки → Кабинеты — управление кабинетами заведения.

**Поведение:**
- Клик на карточку кабинета → открывается форма редактирования
- Меню (⋮) → "Редактировать" или "Удалить"
- Режим сортировки: стрелки вверх/вниз для изменения порядка

**Файл:** `lib/features/rooms/screens/rooms_screen.dart`

**Примечание:** Экран расписания отдельного кабинета (`schedule_screen.dart`) был удалён как избыточный — основное расписание показывает все кабинеты.

### 39. Унифицированный выбор цветов (ColorPickerField)
Для всех сущностей с цветами (типы занятий, предметы, тарифы, участники) используется единый компонент выбора цвета.

**Паттерн работы с цветами:**
- **При создании** — цвет назначается **автоматически случайно** из палитры
- **При редактировании** — цвет можно изменить через ColorPickerField

**Виджет:** `lib/core/widgets/color_picker_field.dart`

**Палитра из 12 предустановленных цветов:**
```dart
const List<String> kPresetColors = [
  '#4CAF50', '#2196F3', '#FF9800', '#9C27B0', '#F44336', '#00BCD4',
  '#795548', '#607D8B', '#E91E63', '#009688', '#3F51B5', '#FFEB3B',
];
```

**Функции:**
```dart
String getRandomPresetColor()           // Случайный цвет из палитры
Color hexToColor(String hex)            // Hex → Color
String colorToHex(Color color)          // Color → Hex
Future<String?> showColorPickerDialog() // Диалог выбора (preset + палитра)
```

**Использование при создании:**
```dart
// В форме создания НЕ показывать выбор цвета
final newEntity = await controller.create(
  name: _nameController.text.trim(),
  color: getRandomPresetColor(), // Автоматический случайный цвет
);
```

**Использование при редактировании:**
```dart
// В форме редактирования показать ColorPickerField
ColorPickerField(
  label: 'Цвет',
  initialColor: entity.color,
  onColorChanged: (color) => setState(() => _selectedColor = color),
)
```

**UI ColorPickerField:**
- Ряд из 12 кружков с предустановленными цветами
- Кнопка "Палитра" для выбора любого цвета через `flutter_colorpicker`
- Текущий выбранный цвет подсвечен рамкой

**Экраны с поддержкой:**
- `lib/features/lesson_types/screens/lesson_types_screen.dart`
- `lib/features/subjects/screens/subjects_screen.dart`
- `lib/features/payment_plans/screens/payment_plans_screen.dart`
- `lib/features/institution/screens/members_screen.dart`

**База данных:**
- Цвет хранится как `TEXT` (hex формат, например: `4CAF50` или `#4CAF50`)
- Поле `color` в таблицах: `subjects`, `lesson_types`, `payment_plans`
- Миграция: `supabase/migrations/add_payment_plan_color.sql`

**ВАЖНО:** Quick add диалоги в расписании (добавление ученика/предмета/типа занятия) **НЕ** показывают выбор цвета — используется только `getRandomPresetColor()`.

### 40. Shimmer-анимация загрузки и предзагрузка дат
Расписание использует shimmer-скелетон для индикации загрузки и предзагружает соседние даты.

**Shimmer-анимация:**
```dart
// Показывается вместо CircularProgressIndicator
if (rooms == null || (lessonsAsync.isLoading && lessons == null)) {
  return ScheduleSkeletonLoader(
    roomCount: rooms?.length.clamp(1, 5) ?? 3,
    startHour: workStartHour,
    endHour: workEndHour,
  );
}
```

**Компоненты shimmer:**
- `ShimmerLoading` — базовый виджет с мерцающим градиентом
- `ShimmerBlock` — блок-заполнитель
- `ScheduleSkeletonLoader` — скелетон дневного режима (пустая сетка)
- `WeekScheduleSkeletonLoader` — скелетон недельного режима (пустая сетка)

**Предзагрузка соседних дат (±3 дня):**
```dart
void _preloadAdjacentDates() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    for (int i = -3; i <= 3; i++) {
      if (i == 0) continue; // Текущая дата через watch

      final adjacentDate = _selectedDate.add(Duration(days: i));
      final params = InstitutionDateParams(widget.institutionId, adjacentDate);

      // Фоновая загрузка без rebuild
      ref.read(lessonsByInstitutionStreamProvider(params).future).catchError((_) => <Lesson>[]);
      ref.read(bookingsByInstitutionDateProvider(params).future).catchError((_) => <Booking>[]);
    }
  });
}
```

**Когда вызывается:**
- При первом входе на экран (`initState`)
- При нажатии "Сегодня"
- При выборе даты через селектор или календарь

**Преимущества:**
- Мгновенное переключение между датами (данные в кеше)
- Realtime обновления для предзагруженных дат (StreamProvider подписан)
- Не блокирует UI (addPostFrameCallback + ref.read)
- Оптимальный диапазон ±3 дня (баланс скорость/трафик)

**Файлы:**
- `lib/core/widgets/shimmer_loading.dart` — shimmer-компоненты
- `lib/features/schedule/screens/all_rooms_schedule_screen.dart` — интеграция

### 41. Выбор ученика в форме занятия (StudentPickerSheet)
Кастомный BottomSheet для выбора ученика с возможностью показать всех без закрытия.

**Проблема:** Стандартный Dropdown закрывался при нажатии "Показать всех", требуя повторного открытия.

**Решение:** Виджет `_StudentPickerSheet` с локальным состоянием.

**Логика отображения:**
- Показывает первых 10 учеников (свои первыми, потом остальные)
- Если учеников > 10 — кнопка "Показать всех (N)" внизу списка
- При нажатии — список расширяется **без закрытия** sheet
- После раскрытия — кнопка "Скрыть"
- При выборе ученика — sheet закрывается

**Использование:**
```dart
InkWell(
  onTap: () => _showStudentPickerSheet(
    context: context,
    myStudents: myStudents,
    otherStudents: otherStudents,
    allStudents: allStudents,
    currentStudent: currentStudent,
  ),
  child: InputDecorator(
    decoration: InputDecoration(
      labelText: 'Ученик *',
      suffixIcon: Icon(Icons.arrow_drop_down),
    ),
    child: Text(currentStudent?.name ?? 'Выберите ученика'),
  ),
)
```

**Константа порога:**
```dart
static const int _initialVisibleCount = 10;
```

**Визуальное оформление:**
- Свои ученики: обычный цвет (`onSurface`)
- Остальные: приглушённый (`onSurfaceVariant`)
- Выбранный: жирный текст + галочка + primaryContainer фон аватара

**Файл:** `lib/features/schedule/screens/all_rooms_schedule_screen.dart`

### 42. Онбординг преподавателя
При присоединении к заведению по коду приглашения преподавателю показывается онбординг.

**Два шага онбординга:**
1. **Выбор цвета** — для отображения занятий в расписании
2. **Выбор направлений** — чекбоксы с предметами заведения (множественный выбор)

**Особенности:**
- Каждый шаг можно пропустить кнопкой "Пропустить"
- Сохраняются только изменения (не дублируются существующие данные)
- Владельцу онбординг не показывается

**Баннер на Dashboard:**
Если преподаватель не заполнил цвет или направления — показывается баннер:
```dart
// Проверка необходимости онбординга
final needsOnboardingProvider = Provider.family<bool, String>((ref, institutionId) {
  final membership = ref.watch(myMembershipProvider(institutionId)).valueOrNull;
  if (membership == null) return false;  // Не мелькать пока грузится

  // Владельцу онбординг не нужен
  final isOwner = institution.ownerId == currentUserId;
  if (isOwner) return false;

  final hasColor = membership.color != null && membership.color!.isNotEmpty;
  final hasSubjects = (teacherSubjects.valueOrNull?.length ?? 0) > 0;

  return !hasColor || !hasSubjects;
});
```

**Редактирование направлений в настройках:**
Участники → меню (⋮) → "Направления" — позволяет изменить привязанные предметы.

**Хранение цвета:**
- В базе хранится **без `#`** (например `3F51B5`)
- При сохранении очищается: `color?.replaceAll('#', '').toUpperCase()`

**Файлы:**
- `lib/features/institution/screens/teacher_onboarding_screen.dart` — экран онбординга
- `lib/features/institution/screens/members_screen.dart` — диалог направлений
- `lib/features/institution/providers/member_provider.dart` — `needsOnboardingProvider`
- `lib/features/dashboard/screens/dashboard_screen.dart` — баннер онбординга

**RLS политика (выполнить в Supabase):**
```sql
-- Разрешить участникам обновлять свой цвет
CREATE POLICY "Members can update own color"
ON institution_members
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Realtime для обновлений цвета/направлений
ALTER PUBLICATION supabase_realtime ADD TABLE institution_members;
```

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

### Git — ТОЛЬКО с разрешения пользователя!
**ЗАПРЕЩЕНО** выполнять любые git-команды без явного разрешения:
- `git push` — **ЗАПРЕЩЕНО**
- `git pull` — **ЗАПРЕЩЕНО**
- `git commit` — **ЗАПРЕЩЕНО**
- `git merge` — **ЗАПРЕЩЕНО**
- `git stash` — **ЗАПРЕЩЕНО**

**Разрешено без спроса** (только чтение):
- `git status`
- `git log`
- `git diff`
- `git branch`

Перед любой операцией, изменяющей репозиторий, **ОБЯЗАТЕЛЬНО спроси разрешения** у пользователя!

### Git — НИКОГДА не использовать rebase!
- `git rebase` — **ПОЛНОСТЬЮ ЗАПРЕЩЁН**
- Всегда использовать **merge** для объединения веток
- При конфликтах: разрешить конфликты вручную → `git add` → `git merge --continue`
- `rebase` переписывает историю и может привести к потере коммитов напарника

## Контакты

При возникновении вопросов по бизнес-логике — спрашивай у пользователя.
