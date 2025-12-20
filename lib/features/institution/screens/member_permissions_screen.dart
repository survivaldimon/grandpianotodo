import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/shared/models/institution_member.dart';

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
  String _memberName = '';
  String _roleName = '';

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  Future<void> _loadMember() async {
    try {
      final members = await ref.read(membersProvider(widget.institutionId).future);
      final member = members.firstWhere((m) => m.id == widget.memberId);
      setState(() {
        _permissions = member.permissions;
        _memberName = member.profile?.fullName ?? 'Участник';
        _roleName = member.roleName;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(institutionRepositoryProvider);
      await repo.updateMemberPermissions(widget.memberId, _permissions);
      ref.invalidate(membersProvider(widget.institutionId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Права сохранены'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Права доступа'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить'),
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
                  color: AppColors.surfaceVariant,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _memberName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        _roleName,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                // Секция: Управление заведением
                _buildSection(
                  'Управление заведением',
                  [
                    _buildPermissionTile(
                      'Управление заведением',
                      'Изменение названия, настроек',
                      _permissions.manageInstitution,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageInstitution: v)),
                    ),
                    _buildPermissionTile(
                      'Управление участниками',
                      'Добавление, удаление, изменение прав',
                      _permissions.manageMembers,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageMembers: v)),
                    ),
                    _buildPermissionTile(
                      'Архивирование данных',
                      'Удаление и архивирование записей',
                      _permissions.archiveData,
                      (v) => setState(() => _permissions = _permissions.copyWith(archiveData: v)),
                    ),
                  ],
                ),

                // Секция: Справочники
                _buildSection(
                  'Справочники',
                  [
                    _buildPermissionTile(
                      'Управление кабинетами',
                      'Создание, редактирование кабинетов',
                      _permissions.manageRooms,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageRooms: v)),
                    ),
                    _buildPermissionTile(
                      'Управление предметами',
                      'Создание, редактирование предметов',
                      _permissions.manageSubjects,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageSubjects: v)),
                    ),
                    _buildPermissionTile(
                      'Управление типами занятий',
                      'Создание, редактирование типов',
                      _permissions.manageLessonTypes,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageLessonTypes: v)),
                    ),
                    _buildPermissionTile(
                      'Управление тарифами',
                      'Создание, редактирование тарифов оплаты',
                      _permissions.managePaymentPlans,
                      (v) => setState(() => _permissions = _permissions.copyWith(managePaymentPlans: v)),
                    ),
                  ],
                ),

                // Секция: Ученики
                _buildSection(
                  'Ученики и группы',
                  [
                    _buildPermissionTile(
                      'Управление учениками',
                      'Добавление, редактирование учеников',
                      _permissions.manageStudents,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageStudents: v)),
                    ),
                    _buildPermissionTile(
                      'Управление группами',
                      'Создание групп, управление составом',
                      _permissions.manageGroups,
                      (v) => setState(() => _permissions = _permissions.copyWith(manageGroups: v)),
                    ),
                  ],
                ),

                // Секция: Расписание
                _buildSection(
                  'Расписание',
                  [
                    _buildPermissionTile(
                      'Просмотр всего расписания',
                      'Видеть занятия всех преподавателей',
                      _permissions.viewAllSchedule,
                      (v) => setState(() => _permissions = _permissions.copyWith(viewAllSchedule: v)),
                    ),
                    _buildPermissionTile(
                      'Создание занятий',
                      'Добавление новых занятий',
                      _permissions.createLessons,
                      (v) => setState(() => _permissions = _permissions.copyWith(createLessons: v)),
                    ),
                    _buildPermissionTile(
                      'Редактирование своих занятий',
                      'Изменение только своих занятий',
                      _permissions.editOwnLessons,
                      (v) => setState(() => _permissions = _permissions.copyWith(editOwnLessons: v)),
                    ),
                    _buildPermissionTile(
                      'Редактирование всех занятий',
                      'Изменение занятий любого преподавателя',
                      _permissions.editAllLessons,
                      (v) => setState(() => _permissions = _permissions.copyWith(editAllLessons: v)),
                    ),
                    _buildPermissionTile(
                      'Удаление занятий',
                      'Удаление и архивирование занятий',
                      _permissions.deleteLessons,
                      (v) => setState(() => _permissions = _permissions.copyWith(deleteLessons: v)),
                    ),
                  ],
                ),

                // Секция: Финансы
                _buildSection(
                  'Финансы',
                  [
                    _buildPermissionTile(
                      'Просмотр оплат',
                      'Видеть историю оплат',
                      _permissions.viewPayments,
                      (v) => setState(() => _permissions = _permissions.copyWith(viewPayments: v)),
                    ),
                    _buildPermissionTile(
                      'Управление оплатами',
                      'Добавление, корректировка оплат',
                      _permissions.managePayments,
                      (v) => setState(() => _permissions = _permissions.copyWith(managePayments: v)),
                    ),
                    _buildPermissionTile(
                      'Просмотр статистики',
                      'Доступ к отчётам и аналитике',
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
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}
