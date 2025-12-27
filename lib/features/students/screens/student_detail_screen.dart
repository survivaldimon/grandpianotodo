import 'package:flutter/material.dart';
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
import 'package:kabinet/features/payments/providers/payment_provider.dart' hide paymentPlansProvider;
import 'package:kabinet/features/payment_plans/providers/payment_plan_provider.dart';
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/features/subscriptions/providers/subscription_provider.dart';
import 'package:kabinet/features/statistics/providers/statistics_provider.dart';
import 'package:kabinet/shared/models/payment.dart';
import 'package:kabinet/shared/models/payment_plan.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subscription.dart';
import 'package:go_router/go_router.dart';

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
    final subscriptionsAsync = ref.watch(subscriptionsStreamProvider(studentId));

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
              if (canArchive)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'archive') {
                      _confirmArchive(context, ref, student);
                    } else if (value == 'restore') {
                      _confirmRestore(context, ref, student);
                    }
                  },
                  itemBuilder: (context) => [
                    if (student.isArchived)
                      const PopupMenuItem(
                        value: 'restore',
                        child: Row(
                          children: [
                            Icon(Icons.unarchive, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Разархивировать', style: TextStyle(color: Colors.green)),
                          ],
                        ),
                      )
                    else
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
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentProvider(studentId));
              ref.invalidate(studentPaymentsProvider(studentId));
              ref.invalidate(subscriptionsStreamProvider(studentId));
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
                ),
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
                        onFreeze: canEditStudent ? () => _showFreezeDialog(context, ref, sub) : null,
                        onUnfreeze: canEditStudent ? () => _unfreezeSubscription(context, ref, sub) : null,
                        onExtend: canEditStudent ? () => _showExtendDialog(context, ref, sub) : null,
                      )).toList(),
                    );
                  },
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
    final phoneController = TextEditingController(text: student.phone ?? '');
    final commentController = TextEditingController(text: student.comment ?? '');
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
                final success = await controller.update(
                  studentId,
                  institutionId: institutionId,
                  name: nameController.text.trim(),
                  phone: phoneController.text.isEmpty ? null : phoneController.text.trim(),
                  comment: commentController.text.isEmpty ? null : commentController.text.trim(),
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

  const _BalanceAndCostCard({
    required this.student,
    required this.hasDebt,
    required this.studentId,
    this.onAddPayment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avgCostAsync = ref.watch(studentAvgCostProvider(studentId));
    final formatter = NumberFormat('#,###', 'ru_RU');

    return Card(
      color: (hasDebt ? AppColors.error : AppColors.primary).withOpacity(0.1),
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
                    ],
                  ),
                ),
                // Разделитель
                Container(
                  width: 1,
                  height: 60,
                  color: hasDebt
                      ? AppColors.error.withOpacity(0.3)
                      : AppColors.primary.withOpacity(0.3),
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
              ],
            ),
            if (onAddPayment != null) ...[
              const SizedBox(height: 16),
              // Кнопка добавить оплату
              ElevatedButton.icon(
                onPressed: onAddPayment,
                icon: const Icon(Icons.add),
                label: const Text(AppStrings.addPayment),
              ),
            ],
          ],
        ),
      ),
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
  final VoidCallback? onFreeze;
  final VoidCallback? onUnfreeze;
  final VoidCallback? onExtend;

  const _SubscriptionCard({
    required this.subscription,
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
            ? AppColors.warning.withOpacity(0.1)
            : AppColors.success.withOpacity(0.1);
        break;
      case SubscriptionStatus.frozen:
        statusColor = AppColors.info;
        cardColor = AppColors.info.withOpacity(0.1);
        break;
      case SubscriptionStatus.expired:
        statusColor = AppColors.error;
        cardColor = AppColors.error.withOpacity(0.1);
        break;
      case SubscriptionStatus.exhausted:
        statusColor = AppColors.textSecondary;
        cardColor = AppColors.textSecondary.withOpacity(0.1);
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
                    color: statusColor.withOpacity(0.2),
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
                      color: AppColors.primary.withOpacity(0.1),
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
                      color: AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Скоро истекает',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                      ),
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
              backgroundColor: statusColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
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
                      icon: Icon(Icons.ac_unit, size: 18, color: AppColors.info),
                      label: const Text('Заморозить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: BorderSide(color: AppColors.info.withOpacity(0.5)),
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
                      icon: Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                      label: const Text('Продлить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
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
      validityDays: int.parse(_validityController.text),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      color: Colors.grey[300],
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
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: AppColors.primary),
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
                      value: currentPlan,
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
                                    fillColor: Colors.white,
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
          final membersAsync = ref.watch(membersProvider(institutionId));
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
                            backgroundColor: color.withOpacity(0.2),
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
