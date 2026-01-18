import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/features/students/providers/student_bindings_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/features/payments/providers/payment_provider.dart';
import 'package:kabinet/features/payments/repositories/payment_repository.dart';
import 'package:kabinet/features/payments/screens/payments_screen.dart' show showAddPaymentSheet;
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/features/subscriptions/providers/subscription_provider.dart';
import 'package:kabinet/features/lesson_types/providers/lesson_type_provider.dart';
import 'package:kabinet/shared/models/lesson_type.dart';
import 'package:kabinet/features/bookings/providers/booking_provider.dart';
import 'package:kabinet/features/bookings/models/booking.dart';
import 'package:kabinet/features/bookings/repositories/booking_repository.dart' hide DayTimeSlot;
import 'package:kabinet/features/lesson_schedules/providers/lesson_schedule_provider.dart';
import 'package:kabinet/features/lesson_schedules/repositories/lesson_schedule_repository.dart';
import 'package:kabinet/features/lesson_schedules/models/lesson_schedule.dart';
import 'package:kabinet/features/rooms/providers/room_provider.dart';
import 'package:kabinet/shared/models/room.dart';
import 'package:kabinet/core/widgets/ios_time_picker.dart';
import 'package:kabinet/core/providers/phone_settings_provider.dart';
import 'package:kabinet/features/statistics/providers/statistics_provider.dart';
import 'package:kabinet/shared/models/payment.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subscription.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/features/students/widgets/merge_students_dialog.dart';
import 'package:kabinet/features/schedule/repositories/lesson_repository.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart';
import 'package:kabinet/features/schedule/screens/all_rooms_schedule_screen.dart';
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/models/institution_member.dart';

/// Экран профиля ученика
class StudentDetailScreen extends ConsumerWidget {
  final String studentId;
  final String institutionId;

  const StudentDetailScreen({
    super.key,
    required this.studentId,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProvider(studentId));
    final paymentsAsync = ref.watch(studentPaymentsProvider(studentId));
    final subscriptionsAsync = ref.watch(allSubscriptionsStreamProvider(studentId));

    return studentAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView.fromException(
          e,
          onRetry: () => ref.invalidate(studentProvider(studentId)),
        ),
      ),
      data: (student) {
        final hasDebt = student.balance < 0;
        // Проверяем права
        final permissions = ref.watch(myPermissionsProvider(institutionId));
        final institutionAsync = ref.watch(currentInstitutionProvider(institutionId));
        final isMyStudentAsync = ref.watch(isMyStudentProvider(
          IsMyStudentParams(studentId, institutionId),
        ));

        // Проверяем права на редактирование ученика
        final isOwner = institutionAsync.maybeWhen(
          data: (inst) => inst.ownerId == ref.watch(currentUserIdProvider),
          orElse: () => false,
        );
        final isAdmin = ref.watch(isAdminProvider(institutionId));
        final hasFullAccess = isOwner || isAdmin;
        final isMyStudent = isMyStudentAsync.maybeWhen(
          data: (v) => v,
          orElse: () => false,
        );
        final canEditStudent = hasFullAccess ||
            (permissions?.manageAllStudents ?? false) ||
            (isMyStudent && (permissions?.manageOwnStudents ?? false));

        // Право архивировать: владелец, или есть права archiveData, или свой ученик
        final canArchive = isOwner ||
            (permissions?.archiveData ?? false) ||
            isMyStudent;

        return Scaffold(
          appBar: AppBar(
            title: Text(student.name),
            actions: [
              if (canEditStudent)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    _showEditStudentDialog(context, ref, student);
                  },
                ),
              if (canArchive || canEditStudent)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'archive') {
                      _confirmArchive(context, ref, student);
                    } else if (value == 'restore') {
                      _confirmRestore(context, ref, student);
                    } else if (value == 'delete') {
                      _confirmDeleteCompletely(context, ref, student);
                    } else if (value == 'merge') {
                      _showMergeWithDialog(context, ref, student);
                    }
                  },
                  itemBuilder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return [
                    // Merge with... (only for non-archived)
                    if (!student.isArchived && canEditStudent)
                      PopupMenuItem(
                        value: 'merge',
                        child: Row(
                          children: [
                            const Icon(Icons.merge, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(l10n.mergeWith),
                          ],
                        ),
                      ),
                    if (canArchive) ...[
                      if (student.isArchived)
                        PopupMenuItem(
                          value: 'restore',
                          child: Row(
                            children: [
                              const Icon(Icons.unarchive, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(l10n.unarchive, style: const TextStyle(color: Colors.green)),
                            ],
                          ),
                        )
                      else
                        PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              const Icon(Icons.archive, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(l10n.archive, style: const TextStyle(color: Colors.orange)),
                            ],
                          ),
                        ),
                      // Delete forever - available always (both archived and active)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_forever, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(l10n.deleteForever, style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ];
                  },
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentProvider(studentId));
              ref.invalidate(studentPaymentsProvider(studentId));
              ref.invalidate(allSubscriptionsStreamProvider(studentId));
              ref.invalidate(studentLessonStatsProvider(studentId));
            },
            child: ListView(
              padding: AppSizes.paddingAllM,
              children: [
                // Archived banner
                if (student.isArchived) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.archive, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.studentInArchive,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd.MM.yyyy').format(student.archivedAt!),
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Merged students section (if any)
                if (student.isMerged) ...[
                  _MergedStudentsCard(mergedFrom: student.mergedFrom!),
                  const SizedBox(height: 16),
                ],
                // Contact info
                Card(
                  child: Padding(
                    padding: AppSizes.paddingAllM,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (student.phone != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.phone, color: AppColors.textSecondary),
                              const SizedBox(width: 12),
                              Text(
                                student.phone!,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (student.comment != null) ...[
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return Text(
                                '${l10n.comment}:',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(student.comment!),
                        ],
                        if (student.phone == null && student.comment == null)
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return Text(
                                l10n.noPhone,
                                style: const TextStyle(color: AppColors.textSecondary),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Prepaid lessons and avg cost
                _BalanceAndCostCard(
                  student: student,
                  hasDebt: hasDebt,
                  studentId: studentId,
                  onAddPayment: canEditStudent ? () => _showAddPaymentDialog(context, ref) : null,
                  onManageLessons: canEditStudent && !student.isArchived
                      ? () => _showBulkLessonActionsSheet(context, ref, student)
                      : null,
                  onAddLessons: canEditStudent && !student.isArchived
                      ? () => _showAddLessonsSheet(context, ref, student)
                      : null,
                  showAvgCost: hasFullAccess, // Только владелец/админ видит среднюю стоимость
                ),
                const SizedBox(height: 16),

                // Lesson statistics
                _LessonStatsCard(studentId: studentId),
                const SizedBox(height: 24),

                // Subscriptions section
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return Text(
                      l10n.subscriptions,
                      style: Theme.of(context).textTheme.titleMedium,
                    );
                  },
                ),
                const SizedBox(height: 8),
                subscriptionsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (subscriptions) {
                    if (subscriptions.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return Text(
                                l10n.noSubscriptions,
                                style: const TextStyle(color: AppColors.textSecondary),
                              );
                            },
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: subscriptions.map((sub) => _SubscriptionCard(
                        subscription: sub,
                        currentStudentId: studentId,
                        onFreeze: canEditStudent ? () => _showFreezeDialog(context, ref, sub) : null,
                        onUnfreeze: canEditStudent ? () => _unfreezeSubscription(context, ref, sub) : null,
                        onExtend: canEditStudent ? () => _showExtendDialog(context, ref, sub) : null,
                      )).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Schedule slots section
                _ScheduleSlotsSection(
                  studentId: studentId,
                  institutionId: institutionId,
                  canEdit: canEditStudent,
                ),
                const SizedBox(height: 24),

                // Teachers section
                _TeachersSection(
                  studentId: studentId,
                  institutionId: institutionId,
                  canEdit: canEditStudent,
                ),
                const SizedBox(height: 24),

                // Subjects section
                _SubjectsSection(
                  studentId: studentId,
                  institutionId: institutionId,
                  canEdit: canEditStudent,
                ),
                const SizedBox(height: 24),

                // Lesson Types section
                _LessonTypesSection(
                  studentId: studentId,
                  institutionId: institutionId,
                  canEdit: canEditStudent,
                ),
                const SizedBox(height: 24),

                // Payments history
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return Text(
                      l10n.paymentHistory,
                      style: Theme.of(context).textTheme.titleMedium,
                    );
                  },
                ),
                const SizedBox(height: 8),
                paymentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (payments) {
                    if (payments.isEmpty) {
                      return Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Text(
                            l10n.noPayments,
                            style: const TextStyle(color: AppColors.textSecondary),
                          );
                        },
                      );
                    }
                    return Column(
                      children: payments.map((p) => _PaymentItem(payment: p)).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Lesson History section
                _LessonHistorySection(
                  studentId: studentId,
                  institutionId: institutionId,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditStudentDialog(BuildContext context, WidgetRef ref, Student student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditStudentSheet(
        student: student,
        institutionId: institutionId,
        phoneDefaultPrefix: ref.read(phoneDefaultPrefixProvider),
        onSaved: () {
          ref.invalidate(studentProvider(studentId));
          ref.invalidate(studentPaymentsProvider(studentId));
        },
      ),
    );
  }

  void _showBulkLessonActionsSheet(BuildContext context, WidgetRef ref, Student student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BulkLessonActionsSheet(
        student: student,
        institutionId: institutionId,
        onCompleted: () {
          // Инвалидируем провайдеры после операций
          ref.invalidate(studentProvider(studentId));
          ref.invalidate(studentLessonStatsProvider(studentId));
        },
      ),
    );
  }

  void _showAddLessonsSheet(BuildContext context, WidgetRef ref, Student student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddLessonsSheet(
        student: student,
        institutionId: institutionId,
        onCompleted: () {
          // Инвалидируем провайдеры после операций
          ref.invalidate(studentProvider(studentId));
          ref.invalidate(studentPaymentsProvider(studentId));
        },
      ),
    );
  }

  void _confirmArchive(BuildContext context, WidgetRef ref, Student student) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.archiveStudentQuestion),
        content: Text(l10n.archiveStudentMessage(student.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final controller = ref.read(studentControllerProvider.notifier);
              final success = await controller.archive(studentId, institutionId);
              if (success && context.mounted) {
                Navigator.pop(context);
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.studentArchived)),
                );
              }
            },
            child: Text(
              l10n.archive,
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRestore(BuildContext context, WidgetRef ref, Student student) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreStudentQuestion),
        content: Text(l10n.restoreStudentMessage(student.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final controller = ref.read(studentControllerProvider.notifier);
              final success = await controller.restore(studentId, institutionId);
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.studentUnarchived),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(
              l10n.unarchive,
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCompletely(BuildContext context, WidgetRef ref, Student student) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(l10n.deleteStudentQuestion),
          ],
        ),
        content: Text(l10n.deleteStudentMessage(student.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final controller = ref.read(studentControllerProvider.notifier);
              final success = await controller.deleteCompletely(studentId, institutionId);
              if (success && context.mounted) {
                Navigator.pop(context); // Close dialog
                context.pop(); // Return to students list
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.studentDeleted),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              l10n.deleteForever,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context, WidgetRef ref) {
    // Используем унифицированный экран добавления оплаты
    showAddPaymentSheet(
      context: context,
      ref: ref,
      institutionId: institutionId,
      canAddForAllStudents: false, // В карточке ученика - только для этого ученика
      preselectedStudentId: studentId,
      onSuccess: () {
        ref.invalidate(studentProvider(studentId));
        ref.invalidate(studentPaymentsProvider(studentId));
        ref.invalidate(subscriptionsStreamProvider(studentId));
        ref.invalidate(studentSubscriptionsProvider(studentId));
        ref.invalidate(activeSubscriptionsProvider(studentId));
      },
    );
  }

  /// Показать диалог выбора учеников для объединения
  void _showMergeWithDialog(BuildContext context, WidgetRef ref, Student currentStudent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (bottomSheetContext) => _SelectStudentsForMergeSheet(
        institutionId: institutionId,
        currentStudent: currentStudent,
        onStudentsSelected: (selectedStudents) async {
          Navigator.pop(bottomSheetContext);
          // Показываем диалог объединения
          final newStudent = await MergeStudentsDialog.show(
            context,
            students: [currentStudent, ...selectedStudents],
            institutionId: institutionId,
            onMerged: () {
              ref.invalidate(studentsProvider(institutionId));
            },
          );
          // Если создан новый ученик — переходим к нему
          if (newStudent != null && context.mounted) {
            context.go('/institutions/$institutionId/students/${newStudent.id}');
          }
        },
      ),
    );
  }

  void _showFreezeDialog(BuildContext context, WidgetRef ref, Subscription subscription) {
    final l10n = AppLocalizations.of(context);
    final daysController = TextEditingController(text: '14');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.freezeSubscription),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.freezeSubscriptionDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: daysController,
                decoration: InputDecoration(
                  labelText: l10n.daysCount,
                  hintText: '14',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.enterQuantityValidation;
                  final num = int.tryParse(v);
                  if (num == null || num <= 0 || num > 90) {
                    return l10n.enterNumberFrom1To90;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final controller = ref.read(subscriptionControllerProvider.notifier);
                final result = await controller.freeze(
                  subscription.id,
                  studentId,
                  int.parse(daysController.text),
                );
                if (result != null && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.subscriptionFrozen)),
                  );
                }
              }
            },
            child: Text(l10n.freeze),
          ),
        ],
      ),
    );
  }

  void _unfreezeSubscription(BuildContext context, WidgetRef ref, Subscription subscription) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(subscriptionControllerProvider.notifier);
    final result = await controller.unfreeze(subscription.id, studentId);
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.subscriptionUnfrozen(DateFormat('dd.MM.yyyy').format(result.expiresAt))),
        ),
      );
    }
  }

  void _showExtendDialog(BuildContext context, WidgetRef ref, Subscription subscription) {
    final l10n = AppLocalizations.of(context);
    final daysController = TextEditingController(text: '7');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.extendSubscription),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.currentTermUntil(DateFormat('dd.MM.yyyy').format(subscription.expiresAt)),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: daysController,
                decoration: InputDecoration(
                  labelText: l10n.extendForDays,
                  hintText: '7',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.enterQuantityValidation;
                  final num = int.tryParse(v);
                  if (num == null || num <= 0 || num > 365) {
                    return l10n.enterNumberFrom1To365;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final controller = ref.read(subscriptionControllerProvider.notifier);
                final result = await controller.extend(
                  subscription.id,
                  studentId,
                  int.parse(daysController.text),
                );
                if (result != null && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.termExtendedUntil(DateFormat('dd.MM.yyyy').format(result.expiresAt))),
                    ),
                  );
                }
              }
            },
            child: Text(l10n.extend),
          ),
        ],
      ),
    );
  }
}

