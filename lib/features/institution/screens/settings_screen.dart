import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/theme/theme_provider.dart';
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
            content: Text(ErrorView.getUserFriendlyMessage(next.error!)),
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
          final isAdmin = ref.watch(isAdminProvider(institutionId));
          // Админ имеет все права владельца, кроме удаления заведения
          final hasFullAccess = isOwner || isAdmin;
          // Проверяем права на управление заведением
          final permissions = ref.watch(myPermissionsProvider(institutionId));
          final canManageInstitution = hasFullAccess || (permissions?.manageInstitution ?? false);

          return ListView(
            children: [
              const _SectionHeader(title: 'ЗАВЕДЕНИЕ'),
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Название'),
                subtitle: Text(institution.name),
                trailing: canManageInstitution ? const Icon(Icons.chevron_right) : null,
                onTap: canManageInstitution
                    ? () => _showEditNameDialog(context, ref, institution.name)
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Рабочее время'),
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
                  title: const Text('Пригласить участника'),
                  subtitle: Text('Код: ${institution.inviteCode}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'Скопировать код',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: institution.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Код скопирован в буфер обмена'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Сгенерировать новый код',
                        onPressed: controllerState.isLoading
                            ? null
                            : () => _regenerateInviteCode(context, ref),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              const _SectionHeader(title: 'УПРАВЛЕНИЕ'),
              // Кабинеты — только если есть право manageRooms
              if (hasFullAccess || (permissions?.manageRooms ?? false))
                ListTile(
                  leading: const Icon(Icons.door_front_door),
                  title: const Text(AppStrings.rooms),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/institutions/$institutionId/rooms');
                  },
                ),
              // Статистика — только если есть право viewStatistics
              if (hasFullAccess || (permissions?.viewStatistics ?? false))
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
              // Предметы — только если есть право manageSubjects
              if (hasFullAccess || (permissions?.manageSubjects ?? false))
                ListTile(
                  leading: const Icon(Icons.music_note),
                  title: const Text(AppStrings.subjects),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/institutions/$institutionId/subjects');
                  },
                ),
              // Типы занятий — только если есть право manageLessonTypes
              if (hasFullAccess || (permissions?.manageLessonTypes ?? false))
                ListTile(
                  leading: const Icon(Icons.event_note),
                  title: const Text(AppStrings.lessonTypes),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/institutions/$institutionId/lesson-types');
                  },
                ),
              // Тарифы оплаты — только если есть право managePaymentPlans
              if (hasFullAccess || (permissions?.managePaymentPlans ?? false))
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
                  context.push('/institutions/$institutionId/profile');
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Тема оформления'),
                subtitle: Text(getThemeModeLabel(ref.watch(themeModeProvider))),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Код страны для телефона'),
                subtitle: Text(ref.watch(phoneCountryCodeProvider).displayLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPhoneCountryCodeDialog(context, ref),
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

  Future<void> _regenerateInviteCode(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сгенерировать новый код?'),
        content: const Text(
          'Старый код перестанет работать. Все, кто ещё не присоединился по старому коду, не смогут это сделать.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сгенерировать'),
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
            content: Text('Новый код: $newCode'),
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
                  widget.institutionId,
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Рабочее время'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Это время будет отображаться в сетке расписания',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Начало', style: TextStyle(fontWeight: FontWeight.w500)),
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
                        const Text('Конец', style: TextStyle(fontWeight: FontWeight.w500)),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                final controller = ref.read(institutionControllerProvider.notifier);
                final success = await controller.updateWorkingHours(
                  widget.institutionId,
                  startHour,
                  endHour,
                );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Рабочее время обновлено')),
                  );
                }
              },
              child: const Text('Сохранить'),
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
        title: const Text('Тема оформления'),
        contentPadding: const EdgeInsets.only(top: 16),
        content: RadioGroup<ThemeMode>(
          groupValue: currentMode,
          onChanged: (mode) {
            ref.read(themeModeProvider.notifier).setThemeMode(mode!);
            Navigator.pop(ctx);
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text('Как в системе'),
                subtitle: Text('Автоматически'),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Тёмная'),
                value: ThemeMode.dark,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Светлая'),
                value: ThemeMode.light,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
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
        title: const Text('Код страны'),
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
                      ? const Text('По локали устройства')
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
            child: const Text('Отмена'),
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
