import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/groups/providers/group_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/features/students/providers/student_bindings_provider.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/student_group.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/core/widgets/error_view.dart';

/// Экран деталей группы
class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  final String institutionId;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));

    return groupAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Группа')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Группа')),
        body: ErrorView.fromException(
          e,
          onRetry: () => ref.invalidate(groupProvider(groupId)),
        ),
      ),
      data: (group) => _GroupDetailContent(
        group: group,
        institutionId: institutionId,
      ),
    );
  }
}

class _GroupDetailContent extends ConsumerWidget {
  final StudentGroup group;
  final String institutionId;

  const _GroupDetailContent({
    required this.group,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = group.members ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _showEditDialog(context, ref);
                  break;
                case 'archive':
                  _showArchiveDialog(context, ref);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Редактировать'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Архивировать', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMemberDialog(context, ref),
        child: const Icon(Icons.person_add),
      ),
      body: ListView(
        children: [
          // Информация о группе
          if (group.comment != null && group.comment!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surfaceVariant,
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      group.comment!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

          // Заголовок списка участников
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                Text(
                  'УЧАСТНИКИ (${members.length})',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddMemberDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить'),
                ),
              ],
            ),
          ),

          // Список участников
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 48, color: AppColors.textTertiary),
                    SizedBox(height: 16),
                    Text(
                      'Нет участников',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Добавьте учеников в группу',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...members.map((student) => _MemberTile(
                  student: student,
                  groupId: group.id,
                  institutionId: institutionId,
                )),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: group.name);
    final commentController = TextEditingController(text: group.comment ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Редактировать группу'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Название группы'),
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите название';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: commentController,
                decoration: const InputDecoration(labelText: 'Комментарий'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final controller = ref.read(groupControllerProvider.notifier);
              await controller.update(
                group.id,
                institutionId: institutionId,
                name: nameController.text.trim(),
                comment: commentController.text.trim(),
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showArchiveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Архивировать группу?'),
        content: Text(
          'Группа "${group.name}" будет перемещена в архив. '
          'Вы сможете восстановить её позже.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final controller = ref.read(groupControllerProvider.notifier);
              final success = await controller.archive(group.id, institutionId);

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              if (success && context.mounted) {
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Группа архивирована'),
                    backgroundColor: Colors.green,
                  ),
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

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    final existingIds = (group.members ?? []).map((m) => m.id).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AddMemberSheet(
        groupId: group.id,
        institutionId: institutionId,
        existingMemberIds: existingIds,
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  final Student student;
  final String groupId;
  final String institutionId;

  const _MemberTile({
    required this.student,
    required this.groupId,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDebt = student.prepaidLessonsCount < 0;
    final balance = student.prepaidLessonsCount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasDebt
              ? AppColors.error.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.person,
            color: hasDebt ? AppColors.error : AppColors.primary,
          ),
        ),
        title: Text(student.name),
        subtitle: Row(
          children: [
            Icon(
              hasDebt ? Icons.warning_amber : Icons.school,
              size: 14,
              color: hasDebt ? AppColors.error : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '$balance занятий',
              style: TextStyle(
                color: hasDebt ? AppColors.error : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: AppColors.error.withValues(alpha: 0.7),
              ),
              onPressed: () => _showRemoveDialog(context, ref),
              tooltip: 'Удалить из группы',
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          context.push('/institutions/$institutionId/students/${student.id}');
        },
      ),
    );
  }

  void _showRemoveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить из группы?'),
        content: Text('Удалить ${student.name} из группы?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final controller = ref.read(groupControllerProvider.notifier);
              await controller.removeMember(groupId, student.id, institutionId);

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
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

// ============================================================================
// SHEET ДОБАВЛЕНИЯ УЧАСТНИКОВ В ГРУППУ
// ============================================================================

class _AddMemberSheet extends ConsumerStatefulWidget {
  final String groupId;
  final String institutionId;
  final Set<String> existingMemberIds;

  const _AddMemberSheet({
    required this.groupId,
    required this.institutionId,
    required this.existingMemberIds,
  });

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  bool _isAdding = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider(widget.institutionId));
    final allStudents = studentsAsync.valueOrNull ?? [];

    // Фильтруем: убираем уже добавленных в группу
    final availableStudents = allStudents
        .where((s) => !widget.existingMemberIds.contains(s.id))
        .where((s) => s.archivedAt == null)
        .toList();

    // Применяем поиск
    final filteredStudents = _searchQuery.isEmpty
        ? availableStudents
        : availableStudents.where((s) {
            return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

    // Выбранные ученики для отображения chips
    final selectedStudents = availableStudents
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Заголовок
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Добавить участников',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Выберите учеников для группы',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Поиск
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск ученика...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          const SizedBox(height: 12),

          // Кнопка создания нового ученика
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _showCreateStudentDialog(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppColors.success,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Создать нового ученика',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Chips выбранных учеников
          if (selectedStudents.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Выбрано: ${selectedStudents.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedStudents.map((student) {
                      return Chip(
                        label: Text(
                          student.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() => _selectedIds.remove(student.id));
                        },
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Список учеников
          Expanded(
            child: studentsAsync.isLoading && allStudents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.people_outline,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Ничего не найдено'
                                  : availableStudents.isEmpty
                                      ? 'Все ученики уже в группе'
                                      : 'Нет доступных учеников',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Text('Сбросить поиск'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final isSelected = _selectedIds.contains(student.id);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIds.add(student.id);
                                } else {
                                  _selectedIds.remove(student.id);
                                }
                              });
                            },
                            title: Text(student.name),
                            subtitle: student.balance != 0
                                ? Text(
                                    'Баланс: ${student.balance}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: student.balance < 0
                                          ? AppColors.error
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : null,
                            secondary: CircleAvatar(
                              backgroundColor: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Text(
                                student.name.isNotEmpty
                                    ? student.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.trailing,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                          );
                        },
                      ),
          ),

          // Sticky кнопка добавления
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.of(context).viewPadding.bottom,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedIds.isEmpty || _isAdding
                    ? null
                    : _addSelectedMembers,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isAdding
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _selectedIds.isEmpty
                            ? 'Выберите учеников'
                            : 'Добавить (${_selectedIds.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSelectedMembers() async {
    setState(() => _isAdding = true);

    try {
      final controller = ref.read(groupControllerProvider.notifier);

      for (final studentId in _selectedIds) {
        await controller.addMember(
          widget.groupId,
          studentId,
          widget.institutionId,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedIds.length == 1
                  ? 'Ученик добавлен в группу'
                  : 'Добавлено учеников: ${_selectedIds.length}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  void _showCreateStudentDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_add, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Новый ученик'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'ФИО *',
                    hintText: 'Иванов Иван',
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Введите имя' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    hintText: '+7 (777) 123-45-67',
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isLoading = true);

                      final controller = ref.read(studentControllerProvider.notifier);
                      final currentUserId = ref.read(currentUserIdProvider);

                      final student = await controller.create(
                        institutionId: widget.institutionId,
                        name: nameController.text.trim(),
                        phone: phoneController.text.isEmpty
                            ? null
                            : phoneController.text.trim(),
                      );

                      if (student != null) {
                        // Автопривязка к преподавателю
                        if (currentUserId != null) {
                          final bindingsController =
                              ref.read(studentBindingsControllerProvider.notifier);
                          await bindingsController.addTeacher(
                            studentId: student.id,
                            userId: currentUserId,
                            institutionId: widget.institutionId,
                          );
                        }

                        // Автоматически выбираем созданного ученика
                        setState(() => _selectedIds.add(student.id));

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Ученик "${student.name}" создан и выбран'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } else {
                        setDialogState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }
}

