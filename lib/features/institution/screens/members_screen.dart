import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/shared/models/institution_member.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';

/// Экран управления участниками заведения
class MembersScreen extends ConsumerWidget {
  final String institutionId;

  const MembersScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider(institutionId));
    final institutionAsync = ref.watch(currentInstitutionProvider(institutionId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.teamMembers),
      ),
      body: membersAsync.when(
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
                onPressed: () => ref.invalidate(membersProvider(institutionId)),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
        data: (members) {
          if (members.isEmpty) {
            return const Center(
              child: Text('Нет участников'),
            );
          }

          final isOwner = institutionAsync.maybeWhen(
            data: (inst) => inst.ownerId == currentUserId,
            orElse: () => false,
          );

          final ownerId = institutionAsync.maybeWhen(
            data: (inst) => inst.ownerId,
            orElse: () => null,
          );

          // Проверяем права на управление участниками (владелец или с разрешением)
          final permissions = ref.watch(myPermissionsProvider(institutionId));
          final canManageMembers = isOwner || (permissions?.manageMembers ?? false);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final isCurrentUser = member.userId == currentUserId;
              final isMemberOwner = member.userId == ownerId;

              return _MemberTile(
                member: member,
                canManageMembers: canManageMembers,
                isCurrentUser: isCurrentUser,
                isMemberOwner: isMemberOwner,
                institutionId: institutionId,
              );
            },
          );
        },
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  final InstitutionMember member;
  final bool canManageMembers;
  final bool isCurrentUser;
  final bool isMemberOwner;
  final String institutionId;

  const _MemberTile({
    required this.member,
    required this.canManageMembers,
    required this.isCurrentUser,
    required this.isMemberOwner,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = member.profile?.fullName ?? 'Без имени';
    final email = member.profile?.email ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isMemberOwner ? AppColors.primary : AppColors.surfaceVariant,
        child: Icon(
          isMemberOwner ? Icons.star : Icons.person,
          color: isMemberOwner ? Colors.white : AppColors.textSecondary,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCurrentUser)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Вы',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.roleName,
            style: TextStyle(
              color: isMemberOwner ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isMemberOwner ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          if (email.isNotEmpty)
            Text(
              email,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
      trailing: canManageMembers && !isMemberOwner && !isCurrentUser
          ? PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditRoleDialog(context, ref);
                    break;
                  case 'permissions':
                    context.push('/institutions/$institutionId/members/${member.id}/permissions');
                    break;
                  case 'remove':
                    _showRemoveDialog(context, ref);
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
                      Text('Изменить роль'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'permissions',
                  child: Row(
                    children: [
                      Icon(Icons.security, size: 20),
                      SizedBox(width: 8),
                      Text('Права доступа'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Удалить', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            )
          : null,
      onTap: canManageMembers && !isMemberOwner && !isCurrentUser
          ? () => context.push('/institutions/$institutionId/members/${member.id}/permissions')
          : null,
    );
  }

  void _showEditRoleDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: member.roleName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Изменить роль'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.profile?.fullName ?? 'Участник',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Название роли',
                hintText: 'Например: Преподаватель, Администратор',
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newRole = controller.text.trim();
              if (newRole.isNotEmpty && newRole != member.roleName) {
                await _updateMemberRole(ref, newRole);
              }
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

  Future<void> _updateMemberRole(WidgetRef ref, String newRole) async {
    try {
      final repo = ref.read(institutionRepositoryProvider);
      await repo.updateMemberRole(member.id, newRole);
      ref.invalidate(membersProvider(institutionId));
    } catch (e) {
      // Error handling
    }
  }

  void _showRemoveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить участника?'),
        content: Text(
          'Вы уверены, что хотите удалить ${member.profile?.fullName ?? "участника"} из заведения?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _removeMember(ref);
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

  Future<void> _removeMember(WidgetRef ref) async {
    try {
      final repo = ref.read(institutionRepositoryProvider);
      await repo.removeMember(member.id);
      ref.invalidate(membersProvider(institutionId));
    } catch (e) {
      // Error handling
    }
  }
}
