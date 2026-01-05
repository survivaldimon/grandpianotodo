# SESSION 2026-01-05: Connection Manager & Schedule Improvements

## Обзор сессии
Реализация централизованного управления соединением как в топовых приложениях (Instagram, Telegram, WhatsApp) + исправление кнопки "Сегодня" в расписании.

---

## 1. ConnectionManager — Централизованное управление соединением

### Проблема
Приложение теряло связь с сервером при переходе в фон или при нестабильном интернете. Ошибка "Нет соединения с сервером" появлялась повторно.

### Решение
Создан `ConnectionManager` — централизованный менеджер соединения, работающий как в топовых приложениях.

### Файл: `lib/core/services/connection_manager.dart`

```dart
enum AppConnectionState {
  connected,        // Соединение работает
  connecting,       // Идёт подключение
  offline,          // Нет интернета
  serverUnavailable // Есть интернет, но сервер недоступен
}

class ConnectionManager {
  // Мониторинг сети через connectivity_plus
  // Проверка сервера каждые 30 секунд
  // Callback для переподключения всех streams

  Future<void> initialize() async { ... }
  void setReconnectCallback(void Function() callback) { ... }
  Future<void> forceReconnect() async { ... }
}
```

### Функции:
- **Мониторинг состояния сети** — WiFi/Mobile/Offline через `connectivity_plus`
- **Автоматическое переподключение** — при восстановлении сети
- **Проверка доступности сервера** — health check каждые 30 секунд
- **Callback для обновления данных** — инвалидация всех провайдеров

### Интеграция в MainShell

```dart
void _setupLifecycleService() {
  // ... existing lifecycle code
  ConnectionManager.instance.initialize();
  ConnectionManager.instance.setReconnectCallback(_reconnectAllStreams);
}

void _reconnectAllStreams() {
  final institutionId = ref.read(currentInstitutionIdProvider);
  if (institutionId != null) {
    _refreshAllData(institutionId);
  }
}
```

### Провайдеры для UI (опционально)

```dart
final connectionStateProvider = StreamProvider<AppConnectionState>((ref) {
  return ConnectionManager.instance.stateStream;
});

final isConnectedProvider = Provider<bool>((ref) {
  final asyncState = ref.watch(connectionStateProvider);
  return asyncState.valueOrNull == AppConnectionState.connected;
});
```

---

## 2. Упрощение репозиториев для быстрой загрузки

### Проблема
После добавления `RealtimeStreamHelper` wrapper'а в репозитории, вкладка "Оплаты" стала грузиться медленно.

### Решение
Откат к простым `async*` stream-методам. ConnectionManager обрабатывает переподключение на уровне приложения.

### Изменённые репозитории:

#### PaymentRepository
```dart
Stream<List<Payment>> watchByInstitution(String institutionId) async* {
  await for (final _ in _client.from('payments').stream(primaryKey: ['id'])) {
    final payments = await getByInstitution(institutionId);
    yield payments;
  }
}
```

#### LessonRepository
```dart
Stream<List<Lesson>> watchByRoom(String roomId, DateTime date) async* {
  await for (final _ in _client.from('lessons').stream(primaryKey: ['id'])) {
    final lessons = await getByRoomAndDate(roomId, date);
    yield lessons;
  }
}
```

#### InstitutionRepository
```dart
Stream<Institution> watchById(String id) async* {
  await for (final _ in _client
      .from('institutions')
      .stream(primaryKey: ['id'])
      .eq('id', id)) {
    yield await getById(id);
  }
}
```

#### BookingRepository
```dart
Stream<List<Booking>> watchByInstitutionAndDate(
  String institutionId,
  DateTime date,
) async* {
  await for (final _ in _client
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('institution_id', institutionId)) {
    final bookings = await getByInstitutionAndDate(institutionId, date);
    yield bookings;
  }
}
```

---

## 3. Исправление кнопки "Сегодня" в расписании

### Проблема
Кнопка "Сегодня" прокручивала селектор дат только если была выбрана другая дата. Если дата уже "сегодня", кнопка не реагировала.

