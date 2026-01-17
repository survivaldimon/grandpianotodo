import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/features/payments/providers/payment_provider.dart';
import 'package:kabinet/features/payment_plans/providers/payment_plan_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/features/subscriptions/providers/subscription_provider.dart';
import 'package:kabinet/shared/models/institution_member.dart';
import 'package:kabinet/shared/models/payment.dart';
import 'package:kabinet/shared/models/payment_plan.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subject.dart';
import 'package:collection/collection.dart';

/// Провайдер связей ученик-предмет для заведения
final _studentSubjectBindingsProvider =
    FutureProvider.family<Map<String, Set<String>>, String>((ref, institutionId) async {
  final client = SupabaseConfig.client;
  final data = await client
      .from('student_subjects')
      .select('student_id, subject_id')
      .eq('institution_id', institutionId);

  // Map: subjectId -> Set<studentId>
  final result = <String, Set<String>>{};
  for (final item in data as List) {
    final subjectId = item['subject_id'] as String;
    final studentId = item['student_id'] as String;
    result.putIfAbsent(subjectId, () => {}).add(studentId);
  }
  return result;
});

/// Провайдер связей ученик-преподаватель для заведения
final _studentTeacherBindingsProvider =
    FutureProvider.family<Map<String, Set<String>>, String>((ref, institutionId) async {
  final client = SupabaseConfig.client;
  final data = await client
      .from('student_teachers')
      .select('student_id, user_id')
      .eq('institution_id', institutionId);

  // Map: userId (teacher) -> Set<studentId>
  final result = <String, Set<String>>{};
  for (final item in data as List) {
    final userId = item['user_id'] as String;
    final studentId = item['student_id'] as String;
    result.putIfAbsent(userId, () => {}).add(studentId);
  }
  return result;
});

