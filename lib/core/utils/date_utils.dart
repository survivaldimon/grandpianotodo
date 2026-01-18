import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Кэш форматтеров по локали
class _DateFormatters {
  final DateFormat dayMonth;
  final DateFormat dayMonthYear;
  final DateFormat shortDate;
  final DateFormat time;
  final DateFormat weekday;
  final DateFormat shortWeekday;

  _DateFormatters(String locale)
      : dayMonth = DateFormat('d MMMM', locale),
        dayMonthYear = DateFormat('d MMMM yyyy', locale),
        shortDate = DateFormat('dd.MM.yyyy', locale),
        time = DateFormat('HH:mm', locale),
        weekday = DateFormat('EEEE', locale),
        shortWeekday = DateFormat('EE', locale);
}

/// Утилиты для работы с датами
class AppDateUtils {
  AppDateUtils._();

  /// Кэш форматтеров по локали
  static final Map<String, _DateFormatters> _formattersCache = {};

  /// Дефолтная локаль (для обратной совместимости)
  static const String _defaultLocale = 'ru';

  static _DateFormatters _getFormatters(String locale) {
    return _formattersCache.putIfAbsent(
      locale,
      () => _DateFormatters(locale),
    );
  }

  /// Форматировать дату: "15 января" / "January 15"
  static String formatDayMonth(DateTime date, [String locale = _defaultLocale]) =>
      _getFormatters(locale).dayMonth.format(date);

  /// Форматировать дату: "15 января 2025" / "January 15, 2025"
  static String formatDayMonthYear(DateTime date, [String locale = _defaultLocale]) =>
      _getFormatters(locale).dayMonthYear.format(date);

  /// Форматировать дату: "15.01.2025"
  static String formatShortDate(DateTime date, [String locale = _defaultLocale]) =>
      _getFormatters(locale).shortDate.format(date);

  /// Форматировать время: "14:30"
  static String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Форматировать DateTime время: "14:30"
  static String formatDateTime(DateTime date, [String locale = _defaultLocale]) =>
      _getFormatters(locale).time.format(date);

  /// День недели: "понедельник" / "Monday"
  static String formatWeekday(DateTime date, [String locale = _defaultLocale]) =>
      _getFormatters(locale).weekday.format(date);

  /// Короткий день недели: "Пн" / "Mon"
  static String formatShortWeekday(DateTime date, [String locale = _defaultLocale]) =>
      _getFormatters(locale).shortWeekday.format(date);

  /// Получить начало дня
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Получить конец дня
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  /// Получить начало недели (понедельник)
  static DateTime startOfWeek(DateTime date) {
    final diff = date.weekday - 1;
    return startOfDay(date.subtract(Duration(days: diff)));
  }

  /// Получить конец недели (воскресенье)
  static DateTime endOfWeek(DateTime date) {
    final diff = 7 - date.weekday;
    return endOfDay(date.add(Duration(days: diff)));
  }

  /// Получить начало месяца
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Получить конец месяца
  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59);
  }

  /// Проверить, что две даты — один и тот же день
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Проверить, что дата — сегодня
  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  /// TimeOfDay в минуты от начала дня
  static int timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  /// Минуты от начала дня в TimeOfDay
  static TimeOfDay minutesToTime(int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  /// Парсинг времени из строки "HH:mm"
  static TimeOfDay parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}
