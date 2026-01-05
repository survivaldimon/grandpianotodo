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
            content: Text(ErrorView.getUserFriendlyMessage(next.error!)),
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
            onPressed: () => _showAddSheet(context, ref),
          ),
        ],
      ),
      body: lessonTypesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView.fromException(
          error,
          onRetry: () => ref.invalidate(lessonTypesProvider(institutionId)),
        ),
        data: (lessonTypes) {
          if (lessonTypes.isEmpty) {
            return EmptyState(
              icon: Icons.event_note,
              title: 'Нет типов занятий',
              subtitle: 'Добавьте первый тип занятия',
              action: ElevatedButton.icon(
                onPressed: () => _showAddSheet(context, ref),
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
                  onEdit: () => _showEditSheet(context, ref, lessonType),
                  onDelete: () => _confirmDelete(context, ref, lessonType),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LessonTypeFormSheet(
        institutionId: institutionId,
        ref: ref,
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, LessonType lessonType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LessonTypeFormSheet(
        institutionId: institutionId,
        ref: ref,
        lessonType: lessonType,
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

/// BottomSheet форма для создания/редактирования типа занятия
class _LessonTypeFormSheet extends StatefulWidget {
  final String institutionId;
  final WidgetRef ref;
  final LessonType? lessonType;

  const _LessonTypeFormSheet({
    required this.institutionId,
    required this.ref,
    this.lessonType,
  });

  @override
  State<_LessonTypeFormSheet> createState() => _LessonTypeFormSheetState();
}

class _LessonTypeFormSheetState extends State<_LessonTypeFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _customDurationController;
  int _selectedDuration = 60;
  bool _isCustomDuration = false;
  bool _isGroup = false;
  String? _selectedColor;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  bool get _isEditing => widget.lessonType != null;

  static const _popularDurations = [30, 45, 60, 90, 120];

  static const _colors = [
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#FF9800', // Orange
    '#9C27B0', // Purple
    '#F44336', // Red
    '#00BCD4', // Cyan
    '#795548', // Brown
    '#607D8B', // Blue Grey
    '#E91E63', // Pink
    '#009688', // Teal
  ];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.lessonType?.name ?? '');
    _priceController = TextEditingController(
        text: widget.lessonType?.defaultPrice?.toStringAsFixed(0) ?? '');

    final existingDuration = widget.lessonType?.defaultDurationMinutes ?? 60;
    // Проверяем, является ли существующая длительность нестандартной
    if (_popularDurations.contains(existingDuration)) {
      _selectedDuration = existingDuration;
      _isCustomDuration = false;
      _customDurationController = TextEditingController();
    } else {
      _selectedDuration = existingDuration;
      _isCustomDuration = true;
      _customDurationController = TextEditingController(text: existingDuration.toString());
    }

    _isGroup = widget.lessonType?.isGroup ?? false;
    _selectedColor = widget.lessonType?.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  int get _effectiveDuration {
    if (_isCustomDuration) {
      return int.tryParse(_customDurationController.text) ?? 60;
    }
    return _selectedDuration;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Дополнительная валидация кастомной длительности
    if (_isCustomDuration) {
      final customValue = int.tryParse(_customDurationController.text);
      if (customValue == null || customValue < 5 || customValue > 480) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Длительность должна быть от 5 до 480 минут'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final controller = widget.ref.read(lessonTypeControllerProvider.notifier);

    bool success = false;
    if (_isEditing) {
      success = await controller.update(
        id: widget.lessonType!.id,
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        defaultDurationMinutes: _effectiveDuration,
        defaultPrice: _priceController.text.isNotEmpty
            ? double.tryParse(_priceController.text)
            : null,
        isGroup: _isGroup,
        color: _selectedColor,
      );
    } else {
      final lessonType = await controller.create(
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        defaultDurationMinutes: _effectiveDuration,
        defaultPrice: _priceController.text.isNotEmpty
            ? double.tryParse(_priceController.text)
            : null,
        isGroup: _isGroup,
        color: _selectedColor,
      );
      success = lessonType != null;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Индикатор перетаскивания
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Заголовок с иконкой
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_note,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isEditing ? 'Редактировать тип занятия' : 'Новый тип занятия',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),

                // Поле названия
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    hintText: 'Например: Индивидуальное',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Введите название' : null,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: !_isEditing,
                ),
                const SizedBox(height: 20),

                // Выбор длительности
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Длительность',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Популярные длительности
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._popularDurations.map((duration) {
                      final isSelected = !_isCustomDuration && _selectedDuration == duration;
                      return ChoiceChip(
                        label: Text('$duration мин'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedDuration = duration;
                            _isCustomDuration = false;
                            _customDurationController.clear();
                          });
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                        side: isSelected
                            ? const BorderSide(color: AppColors.primary, width: 1.5)
                            : null,
                        showCheckmark: false,
                      );
                    }),
                    // Chip "Другое"
                    ChoiceChip(
                      label: const Text('Другое'),
                      selected: _isCustomDuration,
                      onSelected: (_) {
                        setState(() {
                          _isCustomDuration = true;
                        });
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _isCustomDuration ? AppColors.primary : null,
                        fontWeight: _isCustomDuration ? FontWeight.bold : null,
                      ),
                      side: _isCustomDuration
                          ? const BorderSide(color: AppColors.primary, width: 1.5)
                          : null,
                      showCheckmark: false,
                    ),
                  ],
                ),

                // Поле ввода кастомной длительности
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _isCustomDuration
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _customDurationController,
                                  decoration: InputDecoration(
                                    labelText: 'Своя длительность',
                                    hintText: 'Введите минуты',
                                    suffixText: 'мин',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  autofocus: true,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Поле цены
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: 'Цена по умолчанию',
                    hintText: 'Необязательно',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: '₸',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Переключатель группового занятия
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: const Text('Групповое занятие'),
                    subtitle: Text(
                      _isGroup
                          ? 'Несколько учеников одновременно'
                          : 'Один ученик',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    secondary: Icon(
                      _isGroup ? Icons.groups : Icons.person,
                      color: AppColors.primary,
                    ),
                    value: _isGroup,
                    onChanged: (v) => setState(() => _isGroup = v),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Выбор цвета
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Цвет',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colors.map((colorHex) {
                    final color = Color(
                        int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16));
                    final isSelected = _selectedColor == colorHex;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = colorHex),
                      child: Container(
                        width: 40,
                        height: 40,
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
                const SizedBox(height: 32),

                // Кнопка сохранения
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Сохранить' : 'Создать'),
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