/// Экран списка оплат
class PaymentsScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const PaymentsScreen({super.key, required this.institutionId});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy', 'ru');

  // Фильтры
  Set<String> _selectedStudentIds = {};
  Set<String> _selectedSubjectIds = {};
  Set<String> _selectedTeacherIds = {};
  Set<String> _selectedPlanIds = {};
  Set<String> _selectedPaymentMethods = {}; // 'cash', 'card'

  /// Проверяет, есть ли активные фильтры
  bool get _hasActiveFilters =>
      _selectedStudentIds.isNotEmpty ||
      _selectedSubjectIds.isNotEmpty ||
      _selectedTeacherIds.isNotEmpty ||
      _selectedPlanIds.isNotEmpty ||
      _selectedPaymentMethods.isNotEmpty;

  /// Применяет фильтры к списку оплат
  List<Payment> _applyFilters(
    List<Payment> payments, {
    required Map<String, Set<String>> subjectBindings,
    required Map<String, Set<String>> teacherBindings,
  }) {
    return payments.where((p) {
      // Исключаем записи переноса баланса (остаток занятий)
      if (p.isBalanceTransfer) return false;

      // Фильтр по ученикам
      if (_selectedStudentIds.isNotEmpty && !_selectedStudentIds.contains(p.studentId)) {
        return false;
      }

      // Фильтр по предметам
      if (_selectedSubjectIds.isNotEmpty) {
        // Собираем студентов, связанных с выбранными предметами
        final studentsWithSubjects = <String>{};
        for (final subjectId in _selectedSubjectIds) {
          studentsWithSubjects.addAll(subjectBindings[subjectId] ?? {});
        }
        if (!studentsWithSubjects.contains(p.studentId)) {
          return false;
        }
      }

      // Фильтр по преподавателям
      if (_selectedTeacherIds.isNotEmpty) {
        // Собираем студентов, связанных с выбранными преподавателями
        final studentsWithTeachers = <String>{};
        for (final teacherId in _selectedTeacherIds) {
          studentsWithTeachers.addAll(teacherBindings[teacherId] ?? {});
        }
        if (!studentsWithTeachers.contains(p.studentId)) {
          return false;
        }
      }

      // Фильтр по тарифу
      if (_selectedPlanIds.isNotEmpty &&
          (p.paymentPlanId == null || !_selectedPlanIds.contains(p.paymentPlanId))) {
        return false;
      }

      // Фильтр по способу оплаты
      if (_selectedPaymentMethods.isNotEmpty &&
          !_selectedPaymentMethods.contains(p.paymentMethod)) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Сбрасывает все фильтры
  void _resetFilters() {
    setState(() {
      _selectedStudentIds = {};
      _selectedSubjectIds = {};
      _selectedTeacherIds = {};
      _selectedPlanIds = {};
      _selectedPaymentMethods = {};
    });
  }

  /// Строит горизонтальную панель фильтров (кнопки)
  Widget _buildFiltersRow({
    required List<Student> students,
    required List<Subject> subjects,
    required List<InstitutionMember> members,
    required List<PaymentPlan> plans,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Кнопка "Ученики"
          _FilterButton(
            label: 'Ученики',
            isActive: _selectedStudentIds.isNotEmpty,
            onTap: () => _showStudentsSheet(students),
          ),
          const SizedBox(width: 8),
          // Кнопка "Предметы"
          _FilterButton(
            label: 'Предметы',
            isActive: _selectedSubjectIds.isNotEmpty,
            onTap: () => _showSubjectsSheet(subjects),
          ),
          const SizedBox(width: 8),
          // Кнопка "Преподаватели"
          _FilterButton(
            label: 'Преподаватели',
            isActive: _selectedTeacherIds.isNotEmpty,
            onTap: () => _showTeachersSheet(members),
          ),
          const SizedBox(width: 8),
          // Кнопка "Тарифы"
          _FilterButton(
            label: 'Тарифы',
            isActive: _selectedPlanIds.isNotEmpty,
            onTap: () => _showPlansSheet(plans),
          ),
          const SizedBox(width: 8),
          // Кнопка "Способ оплаты"
          _FilterButton(
            label: 'Способ',
            isActive: _selectedPaymentMethods.isNotEmpty,
            onTap: () => _showPaymentMethodsSheet(),
          ),
          // Кнопка сброса
          if (_hasActiveFilters) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: _resetFilters,
              tooltip: 'Сбросить фильтры',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(36, 36),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Показывает BottomSheet с выбором учеников
  void _showStudentsSheet(List<Student> students) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ученики', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedStudentIds = {});
                        setSheetState(() {});
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      value: _selectedStudentIds.isEmpty,
                      onChanged: (_) {
                        setState(() => _selectedStudentIds = {});
                        setSheetState(() {});
                      },
                      title: const Text('Все'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    ...students.map((student) {
                      final isSelected = _selectedStudentIds.contains(student.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedStudentIds.add(student.id);
                            } else {
                              _selectedStudentIds.remove(student.id);
                            }
                          });
                          setSheetState(() {});
                        },
                        title: Text(student.name),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Показывает BottomSheet с выбором предметов
  void _showSubjectsSheet(List<Subject> subjects) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Предметы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedSubjectIds = {});
                        setSheetState(() {});
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      value: _selectedSubjectIds.isEmpty,
                      onChanged: (_) {
                        setState(() => _selectedSubjectIds = {});
                        setSheetState(() {});
                      },
                      title: const Text('Все'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    ...subjects.map((subject) {
                      final isSelected = _selectedSubjectIds.contains(subject.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedSubjectIds.add(subject.id);
                            } else {
                              _selectedSubjectIds.remove(subject.id);
                            }
                          });
                          setSheetState(() {});
                        },
                        title: Text(subject.name),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Показывает BottomSheet с выбором преподавателей
  void _showTeachersSheet(List<InstitutionMember> members) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Преподаватели', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedTeacherIds = {});
                        setSheetState(() {});
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      value: _selectedTeacherIds.isEmpty,
                      onChanged: (_) {
                        setState(() => _selectedTeacherIds = {});
                        setSheetState(() {});
                      },
                      title: const Text('Все'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    ...members.map((member) {
                      final isSelected = _selectedTeacherIds.contains(member.userId);
                      final name = member.profile?.fullName ?? member.roleName;
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedTeacherIds.add(member.userId);
                            } else {
                              _selectedTeacherIds.remove(member.userId);
                            }
                          });
                          setSheetState(() {});
                        },
                        title: Text(name),
                        subtitle: member.profile?.email != null
                            ? Text(member.profile!.email, style: TextStyle(fontSize: 12, color: Colors.grey[600]))
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Показывает BottomSheet с выбором тарифов
  void _showPlansSheet(List<PaymentPlan> plans) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Тарифы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedPlanIds = {});
                        setSheetState(() {});
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      value: _selectedPlanIds.isEmpty,
                      onChanged: (_) {
                        setState(() => _selectedPlanIds = {});
                        setSheetState(() {});
                      },
                      title: const Text('Все'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    ...plans.map((plan) {
                      final isSelected = _selectedPlanIds.contains(plan.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedPlanIds.add(plan.id);
                            } else {
                              _selectedPlanIds.remove(plan.id);
                            }
                          });
                          setSheetState(() {});
                        },
                        title: Text(plan.name),
                        subtitle: Text('${plan.lessonsCount} занятий'),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Показывает BottomSheet с выбором способа оплаты
  void _showPaymentMethodsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Способ оплаты', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedPaymentMethods = {});
                        setSheetState(() {});
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Без ListView — всего 3 элемента, скролл не нужен
              CheckboxListTile(
                value: _selectedPaymentMethods.isEmpty,
                onChanged: (_) {
                  setState(() => _selectedPaymentMethods = {});
                  setSheetState(() {});
                },
                title: const Text('Все'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _selectedPaymentMethods.contains('card'),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedPaymentMethods.add('card');
                    } else {
                      _selectedPaymentMethods.remove('card');
                    }
                  });
                  setSheetState(() {});
                },
                title: const Text('Карта'),
                secondary: const Icon(Icons.credit_card, color: AppColors.primary),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _selectedPaymentMethods.contains('cash'),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedPaymentMethods.add('cash');
                    } else {
                      _selectedPaymentMethods.remove('cash');
                    }
                  });
                  setSheetState(() {});
                },
                title: const Text('Наличные'),
                secondary: const Icon(Icons.payments_outlined, color: AppColors.success),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Получить даты для отображения в зависимости от выбранного периода
  (DateTime, DateTime) _getDisplayDates(StatsPeriod period, CustomDateRange? customRange) {
    if (period == StatsPeriod.custom && customRange != null) {
      return (customRange.start, customRange.end);
    }
    return getPeriodDates(period, customRange: customRange);
  }

  String _periodLabel(StatsPeriod period) {
    switch (period) {
      case StatsPeriod.week:
        return 'Неделя';
      case StatsPeriod.month:
        return 'Месяц';
      case StatsPeriod.quarter:
        return 'Квартал';
      case StatsPeriod.year:
        return 'Год';
      case StatsPeriod.custom:
        return 'Свой';
    }
  }

  /// Выбрать предустановленный период и обновить даты
  void _selectPresetPeriod(StatsPeriod period) {
    ref.read(paymentsPeriodProvider.notifier).state = period;
    final (start, end) = getPeriodDates(period);
    ref.read(paymentsDateRangeProvider.notifier).state = CustomDateRange(start, end);
  }

  /// Можно ли перейти вперёд (не дальше сегодня)
  bool _canNavigateForward(DateTime currentEnd) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return currentEnd.isBefore(today);
  }

  /// Навигация по периодам
  void _navigatePeriod(StatsPeriod period, DateTime currentStart, DateTime currentEnd, {required bool forward}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    DateTime newStart;
    DateTime newEnd;

    final duration = currentEnd.difference(currentStart);

    switch (period) {
      case StatsPeriod.week:
        if (forward) {
          newStart = currentStart.add(const Duration(days: 7));
        } else {
          newStart = currentStart.subtract(const Duration(days: 7));
        }
        newStart = newStart.subtract(Duration(days: newStart.weekday - 1));
        newEnd = DateTime(newStart.year, newStart.month, newStart.day + 6, 23, 59, 59);
        break;
      case StatsPeriod.month:
        if (forward) {
          newStart = DateTime(currentStart.year, currentStart.month + 1, 1);
        } else {
          newStart = DateTime(currentStart.year, currentStart.month - 1, 1);
        }
        newEnd = DateTime(newStart.year, newStart.month + 1, 0, 23, 59, 59);
        break;
      case StatsPeriod.quarter:
        final currentQuarterStart = ((currentStart.month - 1) ~/ 3) * 3 + 1;
        if (forward) {
          newStart = DateTime(currentStart.year, currentQuarterStart + 3, 1);
        } else {
          newStart = DateTime(currentStart.year, currentQuarterStart - 3, 1);
        }
        if (newStart.month < 1) {
          newStart = DateTime(newStart.year - 1, 12 + newStart.month, 1);
        } else if (newStart.month > 12) {
          newStart = DateTime(newStart.year + 1, newStart.month - 12, 1);
        }
        newEnd = DateTime(newStart.year, newStart.month + 3, 0, 23, 59, 59);
        break;
      case StatsPeriod.year:
        if (forward) {
          newStart = DateTime(currentStart.year + 1, 1, 1);
        } else {
          newStart = DateTime(currentStart.year - 1, 1, 1);
        }
        newEnd = DateTime(newStart.year, 12, 31, 23, 59, 59);
        break;
      case StatsPeriod.custom:
        if (forward) {
          newStart = currentEnd.add(const Duration(days: 1));
          newEnd = newStart.add(duration);
        } else {
          newEnd = currentStart.subtract(const Duration(days: 1));
          newStart = newEnd.subtract(duration);
        }
        break;
    }

    if (newEnd.isAfter(today)) {
      newEnd = today;
    }

    ref.read(paymentsDateRangeProvider.notifier).state = CustomDateRange(newStart, newEnd);
  }

  /// Выбор диапазона дат
  Future<void> _selectDateRange(DateTime currentStart, DateTime currentEnd) async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(start: currentStart, end: currentEnd),
      locale: const Locale('ru'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(paymentsPeriodProvider.notifier).state = StatsPeriod.custom;
      ref.read(paymentsDateRangeProvider.notifier).state = CustomDateRange(
        picked.start,
        picked.end,
      );
    }
  }

  PeriodParams _getPeriodParams(StatsPeriod period, CustomDateRange? customRange) {
    final (start, end) = _getDisplayDates(period, customRange);
    return PeriodParams(widget.institutionId, start, end);
  }

  @override
  Widget build(BuildContext context) {
    // Получаем период из провайдеров
    final period = ref.watch(paymentsPeriodProvider);
    final customRange = ref.watch(paymentsDateRangeProvider);
    final periodParams = _getPeriodParams(period, customRange);
    final (displayStart, displayEnd) = _getDisplayDates(period, customRange);

    // Используем StreamProvider для realtime обновлений
    final paymentsAsync = ref.watch(paymentsStreamByPeriodProvider(periodParams));

    // Получаем права текущего пользователя
    final permissions = ref.watch(myPermissionsProvider(widget.institutionId));
    final institutionAsync = ref.watch(currentInstitutionProvider(widget.institutionId));
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

    // Проверяем, является ли пользователь владельцем или админом
    final isOwner = institutionAsync.maybeWhen(
      data: (inst) => inst.ownerId == currentUserId,
      orElse: () => false,
    );
    final isAdmin = ref.watch(isAdminProvider(widget.institutionId));
    final hasFullAccess = isOwner || isAdmin;

    // Право на добавление оплат (для своих или для всех)
    final canAddPayments = hasFullAccess ||
        (permissions?.addPaymentsForOwnStudents ?? false) ||
        (permissions?.addPaymentsForAllStudents ?? false);

    // Право на добавление оплат для всех учеников
    final canAddForAllStudents = hasFullAccess ||
        (permissions?.addPaymentsForAllStudents ?? false);

    // Права на просмотр оплат
    final canViewAllPayments = hasFullAccess ||
        (permissions?.viewAllPayments ?? false);
    final canViewOwnStudentsPayments = permissions?.viewOwnStudentsPayments ?? true;
    final canViewAnyPayments = canViewAllPayments || canViewOwnStudentsPayments;

    // ID своих учеников для фильтрации
    final myStudentIdsAsync = ref.watch(myStudentIdsProvider(widget.institutionId));

    // Получаем данные для фильтров
    final studentsAsync = ref.watch(studentsProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsListProvider(widget.institutionId));
    final membersAsync = ref.watch(membersStreamProvider(widget.institutionId));
    final plansAsync = ref.watch(paymentPlansProvider(widget.institutionId));

    // Загружаем связи для фильтрации
    final subjectBindingsAsync = ref.watch(_studentSubjectBindingsProvider(widget.institutionId));
    final teacherBindingsAsync = ref.watch(_studentTeacherBindingsProvider(widget.institutionId));

    // Вычисляем итого из видимых оплат
    final myStudentIds = myStudentIdsAsync.valueOrNull ?? {};
    double? visibleTotal;
    if (paymentsAsync.hasValue) {
      final allPayments = paymentsAsync.value!;
      // Исключаем записи переноса баланса (остаток занятий)
      final paymentsWithoutTransfers = allPayments.where((p) => !p.isBalanceTransfer).toList();
      List<Payment> accessFiltered = paymentsWithoutTransfers;
      if (!canViewAllPayments) {
        accessFiltered = paymentsWithoutTransfers.where((p) {
          if (myStudentIds.contains(p.studentId)) return true;
          if (p.subscription?.members != null) {
            return p.subscription!.members!.any(
              (m) => myStudentIds.contains(m.studentId),
            );
          }
          return false;
        }).toList();
      }
      visibleTotal = accessFiltered.fold<double>(0.0, (sum, p) => sum + p.amount);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.payments),
      ),
      floatingActionButton: canAddPayments
          ? FloatingActionButton(
              onPressed: () => _showAddPaymentDialog(context, canAddForAllStudents),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          // Быстрый выбор периода (кнопки)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in [StatsPeriod.week, StatsPeriod.month, StatsPeriod.quarter, StatsPeriod.year])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_periodLabel(p)),
                        selected: p == period,
                        onSelected: (_) => _selectPresetPeriod(p),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Выбор своего периода с навигацией
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Стрелка назад
                IconButton(
                  onPressed: () => _navigatePeriod(period, displayStart, displayEnd, forward: false),
                  icon: const Icon(Icons.chevron_left),
                  color: AppColors.primary,
                ),
                // Даты
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDateRange(displayStart, displayEnd),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: period == StatsPeriod.custom
                              ? AppColors.primary
                              : AppColors.border,
                          width: period == StatsPeriod.custom ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            _dateFormat.format(displayStart),
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            _dateFormat.format(displayEnd),
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Стрелка вперёд
                IconButton(
                  onPressed: _canNavigateForward(displayEnd)
                      ? () => _navigatePeriod(period, displayStart, displayEnd, forward: true)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Фильтры (горизонтальные кнопки)
          if (canViewAnyPayments)
            studentsAsync.maybeWhen(
              data: (students) => subjectsAsync.maybeWhen(
                data: (subjects) => membersAsync.maybeWhen(
                  data: (members) => plansAsync.maybeWhen(
                    data: (plans) => _buildFiltersRow(
                      students: students,
                      subjects: subjects,
                      members: members,
                      plans: plans,
                    ),
                    orElse: () => _buildFiltersRow(
                      students: students,
                      subjects: subjects,
                      members: members,
                      plans: [],
                    ),
                  ),
                  orElse: () => _buildFiltersRow(
                    students: students,
                    subjects: subjects,
                    members: [],
                    plans: [],
                  ),
                ),
                orElse: () => _buildFiltersRow(
                  students: students,
                  subjects: [],
                  members: [],
                  plans: [],
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          if (canViewAnyPayments) const SizedBox(height: 12),

          // Total (рассчитывается из видимых оплат)
          if (canViewAnyPayments)
            Container(
              margin: AppSizes.paddingHorizontalM,
              padding: AppSizes.paddingAllM,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(canViewAllPayments ? 'Итого:' : 'Итого (ваши ученики):'),
                  visibleTotal != null
                      ? Text(
                          _formatCurrency(visibleTotal),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                        )
                      : paymentsAsync.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('—'),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Payments list (НИКОГДА не показываем ошибку - используем valueOrNull)
          Expanded(
            child: !canViewAnyPayments
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
                        SizedBox(height: 16),
                        Text(
                          'Нет доступа к просмотру оплат',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final payments = paymentsAsync.valueOrNull;

                      // Показываем loading только при первой загрузке (нет данных)
                      if (payments == null) {
                        return const LoadingIndicator();
                      }

                      // Всегда показываем данные (даже если фоном идёт обновление или ошибка)
                      return _buildPaymentsContent(
                        payments: payments,
                        canViewAllPayments: canViewAllPayments,
                        myStudentIdsAsync: myStudentIdsAsync,
                        subjectBindingsAsync: subjectBindingsAsync,
                        teacherBindingsAsync: teacherBindingsAsync,
                        periodParams: periodParams,
                        institutionId: widget.institutionId,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsContent({
    required List<Payment> payments,
    required bool canViewAllPayments,
    required AsyncValue<Set<String>> myStudentIdsAsync,
    required AsyncValue<Map<String, Set<String>>> subjectBindingsAsync,
    required AsyncValue<Map<String, Set<String>>> teacherBindingsAsync,
    required PeriodParams periodParams,
    required String institutionId,
  }) {
    // Если нужна фильтрация по своим ученикам, ждём загрузки myStudentIds
    if (!canViewAllPayments && myStudentIdsAsync.isLoading) {
      return const LoadingIndicator();
    }

    // Получаем связи для фильтрации
    final subjectBindings = subjectBindingsAsync.valueOrNull ?? {};
    final teacherBindings = teacherBindingsAsync.valueOrNull ?? {};
    final myStudentIds = myStudentIdsAsync.valueOrNull ?? {};

    // Сначала фильтруем по правам доступа
    List<Payment> accessFilteredPayments = payments;
    if (!canViewAllPayments) {
      accessFilteredPayments = payments.where((p) {
        if (myStudentIds.contains(p.studentId)) return true;
        if (p.subscription?.members != null) {
          return p.subscription!.members!.any(
            (m) => myStudentIds.contains(m.studentId),
          );
        }
        return false;
      }).toList();
    }

    // Затем применяем UI фильтры
    final filteredPayments = _applyFilters(
      accessFilteredPayments,
      subjectBindings: subjectBindings,
      teacherBindings: teacherBindings,
    );

    if (accessFilteredPayments.isEmpty) {
      return Center(
        child: Text(
          canViewAllPayments
              ? 'Нет оплат за этот период'
              : 'Нет оплат ваших учеников за этот период',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    if (filteredPayments.isEmpty && _hasActiveFilters) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Нет оплат по заданным фильтрам',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Сбросить фильтры'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(paymentsStreamByPeriodProvider(periodParams));
        ref.invalidate(myStudentIdsProvider(institutionId));
      },
      child: _buildPaymentsList(filteredPayments, myStudentIds, periodParams),
    );
  }

  Widget _buildPaymentsList(List<Payment> payments, Set<String> myStudentIds, PeriodParams periodParams) {
    // Group payments by date
    final groupedPayments = groupBy<Payment, String>(
      payments,
      (p) => DateFormat('yyyy-MM-dd').format(p.paidAt),
    );

    final sortedDates = groupedPayments.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      key: const PageStorageKey('payments_list'),
      padding: AppSizes.paddingHorizontalM,
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateStr = sortedDates[index];
        final date = DateTime.parse(dateStr);
        final dayPayments = groupedPayments[dateStr]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(date: DateFormat('d MMMM', 'ru').format(date)),
            ...dayPayments.map((p) => _PaymentCard(
              payment: p,
              institutionId: widget.institutionId,
              myStudentIds: myStudentIds,
              onChanged: () {
                // Stream провайдер обновляется автоматически через realtime
                ref.invalidate(paymentsStreamByPeriodProvider(periodParams));
              },
            )),
          ],
        );
      },
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'ru_RU');
    return '${formatter.format(amount.toInt())} ₸';
  }

  void _showAddPaymentDialog(BuildContext context, bool canAddForAllStudents) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _AddPaymentSheet(
        institutionId: widget.institutionId,
        canAddForAllStudents: canAddForAllStudents,
        onSuccess: () {
          // Stream провайдер обновляется автоматически через realtime
          final period = ref.read(paymentsPeriodProvider);
          final customRange = ref.read(paymentsDateRangeProvider);
          final params = _getPeriodParams(period, customRange);
          ref.invalidate(paymentsStreamByPeriodProvider(params));
        },
      ),
    );
  }

}

/// Показать форму добавления оплаты
/// Используйте эту функцию из любого экрана для унифицированного добавления оплат
void showAddPaymentSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String institutionId,
  required bool canAddForAllStudents,
  String? preselectedStudentId,
  VoidCallback? onSuccess,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (dialogContext) => _AddPaymentSheet(
      institutionId: institutionId,
      canAddForAllStudents: canAddForAllStudents,
      preselectedStudentId: preselectedStudentId,
      onSuccess: () {
        onSuccess?.call();
      },
    ),
  );
}

/// Форма добавления оплаты
class _AddPaymentSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final bool canAddForAllStudents;
  final String? preselectedStudentId;
  final VoidCallback onSuccess;

  const _AddPaymentSheet({
    required this.institutionId,
    required this.canAddForAllStudents,
    this.preselectedStudentId,
    required this.onSuccess,
  });

  @override
  ConsumerState<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends ConsumerState<_AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _lessonsController = TextEditingController();
  final _validityController = TextEditingController(text: '30');
  final _discountController = TextEditingController();
  final _commentController = TextEditingController();

  Student? _selectedStudent;
  List<Student> _selectedFamilyStudents = [];
  PaymentPlan? _selectedPlan;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _hasDiscount = false;
  double _originalPrice = 0;
  bool _isFamilyMode = false;
  String _paymentMethod = 'card'; // Способ оплаты: 'cash' или 'card'

  // Объединение учеников в групповую карточку
  bool _shouldMergeStudents = false;
  final _mergedNameController = TextEditingController();

  // Флаг для предвыбора ученика (один раз)
  bool _preselectionDone = false;

  // Для FAB прокрутки вниз
  bool _showScrollDownFab = true;
  ScrollController? _currentScrollController;

  void _handleScrollNotification(ScrollNotification notification, ScrollController controller) {
    // Сохраняем контроллер для использования в _scrollToBottom
    _currentScrollController = controller;

    if (notification is ScrollUpdateNotification) {
      final maxScroll = notification.metrics.maxScrollExtent;
      final currentScroll = notification.metrics.pixels;
      // Скрываем FAB только когда совсем внизу (осталось меньше 50 пикселей)
      final shouldShow = maxScroll > 50 && currentScroll < maxScroll - 50;
      if (shouldShow != _showScrollDownFab) {
        setState(() => _showScrollDownFab = shouldShow);
      }
    }
  }

  void _scrollToBottom() {
    if (_currentScrollController == null || !_currentScrollController!.hasClients) return;
    _currentScrollController!.animateTo(
      _currentScrollController!.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _lessonsController.dispose();
    _validityController.dispose();
    _discountController.dispose();
    _commentController.dispose();
    _mergedNameController.dispose();
    super.dispose();
  }

  void _onPlanSelected(PaymentPlan? plan) {
    setState(() {
      _selectedPlan = plan;
      if (plan != null) {
        _originalPrice = plan.price;
        _lessonsController.text = plan.lessonsCount.toString();
        _validityController.text = plan.validityDays.toString();
        _updateFinalAmount();
      } else {
        _originalPrice = 0;
        _hasDiscount = false;
        _discountController.clear();
        _amountController.clear();
        _lessonsController.clear();
      }
    });
  }

  void _updateFinalAmount() {
    if (_selectedPlan != null) {
      double finalAmount = _originalPrice;
      if (_hasDiscount && _discountController.text.isNotEmpty) {
        final discount = double.tryParse(_discountController.text) ?? 0;
        finalAmount = _originalPrice - discount;
        if (finalAmount < 0) finalAmount = 0;
      }
      _amountController.text = finalAmount.toStringAsFixed(0);
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submit() async {
    // Валидация
    if (!_formKey.currentState!.validate()) return;

    if (_isFamilyMode) {
      if (_selectedFamilyStudents.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Выберите минимум 2 ученика для семейного абонемента'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      if (_selectedStudent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Выберите ученика'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    // Формируем комментарий со скидкой
    String? comment = _commentController.text.trim();
    if (_hasDiscount && _discountController.text.isNotEmpty) {
      final discount = double.tryParse(_discountController.text) ?? 0;
      if (discount > 0) {
        final discountNote = 'Скидка: ${discount.toStringAsFixed(0)} ₸';
        comment = comment.isEmpty ? discountNote : '$discountNote\n$comment';
      }
    }

    final controller = ref.read(paymentControllerProvider.notifier);
    Payment? payment;

    if (_isFamilyMode) {
      if (_shouldMergeStudents) {
        // Сначала объединяем учеников в групповую карточку
        final studentController = ref.read(studentControllerProvider.notifier);
        final mergedStudent = await studentController.mergeStudents(
          sourceIds: _selectedFamilyStudents.map((s) => s.id).toList(),
          institutionId: widget.institutionId,
          newName: _mergedNameController.text.trim(),
        );

        if (mergedStudent == null) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ошибка при объединении учеников'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Создаём обычную оплату для объединённого ученика
        payment = await controller.create(
          institutionId: widget.institutionId,
          studentId: mergedStudent.id,
          paymentPlanId: _selectedPlan?.id,
          amount: double.parse(_amountController.text),
          lessonsCount: int.parse(_lessonsController.text),
          paymentMethod: _paymentMethod,
          validityDays: _selectedPlan != null ? int.parse(_validityController.text) : null,
          paidAt: _selectedDate,
          comment: comment.isEmpty ? null : comment,
        );
      } else {
        // Групповой абонемент без объединения
        payment = await controller.createFamilyPayment(
          institutionId: widget.institutionId,
          studentIds: _selectedFamilyStudents.map((s) => s.id).toList(),
          paymentPlanId: _selectedPlan?.id,
          amount: double.parse(_amountController.text),
          lessonsCount: int.parse(_lessonsController.text),
          paymentMethod: _paymentMethod,
          validityDays: int.parse(_validityController.text),
          paidAt: _selectedDate,
          comment: comment.isEmpty ? null : comment,
        );
      }
    } else {
      // Обычная оплата
      payment = await controller.create(
        institutionId: widget.institutionId,
        studentId: _selectedStudent!.id,
        paymentPlanId: _selectedPlan?.id,
        amount: double.parse(_amountController.text),
        lessonsCount: int.parse(_lessonsController.text),
        paymentMethod: _paymentMethod,
        validityDays: _selectedPlan != null ? int.parse(_validityController.text) : null,
        paidAt: _selectedDate,
        comment: comment.isEmpty ? null : comment,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (payment != null) {
        widget.onSuccess();
        Navigator.pop(context);
        String message;
        if (_isFamilyMode && _shouldMergeStudents) {
          message = 'Карточка объединена и оплата добавлена';
        } else if (_isFamilyMode) {
          message = 'Групповой абонемент добавлен';
        } else {
          message = 'Оплата добавлена';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Используем разные провайдеры в зависимости от прав
    final studentsAsync = widget.canAddForAllStudents
        ? ref.watch(studentsProvider(widget.institutionId))
        : ref.watch(studentsForPaymentProvider(widget.institutionId));
    final plansAsync = ref.watch(paymentPlansProvider(widget.institutionId));
    final controllerState = ref.watch(paymentControllerProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        // Сохраняем контроллер сразу для использования в FAB
        _currentScrollController = scrollController;
        return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Скроллируемый контент с FAB
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _handleScrollNotification(notification, scrollController);
                      return false;
                    },
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Заголовок
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payments,
                        color: AppColors.success,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Добавить оплату',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Выберите ученика и тариф',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Переключатель семейного абонемента
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isFamilyMode
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: _isFamilyMode
                        ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.family_restroom,
                        color: _isFamilyMode ? AppColors.primary : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Групповой абонемент',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Один абонемент на несколько учеников',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isFamilyMode,
                        onChanged: (value) {
                          setState(() {
                            _isFamilyMode = value;
                            if (value) {
                              // Переносим выбранного ученика в список
                              if (_selectedStudent != null) {
                                _selectedFamilyStudents = [_selectedStudent!];
                              }
                            } else {
                              // Переносим первого выбранного в одиночный выбор
                              _selectedStudent = _selectedFamilyStudents.isNotEmpty
                                  ? _selectedFamilyStudents.first
                                  : null;
                              _selectedFamilyStudents = [];
                            }
                          });
                        },
                        activeTrackColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Ученик / Ученики
                studentsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (students) {
                    if (students.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Сначала добавьте учеников'),
                      );
                    }

                    // Предвыбор ученика (один раз)
                    if (!_preselectionDone && widget.preselectedStudentId != null) {
                      final preselected = students.where((s) => s.id == widget.preselectedStudentId).firstOrNull;
                      if (preselected != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && !_preselectionDone) {
                            setState(() {
                              _selectedStudent = preselected;
                              _preselectionDone = true;
                            });
                          }
                        });
                      } else {
                        _preselectionDone = true;
                      }
                    }

                    if (_isFamilyMode) {
                      // Мультивыбор для семейного абонемента - список с чекбоксами
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Выберите участников',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_selectedFamilyStudents.length} из ${students.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _selectedFamilyStudents.length >= 2
                                      ? AppColors.success
                                      : Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final student = students[index];
                                final isSelected = _selectedFamilyStudents.any((s) => s.id == student.id);
                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedFamilyStudents.add(student);
                                      } else {
                                        _selectedFamilyStudents.removeWhere((s) => s.id == student.id);
                                      }
                                    });
                                  },
                                  title: Text(student.name),
                                  secondary: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isSelected
                                        ? AppColors.primary
                                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                                    child: Text(
                                      student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isSelected ? Colors.white : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  controlAffinity: ListTileControlAffinity.trailing,
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                );
                              },
                            ),
                          ),
                          if (_selectedFamilyStudents.length < 2)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Выберите минимум 2 ученика',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Опция объединения в групповую карточку
                          if (_selectedFamilyStudents.length >= 2) ...[
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: _shouldMergeStudents
                                    ? AppColors.primary.withValues(alpha: 0.05)
                                    : Theme.of(context).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: _shouldMergeStudents
                                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                                    : null,
                              ),
                              child: CheckboxListTile(
                                value: _shouldMergeStudents,
                                onChanged: (value) {
                                  setState(() {
                                    _shouldMergeStudents = value ?? false;
                                    if (_shouldMergeStudents && _mergedNameController.text.isEmpty) {
                                      // Предзаполняем имя
                                      final names = _selectedFamilyStudents.map((s) => s.name).toList();
                                      if (names.length == 2) {
                                        _mergedNameController.text = '${names[0]} и ${names[1]}';
                                      } else {
                                        _mergedNameController.text = names.first;
                                      }
                                    }
                                  });
                                },
                                title: const Text('Объединить в одну карточку'),
                                subtitle: const Text(
                                  'Создаст групповую карточку учеников',
                                  style: TextStyle(fontSize: 12),
                                ),
                                secondary: Icon(
                                  Icons.merge,
                                  color: _shouldMergeStudents ? AppColors.primary : Colors.grey,
                                ),
                                controlAffinity: ListTileControlAffinity.trailing,
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                            if (_shouldMergeStudents) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _mergedNameController,
                                decoration: InputDecoration(
                                  labelText: 'Имя групповой карточки',
                                  hintText: 'Например: Семья Петровых',
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                                ),
                                validator: _shouldMergeStudents
                                    ? (v) => v == null || v.isEmpty ? 'Введите имя' : null
                                    : null,
                                textCapitalization: TextCapitalization.words,
                              ),
                            ],
                          ],
                        ],
                      );
                    } else {
                      // Одиночный выбор
                      final currentStudent = _selectedStudent != null
                          ? students.where((s) => s.id == _selectedStudent!.id).firstOrNull
                          : null;
                      return DropdownButtonFormField<Student>(
                        decoration: InputDecoration(
                          labelText: 'Ученик',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                        ),
                        initialValue: currentStudent,
                        items: students.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        )).toList(),
                        onChanged: (student) {
                          setState(() => _selectedStudent = student);
                        },
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Дата оплаты
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Дата оплаты',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMMM yyyy', 'ru').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Способ оплаты
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Способ оплаты',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'card',
                            label: Text('Карта'),
                          ),
                          ButtonSegment(
                            value: 'cash',
                            label: Text('Наличные'),
                          ),
                        ],
                        selected: {_paymentMethod},
                        onSelectionChanged: (Set<String> selected) {
                          setState(() => _paymentMethod = selected.first);
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Тариф
                plansAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (plans) {
                    // Находим выбранный план по ID
                    final currentPlan = _selectedPlan != null
                        ? plans.where((p) => p.id == _selectedPlan!.id).firstOrNull
                        : null;
                    return DropdownButtonFormField<PaymentPlan?>(
                      decoration: InputDecoration(
                        labelText: 'Тариф',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      ),
                      isExpanded: true,
                      initialValue: currentPlan,
                      items: [
                        const DropdownMenuItem<PaymentPlan?>(
                          value: null,
                          child: Text('Свой вариант'),
                        ),
                        ...plans.map((plan) => DropdownMenuItem<PaymentPlan?>(
                              value: plan,
                              child: Text(plan.displayNameWithValidity),
                            )),
                      ],
                      onChanged: _onPlanSelected,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Скидка (только если выбран тариф)
                if (_selectedPlan != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _hasDiscount
                          ? AppColors.warning.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: _hasDiscount
                          ? Border.all(color: AppColors.warning.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _hasDiscount,
                              onChanged: (value) {
                                setState(() {
                                  _hasDiscount = value ?? false;
                                  if (!_hasDiscount) {
                                    _discountController.clear();
                                  }
                                  _updateFinalAmount();
                                });
                              },
                              activeColor: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.discount,
                              color: _hasDiscount ? AppColors.warning : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Скидка',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (_hasDiscount) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Builder(
                                  builder: (context) => TextFormField(
                                    controller: _discountController,
                                    decoration: InputDecoration(
                                      hintText: 'Размер скидки',
                                      suffixText: '₸',
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) {
                                      _updateFinalAmount();
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Builder(
                                builder: (context) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Было: ${_originalPrice.toStringAsFixed(0)} ₸',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    Text(
                                      'Итого: ${_amountController.text} ₸',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Сумма (заблокировано если выбран тариф)
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Сумма',
                    suffixText: '₸',
                    suffixIcon: _selectedPlan != null
                        ? const Icon(Icons.lock, size: 16, color: AppColors.textSecondary)
                        : null,
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: _selectedPlan != null
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.number,
                  enabled: _selectedPlan == null, // Блокировка при выборе тарифа
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите сумму';
                    if (double.tryParse(v) == null) return 'Неверная сумма';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Количество занятий и Срок действия в одной строке
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lessonsController,
                        decoration: InputDecoration(
                          labelText: 'Занятий',
                          isDense: true,
                          suffixIcon: _selectedPlan != null
                              ? const Icon(Icons.lock, size: 14, color: AppColors.textSecondary)
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: _selectedPlan != null
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : Theme.of(context).colorScheme.surfaceContainerLow,
                        ),
                        keyboardType: TextInputType.number,
                        enabled: _selectedPlan == null, // Блокировка при выборе тарифа
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите';
                          if (int.tryParse(v) == null) return 'Число';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _validityController,
                        decoration: InputDecoration(
                          labelText: 'Срок (дн.)',
                          isDense: true,
                          suffixIcon: _selectedPlan != null
                              ? const Icon(Icons.lock, size: 14, color: AppColors.textSecondary)
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: _selectedPlan != null
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : Theme.of(context).colorScheme.surfaceContainerLow,
                        ),
                        keyboardType: TextInputType.number,
                        enabled: _selectedPlan == null, // Блокировка при выборе тарифа
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите';
                          final num = int.tryParse(v);
                          if (num == null || num <= 0) return 'Ошибка';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Комментарий
                TextFormField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    labelText: 'Комментарий (необязательно)',
                    prefixIcon: const Icon(Icons.comment_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Кнопка
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading || controllerState.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading || controllerState.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check),
                              const SizedBox(width: 8),
                              Text(
                                _amountController.text.isNotEmpty
                                    ? 'Добавить оплату ${_amountController.text} ₸'
                                    : 'Добавить оплату',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // FAB для прокрутки вниз
                  if (_showScrollDownFab)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton.small(
                        onPressed: _scrollToBottom,
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
      },
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        date,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _PaymentCard extends ConsumerWidget {
  final Payment payment;
  final String institutionId;
  final VoidCallback onChanged;
  final Set<String> myStudentIds;

  const _PaymentCard({
    required this.payment,
    required this.institutionId,
    required this.onChanged,
    required this.myStudentIds,
  });

  /// Проверяет, может ли пользователь управлять этой оплатой
  bool _canManagePayment(WidgetRef ref) {
    final permissions = ref.watch(myPermissionsProvider(institutionId));
    final institutionAsync = ref.watch(currentInstitutionProvider(institutionId));
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

    final isOwner = institutionAsync.maybeWhen(
      data: (inst) => inst.ownerId == currentUserId,
      orElse: () => false,
    );
    final isAdmin = ref.watch(isAdminProvider(institutionId));
    final hasFullAccess = isOwner || isAdmin;

    if (hasFullAccess) return true;
    if (permissions?.manageAllPayments ?? false) return true;

    // Проверяем, это оплата своего ученика
    if (permissions?.manageOwnStudentsPayments ?? true) {
      // Проверяем основного ученика
      if (myStudentIds.contains(payment.studentId)) {
        return true;
      }
      // Для семейных абонементов проверяем всех участников
      if (payment.subscription?.members != null) {
        if (payment.subscription!.members!.any((m) => myStudentIds.contains(m.studentId))) {
          return true;
        }
      }
    }

    return false;
  }

  /// Извлекает название типа занятия из comment если это оплата занятия
  /// Формат: lesson:LESSON_ID|LESSON_TYPE_NAME
  String? _extractLessonTypeName() {
    final comment = payment.comment;
    if (comment == null || !comment.startsWith('lesson:')) return null;
    final pipeIndex = comment.indexOf('|');
    if (pipeIndex == -1) return null;
    return comment.substring(pipeIndex + 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat('#,###', 'ru_RU');
    final amountStr = '${formatter.format(payment.amount.toInt())} ₸';

    // Для семейных абонементов показываем всех участников
    final displayName = payment.displayMemberNames.isNotEmpty
        ? payment.displayMemberNames
        : 'Ученик';

    // Сначала проверяем, это оплата занятия (lesson:ID|TYPE_NAME)
    final lessonTypeName = _extractLessonTypeName();
    final planName = lessonTypeName ??
        payment.paymentPlan?.name ??
        (payment.isCorrection ? 'Корректировка' : 'Свой вариант');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showEditDialog(context, ref),
        leading: Icon(
          payment.isCash ? Icons.payments_outlined : Icons.credit_card,
          color: payment.isCash ? AppColors.success : AppColors.primary,
          size: 24,
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(child: Text(displayName, overflow: TextOverflow.ellipsis)),
                  if (payment.isFamilySubscription) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.family_restroom, size: 16, color: Colors.purple[400]),
                  ],
                ],
              ),
            ),
            Text(
              amountStr,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: payment.isCorrection && payment.amount < 0
                    ? AppColors.error
                    : null,
              ),
            ),
          ],
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                planName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text('${payment.lessonsCount} занятий'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final canManage = _canManagePayment(ref);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _EditPaymentSheet(
        payment: payment,
        institutionId: institutionId,
        canManage: canManage,
        onChanged: onChanged,
      ),
    );
  }
}

/// Форма редактирования оплаты
class _EditPaymentSheet extends ConsumerStatefulWidget {
  final Payment payment;
  final String institutionId;
  final bool canManage;
  final VoidCallback onChanged;

  const _EditPaymentSheet({
    required this.payment,
    required this.institutionId,
    required this.canManage,
    required this.onChanged,
  });

  @override
  ConsumerState<_EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends ConsumerState<_EditPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _lessonsController;
  late final TextEditingController _commentController;
  late final TextEditingController _discountController;
  late String _selectedMethod;
  bool _isLoading = false;

  // Скидка и дата
  bool _hasDiscount = false;
  double _originalAmount = 0;
  late DateTime _selectedDate;

  // Для FAB прокрутки вниз
  bool _showScrollDownFab = true;
  ScrollController? _currentScrollController;

  // Для редактирования участников семейного абонемента
  late List<String> _selectedMemberIds;
  late List<String> _originalMemberIds;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.payment.paidAt;
    _discountController = TextEditingController();

    // Извлекаем скидку из комментария (формат: "Скидка: X ₸")
    String commentWithoutDiscount = widget.payment.comment ?? '';
    final discountMatch = RegExp(r'Скидка:\s*(\d+)\s*₸').firstMatch(commentWithoutDiscount);
    if (discountMatch != null) {
      _hasDiscount = true;
      final discountAmount = double.tryParse(discountMatch.group(1) ?? '') ?? 0;
      _discountController.text = discountAmount.toStringAsFixed(0);
      _originalAmount = widget.payment.amount + discountAmount;
      // Убираем скидку из комментария для редактирования
      commentWithoutDiscount = commentWithoutDiscount
          .replaceFirst(RegExp(r'Скидка:\s*\d+\s*₸\n?'), '')
          .trim();
    } else {
      _originalAmount = widget.payment.amount;
    }

    _amountController = TextEditingController(text: widget.payment.amount.toInt().toString());
    _lessonsController = TextEditingController(text: widget.payment.lessonsCount.toString());
    _commentController = TextEditingController(text: commentWithoutDiscount);
    _selectedMethod = widget.payment.paymentMethod;

    // Инициализируем участников из подписки
    final members = widget.payment.subscription?.members ?? [];
    _selectedMemberIds = members.map((m) => m.studentId).toList();
    _originalMemberIds = List.from(_selectedMemberIds);
  }

  /// Проверяем, изменились ли участники
  bool get _membersChanged {
    if (_selectedMemberIds.length != _originalMemberIds.length) return true;
    final sortedNew = List<String>.from(_selectedMemberIds)..sort();
    final sortedOld = List<String>.from(_originalMemberIds)..sort();
    for (int i = 0; i < sortedNew.length; i++) {
      if (sortedNew[i] != sortedOld[i]) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _lessonsController.dispose();
    _commentController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _updateFinalAmount() {
    if (_hasDiscount && _discountController.text.isNotEmpty) {
      final discount = double.tryParse(_discountController.text) ?? 0;
      final finalAmount = _originalAmount - discount;
      _amountController.text = (finalAmount > 0 ? finalAmount : 0).toStringAsFixed(0);
    } else {
      _amountController.text = _originalAmount.toStringAsFixed(0);
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  void _handleScrollNotification(ScrollNotification notification, ScrollController controller) {
    _currentScrollController = controller;
    if (notification is ScrollUpdateNotification || notification is ScrollEndNotification) {
      final maxScroll = notification.metrics.maxScrollExtent;
      final currentScroll = notification.metrics.pixels;
      // Показываем FAB только если есть куда скроллить (больше 100px) и мы не внизу
      final shouldShow = maxScroll > 100 && currentScroll < maxScroll - 100;
      if (shouldShow != _showScrollDownFab) {
        setState(() => _showScrollDownFab = shouldShow);
      }
    }
  }

  void _scrollToBottom() {
    if (_currentScrollController == null || !_currentScrollController!.hasClients) return;
    _currentScrollController!.animateTo(
      _currentScrollController!.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Секция выбора участников группового абонемента
  Widget _buildMembersSection() {
    final studentsAsync = ref.watch(studentsProvider(widget.institutionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.family_restroom,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Участники абонемента',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '${_selectedMemberIds.length} выбрано',
              style: TextStyle(
                fontSize: 12,
                color: _selectedMemberIds.length >= 2
                    ? AppColors.success
                    : Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        studentsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Ошибка загрузки: $e'),
          data: (students) {
            if (students.isEmpty) {
              return const Text('Нет учеников');
            }

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  final isSelected = _selectedMemberIds.contains(student.id);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: widget.canManage
                        ? (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedMemberIds.add(student.id);
                              } else {
                                _selectedMemberIds.remove(student.id);
                              }
                            });
                          }
                        : null,
                    title: Text(student.name),
                    secondary: CircleAvatar(
                      radius: 16,
                      backgroundColor: isSelected
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: Text(
                        student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  );
                },
              ),
            );
          },
        ),
        if (_selectedMemberIds.length < 2)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 4),
                Text(
                  'Минимум 2 участника',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Проверяем минимум 2 участника для семейного абонемента
    if (widget.payment.isFamilySubscription && _selectedMemberIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите минимум 2 участника для группового абонемента'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(paymentControllerProvider.notifier);

      // 1. Обновляем участников если изменились
      if (_membersChanged && widget.payment.subscription != null) {
        final subscriptionRepo = ref.read(subscriptionRepositoryProvider);
        await subscriptionRepo.updateSubscriptionMembers(
          subscriptionId: widget.payment.subscription!.id,
          studentIds: _selectedMemberIds,
        );

        // Инвалидируем провайдеры затронутых студентов
        final allAffectedIds = {..._originalMemberIds, ..._selectedMemberIds};
        for (final studentId in allAffectedIds) {
          ref.invalidate(studentProvider(studentId));
          ref.invalidate(studentSubscriptionsProvider(studentId));
        }

        // Инвалидируем список оплат для обновления имён участников
        ref.invalidate(paymentsStreamProvider(widget.institutionId));
      }

      // 2. Формируем комментарий со скидкой
      String? comment = _commentController.text.trim();
      if (_hasDiscount && _discountController.text.isNotEmpty) {
        final discount = double.tryParse(_discountController.text) ?? 0;
        if (discount > 0) {
          final discountNote = 'Скидка: ${discount.toStringAsFixed(0)} ₸';
          comment = comment.isEmpty ? discountNote : '$discountNote\n$comment';
        }
      }

      // 3. Обновляем саму оплату
      final result = await controller.updatePayment(
        widget.payment.id,
        studentId: widget.payment.studentId,
        oldLessonsCount: widget.payment.lessonsCount,
        amount: double.parse(_amountController.text),
        lessonsCount: int.parse(_lessonsController.text),
        paymentMethod: _selectedMethod,
        paidAt: _selectedDate,
        comment: comment.isEmpty ? null : comment,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result != null) {
          widget.onChanged();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Оплата обновлена'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить оплату?'),
        content: Text(
          'Оплата на сумму ${widget.payment.amount.toInt()} ₸ будет удалена. '
          'Баланс ученика уменьшится на ${widget.payment.lessonsCount} занятий.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    final controller = ref.read(paymentControllerProvider.notifier);
    final success = await controller.deletePayment(
      widget.payment.id,
      studentId: widget.payment.studentId,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        widget.onChanged();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Оплата удалена'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        final state = ref.read(paymentControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: ${state.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.payment.displayMemberNames.isNotEmpty
        ? widget.payment.displayMemberNames
        : widget.payment.student?.name ?? 'Ученик';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      snap: true,
      snapSizes: const [0.7, 0.9],
      builder: (context, scrollController) {
        // Обновляем состояние FAB после первого рендера
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final maxScroll = scrollController.position.maxScrollExtent;
          final currentScroll = scrollController.position.pixels;
          final shouldShow = maxScroll > 100 && currentScroll < maxScroll - 100;
          if (shouldShow != _showScrollDownFab) {
            setState(() => _showScrollDownFab = shouldShow);
          }
        });

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Скроллируемый контент с FAB
              Expanded(
                child: Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        _handleScrollNotification(notification, scrollController);
                        return false;
                      },
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        children: [
                          if (!widget.canManage) ...[
                            // Баннер "Нет прав"
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.warning.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.lock_outline, color: AppColors.warning),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Нет прав на редактирование',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Вы можете редактировать только оплаты своих учеников',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Заголовок
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: (widget.payment.isCash ? AppColors.success : AppColors.primary)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        widget.payment.isCash ? Icons.payments_outlined : Icons.credit_card,
                                        color: widget.payment.isCash ? AppColors.success : AppColors.primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Оплата от ${DateFormat('d MMMM yyyy', 'ru').format(widget.payment.paidAt)}',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Сумма (заблокировано если есть тариф)
                                TextFormField(
                                  controller: _amountController,
                                  decoration: InputDecoration(
                                    labelText: 'Сумма',
                                    suffixText: '₸',
                                    prefixIcon: const Icon(Icons.payments_outlined),
                                    suffixIcon: widget.payment.paymentPlanId != null
                                        ? const Icon(Icons.lock, size: 18)
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: widget.payment.paymentPlanId != null
                                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                                        : Theme.of(context).colorScheme.surfaceContainerLow,
                                  ),
                                  keyboardType: TextInputType.number,
                                  enabled: widget.canManage && widget.payment.paymentPlanId == null,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Введите сумму';
                                    if (double.tryParse(v) == null) return 'Неверная сумма';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Количество занятий (заблокировано если есть тариф)
                                TextFormField(
                                  controller: _lessonsController,
                                  decoration: InputDecoration(
                                    labelText: 'Количество занятий',
                                    prefixIcon: const Icon(Icons.event),
                                    suffixIcon: widget.payment.paymentPlanId != null
                                        ? const Icon(Icons.lock, size: 18)
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: widget.payment.paymentPlanId != null
                                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                                        : Theme.of(context).colorScheme.surfaceContainerLow,
                                  ),
                                  keyboardType: TextInputType.number,
                                  enabled: widget.canManage && widget.payment.paymentPlanId == null,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Введите количество';
                                    if (int.tryParse(v) == null) return 'Неверное число';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Способ оплаты
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Способ оплаты',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: SegmentedButton<String>(
                                        segments: const [
                                          ButtonSegment(
                                            value: 'card',
                                            label: Text('Карта'),
                                          ),
                                          ButtonSegment(
                                            value: 'cash',
                                            label: Text('Наличные'),
                                          ),
                                        ],
                                        selected: {_selectedMethod},
                                        onSelectionChanged: widget.canManage
                                            ? (Set<String> selected) {
                                                setState(() => _selectedMethod = selected.first);
                                              }
                                            : null,
                                        style: const ButtonStyle(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Дата оплаты
                                if (widget.canManage)
                                  InkWell(
                                    onTap: _selectDate,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, color: AppColors.primary),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Дата оплаты',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                DateFormat('dd MMMM yyyy', 'ru').format(_selectedDate),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (widget.canManage) const SizedBox(height: 16),

                                // Скидка
                                if (widget.canManage)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _hasDiscount
                                          ? AppColors.warning.withValues(alpha: 0.1)
                                          : Theme.of(context).colorScheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(12),
                                      border: _hasDiscount
                                          ? Border.all(color: AppColors.warning.withValues(alpha: 0.3))
                                          : null,
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: _hasDiscount,
                                              onChanged: (value) {
                                                setState(() {
                                                  _hasDiscount = value ?? false;
                                                  if (!_hasDiscount) {
                                                    _discountController.clear();
                                                    _amountController.text = _originalAmount.toStringAsFixed(0);
                                                  }
                                                });
                                              },
                                              activeColor: AppColors.warning,
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.discount,
                                              color: _hasDiscount ? AppColors.warning : Colors.grey,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Скидка',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_hasDiscount) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  controller: _discountController,
                                                  decoration: InputDecoration(
                                                    hintText: 'Размер скидки',
                                                    suffixText: '₸',
                                                    filled: true,
                                                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                                                    contentPadding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: BorderSide.none,
                                                    ),
                                                  ),
                                                  keyboardType: TextInputType.number,
                                                  onChanged: (_) {
                                                    _updateFinalAmount();
                                                    setState(() {});
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'Было: ${_originalAmount.toStringAsFixed(0)} ₸',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      decoration: TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Итого: ${_amountController.text} ₸',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.success,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                if (widget.canManage) const SizedBox(height: 16),

                                // Комментарий
                                TextFormField(
                                  controller: _commentController,
                                  decoration: InputDecoration(
                                    labelText: 'Комментарий',
                                    prefixIcon: const Icon(Icons.comment_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                                  ),
                                  maxLines: 3,
                                  enabled: widget.canManage,
                                ),

                                // Участники группового абонемента
                                if (widget.payment.isFamilySubscription) ...[
                                  const SizedBox(height: 24),
                                  _buildMembersSection(),
                                ],

                                const SizedBox(height: 24),

                                // Кнопка сохранения
                                if (widget.canManage) ...[
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation(Colors.white),
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.check),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Сохранить изменения',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Кнопка удаления
                                  SizedBox(
                                    height: 52,
                                    child: OutlinedButton(
                                      onPressed: _isLoading ? null : _delete,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation(Colors.red),
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.delete_outline),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Удалить оплату',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // FAB для прокрутки вниз
                    if (_showScrollDownFab && widget.canManage)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          onPressed: _scrollToBottom,
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Кнопка фильтра
class _FilterButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primary.withValues(alpha: 0.15) : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.primary : Theme.of(context).colorScheme.outlineVariant,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.primary : Colors.grey[700],
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: isActive ? AppColors.primary : Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
