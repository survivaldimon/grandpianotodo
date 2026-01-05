import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/empty_state.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/teacher_subjects_provider.dart';
import 'package:kabinet/features/groups/providers/group_provider.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/features/students/providers/student_bindings_provider.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subject.dart';
import 'package:kabinet/shared/models/institution_member.dart';
import 'package:kabinet/shared/models/student_group.dart';

// ============================================================================
// ЛОКАЛЬНЫЕ ПРОВАЙДЕРЫ СВЯЗЕЙ ДЛЯ ФИЛЬТРАЦИИ
// ============================================================================

/// Связи: преподаватель (userId) → Set<studentId>
final _studentTeacherBindingsProvider =
    FutureProvider.family<Map<String, Set<String>>, String>((ref, institutionId) async {
  final client = SupabaseConfig.client;
  final data = await client
      .from('student_teachers')
      .select('student_id, user_id')
      .eq('institution_id', institutionId);

  final result = <String, Set<String>>{};
  for (final item in data as List) {
    final userId = item['user_id'] as String;
    final studentId = item['student_id'] as String;
    result.putIfAbsent(userId, () => {}).add(studentId);
  }
  return result;
});

/// Связи: направление (subjectId) → Set<studentId>
final _studentSubjectBindingsProvider =
    FutureProvider.family<Map<String, Set<String>>, String>((ref, institutionId) async {
  final client = SupabaseConfig.client;
  final data = await client
      .from('student_subjects')
      .select('student_id, subject_id')
      .eq('institution_id', institutionId);

  final result = <String, Set<String>>{};
  for (final item in data as List) {
    final subjectId = item['subject_id'] as String;
    final studentId = item['student_id'] as String;
    result.putIfAbsent(subjectId, () => {}).add(studentId);
  }
  return result;
});

/// Связи: группа (groupId) → Set<studentId>
final _studentGroupBindingsProvider =
    FutureProvider.family<Map<String, Set<String>>, String>((ref, institutionId) async {
  final client = SupabaseConfig.client;
  final data = await client
      .from('student_group_members')
      .select('student_id, group_id, student_groups!inner(institution_id)')
      .eq('student_groups.institution_id', institutionId);

  final result = <String, Set<String>>{};
  for (final item in data as List) {
    final groupId = item['group_id'] as String;
    final studentId = item['student_id'] as String;
    result.putIfAbsent(groupId, () => {}).add(studentId);
  }
  return result;
});

/// Последняя активность: studentId → дата последнего завершённого занятия
final _studentLastActivityProvider =
    FutureProvider.family<Map<String, DateTime?>, String>((ref, institutionId) async {
  final client = SupabaseConfig.client;

  // Получаем последнее завершённое занятие для каждого ученика
  final data = await client
      .from('lessons')
      .select('student_id, date')
      .eq('institution_id', institutionId)
      .eq('status', 'completed')
      .isFilter('archived_at', null)
      .not('student_id', 'is', null)
      .order('date', ascending: false);

  final result = <String, DateTime?>{};
  for (final item in data as List) {
    final studentId = item['student_id'] as String?;
    if (studentId == null) continue;

    // Берём только первую (последнюю по дате) запись для каждого ученика
    if (!result.containsKey(studentId)) {
      final dateStr = item['date'] as String;
      result[studentId] = DateTime.parse(dateStr);
    }
  }
  return result;
});

// ============================================================================
// ЭКРАН СПИСКА УЧЕНИКОВ
// ============================================================================