/// Карточка баланса и средней стоимости занятия
class _BalanceAndCostCard extends ConsumerWidget {
  final Student student;
  final bool hasDebt;
  final String studentId;
  final VoidCallback? onAddPayment;
  final VoidCallback? onManageLessons;
  final VoidCallback? onAddLessons; // Добавить занятия (balance transfer)
  final bool showAvgCost;

  const _BalanceAndCostCard({
    required this.student,
    required this.hasDebt,
    required this.studentId,
    this.onAddPayment,
    this.onManageLessons,
    this.onAddLessons,
    this.showAvgCost = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final avgCostAsync = ref.watch(studentAvgCostProvider(studentId));
    final formatter = NumberFormat('#,###', 'ru_RU');

    return Card(
      color: (hasDebt ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
      child: Padding(
        padding: AppSizes.paddingAllL,
        child: Column(
          children: [
            // Баланс и средняя стоимость в строке
            Row(
              children: [
                // Баланс
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        l10n.prepaidLessons.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.balance.toString(),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: hasDebt ? AppColors.error : AppColors.primary,
                            ),
                      ),
                      Text(
                        l10n.lessonsUnit,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      // Разбивка баланса если есть остаток (transfer balance)
                      if (student.hasLegacyBalance) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.subscriptionBalanceLabel(student.subscriptionBalance),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.sync_alt,
                              size: 12,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.legacyBalanceShort(student.legacyBalance),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ],
                      // Кнопка добавления занятий (balance transfer)
                      if (onAddLessons != null) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: onAddLessons,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.addLessonsAction,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Разделитель и средняя стоимость (только для владельца/админа)
                if (showAvgCost) ...[
                  Container(
                    width: 1,
                    height: 60,
                    color: hasDebt
                        ? AppColors.error.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                  // Средняя стоимость
                  Expanded(
                    child: avgCostAsync.when(
                    loading: () => const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (stats) {
                      if (!stats.hasData) {
                        return Column(
                          children: [
                            Text(
                              l10n.avgCost,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '—',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            Text(
                              l10n.noDataAvailable,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Text(
                            stats.isApproximate ? l10n.avgCostApprox : l10n.avgCost,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatter.format(stats.displayCost.round())} ₸',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                          ),
                          Text(
                            l10n.perLesson,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                ], // if (showAvgCost)
              ],
            ),
            if (onAddPayment != null || onManageLessons != null) ...[
              const SizedBox(height: 16),
              // Кнопки управления и оплаты
              Row(
                children: [
                  if (onManageLessons != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onManageLessons,
                        icon: const Icon(Icons.event_note),
                        label: Text(l10n.manageLessonsAction),
                      ),
                    ),
                  if (onManageLessons != null && onAddPayment != null)
                    const SizedBox(width: 8),
                  if (onAddPayment != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAddPayment,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addPayment),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Карточка статистики занятий (проведено/отменено)
class _LessonStatsCard extends ConsumerWidget {
  final String studentId;

  const _LessonStatsCard({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(studentLessonStatsProvider(studentId));

    return statsAsync.when(
      loading: () => Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        // Если нет занятий вообще — не показываем карточку
        if (stats.completed == 0 && stats.cancelled == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.lessonStatisticsTitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Проведено
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stats.completed.toString(),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                            ),
                            Text(
                              l10n.conductedLabel,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.success,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Отменено
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.cancel,
                              color: AppColors.error,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stats.cancelled.toString(),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                  ),
                            ),
                            Text(
                              l10n.cancelledLabel,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.error,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaymentItem extends StatelessWidget {
  final Payment payment;

  const _PaymentItem({required this.payment});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy').format(payment.paidAt);
    final formatter = NumberFormat('#,###', 'ru_RU');

    // Специальное отображение для balance_transfer записей
    if (payment.isBalanceTransfer) {
      return _buildBalanceTransferItem(context, dateStr);
    }

    final amountStr = '${formatter.format(payment.amount.toInt())} ₸';

    // Проверяем, есть ли скидка в комментарии
    final l10n = AppLocalizations.of(context);
    final hasDiscount = payment.comment?.contains('${l10n.discountLabel}:') ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Иконка
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: payment.isCorrection
                    ? AppColors.warning.withValues(alpha: 0.1)
                    : AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                payment.isCorrection ? Icons.edit : Icons.payments,
                color: payment.isCorrection ? AppColors.warning : AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        amountStr,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (payment.paymentPlan != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            payment.paymentPlan!.name,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      if (hasDiscount) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.discount, size: 12, color: AppColors.warning),
                              const SizedBox(width: 2),
                              Text(
                                l10n.discountLabel,
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.paymentLessonsWithDate(payment.lessonsCount, dateStr),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  if (payment.comment != null && payment.comment!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      payment.comment!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Бейджи
            if (payment.isCorrection)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l10n.correctionLabel,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Отображение записи переноса баланса (balance_transfer)
  Widget _buildBalanceTransferItem(BuildContext context, String dateStr) {
    final l10n = AppLocalizations.of(context);
    final remaining = payment.transferLessonsRemaining ?? 0;
    final total = payment.lessonsCount;
    final isExhausted = remaining <= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isExhausted
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Иконка
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isExhausted
                    ? Colors.grey.withValues(alpha: 0.1)
                    : AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.sync_alt,
                color: isExhausted ? Colors.grey : AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.legacyBalanceTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isExhausted
                              ? Colors.grey
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Бейдж с количеством
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isExhausted
                              ? Colors.grey.withValues(alpha: 0.2)
                              : AppColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$remaining / $total',
                          style: TextStyle(
                            color: isExhausted ? Colors.grey : AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  if (payment.comment != null && payment.comment!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      payment.comment!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Индикатор исчерпания
            if (isExhausted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l10n.exhaustedStatus,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final String currentStudentId;
  final VoidCallback? onFreeze;
  final VoidCallback? onUnfreeze;
  final VoidCallback? onExtend;

  const _SubscriptionCard({
    required this.subscription,
    required this.currentStudentId,
    this.onFreeze,
    this.onUnfreeze,
    this.onExtend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = subscription.status;
    final Color statusColor;
    final Color cardColor;

    switch (status) {
      case SubscriptionStatus.active:
        statusColor = AppColors.success;
        cardColor = subscription.isExpiringSoon
            ? AppColors.warning.withValues(alpha: 0.1)
            : AppColors.success.withValues(alpha: 0.1);
        break;
      case SubscriptionStatus.frozen:
        statusColor = AppColors.info;
        cardColor = AppColors.info.withValues(alpha: 0.1);
        break;
      case SubscriptionStatus.expired:
        statusColor = AppColors.error;
        cardColor = AppColors.error.withValues(alpha: 0.1);
        break;
      case SubscriptionStatus.exhausted:
        statusColor = AppColors.textSecondary;
        cardColor = AppColors.textSecondary.withValues(alpha: 0.1);
        break;
    }

    final expiresStr = DateFormat('dd.MM.yyyy').format(subscription.expiresAt);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subscription.getLocalizedStatusName(l10n),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Payment plan name badge
                if (subscription.paymentPlanName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      subscription.paymentPlanName!,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (subscription.isExpiringSoon && status == SubscriptionStatus.active) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.expiringSoon,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                // Family badge
                if (subscription.isFamilySubscription) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.family_restroom,
                          size: 14,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.groupSubscription,
                          style: const TextStyle(
                            color: Colors.purple,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Lessons info
            Row(
              children: [
                Icon(
                  Icons.school,
                  size: 18,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.subscriptionLessonsProgress(subscription.lessonsRemaining, subscription.lessonsTotal),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Expiry info
            Row(
              children: [
                const Icon(
                  Icons.event,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                if (status == SubscriptionStatus.frozen && subscription.frozenUntil != null)
                  Text(
                    l10n.frozenUntilDate(DateFormat('dd.MM.yyyy').format(subscription.frozenUntil!)),
                    style: const TextStyle(color: AppColors.info),
                  )
                else
                  Text(
                    status == SubscriptionStatus.expired
                        ? l10n.expiredDate(expiresStr)
                        : l10n.validUntilDate(expiresStr),
                    style: TextStyle(
                      color: status == SubscriptionStatus.expired
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                if (status == SubscriptionStatus.active && subscription.daysUntilExpiration >= 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    l10n.daysRemainingShort(subscription.daysUntilExpiration),
                    style: TextStyle(
                      color: subscription.isExpiringSoon
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontWeight: subscription.isExpiringSoon
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
            // Progress bar
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: subscription.usagePercent,
              backgroundColor: statusColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
            // Family members (only for family subscriptions)
            if (subscription.isFamilySubscription && subscription.members != null && subscription.members!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.people,
                    size: 18,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: subscription.members!
                          .where((m) => m.student != null)
                          .map((member) {
                        final isCurrentStudent = member.studentId == currentStudentId;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCurrentStudent
                                ? Colors.purple.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: isCurrentStudent
                                ? Border.all(color: Colors.purple.withValues(alpha: 0.5))
                                : null,
                          ),
                          child: Text(
                            member.student!.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrentStudent ? FontWeight.bold : FontWeight.normal,
                              color: isCurrentStudent ? Colors.purple : AppColors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
            // Action buttons (only if can edit)
            if (status != SubscriptionStatus.exhausted && (onFreeze != null || onUnfreeze != null || onExtend != null)) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (status == SubscriptionStatus.active && onFreeze != null)
                    OutlinedButton.icon(
                      onPressed: onFreeze,
                      icon: const Icon(Icons.ac_unit, size: 18, color: AppColors.info),
                      label: Text(l10n.freeze),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: BorderSide(color: AppColors.info.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (status == SubscriptionStatus.frozen && onUnfreeze != null)
                    ElevatedButton.icon(
                      onPressed: onUnfreeze,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(l10n.unfreezeAction),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if ((status == SubscriptionStatus.active || status == SubscriptionStatus.expired) && onExtend != null)
                    OutlinedButton.icon(
                      onPressed: onExtend,
                      icon: const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                      label: Text(l10n.extend),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Секция преподавателей ученика
class _TeachersSection extends ConsumerWidget {
  final String studentId;
  final String institutionId;
  final bool canEdit;

  const _TeachersSection({
    required this.studentId,
    required this.institutionId,
    this.canEdit = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final teachersAsync = ref.watch(studentTeachersProvider(studentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.teachersSection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _showAddTeacherDialog(context, ref),
                tooltip: l10n.addTeacherTooltip,
              ),
          ],
        ),
        const SizedBox(height: 8),
        teachersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
          data: (teachers) {
            if (teachers.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.noLinkedTeachers,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: teachers.map((binding) {
                final name = binding.teacher?.fullName ?? l10n.unknownName;
                return Chip(
                  avatar: const Icon(Icons.person, size: 18),
                  label: Text(name),
                  deleteIcon: canEdit ? const Icon(Icons.close, size: 18) : null,
                  onDeleted: canEdit ? () => _removeTeacher(context, ref, binding.userId) : null,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showAddTeacherDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final membersAsync = ref.watch(membersStreamProvider(institutionId));
          final existingTeachers = ref.watch(studentTeachersProvider(studentId)).valueOrNull ?? [];
          final existingIds = existingTeachers.map((t) => t.userId).toSet();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.addTeacherTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                membersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (members) {
                    final available = members
                        .where((m) => !existingIds.contains(m.userId))
                        .toList();
                    if (available.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.allTeachersAdded),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final member = available[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(member.profile?.fullName ?? member.roleName),
                          onTap: () async {
                            Navigator.pop(dialogContext);
                            await ref
                                .read(studentBindingsControllerProvider.notifier)
                                .addTeacher(
                                  studentId: studentId,
                                  userId: member.userId,
                                  institutionId: institutionId,
                                );
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(l10n.teacherAdded)),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _removeTeacher(BuildContext context, WidgetRef ref, String userId) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeTeacherQuestion),
        content: Text(l10n.removeTeacherMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(studentBindingsControllerProvider.notifier)
                  .removeTeacher(studentId, userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.teacherRemoved)),
                );
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Секция предметов ученика
class _SubjectsSection extends ConsumerWidget {
  final String studentId;
  final String institutionId;
  final bool canEdit;

  const _SubjectsSection({
    required this.studentId,
    required this.institutionId,
    this.canEdit = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subjectsAsync = ref.watch(studentSubjectsProvider(studentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.subjectsSection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _showAddSubjectDialog(context, ref),
                tooltip: l10n.addSubjectTooltip,
              ),
          ],
        ),
        const SizedBox(height: 8),
        subjectsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
          data: (subjects) {
            if (subjects.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.noLinkedSubjects,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects.map((binding) {
                final name = binding.subject?.name ?? l10n.unknownName;
                final color = binding.subject?.color != null
                    ? Color(int.parse('0xFF${binding.subject!.color!.replaceAll('#', '')}'))
                    : AppColors.primary;
                return Chip(
                  avatar: Icon(Icons.book, size: 18, color: color),
                  label: Text(name),
                  deleteIcon: canEdit ? const Icon(Icons.close, size: 18) : null,
                  onDeleted: canEdit ? () => _removeSubject(context, ref, binding.subjectId) : null,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showAddSubjectDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final subjectsListAsync = ref.watch(subjectsListProvider(institutionId));
          final existingSubjects = ref.watch(studentSubjectsProvider(studentId)).valueOrNull ?? [];
          final existingIds = existingSubjects.map((s) => s.subjectId).toSet();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.addSubjectTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                subjectsListAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (subjects) {
                    final available = subjects
                        .where((s) => !existingIds.contains(s.id) && s.archivedAt == null)
                        .toList();
                    if (available.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.allSubjectsAdded),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final subject = available[index];
                        final color = subject.color != null
                            ? Color(int.parse('0xFF${subject.color!.replaceAll('#', '')}'))
                            : AppColors.primary;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.2),
                            child: Icon(Icons.book, color: color),
                          ),
                          title: Text(subject.name),
                          onTap: () async {
                            Navigator.pop(dialogContext);
                            await ref
                                .read(studentBindingsControllerProvider.notifier)
                                .addSubject(
                                  studentId: studentId,
                                  subjectId: subject.id,
                                  institutionId: institutionId,
                                );
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(l10n.subjectAdded)),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _removeSubject(BuildContext context, WidgetRef ref, String subjectId) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeSubjectQuestion),
        content: Text(l10n.removeSubjectMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(studentBindingsControllerProvider.notifier)
                  .removeSubject(studentId, subjectId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.subjectRemoved)),
                );
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Секция типов занятий ученика
class _LessonTypesSection extends ConsumerWidget {
  final String studentId;
  final String institutionId;
  final bool canEdit;

  const _LessonTypesSection({
    required this.studentId,
    required this.institutionId,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lessonTypesAsync = ref.watch(studentLessonTypesProvider(studentId));
    final allLessonTypesAsync = ref.watch(lessonTypesProvider(institutionId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.category, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.lessonTypesSection,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _showAddLessonTypeDialog(context, ref, allLessonTypesAsync),
                    tooltip: l10n.addLessonTypeTooltip,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            lessonTypesAsync.when(
              data: (lessonTypes) {
                if (lessonTypes.isEmpty) {
                  return Text(
                    l10n.noLinkedLessonTypes,
                    style: TextStyle(color: Colors.grey[600]),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: lessonTypes.map((binding) {
                    final lessonType = binding.lessonType;
                    if (lessonType == null) return const SizedBox.shrink();
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: const Icon(Icons.category, size: 16, color: AppColors.primary),
                      ),
                      label: Text(lessonType.name),
                      deleteIcon: canEdit ? const Icon(Icons.close, size: 18) : null,
                      onDeleted: canEdit
                          ? () => _removeLessonType(context, ref, binding.lessonTypeId)
                          : null,
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(l10n.errorFormat(e.toString()), style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLessonTypeDialog(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<LessonType>> allLessonTypesAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    final existingIds = ref.read(studentLessonTypesProvider(studentId)).valueOrNull
        ?.map((e) => e.lessonTypeId)
        .toSet() ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (dialogContext) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.addLessonTypeTitle,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: allLessonTypesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(l10n.errorFormat(e.toString()))),
                  data: (allLessonTypes) {
                    final available = allLessonTypes
                        .where((lt) => !existingIds.contains(lt.id))
                        .toList();
                    if (available.isEmpty) {
                      return Center(
                        child: Text(l10n.allLessonTypesAdded),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final lessonType = available[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                            child: const Icon(Icons.category, color: AppColors.primary),
                          ),
                          title: Text(lessonType.name),
                          onTap: () async {
                            Navigator.pop(dialogContext);
                            await ref
                                .read(studentBindingsControllerProvider.notifier)
                                .addLessonType(
                                  studentId: studentId,
                                  lessonTypeId: lessonType.id,
                                  institutionId: institutionId,
                                );
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(l10n.lessonTypeAdded)),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeLessonType(BuildContext context, WidgetRef ref, String lessonTypeId) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeLessonTypeQuestion),
        content: Text(l10n.removeLessonTypeMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(studentBindingsControllerProvider.notifier)
                  .removeLessonType(studentId, lessonTypeId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.lessonTypeRemoved)),
                );
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Sheet для выбора учеников для объединения
class _SelectStudentsForMergeSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final Student currentStudent;
  final void Function(List<Student>) onStudentsSelected;

  const _SelectStudentsForMergeSheet({
    required this.institutionId,
    required this.currentStudent,
    required this.onStudentsSelected,
  });

  @override
  ConsumerState<_SelectStudentsForMergeSheet> createState() =>
      _SelectStudentsForMergeSheetState();
}

class _SelectStudentsForMergeSheetState
    extends ConsumerState<_SelectStudentsForMergeSheet> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider(widget.institutionId));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.merge, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mergeWithAction,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.selectStudentsToMerge(widget.currentStudent.name),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.searchStudentsHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              ),
            ),

            // Student list
            Expanded(
              child: studentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
                data: (students) {
                  // Фильтруем: исключаем текущего ученика и архивированных
                  var filtered = students
                      .where((s) =>
                          s.id != widget.currentStudent.id && s.archivedAt == null)
                      .toList();

                  // Поиск
                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered
                        .where((s) => s.name.toLowerCase().contains(_searchQuery))
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(l10n.noStudentsToMerge),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      final isSelected = _selectedIds.contains(student.id);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedIds.add(student.id);
                            } else {
                              _selectedIds.remove(student.id);
                            }
                          });
                        },
                        secondary: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            student.name.isNotEmpty
                                ? student.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(student.name),
                        subtitle: Row(
                          children: [
                            Text(
                              l10n.balanceValue(student.balance),
                              style: TextStyle(
                                color: student.hasDebt
                                    ? AppColors.error
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (student.phone != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '• ${student.phone}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Actions
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () {
                                final selectedStudents = ref
                                    .read(studentsProvider(widget.institutionId))
                                    .valueOrNull
                                    ?.where((s) => _selectedIds.contains(s.id))
                                    .toList() ?? [];
                                widget.onStudentsSelected(selectedStudents);
                              },
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          _selectedIds.isEmpty
                              ? l10n.selectStudentsValidation
                              : l10n.nextWithCount(_selectedIds.length),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка с именами объединённых учеников
class _MergedStudentsCard extends ConsumerWidget {
  final List<String> mergedFrom;

  const _MergedStudentsCard({required this.mergedFrom});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final namesAsync = ref.watch(mergedStudentNamesProvider(mergedFrom));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.merge, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.groupCard,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          namesAsync.when(
            loading: () => const SizedBox(
              height: 24,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Text(
              l10n.failedToLoadNames,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            data: (names) => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: names.map((name) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Секция постоянного расписания ученика
class _ScheduleSlotsSection extends ConsumerWidget {
  final String studentId;
  final String institutionId;
  final bool canEdit;

  const _ScheduleSlotsSection({
    required this.studentId,
    required this.institutionId,
    this.canEdit = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // lesson_schedules (бесконечные)
    final schedulesAsync = ref.watch(lessonSchedulesByStudentProvider(studentId));
    final schedules = schedulesAsync.valueOrNull ?? [];

    // repeat_group_id серии (конечные)
    final repeatGroupsAsync = ref.watch(studentRepeatGroupsProvider(studentId));
    final repeatGroups = repeatGroupsAsync.valueOrNull ?? [];

    final isLoading = (schedulesAsync.isLoading && schedulesAsync.valueOrNull == null) ||
                      (repeatGroupsAsync.isLoading && repeatGroupsAsync.valueOrNull == null);

    // Разделяем на активные и неактивные (на паузе или архивированные)
    final activeSchedules = schedules.where((s) => !s.isPaused && s.archivedAt == null).toList();
    final inactiveSchedules = schedules.where((s) => s.isPaused || s.archivedAt != null).toList();

    // Все серии занятий считаются активными
    final activeRepeatGroups = repeatGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.permanentScheduleSection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _showAddScheduleSlotSheet(context, ref),
                tooltip: l10n.addScheduleSlot,
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Loading state (только при первой загрузке)
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          Builder(builder: (_) {
            if (activeSchedules.isEmpty && inactiveSchedules.isEmpty && activeRepeatGroups.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_repeat,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.noPermanentSchedule,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Бесконечные расписания (lesson_schedules)
                ...activeSchedules.map((schedule) => _LessonScheduleSlotCard(
                  schedule: schedule,
                  institutionId: institutionId,
                  canEdit: canEdit,
                )),

                // Серии занятий (repeat_group_id)
                ...activeRepeatGroups.map((group) => _RepeatGroupSlotCard(
                  group: group,
                  studentId: studentId,
                  institutionId: institutionId,
                  canEdit: canEdit,
                )),

                // Неактивные расписания в ExpansionTile
                if (inactiveSchedules.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      l10n.archiveSlots(inactiveSchedules.length),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    children: inactiveSchedules.map((schedule) => _LessonScheduleSlotCard(
                      schedule: schedule,
                      institutionId: institutionId,
                      canEdit: canEdit,
                      isInactive: true,
                    )).toList(),
                  ),
                ],
              ],
            );
          }),
        ],
      ],
    );
  }

  void _showAddScheduleSlotSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AddBookingSlotSheet(
        studentId: studentId,
        institutionId: institutionId,
      ),
    );
  }
}

/// Карточка слота постоянного расписания (lesson schedule)
class _LessonScheduleSlotCard extends ConsumerWidget {
  final LessonSchedule schedule;
  final String institutionId;
  final bool canEdit;
  final bool isInactive;

  const _LessonScheduleSlotCard({
    required this.schedule,
    required this.institutionId,
    this.canEdit = true,
    this.isInactive = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Используем цвет темы (цвет преподавателя хранится в InstitutionMember, не в Profile)
    final teacherColor = theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isInactive ? theme.colorScheme.surfaceContainerHighest : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canEdit ? () => _showSlotOptionsSheet(context, ref) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Day indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isInactive
                      ? theme.colorScheme.surfaceContainerHigh
                      : teacherColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      schedule.dayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isInactive
                            ? theme.colorScheme.onSurfaceVariant
                            : teacherColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Main info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time
                    Text(
                      schedule.timeRange,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isInactive
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Room
                    Row(
                      children: [
                        Icon(
                          Icons.meeting_room,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            schedule.room?.name ?? l10n.roomDefault,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Replacement indicator
                        if (schedule.hasReplacement) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '→ ${schedule.replacementRoom?.name ?? l10n.replacementRoom}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Teacher
                    if (schedule.teacher?.profile != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              schedule.teacher!.profile!.fullName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Status indicators
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (schedule.isPaused)
                    Tooltip(
                      message: schedule.pauseUntil != null
                          ? l10n.pauseUntilDateFormat(DateFormat('dd.MM').format(schedule.pauseUntil!))
                          : l10n.onPause,
                      child: Icon(
                        Icons.pause_circle,
                        size: 20,
                        color: Colors.orange.shade600,
                      ),
                    )
                  else if (isInactive)
                    const Icon(
                      Icons.archive,
                      size: 20,
                      color: AppColors.textSecondary,
                    )
                  else
                    Icon(
                      Icons.repeat,
                      size: 20,
                      color: teacherColor,
                    ),
                  if (canEdit)
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSlotOptionsSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          schedule.dayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${schedule.dayNameFull}, ${schedule.timeRange}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            schedule.room?.name ?? l10n.roomDefault,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Actions
              if (!isInactive) ...[
                // Edit
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(l10n.editAction),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditSheet(context, ref);
                  },
                ),

                // Pause/Resume
                if (schedule.isPaused)
                  ListTile(
                    leading: const Icon(Icons.play_arrow, color: Colors.green),
                    title: Text(l10n.resumeScheduleAction),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _resumeSchedule(context, ref);
                    },
                  )
                else
                  ListTile(
                    leading: Icon(Icons.pause, color: Colors.orange.shade600),
                    title: Text(l10n.pauseScheduleAction),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showPauseDialog(context, ref);
                    },
                  ),

                // Replacement room
                if (schedule.hasReplacement)
                  ListTile(
                    leading: const Icon(Icons.undo, color: AppColors.primary),
                    title: Text(l10n.clearReplacementRoom),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _clearReplacement(context, ref);
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.swap_horiz, color: AppColors.primary),
                    title: Text(l10n.temporaryRoomReplacementAction),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showReplacementDialog(context, ref);
                    },
                  ),

                // Archive
                ListTile(
                  leading: const Icon(Icons.archive, color: Colors.orange),
                  title: Text(l10n.archiveSchedule),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _archiveSchedule(context, ref);
                  },
                ),
              ] else ...[
                // Unarchive
                ListTile(
                  leading: const Icon(Icons.unarchive, color: Colors.green),
                  title: Text(l10n.unarchiveSchedule),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _unarchiveSchedule(context, ref);
                  },
                ),
              ],

              // Delete
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(l10n.deleteScheduleAction, style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteSchedule(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _EditLessonScheduleSheet(
        schedule: schedule,
        institutionId: institutionId,
      ),
    );
  }

  void _resumeSchedule(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(lessonScheduleControllerProvider.notifier);
    await controller.resume(schedule.id, schedule.institutionId, schedule.studentId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scheduleResumedMessage)),
      );
    }
  }

  void _showPauseDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    DateTime? pauseUntil;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.pauseScheduleTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.pauseScheduleUntilQuestion),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => pauseUntil = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.resumeDate,
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    pauseUntil != null
                        ? DateFormat('dd.MM.yyyy').format(pauseUntil!)
                        : l10n.selectDatePlaceholder,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: pauseUntil == null
                  ? null
                  : () async {
                      Navigator.pop(dialogContext);
                      final controller = ref.read(lessonScheduleControllerProvider.notifier);
                      await controller.pause(schedule.id, schedule.institutionId, schedule.studentId, until: pauseUntil);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.schedulePausedUntilMessage(DateFormat('dd.MM.yyyy').format(pauseUntil!)),
                            ),
                          ),
                        );
                      }
                    },
              child: Text(l10n.pauseAction),
            ),
          ],
        ),
      ),
    );
  }

  void _clearReplacement(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(lessonScheduleControllerProvider.notifier);
    await controller.clearReplacementRoom(schedule.id, schedule.institutionId, schedule.studentId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.replacementRoomCleared)),
      );
    }
  }

  void _showReplacementDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    String? selectedRoomId;
    DateTime? replacementUntil;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final roomsAsync = ref.watch(roomsStreamProvider(institutionId));

          return AlertDialog(
            title: Text(l10n.temporaryRoomReplacementTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Room dropdown
                roomsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text(l10n.errorFormat(e.toString())),
                  data: (rooms) => DropdownButtonFormField<String>(
                    key: ValueKey('tempRoom_$selectedRoomId'),
                    initialValue: selectedRoomId,
                    decoration: InputDecoration(labelText: l10n.newRoom),
                    items: rooms
                        .where((r) => r.id != schedule.roomId)
                        .map((r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(r.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => selectedRoomId = v),
                  ),
                ),
                const SizedBox(height: 16),

                // Date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => replacementUntil = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.untilDateLabel,
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      replacementUntil != null
                          ? DateFormat('dd.MM.yyyy').format(replacementUntil!)
                          : l10n.selectDatePlaceholder,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: selectedRoomId == null || replacementUntil == null
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);
                        final controller = ref.read(lessonScheduleControllerProvider.notifier);
                        await controller.setReplacementRoom(
                          schedule.id,
                          schedule.institutionId,
                          schedule.studentId,
                          selectedRoomId!,
                          until: replacementUntil,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.replacementRoomSet)),
                          );
                        }
                      },
                child: Text(l10n.apply),
              ),
            ],
          );
        },
      ),
    );
  }

  void _archiveSchedule(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.archiveScheduleQuestion),
        content: Text(l10n.archiveScheduleMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.archive),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(lessonScheduleControllerProvider.notifier);
      await controller.archive(schedule.id, schedule.institutionId, schedule.studentId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.scheduleArchivedMessage)),
        );
      }
    }
  }

  void _unarchiveSchedule(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(lessonScheduleControllerProvider.notifier);
    await controller.restore(schedule.id, schedule.institutionId, schedule.studentId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scheduleUnarchivedMessage)),
      );
    }
  }

  void _deleteSchedule(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteScheduleQuestion),
        content: Text(l10n.deleteScheduleMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(lessonScheduleControllerProvider.notifier);
      await controller.delete(schedule.id, schedule.institutionId, schedule.studentId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.scheduleDeletedMessage)),
        );
      }
    }
  }
}

/// Карточка серии занятий (repeat_group_id)
class _RepeatGroupSlotCard extends ConsumerWidget {
  final Map<String, dynamic> group;
  final String studentId;
  final String institutionId;
  final bool canEdit;

  const _RepeatGroupSlotCard({
    required this.group,
    required this.studentId,
    required this.institutionId,
    this.canEdit = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final groupColor = theme.colorScheme.secondary;

    // Получаем данные из первого занятия серии
    final dateStr = group['date'] as String?;
    final startTimeStr = group['start_time'] as String?;
    final endTimeStr = group['end_time'] as String?;
    final roomData = group['rooms'] as Map<String, dynamic>?;
    final lessonsCount = group['lessons_count'] as int? ?? 1;

    // Парсим дату для получения дня недели
    DateTime? date;
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr);
    }

    // Форматируем время
    String timeRange = '';
    if (startTimeStr != null && endTimeStr != null) {
      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');
      if (startParts.length >= 2 && endParts.length >= 2) {
        timeRange = '${startParts[0]}:${startParts[1]} - ${endParts[0]}:${endParts[1]}';
      }
    }

    // Получаем название дня недели
    String dayName = '';
    if (date != null) {
      final days = [l10n.mondayShort2, l10n.tuesdayShort2, l10n.wednesdayShort2, l10n.thursdayShort2, l10n.fridayShort2, l10n.saturdayShort2, l10n.sundayShort2];
      dayName = days[date.weekday - 1];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canEdit ? () => _showOptionsSheet(context, ref) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Day indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: groupColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: groupColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Main info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time
                    Text(
                      timeRange,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Room
                    Row(
                      children: [
                        Icon(
                          Icons.meeting_room,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            roomData?['name'] ?? l10n.roomDefault,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Lessons count badge
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: groupColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${lessonsCount}x',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: groupColor,
                      ),
                    ),
                  ),
                  if (canEdit)
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lessonsCount = group['lessons_count'] as int? ?? 1;
    final dateStr = group['date'] as String?;
    final startTimeStr = group['start_time'] as String?;
    final endTimeStr = group['end_time'] as String?;
    final roomData = group['rooms'] as Map<String, dynamic>?;
    final repeatGroupId = group['repeat_group_id'] as String?;

    // Парсим дату
    DateTime? date;
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr);
    }

    // Форматируем время
    String timeRange = '';
    if (startTimeStr != null && endTimeStr != null) {
      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');
      if (startParts.length >= 2 && endParts.length >= 2) {
        timeRange = '${startParts[0]}:${startParts[1]} - ${endParts[0]}:${endParts[1]}';
      }
    }

    // День недели
    String dayNameFull = '';
    if (date != null) {
      final daysFull = [l10n.mondayFull, l10n.tuesdayFull, l10n.wednesdayFull, l10n.thursdayFull, l10n.fridayFull, l10n.saturdayFull, l10n.sundayFull];
      dayNameFull = daysFull[date.weekday - 1];
    }

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${lessonsCount}x',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$dayNameFull, $timeRange',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            roomData?['name'] ?? l10n.roomDefault,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Info
              ListTile(
                leading: Icon(
                  Icons.event,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(l10n.lessonsInSeries(lessonsCount)),
              ),
              if (date != null)
                ListTile(
                  leading: Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(l10n.seriesStartDate(DateFormat('dd.MM.yyyy').format(date))),
                ),

              const Divider(height: 1),

              // Edit action
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.editAction),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditSheet(context, ref);
                },
              ),

              // Delete action
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(l10n.deleteSeriesAction, style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context, ref, repeatGroupId, lessonsCount);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final repeatGroupId = group['repeat_group_id'] as String?;
    if (repeatGroupId == null) return;

    final startTimeStr = group['start_time'] as String?;
    final endTimeStr = group['end_time'] as String?;
    final roomData = group['rooms'] as Map<String, dynamic>?;
    final currentRoomId = roomData?['id'] as String?;

    // Парсим текущее время
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    if (startTimeStr != null) {
      final parts = startTimeStr.split(':');
      if (parts.length >= 2) {
        startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
    if (endTimeStr != null) {
      final parts = endTimeStr.split(':');
      if (parts.length >= 2) {
        endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _EditRepeatGroupSheet(
        repeatGroupId: repeatGroupId,
        studentId: studentId,
        institutionId: institutionId,
        initialStartTime: startTime ?? const TimeOfDay(hour: 12, minute: 0),
        initialEndTime: endTime ?? const TimeOfDay(hour: 13, minute: 0),
        initialRoomId: currentRoomId,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String? repeatGroupId, int lessonsCount) async {
    final l10n = AppLocalizations.of(context);
    if (repeatGroupId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteSeriesQuestion),
        content: Text(l10n.deleteSeriesMessage(lessonsCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(lessonControllerProvider.notifier);
      final success = await controller.deleteRepeatGroup(
        repeatGroupId,
        institutionId,
        studentId: studentId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? l10n.seriesDeleted : l10n.deletionError),
          ),
        );
      }
    }
  }
}

/// Форма редактирования серии занятий
class _EditRepeatGroupSheet extends ConsumerStatefulWidget {
  final String repeatGroupId;
  final String studentId;
  final String institutionId;
  final TimeOfDay initialStartTime;
  final TimeOfDay initialEndTime;
  final String? initialRoomId;

  const _EditRepeatGroupSheet({
    required this.repeatGroupId,
    required this.studentId,
    required this.institutionId,
    required this.initialStartTime,
    required this.initialEndTime,
    this.initialRoomId,
  });

  @override
  ConsumerState<_EditRepeatGroupSheet> createState() => _EditRepeatGroupSheetState();
}

class _EditRepeatGroupSheetState extends ConsumerState<_EditRepeatGroupSheet> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String? _roomId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
    _roomId = widget.initialRoomId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final roomsAsync = ref.watch(roomsStreamProvider(widget.institutionId));
    final rooms = roomsAsync.valueOrNull ?? [];

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.edit_calendar),
                    const SizedBox(width: 8),
                    Text(
                      l10n.editSeriesSheetTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Start time
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(l10n.startTimeLabel),
                  subtitle: Text(
                    '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectStartTime(context),
                ),

                // End time
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_filled),
                  title: Text(l10n.endTimeLabel),
                  subtitle: Text(
                    '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectEndTime(context),
                ),

                const SizedBox(height: 8),

                // Room dropdown
                DropdownButtonFormField<String>(
                  value: _roomId,
                  decoration: InputDecoration(
                    labelText: l10n.roomFieldLabel,
                    prefixIcon: const Icon(Icons.meeting_room),
                    border: const OutlineInputBorder(),
                  ),
                  items: rooms.map((room) {
                    return DropdownMenuItem(
                      value: room.id,
                      child: Text(room.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _roomId = value);
                  },
                ),

                const SizedBox(height: 24),

                // Save button
                FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final picked = await showIosTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final picked = await showIosTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    final controller = ref.read(lessonControllerProvider.notifier);
    final success = await controller.updateRepeatGroup(
      widget.repeatGroupId,
      widget.institutionId,
      studentId: widget.studentId,
      startTime: _startTime,
      endTime: _endTime,
      roomId: _roomId,
    );

    setState(() => _isLoading = false);

    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.seriesUpdated)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.updateError)),
        );
      }
    }
  }
}

/// Форма редактирования постоянного расписания (lesson_schedule)
class _EditLessonScheduleSheet extends ConsumerStatefulWidget {
  final LessonSchedule schedule;
  final String institutionId;

  const _EditLessonScheduleSheet({
    required this.schedule,
    required this.institutionId,
  });

  @override
  ConsumerState<_EditLessonScheduleSheet> createState() => _EditLessonScheduleSheetState();
}

class _EditLessonScheduleSheetState extends ConsumerState<_EditLessonScheduleSheet> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String? _roomId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTime = widget.schedule.startTime;
    _endTime = widget.schedule.endTime;
    _roomId = widget.schedule.roomId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final roomsAsync = ref.watch(roomsStreamProvider(widget.institutionId));
    final rooms = roomsAsync.valueOrNull ?? [];

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          widget.schedule.dayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.editScheduleTitle,
                            style: theme.textTheme.titleLarge,
                          ),
                          Text(
                            widget.schedule.dayNameFull,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Start time
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(l10n.startTimeLabel),
                  subtitle: Text(
                    '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectStartTime(context),
                ),

                // End time
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_filled),
                  title: Text(l10n.endTimeLabel),
                  subtitle: Text(
                    '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectEndTime(context),
                ),

                const SizedBox(height: 8),

                // Room dropdown
                DropdownButtonFormField<String>(
                  value: _roomId,
                  decoration: InputDecoration(
                    labelText: l10n.roomFieldLabel,
                    prefixIcon: const Icon(Icons.meeting_room),
                    border: const OutlineInputBorder(),
                  ),
                  items: rooms.map((room) {
                    return DropdownMenuItem(
                      value: room.id,
                      child: Text(room.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _roomId = value);
                  },
                ),

                const SizedBox(height: 24),

                // Save button
                FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final picked = await showIosTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final picked = await showIosTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    try {
      final controller = ref.read(lessonScheduleControllerProvider.notifier);
      final result = await controller.update(
        widget.schedule.id,
        institutionId: widget.institutionId,
        startTime: _startTime,
        endTime: _endTime,
        roomId: _roomId,
      );

      setState(() => _isLoading = false);

      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        if (result != null) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.scheduleUpdatedMessage)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.scheduleUpdateError)),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorFormat(e.toString()))),
        );
      }
    }
  }
}

/// Форма создания занятий из постоянного расписания
class _CreateLessonsFromScheduleSheet extends ConsumerStatefulWidget {
  final String studentId;
  final String institutionId;

  const _CreateLessonsFromScheduleSheet({
    required this.studentId,
    required this.institutionId,
  });

  @override
  ConsumerState<_CreateLessonsFromScheduleSheet> createState() =>
      _CreateLessonsFromScheduleSheetState();
}

class _CreateLessonsFromScheduleSheetState
    extends ConsumerState<_CreateLessonsFromScheduleSheet> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;
  List<ScheduleConflict> _conflicts = [];
  bool _hasCheckedConflicts = false;
  late AppLocalizations l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок
                Row(
                  children: [
                    Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.createLessonsFromScheduleTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Описание
                Text(
                  l10n.createLessonsFromScheduleDescription,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),

                // Период
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: l10n.fromDateLabel,
                        value: _startDate,
                        onChanged: (date) {
                          setState(() {
                            _startDate = date;
                            _hasCheckedConflicts = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DatePickerField(
                        label: l10n.toDateLabel,
                        value: _endDate,
                        onChanged: (date) {
                          setState(() {
                            _endDate = date;
                            _hasCheckedConflicts = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Быстрый выбор периода
                Wrap(
                  spacing: 8,
                  children: [
                    _PeriodChip(
                      label: l10n.oneWeek,
                      onTap: () => _setEndDate(7),
                    ),
                    _PeriodChip(
                      label: l10n.twoWeeks,
                      onTap: () => _setEndDate(14),
                    ),
                    _PeriodChip(
                      label: l10n.oneMonth,
                      onTap: () => _setEndDate(30),
                    ),
                    _PeriodChip(
                      label: l10n.threeMonths,
                      onTap: () => _setEndDate(90),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Кнопка проверки конфликтов
                if (!_hasCheckedConflicts)
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _checkConflicts,
                    icon: const Icon(Icons.search),
                    label: Text(l10n.checkConflictsAction),
                  ),

                // Результаты проверки
                if (_hasCheckedConflicts) ...[
                  if (_conflicts.isEmpty)
                    Card(
                      color: AppColors.success.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(l10n.noConflictsFound),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning, color: AppColors.warning),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.foundConflictsCount(_conflicts.length),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.theseDatesWillBeSkipped,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: _conflicts.take(10).map((c) {
                                return Chip(
                                  label: Text(
                                    '${c.conflictDate.day}.${c.conflictDate.month}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                            if (_conflicts.length > 10)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  l10n.andMore(_conflicts.length - 10),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Кнопка создания
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _createLessons,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isLoading ? l10n.creatingMessage : l10n.createLessonsAction),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setEndDate(int days) {
    setState(() {
      _endDate = _startDate.add(Duration(days: days));
      _hasCheckedConflicts = false;
    });
  }

  Future<void> _checkConflicts() async {
    setState(() => _isLoading = true);
    try {
      final controller = ref.read(bookingControllerProvider.notifier);
      final conflicts = await controller.checkScheduleConflicts(
        studentId: widget.studentId,
        startDate: _startDate,
        endDate: _endDate,
      );
      setState(() {
        _conflicts = conflicts;
        _hasCheckedConflicts = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createLessons() async {
    setState(() => _isLoading = true);
    try {
      final controller = ref.read(bookingControllerProvider.notifier);
      final result = await controller.createLessonsFromSchedule(
        studentId: widget.studentId,
        institutionId: widget.institutionId,
        startDate: _startDate,
        endDate: _endDate,
        skipConflicts: true,
      );

      if (mounted && result != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.skippedCount > 0
                  ? l10n.lessonsCreatedSkippedCount(result.successCount, result.skippedCount)
                  : l10n.lessonsCreatedResult(result.successCount),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorWithParam(e.toString())), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now().subtract(const Duration(days: 7)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) onChanged(date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          '${value.day}.${value.month.toString().padLeft(2, '0')}.${value.year}',
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}

/// Форма добавления нового слота постоянного расписания занятий (lesson_schedules).
/// Создаёт виртуальные занятия, которые отображаются на каждую соответствующую дату.
/// Реальное занятие создаётся только при проведении или отмене.
class _AddBookingSlotSheet extends ConsumerStatefulWidget {
  final String studentId;
  final String institutionId;

  const _AddBookingSlotSheet({
    required this.studentId,
    required this.institutionId,
  });

  @override
  ConsumerState<_AddBookingSlotSheet> createState() => _AddBookingSlotSheetState();
}

class _AddBookingSlotSheetState extends ConsumerState<_AddBookingSlotSheet> {
  final _formKey = GlobalKey<FormState>();

  // Выбранные дни недели (для batch создания)
  final Set<int> _selectedDays = {};

  // Время для каждого дня
  final Map<int, TimeOfDay> _startTimes = {};
  final Map<int, TimeOfDay> _endTimes = {};

  // Кабинет для каждого дня (индивидуальный выбор)
  final Map<int, String?> _roomIds = {};

  String? _selectedTeacherId;
  String? _selectedSubjectId;
  String? _selectedLessonTypeId;

  bool _isSubmitting = false;
  bool _bindingsLoaded = false;

  // Проверка конфликтов
  bool _isCheckingConflicts = false;
  final Set<int> _conflictingDays = {}; // Дни с конфликтами

  // Дата начала действия расписания
  DateTime _validFrom = DateTime.now();

  static const _defaultStartTime = TimeOfDay(hour: 14, minute: 0);
  static const _defaultEndTime = TimeOfDay(hour: 15, minute: 0);

  @override
  void initState() {
    super.initState();
    // Отложенная загрузка привязок ученика для автозаполнения
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentBindings();
    });
  }

  /// Загружает привязки ученика и автозаполняет поля
  Future<void> _loadStudentBindings() async {
    if (_bindingsLoaded) return;

    // Преподаватели ученика
    final teachersAsync = ref.read(studentTeachersProvider(widget.studentId));
    final teachers = teachersAsync.valueOrNull ?? [];
    if (teachers.length == 1 && _selectedTeacherId == null) {
      setState(() => _selectedTeacherId = teachers.first.userId);
    }

    // Предметы ученика
    final subjectsAsync = ref.read(studentSubjectsProvider(widget.studentId));
    final subjects = subjectsAsync.valueOrNull ?? [];
    if (subjects.length == 1 && _selectedSubjectId == null) {
      setState(() => _selectedSubjectId = subjects.first.subjectId);
    }

    // Типы занятий ученика
    final lessonTypesAsync = ref.read(studentLessonTypesProvider(widget.studentId));
    final lessonTypes = lessonTypesAsync.valueOrNull ?? [];
    if (lessonTypes.length == 1 && _selectedLessonTypeId == null) {
      setState(() => _selectedLessonTypeId = lessonTypes.first.lessonTypeId);
    }

    _bindingsLoaded = true;
  }

  /// Проверяет конфликты для всех выбранных дней
  /// Проверяет: 1) другие повторяющиеся бронирования, 2) ВСЕ будущие занятия
  Future<void> _checkConflicts() async {
    if (_selectedDays.isEmpty) {
      setState(() {
        _conflictingDays.clear();
        _isCheckingConflicts = false;
      });
      return;
    }

    setState(() => _isCheckingConflicts = true);

    final repo = ref.read(bookingRepositoryProvider);
    final newConflicts = <int>{};

    for (final day in _selectedDays) {
      final roomId = _roomIds[day];
      // Пропускаем проверку если кабинет не выбран для этого дня
      if (roomId == null) continue;

      final startTime = _startTimes[day] ?? _defaultStartTime;
      final endTime = _endTimes[day] ?? _defaultEndTime;

      // 1. Проверяем конфликт с другими повторяющимися бронированиями
      final hasBookingConflict = await repo.hasWeeklyConflict(
        roomId: roomId,
        dayOfWeek: day,
        startTime: startTime,
        endTime: endTime,
      );

      if (hasBookingConflict) {
        newConflicts.add(day);
        continue; // Уже конфликт — не нужно проверять занятия
      }

      // 2. Проверяем конфликт с ВСЕМИ будущими занятиями для этого дня недели
      final hasLessonConflict = await repo.hasLessonConflictForDayOfWeek(
        roomId: roomId,
        dayOfWeek: day,
        startTime: startTime,
        endTime: endTime,
        studentId: widget.studentId, // Исключаем занятия этого ученика
      );

      if (hasLessonConflict) {
        newConflicts.add(day);
      }
    }

    if (mounted) {
      setState(() {
        _conflictingDays.clear();
        _conflictingDays.addAll(newConflicts);
        _isCheckingConflicts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roomsAsync = ref.watch(roomsStreamProvider(widget.institutionId));
    final membersAsync = ref.watch(membersStreamProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsListProvider(widget.institutionId));
    final lessonTypesAsync = ref.watch(lessonTypesProvider(widget.institutionId));
    final currentUserId = ref.watch(currentUserIdProvider);

    // Привязки ученика для автозаполнения
    final studentTeachersAsync = ref.watch(studentTeachersProvider(widget.studentId));
    final studentSubjectsAsync = ref.watch(studentSubjectsProvider(widget.studentId));
    final studentLessonTypesAsync = ref.watch(studentLessonTypesProvider(widget.studentId));

    final studentTeachers = studentTeachersAsync.valueOrNull ?? [];
    final studentSubjects = studentSubjectsAsync.valueOrNull ?? [];
    final studentLessonTypes = studentLessonTypesAsync.valueOrNull ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Text(
                l10n.addPermanentScheduleTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.addPermanentScheduleDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Days of week selection
              Text(
                l10n.daysOfWeek,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _buildDaysSelector(),
              const SizedBox(height: 16),

              // Time for each selected day with individual room selection
              if (_selectedDays.isNotEmpty) ...[
                Text(
                  l10n.timeAndRoomsLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                roomsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(l10n.errorWithParam(e.toString())),
                  data: (rooms) => Column(
                    children: _buildDayTimeRows(rooms),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Дата начала действия расписания
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _validFrom,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    locale: const Locale('ru', 'RU'),
                  );
                  if (picked != null && mounted) {
                    setState(() => _validFrom = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.validFromLabel,
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  child: Text(
                    '${_validFrom.day.toString().padLeft(2, '0')}.${_validFrom.month.toString().padLeft(2, '0')}.${_validFrom.year}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Teacher dropdown (приоритет привязанным преподавателям)
              membersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(l10n.errorWithParam(e.toString())),
                data: (members) {
                  // Если преподаватель не выбран
                  if (_selectedTeacherId == null && members.isNotEmpty) {
                    // Сначала пробуем привязанного преподавателя
                    if (studentTeachers.length == 1) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _selectedTeacherId == null) {
                          setState(() => _selectedTeacherId = studentTeachers.first.userId);
                        }
                      });
                    } else {
                      // Иначе текущего пользователя
                      final currentMember = members.firstWhere(
                        (m) => m.userId == currentUserId,
                        orElse: () => members.first,
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _selectedTeacherId == null) {
                          setState(() => _selectedTeacherId = currentMember.userId);
                        }
                      });
                    }
                  }

                  // Сортируем: сначала привязанные преподаватели
                  final bindingUserIds = studentTeachers.map((t) => t.userId).toSet();
                  final sortedMembers = [...members]..sort((a, b) {
                    final aIsBound = bindingUserIds.contains(a.userId) ? 0 : 1;
                    final bIsBound = bindingUserIds.contains(b.userId) ? 0 : 1;
                    return aIsBound.compareTo(bIsBound);
                  });

                  return DropdownButtonFormField<String>(
                    key: ValueKey('teacher_$_selectedTeacherId'),
                    initialValue: _selectedTeacherId,
                    decoration: InputDecoration(
                      labelText: l10n.teacherRequiredLabel,
                      prefixIcon: const Icon(Icons.person),
                    ),
                    items: sortedMembers
                        .map((m) => DropdownMenuItem(
                              value: m.userId,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (bindingUserIds.contains(m.userId))
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  Flexible(
                                    child: Text(
                                      m.profile?.fullName ?? l10n.teacherDefault,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTeacherId = v),
                    validator: (v) => v == null ? l10n.selectTeacherError : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Subject dropdown (приоритет привязанным предметам)
              subjectsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (subjects) {
                  if (subjects.isEmpty) return const SizedBox.shrink();

                  // Автоматически выбираем если один привязанный предмет
                  if (_selectedSubjectId == null && studentSubjects.length == 1) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _selectedSubjectId == null) {
                        setState(() => _selectedSubjectId = studentSubjects.first.subjectId);
                      }
                    });
                  }

                  // Сортируем: сначала привязанные предметы
                  final bindingSubjectIds = studentSubjects.map((s) => s.subjectId).toSet();
                  final sortedSubjects = [...subjects]..sort((a, b) {
                    final aIsBound = bindingSubjectIds.contains(a.id) ? 0 : 1;
                    final bIsBound = bindingSubjectIds.contains(b.id) ? 0 : 1;
                    return aIsBound.compareTo(bIsBound);
                  });

                  return DropdownButtonFormField<String>(
                    key: ValueKey('subject_$_selectedSubjectId'),
                    initialValue: _selectedSubjectId,
                    decoration: InputDecoration(
                      labelText: l10n.subjectOptionalLabel,
                      prefixIcon: const Icon(Icons.book),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.notSpecifiedLabel)),
                      ...sortedSubjects.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (bindingSubjectIds.contains(s.id))
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            Flexible(
                              child: Text(s.name, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      )),
                    ],
                    onChanged: (v) => setState(() => _selectedSubjectId = v),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Lesson type dropdown (приоритет привязанным типам)
              lessonTypesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (types) {
                  if (types.isEmpty) return const SizedBox.shrink();

                  // Автоматически выбираем если один привязанный тип
                  if (_selectedLessonTypeId == null && studentLessonTypes.length == 1) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _selectedLessonTypeId == null) {
                        setState(() => _selectedLessonTypeId = studentLessonTypes.first.lessonTypeId);
                      }
                    });
                  }

                  // Сортируем: сначала привязанные типы
                  final bindingTypeIds = studentLessonTypes.map((t) => t.lessonTypeId).toSet();
                  final sortedTypes = [...types]..sort((a, b) {
                    final aIsBound = bindingTypeIds.contains(a.id) ? 0 : 1;
                    final bIsBound = bindingTypeIds.contains(b.id) ? 0 : 1;
                    return aIsBound.compareTo(bIsBound);
                  });

                  return DropdownButtonFormField<String>(
                    key: ValueKey('lessonType_$_selectedLessonTypeId'),
                    initialValue: _selectedLessonTypeId,
                    decoration: InputDecoration(
                      labelText: l10n.lessonTypeOptionalLabel,
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.notSpecifiedLabel)),
                      ...sortedTypes.map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (bindingTypeIds.contains(t.id))
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            Flexible(
                              child: Text(t.name, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      )),
                    ],
                    onChanged: (v) => setState(() => _selectedLessonTypeId = v),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Статус проверки конфликтов
              if (_isCheckingConflicts)
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.checkingConflictsLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                )
              else if (_conflictingDays.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.conflictsChangeTime(_conflictingDays.length),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Submit button
              Builder(builder: (context) {
                final hasAllRooms = _selectedDays.isNotEmpty &&
                    _selectedDays.every((day) => _roomIds[day] != null);
                final canSubmit = _selectedDays.isNotEmpty &&
                    hasAllRooms &&
                    !_isSubmitting &&
                    !_isCheckingConflicts &&
                    _conflictingDays.isEmpty;

                return ElevatedButton.icon(
                  onPressed: canSubmit ? _submit : null,
                  icon: _isSubmitting || _isCheckingConflicts
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(
                    _isCheckingConflicts
                        ? l10n.checkingLabel
                        : _conflictingDays.isNotEmpty
                            ? l10n.hasConflictsError
                            : !hasAllRooms && _selectedDays.isNotEmpty
                                ? l10n.selectRoomsError
                                : _selectedDays.length > 1
                                    ? l10n.createCountSchedules(_selectedDays.length)
                                    : l10n.createScheduleLabel,
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaysSelector() {
    final l10n = AppLocalizations.of(context);
    final days = [l10n.mondayShort2, l10n.tuesdayShort2, l10n.wednesdayShort2, l10n.thursdayShort2, l10n.fridayShort2, l10n.saturdayShort2, l10n.sundayShort2];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (index) {
        final dayNumber = index + 1; // 1-7
        final isSelected = _selectedDays.contains(dayNumber);

        return FilterChip(
          label: Text(days[index]),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedDays.add(dayNumber);
                _startTimes[dayNumber] = _defaultStartTime;
                _endTimes[dayNumber] = _defaultEndTime;
              } else {
                _selectedDays.remove(dayNumber);
                _startTimes.remove(dayNumber);
                _endTimes.remove(dayNumber);
                _roomIds.remove(dayNumber);
                _conflictingDays.remove(dayNumber);
              }
            });
            _checkConflicts();
          },
        );
      }),
    );
  }

  List<Widget> _buildDayTimeRows(List<Room> rooms) {
    final sortedDays = _selectedDays.toList()..sort();
    return sortedDays.map((day) => _buildDayTimeRow(day, rooms)).toList();
  }

  Widget _buildDayTimeRow(int dayNumber, List<Room> rooms) {
    final l10n = AppLocalizations.of(context);
    final days = ['', l10n.mondayShort2, l10n.tuesdayShort2, l10n.wednesdayShort2, l10n.thursdayShort2, l10n.fridayShort2, l10n.saturdayShort2, l10n.sundayShort2];
    final startTime = _startTimes[dayNumber] ?? _defaultStartTime;
    final endTime = _endTimes[dayNumber] ?? _defaultEndTime;
    final hasConflict = _conflictingDays.contains(dayNumber);
    final selectedRoom = _roomIds[dayNumber];

    // Расчёт длительности
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    final durationText = durationMinutes > 0
        ? (durationMinutes >= 60
            ? l10n.durationFormat(durationMinutes ~/ 60, durationMinutes % 60)
            : l10n.minutesOnly(durationMinutes))
        : l10n.invalidTimeError;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasConflict
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Day label
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasConflict
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  days[dayNumber],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hasConflict
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Time range (tappable)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _pickTimeRange(dayNumber),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_formatTime(startTime)} — ${_formatTime(endTime)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasConflict ? l10n.conflictTimeOccupiedMessage : durationText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: hasConflict
                            ? Theme.of(context).colorScheme.error
                            : (durationMinutes > 0
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Room dropdown
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 120),
              child: DropdownButton<String>(
                value: selectedRoom,
                hint: Text(
                  l10n.roomLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                isExpanded: true,
                underline: const SizedBox.shrink(),
                icon: Icon(
                  Icons.meeting_room_outlined,
                  size: 18,
                  color: selectedRoom != null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                selectedItemBuilder: (context) => rooms.map<Widget>((r) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      r.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                items: rooms.map<DropdownMenuItem<String>>((r) => DropdownMenuItem<String>(
                  value: r.id,
                  child: Text(r.name),
                )).toList(),
                onChanged: (v) {
                  setState(() => _roomIds[dayNumber] = v);
                  _checkConflicts();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Открывает iOS-style пикер диапазона времени
  Future<void> _pickTimeRange(int dayNumber) async {
    final currentStart = _startTimes[dayNumber] ?? _defaultStartTime;
    final currentEnd = _endTimes[dayNumber] ?? _defaultEndTime;

    final result = await showIosTimeRangePicker(
      context: context,
      initialStartTime: currentStart,
      initialEndTime: currentEnd,
      minuteInterval: 5,
      minHour: 6,
      maxHour: 23,
    );

    if (result != null && mounted) {
      setState(() {
        _startTimes[dayNumber] = result.start;
        _endTimes[dayNumber] = result.end;
      });
      _checkConflicts();
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectAtLeastOneDay)),
      );
      return;
    }

    // Проверяем что для всех дней выбраны кабинеты
    final daysWithoutRoom = _selectedDays.where((day) => _roomIds[day] == null).toList();
    if (daysWithoutRoom.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectRoomForEachDay)),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final scheduleController = ref.read(lessonScheduleControllerProvider.notifier);

      // Создаём lesson_schedule записи (виртуальные занятия)
      if (_selectedDays.length == 1) {
        final day = _selectedDays.first;
        await scheduleController.create(
          institutionId: widget.institutionId,
          roomId: _roomIds[day]!,
          teacherId: _selectedTeacherId!,
          studentId: widget.studentId,
          subjectId: _selectedSubjectId,
          lessonTypeId: _selectedLessonTypeId,
          dayOfWeek: day,
          startTime: _startTimes[day]!,
          endTime: _endTimes[day]!,
          validFrom: _validFrom,
        );
      } else {
        final slots = _selectedDays.map((day) => DayTimeSlot(
          dayOfWeek: day,
          startTime: _startTimes[day]!,
          endTime: _endTimes[day]!,
          roomId: _roomIds[day],
        )).toList();

        await scheduleController.createBatch(
          institutionId: widget.institutionId,
          roomId: _roomIds[_selectedDays.first]!, // Fallback, но каждый slot имеет свой roomId
          teacherId: _selectedTeacherId!,
          studentId: widget.studentId,
          subjectId: _selectedSubjectId,
          lessonTypeId: _selectedLessonTypeId,
          slots: slots,
          validFrom: _validFrom,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedDays.length == 1
                  ? l10n.scheduleCreatedMessage
                  : l10n.schedulesCreatedMessage(_selectedDays.length),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithParam(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

/// BottomSheet для массового управления занятиями ученика
class _BulkLessonActionsSheet extends ConsumerStatefulWidget {
  final Student student;
  final String institutionId;
  final VoidCallback onCompleted;

  const _BulkLessonActionsSheet({
    required this.student,
    required this.institutionId,
    required this.onCompleted,
  });

  @override
  ConsumerState<_BulkLessonActionsSheet> createState() => _BulkLessonActionsSheetState();
}

class _BulkLessonActionsSheetState extends ConsumerState<_BulkLessonActionsSheet> {
  List<Lesson>? _futureLessons;
  List<Booking>? _scheduleSlots;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _loadError;
  late AppLocalizations l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final lessonRepo = ref.read(lessonRepositoryProvider);
      final bookingRepo = ref.read(bookingRepositoryProvider);

      // Загружаем параллельно
      final results = await Future.wait([
        lessonRepo.getFutureLessonsForStudent(widget.student.id),
        bookingRepo.getByStudent(widget.student.id),
      ]);

      if (mounted) {
        setState(() {
          _futureLessons = results[0] as List<Lesson>;
          _scheduleSlots = (results[1] as List<Booking>)
              .where((b) => b.archivedAt == null && b.isRecurring)
              .toList();
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading data for ${widget.student.id}: $e');
      if (mounted) {
        setState(() {
          _futureLessons = [];
          _scheduleSlots = [];
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _deleteFutureLessons() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAllLessonsQuestion),
        content: Text(
          l10n.deleteAllLessonsConfirm(_futureLessons!.length, widget.student.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(lessonRepositoryProvider);
      final count = await repo.deleteFutureLessonsForStudent(widget.student.id);

      if (mounted) {
        Navigator.pop(context);
        widget.onCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deletedCountLessons(count))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithParam(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showReassignDialog() async {
    // Получаем список преподавателей
    final members = ref.read(membersProvider(widget.institutionId)).valueOrNull ?? [];
    final teachers = members.toList();

    if (teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noAvailableTeachersError)),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReassignTeacherSheet(
        teachers: teachers,
        lessons: _futureLessons!,
        institutionId: widget.institutionId,
        onReassigned: () {
          Navigator.pop(context); // Закрываем sheet выбора
          Navigator.pop(context); // Закрываем основной sheet
          widget.onCompleted();
        },
      ),
    );
  }

  Future<void> _showReassignSlotsDialog() async {
    // Получаем список преподавателей
    final members = ref.read(membersProvider(widget.institutionId)).valueOrNull ?? [];
    final teachers = members.toList();

    if (teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noAvailableTeachersError)),
      );
      return;
    }

    final selectedTeacherId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.selectTeacherLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...teachers.map((member) => ListTile(
              leading: CircleAvatar(
                backgroundColor: member.color != null
                    ? Color(int.parse('FF${member.color}', radix: 16))
                    : AppColors.primary,
                child: Text(
                  member.profile?.fullName.substring(0, 1).toUpperCase() ?? '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(member.profile?.fullName ?? l10n.noNameLabel),
              onTap: () => Navigator.pop(context, member.userId),
            )),
          ],
        ),
      ),
    );

    if (selectedTeacherId == null) return;

    setState(() => _isProcessing = true);

    try {
      final controller = ref.read(bookingControllerProvider.notifier);

      // TODO: Implement reassignTeacher in BookingController
      // For now, we'll update each slot individually
      for (final slot in _scheduleSlots!) {
        await controller.updateRecurring(
          slot.id,
          institutionId: widget.institutionId,
          teacherId: selectedTeacherId,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reassignedSlotsMessage(_scheduleSlots!.length))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithParam(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pauseAllSlots() async {
    // Выбираем дату до которой приостановить
    final pauseUntil = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: l10n.pauseUntilMessage,
    );

    if (pauseUntil == null) return;

    setState(() => _isProcessing = true);

    try {
      final controller = ref.read(bookingControllerProvider.notifier);

      for (final slot in _scheduleSlots!) {
        await controller.pause(
          slot.id,
          widget.institutionId,
          pauseUntil,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pausedSlotsMessage(_scheduleSlots!.length))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithParam(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _deactivateAllSlots() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deactivateScheduleQuestion),
        content: Text(
          l10n.deactivateScheduleConfirm(_scheduleSlots!.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(l10n.deactivateAction),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final controller = ref.read(bookingControllerProvider.notifier);

      for (final slot in _scheduleSlots!) {
        await controller.archive(
          slot.id,
          widget.institutionId,
          widget.student.id,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deactivatedSlotsMessage(_scheduleSlots!.length))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithParam(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  String _getSlotWord(int count) {
    if (count == 1) return l10n.slotWord;
    if (count >= 2 && count <= 4) return l10n.slotsWordFew;
    return l10n.slotsWordMany;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Заголовок
              Text(
                l10n.manageLessonsHeader,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.student.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Статистика
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_loadError != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.loadingErrorLabel(_loadError!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_futureLessons!.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.noScheduledLessonsLabel),
                      ),
                    ],
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_note,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.foundFutureLessons(_futureLessons!.length),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Кнопки действий
                if (_isProcessing)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  // Переназначить преподавателя
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.swap_horiz, color: Colors.white),
                    ),
                    title: Text(l10n.reassignTeacher),
                    subtitle: Text(l10n.reassignTeacherSubtitleLabel),
                    onTap: _showReassignDialog,
                  ),
                  const Divider(),

                  // Удалить все занятия
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Icon(Icons.delete_sweep, color: Colors.white),
                    ),
                    title: Text(
                      l10n.deleteAllLessonsLabel,
                      style: const TextStyle(color: Colors.red),
                    ),
                    subtitle: Text(l10n.subscriptionBalanceWontChange),
                    onTap: _deleteFutureLessons,
                  ),
                ],
              ],

              // Секция постоянного расписания
              if (_scheduleSlots != null && _scheduleSlots!.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Заголовок секции
                Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.permanentScheduleLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Инфо о слотах
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.slotsCountLabel(_scheduleSlots!.length, _getSlotWord(_scheduleSlots!.length)),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _scheduleSlots!.map((s) => '${s.dayName} ${s.timeRange}').join(', '),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Кнопки действий для слотов
                if (!_isProcessing) ...[
                  // Переназначить преподавателя
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      child: const Icon(Icons.swap_horiz, color: Colors.white),
                    ),
                    title: Text(l10n.reassignTeacher),
                    subtitle: Text(l10n.forAllScheduleSlots),
                    onTap: _showReassignSlotsDialog,
                  ),
                  const Divider(),

                  // Приостановить все
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.warning,
                      child: Icon(Icons.pause, color: Colors.white),
                    ),
                    title: Text(
                      l10n.pauseAllSlots,
                      style: const TextStyle(color: AppColors.warning),
                    ),
                    subtitle: Text(l10n.temporaryPauseAllSlots),
                    onTap: _pauseAllSlots,
                  ),
                  const Divider(),

                  // Деактивировать все
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.archive, color: Colors.white),
                    ),
                    title: Text(
                      l10n.deactivateAllSlots,
                      style: const TextStyle(color: Colors.orange),
                    ),
                    subtitle: Text(l10n.disablePermanentSchedule),
                    onTap: _deactivateAllSlots,
                  ),
                ],
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// BottomSheet для выбора нового преподавателя
class _ReassignTeacherSheet extends ConsumerStatefulWidget {
  final List<InstitutionMember> teachers;
  final List<Lesson> lessons;
  final String institutionId;
  final VoidCallback onReassigned;

  const _ReassignTeacherSheet({
    required this.teachers,
    required this.lessons,
    required this.institutionId,
    required this.onReassigned,
  });

  @override
  ConsumerState<_ReassignTeacherSheet> createState() => _ReassignTeacherSheetState();
}

class _ReassignTeacherSheetState extends ConsumerState<_ReassignTeacherSheet> {
  String? _selectedTeacherId;
  List<LessonConflict>? _conflicts;
  bool _isChecking = false;
  bool _isReassigning = false;
  late AppLocalizations l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context);
  }

  Future<void> _checkConflicts() async {
    if (_selectedTeacherId == null) return;

    setState(() {
      _isChecking = true;
      _conflicts = null;
    });

    try {
      final repo = ref.read(lessonRepositoryProvider);
      final conflicts = await repo.checkReassignmentConflicts(
        widget.lessons,
        _selectedTeacherId!,
      );

      if (mounted) {
        setState(() {
          _conflicts = conflicts;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _conflicts = [];
          _isChecking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorWithParam(e.toString()))),
        );
      }
    }
  }

  Future<void> _reassignLessons() async {
    if (_selectedTeacherId == null) return;

    setState(() => _isReassigning = true);

    try {
      final repo = ref.read(lessonRepositoryProvider);

      // Фильтруем занятия без конфликтов
      final conflictIds = _conflicts?.map((c) => c.lesson.id).toSet() ?? {};
      final lessonsToReassign = widget.lessons
          .where((l) => !conflictIds.contains(l.id))
          .map((l) => l.id)
          .toList();

      if (lessonsToReassign.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noLessonsToReassignError)),
        );
        setState(() => _isReassigning = false);
        return;
      }

      await repo.reassignLessons(lessonsToReassign, _selectedTeacherId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reassignedLessonsMessage(lessonsToReassign.length))),
        );
        widget.onReassigned();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithParam(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isReassigning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflictCount = _conflicts?.length ?? 0;
    final canReassign = _conflicts != null && (widget.lessons.length - conflictCount) > 0;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                l10n.reassignTeacherHeader,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Выбор преподавателя
              DropdownButtonFormField<String>(
                key: ValueKey('reassignTeacher_$_selectedTeacherId'),
                initialValue: _selectedTeacherId,
                decoration: InputDecoration(
                  labelText: l10n.newTeacherFieldLabel,
                  border: const OutlineInputBorder(),
                ),
                items: widget.teachers
                    .map((member) {
                      return DropdownMenuItem(
                        value: member.userId,
                        child: Text(member.profile?.fullName ?? l10n.unknownName),
                      );
                    })
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTeacherId = value;
                    _conflicts = null;
                  });
                  if (value != null) {
                    _checkConflicts();
                  }
                },
              ),
              const SizedBox(height: 16),

              // Результаты проверки конфликтов
              if (_isChecking)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_conflicts != null) ...[
                if (_conflicts!.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          l10n.allLessonsCanReassign(widget.lessons.length),
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.foundConflictsCount(conflictCount),
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.canReassignLessons(widget.lessons.length - conflictCount),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Список конфликтов (первые 5)
                  ...(_conflicts!.take(5).map((conflict) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.close, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${DateFormat('d MMM', 'ru').format(conflict.lesson.date)}, '
                            '${conflict.lesson.startTime.hour}:${conflict.lesson.startTime.minute.toString().padLeft(2, '0')} — '
                            '${conflict.description}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ))),
                  if (_conflicts!.length > 5)
                    Text(
                      l10n.andMoreConflicts(_conflicts!.length - 5),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
                const SizedBox(height: 16),

                // Кнопка переназначения
                if (_isReassigning)
                  const Center(child: CircularProgressIndicator())
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canReassign ? _reassignLessons : null,
                      child: Text(
                        conflictCount > 0
                            ? l10n.reassignLessonsCount(widget.lessons.length - conflictCount)
                            : l10n.reassignAllLessonsLabel,
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// LESSON HISTORY SECTION
// =============================================================================

/// Секция истории занятий с пагинацией и группировкой по месяцам
class _LessonHistorySection extends ConsumerStatefulWidget {
  final String studentId;
  final String institutionId;

  const _LessonHistorySection({
    required this.studentId,
    required this.institutionId,
  });

  @override
  ConsumerState<_LessonHistorySection> createState() =>
      _LessonHistorySectionState();
}

class _LessonHistorySectionState extends ConsumerState<_LessonHistorySection> {
  final List<Lesson> _lessons = [];
  bool _isLoading = false;
  bool _hasMore = true;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(lessonRepositoryProvider);
      final newLessons = await repo.getLessonHistoryForStudent(
        widget.studentId,
        limit: _pageSize,
        offset: _lessons.length,
      );

      setState(() {
        _lessons.addAll(newLessons);
        _hasMore = newLessons.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, List<Lesson>> _groupByMonth(List<Lesson> lessons) {
    final Map<String, List<Lesson>> grouped = {};
    for (final lesson in lessons) {
      final key = DateFormat('LLLL yyyy', 'ru').format(lesson.date);
      final capitalizedKey = key[0].toUpperCase() + key.substring(1);
      grouped.putIfAbsent(capitalizedKey, () => []).add(lesson);
    }
    return grouped;
  }

  void _showLessonDetails(Lesson lesson) {
    showLessonDetailSheet(
      context: context,
      ref: ref,
      lesson: lesson,
      institutionId: widget.institutionId,
      onUpdated: () {
        // Перезагрузить историю при изменении
        setState(() {
          _lessons.clear();
          _hasMore = true;
        });
        _loadMore();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grouped = _groupByMonth(_lessons);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.lessonHistorySection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (_lessons.isEmpty && _isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_lessons.isEmpty)
          Text(
            l10n.noCompletedLessons,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          // Группы по месяцам
          for (final entry in grouped.entries) ...[
            // Заголовок месяца
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            // Занятия месяца
            ...entry.value.map(
              (lesson) => _LessonHistoryItem(
                lesson: lesson,
                onTap: () => _showLessonDetails(lesson),
              ),
            ),
          ],

          // Кнопка "Показать ещё"
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : TextButton.icon(
                        onPressed: _loadMore,
                        icon: const Icon(Icons.expand_more),
                        label: Text(l10n.showMore),
                      ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Компактная карточка занятия в истории
class _LessonHistoryItem extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;

  const _LessonHistoryItem({
    required this.lesson,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCompleted = lesson.status == LessonStatus.completed;
    final statusColor = isCompleted ? Colors.green : AppColors.warning;
    final statusIcon =
        isCompleted ? Icons.check_circle_outline : Icons.cancel_outlined;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Иконка статуса
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),

              // Основная информация
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.subject?.name ?? l10n.noSubjectLabel,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('d MMM', 'ru').format(lesson.date)} • '
                      '${lesson.startTime.hour}:${lesson.startTime.minute.toString().padLeft(2, '0')} - '
                      '${lesson.endTime.hour}:${lesson.endTime.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

              // Стрелка
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Обновлённый диалог редактирования ученика (BottomSheet)
class _EditStudentSheet extends ConsumerStatefulWidget {
  final Student student;
  final String institutionId;
  final String phoneDefaultPrefix;
  final VoidCallback? onSaved;

  const _EditStudentSheet({
    required this.student,
    required this.institutionId,
    required this.phoneDefaultPrefix,
    this.onSaved,
  });

  @override
  ConsumerState<_EditStudentSheet> createState() => _EditStudentSheetState();
}

class _EditStudentSheetState extends ConsumerState<_EditStudentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _commentController;
  final _lessonsController = TextEditingController();
  final _lessonsCommentController = TextEditingController();
  late AppLocalizations l10n;

  bool _isSaving = false;
  bool _showLessonsSection = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context);
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.name);
    final phoneText = widget.student.phone ??
        (widget.phoneDefaultPrefix.isNotEmpty ? '${widget.phoneDefaultPrefix} ' : '');
    _phoneController = TextEditingController(text: phoneText);
    _commentController = TextEditingController(text: widget.student.comment ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    _lessonsController.dispose();
    _lessonsCommentController.dispose();
    super.dispose();
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(studentControllerProvider.notifier);
      final success = await controller.update(
        widget.student.id,
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.isEmpty ? null : _phoneController.text.trim(),
        comment: _commentController.text.isEmpty ? null : _commentController.text.trim(),
      );

      if (success && mounted) {
        Navigator.pop(context);
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.studentUpdated)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addLessons() async {
    final lessonsCount = int.tryParse(_lessonsController.text.trim()) ?? 0;
    if (lessonsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterQuantity)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = PaymentRepository();
      final comment = _lessonsCommentController.text.trim();

      await repo.createBalanceTransfer(
        institutionId: widget.institutionId,
        studentId: widget.student.id,
        lessonsCount: lessonsCount,
        comment: comment.isEmpty ? null : comment,
      );

      if (mounted) {
        _lessonsController.clear();
        _lessonsCommentController.clear();
        setState(() => _showLessonsSection = false);
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lessonsCount > 0
                  ? l10n.lessonsAddedCount(lessonsCount)
                  : l10n.lessonsDeductedCount(lessonsCount.abs()),
            ),
            backgroundColor: lessonsCount > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorWithParam(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Заголовок
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        widget.student.name.isNotEmpty
                            ? widget.student.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(color: cs.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.editStudentTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            widget.student.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // === Секция: Основная информация ===
                _buildSectionHeader(l10n.basicInfoSection, Icons.person_outline),
                const SizedBox(height: 12),

                // ФИО
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.fullNameField,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? l10n.enterNameValidation : null,
                ),
                const SizedBox(height: 12),

                // Телефон
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.phoneField,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // Комментарий
                TextFormField(
                  controller: _commentController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.commentField,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),

                // === Секция: Остаток занятий ===
                _buildSectionHeader(l10n.legacyBalanceSection, Icons.sync_alt),
                const SizedBox(height: 8),

                // Текущий баланс
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.student.legacyBalance > 0
                              ? Colors.orange.withValues(alpha: 0.2)
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: widget.student.legacyBalance > 0
                              ? Colors.orange
                              : cs.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.currentBalance,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              l10n.balanceLessonsCount(widget.student.legacyBalance),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: widget.student.legacyBalance > 0
                                    ? Colors.orange
                                    : cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Кнопка добавить/убрать занятия
                      if (!_showLessonsSection)
                        FilledButton.tonalIcon(
                          onPressed: () => setState(() => _showLessonsSection = true),
                          icon: const Icon(Icons.edit, size: 18),
                          label: Text(l10n.changeBalance),
                        ),
                    ],
                  ),
                ),

                // Форма добавления/списания занятий
                if (_showLessonsSection) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.changeBalanceTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() {
                                _showLessonsSection = false;
                                _lessonsController.clear();
                                _lessonsCommentController.clear();
                              }),
                              icon: const Icon(Icons.close, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lessonsController,
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                          decoration: InputDecoration(
                            labelText: l10n.quantityField,
                            hintText: l10n.quantityHint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: cs.surface,
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _lessonsCommentController,
                          decoration: InputDecoration(
                            labelText: l10n.reasonOptional,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: cs.surface,
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _addLessons,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(l10n.applyAction),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Кнопка сохранения
                FilledButton(
                  onPressed: _isSaving ? null : _saveStudent,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.saveChangesAction),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Форма добавления занятий (balance transfer)
class _AddLessonsSheet extends StatefulWidget {
  final Student student;
  final String institutionId;
  final VoidCallback? onCompleted;

  const _AddLessonsSheet({
    required this.student,
    required this.institutionId,
    this.onCompleted,
  });

  @override
  State<_AddLessonsSheet> createState() => _AddLessonsSheetState();
}

class _AddLessonsSheetState extends State<_AddLessonsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _lessonsController = TextEditingController(text: '1');
  final _commentController = TextEditingController();
  bool _isLoading = false;
  late AppLocalizations l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context);
  }

  @override
  void dispose() {
    _lessonsController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final lessonsCount = int.tryParse(_lessonsController.text.trim()) ?? 0;
    if (lessonsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quantityCannotBeZero)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = PaymentRepository();
      final comment = _commentController.text.trim();

      await repo.createBalanceTransfer(
        institutionId: widget.institutionId,
        studentId: widget.student.id,
        lessonsCount: lessonsCount,
        comment: comment.isEmpty ? null : comment,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onCompleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lessonsCount > 0
                  ? l10n.lessonsAddedCount(lessonsCount)
                  : l10n.lessonsDeductedCount(lessonsCount.abs()),
            ),
            backgroundColor: lessonsCount > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithParam(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Заголовок
              Row(
                children: [
                  const Icon(Icons.sync_alt, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.addLessonsTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.legacyBalanceLabel(widget.student.legacyBalance),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),

              // Поле количества занятий
              TextFormField(
                controller: _lessonsController,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.lessonsQuantityField,
                  hintText: l10n.quantityPlaceholder,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.enterQuantity;
                  }
                  final count = int.tryParse(value.trim());
                  if (count == null) {
                    return l10n.enterInteger;
                  }
                  if (count == 0) {
                    return l10n.quantityCannotBeZero;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Поле комментария
              TextFormField(
                controller: _commentController,
                textInputAction: TextInputAction.done,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.commentOptionalField,
                  hintText: l10n.commentHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.comment_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // Кнопка
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(l10n.save),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
