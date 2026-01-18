import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/widgets/empty_state.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/features/auth/providers/auth_provider.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/shared/models/institution.dart';

/// Экран списка заведений пользователя
class InstitutionsListScreen extends ConsumerStatefulWidget {
  final bool skipAutoNav;

  const InstitutionsListScreen({super.key, this.skipAutoNav = false});

  @override
  ConsumerState<InstitutionsListScreen> createState() => _InstitutionsListScreenState();
}

class _InstitutionsListScreenState extends ConsumerState<InstitutionsListScreen> {
  bool _hasAutoNavigated = false;

  @override
  void initState() {
    super.initState();
    // Принудительно обновляем список заведений при открытии экрана
    Future.microtask(() {
      ref.invalidate(myInstitutionsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final institutionsAsync = ref.watch(myInstitutionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.institutions),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: l10n.archive,
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
      body: Builder(
        builder: (context) {
          final institutions = institutionsAsync.valueOrNull;

          // Показываем loading только при первой загрузке
          if (institutions == null) {
            return const LoadingIndicator();
          }

          // Всегда показываем данные (даже если фоном ошибка)
          // Автонавигация если только одно заведение (не при явном переходе)
          if (institutions.length == 1 && !_hasAutoNavigated && !widget.skipAutoNav) {
            _hasAutoNavigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.go('/institutions/${institutions.first.id}');
              }
            });
            return const LoadingIndicator();
          }
          if (institutions.isEmpty) {
            return _buildEmptyState(context, l10n);
          }
          return _buildInstitutionsList(context, ref, institutions);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return EmptyState(
      icon: Icons.business_outlined,
      title: l10n.noInstitutions,
      subtitle: l10n.createOrJoin,
      action: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () => context.push('/institutions/create'),
            icon: const Icon(Icons.add),
            label: Text(l10n.createInstitution),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/join'),
            icon: const Icon(Icons.group_add),
            label: Text(l10n.joinInstitution),
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
        try {
          ref.invalidate(myInstitutionsProvider);
          await ref.read(myInstitutionsProvider.future);
        } catch (e) {
          debugPrint('[InstitutionsListScreen] refresh error: $e');
        }
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
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Padding(
        padding: AppSizes.paddingAllL,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.add_business),
              title: Text(l10n.createInstitution),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/institutions/create');
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: Text(l10n.joinInstitution),
              onTap: () {
                Navigator.pop(sheetContext);
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
                child: Text(
                  institution.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
    final l10n = AppLocalizations.of(context);
    final archivedAsync = ref.watch(archivedInstitutionsProvider);
    final controllerState = ref.watch(institutionControllerProvider);
    final theme = Theme.of(context);

    // Показать ошибку
    ref.listen(institutionControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorView.getLocalizedErrorMessage(next.error!, l10n)),
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
                l10n.archivedInstitutions,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Builder(
            builder: (context) {
              final institutions = archivedAsync.valueOrNull;

              // Показываем loading только при первой загрузке
              if (institutions == null) {
                return const Center(child: CircularProgressIndicator());
              }

              // Всегда показываем данные (даже если фоном ошибка)
              if (institutions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(l10n.archiveEmpty),
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
                        l10n.archivedOn(_formatDate(institution.archivedAt)),
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
                              tooltip: l10n.restore,
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: Text(l10n.restoreInstitutionQuestion),
                                    content: Text(
                                      l10n.restoreInstitutionMessage(institution.name),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: Text(l10n.cancel),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        child: Text(l10n.restore),
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
                                      SnackBar(
                                        content: Text(l10n.institutionRestored),
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
