import 'package:kabinet/l10n/app_localizations.dart';

/// Стандартные длительности занятий (в минутах)
class LessonDurations {
  LessonDurations._();

  static const List<int> standard = [30, 45, 60, 90];
  static const int defaultDuration = 60;

  /// Получить отображаемую строку (устаревший, используйте getLocalizedDisplayString)
  @Deprecated('Use getLocalizedDisplayString(minutes, l10n) instead')
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

  /// Получить локализованную отображаемую строку
  static String getLocalizedDisplayString(int minutes, AppLocalizations l10n) {
    if (minutes < 60) {
      return l10n.minutesShort(minutes);
    } else if (minutes == 60) {
      return l10n.hourOne;
    } else if (minutes == 90) {
      return l10n.hourOneHalf;
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return l10n.hoursShort(hours);
      }
      return l10n.hoursMinutesShort(hours, mins);
    }
  }
}
