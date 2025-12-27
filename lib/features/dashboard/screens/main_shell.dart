import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';

/// Провайдер ID текущего заведения
final currentInstitutionIdProvider = StateProvider<String?>((ref) => null);

/// Главная оболочка приложения с нижней навигацией
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  Timer? _checkTimer;
  String? _lastInstitutionId;
  bool _isShowingDeletedDialog = false;

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
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
    }

    return Scaffold(
      body: widget.child,
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
