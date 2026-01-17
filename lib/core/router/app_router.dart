import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/features/auth/screens/splash_screen.dart';
import 'package:kabinet/features/auth/screens/login_screen.dart';
import 'package:kabinet/features/auth/screens/register_screen.dart';
import 'package:kabinet/features/auth/screens/reset_password_screen.dart';
import 'package:kabinet/features/institution/screens/institutions_list_screen.dart';
import 'package:kabinet/features/institution/screens/create_institution_screen.dart';
import 'package:kabinet/features/institution/screens/join_institution_screen.dart';
import 'package:kabinet/features/dashboard/screens/main_shell.dart';
import 'package:kabinet/features/dashboard/screens/dashboard_screen.dart';
import 'package:kabinet/features/rooms/screens/rooms_screen.dart';
import 'package:kabinet/features/schedule/screens/all_rooms_schedule_screen.dart';
import 'package:kabinet/features/students/screens/students_list_screen.dart';
import 'package:kabinet/features/students/screens/student_detail_screen.dart';
import 'package:kabinet/features/payments/screens/payments_screen.dart';
import 'package:kabinet/features/institution/screens/settings_screen.dart';
import 'package:kabinet/features/institution/screens/members_screen.dart';
import 'package:kabinet/features/institution/screens/member_permissions_screen.dart';
import 'package:kabinet/features/groups/screens/groups_screen.dart';
import 'package:kabinet/features/groups/screens/group_detail_screen.dart';
import 'package:kabinet/features/statistics/screens/statistics_screen.dart';
import 'package:kabinet/features/lesson_types/screens/lesson_types_screen.dart';
import 'package:kabinet/features/payment_plans/screens/payment_plans_screen.dart';
import 'package:kabinet/features/subjects/screens/subjects_screen.dart';
import 'package:kabinet/features/profile/screens/profile_screen.dart';
import 'package:kabinet/features/institution/screens/teacher_onboarding_screen.dart';

// Navigator keys для каждой ветки (сохранение состояния навигации)
final _dashboardNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final _scheduleNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'schedule');
final _studentsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'students');
final _paymentsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'payments');
final _settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

