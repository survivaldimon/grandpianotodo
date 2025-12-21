import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/statistics/repositories/statistics_repository.dart';

/// Провайдер репозитория статистики
final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepository();
});

/// Период статистики
enum StatsPeriod {
  week,
  month,
  quarter,
  year,
  custom,
}

/// Кастомные даты периода
class CustomDateRange {
  final DateTime start;
  final DateTime end;

  const CustomDateRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomDateRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}

/// Провайдер выбранного периода
final statsPeriodProvider = StateProvider<StatsPeriod>((ref) => StatsPeriod.month);

/// Провайдер кастомного диапазона дат
final customDateRangeProvider = StateProvider<CustomDateRange?>((ref) => null);

/// Даты периода
/// Если customRange задан - используем его даты для любого периода
/// Это позволяет навигировать стрелками, сохраняя выбранный тип периода
(DateTime, DateTime) getPeriodDates(StatsPeriod period, {CustomDateRange? customRange}) {
  // Если есть customRange - используем его даты
  if (customRange != null) {
    return (
      DateTime(customRange.start.year, customRange.start.month, customRange.start.day),
      DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59),
    );
  }

  // Иначе вычисляем даты по типу периода
  final now = DateTime.now();
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

  switch (period) {
    case StatsPeriod.week:
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
      return (weekStart, todayEnd);
    case StatsPeriod.month:
      final monthStart = DateTime(now.year, now.month, 1);
      return (monthStart, todayEnd);
    case StatsPeriod.quarter:
      final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      final quarterStart = DateTime(now.year, quarterMonth, 1);
      return (quarterStart, todayEnd);
    case StatsPeriod.year:
      final yearStart = DateTime(now.year, 1, 1);
      return (yearStart, todayEnd);
    case StatsPeriod.custom:
      // Fallback to month if no custom range set
      final monthStart = DateTime(now.year, now.month, 1);
      return (monthStart, todayEnd);
  }
}

/// Параметры запроса статистики
class StatsParams {
  final String institutionId;
  final StatsPeriod period;
  final CustomDateRange? customRange;

  const StatsParams({
    required this.institutionId,
    required this.period,
    this.customRange,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatsParams &&
          runtimeType == other.runtimeType &&
          institutionId == other.institutionId &&
          period == other.period &&
          customRange == other.customRange;

  @override
  int get hashCode => Object.hash(institutionId, period, customRange);
}

/// Провайдер общей статистики
final generalStatsProvider =
    FutureProvider.family<GeneralStats, StatsParams>((ref, params) async {
  final repo = ref.watch(statisticsRepositoryProvider);
  final (startDate, endDate) = getPeriodDates(params.period, customRange: params.customRange);

  return repo.getGeneralStats(
    institutionId: params.institutionId,
    startDate: startDate,
    endDate: endDate,
  );
});

/// Провайдер статистики по предметам
final subjectStatsProvider =
    FutureProvider.family<List<SubjectStats>, StatsParams>((ref, params) async {
  final repo = ref.watch(statisticsRepositoryProvider);
  final (startDate, endDate) = getPeriodDates(params.period, customRange: params.customRange);

  return repo.getSubjectStats(
    institutionId: params.institutionId,
    startDate: startDate,
    endDate: endDate,
  );
});

/// Провайдер статистики по преподавателям
final teacherStatsProvider =
    FutureProvider.family<List<TeacherStats>, StatsParams>((ref, params) async {
  final repo = ref.watch(statisticsRepositoryProvider);
  final (startDate, endDate) = getPeriodDates(params.period, customRange: params.customRange);

  return repo.getTeacherStats(
    institutionId: params.institutionId,
    startDate: startDate,
    endDate: endDate,
  );
});

/// Провайдер топа учеников
final topStudentsProvider =
    FutureProvider.family<List<StudentStats>, StatsParams>((ref, params) async {
  final repo = ref.watch(statisticsRepositoryProvider);
  final (startDate, endDate) = getPeriodDates(params.period, customRange: params.customRange);

  return repo.getTopStudents(
    institutionId: params.institutionId,
    startDate: startDate,
    endDate: endDate,
  );
});

/// Провайдер должников
final debtorsProvider =
    FutureProvider.family<List<StudentStats>, String>((ref, institutionId) async {
  final repo = ref.watch(statisticsRepositoryProvider);
  return repo.getDebtors(institutionId: institutionId);
});

/// Провайдер статистики по тарифам
final paymentPlanStatsProvider =
    FutureProvider.family<List<PaymentPlanStats>, StatsParams>((ref, params) async {
  final repo = ref.watch(statisticsRepositoryProvider);
  final (startDate, endDate) = getPeriodDates(params.period, customRange: params.customRange);

  return repo.getPaymentPlanStats(
    institutionId: params.institutionId,
    startDate: startDate,
    endDate: endDate,
  );
});
