import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/utils/validators.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';

/// Экран создания нового заведения
class CreateInstitutionScreen extends ConsumerStatefulWidget {
  const CreateInstitutionScreen({super.key});

  @override
  ConsumerState<CreateInstitutionScreen> createState() =>
      _CreateInstitutionScreenState();
}

class _CreateInstitutionScreenState
    extends ConsumerState<CreateInstitutionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(institutionControllerProvider.notifier);
    final institution = await controller.create(_nameController.text.trim());

    if (institution != null && mounted) {
      context.go('/institutions/${institution.id}/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(institutionControllerProvider);
    final isLoading = controllerState.isLoading;

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
        title: const Text(AppStrings.createInstitution),
      ),
      body: Padding(
        padding: AppSizes.paddingAllL,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: AppStrings.institutionName,
                  hintText: 'Например: Музыкальная школа №1',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                textInputAction: TextInputAction.done,
                validator: Validators.required,
                enabled: !isLoading,
                onFieldSubmitted: (_) => _create(),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: isLoading ? null : _create,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(AppStrings.create),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
