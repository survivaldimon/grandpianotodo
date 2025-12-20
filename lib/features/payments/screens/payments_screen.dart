import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/features/payments/providers/payment_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/shared/models/payment.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:collection/collection.dart';

/// Экран списка оплат
class PaymentsScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const PaymentsScreen({super.key, required this.institutionId});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  PeriodParams get _periodParams {
    final startOfMonth = _selectedMonth;
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
    return PeriodParams(widget.institutionId, startOfMonth, endOfMonth);
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentsProvider(_periodParams));
    final totalAsync = ref.watch(periodTotalProvider(_periodParams));
    final monthName = DateFormat('LLLL yyyy', 'ru').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.payments),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPaymentDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPaymentDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Period selector
          Padding(
            padding: AppSizes.paddingAllM,
            child: Row(
              children: [
                const Text('Период:'),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _showMonthPicker,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(monthName[0].toUpperCase() + monthName.substring(1)),
                ),
              ],
            ),
          ),
          // Total
          Container(
            margin: AppSizes.paddingHorizontalM,
            padding: AppSizes.paddingAllM,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Итого:'),
                totalAsync.when(
                  data: (total) => Text(
                    _formatCurrency(total),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                  ),
                  loading: () => const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const Text('—'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Payments list
          Expanded(
            child: paymentsAsync.when(
              loading: () => const LoadingIndicator(),
              error: (error, _) => ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(paymentsProvider(_periodParams)),
              ),
              data: (payments) {
                if (payments.isEmpty) {
                  return const Center(
                    child: Text(
                      'Нет оплат за этот период',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(paymentsProvider(_periodParams));
                    ref.invalidate(periodTotalProvider(_periodParams));
                  },
                  child: _buildPaymentsList(payments),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList(List<Payment> payments) {
    // Group payments by date
    final groupedPayments = groupBy<Payment, String>(
      payments,
      (p) => DateFormat('yyyy-MM-dd').format(p.paidAt),
    );

    final sortedDates = groupedPayments.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: AppSizes.paddingHorizontalM,
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateStr = sortedDates[index];
        final date = DateTime.parse(dateStr);
        final dayPayments = groupedPayments[dateStr]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(date: DateFormat('d MMMM', 'ru').format(date)),
            ...dayPayments.map((p) => _PaymentCard(
              payment: p,
              institutionId: widget.institutionId,
              onChanged: () {
                ref.invalidate(paymentsProvider(_periodParams));
                ref.invalidate(periodTotalProvider(_periodParams));
              },
            )),
          ],
        );
      },
    );
  }

  Future<void> _showMonthPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      locale: const Locale('ru'),
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'ru_RU');
    return '${formatter.format(amount.toInt())} ₸';
  }

  void _showAddPaymentDialog(BuildContext context) {
    final studentsAsync = ref.read(studentsProvider(widget.institutionId));

    studentsAsync.when(
      loading: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Загрузка списка учеников...')),
        );
      },
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки учеников: $e')),
        );
      },
      data: (students) {
        if (students.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сначала добавьте учеников')),
          );
          return;
        }
        _showPaymentForm(context, students);
      },
    );
  }

  void _showPaymentForm(BuildContext context, List<Student> students) {
    Student? selectedStudent;
    final amountController = TextEditingController();
    final lessonsController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Добавить оплату'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Student>(
                    decoration: const InputDecoration(
                      labelText: 'Ученик',
                      prefixIcon: Icon(Icons.person),
                    ),
                    value: selectedStudent,
                    items: students.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name),
                    )).toList(),
                    onChanged: (student) {
                      setState(() => selectedStudent = student);
                    },
                    validator: (v) => v == null ? 'Выберите ученика' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                      prefixIcon: Icon(Icons.payments),
                      suffixText: '₽',
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
                      prefixIcon: Icon(Icons.event),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && selectedStudent != null) {
                  final controller = ref.read(paymentControllerProvider.notifier);
                  final payment = await controller.create(
                    institutionId: widget.institutionId,
                    studentId: selectedStudent!.id,
                    amount: double.parse(amountController.text),
                    lessonsCount: int.parse(lessonsController.text),
                  );
                  if (payment != null && dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ref.invalidate(paymentsProvider(_periodParams));
                    ref.invalidate(periodTotalProvider(_periodParams));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Оплата добавлена'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        date,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _PaymentCard extends ConsumerWidget {
  final Payment payment;
  final String institutionId;
  final VoidCallback onChanged;

  const _PaymentCard({
    required this.payment,
    required this.institutionId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat('#,###', 'ru_RU');
    final amountStr = '${formatter.format(payment.amount.toInt())} ₸';
    final studentName = payment.student?.name ?? 'Ученик';
    final planName = payment.paymentPlan?.name ?? (payment.isCorrection ? 'Корректировка' : 'Оплата');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showPaymentOptions(context, ref),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(studentName, overflow: TextOverflow.ellipsis)),
            Text(
              amountStr,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: payment.isCorrection && payment.amount < 0
                    ? AppColors.error
                    : null,
              ),
            ),
          ],
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(planName),
            Text('${payment.lessonsCount} занятий'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }

  void _showPaymentOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final amountController = TextEditingController(text: payment.amount.toInt().toString());
    final lessonsController = TextEditingController(text: payment.lessonsCount.toString());
    final commentController = TextEditingController(text: payment.comment ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Редактировать оплату'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Сумма',
                    prefixIcon: Icon(Icons.payments),
                    suffixText: '₸',
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
                    prefixIcon: Icon(Icons.event),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите количество';
                    if (int.tryParse(v) == null) return 'Неверное число';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    prefixIcon: Icon(Icons.comment),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final controller = ref.read(paymentControllerProvider.notifier);
                final result = await controller.updatePayment(
                  payment.id,
                  studentId: payment.studentId,
                  oldLessonsCount: payment.lessonsCount,
                  amount: double.parse(amountController.text),
                  lessonsCount: int.parse(lessonsController.text),
                  comment: commentController.text.isEmpty ? null : commentController.text,
                );
                if (result != null && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  onChanged();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Оплата обновлена'),
                      backgroundColor: Colors.green,
                    ),
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

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить оплату?'),
        content: Text(
          'Оплата на сумму ${payment.amount.toInt()} ₸ будет удалена. '
          'Баланс ученика уменьшится на ${payment.lessonsCount} занятий.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final controller = ref.read(paymentControllerProvider.notifier);
              final success = await controller.deletePayment(
                payment.id,
                studentId: payment.studentId,
              );
              if (success) {
                onChanged();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Оплата удалена'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                final state = ref.read(paymentControllerProvider);
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Ошибка удаления: ${state.error}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}
