import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/utils/date_utils.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/features/payments/providers/payment_provider.dart';
import 'package:kabinet/shared/models/lesson.dart';

/// Главный экран (Dashboard)
class DashboardScreen extends ConsumerWidget {
  final String institutionId;

  const DashboardScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final institutionAsync = ref.watch(currentInstitutionProvider(institutionId));
    final lessonsAsync = ref.watch(institutionTodayLessonsProvider(institutionId));
    final debtorsAsync = ref.watch(studentsWithDebtProvider(institutionId));
    final todayPaymentsAsync = ref.watch(todayPaymentsTotalProvider(institutionId));

    return Scaffold(
      appBar: AppBar(
        title: institutionAsync.when(
          data: (institution) => Text(institution.name),
          loading: () => const Text('...'),
          error: (_, __) => const Text('Заведение'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.swap_horiz),
          onPressed: () {
            context.go('/institutions');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              context.go('/institutions/$institutionId/settings');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentInstitutionProvider(institutionId));
          ref.invalidate(institutionTodayLessonsProvider(institutionId));
          ref.invalidate(studentsWithDebtProvider(institutionId));
          ref.invalidate(todayPaymentsTotalProvider(institutionId));
        },
        child: ListView(
          padding: AppSizes.paddingAllM,
          children: [
            // Дата
            Text(
              'Сегодня, ${AppDateUtils.formatDayMonth(today)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Занятия сегодня
            lessonsAsync.when(
              data: (lessons) => _DashboardCard(
                title: 'Занятия сегодня',
                trailing: lessons.length.toString(),
                icon: Icons.event_note,
                onTap: () => context.go('/institutions/$institutionId/rooms'),
              ),
              loading: () => _DashboardCard(
                title: 'Занятия сегодня',
                trailing: '...',
                icon: Icons.event_note,
                onTap: null,
              ),
              error: (_, __) => _DashboardCard(
                title: 'Занятия сегодня',
                trailing: '—',
                icon: Icons.event_note,
                onTap: () => context.go('/institutions/$institutionId/rooms'),
              ),
            ),
            const SizedBox(height: 12),

            // Ближайшее занятие
            lessonsAsync.when(
              data: (lessons) {
                final nextLesson = _getNextLesson(lessons, today);
                if (nextLesson == null) {
                  return _DashboardCard(
                    title: 'Ближайшее занятие',
                    subtitle: 'Нет запланированных занятий',
                    icon: Icons.schedule,
                    onTap: null,
                  );
                }
                return _DashboardCard(
                  title: 'Ближайшее занятие',
                  subtitle: _formatNextLesson(nextLesson),
                  icon: Icons.schedule,
                  onTap: () {
                    // Navigate to lesson detail
                  },
                );
              },
              loading: () => _DashboardCard(
                title: 'Ближайшее занятие',
                subtitle: 'Загрузка...',
                icon: Icons.schedule,
                onTap: null,
              ),
              error: (_, __) => _DashboardCard(
                title: 'Ближайшее занятие',
                subtitle: 'Ошибка загрузки',
                icon: Icons.schedule,
                onTap: null,
              ),
            ),
            const SizedBox(height: 12),

            // Должники
            debtorsAsync.when(
              data: (debtors) {
                final subtitle = debtors.isEmpty
                    ? 'Нет должников'
                    : debtors.take(2).map((s) => '${s.name} (${s.balance})').join(', ');
                return _DashboardCard(
                  title: 'Должники',
                  trailing: debtors.isEmpty ? '0' : debtors.length.toString(),
                  subtitle: subtitle,
                  icon: Icons.warning_amber,
                  iconColor: debtors.isEmpty ? AppColors.success : AppColors.warning,
                  onTap: () => context.go('/institutions/$institutionId/students'),
                );
              },
              loading: () => _DashboardCard(
                title: 'Должники',
                trailing: '...',
                icon: Icons.warning_amber,
                iconColor: AppColors.warning,
                onTap: null,
              ),
              error: (_, __) => _DashboardCard(
                title: 'Должники',
                trailing: '—',
                icon: Icons.warning_amber,
                iconColor: AppColors.warning,
                onTap: () => context.go('/institutions/$institutionId/students'),
              ),
            ),
            const SizedBox(height: 12),

            // Оплаты за сегодня
            todayPaymentsAsync.when(
              data: (total) => _DashboardCard(
                title: 'Сегодня оплачено',
                trailing: _formatCurrency(total),
                icon: Icons.payments,
                iconColor: AppColors.success,
                onTap: () => context.go('/institutions/$institutionId/payments'),
              ),
              loading: () => _DashboardCard(
                title: 'Сегодня оплачено',
                trailing: '...',
                icon: Icons.payments,
                iconColor: AppColors.success,
                onTap: null,
              ),
              error: (_, __) => _DashboardCard(
                title: 'Сегодня оплачено',
                trailing: '—',
                icon: Icons.payments,
                iconColor: AppColors.success,
                onTap: () => context.go('/institutions/$institutionId/payments'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Lesson? _getNextLesson(List<Lesson> lessons, DateTime now) {
    final currentTime = TimeOfDay.now();
    final upcomingLessons = lessons.where((lesson) {
      if (lesson.status == LessonStatus.cancelled ||
          lesson.status == LessonStatus.completed) {
        return false;
      }
      final lessonMinutes = lesson.startTime.hour * 60 + lesson.startTime.minute;
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      return lessonMinutes >= currentMinutes;
    }).toList();

    if (upcomingLessons.isEmpty) return null;
    return upcomingLessons.first;
  }

  String _formatNextLesson(Lesson lesson) {
    final time = '${lesson.startTime.hour.toString().padLeft(2, '0')}:${lesson.startTime.minute.toString().padLeft(2, '0')}';
    final room = lesson.room?.name ?? 'Кабинет';
    final participant = lesson.student?.name ?? lesson.group?.name ?? '';
    return '$time $room — $participant';
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'ru_RU');
    return '${formatter.format(amount.toInt())} ₸';
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailing;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.icon,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Padding(
          padding: AppSizes.paddingAllM,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: iconColor ?? AppColors.primary,
                      ),
                ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
