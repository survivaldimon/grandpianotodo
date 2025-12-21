import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Утилиты для работы с датами
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dayMonth = DateFormat('d MMMM', 'ru');
  static final DateFormat _dayMonthYear = DateFormat('d MMMM yyyy', 'ru');
  static final DateFormat _shortDate = DateFormat('dd.MM.yyyy', 'ru');
  static final DateFormat _time = DateFormat('HH:mm', 'ru');
  static final DateFormat _weekday = DateFormat('EEEE', 'ru');
  static final DateFormat _shortWeekday = DateFormat('EE', 'ru');

  /// Форматировать дату: "15 января"
  static String formatDayMonth(DateTime date) => _dayMonth.format(date);

  /// Форматировать дату: "15 января 2025"
  static String formatDayMonthYear(DateTime date) => _dayMonthYear.format(date);

  /// Форматировать дату: "15.01.2025"
  static String formatShortDate(DateTime date) => _shortDate.format(date);

  /// Форматировать время: "14:30"
  static String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Форматировать DateTime время: "14:30"
  static String formatDateTime(DateTime date) => _time.format(date);

  /// День недели: "понедельник"
  static String formatWeekday(DateTime date) => _weekday.format(date);

  /// Короткий день недели: "Пн"
  static String formatShortWeekday(DateTime date) => _shortWeekday.format(date);

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
