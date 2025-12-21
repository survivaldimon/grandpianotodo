import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/groups/providers/group_provider.dart';
import 'package:kabinet/shared/models/student_group.dart';

/// Экран списка групп
class GroupsScreen extends ConsumerWidget {
  final String institutionId;

  const GroupsScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider(institutionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Группы'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Ошибка: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(groupsProvider(institutionId)),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Нет групп',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Создайте первую группу учеников',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Создать группу'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _GroupTile(
                group: group,
                institutionId: institutionId,
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final commentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новая группа'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название группы',
                  hintText: 'Например: Группа вокала',
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Комментарий (необязательно)',
                ),
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
              final group = await controller.create(
                institutionId: institutionId,
                name: nameController.text.trim(),
                comment: commentController.text.trim().isNotEmpty
                    ? commentController.text.trim()
                    : null,
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              if (group != null && context.mounted) {
                context.push('/institutions/$institutionId/groups/${group.id}');
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends ConsumerWidget {
  final StudentGroup group;
  final String institutionId;

  const _GroupTile({
    required this.group,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: const Icon(Icons.groups, color: AppColors.primary),
      ),
      title: Text(group.name),
      subtitle: Text(
        '${group.membersCount} ${_pluralize(group.membersCount, 'ученик', 'ученика', 'учеников')}',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.push('/institutions/$institutionId/groups/${group.id}');
      },
    );
  }

  String _pluralize(int count, String one, String few, String many) {
    if (count % 10 == 1 && count % 100 != 11) return one;
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return few;
    return many;
  }
}
