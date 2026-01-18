import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/statistics/providers/statistics_provider.dart';
import 'package:kabinet/features/statistics/repositories/statistics_repository.dart';
import 'package:kabinet/l10n/app_localizations.dart';

/// Экран статистики
class StatisticsScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const StatisticsScreen({super.key, required this.institutionId});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy', 'ru');

  @override
  void initState() {
    super.initState();
    // Принудительно обновляем права при открытии экрана статистики
    Future.microtask(() {
      ref.invalidate(myMembershipProvider(widget.institutionId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Проверяем права на просмотр статистики
    final permissions = ref.watch(myPermissionsProvider(widget.institutionId));
    final institutionAsync = ref.watch(currentInstitutionProvider(widget.institutionId));
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

    final isOwner = institutionAsync.maybeWhen(
      data: (inst) => inst.ownerId == currentUserId,
      orElse: () => false,
    );

    final isAdmin = ref.watch(isAdminProvider(widget.institutionId));
    final hasFullAccess = isOwner || isAdmin;

    final canViewStatistics = hasFullAccess || (permissions?.viewStatistics ?? false);

    if (!canViewStatistics) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.statistics)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                l10n.noAccessToStatistics,
                style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.contactOwner,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final period = ref.watch(statsPeriodProvider);
    final customRange = ref.watch(customDateRangeProvider);

    // Получаем актуальные даты для отображения
    final (displayStart, displayEnd) = _getDisplayDates(period, customRange);

    final params = StatsParams(
      institutionId: widget.institutionId,
      period: period,
      customRange: customRange,
    );

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.statistics),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.statsTabGeneral),
              Tab(text: l10n.subjects),
              Tab(text: l10n.teachers),
              Tab(text: l10n.students),
              Tab(text: l10n.paymentPlans),
            ],
          ),
        ),
        body: Column(
          children: [
            // Быстрый выбор периода
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
                          label: Text(_periodLabel(p, l10n)),
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
            const Divider(height: 1),
            // Контент
            Expanded(
              child: TabBarView(
                children: [
                  _GeneralTab(params: params),
                  _SubjectsTab(params: params),
                  _TeachersTab(params: params),
                  _StudentsTab(institutionId: widget.institutionId, params: params),
                  _PaymentPlansTab(params: params),
                ],
              ),
            ),
          ],
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

  String _periodLabel(StatsPeriod period, AppLocalizations l10n) {
    switch (period) {
      case StatsPeriod.week:
        return l10n.periodWeek;
      case StatsPeriod.month:
        return l10n.periodMonth;
      case StatsPeriod.quarter:
        return l10n.periodQuarter;
      case StatsPeriod.year:
        return l10n.periodYear;
      case StatsPeriod.custom:
        return l10n.periodCustom;
    }
  }

  /// Выбрать предустановленный период и обновить даты
  void _selectPresetPeriod(StatsPeriod period) {
    ref.read(statsPeriodProvider.notifier).state = period;
    // Обновляем customRange чтобы даты отображались корректно
    final (start, end) = getPeriodDates(period);
    ref.read(customDateRangeProvider.notifier).state = CustomDateRange(start, end);
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

    // Вычисляем длительность текущего периода для custom
    final duration = currentEnd.difference(currentStart);

    switch (period) {
      case StatsPeriod.week:
        // Неделя: понедельник - воскресенье
        if (forward) {
          newStart = currentStart.add(const Duration(days: 7));
        } else {
          newStart = currentStart.subtract(const Duration(days: 7));
        }
        // Находим понедельник недели
        newStart = newStart.subtract(Duration(days: newStart.weekday - 1));
        newEnd = DateTime(newStart.year, newStart.month, newStart.day + 6, 23, 59, 59);
        break;
      case StatsPeriod.month:
        // Месяц: с 1 по последний день
        if (forward) {
          newStart = DateTime(currentStart.year, currentStart.month + 1, 1);
        } else {
          newStart = DateTime(currentStart.year, currentStart.month - 1, 1);
        }
        newEnd = DateTime(newStart.year, newStart.month + 1, 0, 23, 59, 59);
        break;
      case StatsPeriod.quarter:
        // Квартал: с 1 числа первого месяца по последний день третьего месяца
        final currentQuarterStart = ((currentStart.month - 1) ~/ 3) * 3 + 1;
        if (forward) {
          newStart = DateTime(currentStart.year, currentQuarterStart + 3, 1);
        } else {
          newStart = DateTime(currentStart.year, currentQuarterStart - 3, 1);
        }
        // Корректируем год если нужно
        if (newStart.month < 1) {
          newStart = DateTime(newStart.year - 1, 12 + newStart.month, 1);
        } else if (newStart.month > 12) {
          newStart = DateTime(newStart.year + 1, newStart.month - 12, 1);
        }
        newEnd = DateTime(newStart.year, newStart.month + 3, 0, 23, 59, 59);
        break;
      case StatsPeriod.year:
        // Год: с 1 января по 31 декабря
        if (forward) {
          newStart = DateTime(currentStart.year + 1, 1, 1);
        } else {
          newStart = DateTime(currentStart.year - 1, 1, 1);
        }
        newEnd = DateTime(newStart.year, 12, 31, 23, 59, 59);
        break;
      case StatsPeriod.custom:
        // Для кастомного периода сдвигаем на его длительность
        if (forward) {
          newStart = currentEnd.add(const Duration(days: 1));
          newEnd = newStart.add(duration);
        } else {
          newEnd = currentStart.subtract(const Duration(days: 1));
          newStart = newEnd.subtract(duration);
        }
        break;
    }

    // Не даём уйти в будущее
    if (newEnd.isAfter(today)) {
      newEnd = today;
    }

    // Обновляем даты, НЕ меняя тип периода
    ref.read(customDateRangeProvider.notifier).state = CustomDateRange(newStart, newEnd);
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
      ref.read(statsPeriodProvider.notifier).state = StatsPeriod.custom;
      ref.read(customDateRangeProvider.notifier).state = CustomDateRange(
        picked.start,
        picked.end,
      );
    }
  }
}

