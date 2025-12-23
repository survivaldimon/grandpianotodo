import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/features/auth/screens/splash_screen.dart';
import 'package:kabinet/features/auth/screens/login_screen.dart';
import 'package:kabinet/features/auth/screens/register_screen.dart';
import 'package:kabinet/features/institution/screens/institutions_list_screen.dart';
import 'package:kabinet/features/institution/screens/create_institution_screen.dart';
import 'package:kabinet/features/institution/screens/join_institution_screen.dart';
import 'package:kabinet/features/dashboard/screens/main_shell.dart';
import 'package:kabinet/features/dashboard/screens/dashboard_screen.dart';
import 'package:kabinet/features/rooms/screens/rooms_screen.dart';
import 'package:kabinet/features/schedule/screens/schedule_screen.dart';
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

      // Institutions
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

      // Main App Shell
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Dashboard
          GoRoute(
            path: '/institutions/:institutionId',
            redirect: (context, state) =>
                '/institutions/${state.pathParameters['institutionId']}/dashboard',
          ),
          GoRoute(
            path: '/institutions/:institutionId/dashboard',
            builder: (context, state) => DashboardScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),

          // Schedule (расписание всех кабинетов)
          GoRoute(
            path: '/institutions/:institutionId/schedule',
            builder: (context, state) => AllRoomsScheduleScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),

          // Rooms (настройки кабинетов - для редактирования из Настроек)
          GoRoute(
            path: '/institutions/:institutionId/rooms',
            builder: (context, state) => RoomsScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
            routes: [
              GoRoute(
                path: ':roomId/schedule',
                builder: (context, state) => ScheduleScreen(
                  roomId: state.pathParameters['roomId']!,
                  institutionId: state.pathParameters['institutionId']!,
                ),
              ),
            ],
          ),

          // Students
          GoRoute(
            path: '/institutions/:institutionId/students',
            builder: (context, state) => StudentsListScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
            routes: [
              GoRoute(
                path: ':studentId',
                builder: (context, state) => StudentDetailScreen(
                  studentId: state.pathParameters['studentId']!,
                  institutionId: state.pathParameters['institutionId']!,
                ),
              ),
            ],
          ),

          // Payments
          GoRoute(
            path: '/institutions/:institutionId/payments',
            builder: (context, state) => PaymentsScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),

          // Settings
          GoRoute(
            path: '/institutions/:institutionId/settings',
            builder: (context, state) => SettingsScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),

          // Members
          GoRoute(
            path: '/institutions/:institutionId/members',
            builder: (context, state) => MembersScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),

          // Member Permissions
          GoRoute(
            path: '/institutions/:institutionId/members/:memberId/permissions',
            builder: (context, state) => MemberPermissionsScreen(
              institutionId: state.pathParameters['institutionId']!,
              memberId: state.pathParameters['memberId']!,
            ),
          ),

          // Groups
          GoRoute(
            path: '/institutions/:institutionId/groups',
            builder: (context, state) => GroupsScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),
          GoRoute(
            path: '/institutions/:institutionId/groups/:groupId',
            builder: (context, state) => GroupDetailScreen(
              institutionId: state.pathParameters['institutionId']!,
              groupId: state.pathParameters['groupId']!,
            ),
          ),

          // Statistics
          GoRoute(
            path: '/institutions/:institutionId/statistics',
            builder: (context, state) => StatisticsScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),

          // Lesson Types
          GoRoute(
            path: '/institutions/:institutionId/lesson-types',
            builder: (context, state) => LessonTypesScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),

          // Payment Plans
          GoRoute(
            path: '/institutions/:institutionId/payment-plans',
            builder: (context, state) => PaymentPlansScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),

          // Subjects
          GoRoute(
            path: '/institutions/:institutionId/subjects',
            builder: (context, state) => SubjectsScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),
        ],
      ),
    ],
  );
});
