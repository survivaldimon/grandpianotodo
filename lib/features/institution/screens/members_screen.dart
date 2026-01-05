import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/color_picker_field.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/shared/models/institution_member.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/core/widgets/error_view.dart';

/// Экран управления участниками заведения
class MembersScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const MembersScreen({super.key, required this.institutionId});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersStreamProvider(widget.institutionId));
    final institutionAsync = ref.watch(currentInstitutionProvider(widget.institutionId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.teamMembers),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView.fromException(
          e,
          onRetry: () => ref.invalidate(membersStreamProvider(widget.institutionId)),
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

          // Проверяем статус администратора текущего пользователя
          final isAdmin = ref.watch(isAdminProvider(widget.institutionId));
          final hasFullAccess = isOwner || isAdmin;

          // Проверяем права на управление участниками (владелец, админ или с разрешением)
          final permissions = ref.watch(myPermissionsProvider(widget.institutionId));
          final canManageMembers = hasFullAccess || (permissions?.manageMembers ?? false);

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
                isViewerOwner: isOwner,
                hasFullAccess: hasFullAccess,
                institutionId: widget.institutionId,
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
  final bool isViewerOwner;
  final bool hasFullAccess;
  final String institutionId;

  const _MemberTile({
    required this.member,
    required this.canManageMembers,
    required this.isCurrentUser,
    required this.isMemberOwner,
    required this.isViewerOwner,
    required this.hasFullAccess,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = member.profile?.fullName ?? 'Без имени';
    final email = member.profile?.email ?? '';
    final isMemberAdmin = member.isAdmin;

    // Только владелец может редактировать администраторов
    final canEditThisMember = canManageMembers && !isMemberOwner && !isCurrentUser &&
        (!isMemberAdmin || isViewerOwner);

    // Право менять цвет: себе самому или админ/владелец — любому
    final canChangeColor = isCurrentUser || hasFullAccess;

    // Парсим цвет участника
    Color? memberColor;
    if (member.color != null && member.color!.isNotEmpty) {
      try {
        memberColor = Color(int.parse('FF${member.color!.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: isMemberOwner
                ? AppColors.primary
                : isMemberAdmin
                    ? AppColors.primary.withValues(alpha: 0.7)
                    : AppColors.surfaceVariant,
            child: Icon(
              isMemberOwner
                  ? Icons.star
                  : isMemberAdmin
                      ? Icons.admin_panel_settings
                      : Icons.person,
              color: (isMemberOwner || isMemberAdmin) ? Colors.white : AppColors.textSecondary,
            ),
          ),
          // Индикатор цвета
          if (memberColor != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: memberColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isMemberAdmin && !isMemberOwner)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Админ',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
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
      trailing: (canEditThisMember || canChangeColor)
          ? PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'color':
                    _showColorPickerDialog(context, ref, memberColor);
                    break;
                  case 'edit':
                    _showEditRoleDialog(context, ref);
                    break;
                  case 'permissions':
                    context.push('/institutions/$institutionId/members/${member.id}/permissions');
                    break;
                  case 'transfer':
                    _showTransferOwnershipDialog(context, ref);
                    break;
                  case 'remove':
                    _showRemoveDialog(context, ref);
                    break;
                }
              },
              itemBuilder: (context) => [
                // Изменить цвет — себе или админ/владелец любому
                if (canChangeColor)
                  PopupMenuItem(
                    value: 'color',
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: memberColor ?? Colors.grey[300],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Изменить цвет'),
                      ],
                    ),
                  ),
                if (canEditThisMember)
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
                if (canEditThisMember)
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
                // Передача владения - только для владельца
                if (isViewerOwner && canEditThisMember)
                  PopupMenuItem(
                    value: 'transfer',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, size: 20, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Text('Передать владение', style: TextStyle(color: AppColors.warning)),
                      ],
                    ),
                  ),
                if (canEditThisMember)
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
      onTap: canEditThisMember
          ? () => context.push('/institutions/$institutionId/members/${member.id}/permissions')
          : canChangeColor && isCurrentUser
              ? () => _showColorPickerDialog(context, ref, memberColor)
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
      ref.invalidate(membersStreamProvider(institutionId));
    } catch (e) {
      // Error handling
    }
  }

  void _showColorPickerDialog(BuildContext context, WidgetRef ref, Color? currentColor) async {
    final currentHex = currentColor != null
        ? colorToHex(currentColor)
        : null;

    final result = await showColorPickerDialog(
      context,
      currentColor: currentHex,
      showReset: currentColor != null,
    );

    if (result != null && context.mounted) {
      if (result.isEmpty) {
        // Сброс цвета
        await _updateMemberColor(context, ref, null);
      } else {
        // Новый цвет (убираем # если есть)
        final hex = result.replaceAll('#', '').toUpperCase();
        await _updateMemberColor(context, ref, hex);
      }
    }
  }

  Future<void> _updateMemberColor(BuildContext context, WidgetRef ref, String? color) async {
    try {
      final controller = ref.read(memberControllerProvider.notifier);
      final success = await controller.updateColor(member.id, institutionId, color);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(color != null ? 'Цвет обновлён' : 'Цвет сброшен'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
      ref.invalidate(membersStreamProvider(institutionId));
    } catch (e) {
      // Error handling
    }
  }

  void _showTransferOwnershipDialog(BuildContext context, WidgetRef ref) {
    final memberName = member.profile?.fullName ?? 'этого участника';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Передать владение?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вы собираетесь передать права владельца пользователю:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      memberName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Внимание!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Вы потеряете права владельца\n'
                    '• Новый владелец сможет удалить заведение\n'
                    '• Это действие нельзя отменить самостоятельно',
                    style: TextStyle(fontSize: 13, color: AppColors.error),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _transferOwnership(context, ref);
            },
            child: const Text('Передать'),
          ),
        ],
      ),
    );
  }

  Future<void> _transferOwnership(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(institutionRepositoryProvider);
      await repo.transferOwnership(institutionId, member.userId);

      // Инвалидируем провайдеры
      ref.invalidate(membersStreamProvider(institutionId));
      ref.invalidate(currentInstitutionProvider(institutionId));
      ref.invalidate(currentInstitutionStreamProvider(institutionId));
      ref.invalidate(myMembershipProvider(institutionId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Права владельца переданы ${member.profile?.fullName ?? "участнику"}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
