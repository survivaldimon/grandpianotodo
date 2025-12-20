import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/widgets/empty_state.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/features/auth/providers/auth_provider.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/shared/models/institution.dart';

/// Экран списка заведений пользователя
class InstitutionsListScreen extends ConsumerWidget {
  const InstitutionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutionsAsync = ref.watch(myInstitutionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.institutions),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Архив',
            onPressed: () => _showArchivedInstitutions(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: institutionsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(myInstitutionsProvider),
        ),
        data: (institutions) {
          if (institutions.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildInstitutionsList(context, ref, institutions);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.business_outlined,
      title: 'Нет заведений',
      subtitle: 'Создайте новое заведение или присоединитесь по коду',
      action: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () => context.push('/institutions/create'),
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.createInstitution),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/join'),
            icon: const Icon(Icons.group_add),
            label: const Text(AppStrings.joinInstitution),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionsList(
    BuildContext context,
    WidgetRef ref,
    List<Institution> institutions,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myInstitutionsProvider);
        await ref.read(myInstitutionsProvider.future);
      },
      child: ListView.builder(
        padding: AppSizes.paddingAllM,
        itemCount: institutions.length,
        itemBuilder: (context, index) {
          final institution = institutions[index];
          return _InstitutionCard(institution: institution);
        },
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: AppSizes.paddingAllL,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.add_business),
              title: const Text(AppStrings.createInstitution),
              onTap: () {
                Navigator.pop(context);
                context.push('/institutions/create');
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text(AppStrings.joinInstitution),
              onTap: () {
                Navigator.pop(context);
                context.push('/join');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showArchivedInstitutions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _ArchivedInstitutionsSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _InstitutionCard extends StatelessWidget {
  final Institution institution;

  const _InstitutionCard({required this.institution});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/institutions/${institution.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppSizes.paddingAllM,
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  institution.name.isNotEmpty
                      ? institution.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      institution.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Код: ${institution.inviteCode}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedInstitutionsSheet extends ConsumerWidget {
  final ScrollController scrollController;

  const _ArchivedInstitutionsSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedInstitutionsProvider);
    final controllerState = ref.watch(institutionControllerProvider);
    final theme = Theme.of(context);

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

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.archive),
              const SizedBox(width: 12),
              Text(
                'Архив заведений',
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: archivedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Ошибка: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(archivedInstitutionsProvider),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
            data: (institutions) {
              if (institutions.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Архив пуст'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: institutions.length,
                itemBuilder: (context, index) {
                  final institution = institutions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        child: Text(
                          institution.name.isNotEmpty
                              ? institution.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(institution.name),
                      subtitle: Text(
                        'Архивировано ${_formatDate(institution.archivedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: controllerState.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: 'Восстановить',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Восстановить заведение?'),
                                    content: Text(
                                      'Заведение "${institution.name}" будет восстановлено и появится в основном списке.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Отмена'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Восстановить'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true && context.mounted) {
                                  final success = await ref
                                      .read(institutionControllerProvider.notifier)
                                      .restore(institution.id);

                                  if (success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Заведение восстановлено'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
