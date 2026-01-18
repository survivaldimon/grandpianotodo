import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/features/profile/providers/profile_provider.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Экран профиля пользователя
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(currentProfileProvider);
    final controllerState = ref.watch(profileControllerProvider);

    ref.listen(profileControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorView.getLocalizedErrorMessage(next.error!, l10n)),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
      ),
      body: Builder(
        builder: (context) {
          final profile = profileAsync.valueOrNull;

          // Loading только при первой загрузке
          if (profile == null) {
            return const LoadingIndicator();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    profile.fullName.isNotEmpty
                        ? profile.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Name
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(l10n.name),
                  subtitle: Text(profile.fullName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showEditNameDialog(context, ref, profile.fullName, l10n),
                ),
              ),

              // Email
              Card(
                child: ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(profile.email),
                  trailing: const Icon(Icons.lock, size: 16, color: Colors.grey),
                ),
              ),

              // Registration date
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(l10n.registrationDate),
                  subtitle: Text(
                    DateFormat('dd MMMM yyyy', Localizations.localeOf(context).languageCode).format(profile.createdAt),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Loading indicator
              if (controllerState.isLoading)
                const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName, AppLocalizations l10n) {
    final nameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editName),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: l10n.personName,
              hintText: l10n.personNameHint,
            ),
            textCapitalization: TextCapitalization.words,
            validator: (v) => v == null || v.trim().isEmpty ? l10n.enterPersonName : null,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final controller = ref.read(profileControllerProvider.notifier);
                final success = await controller.updateName(nameController.text.trim());
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ref.invalidate(currentProfileProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.personNameUpdated),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
