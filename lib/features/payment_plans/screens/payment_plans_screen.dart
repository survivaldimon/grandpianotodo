import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/core/widgets/empty_state.dart';
import 'package:kabinet/features/payment_plans/providers/payment_plan_provider.dart';
import 'package:kabinet/shared/models/payment_plan.dart';

/// Экран управления тарифами оплаты
class PaymentPlansScreen extends ConsumerWidget {
  final String institutionId;

  const PaymentPlansScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(paymentPlansProvider(institutionId));

    // Показать ошибку контроллера
    ref.listen(paymentPlanControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тарифы оплаты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: plansAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(paymentPlansProvider(institutionId)),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return EmptyState(
              icon: Icons.credit_card,
              title: 'Нет тарифов',
              subtitle: 'Добавьте первый тариф оплаты',
              action: ElevatedButton.icon(
                onPressed: () => _showAddDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(paymentPlansProvider(institutionId));
              await ref.read(paymentPlansProvider(institutionId).future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                return _PaymentPlanCard(
                  plan: plan,
                  onEdit: () => _showEditDialog(context, ref, plan),
                  onDelete: () => _confirmDelete(context, ref, plan),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final lessonsController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый тариф'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    hintText: 'Например: Абонемент на 8 занятий',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lessonsController,
                  decoration: const InputDecoration(
                    labelText: 'Количество занятий',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите количество';
                    final num = int.tryParse(v);
                    if (num == null || num <= 0) return 'Некорректное значение';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Цена (₽)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите цену';
                    final num = double.tryParse(v);
                    if (num == null || num <= 0) return 'Некорректное значение';
                    return null;
                  },
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
                final controller =
                    ref.read(paymentPlanControllerProvider.notifier);
                final plan = await controller.create(
                  institutionId: institutionId,
                  name: nameController.text.trim(),
                  lessonsCount: int.parse(lessonsController.text),
                  price: double.parse(priceController.text),
                );
                if (plan != null && context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, PaymentPlan plan) {
    final nameController = TextEditingController(text: plan.name);
    final priceController = TextEditingController(text: plan.price.toString());
    final lessonsController =
        TextEditingController(text: plan.lessonsCount.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать тариф'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lessonsController,
                  decoration: const InputDecoration(
                    labelText: 'Количество занятий',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите количество';
                    final num = int.tryParse(v);
                    if (num == null || num <= 0) return 'Некорректное значение';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Цена (₽)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите цену';
                    final num = double.tryParse(v);
                    if (num == null || num <= 0) return 'Некорректное значение';
                    return null;
                  },
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
                final controller =
                    ref.read(paymentPlanControllerProvider.notifier);
                final success = await controller.update(
                  id: plan.id,
                  institutionId: institutionId,
                  name: nameController.text.trim(),
                  lessonsCount: int.parse(lessonsController.text),
                  price: double.parse(priceController.text),
                );
                if (success && context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, PaymentPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить тариф?'),
        content: Text(
            'Вы уверены, что хотите удалить "${plan.name}"? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final controller =
                  ref.read(paymentPlanControllerProvider.notifier);
              final success = await controller.archive(plan.id, institutionId);
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Тариф удален')),
                );
              }
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentPlanCard extends StatelessWidget {
  final PaymentPlan plan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PaymentPlanCard({
    required this.plan,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
          child: Text(
            '${plan.lessonsCount}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Text(plan.name),
        subtitle: Text(
          '${plan.price.toStringAsFixed(0)} ₽ • ${plan.pricePerLesson.toStringAsFixed(0)} ₽/занятие',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Редактировать'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Удалить', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
