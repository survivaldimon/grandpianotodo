import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/providers/phone_settings_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/shared/models/student.dart';

/// Диалог объединения учеников
/// Показывает список объединяемых учеников и форму для нового
class MergeStudentsDialog extends ConsumerStatefulWidget {
  final List<Student> students;
  final String institutionId;
  final VoidCallback? onMerged;

  const MergeStudentsDialog({
    super.key,
    required this.students,
    required this.institutionId,
    this.onMerged,
  });

  /// Показать диалог объединения
  static Future<Student?> show(
    BuildContext context, {
    required List<Student> students,
    required String institutionId,
    VoidCallback? onMerged,
  }) {
    return showModalBottomSheet<Student>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => MergeStudentsDialog(
        students: students,
        institutionId: institutionId,
        onMerged: onMerged,
      ),
    );
  }

  @override
  ConsumerState<MergeStudentsDialog> createState() => _MergeStudentsDialogState();
}

class _MergeStudentsDialogState extends ConsumerState<MergeStudentsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Предзаполняем имя из первых букв имён учеников
    final names = widget.students.map((s) => s.name).toList();
    if (names.length == 2) {
      // Для двух учеников предлагаем "Имя1 и Имя2"
      _nameController.text = '${names[0]} и ${names[1]}';
    } else {
      // Для нескольких берём первое имя
      _nameController.text = names.first;
    }

    // Если есть телефон у первого, используем его
    final firstWithPhone = widget.students.firstWhere(
      (s) => s.phone != null && s.phone!.isNotEmpty,
      orElse: () => widget.students.first,
    );
    if (firstWithPhone.phone != null && firstWithPhone.phone!.isNotEmpty) {
      _phoneController.text = firstWithPhone.phone!;
    } else {
      // Автозаполнение кода страны если ни у кого нет телефона
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final prefix = ref.read(phoneDefaultPrefixProvider);
          if (prefix.isNotEmpty && _phoneController.text.isEmpty) {
            _phoneController.text = '$prefix ';
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  int get _totalBalance {
    return widget.students.fold(0, (sum, s) => sum + s.balance);
  }

  int get _totalLegacyBalance {
    return widget.students.fold(0, (sum, s) => sum + s.legacyBalance);
  }

  Future<void> _merge() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final controller = ref.read(studentControllerProvider.notifier);
    final newStudent = await controller.mergeStudents(
      sourceIds: widget.students.map((s) => s.id).toList(),
      institutionId: widget.institutionId,
      newName: _nameController.text.trim(),
      newPhone: _phoneController.text.isEmpty ? null : _phoneController.text.trim(),
      newComment: _commentController.text.isEmpty ? null : _commentController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (newStudent != null) {
      widget.onMerged?.call();
      Navigator.pop(context, newStudent);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).cardCreatedWithName(newStudent.name)),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).mergeError),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.merge, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.mergeStudentsCount(widget.students.length),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Warning
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.mergeStudentsWarning,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Students list
                  Text(
                    l10n.studentsToMerge,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.students.map((student) => _buildStudentTile(student)),
                  const SizedBox(height: 8),

                  // Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat(
                          l10n.totalBalance,
                          '$_totalBalance',
                          _totalBalance < 0 ? AppColors.error : AppColors.primary,
                        ),
                        if (_totalLegacyBalance > 0)
                          _buildSummaryStat(
                            l10n.fromLegacyBalance,
                            '$_totalLegacyBalance',
                            AppColors.warning,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // New student form
                  Text(
                    l10n.newCardData,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: l10n.personName,
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerLow,
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? l10n.enterPersonName : null,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: l10n.phone,
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerLow,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            labelText: l10n.comment,
                            prefixIcon: const Icon(Icons.notes_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerLow,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Actions
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _merge,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.merge),
                        label: Text(l10n.merge),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTile(Student student) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (student.phone != null && student.phone!.isNotEmpty)
                  Text(
                    student.phone!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${student.balance}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: student.hasDebt ? AppColors.error : AppColors.primary,
                ),
              ),
              Text(
                AppLocalizations.of(context).lessonsCountField.toLowerCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
