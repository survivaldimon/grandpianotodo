import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/utils/validators.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/core/widgets/error_view.dart';

/// Экран присоединения к заведению по коду
class JoinInstitutionScreen extends ConsumerStatefulWidget {
  final String? code;

  const JoinInstitutionScreen({super.key, this.code});

  @override
  ConsumerState<JoinInstitutionScreen> createState() =>
      _JoinInstitutionScreenState();
}

class _JoinInstitutionScreenState extends ConsumerState<JoinInstitutionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.code);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(institutionControllerProvider.notifier);
    final institution = await controller.joinByCode(_codeController.text.trim().toUpperCase());

    if (institution != null && mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.joinedInstitution(institution.name)),
          backgroundColor: Colors.green,
        ),
      );
      // Редирект на онбординг (выбор цвета и направлений)
      context.go('/institutions/${institution.id}/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(institutionControllerProvider);
    final isLoading = controllerState.isLoading;

    final l10n = AppLocalizations.of(context);

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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.joinInstitution),
      ),
      body: Padding(
        padding: AppSizes.paddingAllL,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.inviteCodeDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: l10n.inviteCode,
                  hintText: l10n.inviteCodeHint,
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                validator: Validators.required(l10n),
                enabled: !isLoading,
                onFieldSubmitted: (_) => _join(),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: isLoading ? null : _join,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.joinInstitution),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
