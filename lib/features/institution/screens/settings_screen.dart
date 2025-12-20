import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/features/auth/providers/auth_provider.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';

/// Экран настроек заведения
class SettingsScreen extends ConsumerWidget {
  final String institutionId;

  const SettingsScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutionAsync = ref.watch(currentInstitutionProvider(institutionId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final controllerState = ref.watch(institutionControllerProvider);

    // Показать ошибку
    ref.listen(institutionControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: institutionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Ошибка загрузки: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentInstitutionProvider(institutionId)),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
        data: (institution) {
          final isOwner = institution.ownerId == currentUserId;

          return ListView(
            children: [
              const _SectionHeader(title: 'ЗАВЕДЕНИЕ'),
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Название'),
                subtitle: Text(institution.name),
                trailing: isOwner ? const Icon(Icons.chevron_right) : null,
                onTap: isOwner
                    ? () => _showEditNameDialog(context, ref, institution.name)
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Пригласить участника'),
                subtitle: Text('Код: ${institution.inviteCode}'),
                trailing: const Icon(Icons.copy),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: institution.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Код скопирован в буфер обмена'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const Divider(),
              const _SectionHeader(title: 'УПРАВЛЕНИЕ'),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Статистика'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/institutions/$institutionId/statistics');
                },
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text(AppStrings.teamMembers),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/institutions/$institutionId/members');
                },
              ),
              ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text(AppStrings.subjects),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/institutions/$institutionId/subjects');
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_note),
                title: const Text(AppStrings.lessonTypes),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/institutions/$institutionId/lesson-types');
                },
              ),
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text(AppStrings.paymentPlans),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/institutions/$institutionId/payment-plans');
                },
              ),
              const Divider(),
              const _SectionHeader(title: 'АККАУНТ'),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text(AppStrings.profile),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navigate to profile
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  AppStrings.logout,
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Выход'),
                      content: const Text('Вы уверены, что хотите выйти?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Выйти', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  }
                },
              ),
              const Divider(),
              const _SectionHeader(title: 'ОПАСНАЯ ЗОНА'),
              ListTile(
                leading: Icon(
                  isOwner ? Icons.archive : Icons.exit_to_app,
                  color: Colors.orange,
                ),
                title: Text(
                  isOwner ? 'Архивировать заведение' : 'Покинуть заведение',
                  style: const TextStyle(color: Colors.orange),
                ),
                subtitle: Text(
                  isOwner
                      ? 'Заведение можно будет восстановить'
                      : 'Вы больше не будете участником',
                ),
                enabled: !controllerState.isLoading,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(isOwner ? 'Архивировать заведение?' : 'Покинуть заведение?'),
                      content: Text(
                        isOwner
                            ? 'Заведение "${institution.name}" будет перемещено в архив. Вы сможете восстановить его позже из списка заведений.'
                            : 'Вы уверены, что хотите покинуть "${institution.name}"? Чтобы вернуться, вам понадобится новый код приглашения.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            isOwner ? 'Архивировать' : 'Покинуть',
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    final controller = ref.read(institutionControllerProvider.notifier);
                    bool success;

                    if (isOwner) {
                      success = await controller.archive(institutionId);
                    } else {
                      success = await controller.leave(institutionId);
                    }

                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isOwner
                                ? 'Заведение архивировано'
                                : 'Вы покинули заведение',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      context.go('/institutions');
                    }
                  }
                },
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final nameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Название заведения'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Название'),
            validator: (v) => v == null || v.isEmpty ? 'Введите название' : null,
            autofocus: true,
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
                final controller = ref.read(institutionControllerProvider.notifier);
                final success = await controller.update(
                  institutionId,
                  nameController.text.trim(),
                );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Название обновлено')),
                  );
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
