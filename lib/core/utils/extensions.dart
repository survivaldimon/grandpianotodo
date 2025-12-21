import 'package:flutter/material.dart';

/// Расширение для String
extension StringExtension on String {
  /// Первая буква заглавная
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Преобразовать HEX цвет в Color
  Color? toColor() {
    try {
      final hex = replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Расширение для Color
extension ColorExtension on Color {
  /// Преобразовать Color в HEX строку
  String toHex({bool withHash = true}) {
    final hex = '${red.toRadixString(16).padLeft(2, '0')}'
        '${green.toRadixString(16).padLeft(2, '0')}'
        '${blue.toRadixString(16).padLeft(2, '0')}';
    return withHash ? '#$hex' : hex;
  }
}

/// Расширение для TimeOfDay
extension TimeOfDayExtension on TimeOfDay {
  /// Сравнение
  bool isBefore(TimeOfDay other) {
    return hour < other.hour || (hour == other.hour && minute < other.minute);
  }

  bool isAfter(TimeOfDay other) {
    return hour > other.hour || (hour == other.hour && minute > other.minute);
  }

  bool isAtSameMomentAs(TimeOfDay other) {
    return hour == other.hour && minute == other.minute;
  }

  /// Добавить минуты
  TimeOfDay addMinutes(int minutes) {
    final totalMinutes = hour * 60 + minute + minutes;
    return TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
  }

  /// Вычесть минуты
  TimeOfDay subtractMinutes(int minutes) => addMinutes(-minutes);

  /// Разница в минутах
  int differenceInMinutes(TimeOfDay other) {
    return (hour * 60 + minute) - (other.hour * 60 + other.minute);
  }

  /// Форматирование "HH:mm"
  String format24() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

/// Расширение для DateTime
extension DateTimeExtension on DateTime {
  /// Только дата (без времени)
  DateTime get dateOnly => DateTime(year, month, day);

  /// Начало дня
  DateTime get startOfDay => DateTime(year, month, day);

  /// Конец дня
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);

  /// Комбинировать дату с TimeOfDay
  DateTime withTime(TimeOfDay time) {
    return DateTime(year, month, day, time.hour, time.minute);
  }

  /// Получить TimeOfDay из DateTime
  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);
}

/// Расширение для List
extension ListExtension<T> on List<T> {
  /// Безопасный доступ по индексу
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }
}

/// Расширение для BuildContext
extension BuildContextExtension on BuildContext {
  /// Получить тему
  ThemeData get theme => Theme.of(this);

  /// Получить цветовую схему
  ColorScheme get colorScheme => theme.colorScheme;

  /// Получить текстовую тему
  TextTheme get textTheme => theme.textTheme;

  /// Получить MediaQuery
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Ширина экрана
  double get screenWidth => mediaQuery.size.width;

  /// Высота экрана
  double get screenHeight => mediaQuery.size.height;

  /// Показать SnackBar
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
      ),
    );
  }
}