/// Провайдер роутера
final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isOnAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/splash';

      // Если на странице splash — не редиректим (она сама разберётся)
      if (state.matchedLocation == '/splash') return null;

      // Если на странице сброса пароля — не редиректим
      if (state.matchedLocation == '/reset-password') return null;

      // Если не авторизован и не на auth странице — редирект на логин
      if (!isAuthenticated && !isOnAuthPage) {
        return '/login';
      }

      // Если авторизован и на auth странице — редирект на список заведений
      if (isAuthenticated && isOnAuthPage) {
        return '/institutions';
      }

      return null;
    },
    routes: [
      // Auth
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // Institutions list
      GoRoute(
        path: '/institutions',
        builder: (context, state) {
          final skipAuto = state.uri.queryParameters['skipAuto'] == 'true';
          return InstitutionsListScreen(skipAutoNav: skipAuto);
        },
      ),
      GoRoute(
        path: '/institutions/create',
        builder: (context, state) => const CreateInstitutionScreen(),
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) => const JoinInstitutionScreen(),
      ),
      GoRoute(
        path: '/join/:code',
        builder: (context, state) => JoinInstitutionScreen(
          code: state.pathParameters['code'],
        ),
      ),

      // Teacher Onboarding (вне ShellRoute — полноэкранный flow)
      GoRoute(
        path: '/institutions/:institutionId/onboarding',
        builder: (context, state) => TeacherOnboardingScreen(
          institutionId: state.pathParameters['institutionId']!,
        ),
      ),

      // Main App: /institutions/:institutionId/...
      // StatefulShellRoute вложен внутрь GoRoute с параметром
      GoRoute(
        path: '/institutions/:institutionId',
        redirect: (context, state) {
          // Редирект на dashboard ТОЛЬКО если путь точно /institutions/:id (без суффикса)
          final fullPath = state.uri.path;
          final institutionId = state.pathParameters['institutionId'];
          final basePath = '/institutions/$institutionId';
          if (fullPath == basePath || fullPath == '$basePath/') {
            return '$basePath/dashboard';
          }
          return null;
        },
        routes: [
          // StatefulShellRoute с сохранением состояния навигации
          // Пути внутри branches НЕ содержат параметров — это требование go_router
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => MainShell(
              navigationShell: navigationShell,
            ),
            branches: [
              // Branch 0: Dashboard
              StatefulShellBranch(
                navigatorKey: _dashboardNavigatorKey,
                routes: [
                  GoRoute(
                    path: 'dashboard',
                    name: 'dashboard',
                    builder: (context, state) => DashboardScreen(
                      institutionId: state.pathParameters['institutionId']!,
                    ),
                  ),
                ],
              ),

              // Branch 1: Schedule
              StatefulShellBranch(
                navigatorKey: _scheduleNavigatorKey,
                routes: [
                  GoRoute(
                    path: 'schedule',
                    name: 'schedule',
                    builder: (context, state) => AllRoomsScheduleScreen(
                      institutionId: state.pathParameters['institutionId']!,
                    ),
                  ),
                ],
              ),

              // Branch 2: Students (+ Groups)
              StatefulShellBranch(
                navigatorKey: _studentsNavigatorKey,
                routes: [
                  GoRoute(
                    path: 'students',
                    name: 'students',
                    builder: (context, state) => StudentsListScreen(
                      institutionId: state.pathParameters['institutionId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: ':studentId',
                        pageBuilder: (context, state) => CupertinoPage(
                          child: StudentDetailScreen(
                            studentId: state.pathParameters['studentId']!,
                            institutionId: state.pathParameters['institutionId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'groups',
                    pageBuilder: (context, state) => CupertinoPage(
                      child: GroupsScreen(
                        institutionId: state.pathParameters['institutionId']!,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: ':groupId',
                        pageBuilder: (context, state) => CupertinoPage(
                          child: GroupDetailScreen(
                            institutionId: state.pathParameters['institutionId']!,
                            groupId: state.pathParameters['groupId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Branch 3: Payments
              StatefulShellBranch(
                navigatorKey: _paymentsNavigatorKey,
                routes: [
                  GoRoute(
                    path: 'payments',
                    name: 'payments',
                    builder: (context, state) => PaymentsScreen(
                      institutionId: state.pathParameters['institutionId']!,
                    ),
                  ),
                ],
              ),

              // Branch 4: Settings (+ все вложенные экраны)
              StatefulShellBranch(
                navigatorKey: _settingsNavigatorKey,
                routes: [
                  GoRoute(
                    path: 'settings',
                    name: 'settings',
                    builder: (context, state) => SettingsScreen(
                      institutionId: state.pathParameters['institutionId']!,
                    ),
                  ),
                  // Members
                  GoRoute(
                    path: 'members',
                    pageBuilder: (context, state) => CupertinoPage(
                      child: MembersScreen(
                        institutionId: state.pathParameters['institutionId']!,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: ':memberId/permissions',
                        pageBuilder: (context, state) => CupertinoPage(
                          child: MemberPermissionsScreen(
                            institutionId: state.pathParameters['institutionId']!,
                            memberId: state.pathParameters['memberId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Rooms
                  GoRoute(
                    path: 'rooms',
                    pageBuilder: (context, state) => CupertinoPage(
                      child: RoomsScreen(
                        institutionId: state.pathParameters['institutionId']!,
                      ),
                    ),
                  ),
                  // Statistics
                  GoRoute(
                    path: 'statistics',
                    pageBuilder: (context, state) => CupertinoPage(
                      child: StatisticsScreen(
                        institutionId: state.pathParameters['institutionId']!,
                      ),
                    ),
                  ),
                  // Lesson Types
                  GoRoute(
                    path: 'lesson-types',
                    pageBuilder: (context, state) => CupertinoPage(
                      child: LessonTypesScreen(
                        institutionId: state.pathParameters['institutionId']!,
                      ),
                    ),
                  ),
                  // Payment Plans
                  GoRoute(
                    path: 'payment-plans',
                    pageBuilder: (context, state) => CupertinoPage(
                      child: PaymentPlansScreen(
                        institutionId: state.pathParameters['institutionId']!,
                      ),
                    ),
                  ),
                  // Subjects
                  GoRoute(
                    path: 'subjects',
                    pageBuilder: (context, state) => CupertinoPage(
                      child: SubjectsScreen(
                        institutionId: state.pathParameters['institutionId']!,
                      ),
                    ),
                  ),
                  // Profile
                  GoRoute(
                    path: 'profile',
                    pageBuilder: (context, state) => const CupertinoPage(
                      child: ProfileScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
