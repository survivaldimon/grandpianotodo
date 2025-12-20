import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/core/widgets/empty_state.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/shared/models/student.dart';

/// Экран списка учеников
class StudentsListScreen extends ConsumerWidget {
  final String institutionId;

  const StudentsListScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(studentFilterProvider);
    final studentsAsync = ref.watch(filteredStudentsProvider(institutionId));

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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddStudentDialog(context, ref),
          ),
        ],
      ),
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
              error: (error, _) => ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(filteredStudentsProvider(institutionId)),
              ),
              data: (students) {
                if (students.isEmpty) {
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
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(filteredStudentsProvider(institutionId));
                    await ref.read(filteredStudentsProvider(institutionId).future);
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

  void _showAddStudentDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final commentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый ученик'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'ФИО'),
                validator: (v) => v == null || v.isEmpty ? 'Введите имя' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Телефон'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: commentController,
                decoration: const InputDecoration(labelText: 'Комментарий'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final controller = ref.read(studentControllerProvider.notifier);
                final student = await controller.create(
                  institutionId: institutionId,
                  name: nameController.text.trim(),
                  phone: phoneController.text.isEmpty ? null : phoneController.text.trim(),
                  comment: commentController.text.isEmpty ? null : commentController.text.trim(),
                );
                if (student != null && context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Создать'),
          ),
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
