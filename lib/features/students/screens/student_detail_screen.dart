import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kabinet/core/constants/app_strings.dart';
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
import 'package:kabinet/features/payment_plans/providers/payment_plan_provider.dart';
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/features/subscriptions/providers/subscription_provider.dart';
import 'package:kabinet/features/lesson_types/providers/lesson_type_provider.dart';
import 'package:kabinet/shared/models/lesson_type.dart';
import 'package:kabinet/features/student_schedules/providers/student_schedule_provider.dart';
import 'package:kabinet/features/student_schedules/repositories/student_schedule_repository.dart';
import 'package:kabinet/shared/models/student_schedule.dart';
import 'package:kabinet/features/rooms/providers/room_provider.dart';
import 'package:kabinet/core/widgets/ios_time_picker.dart';
import 'package:kabinet/core/providers/phone_settings_provider.dart';
import 'package:kabinet/features/statistics/providers/statistics_provider.dart';
import 'package:kabinet/shared/models/payment.dart';
import 'package:kabinet/shared/models/payment_plan.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subscription.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/features/students/widgets/merge_students_dialog.dart';
import 'package:kabinet/features/schedule/repositories/lesson_repository.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart';
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
                  itemBuilder: (context) => [
                    // Объединить с... (только для неархивированных)
                    if (!student.isArchived && canEditStudent)
                      const PopupMenuItem(
                        value: 'merge',
                        child: Row(
                          children: [
                            Icon(Icons.merge, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Объединить с...'),
                          ],
                        ),
                      ),
                    if (canArchive) ...[
                      if (student.isArchived) ...[
                        const PopupMenuItem(
                          value: 'restore',
                          child: Row(
                            children: [
                              Icon(Icons.unarchive, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Разархивировать', style: TextStyle(color: Colors.green)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Удалить навсегда', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ] else
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Архивировать', style: TextStyle(color: Colors.orange)),
                            ],
                          ),
                        ),
                    ],
                  ],
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ученик архивирован',
                                style: TextStyle(
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
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Секция объединённых учеников (если есть)
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
                          Text(
                            'Комментарий:',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(student.comment!),
                        ],
                        if (student.phone == null && student.comment == null)
                          const Text(
                            'Нет дополнительной информации',
                            style: TextStyle(color: AppColors.textSecondary),
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
                  showAvgCost: hasFullAccess, // Только владелец/админ видит среднюю стоимость
                ),
                const SizedBox(height: 16),

                // Lesson statistics
                _LessonStatsCard(studentId: studentId),
                const SizedBox(height: 24),

                // Subscriptions section
                Text(
                  'Абонементы',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                subscriptionsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView.inline(e),
                  data: (subscriptions) {
                    if (subscriptions.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Нет абонементов',
                            style: TextStyle(color: AppColors.textSecondary),
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
                Text(
                  'История оплат',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                paymentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView.inline(e),
                  data: (payments) {
                    if (payments.isEmpty) {
                      return const Text(
                        'Нет оплат',
                        style: TextStyle(color: AppColors.textSecondary),
                      );
                    }
                    return Column(
                      children: payments.map((p) => _PaymentItem(payment: p)).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditStudentDialog(BuildContext context, WidgetRef ref, Student student) {
    final nameController = TextEditingController(text: student.name);
    // Автозаполнение кода страны если телефон пустой
    final prefix = ref.read(phoneDefaultPrefixProvider);
    final phoneText = student.phone ?? (prefix.isNotEmpty ? '$prefix ' : '');
    final phoneController = TextEditingController(text: phoneText);
    final commentController = TextEditingController(text: student.comment ?? '');
    final legacyBalanceController = TextEditingController(
      text: student.legacyBalance > 0 ? student.legacyBalance.toString() : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать ученика'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'ФИО'),
                  validator: (v) => v == null || v.isEmpty ? 'Введите имя' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Телефон'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: commentController,
                  decoration: const InputDecoration(labelText: 'Комментарий'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: legacyBalanceController,
                  decoration: const InputDecoration(
                    labelText: 'Остаток занятий',
                    hintText: 'При переносе из другой школы',
                    prefixIcon: Icon(Icons.sync_alt_outlined),
                    suffixText: 'занятий',
                    helperText: 'Списывается первым, не влияет на доход',
                    helperMaxLines: 2,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final controller = ref.read(studentControllerProvider.notifier);
                final legacyBalance = int.tryParse(legacyBalanceController.text.trim());
                final success = await controller.update(
                  studentId,
                  institutionId: institutionId,
                  name: nameController.text.trim(),
                  phone: phoneController.text.isEmpty ? null : phoneController.text.trim(),
                  comment: commentController.text.isEmpty ? null : commentController.text.trim(),
                  legacyBalance: legacyBalance,
                );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ученик обновлен')),
                  );
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
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

  void _confirmArchive(BuildContext context, WidgetRef ref, Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Архивировать ученика?'),
        content: Text(
          'Вы уверены, что хотите архивировать "${student.name}"? Ученик будет перемещен в архив.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final controller = ref.read(studentControllerProvider.notifier);
              final success = await controller.archive(studentId, institutionId);
              if (success && context.mounted) {
                Navigator.pop(context);
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ученик архивирован')),
                );
              }
            },
            child: const Text(
              'Архивировать',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRestore(BuildContext context, WidgetRef ref, Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Разархивировать ученика?'),
        content: Text(
          'Вы уверены, что хотите вернуть "${student.name}" из архива?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final controller = ref.read(studentControllerProvider.notifier);
              final success = await controller.restore(studentId, institutionId);
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ученик восстановлен из архива'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              'Разархивировать',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCompletely(BuildContext context, WidgetRef ref, Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Удалить навсегда?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вы собираетесь ПОЛНОСТЬЮ УДАЛИТЬ ученика "${student.name}" и все связанные данные:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('• Все занятия из расписания'),
            const Text('• Все оплаты'),
            const Text('• Все подписки (включая семейные)'),
            const Text('• Связи с преподавателями и предметами'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Это действие НЕОБРАТИМО!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final controller = ref.read(studentControllerProvider.notifier);
              final success = await controller.deleteCompletely(studentId, institutionId);
              if (success && context.mounted) {
                Navigator.pop(context); // Закрыть диалог
                context.pop(); // Вернуться к списку учеников
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ученик и все данные удалены'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Удалить навсегда',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddPaymentSheet(
        institutionId: institutionId,
        studentId: studentId,
        onCreated: () {
          ref.invalidate(studentProvider(studentId));
          ref.invalidate(studentPaymentsProvider(studentId));
          ref.invalidate(subscriptionsStreamProvider(studentId));
        },
      ),
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
    final daysController = TextEditingController(text: '14');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заморозить абонемент'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'При заморозке срок действия абонемента приостанавливается. '
                'После разморозки срок будет продлён на количество дней заморозки.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: daysController,
                decoration: const InputDecoration(
                  labelText: 'Количество дней',
                  hintText: '14',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите количество';
                  final num = int.tryParse(v);
                  if (num == null || num <= 0 || num > 90) {
                    return 'Введите число от 1 до 90';
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
            child: const Text('Отмена'),
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
                    const SnackBar(content: Text('Абонемент заморожен')),
                  );
                }
              }
            },
            child: const Text('Заморозить'),
          ),
        ],
      ),
    );
  }

  void _unfreezeSubscription(BuildContext context, WidgetRef ref, Subscription subscription) async {
    final controller = ref.read(subscriptionControllerProvider.notifier);
    final result = await controller.unfreeze(subscription.id, studentId);
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Абонемент разморожен. Срок продлён до ${DateFormat('dd.MM.yyyy').format(result.expiresAt)}'),
        ),
      );
    }
  }

  void _showExtendDialog(BuildContext context, WidgetRef ref, Subscription subscription) {
    final daysController = TextEditingController(text: '7');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Продлить срок'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Текущий срок: до ${DateFormat('dd.MM.yyyy').format(subscription.expiresAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: daysController,
                decoration: const InputDecoration(
                  labelText: 'Продлить на дней',
                  hintText: '7',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите количество';
                  final num = int.tryParse(v);
                  if (num == null || num <= 0 || num > 365) {
                    return 'Введите число от 1 до 365';
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
            child: const Text('Отмена'),
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
                      content: Text('Срок продлён до ${DateFormat('dd.MM.yyyy').format(result.expiresAt)}'),
                    ),
                  );
                }
              }
            },
            child: const Text('Продлить'),
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
  final bool showAvgCost;

  const _BalanceAndCostCard({
    required this.student,
    required this.hasDebt,
    required this.studentId,
    this.onAddPayment,
    this.onManageLessons,
    this.showAvgCost = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        AppStrings.prepaidLessons.toUpperCase(),
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
                        'занятий',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      // Разбивка баланса если есть legacy
                      if (student.hasLegacyBalance) ...[
                        const SizedBox(height: 8),
                        Text(
                          'из абонементов: ${student.subscriptionBalance}',
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
                              'из остатка: ${student.legacyBalance}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
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
                              'СР. СТОИМОСТЬ',
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
                              'нет данных',
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
                            stats.isApproximate ? 'СР. СТОИМОСТЬ ≈' : 'СР. СТОИМОСТЬ',
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
                            'за занятие',
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
                        label: const Text('Управление'),
                      ),
                    ),
                  if (onManageLessons != null && onAddPayment != null)
                    const SizedBox(width: 8),
                  if (onAddPayment != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAddPayment,
                        icon: const Icon(Icons.add),
                        label: const Text(AppStrings.addPayment),
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
                  'Статистика занятий',
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
                              'Проведено',
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
                              'Отменено',
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
    final amountStr = '${formatter.format(payment.amount.toInt())} ₸';

    // Проверяем, есть ли скидка в комментарии
    final hasDiscount = payment.comment?.contains('Скидка:') ?? false;

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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.discount, size: 12, color: AppColors.warning),
                              SizedBox(width: 2),
                              Text(
                                'Скидка',
                                style: TextStyle(
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
                    '${payment.lessonsCount} занятий • $dateStr',
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
                child: const Text(
                  'Корр.',
                  style: TextStyle(
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
                    subscription.statusDisplayName,
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
                    child: const Text(
                      'Скоро истекает',
                      style: TextStyle(
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.family_restroom,
                          size: 14,
                          color: Colors.purple,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Групповой',
                          style: TextStyle(
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
                  '${subscription.lessonsRemaining} / ${subscription.lessonsTotal} занятий',
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
                    'Заморожен до ${DateFormat('dd.MM.yyyy').format(subscription.frozenUntil!)}',
                    style: const TextStyle(color: AppColors.info),
                  )
                else
                  Text(
                    status == SubscriptionStatus.expired
                        ? 'Истёк $expiresStr'
                        : 'Действует до $expiresStr',
                    style: TextStyle(
                      color: status == SubscriptionStatus.expired
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                if (status == SubscriptionStatus.active && subscription.daysUntilExpiration >= 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${subscription.daysUntilExpiration} дн.)',
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
                      label: const Text('Заморозить'),
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
                      label: const Text('Разморозить'),
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
                      label: const Text('Продлить'),
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

/// Форма добавления оплаты
class _AddPaymentSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final String studentId;
  final VoidCallback onCreated;

  const _AddPaymentSheet({
    required this.institutionId,
    required this.studentId,
    required this.onCreated,
  });

  @override
  ConsumerState<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends ConsumerState<_AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _lessonsController = TextEditingController();
  final _validityController = TextEditingController(text: '30');
  final _discountController = TextEditingController();
  final _commentController = TextEditingController();

  PaymentPlan? _selectedPlan;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _hasDiscount = false;
  double _originalPrice = 0;

  @override
  void dispose() {
    _amountController.dispose();
    _lessonsController.dispose();
    _validityController.dispose();
    _discountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onPlanSelected(PaymentPlan? plan) {
    setState(() {
      _selectedPlan = plan;
      if (plan != null) {
        _originalPrice = plan.price;
        _lessonsController.text = plan.lessonsCount.toString();
        _validityController.text = plan.validityDays.toString();
        _updateFinalAmount();
      } else {
        _originalPrice = 0;
        _hasDiscount = false;
        _discountController.clear();
        _amountController.clear();
      }
    });
  }

  void _updateFinalAmount() {
    if (_selectedPlan != null) {
      double finalAmount = _originalPrice;
      if (_hasDiscount && _discountController.text.isNotEmpty) {
        final discount = double.tryParse(_discountController.text) ?? 0;
        finalAmount = _originalPrice - discount;
        if (finalAmount < 0) finalAmount = 0;
      }
      _amountController.text = finalAmount.toStringAsFixed(0);
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Формируем комментарий со скидкой
    String? comment = _commentController.text.trim();
    if (_hasDiscount && _discountController.text.isNotEmpty) {
      final discount = double.tryParse(_discountController.text) ?? 0;
      if (discount > 0) {
        final discountNote = 'Скидка: ${discount.toStringAsFixed(0)} ₸';
        comment = comment.isEmpty ? discountNote : '$discountNote\n$comment';
      }
    }

    final controller = ref.read(paymentControllerProvider.notifier);
    final payment = await controller.create(
      institutionId: widget.institutionId,
      studentId: widget.studentId,
      paymentPlanId: _selectedPlan?.id,
      amount: double.parse(_amountController.text),
      lessonsCount: int.parse(_lessonsController.text),
      paidAt: _selectedDate,
      comment: comment.isEmpty ? null : comment,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (payment != null) {
        widget.onCreated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Оплата добавлена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(paymentPlansProvider(widget.institutionId));
    final controllerState = ref.watch(paymentControllerProvider);

    ref.listen(paymentControllerProvider, (prev, next) {
      if (next.hasError && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ErrorView.getUserFriendlyMessage(next.error!)),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Индикатор
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
                const SizedBox(height: 20),

                // Заголовок
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payments,
                        color: AppColors.success,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Добавить оплату',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Выберите тариф или введите сумму',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Дата оплаты
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Дата оплаты',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMMM yyyy', 'ru').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Тариф
                plansAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => ErrorView.inline(e),
                  data: (plans) {
                    // Находим выбранный план по ID
                    final currentPlan = _selectedPlan != null
                        ? plans.where((p) => p.id == _selectedPlan!.id).firstOrNull
                        : null;
                    return DropdownButtonFormField<PaymentPlan?>(
                      decoration: InputDecoration(
                        labelText: 'Тариф',
                        prefixIcon: const Icon(Icons.credit_card_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      initialValue: currentPlan,
                      items: [
                        const DropdownMenuItem<PaymentPlan?>(
                          value: null,
                          child: Text('Свой вариант'),
                        ),
                        ...plans.map((plan) => DropdownMenuItem<PaymentPlan?>(
                              value: plan,
                              child: Text(plan.displayNameWithValidity),
                            )),
                      ],
                      onChanged: _onPlanSelected,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Скидка (только если выбран тариф)
                if (_selectedPlan != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _hasDiscount
                          ? AppColors.warning.withValues(alpha: 0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: _hasDiscount
                          ? Border.all(color: AppColors.warning.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _hasDiscount,
                              onChanged: (value) {
                                setState(() {
                                  _hasDiscount = value ?? false;
                                  if (!_hasDiscount) {
                                    _discountController.clear();
                                  }
                                  _updateFinalAmount();
                                });
                              },
                              activeColor: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.discount,
                              color: _hasDiscount ? AppColors.warning : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Скидка',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (_hasDiscount) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _discountController,
                                  decoration: InputDecoration(
                                    hintText: 'Размер скидки',
                                    suffixText: '₸',
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    _updateFinalAmount();
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Было: ${_originalPrice.toStringAsFixed(0)} ₸',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  Text(
                                    'Итого: ${_amountController.text} ₸',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Сумма
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Сумма',
                    suffixText: '₸',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите сумму';
                    if (double.tryParse(v) == null) return 'Неверная сумма';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Количество занятий и Срок действия в одной строке
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lessonsController,
                        decoration: InputDecoration(
                          labelText: 'Занятий',
                          prefixIcon: const Icon(Icons.school_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите';
                          if (int.tryParse(v) == null) return 'Число';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _validityController,
                        decoration: InputDecoration(
                          labelText: 'Срок (дней)',
                          prefixIcon: const Icon(Icons.timer_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите';
                          final num = int.tryParse(v);
                          if (num == null || num <= 0) return 'Ошибка';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Комментарий
                TextFormField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    labelText: 'Комментарий (необязательно)',
                    prefixIcon: const Icon(Icons.comment_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Кнопка
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading || controllerState.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading || controllerState.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check),
                              const SizedBox(width: 8),
                              Text(
                                _amountController.text.isNotEmpty
                                    ? 'Добавить оплату ${_amountController.text} ₸'
                                    : 'Добавить оплату',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
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
    final teachersAsync = ref.watch(studentTeachersProvider(studentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Преподаватели',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _showAddTeacherDialog(context, ref),
                tooltip: 'Добавить преподавателя',
              ),
          ],
        ),
        const SizedBox(height: 8),
        teachersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView.inline(e),
          data: (teachers) {
            if (teachers.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Нет привязанных преподавателей',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: teachers.map((binding) {
                final name = binding.teacher?.fullName ?? 'Неизвестный';
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
                  'Добавить преподавателя',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                membersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView.inline(e),
                  data: (members) {
                    final available = members
                        .where((m) => !existingIds.contains(m.userId))
                        .toList();
                    if (available.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Все преподаватели уже добавлены'),
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
                                const SnackBar(content: Text('Преподаватель добавлен')),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить преподавателя?'),
        content: const Text('Преподаватель будет отвязан от этого ученика.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(studentBindingsControllerProvider.notifier)
                  .removeTeacher(studentId, userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Преподаватель удалён')),
                );
              }
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
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
    final subjectsAsync = ref.watch(studentSubjectsProvider(studentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Предметы',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _showAddSubjectDialog(context, ref),
                tooltip: 'Добавить предмет',
              ),
          ],
        ),
        const SizedBox(height: 8),
        subjectsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView.inline(e),
          data: (subjects) {
            if (subjects.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Нет привязанных предметов',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects.map((binding) {
                final name = binding.subject?.name ?? 'Неизвестный';
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
                  'Добавить предмет',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                subjectsListAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView.inline(e),
                  data: (subjects) {
                    final available = subjects
                        .where((s) => !existingIds.contains(s.id) && s.archivedAt == null)
                        .toList();
                    if (available.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Все предметы уже добавлены'),
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
                                const SnackBar(content: Text('Предмет добавлен')),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить предмет?'),
        content: const Text('Предмет будет отвязан от этого ученика.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(studentBindingsControllerProvider.notifier)
                  .removeSubject(studentId, subjectId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Предмет удалён')),
                );
              }
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
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
                const Text(
                  'Типы занятий',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _showAddLessonTypeDialog(context, ref, allLessonTypesAsync),
                    tooltip: 'Добавить тип занятия',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            lessonTypesAsync.when(
              data: (lessonTypes) {
                if (lessonTypes.isEmpty) {
                  return Text(
                    'Нет привязанных типов занятий',
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
              error: (e, _) => Text('Ошибка: $e', style: const TextStyle(color: Colors.red)),
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
              const Text(
                'Добавить тип занятия',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: allLessonTypesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Ошибка: $e')),
                  data: (allLessonTypes) {
                    final available = allLessonTypes
                        .where((lt) => !existingIds.contains(lt.id))
                        .toList();
                    if (available.isEmpty) {
                      return const Center(
                        child: Text('Все типы занятий уже добавлены'),
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
                                const SnackBar(content: Text('Тип занятия добавлен')),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить тип занятия?'),
        content: const Text('Тип занятия будет отвязан от этого ученика.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(studentBindingsControllerProvider.notifier)
                  .removeLessonType(studentId, lessonTypeId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Тип занятия удалён')),
                );
              }
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
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
                          'Объединить с...',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Выберите учеников для объединения с "${widget.currentStudent.name}"',
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
                  hintText: 'Поиск учеников...',
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
                error: (e, _) => ErrorView.inline(e),
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
                    return const Center(
                      child: Text('Нет учеников для объединения'),
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
                              'Баланс: ${student.balance}',
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
                        child: const Text('Отмена'),
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
                              ? 'Выберите учеников'
                              : 'Далее (${_selectedIds.length})',
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
                'Групповая карточка',
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
              'Не удалось загрузить имена',
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
    final params = StudentScheduleParams(studentId, institutionId);
    final activeSchedules = ref.watch(activeStudentSchedulesProvider(params));
    final inactiveSchedules = ref.watch(inactiveStudentSchedulesProvider(params));
    // Проверяем loading через основной stream заведения
    final institutionSchedulesAsync = ref.watch(institutionSchedulesStreamProvider(institutionId));
    final isLoading = institutionSchedulesAsync.isLoading && institutionSchedulesAsync.valueOrNull == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Постоянное расписание',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _showAddScheduleSlotSheet(context, ref),
                tooltip: 'Добавить слот',
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
            if (activeSchedules.isEmpty && inactiveSchedules.isEmpty) {
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
                          'Нет постоянного расписания',
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
                // Active schedules
                ...activeSchedules.map((schedule) => _ScheduleSlotCard(
                  schedule: schedule,
                  institutionId: institutionId,
                  canEdit: canEdit,
                )),

                // Inactive schedules in ExpansionTile
                if (inactiveSchedules.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Архив (${inactiveSchedules.length})',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    children: inactiveSchedules.map((schedule) => _ScheduleSlotCard(
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
      builder: (sheetContext) => _AddScheduleSlotSheet(
        studentId: studentId,
        institutionId: institutionId,
      ),
    );
  }
}

/// Карточка слота расписания
class _ScheduleSlotCard extends ConsumerWidget {
  final StudentSchedule schedule;
  final String institutionId;
  final bool canEdit;
  final bool isInactive;

  const _ScheduleSlotCard({
    required this.schedule,
    required this.institutionId,
    this.canEdit = true,
    this.isInactive = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
                            schedule.room?.name ?? 'Кабинет',
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
                              '→ ${schedule.replacementRoom?.name ?? 'Замена'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Teacher
                    if (schedule.teacher != null) ...[
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
                              schedule.teacher!.fullName,
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
                          ? 'Пауза до ${DateFormat('dd.MM').format(schedule.pauseUntil!)}'
                          : 'На паузе',
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
                            schedule.room?.name ?? 'Кабинет',
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
                // Pause/Resume
                if (schedule.isPaused)
                  ListTile(
                    leading: const Icon(Icons.play_arrow, color: Colors.green),
                    title: const Text('Возобновить'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _resumeSchedule(context, ref);
                    },
                  )
                else
                  ListTile(
                    leading: Icon(Icons.pause, color: Colors.orange.shade600),
                    title: const Text('Приостановить'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showPauseDialog(context, ref);
                    },
                  ),

                // Replacement room
                if (schedule.hasReplacement)
                  ListTile(
                    leading: const Icon(Icons.undo, color: AppColors.primary),
                    title: const Text('Снять замену кабинета'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _clearReplacement(context, ref);
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.swap_horiz, color: AppColors.primary),
                    title: const Text('Временная замена кабинета'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showReplacementDialog(context, ref);
                    },
                  ),

                // Deactivate
                ListTile(
                  leading: const Icon(Icons.archive, color: Colors.orange),
                  title: const Text('Деактивировать'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deactivateSchedule(context, ref);
                  },
                ),
              ] else ...[
                // Reactivate
                ListTile(
                  leading: const Icon(Icons.unarchive, color: Colors.green),
                  title: const Text('Активировать'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reactivateSchedule(context, ref);
                  },
                ),
              ],

              // Delete
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить', style: TextStyle(color: Colors.red)),
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

  void _resumeSchedule(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(studentScheduleControllerProvider.notifier);
    final success = await controller.resume(
      schedule.id,
      institutionId,
      schedule.studentId,
    );
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Расписание возобновлено')),
      );
    }
  }

  void _showPauseDialog(BuildContext context, WidgetRef ref) {
    DateTime? pauseUntil;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Приостановить расписание'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('До какой даты приостановить?'),
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
                  decoration: const InputDecoration(
                    labelText: 'Дата возобновления',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    pauseUntil != null
                        ? DateFormat('dd.MM.yyyy').format(pauseUntil!)
                        : 'Выберите дату',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: pauseUntil == null
                  ? null
                  : () async {
                      Navigator.pop(dialogContext);
                      final controller = ref.read(studentScheduleControllerProvider.notifier);
                      final success = await controller.pause(
                        schedule.id,
                        pauseUntil!,
                        institutionId,
                        schedule.studentId,
                      );
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Расписание приостановлено до ${DateFormat('dd.MM.yyyy').format(pauseUntil!)}',
                            ),
                          ),
                        );
                      }
                    },
              child: const Text('Приостановить'),
            ),
          ],
        ),
      ),
    );
  }

  void _clearReplacement(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(studentScheduleControllerProvider.notifier);
    final success = await controller.clearReplacement(
      schedule.id,
      institutionId,
      schedule.studentId,
    );
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Замена кабинета снята')),
      );
    }
  }

  void _showReplacementDialog(BuildContext context, WidgetRef ref) {
    String? selectedRoomId;
    DateTime? replacementUntil;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final roomsAsync = ref.watch(roomsStreamProvider(institutionId));

          return AlertDialog(
            title: const Text('Временная замена кабинета'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Room dropdown
                roomsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Ошибка: $e'),
                  data: (rooms) => DropdownButtonFormField<String>(
                    key: ValueKey('tempRoom_$selectedRoomId'),
                    initialValue: selectedRoomId,
                    decoration: const InputDecoration(labelText: 'Новый кабинет'),
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
                    decoration: const InputDecoration(
                      labelText: 'До какой даты',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      replacementUntil != null
                          ? DateFormat('dd.MM.yyyy').format(replacementUntil!)
                          : 'Выберите дату',
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: selectedRoomId == null || replacementUntil == null
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);
                        final controller = ref.read(studentScheduleControllerProvider.notifier);
                        final success = await controller.setReplacement(
                          schedule.id,
                          selectedRoomId!,
                          replacementUntil!,
                          institutionId,
                          schedule.studentId,
                        );
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Замена кабинета установлена')),
                          );
                        }
                      },
                child: const Text('Применить'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deactivateSchedule(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Деактивировать расписание?'),
        content: const Text(
          'Слот будет перемещён в архив. Вы сможете активировать его позже.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Деактивировать'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(studentScheduleControllerProvider.notifier);
      final success = await controller.deactivate(
        schedule.id,
        institutionId,
        schedule.studentId,
      );
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Расписание деактивировано')),
        );
      }
    }
  }

  void _reactivateSchedule(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(studentScheduleControllerProvider.notifier);
    final success = await controller.reactivate(
      schedule.id,
      institutionId,
      schedule.studentId,
    );
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Расписание активировано')),
      );
    }
  }

  void _deleteSchedule(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить расписание?'),
        content: const Text(
          'Этот слот будет удалён навсегда. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(studentScheduleControllerProvider.notifier);
      final success = await controller.delete(
        schedule.id,
        institutionId,
        schedule.studentId,
      );
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Расписание удалено')),
        );
      }
    }
  }
}

/// Форма добавления нового слота расписания
class _AddScheduleSlotSheet extends ConsumerStatefulWidget {
  final String studentId;
  final String institutionId;

  const _AddScheduleSlotSheet({
    required this.studentId,
    required this.institutionId,
  });

  @override
  ConsumerState<_AddScheduleSlotSheet> createState() => _AddScheduleSlotSheetState();
}

class _AddScheduleSlotSheetState extends ConsumerState<_AddScheduleSlotSheet> {
  final _formKey = GlobalKey<FormState>();

  // Выбранные дни недели (для batch создания)
  final Set<int> _selectedDays = {};

  // Время для каждого дня
  final Map<int, TimeOfDay> _startTimes = {};
  final Map<int, TimeOfDay> _endTimes = {};

  String? _selectedRoomId;
  String? _selectedTeacherId;
  String? _selectedSubjectId;
  String? _selectedLessonTypeId;

  bool _isSubmitting = false;
  bool _bindingsLoaded = false;

  // Проверка конфликтов
  bool _isCheckingConflicts = false;
  final Set<int> _conflictingDays = {}; // Дни с конфликтами

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
  /// Проверяет: 1) другие постоянные расписания, 2) ВСЕ будущие занятия
  Future<void> _checkConflicts() async {
    if (_selectedRoomId == null || _selectedDays.isEmpty) {
      setState(() {
        _conflictingDays.clear();
        _isCheckingConflicts = false;
      });
      return;
    }

    setState(() => _isCheckingConflicts = true);

    final repo = ref.read(studentScheduleRepositoryProvider);
    final newConflicts = <int>{};

    for (final day in _selectedDays) {
      final startTime = _startTimes[day] ?? _defaultStartTime;
      final endTime = _endTimes[day] ?? _defaultEndTime;

      // 1. Проверяем конфликт с другими постоянными расписаниями
      final hasScheduleConflict = await repo.hasScheduleConflict(
        roomId: _selectedRoomId!,
        dayOfWeek: day,
        startTime: startTime,
        endTime: endTime,
      );

      if (hasScheduleConflict) {
        newConflicts.add(day);
        continue; // Уже конфликт — не нужно проверять занятия
      }

      // 2. Проверяем конфликт с ВСЕМИ будущими занятиями для этого дня недели
      final hasLessonConflict = await repo.hasLessonConflictForDayOfWeek(
        roomId: _selectedRoomId!,
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
                'Добавить постоянное расписание',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Выберите дни недели и время занятий',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Days of week selection
              Text(
                'Дни недели',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _buildDaysSelector(),
              const SizedBox(height: 16),

              // Time for each selected day
              if (_selectedDays.isNotEmpty) ...[
                Text(
                  'Время занятий',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ..._buildDayTimeRows(),
                const SizedBox(height: 16),
              ],

              // Room dropdown
              roomsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Ошибка: $e'),
                data: (rooms) => DropdownButtonFormField<String>(
                  key: ValueKey('room_$_selectedRoomId'),
                  initialValue: _selectedRoomId,
                  decoration: const InputDecoration(
                    labelText: 'Кабинет *',
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                  items: rooms
                      .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedRoomId = v);
                    _checkConflicts();
                  },
                  validator: (v) => v == null ? 'Выберите кабинет' : null,
                ),
              ),
              const SizedBox(height: 16),

              // Teacher dropdown (приоритет привязанным преподавателям)
              membersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Ошибка: $e'),
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
                    decoration: const InputDecoration(
                      labelText: 'Преподаватель *',
                      prefixIcon: Icon(Icons.person),
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
                                      m.profile?.fullName ?? 'Преподаватель',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTeacherId = v),
                    validator: (v) => v == null ? 'Выберите преподавателя' : null,
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
                    decoration: const InputDecoration(
                      labelText: 'Предмет (опционально)',
                      prefixIcon: Icon(Icons.book),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Не указано')),
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
                    decoration: const InputDecoration(
                      labelText: 'Тип занятия (опционально)',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Не указано')),
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
                      'Проверка конфликтов...',
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
                      'Конфликты: ${_conflictingDays.length} (измените время)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Submit button
              ElevatedButton.icon(
                onPressed: _selectedDays.isEmpty ||
                        _isSubmitting ||
                        _isCheckingConflicts ||
                        _conflictingDays.isNotEmpty
                    ? null
                    : _submit,
                icon: _isSubmitting || _isCheckingConflicts
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  _isCheckingConflicts
                      ? 'Проверка...'
                      : _conflictingDays.isNotEmpty
                          ? 'Есть конфликты'
                          : _selectedDays.length > 1
                              ? 'Создать ${_selectedDays.length} слотов'
                              : 'Создать слот',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaysSelector() {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

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
                _conflictingDays.remove(dayNumber);
              }
            });
            _checkConflicts();
          },
        );
      }),
    );
  }

  List<Widget> _buildDayTimeRows() {
    final sortedDays = _selectedDays.toList()..sort();
    return sortedDays.map((day) => _buildDayTimeRow(day)).toList();
  }

  Widget _buildDayTimeRow(int dayNumber) {
    const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final startTime = _startTimes[dayNumber] ?? _defaultStartTime;
    final endTime = _endTimes[dayNumber] ?? _defaultEndTime;
    final hasConflict = _conflictingDays.contains(dayNumber);

    // Расчёт длительности
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    final durationText = durationMinutes > 0
        ? (durationMinutes >= 60
            ? '${durationMinutes ~/ 60} ч${durationMinutes % 60 > 0 ? ' ${durationMinutes % 60} мин' : ''}'
            : '$durationMinutes мин')
        : 'Некорректно';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasConflict
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pickTimeRange(dayNumber),
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

              // Time range
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatTime(startTime)} — ${_formatTime(endTime)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasConflict ? 'Конфликт! Время занято' : durationText,
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

              // Conflict or Edit icon
              Icon(
                hasConflict ? Icons.warning_amber_rounded : Icons.edit_outlined,
                color: hasConflict
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один день недели')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final controller = ref.read(studentScheduleControllerProvider.notifier);

      if (_selectedDays.length == 1) {
        // Single slot
        final day = _selectedDays.first;
        await controller.create(
          institutionId: widget.institutionId,
          studentId: widget.studentId,
          teacherId: _selectedTeacherId!,
          roomId: _selectedRoomId!,
          subjectId: _selectedSubjectId,
          lessonTypeId: _selectedLessonTypeId,
          dayOfWeek: day,
          startTime: _startTimes[day]!,
          endTime: _endTimes[day]!,
        );
      } else {
        // Multiple slots (batch)
        final slots = _selectedDays.map((day) => DayTimeSlot(
          dayOfWeek: day,
          startTime: _startTimes[day]!,
          endTime: _endTimes[day]!,
        )).toList();

        await controller.createBatch(
          institutionId: widget.institutionId,
          studentId: widget.studentId,
          teacherId: _selectedTeacherId!,
          roomId: _selectedRoomId!,
          subjectId: _selectedSubjectId,
          lessonTypeId: _selectedLessonTypeId,
          slots: slots,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedDays.length == 1
                  ? 'Слот расписания создан'
                  : 'Создано ${_selectedDays.length} слотов расписания',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
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
  List<StudentSchedule>? _scheduleSlots;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final lessonRepo = ref.read(lessonRepositoryProvider);
      final scheduleRepo = ref.read(studentScheduleRepositoryProvider);

      // Загружаем параллельно
      final results = await Future.wait([
        lessonRepo.getFutureLessonsForStudent(widget.student.id),
        scheduleRepo.getByStudent(widget.student.id),
      ]);

      if (mounted) {
        setState(() {
          _futureLessons = results[0] as List<Lesson>;
          _scheduleSlots = (results[1] as List<StudentSchedule>)
              .where((s) => s.isActive)
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
        title: const Text('Удалить все занятия?'),
        content: Text(
          'Вы уверены, что хотите удалить ${_futureLessons!.length} будущих занятий "${widget.student.name}"?\n\n'
          'Баланс абонементов не изменится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
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
          SnackBar(content: Text('Удалено $count занятий')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
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
        const SnackBar(content: Text('Нет доступных преподавателей')),
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
        const SnackBar(content: Text('Нет доступных преподавателей')),
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
              'Выберите преподавателя',
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
              title: Text(member.profile?.fullName ?? 'Без имени'),
              onTap: () => Navigator.pop(context, member.userId),
            )),
          ],
        ),
      ),
    );

    if (selectedTeacherId == null) return;

    setState(() => _isProcessing = true);

    try {
      final controller = ref.read(studentScheduleControllerProvider.notifier);
      final scheduleIds = _scheduleSlots!.map((s) => s.id).toList();

      await controller.reassignTeacher(
        scheduleIds,
        selectedTeacherId,
        widget.institutionId,
        [widget.student.id],
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Переназначено ${scheduleIds.length} слотов')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
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
      helpText: 'Приостановить до',
    );

    if (pauseUntil == null) return;

    setState(() => _isProcessing = true);

    try {
      final controller = ref.read(studentScheduleControllerProvider.notifier);

      for (final slot in _scheduleSlots!) {
        await controller.pause(
          slot.id,
          pauseUntil,
          widget.institutionId,
          widget.student.id,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Приостановлено ${_scheduleSlots!.length} слотов')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
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
        title: const Text('Деактивировать расписание?'),
        content: Text(
          'Деактивировать ${_scheduleSlots!.length} слотов постоянного расписания?\n\n'
          'Слоты останутся в архиве и могут быть восстановлены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Деактивировать'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final controller = ref.read(studentScheduleControllerProvider.notifier);

      for (final slot in _scheduleSlots!) {
        await controller.deactivate(
          slot.id,
          widget.institutionId,
          widget.student.id,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Деактивировано ${_scheduleSlots!.length} слотов')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
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
                'Управление занятиями',
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
                          'Ошибка загрузки: $_loadError',
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
                      const Expanded(
                        child: Text('Нет запланированных занятий'),
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
                          'Найдено ${_futureLessons!.length} будущих занятий',
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
                    title: const Text('Переназначить преподавателя'),
                    subtitle: const Text('Выбрать нового преподавателя для всех занятий'),
                    onTap: _showReassignDialog,
                  ),
                  const Divider(),

                  // Удалить все занятия
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Icon(Icons.delete_sweep, color: Colors.white),
                    ),
                    title: const Text(
                      'Удалить все занятия',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text('Баланс абонементов не изменится'),
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
                      'Постоянное расписание',
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
                              '${_scheduleSlots!.length} ${_scheduleSlots!.length == 1 ? 'слот' : _scheduleSlots!.length < 5 ? 'слота' : 'слотов'}',
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
                    title: const Text('Переназначить преподавателя'),
                    subtitle: const Text('Для всех слотов расписания'),
                    onTap: _showReassignSlotsDialog,
                  ),
                  const Divider(),

                  // Приостановить все
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.warning,
                      child: Icon(Icons.pause, color: Colors.white),
                    ),
                    title: const Text(
                      'Приостановить',
                      style: TextStyle(color: AppColors.warning),
                    ),
                    subtitle: const Text('Временно приостановить все слоты'),
                    onTap: _pauseAllSlots,
                  ),
                  const Divider(),

                  // Деактивировать все
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.archive, color: Colors.white),
                    ),
                    title: const Text(
                      'Деактивировать',
                      style: TextStyle(color: Colors.orange),
                    ),
                    subtitle: const Text('Отключить постоянное расписание'),
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
          SnackBar(content: Text('Ошибка проверки: $e')),
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
          const SnackBar(content: Text('Нет занятий для переназначения')),
        );
        setState(() => _isReassigning = false);
        return;
      }

      await repo.reassignLessons(lessonsToReassign, _selectedTeacherId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Переназначено ${lessonsToReassign.length} занятий')),
        );
        widget.onReassigned();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
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
                'Переназначить преподавателя',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Выбор преподавателя
              DropdownButtonFormField<String>(
                key: ValueKey('reassignTeacher_$_selectedTeacherId'),
                initialValue: _selectedTeacherId,
                decoration: const InputDecoration(
                  labelText: 'Новый преподаватель',
                  border: OutlineInputBorder(),
                ),
                items: widget.teachers
                    .map((member) {
                      return DropdownMenuItem(
                        value: member.userId,
                        child: Text(member.profile?.fullName ?? 'Неизвестный'),
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
                          'Все ${widget.lessons.length} занятий можно переназначить',
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
                                'Найдено $conflictCount конфликтов',
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
                          'Можно переназначить: ${widget.lessons.length - conflictCount} занятий',
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
                      '...и ещё ${_conflicts!.length - 5} конфликтов',
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
                            ? 'Переназначить ${widget.lessons.length - conflictCount} занятий'
                            : 'Переназначить все занятия',
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