/// Экран списка учеников
class StudentsListScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const StudentsListScreen({super.key, required this.institutionId});

  @override
  ConsumerState<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends ConsumerState<StudentsListScreen> {
  // Расширенные фильтры
  Set<String> _selectedTeacherIds = {};
  Set<String> _selectedSubjectIds = {};
  Set<String> _selectedGroupIds = {};
  int? _inactivityDays; // null = все, 7/14/30/60 дней без занятий

  bool get _hasAdvancedFilters =>
      _selectedTeacherIds.isNotEmpty ||
      _selectedSubjectIds.isNotEmpty ||
      _selectedGroupIds.isNotEmpty ||
      _inactivityDays != null;

  void _resetAdvancedFilters() {
    setState(() {
      _selectedTeacherIds = {};
      _selectedSubjectIds = {};
      _selectedGroupIds = {};
      _inactivityDays = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Проверяем права
    final permissions = ref.watch(myPermissionsProvider(widget.institutionId));
    final institutionAsync = ref.watch(currentInstitutionProvider(widget.institutionId));
    final isOwner = institutionAsync.maybeWhen(
      data: (inst) => inst.ownerId == ref.watch(currentUserIdProvider),
      orElse: () => false,
    );
    final isAdmin = ref.watch(isAdminProvider(widget.institutionId));
    final hasFullAccess = isOwner || isAdmin;
    final canManageAllStudents = hasFullAccess || (permissions?.manageAllStudents ?? false);
    final canAddStudent = hasFullAccess ||
        (permissions?.manageOwnStudents ?? false) ||
        (permissions?.manageAllStudents ?? false);

    final filter = ref.watch(studentFilterProvider);
    final studentsAsync = ref.watch(filteredStudentsProvider(
      StudentFilterParams(institutionId: widget.institutionId, onlyMyStudents: !canManageAllStudents),
    ));

    // Загружаем данные для фильтров
    final teacherBindingsAsync = ref.watch(_studentTeacherBindingsProvider(widget.institutionId));
    final subjectBindingsAsync = ref.watch(_studentSubjectBindingsProvider(widget.institutionId));
    final groupBindingsAsync = ref.watch(_studentGroupBindingsProvider(widget.institutionId));
    final lastActivityAsync = ref.watch(_studentLastActivityProvider(widget.institutionId));

    // Для отображения в фильтрах
    final membersAsync = ref.watch(membersProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsListProvider(widget.institutionId));
    final groupsAsync = ref.watch(groupsProvider(widget.institutionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.students),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups),
            tooltip: 'Группы',
            onPressed: () => context.push('/institutions/${widget.institutionId}/groups'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Search
            },
          ),
        ],
      ),
      floatingActionButton: canAddStudent
          ? FloatingActionButton(
              onPressed: () => _showAddStudentDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          // Основные фильтры (Все/Мои/С долгом/Архив)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Все'),
                  selected: filter == StudentFilter.all,
                  onSelected: (_) => ref.read(studentFilterProvider.notifier).state = StudentFilter.all,
                ),
                if (canManageAllStudents) ...[
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Мои'),
                    selected: filter == StudentFilter.myStudents,
                    onSelected: (_) => ref.read(studentFilterProvider.notifier).state = StudentFilter.myStudents,
                  ),
                ],
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('С долгом'),
                  selected: filter == StudentFilter.withDebt,
                  onSelected: (_) => ref.read(studentFilterProvider.notifier).state = StudentFilter.withDebt,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Архив'),
                  selected: filter == StudentFilter.archived,
                  onSelected: (_) => ref.read(studentFilterProvider.notifier).state = StudentFilter.archived,
                ),
              ],
            ),
          ),

          // Расширенные фильтры (по преподавателю, направлению, группе, активности)
          if (canManageAllStudents) ...[
            const Divider(height: 1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Фильтр по преподавателю
                  _FilterButton(
                    label: 'Преподаватель',
                    isActive: _selectedTeacherIds.isNotEmpty,
                    onPressed: () => _showTeacherFilter(
                      membersAsync.valueOrNull ?? [],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Фильтр по направлению
                  _FilterButton(
                    label: 'Направление',
                    isActive: _selectedSubjectIds.isNotEmpty,
                    onPressed: () => _showSubjectFilter(
                      subjectsAsync.valueOrNull ?? [],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Фильтр по группе
                  _FilterButton(
                    label: 'Группа',
                    isActive: _selectedGroupIds.isNotEmpty,
                    onPressed: () => _showGroupFilter(
                      groupsAsync.valueOrNull ?? [],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Фильтр по активности
                  _FilterButton(
                    label: 'Активность',
                    isActive: _inactivityDays != null,
                    onPressed: () => _showActivityFilter(),
                  ),
                  // Кнопка сброса
                  if (_hasAdvancedFilters) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _resetAdvancedFilters,
                      child: const Text('Сбросить'),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Список учеников (НИКОГДА не показываем ошибку - используем valueOrNull)
          Expanded(
            child: Builder(
              builder: (context) {
                final students = studentsAsync.valueOrNull;

                // Показываем loading только при первой загрузке (нет данных)
                if (students == null) {
                  return const LoadingIndicator();
                }

                // Всегда показываем данные (даже если фоном идёт обновление или ошибка)
                // Применяем расширенные фильтры
                final filteredStudents = _applyAdvancedFilters(
                  students,
                  teacherBindings: teacherBindingsAsync.valueOrNull ?? {},
                  subjectBindings: subjectBindingsAsync.valueOrNull ?? {},
                  groupBindings: groupBindingsAsync.valueOrNull ?? {},
                  lastActivityMap: lastActivityAsync.valueOrNull ?? {},
                );

                if (filteredStudents.isEmpty) {
                  if (_hasAdvancedFilters) {
                    return _buildFilteredEmptyState();
                  }
                  return _buildEmptyState(context, ref, filter);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(filteredStudentsProvider(
                      StudentFilterParams(institutionId: widget.institutionId, onlyMyStudents: !canManageAllStudents),
                    ));
                    ref.invalidate(_studentTeacherBindingsProvider(widget.institutionId));
                    ref.invalidate(_studentSubjectBindingsProvider(widget.institutionId));
                    ref.invalidate(_studentGroupBindingsProvider(widget.institutionId));
                    ref.invalidate(_studentLastActivityProvider(widget.institutionId));
                  },
                  child: ListView.builder(
                    padding: AppSizes.paddingHorizontalM,
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = filteredStudents[index];
                      return _StudentCard(
                        student: student,
                        onTap: () {
                          context.go('/institutions/${widget.institutionId}/students/${student.id}');
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Применение расширенных фильтров
  List<Student> _applyAdvancedFilters(
    List<Student> students, {
    required Map<String, Set<String>> teacherBindings,
    required Map<String, Set<String>> subjectBindings,
    required Map<String, Set<String>> groupBindings,
    required Map<String, DateTime?> lastActivityMap,
  }) {
    if (!_hasAdvancedFilters) return students;

    return students.where((s) {
      // Фильтр по преподавателю
      if (_selectedTeacherIds.isNotEmpty) {
        final studentTeachers = teacherBindings.entries
            .where((e) => e.value.contains(s.id))
            .map((e) => e.key)
            .toSet();
        if (studentTeachers.intersection(_selectedTeacherIds).isEmpty) {
          return false;
        }
      }

      // Фильтр по направлению
      if (_selectedSubjectIds.isNotEmpty) {
        final studentSubjects = subjectBindings.entries
            .where((e) => e.value.contains(s.id))
            .map((e) => e.key)
            .toSet();
        if (studentSubjects.intersection(_selectedSubjectIds).isEmpty) {
          return false;
        }
      }

      // Фильтр по группе
      if (_selectedGroupIds.isNotEmpty) {
        final studentGroups = groupBindings.entries
            .where((e) => e.value.contains(s.id))
            .map((e) => e.key)
            .toSet();
        if (studentGroups.intersection(_selectedGroupIds).isEmpty) {
          return false;
        }
      }

      // Фильтр по активности (неактивные за N дней)
      if (_inactivityDays != null) {
        final lastActivity = lastActivityMap[s.id];
        if (lastActivity == null) {
          // Нет занятий вообще = неактивен
          return true;
        }
        final daysSinceLastLesson = DateTime.now().difference(lastActivity).inDays;
        if (daysSinceLastLesson < _inactivityDays!) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Показать фильтр по преподавателю
  void _showTeacherFilter(List<InstitutionMember> members) {
    final activeMembers = members.where((m) => !m.isArchived).toList();

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Преподаватель',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedTeacherIds = {});
                        setSheetState(() {});
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Список преподавателей
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // "Все"
                    CheckboxListTile(
                      value: _selectedTeacherIds.isEmpty,
                      onChanged: (_) {
                        setState(() => _selectedTeacherIds = {});
                        setSheetState(() {});
                      },
                      title: const Text('Все'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    // Преподаватели
                    ...activeMembers.map((member) => CheckboxListTile(
                      value: _selectedTeacherIds.contains(member.userId),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedTeacherIds.add(member.userId);
                          } else {
                            _selectedTeacherIds.remove(member.userId);
                          }
                        });
                        setSheetState(() {});
                      },
                      title: Text(member.profile?.fullName ?? 'Без имени'),
                      controlAffinity: ListTileControlAffinity.leading,
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Показать фильтр по направлению
  void _showSubjectFilter(List<Subject> subjects) {
    final activeSubjects = subjects.where((s) => s.archivedAt == null).toList();

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Направление',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedSubjectIds = {});
                        setSheetState(() {});
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Список направлений
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // "Все"
                    CheckboxListTile(
                      value: _selectedSubjectIds.isEmpty,
                      onChanged: (_) {
                        setState(() => _selectedSubjectIds = {});
                        setSheetState(() {});
                      },
                      title: const Text('Все'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    // Направления
                    ...activeSubjects.map((subject) {
                      final color = subject.color != null
                          ? Color(int.parse('0xFF${subject.color!.replaceAll('#', '')}'))
                          : AppColors.primary;
                      return CheckboxListTile(
                        value: _selectedSubjectIds.contains(subject.id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedSubjectIds.add(subject.id);
                            } else {
                              _selectedSubjectIds.remove(subject.id);
                            }
                          });
                          setSheetState(() {});
                        },
                        title: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(subject.name),
                          ],
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Показать фильтр по группе
  void _showGroupFilter(List<StudentGroup> groups) {
    final activeGroups = groups.where((g) => g.archivedAt == null).toList();

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Группа',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedGroupIds = {});
                        setSheetState(() {});
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Список групп
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // "Все"
                    CheckboxListTile(
                      value: _selectedGroupIds.isEmpty,
                      onChanged: (_) {
                        setState(() => _selectedGroupIds = {});
                        setSheetState(() {});
                      },
                      title: const Text('Все'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    // Группы
                    ...activeGroups.map((group) => CheckboxListTile(
                      value: _selectedGroupIds.contains(group.id),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedGroupIds.add(group.id);
                          } else {
                            _selectedGroupIds.remove(group.id);
                          }
                        });
                        setSheetState(() {});
                      },
                      title: Text(group.name),
                      subtitle: Text('${group.membersCount} учеников'),
                      controlAffinity: ListTileControlAffinity.leading,
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Показать фильтр по активности
  void _showActivityFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Активность',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _inactivityDays = null);
                        setSheetState(() {});
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Опции
              RadioListTile<int?>(
                value: null,
                groupValue: _inactivityDays,
                onChanged: (value) {
                  setState(() => _inactivityDays = value);
                  setSheetState(() {});
                },
                title: const Text('Все'),
              ),
              RadioListTile<int?>(
                value: 7,
                groupValue: _inactivityDays,
                onChanged: (value) {
                  setState(() => _inactivityDays = value);
                  setSheetState(() {});
                },
                title: const Text('Нет занятий 7+ дней'),
              ),
              RadioListTile<int?>(
                value: 14,
                groupValue: _inactivityDays,
                onChanged: (value) {
                  setState(() => _inactivityDays = value);
                  setSheetState(() {});
                },
                title: const Text('Нет занятий 14+ дней'),
              ),
              RadioListTile<int?>(
                value: 30,
                groupValue: _inactivityDays,
                onChanged: (value) {
                  setState(() => _inactivityDays = value);
                  setSheetState(() {});
                },
                title: const Text('Нет занятий 30+ дней'),
              ),
              RadioListTile<int?>(
                value: 60,
                groupValue: _inactivityDays,
                onChanged: (value) {
                  setState(() => _inactivityDays = value);
                  setSheetState(() {});
                },
                title: const Text('Нет занятий 60+ дней'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Нет учеников по заданным фильтрам',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _resetAdvancedFilters,
            child: const Text('Сбросить фильтры'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, StudentFilter filter) {
    switch (filter) {
      case StudentFilter.archived:
        return const EmptyState(
          icon: Icons.archive_outlined,
          title: 'Архив пуст',
          subtitle: 'Здесь будут отображаться архивированные ученики',
        );
      case StudentFilter.withDebt:
        return const EmptyState(
          icon: Icons.check_circle_outlined,
          title: 'Нет учеников с долгом',
          subtitle: 'У всех учеников положительный баланс',
        );
      case StudentFilter.myStudents:
        return const EmptyState(
          icon: Icons.person_outlined,
          title: 'Нет привязанных учеников',
          subtitle: 'К вам пока не привязаны ученики',
        );
      case StudentFilter.all:
        return EmptyState(
          icon: Icons.person_outlined,
          title: 'Нет учеников',
          subtitle: 'Добавьте первого ученика',
          action: ElevatedButton.icon(
            onPressed: () => _showAddStudentDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Добавить ученика'),
          ),
        );
    }
  }

  void _showAddStudentDialog(BuildContext context, WidgetRef ref) {
    final permissions = ref.read(myPermissionsProvider(widget.institutionId));
    final institutionAsync = ref.read(currentInstitutionProvider(widget.institutionId));
    final currentUserId = ref.read(currentUserIdProvider);
    final isOwner = institutionAsync.maybeWhen(
      data: (inst) => inst.ownerId == currentUserId,
      orElse: () => false,
    );
    final isAdmin = ref.read(isAdminProvider(widget.institutionId));
    final hasFullAccess = isOwner || isAdmin;
    final canManageAllStudents = hasFullAccess || (permissions?.manageAllStudents ?? false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _AddStudentSheet(
        institutionId: widget.institutionId,
        canManageAllStudents: canManageAllStudents,
        currentUserId: currentUserId,
      ),
    );
  }
}

// ============================================================================
// ВИДЖЕТ КНОПКИ ФИЛЬТРА
// ============================================================================

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _FilterButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.primary : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: isActive ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ФОРМА СОЗДАНИЯ УЧЕНИКА
// ============================================================================

/// Форма создания нового ученика
class _AddStudentSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final bool canManageAllStudents;
  final String? currentUserId;

  const _AddStudentSheet({
    required this.institutionId,
    required this.canManageAllStudents,
    this.currentUserId,
  });

  @override
  ConsumerState<_AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends ConsumerState<_AddStudentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commentController = TextEditingController();

  InstitutionMember? _selectedTeacher;
  Subject? _selectedSubject;
  bool _isLoading = false;
  bool _teacherInitialized = false;
  bool _subjectInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(studentControllerProvider.notifier);
      final student = await controller.create(
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.isEmpty ? null : _phoneController.text.trim(),
        comment: _commentController.text.isEmpty ? null : _commentController.text.trim(),
      );

      if (student != null) {
        // Создаём привязки если выбраны
        if (_selectedTeacher != null || _selectedSubject != null) {
          final bindingsController = ref.read(studentBindingsControllerProvider.notifier);

          if (_selectedTeacher != null) {
            await bindingsController.addTeacher(
              studentId: student.id,
              userId: _selectedTeacher!.userId,
              institutionId: widget.institutionId,
            );
          }

          if (_selectedSubject != null) {
            await bindingsController.addSubject(
              studentId: student.id,
              subjectId: _selectedSubject!.id,
              institutionId: widget.institutionId,
            );
          }

          // Принудительно обновляем список учеников для обновления myStudentIds
          ref.invalidate(filteredStudentsProvider(
            StudentFilterParams(institutionId: widget.institutionId, onlyMyStudents: true),
          ));
          ref.invalidate(filteredStudentsProvider(
            StudentFilterParams(institutionId: widget.institutionId, onlyMyStudents: false),
          ));
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ученик "${student.name}" создан'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersStreamProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsListProvider(widget.institutionId));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Индикатор
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Заголовок
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Новый ученик',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Заполните данные ученика',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ФИО
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'ФИО *',
                    hintText: 'Иванов Иван Иванович',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Введите имя ученика' : null,
                ),
                const SizedBox(height: 16),

                // Телефон
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Телефон',
                    hintText: '+7 (777) 123-45-67',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Преподаватель
                membersAsync.when(
                  loading: () => _buildDropdownSkeleton('Преподаватель'),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (members) {
                    // Показываем всех активных участников
                    final activeMembers = members.where((m) => !m.isArchived).toList();

                    // Если нет прав на управление всеми учениками - автоматически привязываем к текущему пользователю
                    if (!widget.canManageAllStudents && !_teacherInitialized) {
                      final currentMember = activeMembers.where((m) => m.userId == widget.currentUserId).firstOrNull;
                      if (currentMember != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _selectedTeacher = currentMember;
                              _teacherInitialized = true;
                            });
                            // Автовыбор направления если у преподавателя только одно
                            _autoSelectSubjectForTeacher(currentMember.userId);
                          }
                        });
                      }
                    }

                    // Если нет прав - показываем только информацию без возможности изменить
                    if (!widget.canManageAllStudents) {
                      final teacherName = _selectedTeacher?.profile?.fullName ?? 'Вы';
                      return InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Преподаватель',
                          prefixIcon: const Icon(Icons.school_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        child: Text(
                          teacherName,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      );
                    }

                    if (activeMembers.isEmpty) {
                      return InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Преподаватель',
                          prefixIcon: const Icon(Icons.school_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                        ),
                        child: Text(
                          'Нет доступных преподавателей',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      );
                    }

                    return DropdownButtonFormField<InstitutionMember>(
                      value: _selectedTeacher,
                      decoration: InputDecoration(
                        labelText: 'Преподаватель',
                        prefixIcon: const Icon(Icons.school_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      ),
                      dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
                      hint: const Text('Выберите преподавателя'),
                      items: activeMembers.map((member) => DropdownMenuItem(
                        value: member,
                        child: Text(
                          member.profile?.fullName ?? 'Без имени',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (value) {
                        setState(() => _selectedTeacher = value);
                        // Автовыбор направления если у преподавателя только одно
                        if (value != null) {
                          _autoSelectSubjectForTeacher(value.userId);
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Направление
                subjectsAsync.when(
                  loading: () => _buildDropdownSkeleton('Направление'),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (subjects) {
                    final activeSubjects = subjects.where((s) => s.archivedAt == null).toList();

                    return DropdownButtonFormField<Subject>(
                      value: _selectedSubject,
                      decoration: InputDecoration(
                        labelText: 'Направление',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      ),
                      dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
                      hint: const Text('Выберите направление'),
                      items: activeSubjects.map((subject) {
                        final color = subject.color != null
                            ? Color(int.parse('0xFF${subject.color!.replaceAll('#', '')}'))
                            : AppColors.primary;
                        return DropdownMenuItem(
                          value: subject,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(subject.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedSubject = value),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Комментарий
                TextFormField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    labelText: 'Комментарий',
                    hintText: 'Дополнительная информация...',
                    prefixIcon: const Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 28),

                // Кнопки
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createStudent,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Создать ученика',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Автовыбор направления если у преподавателя только одно
  Future<void> _autoSelectSubjectForTeacher(String userId) async {
    if (_subjectInitialized) return;

    try {
      final teacherSubjects = await ref.read(
        teacherSubjectsProvider(
          TeacherSubjectsParams(
            userId: userId,
            institutionId: widget.institutionId,
          ),
        ).future,
      );

      if (teacherSubjects.length == 1 && mounted) {
        final subjectsAsync = ref.read(subjectsListProvider(widget.institutionId));
        final subjects = subjectsAsync.valueOrNull ?? [];
        final activeSubjects = subjects.where((s) => s.archivedAt == null).toList();
        final matchingSubject = activeSubjects.firstWhere(
          (s) => s.id == teacherSubjects.first.subjectId,
          orElse: () => teacherSubjects.first.subject!,
        );

        setState(() {
          _selectedSubject = matchingSubject;
          _subjectInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Ошибка автовыбора направления: $e');
    }
  }

  Widget _buildDropdownSkeleton(String label) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}

// ============================================================================
// КАРТОЧКА УЧЕНИКА
// ============================================================================

class _StudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;

  const _StudentCard({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasDebt = student.balance < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
              '${student.balance} занятий',
              style: TextStyle(
                color: hasDebt ? AppColors.error : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