/// Вкладка общей статистики
class _GeneralTab extends ConsumerWidget {
  final StatsParams params;

  const _GeneralTab({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(generalStatsProvider(params));

    final stats = statsAsync.valueOrNull;

    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Занятия
          _SectionTitle(title: l10n.lessons),
          _StatsGrid(
            items: [
              _StatItem(
                label: l10n.statsTotal,
                value: stats.totalLessons.toString(),
                icon: Icons.event,
                color: AppColors.primary,
              ),
              _StatItem(
                label: l10n.completed,
                value: stats.completedLessons.toString(),
                icon: Icons.check_circle,
                color: AppColors.success,
              ),
              _StatItem(
                label: l10n.cancelled,
                value: stats.cancelledLessons.toString(),
                icon: Icons.cancel,
                color: AppColors.error,
              ),
              _StatItem(
                label: l10n.scheduled,
                value: stats.scheduledLessons.toString(),
                icon: Icons.schedule,
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Финансы
          _SectionTitle(title: l10n.statsFinances),
          Builder(
            builder: (context) {
              // Рассчитываем среднюю стоимость: точную (из subscription_id) или приблизительную
              final double avgCost;
              final bool isApproximate;
              if (stats.avgLessonCost > 0) {
                avgCost = stats.avgLessonCost;
                isApproximate = false;
              } else if (stats.completedLessons > 0 && stats.totalPayments > 0) {
                // Приблизительный расчёт: оплаты / проведённые занятия
                avgCost = stats.totalPayments / stats.completedLessons;
                isApproximate = true;
              } else {
                avgCost = 0;
                isApproximate = false;
              }

              return _StatsGrid(
                items: [
                  _StatItem(
                    label: l10n.payments,
                    value: _formatMoney(stats.totalPayments),
                    icon: Icons.payments,
                    color: AppColors.success,
                  ),
                  if (avgCost > 0)
                    _StatItem(
                      label: isApproximate ? l10n.statsAvgLessonApprox : l10n.statsAvgLesson,
                      value: _formatMoney(avgCost),
                      icon: Icons.trending_up,
                      color: AppColors.primary,
                    ),
                  if (stats.totalDiscounts > 0)
                    _StatItem(
                      label: l10n.statsDiscounts,
                      value: _formatMoney(stats.totalDiscounts),
                      icon: Icons.discount,
                      color: AppColors.warning,
                    ),
                ],
              );
            },
          ),
          // Детализация
          if (stats.paidLessonsCount > 0 || stats.discountedPaymentsCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  if (stats.paidLessonsCount > 0)
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.statsPaidLessonsOf(stats.paidLessonsCount, stats.completedLessons),
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  if (stats.discountedPaymentsCount > 0) ...[
                    if (stats.paidLessonsCount > 0) const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.discount_outlined, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.statsPaymentsWithDiscount(stats.discountedPaymentsCount),
                            style: const TextStyle(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Загруженность
          _SectionTitle(title: l10n.statsWorkload),
          _StatsGrid(
            items: [
              _StatItem(
                label: l10n.statsLessonHours,
                value: stats.roomHours.toStringAsFixed(1),
                icon: Icons.access_time,
                color: AppColors.primary,
              ),
              _StatItem(
                label: l10n.statsActiveStudents,
                value: stats.activeStudents.toString(),
                icon: Icons.people,
                color: AppColors.primary,
              ),
            ],
          ),

          // Способы оплаты (если есть оплаты)
          if (stats.cashCount > 0 || stats.cardCount > 0) ...[
            const SizedBox(height: 24),
            _SectionTitle(title: l10n.statsPaymentMethods),
            _StatsGrid(
              items: [
                _StatItem(
                  label: l10n.card,
                  value: _formatMoney(stats.cardTotal),
                  icon: Icons.credit_card,
                  color: AppColors.primary,
                ),
                _StatItem(
                  label: l10n.cash,
                  value: _formatMoney(stats.cashTotal),
                  icon: Icons.payments_outlined,
                  color: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Детализация по количеству и процентам
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.credit_card, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.statsCardPayments(stats.cardCount, _calcPercent(stats.cardTotal, stats.totalPayments)),
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.statsCashPayments(stats.cashCount, _calcPercent(stats.cashTotal, stats.totalPayments)),
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
    );
  }

  String _calcPercent(double part, double total) {
    if (total <= 0) return '0';
    return ((part / total) * 100).toStringAsFixed(0);
  }

  String _formatMoney(double amount) {
    final formatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₸', decimalDigits: 0);
    return formatter.format(amount);
  }
}

/// Вкладка статистики по предметам
class _SubjectsTab extends ConsumerWidget {
  final StatsParams params;

  const _SubjectsTab({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(subjectStatsProvider(params));
    final generalStatsAsync = ref.watch(generalStatsProvider(params));
    final formatter = NumberFormat('#,###', 'ru_RU');

    final stats = statsAsync.valueOrNull;

    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stats.isEmpty) {
      return Center(child: Text(l10n.noDataForPeriod));
    }

    // Получаем общую среднюю стоимость для приблизительного расчёта
    final generalStats = generalStatsAsync.valueOrNull;
        final double approxAvgCost = generalStats != null &&
                generalStats.completedLessons > 0 &&
                generalStats.totalPayments > 0
            ? generalStats.totalPayments / generalStats.completedLessons
            : 0;

        return ListView.builder(
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            final color = stat.color != null
                ? Color(int.parse('FF${stat.color!.replaceAll('#', '')}', radix: 16))
                : AppColors.primary;

            // Показываем точную или приблизительную стоимость
            final showCost = stat.avgLessonCost > 0 || approxAvgCost > 0;
            final costValue = stat.avgLessonCost > 0 ? stat.avgLessonCost : approxAvgCost;
            final isApproximate = stat.avgLessonCost <= 0 && approxAvgCost > 0;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(Icons.music_note, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.subjectName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${stat.percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              if (showCost) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.trending_up,
                                        size: 12,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${isApproximate ? '≈ ' : ''}${formatter.format(costValue.round())} ₸',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${stat.lessonsCount}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}

/// Вкладка статистики по преподавателям
class _TeachersTab extends ConsumerWidget {
  final StatsParams params;

  const _TeachersTab({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(teacherStatsProvider(params));
    final generalStatsAsync = ref.watch(generalStatsProvider(params));
    final formatter = NumberFormat('#,###', 'ru_RU');

    final stats = statsAsync.valueOrNull;

    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stats.isEmpty) {
      return Center(child: Text(l10n.noDataForPeriod));
    }

    // Получаем общую среднюю стоимость для приблизительного расчёта
    final generalStats = generalStatsAsync.valueOrNull;
        final double approxAvgCost = generalStats != null &&
                generalStats.completedLessons > 0 &&
                generalStats.totalPayments > 0
            ? generalStats.totalPayments / generalStats.completedLessons
            : 0;

        return ListView.builder(
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];

            // Показываем точную или приблизительную стоимость
            final showCost = stat.avgLessonCost > 0 || approxAvgCost > 0;
            final costValue = stat.avgLessonCost > 0 ? stat.avgLessonCost : approxAvgCost;
            final isApproximate = stat.avgLessonCost <= 0 && approxAvgCost > 0;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(
                        stat.teacherName.isNotEmpty ? stat.teacherName[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.teacherName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          if (stat.subjects.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              stat.subjects.join(', '),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (showCost) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.trending_up,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${l10n.statsAvgLessonShort}: ${isApproximate ? '≈ ' : ''}${formatter.format(costValue.round())} ₸',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${stat.lessonsCount}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}

/// Вкладка статистики по ученикам
class _StudentsTab extends ConsumerWidget {
  final String institutionId;
  final StatsParams params;

  const _StudentsTab({
    required this.institutionId,
    required this.params,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final topStudentsAsync = ref.watch(topStudentsProvider(params));
    final debtorsAsync = ref.watch(debtorsProvider(institutionId));
    final generalStatsAsync = ref.watch(generalStatsProvider(params));
    final lessonStatsAsync = ref.watch(allStudentsLessonStatsProvider(params));

    return ListView(
      children: [
        // Статистика занятий (проведено/отменено)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _SectionTitle(title: l10n.statsLessonStats),
        ),
        Builder(
          builder: (context) {
            final stats = generalStatsAsync.valueOrNull;

            if (stats == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final total = stats.completedLessons + stats.cancelledLessons;
            final cancellationRate = total > 0
                ? (stats.cancelledLessons / total * 100).toStringAsFixed(1)
                : '0';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Проведено
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stats.completedLessons.toString(),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                                Text(
                                  l10n.completed,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Отменено
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.cancel,
                                  color: AppColors.error,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stats.cancelledLessons.toString(),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                  ),
                                ),
                                Text(
                                  l10n.cancelled,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (stats.cancelledLessons > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.cancellationRatePercent(cancellationRate.toString()),
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),

        const Divider(height: 32),

        // Топ учеников
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SectionTitle(title: l10n.topByLessons),
        ),
        Builder(
          builder: (context) {
            final students = topStudentsAsync.valueOrNull;

            if (students == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (students.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noDataForPeriod),
              );
            }

            return Column(
              children: students.asMap().entries.map((entry) {
                final index = entry.key;
                final stat = entry.value;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getMedalColor(index),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: index < 3 ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(stat.studentName),
                  trailing: Text(
                    l10n.lessonsCountShort(stat.lessonsCount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const Divider(height: 32),

        // Должники
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SectionTitle(title: l10n.debtors),
        ),
        Builder(
          builder: (context) {
            final debtors = debtorsAsync.valueOrNull;

            if (debtors == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (debtors.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(l10n.noDebtors),
                  ],
                ),
              );
            }

            return Column(
              children: debtors.map((stat) {
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.error,
                    child: Icon(Icons.warning, color: Colors.white),
                  ),
                  title: Text(stat.studentName),
                  trailing: Text(
                    '${stat.balance}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const Divider(height: 32),

        // Статистика по каждому ученику
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SectionTitle(title: l10n.byStudents),
        ),
        Builder(
          builder: (context) {
            final stats = lessonStatsAsync.valueOrNull;

            if (stats == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (stats.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noDataForPeriod),
              );
            }

            return Column(
              children: stats.map((stat) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Имя ученика
                        Expanded(
                          child: Text(
                            stat.studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Проведено
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                stat.completedCount.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Отменено
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cancel,
                                size: 16,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                stat.cancelledCount.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Color _getMedalColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFFFD700); // Gold
      case 1:
        return const Color(0xFFC0C0C0); // Silver
      case 2:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.surfaceVariant;
    }
  }
}

/// Вкладка статистики по тарифам оплаты
class _PaymentPlansTab extends ConsumerWidget {
  final StatsParams params;

  const _PaymentPlansTab({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(paymentPlanStatsProvider(params));
    final generalStatsAsync = ref.watch(generalStatsProvider(params));

    final stats = statsAsync.valueOrNull;

    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stats.isEmpty) {
      return Center(child: Text(l10n.noDataForPeriod));
    }

    // Считаем итоги
    final totalPurchases = stats.fold<int>(0, (sum, s) => sum + s.purchaseCount);
    final totalAmount = stats.fold<double>(0, (sum, s) => sum + s.totalAmount);
    final totalLessons = stats.fold<int>(0, (sum, s) => sum + s.totalLessons);

        // Получаем данные о скидках
        final generalStats = generalStatsAsync.valueOrNull;
        final totalDiscounts = generalStats?.totalDiscounts ?? 0;
        final discountedCount = generalStats?.discountedPaymentsCount ?? 0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Итоги
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryItem(
                        label: l10n.purchases,
                        value: totalPurchases.toString(),
                        icon: Icons.shopping_cart,
                      ),
                      _SummaryItem(
                        label: l10n.sumLabel,
                        value: _formatMoney(totalAmount),
                        icon: Icons.payments,
                      ),
                      _SummaryItem(
                        label: l10n.lessons,
                        value: totalLessons.toString(),
                        icon: Icons.event,
                      ),
                    ],
                  ),
                  // Средняя стоимость занятия
                  if (totalLessons > 0) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.trending_up, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${l10n.avgLessonCost}: ',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _formatMoney(totalAmount / totalLessons),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Секция со скидками
            if (discountedCount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.discount, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Text(
                          l10n.paymentsWithDiscount,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          label: l10n.payments,
                          value: discountedCount.toString(),
                          icon: Icons.receipt_long,
                          color: AppColors.warning,
                        ),
                        _SummaryItem(
                          label: l10n.discountSum,
                          value: _formatMoney(totalDiscounts),
                          icon: Icons.savings,
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Способы оплаты (общие итоги)
            Builder(
              builder: (context) {
                final totalCashTotal = stats.fold<double>(0, (sum, s) => sum + s.cashTotal);
                final totalCardTotal = stats.fold<double>(0, (sum, s) => sum + s.cardTotal);
                final totalCashCount = stats.fold<int>(0, (sum, s) => sum + s.cashCount);
                final totalCardCount = stats.fold<int>(0, (sum, s) => sum + s.cardCount);

                if (totalCashCount == 0 && totalCardCount == 0) {
                  return const SizedBox.shrink();
                }

                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.credit_card, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                l10n.paymentMethods,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _SummaryItem(
                                label: l10n.cardPaymentsCount(totalCardCount),
                                value: _formatMoney(totalCardTotal),
                                icon: Icons.credit_card,
                                color: AppColors.primary,
                              ),
                              _SummaryItem(
                                label: l10n.cashPaymentsCount(totalCashCount),
                                value: _formatMoney(totalCashTotal),
                                icon: Icons.payments_outlined,
                                color: AppColors.success,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            _SectionTitle(title: l10n.byPlans),
            const SizedBox(height: 8),
            ...stats.map((stat) => _PaymentPlanStatCard(stat: stat)),
          ],
        );
  }

  String _formatMoney(double amount) {
    final formatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₸', decimalDigits: 0);
    return formatter.format(amount);
  }
}

/// Элемент итоговой статистики
class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppColors.success;
    return Column(
      children: [
        Icon(icon, color: itemColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: itemColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Карточка статистики по тарифу
class _PaymentPlanStatCard extends StatelessWidget {
  final PaymentPlanStats stat;

  const _PaymentPlanStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₸', decimalDigits: 0);
    final avgCost = stat.totalLessons > 0 ? stat.totalAmount / stat.totalLessons : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с названием и количеством покупок
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: stat.planId != null && stat.planId != 'custom'
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.textSecondary.withValues(alpha: 0.2),
                  child: Icon(
                    stat.planId != null && stat.planId != 'custom'
                        ? Icons.card_membership
                        : Icons.edit,
                    color: stat.planId != null && stat.planId != 'custom'
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stat.planName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${stat.purchaseCount} ${AppLocalizations.of(context).purchasesShort}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Детализация
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Сумма и занятия
                  Row(
                    children: [
                      Expanded(
                        child: _DetailRow(
                          icon: Icons.payments,
                          label: l10n.sumLabel,
                          value: formatter.format(stat.totalAmount),
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DetailRow(
                          icon: Icons.event,
                          label: l10n.lessons,
                          value: stat.totalLessons.toString(),
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  // Средняя стоимость
                  if (stat.totalLessons > 0) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.trending_up, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${l10n.avgLesson}: ',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          formatter.format(avgCost),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Способы оплаты для этого тарифа
                  if (stat.cashCount > 0 || stat.cardCount > 0) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (stat.cardCount > 0) ...[
                          const Icon(Icons.credit_card, size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            formatter.format(stat.cardTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            ' (${stat.cardCount})',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (stat.cardCount > 0 && stat.cashCount > 0)
                          const SizedBox(width: 16),
                        if (stat.cashCount > 0) ...[
                          const Icon(Icons.payments_outlined, size: 16, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            formatter.format(stat.cashTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppColors.success,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            ' (${stat.cashCount})',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Строка детализации
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Заголовок секции
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

/// Сетка статистики
class _StatsGrid extends StatelessWidget {
  final List<_StatItem> items;

  const _StatsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: items.map((item) => _StatCard(item: item)).toList(),
    );
  }
}

/// Элемент статистики
class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

/// Карточка статистики
class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 20, color: item.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: item.color,
            ),
          ),
        ],
      ),
    );
  }
}
