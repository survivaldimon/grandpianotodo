/// Период для статистики
enum StatisticsPeriod {
  day,
  week,
  month,
  custom;

  String get displayName {
    switch (this) {
      case StatisticsPeriod.day:
        return 'День';
      case StatisticsPeriod.week:
        return 'Неделя';
      case StatisticsPeriod.month:
        return 'Месяц';
      case StatisticsPeriod.custom:
        return 'Произвольный';
    }
  }
}
