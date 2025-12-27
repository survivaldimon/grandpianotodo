import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/core/widgets/empty_state.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/teacher_subjects_provider.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/features/students/providers/student_bindings_provider.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subject.dart';
import 'package:kabinet/shared/models/institution_member.dart';

/// Экран списка учеников
class StudentsListScreen extends ConsumerWidget {
  final String institutionId;

  const StudentsListScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Проверяем права
    final permissions = ref.watch(myPermissionsProvider(institutionId));
    final institutionAsync = ref.watch(currentInstitutionProvider(institutionId));
    final isOwner = institutionAsync.maybeWhen(
      data: (inst) => inst.ownerId == ref.watch(currentUserIdProvider),
      orElse: () => false,
    );
    final isAdmin = ref.watch(isAdminProvider(institutionId));
    final hasFullAccess = isOwner || isAdmin;
    final canManageAllStudents = hasFullAccess || (permissions?.manageAllStudents ?? false);
    final canAddStudent = hasFullAccess ||
        (permissions?.manageOwnStudents ?? false) ||
        (permissions?.manageAllStudents ?? false);

    final filter = ref.watch(studentFilterProvider);
    final studentsAsync = ref.watch(filteredStudentsProvider(
      StudentFilterParams(institutionId: institutionId, onlyMyStudents: !canManageAllStudents),
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.students),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups),
            tooltip: 'Группы',
            onPressed: () => context.push('/institutions/$institutionId/groups'),
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
          // Filter chips
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
                // Кнопка "Мои" только для тех, кто видит всех учеников
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
          // Students list
          Expanded(
            child: studentsAsync.when(
              loading: () => const LoadingIndicator(),
              error: (error, _) => ErrorView.fromException(
                error,
                onRetry: () => ref.invalidate(filteredStudentsProvider(
                  StudentFilterParams(institutionId: institutionId, onlyMyStudents: !canManageAllStudents),
                )),
              ),
              data: (students) {
                if (students.isEmpty) {
                  return _buildEmptyState(context, ref, filter);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(filteredStudentsProvider(
                      StudentFilterParams(institutionId: institutionId, onlyMyStudents: !canManageAllStudents),
                    ));
                  },
                  child: ListView.builder(
                    padding: AppSizes.paddingHorizontalM,
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return _StudentCard(
                        student: student,
                        onTap: () {
                          context.go('/institutions/$institutionId/students/${student.id}');
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
    final permissions = ref.read(myPermissionsProvider(institutionId));
    final institutionAsync = ref.read(currentInstitutionProvider(institutionId));
    final currentUserId = ref.read(currentUserIdProvider);
    final isOwner = institutionAsync.maybeWhen(
      data: (inst) => inst.ownerId == currentUserId,
      orElse: () => false,
    );
    final isAdmin = ref.read(isAdminProvider(institutionId));
    final hasFullAccess = isOwner || isAdmin;
    final canManageAllStudents = hasFullAccess || (permissions?.manageAllStudents ?? false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _AddStudentSheet(
        institutionId: institutionId,
        canManageAllStudents: canManageAllStudents,
        currentUserId: currentUserId,
      ),
    );
  }
}

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
    final membersAsync = ref.watch(membersProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsListProvider(widget.institutionId));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      color: Colors.grey[300],
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Новый ученик',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Заполните данные ученика',
                            style: TextStyle(
                              color: AppColors.textSecondary,
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
                    fillColor: Colors.grey[50],
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
                    fillColor: Colors.grey[50],
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
                          fillColor: Colors.grey[100],
                        ),
                        child: Text(
                          teacherName,
                          style: const TextStyle(color: AppColors.textPrimary),
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
                          fillColor: Colors.grey[50],
                        ),
                        child: const Text(
                          'Нет доступных преподавателей',
                          style: TextStyle(color: AppColors.textSecondary),
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
                        fillColor: Colors.grey[50],
                      ),
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
                        fillColor: Colors.grey[50],
                      ),
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
                    fillColor: Colors.grey[50],
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
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

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
              ? AppColors.error.withOpacity(0.1)
              : AppColors.primary.withOpacity(0.1),
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
              color: hasDebt ? AppColors.error : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '${student.balance} занятий',
              style: TextStyle(
                color: hasDebt ? AppColors.error : AppColors.textSecondary,
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
