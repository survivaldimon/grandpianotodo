import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/color_picker_field.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/features/institution/providers/teacher_subjects_provider.dart';
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/shared/models/subject.dart'; // Subject, TeacherSubject

/// Экран онбординга для нового преподавателя
/// Показывается после присоединения к заведению по коду
class TeacherOnboardingScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const TeacherOnboardingScreen({
    super.key,
    required this.institutionId,
  });

  @override
  ConsumerState<TeacherOnboardingScreen> createState() => _TeacherOnboardingScreenState();
}

class _TeacherOnboardingScreenState extends ConsumerState<TeacherOnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Шаг 1: Цвет
  String? _selectedColor;
  String? _initialColor; // Цвет который был при входе
  bool _colorInitialized = false;

  // Шаг 2: Направления (предметы)
  final Set<String> _selectedSubjectIds = {};
  final Set<String> _existingSubjectIds = {}; // Направления которые уже есть
  bool _subjectsInitialized = false;

  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipPage() {
    if (_currentPage == 0) {
      // Пропустить выбор цвета
      _nextPage();
    } else {
      // Пропустить выбор направлений — завершить
      _finish();
    }
  }

  Future<void> _saveColorAndNext() async {
    final membership = ref.read(myMembershipProvider(widget.institutionId)).valueOrNull;

    // Сохраняем цвет только если он выбран и отличается от начального
    if (_selectedColor != null && _selectedColor != _initialColor && membership != null) {
      setState(() => _isSaving = true);

      final controller = ref.read(memberControllerProvider.notifier);
      await controller.updateColor(membership.id, widget.institutionId, _selectedColor);
      // Обновляем начальный цвет чтобы _finish() не сохранял повторно
      _initialColor = _selectedColor;

      setState(() => _isSaving = false);
    }
    _nextPage();
  }

  Future<void> _finish() async {
    final membership = ref.read(myMembershipProvider(widget.institutionId)).valueOrNull;

    if (membership == null) {
      if (mounted) context.go('/institutions/${widget.institutionId}/dashboard');
      return;
    }

    setState(() => _isSaving = true);

    // Сохраняем цвет если выбран и отличается от начального
    if (_selectedColor != null && _selectedColor != _initialColor) {
      final controller = ref.read(memberControllerProvider.notifier);
      await controller.updateColor(membership.id, widget.institutionId, _selectedColor);
    }

    // Сохраняем только НОВЫЕ направления (которых ещё не было)
    final newSubjectIds = _selectedSubjectIds.difference(_existingSubjectIds);
    if (newSubjectIds.isNotEmpty) {
      final teacherSubjectsController = ref.read(teacherSubjectsControllerProvider.notifier);
      for (final subjectId in newSubjectIds) {
        await teacherSubjectsController.addSubject(
          userId: membership.userId,
          subjectId: subjectId,
          institutionId: widget.institutionId,
        );
      }
    }

    // Инвалидируем провайдеры чтобы баннер сразу пропал
    ref.invalidate(myMembershipProvider(widget.institutionId));
    ref.invalidate(teacherSubjectsProvider(
      TeacherSubjectsParams(userId: membership.userId, institutionId: widget.institutionId),
    ));

    setState(() => _isSaving = false);

    if (mounted) {
      context.go('/institutions/${widget.institutionId}/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectsAsync = ref.watch(subjectsListProvider(widget.institutionId));
    final membershipAsync = ref.watch(myMembershipProvider(widget.institutionId));
    final membership = membershipAsync.valueOrNull;

    // Инициализируем цвет когда membership загружен (один раз)
    if (membership != null && !_colorInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_colorInitialized && mounted) {
          setState(() {
            if (membership.color != null && membership.color!.isNotEmpty) {
              _initialColor = membership.color;
              _selectedColor = membership.color;
            }
            _colorInitialized = true;
          });
        }
      });
    }

    // Инициализируем направления когда они загружены (один раз)
    if (membership != null && !_subjectsInitialized) {
      final teacherSubjectsAsync = ref.watch(teacherSubjectsProvider(
        TeacherSubjectsParams(userId: membership.userId, institutionId: widget.institutionId),
      ));
      final teacherSubjects = teacherSubjectsAsync.valueOrNull;
      if (teacherSubjects != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_subjectsInitialized && mounted) {
            setState(() {
              for (final ts in teacherSubjects) {
                _existingSubjectIds.add(ts.subjectId);
                _selectedSubjectIds.add(ts.subjectId);
              }
              _subjectsInitialized = true;
            });
          }
        });
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  _buildDot(0),
                  const SizedBox(width: 8),
                  _buildDot(1),
                  const Spacer(),
                  TextButton(
                    onPressed: _isSaving ? null : _skipPage,
                    child: Text(
                      'Пропустить',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  // Page 1: Выбор цвета
                  _buildColorPage(theme),

                  // Page 2: Выбор направлений
                  _buildSubjectsPage(theme, subjectsAsync),
                ],
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (_currentPage == 0) {
                            _saveColorAndNext();
                          } else {
                            _finish();
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == 0 ? 'Далее' : 'Готово',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Icon(_currentPage == 0 ? Icons.arrow_forward : Icons.check),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildColorPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.palette,
            size: 80,
            color: _selectedColor != null
                ? hexToColor(_selectedColor!)
                : AppColors.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Добро пожаловать!',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Выберите цвет для отображения\nваших занятий в расписании',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ColorPickerField(
            selectedColor: _selectedColor,
            onColorChanged: (color) {
              setState(() => _selectedColor = color);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsPage(ThemeData theme, AsyncValue<List<Subject>> subjectsAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(
            Icons.school,
            size: 80,
            color: AppColors.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Ваши направления',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Выберите предметы, которые вы ведёте',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          subjectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Ошибка загрузки: $e'),
            data: (subjects) {
              if (subjects.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'В заведении пока нет предметов',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Владелец может добавить их в настройках',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: subjects.map((subject) {
                  final isSelected = _selectedSubjectIds.contains(subject.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedSubjectIds.remove(subject.id);
                            } else {
                              _selectedSubjectIds.add(subject.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: AppColors.primary, width: 2)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: subject.color != null
                                      ? hexToColor(subject.color!).withValues(alpha: 0.2)
                                      : theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.music_note,
                                  color: subject.color != null
                                      ? hexToColor(subject.color!)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  subject.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedSubjectIds.add(subject.id);
                                    } else {
                                      _selectedSubjectIds.remove(subject.id);
                                    }
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          if (_selectedSubjectIds.isNotEmpty)
            Text(
              'Выбрано: ${_selectedSubjectIds.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
