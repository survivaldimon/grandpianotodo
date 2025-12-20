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
}

/// Провайдер выбранного периода
final statsPeriodProvider = StateProvider<StatsPeriod>((ref) => StatsPeriod.month);

/// Даты периода
(DateTime, DateTime) getPeriodDates(StatsPeriod period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (period) {
    case StatsPeriod.week:
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      return (weekStart, today);
    case StatsPeriod.month:
      final monthStart = DateTime(now.year, now.month, 1);
      return (monthStart, today);
    case StatsPeriod.quarter:
      final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      final quarterStart = DateTime(now.year, quarterMonth, 1);
      return (quarterStart, today);
    case StatsPeriod.year:
      final yearStart = DateTime(now.year, 1, 1);
      return (yearStart, today);
  }
}

/// Параметры запроса статистики
class StatsParams {
  final String institutionId;
  final StatsPeriod period;

  const StatsParams({
    required this.institutionId,
    required this.period,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatsParams &&
          runtimeType == other.runtimeType &&
          institutionId == other.institutionId &&
          period == other.period;

  @override
  int get hashCode => institutionId.hashCode ^ period.hashCode;
}

/// Провайдер общей статистики
final generalStatsProvider =
    FutureProvider.family<GeneralStats, StatsParams>((ref, params) async {
  final repo = ref.watch(statisticsRepositoryProvider);
  final (startDate, endDate) = getPeriodDates(params.period);

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
  final (startDate, endDate) = getPeriodDates(params.period);

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
  final (startDate, endDate) = getPeriodDates(params.period);

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
  final (startDate, endDate) = getPeriodDates(params.period);

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
