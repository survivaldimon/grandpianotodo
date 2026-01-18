import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/groups/providers/group_provider.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/shared/models/student_group.dart';

/// Экран списка групп
class GroupsScreen extends ConsumerWidget {
  final String institutionId;

  const GroupsScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final groupsAsync = ref.watch(groupsProvider(institutionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groups),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref, l10n),
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (context) {
          final groups = groupsAsync.valueOrNull;

          // Показываем loading только при первой загрузке
          if (groups == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Всегда показываем данные (даже если фоном ошибка)
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.groups, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noGroups,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.createFirstGroup,
                    style: const TextStyle(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context, ref, l10n),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.createGroup),
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

  void _showCreateDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final nameController = TextEditingController();
    final commentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.newGroup),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.groupName,
                  hintText: l10n.groupNameHint,
                ),
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.enterName;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: commentController,
                decoration: InputDecoration(
                  labelText: l10n.commentOptional,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
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
            child: Text(l10n.create),
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
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: const Icon(Icons.groups, color: AppColors.primary),
      ),
      title: Text(group.name),
      subtitle: Text(
        l10n.studentsCountPlural(group.membersCount),
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.push('/institutions/$institutionId/groups/${group.id}');
      },
    );
  }
}
