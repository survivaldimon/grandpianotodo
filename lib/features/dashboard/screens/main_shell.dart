import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/core/services/app_lifecycle_service.dart';
import 'package:kabinet/core/services/connection_manager.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';

/// Провайдер ID текущего заведения
final currentInstitutionIdProvider = StateProvider<String?>((ref) => null);

/// Главная оболочка приложения с нижней навигацией
/// Использует StatefulNavigationShell для сохранения состояния навигации между вкладками
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

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

  /// История переключений вкладок (для back button как в Instagram)
  final List<int> _tabHistory = [0];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    // Инициализируем индекс из navigationShell
    _lastKnownIndex = widget.navigationShell.currentIndex;
    if (!_tabHistory.contains(_lastKnownIndex)) {
      _tabHistory.add(_lastKnownIndex);
    }

    // Настраиваем callback для обновления данных при возврате из фона
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupLifecycleService();
    });
  }

  void _setupLifecycleService() {
    final lifecycleService = AppLifecycleService.instance;
    lifecycleService.initialize(ref);
    lifecycleService.setRefreshCallback(_refreshAllData);

    // Инициализируем ConnectionManager
    ConnectionManager.instance.initialize();
    ConnectionManager.instance.setReconnectCallback(_reconnectAllStreams);
  }

  /// Переподключение всех streams при восстановлении соединения
  void _reconnectAllStreams() {
    final institutionId = ref.read(currentInstitutionIdProvider);
    if (institutionId != null) {
      debugPrint('[MainShell] Reconnecting all streams for: $institutionId');
      _refreshAllData(institutionId);
    }
  }

  /// Инвалидация критичных провайдеров при возврате из фона
  void _refreshAllData(String institutionId) {
    debugPrint('[MainShell] Refreshing critical providers for: $institutionId');

    // Только критичные провайдеры — для header и прав доступа
    ref.invalidate(currentInstitutionStreamProvider(institutionId));
    ref.invalidate(myMembershipProvider(institutionId));

    debugPrint('[MainShell] Critical providers invalidated (Realtime handles the rest)');
  }

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Анимация при программном переключении вкладки (через deep link)
    final oldIndex = oldWidget.navigationShell.currentIndex;
    final newIndex = widget.navigationShell.currentIndex;

    if (oldIndex != newIndex) {
      _animateToTab(newIndex);
      // Добавляем в историю если это не повтор
      if (_tabHistory.isEmpty || _tabHistory.last != newIndex) {
        _tabHistory.add(newIndex);
      }
    }
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

    // Определяем направление анимации
    final goingToHigherIndex = newIndex > previousIndex;

    setState(() {
      _slideAnimation = Tween<Offset>(
        begin: Offset(goingToHigherIndex ? 0.3 : -0.3, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ));
    });

    _animationController.forward(from: 0.0);
  }

  /// Обработка нажатия на вкладку
  void _onTabSelected(int index, String? institutionId) {
    if (institutionId == null) return;

    final currentIndex = widget.navigationShell.currentIndex;

    // Повторное нажатие на активную вкладку - сброс к корню (как Instagram)
    if (index == currentIndex) {
      // initialLocation: true сбрасывает stack к корневому экрану
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }

    // Добавляем в историю если это не повтор
    if (_tabHistory.isEmpty || _tabHistory.last != index) {
      _tabHistory.add(index);
    }

    // Переключение с анимацией
    _animateToTab(index);

    // goBranch сохраняет navigation stack внутри branch (в отличие от goNamed)
    widget.navigationShell.goBranch(index);
  }

  void _startMembershipCheck(String institutionId) {
    if (_lastInstitutionId != institutionId) {
      _checkTimer?.cancel();
      _lastInstitutionId = institutionId;

      _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _checkMembership(institutionId);
      });
    }
  }

  Future<void> _checkMembership(String institutionId) async {
    if (_isShowingDeletedDialog) return;

    ref.invalidate(myMembershipProvider(institutionId));
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
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: AppColors.warning,
          ),
          title: Text(l10n.institutionDeleted),
          content: Text(l10n.institutionDeletedMessage),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/institutions');
              },
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    ).then((_) {
      _isShowingDeletedDialog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final routerState = GoRouterState.of(context);

    // Извлекаем institutionId из pathParameters
    String? institutionId = routerState.pathParameters['institutionId'];

    // Fallback: извлекаем из URL если pathParameters пустой
    if (institutionId == null) {
      final location = routerState.matchedLocation;
      final uri = Uri.parse(location);
      final segments = uri.pathSegments;
      for (int i = 0; i < segments.length; i++) {
        if (segments[i] == 'institutions' && i + 1 < segments.length) {
          institutionId = segments[i + 1];
          break;
        }
      }
    }

    // Запускаем периодическую проверку членства
    if (institutionId != null) {
      _startMembershipCheck(institutionId);
      AppLifecycleService.instance.setCurrentInstitution(institutionId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentInstitutionIdProvider.notifier).state = institutionId;
      });
    }

    // PopScope для обработки back button (как Instagram)
    return PopScope(
      // Разрешаем выход только если мы на Dashboard и история пуста
      canPop: _tabHistory.length <= 1 && currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Если есть история - возвращаемся к предыдущей вкладке
          if (_tabHistory.length > 1) {
            _tabHistory.removeLast();
            final previousTab = _tabHistory.last;
            _animateToTab(previousTab);
            // goBranch сохраняет navigation stack внутри branch
            widget.navigationShell.goBranch(previousTab);
          }
        }
      },
      child: Scaffold(
        body: SlideTransition(
          position: _slideAnimation,
          child: widget.navigationShell,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) => _onTabSelected(index, institutionId),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: AppLocalizations.of(context).dashboard,
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: AppLocalizations.of(context).schedule,
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline),
              selectedIcon: const Icon(Icons.people),
              label: AppLocalizations.of(context).students,
            ),
            NavigationDestination(
              icon: const Icon(Icons.payments_outlined),
              selectedIcon: const Icon(Icons.payments),
              label: AppLocalizations.of(context).payments,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: AppLocalizations.of(context).settings,
            ),
          ],
        ),
      ),
    );
  }
}
