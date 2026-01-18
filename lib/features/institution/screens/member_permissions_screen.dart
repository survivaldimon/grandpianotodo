import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/features/institution/providers/teacher_subjects_provider.dart';
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/shared/models/institution_member.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';

/// Экран редактирования прав участника
class MemberPermissionsScreen extends ConsumerStatefulWidget {
  final String memberId;
  final String institutionId;

  const MemberPermissionsScreen({
    super.key,
    required this.memberId,
    required this.institutionId,
  });

  @override
  ConsumerState<MemberPermissionsScreen> createState() =>
      _MemberPermissionsScreenState();
}

class _MemberPermissionsScreenState
    extends ConsumerState<MemberPermissionsScreen> {
  late MemberPermissions _permissions;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAdmin = false;
  bool _isOwnerViewing = false;
  String _memberName = '';
  String _roleName = '';
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  Future<void> _loadMember() async {
    try {
      final members = await ref.read(membersProvider(widget.institutionId).future);
      final member = members.firstWhere((m) => m.id == widget.memberId);

      // Проверяем, является ли текущий пользователь владельцем
      final institution = await ref.read(currentInstitutionProvider(widget.institutionId).future);
      final currentUserId = ref.read(currentUserIdProvider);

      setState(() {
        _permissions = member.permissions;
        _isAdmin = member.isAdmin;
        _isOwnerViewing = institution.ownerId == currentUserId;
        _memberName = member.profile?.fullName ?? AppLocalizations.of(context).member;
        _roleName = member.roleName;
        _userId = member.userId;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loadingError(e.toString()))),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(institutionRepositoryProvider);
      // Сохраняем права и статус администратора параллельно
      await Future.wait([
        repo.updateMemberPermissions(widget.memberId, _permissions),
        if (_isOwnerViewing) repo.updateMemberAdminStatus(widget.memberId, _isAdmin),
      ]);
      ref.invalidate(membersStreamProvider(widget.institutionId));
      // Инвалидируем права для обновления по всему приложению
      ref.invalidate(myMembershipProvider(widget.institutionId));

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.permissionsSaved),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.saveError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.permissions),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Заголовок с именем участника
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _memberName,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  _roleName,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          if (_isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.admin_panel_settings, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.adminBadge,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Секция: Администратор (только для владельца)
                if (_isOwnerViewing) _buildAdminSection(),

                // Секция: Направления (предметы)
                if (_userId.isNotEmpty) _buildSubjectsSection(),

                // Секция: Управление заведением
                _buildSection(
                  l10n.permissionSectionInstitution,
                  [
                    _buildPermissionTile(
                      l10n.permissionManageInstitution,
                      l10n.permissionManageInstitutionDesc,
                      _permissions.manageInstitution,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageInstitution: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionManageMembers,
                      l10n.permissionManageMembersDesc,
                      _permissions.manageMembers,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageMembers: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionArchiveData,
                      l10n.permissionArchiveDataDesc,
                      _permissions.archiveData,
                      (v) => setState(() => _permissions = _permissions.copyWith(archiveData: v)),
                    ),
                  ],
                ),

                // Секция: Справочники
                _buildSection(
                  l10n.permissionSectionReferences,
                  [
                    _buildPermissionTile(
                      l10n.permissionManageRooms,
                      l10n.permissionManageRoomsDesc,
                      _permissions.manageRooms,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageRooms: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionManageSubjects,
                      l10n.permissionManageSubjectsDesc,
                      _permissions.manageSubjects,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageSubjects: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionManageLessonTypes,
                      l10n.permissionManageLessonTypesDesc,
                      _permissions.manageLessonTypes,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageLessonTypes: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionManagePaymentPlans,
                      l10n.permissionManagePaymentPlansDesc,
                      _permissions.managePaymentPlans,
                      (v) => setState(() => _permissions = _permissions.copyWith(managePaymentPlans: v)),
                    ),
                  ],
                ),

                // Секция: Ученики
                _buildSection(
                  l10n.permissionSectionStudents,
                  [
                    _buildPermissionTile(
                      l10n.permissionManageOwnStudents,
                      l10n.permissionManageOwnStudentsDesc,
                      _permissions.manageOwnStudents,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageOwnStudents: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionManageAllStudents,
                      l10n.permissionManageAllStudentsDesc,
                      _permissions.manageAllStudents,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageAllStudents: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionManageGroups,
                      l10n.permissionManageGroupsDesc,
                      _permissions.manageGroups,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageGroups: v)),
                    ),
                  ],
                ),

                // Секция: Расписание
                _buildSection(
                  l10n.schedule,
                  [
                    _buildPermissionTile(
                      l10n.permissionViewAllSchedule,
                      l10n.permissionViewAllScheduleDesc,
                      _permissions.viewAllSchedule,
                      (v) => setState(() => _permissions = _permissions.copyWith(viewAllSchedule: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionCreateLessons,
                      l10n.permissionCreateLessonsDesc,
                      _permissions.createLessons,
                      (v) => setState(() => _permissions = _permissions.copyWith(createLessons: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionEditOwnLessons,
                      l10n.permissionEditOwnLessonsDesc,
                      _permissions.editOwnLessons,
                      (v) => setState(() => _permissions = _permissions.copyWith(editOwnLessons: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionEditAllLessons,
                      l10n.permissionEditAllLessonsDesc,
                      _permissions.editAllLessons,
                      (v) => setState(() => _permissions = _permissions.copyWith(editAllLessons: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionDeleteOwnLessons,
                      l10n.permissionDeleteOwnLessonsDesc,
                      _permissions.deleteOwnLessons,
                      (v) => setState(() => _permissions = _permissions.copyWith(deleteOwnLessons: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionDeleteAllLessons,
                      l10n.permissionDeleteAllLessonsDesc,
                      _permissions.deleteAllLessons,
                      (v) => setState(() => _permissions = _permissions.copyWith(deleteAllLessons: v)),
                    ),
                  ],
                ),

                // Секция: Финансы
                _buildSection(
                  l10n.permissionSectionFinance,
                  [
                    _buildPermissionTile(
                      l10n.permissionViewOwnStudentsPayments,
                      l10n.permissionViewOwnStudentsPaymentsDesc,
                      _permissions.viewOwnStudentsPayments,
                      (v) => setState(() => _permissions = _permissions.copyWith(viewOwnStudentsPayments: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionViewAllPayments,
                      l10n.permissionViewAllPaymentsDesc,
                      _permissions.viewAllPayments,
                      (v) => setState(() => _permissions = _permissions.copyWith(viewAllPayments: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionAddPaymentsForOwnStudents,
                      l10n.permissionAddPaymentsForOwnStudentsDesc,
                      _permissions.addPaymentsForOwnStudents,
                      (v) => setState(() => _permissions = _permissions.copyWith(addPaymentsForOwnStudents: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionAddPaymentsForAllStudents,
                      l10n.permissionAddPaymentsForAllStudentsDesc,
                      _permissions.addPaymentsForAllStudents,
                      (v) => setState(() => _permissions = _permissions.copyWith(addPaymentsForAllStudents: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionManageOwnStudentsPayments,
                      l10n.permissionManageOwnStudentsPaymentsDesc,
                      _permissions.manageOwnStudentsPayments,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageOwnStudentsPayments: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionManageAllPayments,
                      l10n.permissionManageAllPaymentsDesc,
                      _permissions.manageAllPayments,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageAllPayments: v)),
                    ),
                    _buildPermissionTile(
                      l10n.permissionViewStatistics,
                      l10n.permissionViewStatisticsDesc,
                      _permissions.viewStatistics,
                      (v) => setState(() => _permissions = _permissions.copyWith(viewStatistics: v)),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildAdminSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            l10n.statusSection,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: _isAdmin ? AppColors.primary.withValues(alpha: 0.05) : null,
          child: SwitchListTile(
            secondary: Icon(
              Icons.admin_panel_settings,
              color: _isAdmin ? AppColors.primary : null,
            ),
            title: Text(l10n.admin),
            subtitle: Text(
              _isAdmin
                  ? l10n.adminHasAllPermissions
                  : l10n.grantFullPermissions,
              style: const TextStyle(fontSize: 12),
            ),
            value: _isAdmin,
            onChanged: (v) => setState(() => _isAdmin = v),
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            activeThumbColor: AppColors.primary,
          ),
        ),
        if (_isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.allPermissionsEnabledForAdmin,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Divider(),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _buildPermissionTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    // Если включён админ - все права включены и заблокированы
    final isDisabled = _isAdmin;
    final displayValue = isDisabled ? true : value;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(
          isDisabled ? AppLocalizations.of(context).enabledForAdmin : subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDisabled ? AppColors.textTertiary : null,
          ),
        ),
        value: displayValue,
        onChanged: isDisabled ? null : onChanged,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
        activeThumbColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSubjectsSection() {
    final l10n = AppLocalizations.of(context);
    final params = TeacherSubjectsParams(
      userId: _userId,
      institutionId: widget.institutionId,
    );
    final teacherSubjectsAsync = ref.watch(teacherSubjectsProvider(params));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.teacherSubjectsLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: () => _showAddSubjectDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.add),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.teacherSubjectsHint,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        teacherSubjectsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (teacherSubjects) {
            if (teacherSubjects.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.noDirectionsHint,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: teacherSubjects.map((ts) {
                  final subject = ts.subject;
                  final color = subject?.color != null
                      ? Color(int.parse('0xFF${subject!.color!.replaceAll('#', '')}'))
                      : AppColors.primary;

                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: color,
                      radius: 12,
                      child: const Icon(Icons.book, size: 14, color: Colors.white),
                    ),
                    label: Text(subject?.name ?? l10n.unknownSubject),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeSubject(ts.subjectId),
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const Divider(),
      ],
    );
  }

  void _showAddSubjectDialog() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final allSubjectsAsync = ref.watch(subjectsListProvider(widget.institutionId));
          final teacherSubjectsAsync = ref.watch(teacherSubjectsProvider(
            TeacherSubjectsParams(userId: _userId, institutionId: widget.institutionId),
          ));

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.addDirectionTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.selectSubjectFor(_memberName),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                allSubjectsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (allSubjects) {
                    final existingIds = teacherSubjectsAsync.valueOrNull
                            ?.map((ts) => ts.subjectId)
                            .toSet() ??
                        {};

                    final available = allSubjects
                        .where((s) => !existingIds.contains(s.id) && s.archivedAt == null)
                        .toList();

                    if (available.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.allSubjectsAdded),
                      );
                    }

                    return Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: available.length,
                        itemBuilder: (context, index) {
                          final subject = available[index];
                          final color = subject.color != null
                              ? Color(int.parse('0xFF${subject.color!.replaceAll('#', '')}'))
                              : AppColors.primary;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.2),
                              child: Icon(Icons.book, color: color),
                            ),
                            title: Text(subject.name),
                            onTap: () async {
                              Navigator.pop(dialogContext);
                              final messenger = ScaffoldMessenger.of(context);
                              await ref
                                  .read(teacherSubjectsControllerProvider.notifier)
                                  .addSubject(
                                    userId: _userId,
                                    subjectId: subject.id,
                                    institutionId: widget.institutionId,
                                  );
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.directionAdded(subject.name)),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _removeSubject(String subjectId) async {
    await ref.read(teacherSubjectsControllerProvider.notifier).removeSubject(
          userId: _userId,
          subjectId: subjectId,
          institutionId: widget.institutionId,
        );
  }
}
