# SESSION 2025-12-28: Анимация вкладок и исправления

## Обзор сессии
Дата: 28 декабря 2025

### Выполненные задачи:
1. Исправление видимости оплат для участников
2. Автопривязка ученика к преподавателю при создании
3. Slide-анимация переключения вкладок в стиле iOS

---

## 1. Исправление видимости оплат для участников

### Проблема
Когда участник добавлял оплату для своего ученика, он не видел её в списке оплат. Оплату видел только владелец.

### Причины
1. **Проблема загрузки:** `myStudentIdsAsync.valueOrNull ?? {}` возвращал пустой set во время загрузки, что приводило к фильтрации всех оплат
2. **Отсутствие привязки:** При создании ученика он не привязывался автоматически к преподавателю в таблице `student_teachers`

### Решение

#### Часть 1: Исправление состояния загрузки в `payments_screen.dart`
```dart
// Если нужна фильтрация по своим ученикам, ждём загрузки myStudentIds
if (!canViewAllPayments && myStudentIdsAsync.isLoading) {
  return const LoadingIndicator();
}
```

#### Часть 2: Автопривязка ученика к преподавателю в `student_provider.dart`
```dart
Future<Student?> create({...}) async {
  final student = await _repo.create(...);

  // Автоматически привязываем созданного ученика к текущему пользователю
  final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
  if (currentUserId != null) {
    final bindingsController = _ref.read(studentBindingsControllerProvider.notifier);
    await bindingsController.addTeacher(
      studentId: student.id,
      userId: currentUserId,
      institutionId: institutionId,
    );
    _ref.invalidate(myStudentIdsProvider(institutionId));
  }

  return student;
}
```

### Изменённые файлы
- `lib/features/payments/screens/payments_screen.dart`
- `lib/features/students/providers/student_provider.dart`

---

## 2. Slide-анимация переключения вкладок

### Требование
Реализовать анимацию переключения вкладок в стиле iOS:
- При переходе вправо (на вкладку с бо́льшим индексом) — страница въезжает справа
- При переходе влево (на вкладку с меньшим индексом) — страница въезжает слева

### Попытки реализации

#### Попытка 1: CustomTransitionPage в go_router
Использовали `pageBuilder` с `CustomTransitionPage` для каждого маршрута внутри ShellRoute.

**Проблема:** Анимация работала для большинства вкладок, но не работала для вкладки "Расписание".

#### Попытка 2: AnimatedSwitcher в MainShell
Пытались использовать `AnimatedSwitcher` с `SlideTransition` для анимации child виджета.

**Проблема:** GlobalKey конфликты — go_router виджеты содержат GlobalKey и не могут дублироваться в дереве виджетов.

#### Попытка 3: AnimationController в MainShell (финальное решение)
Реализовали анимацию напрямую в MainShell с использованием:
- `SingleTickerProviderStateMixin` для AnimationController
- `didChangeDependencies` для отслеживания смены маршрута
- `addPostFrameCallback` для запуска анимации после завершения фрейма

### Финальная реализация

```dart
class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Animation<Offset> _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
  int _lastKnownIndex = -1;
  String? _lastLocation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkRouteChange();
  }

  void _checkRouteChange() {
    final location = GoRouterState.of(context).matchedLocation;

    // Если маршрут не изменился - ничего не делаем
    if (location == _lastLocation) return;
    _lastLocation = location;

    // Определяем индекс вкладки
    int newIndex = 0;
    if (location.contains('/schedule')) {
      newIndex = 1;
    } else if (location.contains('/students')) {
      newIndex = 2;
    } else if (location.contains('/payments')) {
      newIndex = 3;
    } else if (location.contains('/settings') || location.contains('/statistics')) {
      newIndex = 4;
    }

    // Запускаем анимацию после завершения текущего фрейма
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animateToTab(newIndex);
      }
    });
  }

  void _animateToTab(int newIndex) {
    if (_lastKnownIndex == -1) {
      _lastKnownIndex = newIndex;
      return;
    }

    if (newIndex == _lastKnownIndex) return;

    final previousIndex = _lastKnownIndex;
    _lastKnownIndex = newIndex;

    final goingToHigherIndex = newIndex > previousIndex;

    setState(() {
      _slideAnimation = Tween<Offset>(
        begin: Offset(goingToHigherIndex ? 1.0 : -1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
    });

    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    // ...
    return Scaffold(
      body: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
      bottomNavigationBar: NavigationBar(...),
    );
  }
}
```

### Ключевые особенности решения

| Особенность | Описание |
|-------------|----------|
| `didChangeDependencies` | Вызывается при изменении GoRouterState (inherited widget) |
| `_lastLocation` | Предотвращает повторные анимации при rebuild виджета |
| `addPostFrameCallback` | Гарантирует запуск анимации после завершения текущего фрейма |
| `setState` | Обновляет SlideTransition с новой анимацией |
| `Curves.easeOutCubic` | Плавная кривая анимации |

### Индексы вкладок

| Индекс | Вкладка |
|--------|---------|
| 0 | Главная (Dashboard) |
| 1 | Расписание (Schedule) |
| 2 | Ученики (Students) |
| 3 | Оплаты (Payments) |
| 4 | Настройки (Settings) |

### Изменённые файлы
- `lib/features/dashboard/screens/main_shell.dart`
- `lib/core/router/app_router.dart` (откат к простому builder)

---

## Технические заметки

### Почему CustomTransitionPage не работал для Schedule
ShellRoute в go_router оптимизирует переключение между дочерними маршрутами. Для некоторых экранов (особенно Schedule с его сложным состоянием и StreamProviders) page transition мог не срабатывать из-за особенностей rebuild цикла.

### Почему AnimatedSwitcher вызывал GlobalKey конфликты
При использовании AnimatedSwitcher для анимации перехода, оба виджета (старый и новый) существуют одновременно в дереве. Go_router виджеты содержат GlobalKey, которые должны быть уникальны, поэтому дублирование вызывало ошибку.

### Решение через didChangeDependencies
`didChangeDependencies` вызывается когда InheritedWidget (в данном случае GoRouterState) изменяется. Это надёжный способ отследить смену маршрута без race conditions, которые возникали при использовании callback в build методе.

---

## Итоги сессии

### Добавлено
- Slide-анимация переключения вкладок в MainShell
- Автопривязка ученика к текущему преподавателю при создании

### Исправлено
- Видимость оплат для участников (ожидание загрузки myStudentIds)
- Правильное направление анимации вкладок для всех переходов

### Обновлённая документация
- `CLAUDE.md` — добавлены секции 25 (анимация вкладок) и 26 (автопривязка ученика)
- Создан `SESSION_2025_12_28_TAB_ANIMATIONS.md`
