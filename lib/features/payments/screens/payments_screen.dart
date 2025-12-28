import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/payments/providers/payment_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/shared/models/payment.dart';
import 'package:kabinet/shared/models/payment_plan.dart';
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
    // Используем StreamProvider для realtime обновлений
    final paymentsAsync = ref.watch(paymentsStreamByPeriodProvider(_periodParams));
    final monthName = DateFormat('LLLL yyyy', 'ru').format(_selectedMonth);

    // Получаем права текущего пользователя
    final permissions = ref.watch(myPermissionsProvider(widget.institutionId));
    final institutionAsync = ref.watch(currentInstitutionProvider(widget.institutionId));
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

    // Проверяем, является ли пользователь владельцем или админом
    final isOwner = institutionAsync.maybeWhen(
      data: (inst) => inst.ownerId == currentUserId,
      orElse: () => false,
    );
    final isAdmin = ref.watch(isAdminProvider(widget.institutionId));
    final hasFullAccess = isOwner || isAdmin;

    // Право на добавление оплат (для своих или для всех)
    final canAddPayments = hasFullAccess ||
        (permissions?.addPaymentsForOwnStudents ?? false) ||
        (permissions?.addPaymentsForAllStudents ?? false);

    // Право на добавление оплат для всех учеников
    final canAddForAllStudents = hasFullAccess ||
        (permissions?.addPaymentsForAllStudents ?? false);

    // Права на просмотр оплат
    final canViewAllPayments = hasFullAccess ||
        (permissions?.viewAllPayments ?? false);
    final canViewOwnStudentsPayments = permissions?.viewOwnStudentsPayments ?? true;
    final canViewAnyPayments = canViewAllPayments || canViewOwnStudentsPayments;

    // ID своих учеников для фильтрации
    final myStudentIdsAsync = ref.watch(myStudentIdsProvider(widget.institutionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.payments),
        actions: [
          if (canAddPayments)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddPaymentDialog(context, canAddForAllStudents),
            ),
        ],
      ),
      floatingActionButton: canAddPayments
          ? FloatingActionButton(
              onPressed: () => _showAddPaymentDialog(context, canAddForAllStudents),
              child: const Icon(Icons.add),
            )
          : null,
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
          // Total — считаем из realtime данных
          if (canViewAnyPayments)
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
                  Text(canViewAllPayments ? 'Итого:' : 'Итого (ваши ученики):'),
                  paymentsAsync.when(
                    data: (payments) {
                      double total;
                      if (canViewAllPayments) {
                        // Сумма всех оплат
                        total = payments.fold<double>(0, (sum, p) => sum + p.amount);
                      } else {
                        // Сумма только оплат своих учеников
                        final myStudentIds = myStudentIdsAsync.valueOrNull ?? {};
                        total = payments
                            .where((p) {
                              if (myStudentIds.contains(p.studentId)) {
                                return true;
                              }
                              if (p.subscription?.members != null) {
                                return p.subscription!.members!.any(
                                  (m) => myStudentIds.contains(m.studentId),
                                );
                              }
                              return false;
                            })
                            .fold<double>(0, (sum, p) => sum + p.amount);
                      }
                      return Text(
                        _formatCurrency(total),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                      );
                    },
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
            child: !canViewAnyPayments
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
                        SizedBox(height: 16),
                        Text(
                          'Нет доступа к просмотру оплат',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : paymentsAsync.when(
                    loading: () => const LoadingIndicator(),
                    error: (error, _) => ErrorView.fromException(
                      error,
                      onRetry: () => ref.invalidate(paymentsProvider(_periodParams)),
                    ),
                    data: (payments) {
                      // Если нужна фильтрация по своим ученикам, ждём загрузки myStudentIds
                      if (!canViewAllPayments && myStudentIdsAsync.isLoading) {
                        return const LoadingIndicator();
                      }

                      // Фильтруем оплаты по правам
                      List<Payment> filteredPayments = payments;
                      final myStudentIds = myStudentIdsAsync.valueOrNull ?? {};

                      if (!canViewAllPayments) {
                        // Показываем только оплаты своих учеников
                        filteredPayments = payments.where((p) {
                          // Проверяем основного ученика
                          if (myStudentIds.contains(p.studentId)) {
                            return true;
                          }
                          // Для семейных абонементов проверяем всех участников
                          if (p.subscription?.members != null) {
                            return p.subscription!.members!.any(
                              (m) => myStudentIds.contains(m.studentId),
                            );
                          }
                          return false;
                        }).toList();
                      }

                      if (filteredPayments.isEmpty) {
                        return Center(
                          child: Text(
                            canViewAllPayments
                                ? 'Нет оплат за этот период'
                                : 'Нет оплат ваших учеников за этот период',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async {
                          // Инвалидируем stream провайдер для принудительного обновления
                          ref.invalidate(paymentsStreamByPeriodProvider(_periodParams));
                          ref.invalidate(myStudentIdsProvider(widget.institutionId));
                        },
                        child: _buildPaymentsList(filteredPayments, myStudentIds),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList(List<Payment> payments, Set<String> myStudentIds) {
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
              myStudentIds: myStudentIds,
              onChanged: () {
                // Stream провайдер обновляется автоматически через realtime
                ref.invalidate(paymentsStreamByPeriodProvider(_periodParams));
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

  void _showAddPaymentDialog(BuildContext context, bool canAddForAllStudents) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _AddPaymentSheet(
        institutionId: widget.institutionId,
        canAddForAllStudents: canAddForAllStudents,
        onSuccess: () {
          // Stream провайдер обновляется автоматически через realtime
          ref.invalidate(paymentsStreamByPeriodProvider(_periodParams));
        },
      ),
    );
  }

}

/// Форма добавления оплаты
class _AddPaymentSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final bool canAddForAllStudents;
  final VoidCallback onSuccess;

  const _AddPaymentSheet({
    required this.institutionId,
    required this.canAddForAllStudents,
    required this.onSuccess,
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

  Student? _selectedStudent;
  List<Student> _selectedFamilyStudents = [];
  PaymentPlan? _selectedPlan;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _hasDiscount = false;
  double _originalPrice = 0;
  bool _isFamilyMode = false;

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
        _lessonsController.clear();
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
    // Валидация
    if (!_formKey.currentState!.validate()) return;

    if (_isFamilyMode) {
      if (_selectedFamilyStudents.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Выберите минимум 2 ученика для семейного абонемента'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      if (_selectedStudent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Выберите ученика'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

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
    Payment? payment;

    if (_isFamilyMode) {
      // Семейный абонемент
      payment = await controller.createFamilyPayment(
        institutionId: widget.institutionId,
        studentIds: _selectedFamilyStudents.map((s) => s.id).toList(),
        paymentPlanId: _selectedPlan?.id,
        amount: double.parse(_amountController.text),
        lessonsCount: int.parse(_lessonsController.text),
        validityDays: int.parse(_validityController.text),
        paidAt: _selectedDate,
        comment: comment.isEmpty ? null : comment,
      );
    } else {
      // Обычная оплата
      payment = await controller.create(
        institutionId: widget.institutionId,
        studentId: _selectedStudent!.id,
        paymentPlanId: _selectedPlan?.id,
        amount: double.parse(_amountController.text),
        lessonsCount: int.parse(_lessonsController.text),
        validityDays: int.parse(_validityController.text),
        paidAt: _selectedDate,
        comment: comment.isEmpty ? null : comment,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (payment != null) {
        widget.onSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFamilyMode
                ? 'Семейный абонемент добавлен'
                : 'Оплата добавлена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Используем разные провайдеры в зависимости от прав
    final studentsAsync = widget.canAddForAllStudents
        ? ref.watch(studentsProvider(widget.institutionId))
        : ref.watch(studentsForPaymentProvider(widget.institutionId));
    final plansAsync = ref.watch(paymentPlansProvider(widget.institutionId));
    final controllerState = ref.watch(paymentControllerProvider);

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
                            'Выберите ученика и тариф',
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

                // Переключатель семейного абонемента
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isFamilyMode
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: _isFamilyMode
                        ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.family_restroom,
                        color: _isFamilyMode ? AppColors.primary : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Семейный абонемент',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Один абонемент на несколько учеников',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isFamilyMode,
                        onChanged: (value) {
                          setState(() {
                            _isFamilyMode = value;
                            if (value) {
                              // Переносим выбранного ученика в список
                              if (_selectedStudent != null) {
                                _selectedFamilyStudents = [_selectedStudent!];
                              }
                            } else {
                              // Переносим первого выбранного в одиночный выбор
                              _selectedStudent = _selectedFamilyStudents.isNotEmpty
                                  ? _selectedFamilyStudents.first
                                  : null;
                              _selectedFamilyStudents = [];
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Ученик / Ученики
                studentsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => ErrorView.inline(e),
                  data: (students) {
                    if (students.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Сначала добавьте учеников'),
                      );
                    }

                    if (_isFamilyMode) {
                      // Мультивыбор для семейного абонемента - список с чекбоксами
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Выберите участников',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_selectedFamilyStudents.length} из ${students.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _selectedFamilyStudents.length >= 2
                                      ? AppColors.success
                                      : Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final student = students[index];
                                final isSelected = _selectedFamilyStudents.any((s) => s.id == student.id);
                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedFamilyStudents.add(student);
                                      } else {
                                        _selectedFamilyStudents.removeWhere((s) => s.id == student.id);
                                      }
                                    });
                                  },
                                  title: Text(student.name),
                                  secondary: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isSelected
                                        ? AppColors.primary
                                        : Colors.grey[200],
                                    child: Text(
                                      student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isSelected ? Colors.white : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  controlAffinity: ListTileControlAffinity.trailing,
                                  activeColor: AppColors.primary,
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                );
                              },
                            ),
                          ),
                          if (_selectedFamilyStudents.length < 2)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Выберите минимум 2 ученика',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    } else {
                      // Одиночный выбор
                      final currentStudent = _selectedStudent != null
                          ? students.where((s) => s.id == _selectedStudent!.id).firstOrNull
                          : null;
                      return DropdownButtonFormField<Student>(
                        decoration: InputDecoration(
                          labelText: 'Ученик',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        value: currentStudent,
                        items: students.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        )).toList(),
                        onChanged: (student) {
                          setState(() => _selectedStudent = student);
                        },
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

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
  final Set<String> myStudentIds;

  const _PaymentCard({
    required this.payment,
    required this.institutionId,
    required this.onChanged,
    required this.myStudentIds,
  });

  /// Проверяет, может ли пользователь управлять этой оплатой
  bool _canManagePayment(WidgetRef ref) {
    final permissions = ref.watch(myPermissionsProvider(institutionId));
    final institutionAsync = ref.watch(currentInstitutionProvider(institutionId));
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

    final isOwner = institutionAsync.maybeWhen(
      data: (inst) => inst.ownerId == currentUserId,
      orElse: () => false,
    );
    final isAdmin = ref.watch(isAdminProvider(institutionId));
    final hasFullAccess = isOwner || isAdmin;

    if (hasFullAccess) return true;
    if (permissions?.manageAllPayments ?? false) return true;

    // Проверяем, это оплата своего ученика
    if (permissions?.manageOwnStudentsPayments ?? true) {
      // Проверяем основного ученика
      if (myStudentIds.contains(payment.studentId)) {
        return true;
      }
      // Для семейных абонементов проверяем всех участников
      if (payment.subscription?.members != null) {
        if (payment.subscription!.members!.any((m) => myStudentIds.contains(m.studentId))) {
          return true;
        }
      }
    }

    return false;
  }

  /// Извлекает название типа занятия из comment если это оплата занятия
  /// Формат: lesson:LESSON_ID|LESSON_TYPE_NAME
  String? _extractLessonTypeName() {
    final comment = payment.comment;
    if (comment == null || !comment.startsWith('lesson:')) return null;
    final pipeIndex = comment.indexOf('|');
    if (pipeIndex == -1) return null;
    return comment.substring(pipeIndex + 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat('#,###', 'ru_RU');
    final amountStr = '${formatter.format(payment.amount.toInt())} ₸';

    // Для семейных абонементов показываем всех участников
    final displayName = payment.displayMemberNames.isNotEmpty
        ? payment.displayMemberNames
        : 'Ученик';

    // Сначала проверяем, это оплата занятия (lesson:ID|TYPE_NAME)
    final lessonTypeName = _extractLessonTypeName();
    final planName = lessonTypeName ??
        payment.paymentPlan?.name ??
        (payment.isCorrection ? 'Корректировка' : 'Свой вариант');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showPaymentOptions(context, ref),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(child: Text(displayName, overflow: TextOverflow.ellipsis)),
                  if (payment.isFamilySubscription) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.family_restroom, size: 16, color: Colors.purple[400]),
                  ],
                ],
              ),
            ),
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
    final canManage = _canManagePayment(ref);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Информация об оплате
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('${payment.student?.name ?? "Ученик"} — ${payment.amount.toInt()} ₸'),
              subtitle: Text('${payment.lessonsCount} занятий'),
            ),
            const Divider(),
            if (canManage) ...[
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
            ] else ...[
              const ListTile(
                leading: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                title: Text(
                  'Нет прав на редактирование',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                subtitle: Text(
                  'Вы можете редактировать только оплаты своих учеников',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
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
