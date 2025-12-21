import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/features/payments/providers/payment_provider.dart';
import 'package:kabinet/shared/models/payment.dart';
import 'package:kabinet/shared/models/student.dart';
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

    return studentAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(studentProvider(studentId)),
        ),
      ),
      data: (student) {
        final hasDebt = student.balance < 0;

        return Scaffold(
          appBar: AppBar(
            title: Text(student.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _showEditStudentDialog(context, ref, student);
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'archive') {
                    _confirmArchive(context, ref, student);
                  }
                },
                itemBuilder: (context) => [
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
            },
            child: ListView(
              padding: AppSizes.paddingAllM,
              children: [
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

                // Prepaid lessons
                Card(
                  color: (hasDebt ? AppColors.error : AppColors.primary).withOpacity(0.1),
                  child: Padding(
                    padding: AppSizes.paddingAllL,
                    child: Column(
                      children: [
                        Text(
                          AppStrings.prepaidLessons.toUpperCase(),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          student.balance.toString(),
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: hasDebt ? AppColors.error : AppColors.primary,
                              ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            _showAddPaymentDialog(context, ref);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text(AppStrings.addPayment),
                        ),
                      ],
                    ),
                  ),
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
                  error: (e, _) => Text('Ошибка: $e'),
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

  void _showAddPaymentDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    final lessonsController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить оплату'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Сумма (₸)',
                  hintText: '20000',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите сумму';
                  if (double.tryParse(v) == null) return 'Неверная сумма';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: lessonsController,
                decoration: const InputDecoration(
                  labelText: 'Количество занятий',
                  hintText: '8',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите количество';
                  if (int.tryParse(v) == null) return 'Неверное число';
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
                final controller = ref.read(paymentControllerProvider.notifier);
                final payment = await controller.create(
                  institutionId: institutionId,
                  studentId: studentId,
                  amount: double.parse(amountController.text),
                  lessonsCount: int.parse(lessonsController.text),
                );
                if (payment != null && context.mounted) {
                  Navigator.pop(context);
                  ref.invalidate(studentProvider(studentId));
                }
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final String date;
  final String time;
  final String title;
  final String status;
  final Color statusColor;

  const _HistoryItem({
    required this.date,
    required this.time,
    required this.title,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(date, style: Theme.of(context).textTheme.bodySmall),
          Text(time, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      title: Text(title),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          status,
          style: TextStyle(color: statusColor, fontSize: 12),
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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
      title: Text(amountStr, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${payment.lessonsCount} занятий'),
      trailing: payment.isCorrection
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Корректировка',
                style: TextStyle(color: AppColors.warning, fontSize: 10),
              ),
            )
          : null,
    );
  }
}
