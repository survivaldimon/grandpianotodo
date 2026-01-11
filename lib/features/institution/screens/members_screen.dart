import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/color_picker_field.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/features/institution/providers/teacher_subjects_provider.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart';
import 'package:kabinet/features/schedule/repositories/lesson_repository.dart';
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/shared/models/institution_member.dart';
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';

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
      body: Builder(
        builder: (context) {
          final members = membersAsync.valueOrNull;

          // Показываем loading только при первой загрузке
          if (members == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Всегда показываем данные (даже если фоном ошибка)
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
                  case 'subjects':
                    _showSubjectsDialog(context, ref);
                    break;
                  case 'edit':
                    _showEditRoleDialog(context, ref);
                    break;
                  case 'permissions':
                    context.push('/institutions/$institutionId/members/${member.id}/permissions');
                    break;
                  case 'manage_lessons':
                    _showTeacherBulkActionsSheet(context, ref);
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
                // Направления — себе или админ/владелец любому
                if (canChangeColor)
                  const PopupMenuItem(
                    value: 'subjects',
                    child: Row(
                      children: [
                        Icon(Icons.school, size: 20),
                        SizedBox(width: 8),
                        Text('Направления'),
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
                // Управление занятиями преподавателя (для себя или если есть права)
                if (canEditThisMember || isCurrentUser)
                  const PopupMenuItem(
                    value: 'manage_lessons',
                    child: Row(
                      children: [
                        Icon(Icons.event_note, size: 20, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Управление занятиями'),
                      ],
                    ),
                  ),
                // Передача владения - только для владельца
                if (isViewerOwner && canEditThisMember)
                  const PopupMenuItem(
                    value: 'transfer',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, size: 20, color: AppColors.warning),
                        SizedBox(width: 8),
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

  void _showSubjectsDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SubjectsSelectionSheet(
        member: member,
        institutionId: institutionId,
      ),
    );
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
            const Text(
              'Вы собираетесь передать права владельца пользователю:',
              style: TextStyle(fontSize: 14),
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

  void _showTeacherBulkActionsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TeacherBulkActionsSheet(
        teacherId: member.userId,
        teacherName: member.profile?.fullName ?? 'Преподаватель',
        institutionId: institutionId,
      ),
    );
  }
}

/// BottomSheet для bulk-операций с занятиями преподавателя
class _TeacherBulkActionsSheet extends ConsumerStatefulWidget {
  final String teacherId;
  final String teacherName;
  final String institutionId;

  const _TeacherBulkActionsSheet({
    required this.teacherId,
    required this.teacherName,
    required this.institutionId,
  });

  @override
  ConsumerState<_TeacherBulkActionsSheet> createState() =>
      _TeacherBulkActionsSheetState();
}

class _TeacherBulkActionsSheetState
    extends ConsumerState<_TeacherBulkActionsSheet> {
  int? _futureCount;
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadFutureLessonsCount();
  }

  Future<void> _loadFutureLessonsCount() async {
    final repo = ref.read(lessonRepositoryProvider);
    try {
      final count = await repo.countFutureLessonsForTeacher(
        widget.teacherId,
        widget.institutionId,
      );
      if (mounted) {
        setState(() {
          _futureCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _futureCount = 0;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.event_note, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Управление занятиями',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.teacherName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Statistics
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Text(
                              'Будущих занятий: $_futureCount',
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Actions
                      if (_futureCount != null && _futureCount! > 0) ...[
                        // Удалить все занятия
                        _ActionButton(
                          icon: Icons.delete_outline,
                          label: 'Удалить все будущие занятия',
                          description:
                              'Занятия будут удалены без изменения баланса учеников',
                          color: AppColors.error,
                          isLoading: _isDeleting,
                          onTap: _showDeleteConfirmation,
                        ),
                        const SizedBox(height: 12),
                        // Переназначить преподавателя
                        _ActionButton(
                          icon: Icons.swap_horiz,
                          label: 'Переназначить преподавателя',
                          description:
                              'Передать все занятия другому преподавателю',
                          color: AppColors.primary,
                          onTap: _showReassignSheet,
                        ),
                      ] else ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Нет будущих занятий для управления',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          // Bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Удалить занятия?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Будет удалено $_futureCount занятий преподавателя:'),
            const SizedBox(height: 8),
            Text(
              widget.teacherName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Баланс абонементов учеников не изменится.\n'
                'Это действие нельзя отменить.',
                style: TextStyle(fontSize: 13),
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
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteAllLessons();
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllLessons() async {
    setState(() => _isDeleting = true);

    try {
      final repo = ref.read(lessonRepositoryProvider);
      final deleted = await repo.deleteFutureLessonsForTeacher(
        widget.teacherId,
        widget.institutionId,
      );

      // Realtime провайдеры обновятся автоматически

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Удалено занятий: $deleted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showReassignSheet() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TeacherReassignSheet(
        teacherId: widget.teacherId,
        teacherName: widget.teacherName,
        institutionId: widget.institutionId,
        lessonsCount: _futureCount ?? 0,
      ),
    );
  }
}

/// Кнопка действия в bulk actions sheet
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}

/// BottomSheet для переназначения занятий другому преподавателю
class _TeacherReassignSheet extends ConsumerStatefulWidget {
  final String teacherId;
  final String teacherName;
  final String institutionId;
  final int lessonsCount;

  const _TeacherReassignSheet({
    required this.teacherId,
    required this.teacherName,
    required this.institutionId,
    required this.lessonsCount,
  });

  @override
  ConsumerState<_TeacherReassignSheet> createState() =>
      _TeacherReassignSheetState();
}

class _TeacherReassignSheetState extends ConsumerState<_TeacherReassignSheet> {
  String? _selectedTeacherId;
  List<LessonConflict> _conflicts = [];
  bool _isCheckingConflicts = false;
  bool _isReassigning = false;
  bool _hasCheckedConflicts = false; // Проверка завершена успешно
  List<Lesson>? _futureLessons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final membersAsync = ref.watch(membersStreamProvider(widget.institutionId));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Переназначить занятия',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.lessonsCount} занятий от ${widget.teacherName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Выбор нового преподавателя
                  Text(
                    'Выберите нового преподавателя:',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  membersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Ошибка: $e'),
                    data: (members) {
                      // Фильтруем текущего преподавателя
                      final otherMembers = members
                          .where((m) => m.userId != widget.teacherId)
                          .toList();

                      if (otherMembers.isEmpty) {
                        return const Text('Нет других преподавателей');
                      }

                      return DropdownButtonFormField<String>(
                        key: ValueKey(_selectedTeacherId),
                        initialValue: _selectedTeacherId,
                        decoration: InputDecoration(
                          labelText: 'Преподаватель',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: otherMembers.map((m) {
                          return DropdownMenuItem(
                            value: m.userId,
                            child: Text(m.profile?.fullName ?? 'Без имени'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTeacherId = value;
                            _conflicts = [];
                            _hasCheckedConflicts = false; // Сбрасываем при смене преподавателя
                          });
                          if (value != null) {
                            _checkConflicts(value);
                          }
                        },
                      );
                    },
                  ),
                  // Конфликты
                  if (_isCheckingConflicts) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Проверка конфликтов...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ] else if (_conflicts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber,
                                  color: AppColors.warning, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Найдено ${_conflicts.length} конфликтов',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Показываем первые 5 конфликтов
                          ..._conflicts.take(5).map((c) => Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• '),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat('d MMM, HH:mm', 'ru')
                                                .format(c.lesson.date),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            c.description,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          if (_conflicts.length > 5) ...[
                            const SizedBox(height: 8),
                            Text(
                              '...и ещё ${_conflicts.length - 5} конфликтов',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (_selectedTeacherId != null && !_isCheckingConflicts) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Конфликтов не найдено. Все занятия будут переназначены.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Bottom buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    // Кнопка активна только после успешной проверки конфликтов
                    onPressed: _selectedTeacherId != null &&
                            !_isReassigning &&
                            !_isCheckingConflicts &&
                            _hasCheckedConflicts
                        ? _reassignLessons
                        : null,
                    child: _isReassigning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_conflicts.isNotEmpty
                            ? 'Пропустить конфликты'
                            : 'Переназначить'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkConflicts(String newTeacherId) async {
    setState(() => _isCheckingConflicts = true);

    try {
      final repo = ref.read(lessonRepositoryProvider);

      // Получаем занятия если еще не получали
      _futureLessons ??= await repo.getFutureLessonsForTeacher(
        widget.teacherId,
        widget.institutionId,
      );

      // Проверяем конфликты
      final conflicts =
          await repo.checkReassignmentConflicts(_futureLessons!, newTeacherId);

      if (mounted) {
        setState(() {
          _conflicts = conflicts;
          _isCheckingConflicts = false;
          _hasCheckedConflicts = true; // Проверка успешно завершена
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _conflicts = [];
          _isCheckingConflicts = false;
          _hasCheckedConflicts = false; // Проверка провалилась
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка проверки: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _reassignLessons() async {
    if (_selectedTeacherId == null || _futureLessons == null) return;

    setState(() => _isReassigning = true);

    try {
      final repo = ref.read(lessonRepositoryProvider);

      // Фильтруем конфликтные занятия
      final conflictIds = _conflicts.map((c) => c.lesson.id).toSet();
      final lessonsToReassign = _futureLessons!
          .where((l) => !conflictIds.contains(l.id))
          .map((l) => l.id)
          .toList();

      if (lessonsToReassign.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Нет занятий для переназначения'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      await repo.reassignLessons(lessonsToReassign, _selectedTeacherId!);

      // Realtime провайдеры обновятся автоматически

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Переназначено занятий: ${lessonsToReassign.length}'
              '${_conflicts.isNotEmpty ? ' (пропущено: ${_conflicts.length})' : ''}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReassigning = false);
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

/// Диалог выбора направлений (предметов) для участника
class _SubjectsSelectionSheet extends ConsumerStatefulWidget {
  final InstitutionMember member;
  final String institutionId;

  const _SubjectsSelectionSheet({
    required this.member,
    required this.institutionId,
  });

  @override
  ConsumerState<_SubjectsSelectionSheet> createState() => _SubjectsSelectionSheetState();
}

class _SubjectsSelectionSheetState extends ConsumerState<_SubjectsSelectionSheet> {
  final Set<String> _selectedSubjectIds = {};
  final Set<String> _initialSubjectIds = {};
  bool _initialized = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectsAsync = ref.watch(subjectsListProvider(widget.institutionId));
    final teacherSubjectsAsync = ref.watch(teacherSubjectsProvider(
      TeacherSubjectsParams(userId: widget.member.userId, institutionId: widget.institutionId),
    ));

    // Инициализация выбранных направлений
    if (!_initialized && teacherSubjectsAsync.hasValue) {
      final teacherSubjects = teacherSubjectsAsync.value!;
      for (final ts in teacherSubjects) {
        _selectedSubjectIds.add(ts.subjectId);
        _initialSubjectIds.add(ts.subjectId);
      }
      _initialized = true;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.school),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Направления',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.member.profile?.fullName ?? 'Участник',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSaving)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: _hasChanges ? _save : null,
                    child: const Text('Сохранить'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Subjects list
          Flexible(
            child: subjectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
              data: (subjects) {
                if (subjects.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Нет доступных направлений',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final subject = subjects[index];
                    final isSelected = _selectedSubjectIds.contains(subject.id);

                    Color? subjectColor;
                    if (subject.color != null) {
                      subjectColor = hexToColor(subject.color!);
                    }

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedSubjectIds.add(subject.id);
                          } else {
                            _selectedSubjectIds.remove(subject.id);
                          }
                        });
                      },
                      secondary: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: subjectColor?.withValues(alpha: 0.2) ??
                              theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.music_note,
                          color: subjectColor ?? theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(subject.name),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                );
              },
            ),
          ),
          // Bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  bool get _hasChanges {
    if (_selectedSubjectIds.length != _initialSubjectIds.length) return true;
    return !_selectedSubjectIds.containsAll(_initialSubjectIds);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final controller = ref.read(teacherSubjectsControllerProvider.notifier);
    final toAdd = _selectedSubjectIds.difference(_initialSubjectIds);
    final toRemove = _initialSubjectIds.difference(_selectedSubjectIds);

    // Добавляем новые
    for (final subjectId in toAdd) {
      await controller.addSubject(
        userId: widget.member.userId,
        subjectId: subjectId,
        institutionId: widget.institutionId,
      );
    }

    // Удаляем убранные
    for (final subjectId in toRemove) {
      await controller.removeSubject(
        userId: widget.member.userId,
        subjectId: subjectId,
        institutionId: widget.institutionId,
      );
    }

    setState(() => _isSaving = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Направления обновлены'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}
