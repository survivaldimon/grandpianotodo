import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/services/app_lifecycle_service.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/bookings/providers/booking_provider.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/features/payments/providers/payment_provider.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';

/// Провайдер ID текущего заведения
final currentInstitutionIdProvider = StateProvider<String?>((ref) => null);

/// Главная оболочка приложения с нижней навигацией
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  Timer? _checkTimer;
  String? _lastInstitutionId;
  bool _isShowingDeletedDialog = false;

  late AnimationController _animationController;
  Animation<Offset> _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
  int _lastKnownIndex = -1; // -1 означает "ещё не определён"
  String? _lastLocation; // Для отслеживания смены маршрута

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    // Настраиваем callback для обновления данных при возврате из фона
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupLifecycleService();
    });
  }

  void _setupLifecycleService() {
    final lifecycleService = AppLifecycleService.instance;
    lifecycleService.initialize(ref);
    lifecycleService.setRefreshCallback(_refreshAllData);
  }

  /// Инвалидация всех ключевых провайдеров при возврате из фона
  void _refreshAllData(String institutionId) {
    debugPrint('[MainShell] Refreshing all data for institution: $institutionId');

    // Инвалидируем провайдеры заведения
    ref.invalidate(currentInstitutionStreamProvider(institutionId));
    ref.invalidate(currentInstitutionProvider(institutionId));
    ref.invalidate(myMembershipProvider(institutionId));

    // Инвалидируем провайдеры расписания
    ref.invalidate(unmarkedLessonsProvider(institutionId));
    ref.invalidate(unmarkedLessonsStreamProvider(institutionId));
    ref.invalidate(institutionTodayLessonsProvider(institutionId));

    // Инвалидируем провайдеры оплат
    ref.invalidate(paymentsStreamProvider(institutionId));

    // Инвалидируем провайдеры учеников
    ref.invalidate(studentsProvider(institutionId));

    // Инвалидируем провайдеры участников
    ref.invalidate(membersStreamProvider(institutionId));

    // Инвалидируем провайдеры бронирований
    final today = DateTime.now();
    ref.invalidate(bookingsByInstitutionDateProvider(
      InstitutionDateParams(institutionId, today),
    ));

    debugPrint('[MainShell] All providers invalidated');
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

  @override
  void dispose() {
    _animationController.dispose();
    _checkTimer?.cancel();
    super.dispose();
  }

  void _animateToTab(int newIndex) {
    // Первый вызов - просто запоминаем индекс без анимации
    if (_lastKnownIndex == -1) {
      _lastKnownIndex = newIndex;
      return;
    }

    // Если индекс не изменился - ничего не делаем
    if (newIndex == _lastKnownIndex) {
      return;
    }

    final previousIndex = _lastKnownIndex;
    _lastKnownIndex = newIndex;

    // Определяем направление:
    // Если идём на вкладку с бо́льшим индексом (вправо) - страница въезжает справа
    // Если идём на вкладку с меньшим индексом (влево) - страница въезжает слева
    final goingToHigherIndex = newIndex > previousIndex;

    setState(() {
      _slideAnimation = Tween<Offset>(
        begin: Offset(goingToHigherIndex ? 0.3 : -0.3, 0.0), // Меньшее смещение = быстрее
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ));
    });

    // Запускаем анимацию с начала
    _animationController.forward(from: 0.0);
  }

  void _startMembershipCheck(String institutionId) {
    // Отменяем предыдущий таймер если ID изменился
    if (_lastInstitutionId != institutionId) {
      _checkTimer?.cancel();
      _lastInstitutionId = institutionId;

      // Проверяем каждые 10 секунд
      _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _checkMembership(institutionId);
      });
    }
  }

  Future<void> _checkMembership(String institutionId) async {
    if (_isShowingDeletedDialog) return;

    // Инвалидируем и проверяем членство
    ref.invalidate(myMembershipProvider(institutionId));

    // Даём время на загрузку
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final membership = ref.read(myMembershipProvider(institutionId));

    membership.whenData((member) {
      if (member == null && mounted && !_isShowingDeletedDialog) {
        _showInstitutionDeletedDialog();
      }
    });
  }

  void _showInstitutionDeletedDialog() {
    _isShowingDeletedDialog = true;
    _checkTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          size: 48,
          color: AppColors.warning,
        ),
        title: const Text('Заведение удалено'),
        content: const Text(
          'Это заведение было удалено владельцем. Вы будете перенаправлены на главный экран.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/institutions');
            },
            child: const Text('ОК'),
          ),
        ],
      ),
    ).then((_) {
      _isShowingDeletedDialog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    // Определяем текущий индекс на основе маршрута
    int currentIndex = 0;
    if (location.contains('/schedule')) {
      currentIndex = 1;
    } else if (location.contains('/students')) {
      currentIndex = 2;
    } else if (location.contains('/payments')) {
      currentIndex = 3;
    } else if (location.contains('/settings') ||
        location.contains('/statistics')) {
      currentIndex = 4;
    }

    // Извлекаем institutionId из маршрута
    final uri = Uri.parse(location);
    final segments = uri.pathSegments;
    String? institutionId;
    for (int i = 0; i < segments.length; i++) {
      if (segments[i] == 'institutions' && i + 1 < segments.length) {
        institutionId = segments[i + 1];
        break;
      }
    }

    // Запускаем периодическую проверку членства
    if (institutionId != null) {
      _startMembershipCheck(institutionId);
      // Обновляем ID заведения в сервисе для инвалидации при resumed
      AppLifecycleService.instance.setCurrentInstitution(institutionId);
    }

    return Scaffold(
      body: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          if (institutionId == null) return;
          switch (index) {
            case 0:
              context.go('/institutions/$institutionId/dashboard');
              break;
            case 1:
              context.go('/institutions/$institutionId/schedule');
              break;
            case 2:
              context.go('/institutions/$institutionId/students');
              break;
            case 3:
              context.go('/institutions/$institutionId/payments');
              break;
            case 4:
              context.go('/institutions/$institutionId/settings');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: AppStrings.dashboard,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: AppStrings.schedule,
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: AppStrings.students,
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: AppStrings.payments,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: AppStrings.settings,
          ),
        ],
      ),
    );
  }
}