### Причина
В `_WeekDaySelector.didUpdateWidget` была проверка:
```dart
if (!AppDateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
```

Если дата не менялась — прокрутка не происходила.

### Решение
Добавлен параметр `scrollToTodayKey` для принудительной прокрутки.

### Файл: `lib/features/schedule/screens/all_rooms_schedule_screen.dart`

```dart
class _WeekDaySelector extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final int scrollToTodayKey; // Новый параметр

  const _WeekDaySelector({
    required this.selectedDate,
    required this.onDateSelected,
    this.scrollToTodayKey = 0,
  });
}

// В State:
@override
void didUpdateWidget(_WeekDaySelector oldWidget) {
  super.didUpdateWidget(oldWidget);

  // Прокручиваем при изменении ключа ИЛИ при изменении даты на сегодня
  final keyChanged = oldWidget.scrollToTodayKey != widget.scrollToTodayKey;
  final dateChangedToToday = !AppDateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate) &&
      AppDateUtils.isToday(widget.selectedDate);

  if (keyChanged || dateChangedToToday) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _calculateOffset(widget.selectedDate),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
```

### Использование:
```dart
_WeekDaySelector(
  selectedDate: _selectedDate,
  scrollToTodayKey: _scrollResetKey, // Увеличивается в _goToToday()
  onDateSelected: (date) {
    setState(() => _selectedDate = date);
  },
),
```

---

## 4. Обсуждение: Кеширование данных

### Вопрос
Нужно ли реализовать кеш для работы офлайн?

### Ответ
Для данного приложения кеш **не рекомендуется**:
- Расписание и оплаты — данные, которые должны быть актуальными
- Realtime синхронизация важнее кеша
- Устаревшее расписание хуже, чем ожидание загрузки
- Приложение используется онлайн — без интернета оно бесполезно

### Рекомендация
Быстрая загрузка + ConnectionManager + skeleton/shimmer при загрузке.

---

## Изменённые файлы

| Файл | Изменение |
|------|-----------|
| `lib/core/services/connection_manager.dart` | Создан — централизованное управление соединением |
| `lib/core/utils/realtime_stream_helper.dart` | Создан (не используется) — helper для resilient streams |
| `lib/features/dashboard/screens/main_shell.dart` | Интеграция ConnectionManager |
| `lib/features/payments/repositories/payment_repository.dart` | Упрощён stream-метод |
| `lib/features/schedule/repositories/lesson_repository.dart` | Упрощены stream-методы |
| `lib/features/institution/repositories/institution_repository.dart` | Упрощены stream-методы |
| `lib/features/bookings/repositories/booking_repository.dart` | Упрощён stream-метод |
| `lib/features/schedule/screens/all_rooms_schedule_screen.dart` | Исправлена кнопка "Сегодня" |
| `pubspec.yaml` | Добавлен `connectivity_plus: ^6.1.0` |

---

## Архитектура управления соединением

```
┌─────────────────────────────────────────────────────────────┐
│                    ConnectionManager                         │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ connectivity│  │ Health Check │  │ Reconnect Callback│  │
│  │   _plus     │  │  (30 sec)    │  │                   │  │
│  └──────┬──────┘  └──────┬───────┘  └─────────┬─────────┘  │
│         │                │                     │            │
│         └────────────────┴─────────────────────┘            │
│                          │                                  │
│                   AppConnectionState                        │
│         (connected/connecting/offline/serverUnavailable)    │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                       MainShell                              │
│                                                              │
│  _reconnectAllStreams() → ref.invalidate(allProviders)      │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     Repositories                             │
│                                                              │
│  Простые async* streams без wrapper'ов                      │
│  Быстрая загрузка, минимальный overhead                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Результат

1. **Быстрая загрузка** — без дополнительных задержек от wrapper'ов
2. **Автоматическое восстановление** — ConnectionManager переподключает всё при восстановлении сети
3. **Кнопка "Сегодня" работает всегда** — даже если дата не менялась
4. **Простой и поддерживаемый код** — легко понять и модифицировать
