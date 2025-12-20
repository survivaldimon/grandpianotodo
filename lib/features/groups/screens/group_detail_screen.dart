import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/groups/providers/group_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/student_group.dart';

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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Ошибка: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(groupProvider(groupId)),
                child: const Text('Повторить'),
              ),
            ],
          ),
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
                      style: TextStyle(color: AppColors.textSecondary),
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
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    Text(
                      'Нет участников',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
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
    final studentsAsync = ref.read(studentsProvider(institutionId));

    studentsAsync.whenData((allStudents) {
      final existingIds = (group.members ?? []).map((m) => m.id).toSet();
      final availableStudents = allStudents
          .where((s) => !existingIds.contains(s.id))
          .toList();

      if (availableStudents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Все ученики уже в группе'),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (dialogContext) => _AddMemberDialog(
          availableStudents: availableStudents,
          groupId: group.id,
          institutionId: institutionId,
        ),
      );
    });
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
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceVariant,
        child: Text(
          student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(student.name),
      subtitle: student.prepaidLessonsCount != 0
          ? Text(
              'Баланс: ${student.prepaidLessonsCount}',
              style: TextStyle(
                color: student.prepaidLessonsCount < 0
                    ? Colors.red
                    : AppColors.textSecondary,
              ),
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
        onPressed: () => _showRemoveDialog(context, ref),
        tooltip: 'Удалить из группы',
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

class _AddMemberDialog extends ConsumerStatefulWidget {
  final List<Student> availableStudents;
  final String groupId;
  final String institutionId;

  const _AddMemberDialog({
    required this.availableStudents,
    required this.groupId,
    required this.institutionId,
  });

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить участников'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.availableStudents.length,
          itemBuilder: (context, index) {
            final student = widget.availableStudents[index];
            final isSelected = _selectedIds.contains(student.id);

            return CheckboxListTile(
              title: Text(student.name),
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
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () async {
                  final controller = ref.read(groupControllerProvider.notifier);

                  for (final studentId in _selectedIds) {
                    await controller.addMember(
                      widget.groupId,
                      studentId,
                      widget.institutionId,
                    );
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
          child: Text('Добавить (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
