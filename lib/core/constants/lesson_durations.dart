/// Стандартные длительности занятий (в минутах)
class LessonDurations {
  LessonDurations._();

  static const List<int> standard = [30, 45, 60, 90];
  static const int defaultDuration = 60;

  /// Получить отображаемую строку
  static String getDisplayString(int minutes) {
    if (minutes < 60) {
      return '$minutes мин';
    } else if (minutes == 60) {
      return '1 час';
    } else if (minutes == 90) {
      return '1.5 часа';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '$hours ч';
      }
      return '$hours ч $mins мин';
    }
  }
}
