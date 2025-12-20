import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';

/// Провайдер ID текущего заведения
final currentInstitutionIdProvider = StateProvider<String?>((ref) => null);

/// Главная оболочка приложения с нижней навигацией
class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    // Определяем текущий индекс на основе маршрута
    int currentIndex = 0;
    if (location.contains('/rooms')) {
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

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          if (institutionId == null) return;
          switch (index) {
            case 0:
              context.go('/institutions/$institutionId/dashboard');
              break;
            case 1:
              context.go('/institutions/$institutionId/rooms');
              break;
            case 2:
              context.go('/institutions/$institutionId/students');
              break;
            case 3:
              context.go('/institutions/$institutionId/payments');
              break;
            case 4:
              _showMoreMenu(context, institutionId);
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
            icon: Icon(Icons.door_front_door_outlined),
            selectedIcon: Icon(Icons.door_front_door),
            label: AppStrings.rooms,
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
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: AppStrings.more,
          ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context, String institutionId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.groups),
            title: const Text(AppStrings.groups),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to groups
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text(AppStrings.statistics),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to statistics
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text(AppStrings.settings),
            onTap: () {
              Navigator.pop(context);
              context.go('/institutions/$institutionId/settings');
            },
          ),
        ],
      ),
    );
  }
}
