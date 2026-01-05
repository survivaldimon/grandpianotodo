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
import 'package:kabinet/features/subscriptions/providers/subscription_provider.dart';
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/models/subscription.dart';
import 'package:kabinet/core/widgets/error_view.dart';

/// Главный экран (Dashboard)
class DashboardScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const DashboardScreen({super.key, required this.institutionId});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Обновляем данные когда приложение возвращается из фона
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _refreshData() {
    ref.invalidate(currentInstitutionProvider(widget.institutionId));
    ref.invalidate(institutionTodayLessonsProvider(widget.institutionId));
    ref.invalidate(studentsWithDebtProvider(widget.institutionId));
    ref.invalidate(todayPaymentsTotalProvider(widget.institutionId));
    ref.invalidate(unmarkedLessonsStreamProvider(widget.institutionId));
    ref.invalidate(expiringSubscriptionsProvider(
      ExpiringSubscriptionsParams(widget.institutionId, days: 7),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final institutionAsync = ref.watch(currentInstitutionProvider(widget.institutionId));
    final lessonsAsync = ref.watch(institutionTodayLessonsProvider(widget.institutionId));
    final debtorsAsync = ref.watch(studentsWithDebtProvider(widget.institutionId));
    final todayPaymentsAsync = ref.watch(todayPaymentsTotalProvider(widget.institutionId));
    final unmarkedLessonsAsync = ref.watch(unmarkedLessonsStreamProvider(widget.institutionId));
    final expiringSubscriptionsAsync = ref.watch(
      expiringSubscriptionsProvider(ExpiringSubscriptionsParams(widget.institutionId, days: 7)),
    );

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
              context.go('/institutions/${widget.institutionId}/settings');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshData();
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
                onTap: () => context.go('/institutions/${widget.institutionId}/schedule'),
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
                onTap: () => context.go('/institutions/${widget.institutionId}/schedule'),
              ),
            ),
            const SizedBox(height: 12),

            // Неотмеченные занятия (без моргания при обновлении)
            Builder(builder: (context) {
              final lessons = unmarkedLessonsAsync.valueOrNull;

              // Показываем loading только при первой загрузке (когда данных ещё нет)
              if (lessons == null) {
                return _DashboardCard(
                  title: AppStrings.unmarkedLessons,
                  trailing: '...',
                  icon: Icons.pending_actions,
                  onTap: null,
                );
              }

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
            }),
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
                    context.go('/institutions/${widget.institutionId}/schedule');
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
                  onTap: () {
                    ref.read(studentFilterProvider.notifier).state = StudentFilter.withDebt;
                    context.go('/institutions/${widget.institutionId}/students');
                  },
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
                onTap: () {
                  ref.read(studentFilterProvider.notifier).state = StudentFilter.withDebt;
                  context.go('/institutions/${widget.institutionId}/students');
                },
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
                onTap: () => context.go('/institutions/${widget.institutionId}/payments'),
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
                onTap: () => context.go('/institutions/${widget.institutionId}/payments'),
              ),
            ),
            const SizedBox(height: 12),

            // Истекающие абонементы
            expiringSubscriptionsAsync.when(
              data: (subscriptions) {
                if (subscriptions.isEmpty) {
                  return const SizedBox.shrink();
                }
                final subtitle = subscriptions.take(2).map((s) {
                  final name = s.student?.name ?? 'Ученик';
                  final days = s.daysUntilExpiration;
                  return '$name ($days дн.)';
                }).join(', ');
                return _DashboardCard(
                  title: 'Истекающие абонементы',
                  trailing: subscriptions.length.toString(),
                  subtitle: subtitle,
                  icon: Icons.timer,
                  iconColor: AppColors.warning,
                  onTap: () => _showExpiringSubscriptionsSheet(context, subscriptions),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpiringSubscriptionsSheet(
    BuildContext context,
    List<Subscription> subscriptions,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
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
                  const Icon(Icons.timer, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Text(
                    'Истекающие абонементы (${subscriptions.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: subscriptions.length,
                itemBuilder: (context, index) {
                  final sub = subscriptions[index];
                  final studentName = sub.student?.name ?? 'Ученик';
                  final expiresStr = DateFormat('dd.MM.yyyy').format(sub.expiresAt);
                  final daysLeft = sub.daysUntilExpiration;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: daysLeft <= 3
                          ? AppColors.error.withValues(alpha: 0.2)
                          : AppColors.warning.withValues(alpha: 0.2),
                      child: Text(
                        '$daysLeft',
                        style: TextStyle(
                          color: daysLeft <= 3 ? AppColors.error : AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(studentName),
                    subtitle: Text(
                      '${sub.lessonsRemaining}/${sub.lessonsTotal} занятий • до $expiresStr',
                    ),
                    trailing: daysLeft <= 3
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Срочно',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/institutions/${widget.institutionId}/students/${sub.studentId}');
                    },
                  );
                },
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
      builder: (context) => _UnmarkedLessonsSheet(institutionId: widget.institutionId),
    );
  }
}

/// Состояние отметки занятия
class _LessonMark {
  bool isCompleted = false;
  bool isCancelled = false;
  bool isPaid = false;

  bool get hasChanges => isCompleted || isCancelled || isPaid;
}

/// BottomSheet со списком неотмеченных занятий
class _UnmarkedLessonsSheet extends ConsumerStatefulWidget {
  final String institutionId;

  const _UnmarkedLessonsSheet({required this.institutionId});

  @override
  ConsumerState<_UnmarkedLessonsSheet> createState() => _UnmarkedLessonsSheetState();
}

class _UnmarkedLessonsSheetState extends ConsumerState<_UnmarkedLessonsSheet> {
  final Map<String, _LessonMark> _marks = {};
  bool _isSaving = false;

  void _updateMark(String lessonId, {bool? completed, bool? cancelled, bool? paid}) {
    setState(() {
      _marks.putIfAbsent(lessonId, () => _LessonMark());
      final mark = _marks[lessonId]!;

      if (completed != null) {
        mark.isCompleted = completed;
        if (completed) mark.isCancelled = false;
      }
      if (cancelled != null) {
        mark.isCancelled = cancelled;
        if (cancelled) {
          mark.isCompleted = false;
          mark.isPaid = false;
        }
      }
      if (paid != null) {
        mark.isPaid = paid;
        if (paid) {
          mark.isCompleted = true;
          mark.isCancelled = false;
        }
      }
    });
  }

  _LessonMark _getMark(String lessonId) {
    return _marks.putIfAbsent(lessonId, () => _LessonMark());
  }

  bool get _hasAnyChanges => _marks.values.any((m) => m.hasChanges);

  Future<void> _saveAll(List<Lesson> lessons) async {
    if (!_hasAnyChanges) return;

    setState(() => _isSaving = true);

    final lessonController = ref.read(lessonControllerProvider.notifier);
    final paymentController = ref.read(paymentControllerProvider.notifier);

    // Собираем задачи для параллельного выполнения
    final futures = <Future>[];
    final affectedStudentIds = <String>{};

    for (final lesson in lessons) {
      final mark = _marks[lesson.id];
      if (mark == null || !mark.hasChanges) continue;

      if (lesson.studentId != null) {
        affectedStudentIds.add(lesson.studentId!);
      }

      if (mark.isCompleted) {
        futures.add(
          lessonController.complete(lesson.id, lesson.roomId, lesson.date, widget.institutionId).then((_) async {
            // Если оплачено - создать оплату
            if (mark.isPaid && lesson.studentId != null && lesson.lessonType?.defaultPrice != null) {
              final lessonTypeName = lesson.lessonType?.name ?? 'Оплата занятия';
              await paymentController.create(
                institutionId: widget.institutionId,
                studentId: lesson.studentId!,
                amount: lesson.lessonType!.defaultPrice!,
                lessonsCount: 1,
                comment: 'lesson:${lesson.id}|$lessonTypeName',
              );
            }
          }),
        );
      } else if (mark.isCancelled) {
        futures.add(
          lessonController.cancel(lesson.id, lesson.roomId, lesson.date, widget.institutionId),
        );
      }
    }

    // Выполняем все операции параллельно
    await Future.wait(futures);

    // Инвалидируем провайдеры
    ref.invalidate(unmarkedLessonsProvider(widget.institutionId));
    ref.invalidate(unmarkedLessonsStreamProvider(widget.institutionId));
    ref.invalidate(todayPaymentsTotalProvider(widget.institutionId));

    // Примечание: lessonsByInstitutionStreamProvider и institutionTodayLessonsProvider
    // используют StreamProvider и обновляются автоматически через Supabase Realtime

    // Инвалидируем подписки затронутых студентов
    for (final studentId in affectedStudentIds) {
      ref.invalidate(studentSubscriptionsProvider(studentId));
      ref.invalidate(subscriptionsStreamProvider(studentId));
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Изменения сохранены'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(unmarkedLessonsStreamProvider(widget.institutionId));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.pending_actions, color: AppColors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: lessonsAsync.when(
                    skipLoadingOnRefresh: true,
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
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lesson list (без мигания при Realtime обновлениях)
          Expanded(
            child: Builder(
              builder: (context) {
                final lessons = lessonsAsync.valueOrNull;
                final error = lessonsAsync.error;

                // Показываем ошибку если есть (и нет закешированных данных)
                if (error != null && lessons == null) {
                  return ErrorView.fromException(error);
                }

                // Показываем loading только при первой загрузке
                if (lessons == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Показываем данные (даже если идёт фоновая загрузка)
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

                return ListView.separated(
                  controller: scrollController,
                  itemCount: lessons.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final lesson = lessons[index];
                    final mark = _getMark(lesson.id);
                    final hasPrice = lesson.lessonType?.defaultPrice != null &&
                                     lesson.lessonType!.defaultPrice! > 0;
                    final hasStudent = lesson.studentId != null;

                    return _UnmarkedLessonItem(
                      lesson: lesson,
                      mark: mark,
                      showPaid: hasPrice && hasStudent,
                      onCompletedChanged: (v) => _updateMark(lesson.id, completed: v),
                      onCancelledChanged: (v) => _updateMark(lesson.id, cancelled: v),
                      onPaidChanged: (v) => _updateMark(lesson.id, paid: v),
                    );
                  },
                );
              },
            ),
          ),

          // Save button
          if (_hasAnyChanges || _isSaving)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: lessonsAsync.when(
                data: (lessons) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveAll(lessons),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить'),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
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
                  color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
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
class _UnmarkedLessonItem extends StatelessWidget {
  final Lesson lesson;
  final _LessonMark mark;
  final bool showPaid;
  final ValueChanged<bool> onCompletedChanged;
  final ValueChanged<bool> onCancelledChanged;
  final ValueChanged<bool> onPaidChanged;

  const _UnmarkedLessonItem({
    required this.lesson,
    required this.mark,
    required this.showPaid,
    required this.onCompletedChanged,
    required this.onCancelledChanged,
    required this.onPaidChanged,
  });

  @override
  Widget build(BuildContext context) {
    final date = AppDateUtils.formatDayMonth(lesson.date);
    final time =
        '${lesson.startTime.hour.toString().padLeft(2, '0')}:${lesson.startTime.minute.toString().padLeft(2, '0')}';
    final participant = lesson.student?.name ?? lesson.group?.name ?? '—';
    final room = lesson.room?.name ?? '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$date, $time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      participant,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      room,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (showPaid)
                Text(
                  '${lesson.lessonType!.defaultPrice!.toInt()} ₸',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Checkboxes row
          Row(
            children: [
              // Проведено
              _LessonCheckbox(
                label: 'Проведено',
                value: mark.isCompleted,
                onChanged: onCompletedChanged,
                activeColor: AppColors.success,
              ),
              const SizedBox(width: 16),
              // Отменено
              _LessonCheckbox(
                label: 'Отменено',
                value: mark.isCancelled,
                onChanged: onCancelledChanged,
                activeColor: AppColors.warning,
              ),
              // Оплачено
              if (showPaid) ...[
                const SizedBox(width: 16),
                _LessonCheckbox(
                  label: 'Оплачено',
                  value: mark.isPaid,
                  onChanged: onPaidChanged,
                  activeColor: AppColors.primary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Чекбокс с подписью для занятия
class _LessonCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const _LessonCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: activeColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: value ? activeColor : AppColors.textSecondary,
              fontWeight: value ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
