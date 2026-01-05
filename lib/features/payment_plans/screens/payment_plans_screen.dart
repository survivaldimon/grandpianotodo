import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/core/widgets/empty_state.dart';
import 'package:kabinet/core/widgets/color_picker_field.dart';
import 'package:kabinet/features/payment_plans/providers/payment_plan_provider.dart';
import 'package:kabinet/shared/models/payment_plan.dart';

/// Экран управления тарифами оплаты
class PaymentPlansScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const PaymentPlansScreen({super.key, required this.institutionId});

  @override
  ConsumerState<PaymentPlansScreen> createState() => _PaymentPlansScreenState();
}

class _PaymentPlansScreenState extends ConsumerState<PaymentPlansScreen> {
  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(paymentPlansProvider(widget.institutionId));
    final plans = plansAsync.valueOrNull ?? [];
    final hasPlans = plans.isNotEmpty;

    // Показать ошибку контроллера
    ref.listen(paymentPlanControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorView.getUserFriendlyMessage(next.error!)),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тарифы оплаты'),
      ),
      floatingActionButton: hasPlans
          ? FloatingActionButton(
              onPressed: () => _showAddSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: Builder(
        builder: (context) {
          final plans = plansAsync.valueOrNull;

          // Показываем loading только при первой загрузке
          if (plans == null) {
            return const LoadingIndicator();
          }

          // Всегда показываем данные (даже если фоном ошибка)
          if (plans.isEmpty) {
            return EmptyState(
              icon: Icons.credit_card_outlined,
              title: 'Нет тарифов',
              subtitle: 'Добавьте первый тариф оплаты',
              action: ElevatedButton.icon(
                onPressed: () => _showAddSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Добавить тариф'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(paymentPlansProvider(widget.institutionId));
              await ref.read(paymentPlansProvider(widget.institutionId).future);
            },
            child: ListView.builder(
              padding: AppSizes.paddingAllM,
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                return _PaymentPlanCard(
                  plan: plan,
                  institutionId: widget.institutionId,
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _AddPlanSheet(
        institutionId: widget.institutionId,
      ),
    );
  }
}

/// Карточка тарифа
class _PaymentPlanCard extends ConsumerWidget {
  final PaymentPlan plan;
  final String institutionId;

  const _PaymentPlanCard({
    required this.plan,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = plan.color != null
        ? hexToColor(plan.color!)
        : AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
          child: Center(
            child: Text(
              '${plan.lessonsCount}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        title: Text(
          plan.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${plan.price.toStringAsFixed(0)} ₸',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${plan.pricePerLesson.toStringAsFixed(0)} ₸/занятие • ${plan.validityDays} дн.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showOptions(context, ref),
        ),
        onTap: () => _showEditSheet(context),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
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
                _showEditSheet(context);
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

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _EditPlanSheet(
        plan: plan,
        institutionId: institutionId,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить тариф?'),
        content: Text(
          'Тариф "${plan.name}" будет удалён. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final controller = ref.read(paymentPlanControllerProvider.notifier);
              final success = await controller.archive(plan.id, institutionId);
              if (success) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Тариф удалён'),
                    backgroundColor: AppColors.error,
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

/// Форма создания нового тарифа (случайный цвет)
class _AddPlanSheet extends ConsumerStatefulWidget {
  final String institutionId;

  const _AddPlanSheet({required this.institutionId});

  @override
  ConsumerState<_AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends ConsumerState<_AddPlanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lessonsController = TextEditingController();
  final _priceController = TextEditingController();
  final _validityController = TextEditingController(text: '30');
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _lessonsController.dispose();
    _priceController.dispose();
    _validityController.dispose();
    super.dispose();
  }

  Future<void> _createPlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(paymentPlanControllerProvider.notifier);
      final plan = await controller.create(
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        lessonsCount: int.parse(_lessonsController.text),
        price: double.parse(_priceController.text),
        validityDays: int.parse(_validityController.text),
        color: getRandomPresetColor(), // Случайный цвет
      );

      if (plan != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Тариф "${plan.name}" создан'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.credit_card,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Новый тариф',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Заполните данные тарифа',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Название
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Название *',
                    hintText: 'Например: Абонемент на 8 занятий',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 16),

                // Количество занятий и Цена в одной строке
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lessonsController,
                        decoration: InputDecoration(
                          labelText: 'Занятий *',
                          hintText: '8',
                          prefixIcon: const Icon(Icons.event_repeat),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Обязательно';
                          final num = int.tryParse(v);
                          if (num == null || num <= 0) return 'Ошибка';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Цена *',
                          hintText: '40000',
                          suffixText: '₸',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Обязательно';
                          final num = double.tryParse(v);
                          if (num == null || num <= 0) return 'Ошибка';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Срок действия
                TextFormField(
                  controller: _validityController,
                  decoration: InputDecoration(
                    labelText: 'Срок действия (дней) *',
                    hintText: '30',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите срок';
                    final num = int.tryParse(v);
                    if (num == null || num <= 0) return 'Некорректное значение';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Кнопка создания
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createPlan,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Создать тариф',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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

/// Форма редактирования тарифа (с выбором цвета)
class _EditPlanSheet extends ConsumerStatefulWidget {
  final PaymentPlan plan;
  final String institutionId;

  const _EditPlanSheet({
    required this.plan,
    required this.institutionId,
  });

  @override
  ConsumerState<_EditPlanSheet> createState() => _EditPlanSheetState();
}

class _EditPlanSheetState extends ConsumerState<_EditPlanSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _lessonsController;
  late final TextEditingController _priceController;
  late final TextEditingController _validityController;
  late String? _selectedColor;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plan.name);
    _lessonsController = TextEditingController(text: widget.plan.lessonsCount.toString());
    _priceController = TextEditingController(text: widget.plan.price.toStringAsFixed(0));
    _validityController = TextEditingController(text: widget.plan.validityDays.toString());
    _selectedColor = widget.plan.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lessonsController.dispose();
    _priceController.dispose();
    _validityController.dispose();
    super.dispose();
  }

  Future<void> _updatePlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(paymentPlanControllerProvider.notifier);
      final success = await controller.update(
        id: widget.plan.id,
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        lessonsCount: int.parse(_lessonsController.text),
        price: double.parse(_priceController.text),
        validityDays: int.parse(_validityController.text),
        color: _selectedColor,
      );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Тариф обновлён'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Редактировать тариф',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Измените данные тарифа',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Название
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Название *',
                    hintText: 'Например: Абонемент на 8 занятий',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 16),

                // Количество занятий и Цена в одной строке
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lessonsController,
                        decoration: InputDecoration(
                          labelText: 'Занятий *',
                          hintText: '8',
                          prefixIcon: const Icon(Icons.event_repeat),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Обязательно';
                          final num = int.tryParse(v);
                          if (num == null || num <= 0) return 'Ошибка';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Цена *',
                          hintText: '40000',
                          suffixText: '₸',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Обязательно';
                          final num = double.tryParse(v);
                          if (num == null || num <= 0) return 'Ошибка';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Срок действия
                TextFormField(
                  controller: _validityController,
                  decoration: InputDecoration(
                    labelText: 'Срок действия (дней) *',
                    hintText: '30',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите срок';
                    final num = int.tryParse(v);
                    if (num == null || num <= 0) return 'Некорректное значение';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Выбор цвета
                ColorPickerField(
                  label: 'Цвет',
                  selectedColor: _selectedColor,
                  onColorChanged: (color) => setState(() => _selectedColor = color),
                ),
                const SizedBox(height: 28),

                // Кнопка сохранения
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updatePlan,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Сохранить',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
