import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/constants/app_strings.dart';
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
    final unmarkedLessonsAsync = ref.watch(unmarkedLessonsStreamProvider(institutionId));

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
            context.go('/institutions?skipAuto=true');
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
          ref.invalidate(unmarkedLessonsProvider(institutionId));
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

            // Неотмеченные занятия
            unmarkedLessonsAsync.when(
              data: (lessons) {
                final subtitle = lessons.isEmpty
                    ? AppStrings.noUnmarkedLessons
                    : lessons.take(2).map((l) {
                        final date = AppDateUtils.formatDayMonth(l.date);
                        final time =
                            '${l.startTime.hour.toString().padLeft(2, '0')}:${l.startTime.minute.toString().padLeft(2, '0')}';
                        return '$date $time';
                      }).join(', ');
                return _DashboardCard(
                  title: AppStrings.unmarkedLessons,
                  trailing: lessons.length.toString(),
                  subtitle: subtitle,
                  icon: Icons.pending_actions,
                  iconColor: lessons.isEmpty ? AppColors.success : AppColors.error,
                  onTap: lessons.isEmpty
                      ? null
                      : () => _showUnmarkedLessonsSheet(context, ref, lessons),
                );
              },
              loading: () => _DashboardCard(
                title: AppStrings.unmarkedLessons,
                trailing: '...',
                icon: Icons.pending_actions,
                onTap: null,
              ),
              error: (_, __) => _DashboardCard(
                title: AppStrings.unmarkedLessons,
                trailing: '—',
                icon: Icons.pending_actions,
                iconColor: AppColors.error,
                onTap: null,
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

  void _showUnmarkedLessonsSheet(
    BuildContext context,
    WidgetRef ref,
    List<Lesson> lessons,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _UnmarkedLessonsSheet(institutionId: institutionId),
    );
  }
}

/// BottomSheet со списком неотмеченных занятий
class _UnmarkedLessonsSheet extends ConsumerWidget {
  final String institutionId;

  const _UnmarkedLessonsSheet({required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(unmarkedLessonsStreamProvider(institutionId));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.pending_actions, color: AppColors.error),
                const SizedBox(width: 12),
                lessonsAsync.when(
                  data: (lessons) => Text(
                    '${AppStrings.unmarkedLessons} (${lessons.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  loading: () => Text(
                    '${AppStrings.unmarkedLessons} (...)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  error: (_, __) => Text(
                    AppStrings.unmarkedLessons,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: lessonsAsync.when(
              data: (lessons) {
                if (lessons.isEmpty) {
                  return Center(
                    child: Text(
                      AppStrings.noUnmarkedLessons,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = lessons[index];
                    return _UnmarkedLessonTile(
                      lesson: lesson,
                      institutionId: institutionId,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
            ),
          ),
        ],
      ),
    );
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

/// Элемент списка неотмеченного занятия
class _UnmarkedLessonTile extends ConsumerStatefulWidget {
  final Lesson lesson;
  final String institutionId;

  const _UnmarkedLessonTile({
    required this.lesson,
    required this.institutionId,
  });

  @override
  ConsumerState<_UnmarkedLessonTile> createState() => _UnmarkedLessonTileState();
}

class _UnmarkedLessonTileState extends ConsumerState<_UnmarkedLessonTile> {
  bool _isCompleted = false;
  bool _isPaid = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final date = AppDateUtils.formatDayMonth(lesson.date);
    final time =
        '${lesson.startTime.hour.toString().padLeft(2, '0')}:${lesson.startTime.minute.toString().padLeft(2, '0')}';
    final participant = lesson.student?.name ?? lesson.group?.name ?? '—';
    final room = lesson.room?.name ?? '—';

    final hasPrice = lesson.lessonType?.defaultPrice != null &&
                     lesson.lessonType!.defaultPrice! > 0;
    final hasStudent = lesson.studentId != null;

    return ListTile(
      title: Text('$date, $time — $participant'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(room),
          if (hasPrice && hasStudent)
            Text(
              '${lesson.lessonType?.name ?? "Занятие"}: ${lesson.lessonType!.defaultPrice!.toInt()} ₸',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
              ),
            ),
        ],
      ),
      trailing: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Checkbox Проведено
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _isCompleted,
                      onChanged: (value) async {
                        if (value == true) {
                          await _handleComplete();
                        } else {
                          setState(() {
                            _isCompleted = false;
                            _isPaid = false;
                          });
                        }
                      },
                      activeColor: AppColors.success,
                    ),
                    Text(
                      'Проведено',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                // Checkbox Оплачено (только если есть цена и ученик)
                if (hasPrice && hasStudent) ...[
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _isPaid,
                        onChanged: _isCompleted
                            ? null
                            : (value) async {
                                setState(() => _isPaid = value ?? false);
                                if (value == true) {
                                  await _handleCompleteWithPayment();
                                }
                              },
                        activeColor: AppColors.primary,
                      ),
                      Text(
                        'Оплачено',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 8),
                // Кнопка Отмена
                IconButton(
                  icon: const Icon(Icons.cancel_outlined),
                  color: AppColors.warning,
                  tooltip: AppStrings.markCancelled,
                  onPressed: _markCancelled,
                ),
                // Кнопка Удалить
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  tooltip: 'Удалить',
                  onPressed: _deleteLesson,
                ),
              ],
            ),
    );
  }

  Future<void> _handleComplete() async {
    setState(() => _isLoading = true);

    final controller = ref.read(lessonControllerProvider.notifier);
    await controller.complete(
      widget.lesson.id,
      widget.lesson.roomId,
      widget.lesson.date,
    );
    ref.invalidate(unmarkedLessonsProvider(widget.institutionId));

    if (mounted) {
      setState(() {
        _isCompleted = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCompleteWithPayment() async {
    setState(() => _isLoading = true);

    final lesson = widget.lesson;

    // Сначала помечаем занятие как проведённое
    final lessonController = ref.read(lessonControllerProvider.notifier);
    await lessonController.complete(
      lesson.id,
      lesson.roomId,
      lesson.date,
    );

    // Затем создаём оплату
    if (lesson.studentId != null && lesson.lessonType?.defaultPrice != null) {
      final paymentController = ref.read(paymentControllerProvider.notifier);
      await paymentController.create(
        institutionId: widget.institutionId,
        studentId: lesson.studentId!,
        amount: lesson.lessonType!.defaultPrice!,
        lessonsCount: 1,
        comment: lesson.lessonType?.name ?? 'Оплата занятия',
      );
    }

    ref.invalidate(unmarkedLessonsProvider(widget.institutionId));
    ref.invalidate(todayPaymentsTotalProvider(widget.institutionId));

    if (mounted) {
      setState(() {
        _isCompleted = true;
        _isPaid = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _markCancelled() async {
    setState(() => _isLoading = true);

    final controller = ref.read(lessonControllerProvider.notifier);
    await controller.cancel(
      widget.lesson.id,
      widget.lesson.roomId,
      widget.lesson.date,
    );
    ref.invalidate(unmarkedLessonsProvider(widget.institutionId));

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLesson() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить занятие?'),
        content: const Text(
          'Занятие будет удалено безвозвратно. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);

      final controller = ref.read(lessonControllerProvider.notifier);
      final success = await controller.delete(
        widget.lesson.id,
        widget.lesson.roomId,
        widget.lesson.date,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Занятие удалено'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
