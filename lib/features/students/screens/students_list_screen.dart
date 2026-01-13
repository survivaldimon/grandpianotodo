import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:kabinet/features/students/widgets/merge_students_dialog.dart';
import 'package:kabinet/features/bookings/providers/booking_provider.dart';
import 'package:kabinet/features/bookings/repositories/booking_repository.dart';
import 'package:kabinet/features/payments/repositories/payment_repository.dart';
import 'package:kabinet/features/rooms/providers/room_provider.dart';
import 'package:kabinet/features/lesson_types/providers/lesson_type_provider.dart';
import 'package:kabinet/shared/models/lesson_type.dart';
import 'package:kabinet/core/widgets/ios_time_picker.dart';
import 'package:kabinet/core/providers/phone_settings_provider.dart';

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

/// Связи: studentId → список имён преподавателей
final _studentTeacherNamesProvider =
    FutureProvider.family<Map<String, List<String>>, String>((ref, institutionId) async {
  final client = SupabaseConfig.client;

  // Получаем связи student_teachers
  final bindingsData = await client
      .from('student_teachers')
      .select('student_id, user_id')
      .eq('institution_id', institutionId);

  // Получаем имена участников
  final membersData = await client
      .from('institution_members')
      .select('user_id, profiles(full_name)')
      .eq('institution_id', institutionId);

  // Создаём map userId → имя
  final userNames = <String, String>{};
  for (final member in membersData as List) {
    final userId = member['user_id'] as String;
    final profile = member['profiles'] as Map<String, dynamic>?;
    final fullName = profile?['full_name'] as String? ?? 'Без имени';
    userNames[userId] = fullName;
  }

  // Создаём map studentId → список имён преподавателей
  final result = <String, List<String>>{};
  for (final binding in bindingsData as List) {
    final studentId = binding['student_id'] as String;
    final userId = binding['user_id'] as String;
    final teacherName = userNames[userId];
    if (teacherName != null) {
      result.putIfAbsent(studentId, () => []).add(teacherName);
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

class _StudentsListScreenState extends ConsumerState<StudentsListScreen>
    with SingleTickerProviderStateMixin {
  // TabController для вкладок Ученики/Группы
  late TabController _tabController;
  int _currentTabIndex = 0;

  // Режим множественного выбора для объединения
  bool _isSelectionMode = false;
  Set<String> _selectedStudentIds = {};

  // Поиск по имени (поле под фильтрами)
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Расширенные фильтры
  Set<String> _selectedTeacherIds = {};
  Set<String> _selectedSubjectIds = {};
  Set<String> _selectedGroupIds = {};
  int? _inactivityDays; // null = все, 7/14/30/60 дней без занятий

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _currentTabIndex = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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

  void _enterSelectionMode(String studentId) {
    setState(() {
      _isSelectionMode = true;
      _selectedStudentIds = {studentId};
    });
    HapticFeedback.mediumImpact();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedStudentIds = {};
    });
  }

  void _toggleStudentSelection(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
        if (_selectedStudentIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }

  Future<void> _mergeSelectedStudents(List<Student> allStudents) async {
    final selectedStudents = allStudents
        .where((s) => _selectedStudentIds.contains(s.id))
        .toList();

    if (selectedStudents.length < 2) return;

    final newStudent = await MergeStudentsDialog.show(
      context,
      students: selectedStudents,
      institutionId: widget.institutionId,
      onMerged: () {
        ref.invalidate(studentsProvider(widget.institutionId));
      },
    );

    if (newStudent != null && mounted) {
      _exitSelectionMode();
      context.go('/institutions/${widget.institutionId}/students/${newStudent.id}');
    }
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

    // Имена преподавателей для отображения (только если видим всех учеников)
    final teacherNamesAsync = canManageAllStudents
        ? ref.watch(_studentTeacherNamesProvider(widget.institutionId))
        : null;

    // Для отображения в фильтрах
    final membersAsync = ref.watch(membersProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsListProvider(widget.institutionId));
    final groupsAsync = ref.watch(groupsProvider(widget.institutionId));

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        title: _isSelectionMode
            ? Text('Выбрано: ${_selectedStudentIds.length}')
            : const Text(AppStrings.students),
        bottom: _isSelectionMode
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Ученики', icon: Icon(Icons.person)),
                  Tab(text: 'Группы', icon: Icon(Icons.groups)),
                ],
              ),
      ),
      floatingActionButton: _buildFab(canAddStudent, studentsAsync.valueOrNull ?? []),
      body: _isSelectionMode
          ? _buildStudentsList(
              studentsAsync,
              teacherBindingsAsync,
              subjectBindingsAsync,
              groupBindingsAsync,
              lastActivityAsync,
              canManageAllStudents,
            )
          : TabBarView(
        controller: _tabController,
        children: [
          // ========== ВКЛАДКА УЧЕНИКОВ ==========
          Column(
            children: [
              // Поле поиска по имени
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск по имени...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),

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
                    var filteredStudents = _applyAdvancedFilters(
                      students,
                      teacherBindings: teacherBindingsAsync.valueOrNull ?? {},
                      subjectBindings: subjectBindingsAsync.valueOrNull ?? {},
                      groupBindings: groupBindingsAsync.valueOrNull ?? {},
                      lastActivityMap: lastActivityAsync.valueOrNull ?? {},
                    );

                    // Применяем поиск по имени
                    if (_searchQuery.isNotEmpty) {
                      filteredStudents = filteredStudents
                          .where((s) => s.name.toLowerCase().contains(_searchQuery))
                          .toList();
                    }

                    if (filteredStudents.isEmpty) {
                      if (_searchQuery.isNotEmpty) {
                        return _buildSearchEmptyState();
                      }
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
                        ref.invalidate(_studentTeacherNamesProvider(widget.institutionId));
                      },
                      child: ListView.builder(
                        padding: AppSizes.paddingHorizontalM,
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final isSelected = _selectedStudentIds.contains(student.id);
                          // Получаем имена преподавателей для этого ученика
                          final teacherNames = teacherNamesAsync?.valueOrNull?[student.id];
                          return _StudentCard(
                            student: student,
                            teacherNames: teacherNames,
                            isSelectionMode: _isSelectionMode,
                            isSelected: isSelected,
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleStudentSelection(student.id);
                              } else {
                                context.go('/institutions/${widget.institutionId}/students/${student.id}');
                              }
                            },
                            onLongPress: () {
                              if (!_isSelectionMode && !student.isArchived) {
                                _enterSelectionMode(student.id);
                              }
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

          // ========== ВКЛАДКА ГРУПП ==========
          _GroupsTab(
            institutionId: widget.institutionId,
            groups: groupsAsync.valueOrNull ?? [],
            isLoading: groupsAsync.isLoading && groupsAsync.valueOrNull == null,
            onRefresh: () => ref.invalidate(groupsProvider(widget.institutionId)),
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
              RadioGroup<int?>(
                groupValue: _inactivityDays,
                onChanged: (value) {
                  setState(() => _inactivityDays = value);
                  setSheetState(() {});
                },
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<int?>(
                      value: null,
                      title: Text('Все'),
                    ),
                    RadioListTile<int?>(
                      value: 7,
                      title: Text('Нет занятий 7+ дней'),
                    ),
                    RadioListTile<int?>(
                      value: 14,
                      title: Text('Нет занятий 14+ дней'),
                    ),
                    RadioListTile<int?>(
                      value: 30,
                      title: Text('Нет занятий 30+ дней'),
                    ),
                    RadioListTile<int?>(
                      value: 60,
                      title: Text('Нет занятий 60+ дней'),
                    ),
                  ],
                ),
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

  Widget _buildSearchEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Ничего не найдено',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Попробуйте изменить запрос',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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

  /// Список учеников для режима выбора
  Widget _buildStudentsList(
    AsyncValue<List<Student>> studentsAsync,
    AsyncValue<Map<String, Set<String>>> teacherBindingsAsync,
    AsyncValue<Map<String, Set<String>>> subjectBindingsAsync,
    AsyncValue<Map<String, Set<String>>> groupBindingsAsync,
    AsyncValue<Map<String, DateTime?>> lastActivityAsync,
    bool canManageAllStudents,
  ) {
    final students = studentsAsync.valueOrNull;
    if (students == null) {
      return const LoadingIndicator();
    }

    final filteredStudents = _applyAdvancedFilters(
      students,
      teacherBindings: teacherBindingsAsync.valueOrNull ?? {},
      subjectBindings: subjectBindingsAsync.valueOrNull ?? {},
      groupBindings: groupBindingsAsync.valueOrNull ?? {},
      lastActivityMap: lastActivityAsync.valueOrNull ?? {},
    );

    // Исключаем архивированных в режиме выбора
    final selectableStudents = filteredStudents
        .where((s) => s.archivedAt == null)
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(filteredStudentsProvider(
          StudentFilterParams(
              institutionId: widget.institutionId,
              onlyMyStudents: !canManageAllStudents),
        ));
      },
      child: ListView.builder(
        padding: AppSizes.paddingHorizontalM,
        itemCount: selectableStudents.length,
        itemBuilder: (context, index) {
          final student = selectableStudents[index];
          final isSelected = _selectedStudentIds.contains(student.id);
          return _StudentCard(
            student: student,
            isSelectionMode: true,
            isSelected: isSelected,
            onTap: () => _toggleStudentSelection(student.id),
            onLongPress: null,
          );
        },
      ),
    );
  }

  /// FAB по контексту текущей вкладки
  Widget? _buildFab(bool canAddStudent, List<Student> allStudents) {
    // В режиме выбора — кнопка объединения
    if (_isSelectionMode) {
      final canMerge = _selectedStudentIds.length >= 2;
      return FloatingActionButton.extended(
        onPressed: canMerge ? () => _mergeSelectedStudents(allStudents) : null,
        backgroundColor: canMerge ? AppColors.primary : Theme.of(context).disabledColor,
        icon: const Icon(Icons.merge),
        label: Text('Объединить (${_selectedStudentIds.length})'),
      );
    }

    if (_currentTabIndex == 0) {
      // Вкладка Ученики
      if (!canAddStudent) return null;
      return FloatingActionButton(
        onPressed: () => _showAddStudentDialog(context, ref),
        child: const Icon(Icons.add),
      );
    } else {
      // Вкладка Группы
      return FloatingActionButton(
        onPressed: () => _showAddGroupDialog(context, ref),
        child: const Icon(Icons.add),
      );
    }
  }

  /// Диалог создания группы
  void _showAddGroupDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новая группа'),
        content: Form(
          key: formKey,
          child: TextFormField(
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
                institutionId: widget.institutionId,
                name: nameController.text.trim(),
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              if (group != null && context.mounted) {
                // Переходим к деталям группы
                context.push('/institutions/${widget.institutionId}/groups/${group.id}');
              }
            },
            child: const Text('Создать'),
          ),
        ],
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
  final _legacyBalanceController = TextEditingController();

  InstitutionMember? _selectedTeacher;
  Subject? _selectedSubject;
  LessonType? _selectedLessonType;
  bool _isLoading = false;
  bool _teacherInitialized = false;
  bool _subjectInitialized = false;
  bool _lessonTypeInitialized = false;

  // Настройки расписания
  bool _setupSchedule = false;
  final Set<int> _selectedDays = {};
  final Map<int, TimeOfDay> _startTimes = {};
  final Map<int, TimeOfDay> _endTimes = {};
  String? _selectedRoomId;

  static const _defaultStartTime = TimeOfDay(hour: 14, minute: 0);
  static const _defaultEndTime = TimeOfDay(hour: 15, minute: 0);

  @override
  void initState() {
    super.initState();
    // Автозаполнение кода страны в поле телефона
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final prefix = ref.read(phoneDefaultPrefixProvider);
        if (prefix.isNotEmpty && _phoneController.text.isEmpty) {
          _phoneController.text = '$prefix ';
          // Ставим курсор в конец
          _phoneController.selection = TextSelection.fromPosition(
            TextPosition(offset: _phoneController.text.length),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    _legacyBalanceController.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate()) return;

    // Валидация расписания если настроено
    if (_setupSchedule && _selectedDays.isNotEmpty && _selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите кабинет для расписания')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(studentControllerProvider.notifier);
      final initialBalance = int.tryParse(_legacyBalanceController.text.trim()) ?? 0;

      // Создаём ученика БЕЗ legacyBalance (новая система balance_transfer)
      final student = await controller.create(
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.isEmpty ? null : _phoneController.text.trim(),
        comment: _commentController.text.isEmpty ? null : _commentController.text.trim(),
        legacyBalance: 0, // Всегда 0 — баланс теперь через balance_transfer
      );

      if (student != null) {
        // Если введён начальный баланс — создаём запись balance_transfer
        if (initialBalance > 0) {
          try {
            final paymentRepo = PaymentRepository();
            await paymentRepo.createBalanceTransfer(
              institutionId: widget.institutionId,
              studentId: student.id,
              lessonsCount: initialBalance,
              comment: 'Начальный остаток',
            );
            // Инвалидируем провайдеры для обновления баланса
            ref.invalidate(studentProvider(student.id));
            ref.invalidate(studentsProvider(widget.institutionId));
          } catch (e) {
            // Не критичная ошибка — ученик создан, но баланс не добавлен
            debugPrint('Error creating balance transfer: $e');
          }
        }

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

        // Создаём постоянное расписание если настроено
        if (_setupSchedule && _selectedDays.isNotEmpty && _selectedRoomId != null) {
          await _createScheduleSlots(student.id);
        }

        if (mounted) {
          Navigator.pop(context);
          final message = _setupSchedule && _selectedDays.isNotEmpty
              ? 'Ученик "${student.name}" создан с расписанием'
              : 'Ученик "${student.name}" создан';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
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

  /// Создаёт слоты постоянного расписания для ученика (weekly bookings)
  Future<void> _createScheduleSlots(String studentId) async {
    final bookingController = ref.read(bookingControllerProvider.notifier);
    final teacherId = _selectedTeacher?.userId ?? widget.currentUserId;

    if (teacherId == null || _selectedRoomId == null) return;

    try {
      if (_selectedDays.length == 1) {
        final day = _selectedDays.first;
        await bookingController.createRecurring(
          institutionId: widget.institutionId,
          studentId: studentId,
          teacherId: teacherId,
          roomId: _selectedRoomId!,
          subjectId: _selectedSubject?.id,
          dayOfWeek: day,
          startTime: _startTimes[day]!,
          endTime: _endTimes[day]!,
        );
      } else {
        final slots = _selectedDays.map((day) => DayTimeSlot(
          dayOfWeek: day,
          startTime: _startTimes[day]!,
          endTime: _endTimes[day]!,
        )).toList();

        await bookingController.createRecurringBatch(
          institutionId: widget.institutionId,
          studentId: studentId,
          teacherId: teacherId,
          roomId: _selectedRoomId!,
          subjectId: _selectedSubject?.id,
          slots: slots,
        );
      }
    } catch (e) {
      debugPrint('Ошибка создания расписания: $e');
      // Не прерываем — ученик уже создан
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersStreamProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsListProvider(widget.institutionId));
    final lessonTypesAsync = ref.watch(lessonTypesProvider(widget.institutionId));

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

                    // Автозаполнение текущего пользователя как преподавателя для ВСЕХ
                    if (!_teacherInitialized) {
                      final currentMember = activeMembers.where((m) => m.userId == widget.currentUserId).firstOrNull;
                      if (currentMember != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && !_teacherInitialized) {
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

                    // Ищем соответствующий элемент в списке по userId
                    final effectiveTeacher = _selectedTeacher != null
                        ? activeMembers.where((m) => m.userId == _selectedTeacher!.userId).firstOrNull
                        : null;

                    return DropdownButtonFormField<InstitutionMember>(
                      key: ValueKey('teacher_${effectiveTeacher?.userId}'),
                      value: effectiveTeacher,
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

                    // Ищем соответствующий элемент в списке по id
                    final effectiveSubject = _selectedSubject != null
                        ? activeSubjects.where((s) => s.id == _selectedSubject!.id).firstOrNull
                        : null;

                    return DropdownButtonFormField<Subject>(
                      key: ValueKey('subject_${effectiveSubject?.id}'),
                      value: effectiveSubject,
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

                // Тип занятия
                lessonTypesAsync.when(
                  loading: () => _buildDropdownSkeleton('Тип занятия'),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (lessonTypes) {
                    final activeTypes = lessonTypes.where((t) => t.archivedAt == null).toList();

                    // Автовыбор если только один тип занятия
                    if (activeTypes.length == 1 && !_lessonTypeInitialized) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_lessonTypeInitialized) {
                          setState(() {
                            _selectedLessonType = activeTypes.first;
                            _lessonTypeInitialized = true;
                          });
                        }
                      });
                    }

                    if (activeTypes.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    // Ищем соответствующий элемент в списке по id
                    final effectiveLessonType = _selectedLessonType != null
                        ? activeTypes.where((t) => t.id == _selectedLessonType!.id).firstOrNull
                        : null;

                    return DropdownButtonFormField<LessonType>(
                      key: ValueKey('lessonType_${effectiveLessonType?.id}'),
                      value: effectiveLessonType,
                      decoration: InputDecoration(
                        labelText: 'Тип занятия',
                        prefixIcon: const Icon(Icons.event_note_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      ),
                      dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
                      hint: const Text('Выберите тип занятия'),
                      items: activeTypes.map((type) {
                        final color = type.color != null
                            ? Color(int.parse('0xFF${type.color!.replaceAll('#', '')}'))
                            : AppColors.primary;
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                              Text(
                                type.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedLessonType = value),
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
                const SizedBox(height: 16),

                // Остаток занятий (для переносимых учеников)
                TextFormField(
                  controller: _legacyBalanceController,
                  decoration: InputDecoration(
                    labelText: 'Остаток занятий',
                    hintText: 'При переносе из другой школы',
                    prefixIcon: const Icon(Icons.sync_alt_outlined),
                    suffixText: 'занятий',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                    helperText: 'Списывается первым, не влияет на доход',
                    helperMaxLines: 2,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),

                // Постоянное расписание (опционально)
                _buildScheduleSection(),
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

  /// Секция настройки постоянного расписания
  Widget _buildScheduleSection() {
    final roomsAsync = ref.watch(roomsStreamProvider(widget.institutionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Чекбокс для включения настройки расписания
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _setupSchedule = !_setupSchedule),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _setupSchedule
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _setupSchedule
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _setupSchedule ? Icons.check_box : Icons.check_box_outline_blank,
                  color: _setupSchedule
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Настроить постоянное расписание',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Выберите дни и время занятий',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _setupSchedule ? Icons.expand_less : Icons.expand_more,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
          ),
        ),

        // Развёрнутая секция расписания
        if (_setupSchedule) ...[
          const SizedBox(height: 16),

          // Кабинет
          roomsAsync.when(
            loading: () => _buildDropdownSkeleton('Кабинет'),
            error: (_, __) => const SizedBox.shrink(),
            data: (rooms) {
              if (rooms.isEmpty) return const SizedBox.shrink();

              // Автовыбор первого кабинета
              if (_selectedRoomId == null && rooms.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedRoomId == null) {
                    setState(() => _selectedRoomId = rooms.first.id);
                  }
                });
              }

              return DropdownButtonFormField<String>(
                key: ValueKey('room_$_selectedRoomId'),
                initialValue: _selectedRoomId,
                decoration: InputDecoration(
                  labelText: 'Кабинет для занятий',
                  prefixIcon: const Icon(Icons.meeting_room_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                ),
                dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
                items: rooms.map((r) => DropdownMenuItem(
                  value: r.id,
                  child: Text(r.name),
                )).toList(),
                onChanged: (v) => setState(() => _selectedRoomId = v),
              );
            },
          ),
          const SizedBox(height: 16),

          // Дни недели
          Text(
            'Дни недели',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _buildDaysSelector(),

          // Время для выбранных дней
          if (_selectedDays.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Время занятий',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ..._buildDayTimeRows(),
          ],
        ],
      ],
    );
  }

  Widget _buildDaysSelector() {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (index) {
        final dayNumber = index + 1;
        final isSelected = _selectedDays.contains(dayNumber);

        return FilterChip(
          label: Text(days[index]),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedDays.add(dayNumber);
                _startTimes[dayNumber] = _defaultStartTime;
                _endTimes[dayNumber] = _defaultEndTime;
              } else {
                _selectedDays.remove(dayNumber);
                _startTimes.remove(dayNumber);
                _endTimes.remove(dayNumber);
              }
            });
          },
        );
      }),
    );
  }

  List<Widget> _buildDayTimeRows() {
    final sortedDays = _selectedDays.toList()..sort();
    return sortedDays.map((day) => _buildDayTimeRow(day)).toList();
  }

  Widget _buildDayTimeRow(int dayNumber) {
    const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final startTime = _startTimes[dayNumber] ?? _defaultStartTime;
    final endTime = _endTimes[dayNumber] ?? _defaultEndTime;

    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    final durationText = durationMinutes > 0
        ? (durationMinutes >= 60
            ? '${durationMinutes ~/ 60} ч${durationMinutes % 60 > 0 ? ' ${durationMinutes % 60} мин' : ''}'
            : '$durationMinutes мин')
        : 'Некорректно';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pickTimeRange(dayNumber),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    days[dayNumber],
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatTime(startTime)} — ${_formatTime(endTime)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      durationText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: durationMinutes > 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTimeRange(int dayNumber) async {
    final currentStart = _startTimes[dayNumber] ?? _defaultStartTime;
    final currentEnd = _endTimes[dayNumber] ?? _defaultEndTime;

    final result = await showIosTimeRangePicker(
      context: context,
      initialStartTime: currentStart,
      initialEndTime: currentEnd,
      minuteInterval: 5,
      minHour: 6,
      maxHour: 23,
    );

    if (result != null && mounted) {
      setState(() {
        _startTimes[dayNumber] = result.start;
        _endTimes[dayNumber] = result.end;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// ВКЛАДКА ГРУПП
// ============================================================================

class _GroupsTab extends StatelessWidget {
  final String institutionId;
  final List<StudentGroup> groups;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _GroupsTab({
    required this.institutionId,
    required this.groups,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingIndicator();
    }

    if (groups.isEmpty) {
      return const EmptyState(
        icon: Icons.groups,
        title: 'Нет групп',
        subtitle: 'Создайте первую группу учеников',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return _GroupCard(
            group: group,
            institutionId: institutionId,
          );
        },
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final StudentGroup group;
  final String institutionId;

  const _GroupCard({
    required this.group,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.groups, color: AppColors.primary),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${group.membersCount} ${_pluralize(group.membersCount, 'ученик', 'ученика', 'учеников')}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push('/institutions/$institutionId/groups/${group.id}');
        },
      ),
    );
  }

  String _pluralize(int count, String one, String few, String many) {
    if (count % 10 == 1 && count % 100 != 11) return one;
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return few;
    return many;
  }
}

// ============================================================================
// КАРТОЧКА УЧЕНИКА
// ============================================================================

class _StudentCard extends StatelessWidget {
  final Student student;
  final List<String>? teacherNames;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  const _StudentCard({
    required this.student,
    this.teacherNames,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasDebt = student.balance < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.1)
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Чекбокс в режиме выбора
              if (isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Аватар
              CircleAvatar(
                backgroundColor: hasDebt
                    ? AppColors.error.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person,
                  color: hasDebt ? AppColors.error : AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              // Информация
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    // Имя преподавателя (если есть)
                    if (teacherNames != null && teacherNames!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        teacherNames!.join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          hasDebt ? Icons.warning_amber : Icons.school,
                          size: 14,
                          color: hasDebt
                              ? AppColors.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${student.balance} занятий',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasDebt
                                ? AppColors.error
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Стрелка только если не режим выбора
              if (!isSelectionMode) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
