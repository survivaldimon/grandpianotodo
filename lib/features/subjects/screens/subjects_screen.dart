import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/core/widgets/empty_state.dart';
import 'package:kabinet/core/widgets/color_picker_field.dart';
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/shared/models/subject.dart';

/// Экран управления предметами
class SubjectsScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const SubjectsScreen({super.key, required this.institutionId});

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subjectsAsync = ref.watch(subjectsListProvider(widget.institutionId));
    final subjects = subjectsAsync.valueOrNull ?? [];
    final hasItems = subjects.isNotEmpty;

    // Показать ошибку контроллера
    ref.listen(subjectControllerProvider, (prev, next) {
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
        title: Text(l10n.subjects),
      ),
      floatingActionButton: hasItems
          ? FloatingActionButton(
              onPressed: () => _showAddSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: Builder(
        builder: (context) {
          final subjects = subjectsAsync.valueOrNull;

          // Показываем loading только при первой загрузке
          if (subjects == null) {
            return const LoadingIndicator();
          }

          // Всегда показываем данные (даже если фоном ошибка)
          if (subjects.isEmpty) {
            final l10n = AppLocalizations.of(context);
            return EmptyState(
              icon: Icons.music_note_outlined,
              title: l10n.noSubjects,
              subtitle: l10n.addFirstSubject,
              action: ElevatedButton.icon(
                onPressed: () => _showAddSheet(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.addSubject),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              try {
                ref.invalidate(subjectsListProvider(widget.institutionId));
                await ref.read(subjectsListProvider(widget.institutionId).future);
              } catch (e) {
                debugPrint('[SubjectsScreen] refresh error: $e');
              }
            },
            child: ListView.builder(
              padding: AppSizes.paddingAllM,
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                return _SubjectCard(
                  subject: subject,
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
      builder: (context) => _AddSubjectSheet(
        institutionId: widget.institutionId,
      ),
    );
  }
}

/// Карточка предмета
class _SubjectCard extends ConsumerWidget {
  final Subject subject;
  final String institutionId;

  const _SubjectCard({
    required this.subject,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = subject.color != null
        ? hexToColor(subject.color!)
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
          child: Icon(Icons.music_note, color: color),
        ),
        title: Text(
          subject.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
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
      builder: (dialogContext) => _EditSubjectSheet(
        subject: subject,
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
        title: Text(l10n.deleteSubjectQuestion),
        content: Text(
          l10n.subjectWillBeDeleted(subject.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final controller = ref.read(subjectControllerProvider.notifier);
              final success = await controller.archive(subject.id, institutionId);
              if (success) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.subjectDeleted),
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

/// Форма создания нового предмета (без выбора цвета - случайный)
class _AddSubjectSheet extends ConsumerStatefulWidget {
  final String institutionId;

  const _AddSubjectSheet({required this.institutionId});

  @override
  ConsumerState<_AddSubjectSheet> createState() => _AddSubjectSheetState();
}

class _AddSubjectSheetState extends ConsumerState<_AddSubjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createSubject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(subjectControllerProvider.notifier);
      final subject = await controller.create(
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        color: getRandomPresetColor(), // Случайный цвет
      );

      if (subject != null && mounted) {
        final l10n = AppLocalizations.of(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.subjectCreated(subject.name)),
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
                        Icons.music_note,
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
                            l10n.newSubject,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.enterSubjectName,
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
                    labelText: l10n.subjectNameRequired,
                    hintText: l10n.subjectNameHint,
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.isEmpty ? l10n.enterName : null,
                  autofocus: true,
                ),
                const SizedBox(height: 28),

                // Кнопка
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createSubject,
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
                            l10n.createSubject,
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

/// Форма редактирования предмета (с выбором цвета)
class _EditSubjectSheet extends ConsumerStatefulWidget {
  final Subject subject;
  final String institutionId;

  const _EditSubjectSheet({
    required this.subject,
    required this.institutionId,
  });

  @override
  ConsumerState<_EditSubjectSheet> createState() => _EditSubjectSheetState();
}

class _EditSubjectSheetState extends ConsumerState<_EditSubjectSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String? _selectedColor;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subject.name);
    _selectedColor = widget.subject.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateSubject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(subjectControllerProvider.notifier);
      final success = await controller.update(
        id: widget.subject.id,
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        color: _selectedColor,
      );

      if (success && mounted) {
        final l10n = AppLocalizations.of(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.subjectUpdated),
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
                            l10n.editSubject,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.changeSubjectData,
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
                    labelText: l10n.subjectNameRequired,
                    hintText: l10n.subjectNameHint,
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.isEmpty ? l10n.enterName : null,
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
                    onPressed: _isLoading ? null : _updateSubject,
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
