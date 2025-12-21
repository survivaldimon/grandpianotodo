import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/core/widgets/empty_state.dart';
import 'package:kabinet/features/lesson_types/providers/lesson_type_provider.dart';
import 'package:kabinet/shared/models/lesson_type.dart';

/// Экран управления типами занятий
class LessonTypesScreen extends ConsumerWidget {
  final String institutionId;

  const LessonTypesScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonTypesAsync = ref.watch(lessonTypesProvider(institutionId));

    // Показать ошибку контроллера
    ref.listen(lessonTypeControllerProvider, (prev, next) {
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
        title: const Text('Типы занятий'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: lessonTypesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(lessonTypesProvider(institutionId)),
        ),
        data: (lessonTypes) {
          if (lessonTypes.isEmpty) {
            return EmptyState(
              icon: Icons.event_note,
              title: 'Нет типов занятий',
              subtitle: 'Добавьте первый тип занятия',
              action: ElevatedButton.icon(
                onPressed: () => _showAddDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(lessonTypesProvider(institutionId));
              await ref.read(lessonTypesProvider(institutionId).future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: lessonTypes.length,
              itemBuilder: (context, index) {
                final lessonType = lessonTypes[index];
                return _LessonTypeCard(
                  lessonType: lessonType,
                  onEdit: () => _showEditDialog(context, ref, lessonType),
                  onDelete: () => _confirmDelete(context, ref, lessonType),
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
    final durationController = TextEditingController(text: '60');
    final priceController = TextEditingController();
    bool isGroup = false;
    String? selectedColor;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Новый тип занятия'),
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
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Длительность (минут)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Введите длительность';
                      final num = int.tryParse(v);
                      if (num == null || num <= 0) return 'Некорректное значение';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Цена по умолчанию (необязательно)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Групповое занятие'),
                    value: isGroup,
                    onChanged: (v) => setState(() => isGroup = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  _ColorPicker(
                    selectedColor: selectedColor,
                    onColorSelected: (color) =>
                        setState(() => selectedColor = color),
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
                      ref.read(lessonTypeControllerProvider.notifier);
                  final lessonType = await controller.create(
                    institutionId: institutionId,
                    name: nameController.text.trim(),
                    defaultDurationMinutes: int.parse(durationController.text),
                    defaultPrice: priceController.text.isNotEmpty
                        ? double.tryParse(priceController.text)
                        : null,
                    isGroup: isGroup,
                    color: selectedColor,
                  );
                  if (lessonType != null && context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, LessonType lessonType) {
    final nameController = TextEditingController(text: lessonType.name);
    final durationController =
        TextEditingController(text: lessonType.defaultDurationMinutes.toString());
    final priceController = TextEditingController(
        text: lessonType.defaultPrice?.toString() ?? '');
    bool isGroup = lessonType.isGroup;
    String? selectedColor = lessonType.color;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Редактировать тип занятия'),
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
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Длительность (минут)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Введите длительность';
                      final num = int.tryParse(v);
                      if (num == null || num <= 0) return 'Некорректное значение';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Цена по умолчанию (необязательно)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Групповое занятие'),
                    value: isGroup,
                    onChanged: (v) => setState(() => isGroup = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  _ColorPicker(
                    selectedColor: selectedColor,
                    onColorSelected: (color) =>
                        setState(() => selectedColor = color),
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
                      ref.read(lessonTypeControllerProvider.notifier);
                  final success = await controller.update(
                    id: lessonType.id,
                    institutionId: institutionId,
                    name: nameController.text.trim(),
                    defaultDurationMinutes: int.parse(durationController.text),
                    defaultPrice: priceController.text.isNotEmpty
                        ? double.tryParse(priceController.text)
                        : null,
                    isGroup: isGroup,
                    color: selectedColor,
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
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, LessonType lessonType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить тип занятия?'),
        content: Text(
            'Вы уверены, что хотите удалить "${lessonType.name}"? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final controller =
                  ref.read(lessonTypeControllerProvider.notifier);
              final success =
                  await controller.archive(lessonType.id, institutionId);
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Тип занятия удален')),
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

class _LessonTypeCard extends StatelessWidget {
  final LessonType lessonType;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LessonTypeCard({
    required this.lessonType,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = lessonType.color != null
        ? Color(int.parse('FF${lessonType.color!.replaceAll('#', '')}', radix: 16))
        : AppColors.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(
            lessonType.isGroup ? Icons.groups : Icons.person,
            color: color,
          ),
        ),
        title: Text(lessonType.name),
        subtitle: Text(
          '${lessonType.defaultDurationMinutes} мин${lessonType.defaultPrice != null ? ' • ${lessonType.defaultPrice!.toStringAsFixed(0)} ₸' : ''}',
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

class _ColorPicker extends StatelessWidget {
  final String? selectedColor;
  final ValueChanged<String> onColorSelected;

  const _ColorPicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  static const colors = [
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#FF9800', // Orange
    '#9C27B0', // Purple
    '#F44336', // Red
    '#00BCD4', // Cyan
    '#795548', // Brown
    '#607D8B', // Blue Grey
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Цвет',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((colorHex) {
            final color = Color(int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16));
            final isSelected = selectedColor == colorHex;

            return GestureDetector(
              onTap: () => onColorSelected(colorHex),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: isSelected
                      ? [BoxShadow(color: color, blurRadius: 8)]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
