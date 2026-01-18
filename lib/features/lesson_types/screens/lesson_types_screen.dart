import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/core/widgets/empty_state.dart';
import 'package:kabinet/core/widgets/color_picker_field.dart';
import 'package:kabinet/features/lesson_types/providers/lesson_type_provider.dart';
import 'package:kabinet/shared/models/lesson_type.dart';
import 'package:kabinet/l10n/app_localizations.dart';

/// Экран управления типами занятий
class LessonTypesScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const LessonTypesScreen({super.key, required this.institutionId});

  @override
  ConsumerState<LessonTypesScreen> createState() => _LessonTypesScreenState();
}

class _LessonTypesScreenState extends ConsumerState<LessonTypesScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lessonTypesAsync = ref.watch(lessonTypesProvider(widget.institutionId));
    final lessonTypes = lessonTypesAsync.valueOrNull ?? [];
    final hasItems = lessonTypes.isNotEmpty;

    // Показать ошибку контроллера
    ref.listen(lessonTypeControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorView.getLocalizedErrorMessage(next.error!, l10n)),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.lessonTypes),
      ),
      floatingActionButton: hasItems
          ? FloatingActionButton(
              onPressed: () => _showAddSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: Builder(
        builder: (context) {
          final lessonTypes = lessonTypesAsync.valueOrNull;

          // Показываем loading только при первой загрузке
          if (lessonTypes == null) {
            return const LoadingIndicator();
          }

          // Всегда показываем данные (даже если фоном ошибка)
          if (lessonTypes.isEmpty) {
            return EmptyState(
              icon: Icons.event_note_outlined,
              title: l10n.noLessonTypes,
              subtitle: l10n.addFirstLessonType,
              action: ElevatedButton.icon(
                onPressed: () => _showAddSheet(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.addType),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              try {
                ref.invalidate(lessonTypesProvider(widget.institutionId));
                await ref.read(lessonTypesProvider(widget.institutionId).future);
              } catch (e) {
                debugPrint('[LessonTypesScreen] refresh error: $e');
              }
            },
            child: ListView.builder(
              padding: AppSizes.paddingAllM,
              itemCount: lessonTypes.length,
              itemBuilder: (context, index) {
                final lessonType = lessonTypes[index];
                return _LessonTypeCard(
                  lessonType: lessonType,
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
      builder: (context) => _AddLessonTypeSheet(
        institutionId: widget.institutionId,
      ),
    );
  }
}

/// Карточка типа занятия
class _LessonTypeCard extends ConsumerWidget {
  final LessonType lessonType;
  final String institutionId;

  const _LessonTypeCard({
    required this.lessonType,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final color = lessonType.color != null
        ? hexToColor(lessonType.color!)
        : AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
          child: Icon(
            lessonType.isGroup ? Icons.groups : Icons.person,
            color: color,
          ),
        ),
        title: Text(
          lessonType.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${lessonType.defaultDurationMinutes} ${l10n.minutes}${lessonType.defaultPrice != null ? ' • ${lessonType.defaultPrice!.toStringAsFixed(0)} ₸' : ''}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showOptions(context, ref),
        ),
        onTap: () => _showEditSheet(context),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                _showEditSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
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
      builder: (dialogContext) => _EditLessonTypeSheet(
        lessonType: lessonType,
        institutionId: institutionId,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteLessonTypeQuestion),
        content: Text(
          l10n.lessonTypeWillBeDeleted(lessonType.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final controller = ref.read(lessonTypeControllerProvider.notifier);
              final success = await controller.archive(lessonType.id, institutionId);
              if (success) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.lessonTypeDeleted),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

/// Форма создания нового типа занятия (без выбора цвета - случайный)
class _AddLessonTypeSheet extends ConsumerStatefulWidget {
  final String institutionId;

  const _AddLessonTypeSheet({required this.institutionId});

  @override
  ConsumerState<_AddLessonTypeSheet> createState() => _AddLessonTypeSheetState();
}

class _AddLessonTypeSheetState extends ConsumerState<_AddLessonTypeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _customDurationController = TextEditingController();
  int _selectedDuration = 60;
  bool _isCustomDuration = false;
  bool _isGroup = false;
  bool _isLoading = false;

  static const _popularDurations = [30, 45, 60, 90, 120];

  int get _effectiveDuration {
    if (_isCustomDuration) {
      return int.tryParse(_customDurationController.text) ?? 60;
    }
    return _selectedDuration;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  Future<void> _createLessonType() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    // Валидация кастомной длительности
    if (_isCustomDuration) {
      final customValue = int.tryParse(_customDurationController.text);
      if (customValue == null || customValue < 5 || customValue > 480) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.durationValidationError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(lessonTypeControllerProvider.notifier);
      final lessonType = await controller.create(
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        defaultDurationMinutes: _effectiveDuration,
        defaultPrice: _priceController.text.isNotEmpty
            ? double.tryParse(_priceController.text)
            : null,
        isGroup: _isGroup,
        color: getRandomPresetColor(), // Случайный цвет
      );

      if (lessonType != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.lessonTypeCreated(lessonType.name)),
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
    final l10n = AppLocalizations.of(context);
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
                        Icons.event_note,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.newLessonType,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.fillLessonTypeData,
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
                    labelText: l10n.nameRequired,
                    hintText: l10n.nameHintExample,
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.isEmpty ? l10n.enterNameValidation : null,
                ),
                const SizedBox(height: 16),

                // Длительность
                Text(
                  l10n.duration,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._popularDurations.map((duration) {
                      final isSelected = !_isCustomDuration && _selectedDuration == duration;
                      return ChoiceChip(
                        label: Text('$duration ${l10n.minutes}'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedDuration = duration;
                            _isCustomDuration = false;
                            _customDurationController.clear();
                          });
                        },
                        showCheckmark: false,
                      );
                    }),
                    ChoiceChip(
                      label: Text(l10n.other),
                      selected: _isCustomDuration,
                      onSelected: (_) {
                        setState(() => _isCustomDuration = true);
                      },
                      showCheckmark: false,
                    ),
                  ],
                ),

                // Поле кастомной длительности
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _isCustomDuration
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextFormField(
                            controller: _customDurationController,
                            decoration: InputDecoration(
                              labelText: l10n.customDuration,
                              suffixText: l10n.minutes,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                            ),
                            keyboardType: TextInputType.number,
                            autofocus: true,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Цена
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: l10n.defaultPrice,
                    hintText: l10n.optional,
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: '₸',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Групповое занятие
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Text(l10n.groupLessonSwitch),
                    subtitle: Text(
                      _isGroup ? l10n.multipleStudents : l10n.oneStudent,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                const SizedBox(height: 28),

                // Кнопка
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createLessonType,
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
                        : Text(
                            l10n.createType,
                            style: const TextStyle(
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

/// Форма редактирования типа занятия (с выбором цвета)
class _EditLessonTypeSheet extends ConsumerStatefulWidget {
  final LessonType lessonType;
  final String institutionId;

  const _EditLessonTypeSheet({
    required this.lessonType,
    required this.institutionId,
  });

  @override
  ConsumerState<_EditLessonTypeSheet> createState() => _EditLessonTypeSheetState();
}

class _EditLessonTypeSheetState extends ConsumerState<_EditLessonTypeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _customDurationController;
  late int _selectedDuration;
  late bool _isCustomDuration;
  late bool _isGroup;
  late String? _selectedColor;
  bool _isLoading = false;

  static const _popularDurations = [30, 45, 60, 90, 120];

  int get _effectiveDuration {
    if (_isCustomDuration) {
      return int.tryParse(_customDurationController.text) ?? 60;
    }
    return _selectedDuration;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.lessonType.name);
    _priceController = TextEditingController(
      text: widget.lessonType.defaultPrice?.toStringAsFixed(0) ?? '',
    );

    final existingDuration = widget.lessonType.defaultDurationMinutes;
    if (_popularDurations.contains(existingDuration)) {
      _selectedDuration = existingDuration;
      _isCustomDuration = false;
      _customDurationController = TextEditingController();
    } else {
      _selectedDuration = existingDuration;
      _isCustomDuration = true;
      _customDurationController = TextEditingController(text: existingDuration.toString());
    }

    _isGroup = widget.lessonType.isGroup;
    _selectedColor = widget.lessonType.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  Future<void> _updateLessonType() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    if (_isCustomDuration) {
      final customValue = int.tryParse(_customDurationController.text);
      if (customValue == null || customValue < 5 || customValue > 480) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.durationValidationError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(lessonTypeControllerProvider.notifier);
      final success = await controller.update(
        id: widget.lessonType.id,
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        defaultDurationMinutes: _effectiveDuration,
        defaultPrice: _priceController.text.isNotEmpty
            ? double.tryParse(_priceController.text)
            : null,
        isGroup: _isGroup,
        color: _selectedColor,
      );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.lessonTypeUpdated),
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
    final l10n = AppLocalizations.of(context);
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
                          Text(
                            l10n.editLessonType,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.changeLessonTypeData,
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
                    labelText: l10n.nameRequired,
                    hintText: l10n.nameHintExample,
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.isEmpty ? l10n.enterNameValidation : null,
                ),
                const SizedBox(height: 16),

                // Длительность
                Text(
                  l10n.duration,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._popularDurations.map((duration) {
                      final isSelected = !_isCustomDuration && _selectedDuration == duration;
                      return ChoiceChip(
                        label: Text('$duration ${l10n.minutes}'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedDuration = duration;
                            _isCustomDuration = false;
                            _customDurationController.clear();
                          });
                        },
                        showCheckmark: false,
                      );
                    }),
                    ChoiceChip(
                      label: Text(l10n.other),
                      selected: _isCustomDuration,
                      onSelected: (_) {
                        setState(() => _isCustomDuration = true);
                      },
                      showCheckmark: false,
                    ),
                  ],
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _isCustomDuration
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextFormField(
                            controller: _customDurationController,
                            decoration: InputDecoration(
                              labelText: l10n.customDuration,
                              suffixText: l10n.minutes,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Цена
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: l10n.defaultPrice,
                    hintText: l10n.optional,
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: '₸',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Групповое занятие
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Text(l10n.groupLessonSwitch),
                    subtitle: Text(
                      _isGroup ? l10n.multipleStudents : l10n.oneStudent,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                const SizedBox(height: 20),

                // Выбор цвета
                ColorPickerField(
                  label: l10n.color,
                  selectedColor: _selectedColor,
                  onColorChanged: (color) => setState(() => _selectedColor = color),
                ),
                const SizedBox(height: 28),

                // Кнопка
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateLessonType,
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
                        : Text(
                            l10n.save,
                            style: const TextStyle(
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
