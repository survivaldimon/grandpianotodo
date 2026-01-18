import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/extensions/context_extensions.dart';
import 'package:kabinet/core/theme/theme_provider.dart';
import 'package:kabinet/core/providers/locale_provider.dart';
import 'package:kabinet/core/providers/phone_settings_provider.dart';
import 'package:kabinet/features/auth/providers/auth_provider.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/core/widgets/error_view.dart';

/// Экран настроек заведения
class SettingsScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const SettingsScreen({super.key, required this.institutionId});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Принудительно обновляем права при открытии экрана настроек
    Future.microtask(() {
      ref.invalidate(myMembershipProvider(widget.institutionId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final institutionId = widget.institutionId;
    final institutionAsync = ref.watch(currentInstitutionProvider(institutionId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final controllerState = ref.watch(institutionControllerProvider);

    // Показать ошибку
    ref.listen(institutionControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorView.getLocalizedErrorMessage(next.error!, context.l10n)),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings),
      ),
      body: institutionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('${context.l10n.error}: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentInstitutionProvider(institutionId)),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
        data: (institution) {
          final isOwner = institution.ownerId == currentUserId;
          final isAdmin = ref.watch(isAdminProvider(institutionId));
          // Админ имеет все права владельца, кроме удаления заведения
          final hasFullAccess = isOwner || isAdmin;
          // Проверяем права на управление заведением
          final permissions = ref.watch(myPermissionsProvider(institutionId));
          final canManageInstitution = hasFullAccess || (permissions?.manageInstitution ?? false);

          return ListView(
            children: [
              _SectionHeader(title: context.l10n.institutions.toUpperCase()),
              ListTile(
                leading: const Icon(Icons.business),
                title: Text(context.l10n.institutionName),
                subtitle: Text(institution.name),
                trailing: canManageInstitution ? const Icon(Icons.chevron_right) : null,
                onTap: canManageInstitution
                    ? () => _showEditNameDialog(context, ref, institution.name)
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(context.l10n.workingHours),
                subtitle: Text(
                  '${institution.workStartHour.toString().padLeft(2, '0')}:00 — ${institution.workEndHour.toString().padLeft(2, '0')}:00',
                ),
                trailing: canManageInstitution ? const Icon(Icons.chevron_right) : null,
                onTap: canManageInstitution
                    ? () => _showWorkingHoursDialog(
                          context,
                          ref,
                          institution.workStartHour,
                          institution.workEndHour,
                        )
                    : null,
              ),
              // Код приглашения виден владельцу и администратору
              if (hasFullAccess)
                ListTile(
                  leading: const Icon(Icons.share),
                  title: Text(context.l10n.inviteMembers),
                  subtitle: Text('${context.l10n.inviteCode}: ${institution.inviteCode}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: context.l10n.copy,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: institution.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.inviteCodeCopied),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: context.l10n.generateNewCode,
                        onPressed: controllerState.isLoading
                            ? null
                            : () => _regenerateInviteCode(context, ref),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              _SectionHeader(title: context.l10n.general.toUpperCase()),
              // Кабинеты — только если есть право manageRooms
              if (hasFullAccess || (permissions?.manageRooms ?? false))
                ListTile(
                  leading: const Icon(Icons.door_front_door),
                  title: Text(context.l10n.rooms),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/institutions/$institutionId/rooms');
                  },
                ),
              // Статистика — только если есть право viewStatistics
              if (hasFullAccess || (permissions?.viewStatistics ?? false))
                ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: Text(context.l10n.statistics),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/institutions/$institutionId/statistics');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.people),
                title: Text(context.l10n.teamMembers),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/institutions/$institutionId/members');
                },
              ),
              // Предметы — только если есть право manageSubjects
              if (hasFullAccess || (permissions?.manageSubjects ?? false))
                ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(context.l10n.subjects),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/institutions/$institutionId/subjects');
                  },
                ),
              // Типы занятий — только если есть право manageLessonTypes
              if (hasFullAccess || (permissions?.manageLessonTypes ?? false))
                ListTile(
                  leading: const Icon(Icons.event_note),
                  title: Text(context.l10n.lessonTypes),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/institutions/$institutionId/lesson-types');
                  },
                ),
              // Тарифы оплаты — только если есть право managePaymentPlans
              if (hasFullAccess || (permissions?.managePaymentPlans ?? false))
                ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: Text(context.l10n.paymentPlans),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/institutions/$institutionId/payment-plans');
                  },
                ),
              const Divider(),
              _SectionHeader(title: context.l10n.account.toUpperCase()),
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(context.l10n.profile),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/institutions/$institutionId/profile');
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: Text(context.l10n.theme),
                subtitle: Text(getThemeModeLabel(ref.watch(themeModeProvider), context.l10n)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.l10n.language),
                subtitle: Text(ref.watch(localeProvider).label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageDialog(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(context.l10n.phoneCountry),
                subtitle: Text(ref.watch(phoneCountryCodeProvider).displayLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPhoneCountryCodeDialog(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  context.l10n.logout,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(context.l10n.logout),
                      content: Text(context.l10n.confirmLogout),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: Text(context.l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: Text(context.l10n.logout, style: const TextStyle(color: Colors.red)),
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
              _SectionHeader(title: context.l10n.dangerZone.toUpperCase()),
              ListTile(
                leading: Icon(
                  isOwner ? Icons.archive : Icons.exit_to_app,
                  color: Colors.orange,
                ),
                title: Text(
                  isOwner ? context.l10n.archiveInstitution : context.l10n.leaveInstitutionAction,
                  style: const TextStyle(color: Colors.orange),
                ),
                subtitle: Text(
                  isOwner
                      ? context.l10n.institutionCanBeRestored
                      : context.l10n.youWillNoLongerBeMember,
                ),
                enabled: !controllerState.isLoading,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(isOwner ? context.l10n.archiveInstitutionQuestion : context.l10n.leaveInstitutionQuestion),
                      content: Text(
                        isOwner
                            ? context.l10n.archiveInstitutionMessage(institution.name)
                            : context.l10n.leaveInstitutionMessage(institution.name),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: Text(context.l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: Text(
                            isOwner ? context.l10n.archive : context.l10n.leaveInstitution,
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
                                ? context.l10n.institutionArchived
                                : context.l10n.youLeftInstitution,
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

  Future<void> _regenerateInviteCode(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.generateNewCodeQuestion),
        content: Text(context.l10n.generateNewCodeMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.generate),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final controller = ref.read(institutionControllerProvider.notifier);
      final newCode = await controller.regenerateInviteCode(widget.institutionId);
      if (newCode != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.newCodeGenerated(newCode)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final nameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.institutionName),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: InputDecoration(labelText: context.l10n.institutionName),
            validator: (v) => v == null || v.isEmpty ? context.l10n.enterName : null,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final controller = ref.read(institutionControllerProvider.notifier);
                final success = await controller.update(
                  widget.institutionId,
                  nameController.text.trim(),
                );
                if (success && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.nameUpdated)),
                  );
                }
              }
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }

  void _showWorkingHoursDialog(
    BuildContext context,
    WidgetRef ref,
    int currentStartHour,
    int currentEndHour,
  ) {
    int startHour = currentStartHour;
    int endHour = currentEndHour;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(context.l10n.workingHours),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.workingHoursDescription,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.start, style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: startHour,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: List.generate(24, (i) => i)
                              .map((h) => DropdownMenuItem(
                                    value: h,
                                    child: Text('${h.toString().padLeft(2, '0')}:00'),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                startHour = v;
                                if (endHour <= startHour) {
                                  endHour = startHour + 1;
                                  if (endHour > 23) endHour = 23;
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.end, style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: endHour,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: List.generate(24 - startHour, (i) => startHour + i + 1)
                              .map((h) => DropdownMenuItem(
                                    value: h,
                                    child: Text('${h.toString().padLeft(2, '0')}:00'),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => endHour = v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final controller = ref.read(institutionControllerProvider.notifier);
                final success = await controller.updateWorkingHours(
                  widget.institutionId,
                  startHour,
                  endHour,
                );
                if (success && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.workingHoursUpdated)),
                  );
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  /// Диалог выбора темы оформления
  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(themeModeProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.theme),
        contentPadding: const EdgeInsets.only(top: 16),
        content: RadioGroup<ThemeMode>(
          groupValue: currentMode,
          onChanged: (mode) {
            ref.read(themeModeProvider.notifier).setThemeMode(mode!);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text(context.l10n.themeSystem),
                subtitle: Text(context.l10n.languageSystem),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: Text(context.l10n.themeDark),
                value: ThemeMode.dark,
              ),
              RadioListTile<ThemeMode>(
                title: Text(context.l10n.themeLight),
                value: ThemeMode.light,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
  }

  /// Диалог выбора языка приложения
  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.read(localeProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.language),
        contentPadding: const EdgeInsets.only(top: 16),
        content: RadioGroup<AppLocale>(
          groupValue: currentLocale,
          onChanged: (locale) {
            ref.read(localeProvider.notifier).setLocale(locale!);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLocale.values.map((locale) {
              return RadioListTile<AppLocale>(
                title: Text(locale.label),
                subtitle: locale == AppLocale.system
                    ? Text(context.l10n.languageSystem)
                    : null,
                value: locale,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
  }

  /// Диалог выбора кода страны для телефона
  void _showPhoneCountryCodeDialog(BuildContext context, WidgetRef ref) {
    final currentCode = ref.read(phoneCountryCodeProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.phoneCountry),
        contentPadding: const EdgeInsets.only(top: 16),
        content: SingleChildScrollView(
          child: RadioGroup<PhoneCountryCode>(
            groupValue: currentCode,
            onChanged: (code) {
              ref.read(phoneCountryCodeProvider.notifier).setCountryCode(code!);
              Navigator.pop(ctx);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: PhoneCountryCode.values.map((code) {
                return RadioListTile<PhoneCountryCode>(
                  title: Text(code.displayLabel),
                  subtitle: code == PhoneCountryCode.auto
                      ? Text(context.l10n.byLocale)
                      : null,
                  value: code,
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
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
