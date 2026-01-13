import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS-стиль пикер времени с барабанами (CupertinoPicker)
/// Шаг минут настраивается (по умолчанию 5 минут)
class IosTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final int minuteInterval;
  final int minHour;
  final int maxHour;

  const IosTimePicker({
    super.key,
    required this.initialTime,
    this.minuteInterval = 5,
    this.minHour = 0,
    this.maxHour = 23,
  });

  @override
  State<IosTimePicker> createState() => _IosTimePickerState();
}

class _IosTimePickerState extends State<IosTimePicker> {
  late int _selectedHour;
  late int _selectedMinuteIndex;
  late List<int> _minutes;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour.clamp(widget.minHour, widget.maxHour);

    // Генерируем список минут с заданным шагом
    _minutes = List.generate(
      60 ~/ widget.minuteInterval,
      (i) => i * widget.minuteInterval,
    );

    // Находим ближайшее значение минут
    _selectedMinuteIndex = _findClosestMinuteIndex(widget.initialTime.minute);

    _hourController = FixedExtentScrollController(
      initialItem: _selectedHour - widget.minHour,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinuteIndex,
    );
  }

  int _findClosestMinuteIndex(int minute) {
    int closestIndex = 0;
    int minDiff = 60;
    for (int i = 0; i < _minutes.length; i++) {
      final diff = (minute - _minutes[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final hours = List.generate(
      widget.maxHour - widget.minHour + 1,
      (i) => widget.minHour + i,
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  Text(
                    'Выберите время',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final time = TimeOfDay(
                        hour: _selectedHour,
                        minute: _minutes[_selectedMinuteIndex],
                      );
                      Navigator.pop(context, time);
                    },
                    child: const Text(
                      'Готово',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            // Пикеры
            SizedBox(
              height: 220,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: isDark ? Brightness.dark : Brightness.light,
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(
                      fontSize: 22,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Часы
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _hourController,
                        itemExtent: 44,
                        looping: true,
                        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                          capEndEdge: false,
                          background: colorScheme.primary.withValues(alpha: 0.1),
                        ),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedHour = hours[index % hours.length];
                          });
                        },
                        children: hours.map((hour) {
                          return Center(
                            child: Text(
                              hour.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 22,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Разделитель
                    Text(
                      ':',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    // Минуты
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _minuteController,
                        itemExtent: 44,
                        looping: true,
                        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                          capStartEdge: false,
                          background: colorScheme.primary.withValues(alpha: 0.1),
                        ),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedMinuteIndex = index % _minutes.length;
                          });
                        },
                        children: _minutes.map((minute) {
                          return Center(
                            child: Text(
                              minute.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 22,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Показать iOS-стиль пикер времени
///
/// [context] - BuildContext
/// [initialTime] - начальное время
/// [minuteInterval] - шаг минут (по умолчанию 5)
/// [minHour] - минимальный час (по умолчанию 0)
/// [maxHour] - максимальный час (по умолчанию 23)
///
/// Возвращает выбранное время или null если отменено
Future<TimeOfDay?> showIosTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  int minuteInterval = 5,
  int minHour = 0,
  int maxHour = 23,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => IosTimePicker(
      initialTime: initialTime,
      minuteInterval: minuteInterval,
      minHour: minHour,
      maxHour: maxHour,
    ),
  );
}

// ============================================================================
// КОМБИНИРОВАННЫЙ ПИКЕР НАЧАЛА И КОНЦА ВРЕМЕНИ
// ============================================================================

/// Результат выбора диапазона времени
class TimeRange {
  final TimeOfDay start;
  final TimeOfDay end;

  const TimeRange({required this.start, required this.end});
}

/// iOS-стиль пикер для выбора диапазона времени (начало и конец)
class IosTimeRangePicker extends StatefulWidget {
  final TimeOfDay initialStartTime;
  final TimeOfDay initialEndTime;
  final int minuteInterval;
  final int minHour;
  final int maxHour;
  final int defaultDurationMinutes; // Длительность по умолчанию

  const IosTimeRangePicker({
    super.key,
    required this.initialStartTime,
    required this.initialEndTime,
    this.minuteInterval = 5,
    this.minHour = 0,
    this.maxHour = 23,
    this.defaultDurationMinutes = 60, // По умолчанию 1 час
  });

  @override
  State<IosTimeRangePicker> createState() => _IosTimeRangePickerState();
}

class _IosTimeRangePickerState extends State<IosTimeRangePicker> {
  late int _startHour;
  late int _startMinuteIndex;
  late int _endHour;
  late int _endMinuteIndex;
  late List<int> _minutes;

  late FixedExtentScrollController _startHourController;
  late FixedExtentScrollController _startMinuteController;
  late FixedExtentScrollController _endHourController;
  late FixedExtentScrollController _endMinuteController;

  @override
  void initState() {
    super.initState();

    // Генерируем список минут с заданным шагом
    _minutes = List.generate(
      60 ~/ widget.minuteInterval,
      (i) => i * widget.minuteInterval,
    );

    _startHour = widget.initialStartTime.hour.clamp(widget.minHour, widget.maxHour);
    _startMinuteIndex = _findClosestMinuteIndex(widget.initialStartTime.minute);

    _endHour = widget.initialEndTime.hour.clamp(widget.minHour, widget.maxHour);
    _endMinuteIndex = _findClosestMinuteIndex(widget.initialEndTime.minute);

    _startHourController = FixedExtentScrollController(
      initialItem: _startHour - widget.minHour,
    );
    _startMinuteController = FixedExtentScrollController(
      initialItem: _startMinuteIndex,
    );
    _endHourController = FixedExtentScrollController(
      initialItem: _endHour - widget.minHour,
    );
    _endMinuteController = FixedExtentScrollController(
      initialItem: _endMinuteIndex,
    );
  }

  /// Автоматически обновить время окончания на основе длительности
  void _autoUpdateEndTime() {
    final startMinutes = _startHour * 60 + _minutes[_startMinuteIndex];
    final endMinutes = startMinutes + widget.defaultDurationMinutes;

    final newEndHour = (endMinutes ~/ 60).clamp(widget.minHour, widget.maxHour);
    final newEndMinute = endMinutes % 60;
    final newEndMinuteIndex = _findClosestMinuteIndex(newEndMinute);

    if (newEndHour != _endHour || newEndMinuteIndex != _endMinuteIndex) {
      setState(() {
        _endHour = newEndHour;
        _endMinuteIndex = newEndMinuteIndex;
      });

      // Анимируем скролл к новому значению
      _endHourController.animateToItem(
        _endHour - widget.minHour,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      _endMinuteController.animateToItem(
        _endMinuteIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  int _findClosestMinuteIndex(int minute) {
    int closestIndex = 0;
    int minDiff = 60;
    for (int i = 0; i < _minutes.length; i++) {
      final diff = (minute - _minutes[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  @override
  void dispose() {
    _startHourController.dispose();
    _startMinuteController.dispose();
    _endHourController.dispose();
    _endMinuteController.dispose();
    super.dispose();
  }

  int get _durationMinutes {
    final startMinutes = _startHour * 60 + _minutes[_startMinuteIndex];
    final endMinutes = _endHour * 60 + _minutes[_endMinuteIndex];
    return endMinutes - startMinutes;
  }

  String get _durationText {
    final duration = _durationMinutes;
    if (duration <= 0) return 'Некорректно';
    final hours = duration ~/ 60;
    final mins = duration % 60;
    if (hours > 0 && mins > 0) return '$hours ч $mins мин';
    if (hours > 0) return '$hours ч';
    return '$mins мин';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final hours = List.generate(
      widget.maxHour - widget.minHour + 1,
      (i) => widget.minHour + i,
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  Column(
                    children: [
                      Text(
                        'Время занятия',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _durationText,
                        style: TextStyle(
                          fontSize: 13,
                          color: _durationMinutes > 0
                              ? colorScheme.primary
                              : colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _durationMinutes > 0
                        ? () {
                            final range = TimeRange(
                              start: TimeOfDay(
                                hour: _startHour,
                                minute: _minutes[_startMinuteIndex],
                              ),
                              end: TimeOfDay(
                                hour: _endHour,
                                minute: _minutes[_endMinuteIndex],
                              ),
                            );
                            Navigator.pop(context, range);
                          }
                        : null,
                    child: const Text(
                      'Готово',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),

            // Пикеры
            SizedBox(
              height: 200,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: isDark ? Brightness.dark : Brightness.light,
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(
                      fontSize: 20,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Начало
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Начало',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                // Часы начала
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: _startHourController,
                                    itemExtent: 36,
                                    looping: true,
                                    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                                      capEndEdge: false,
                                      background: colorScheme.primary.withValues(alpha: 0.1),
                                    ),
                                    onSelectedItemChanged: (index) {
                                      setState(() {
                                        _startHour = hours[index % hours.length];
                                      });
                                      _autoUpdateEndTime();
                                    },
                                    children: hours.map((hour) {
                                      return Center(
                                        child: Text(
                                          hour.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 20,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Text(
                                  ':',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                // Минуты начала
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: _startMinuteController,
                                    itemExtent: 36,
                                    looping: true,
                                    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                                      capStartEdge: false,
                                      background: colorScheme.primary.withValues(alpha: 0.1),
                                    ),
                                    onSelectedItemChanged: (index) {
                                      setState(() {
                                        _startMinuteIndex = index % _minutes.length;
                                      });
                                      _autoUpdateEndTime();
                                    },
                                    children: _minutes.map((minute) {
                                      return Center(
                                        child: Text(
                                          minute.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 20,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Разделитель
                    Container(
                      width: 1,
                      height: 120,
                      color: colorScheme.outlineVariant,
                    ),

                    // Конец
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Конец',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                // Часы конца
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: _endHourController,
                                    itemExtent: 36,
                                    looping: true,
                                    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                                      capEndEdge: false,
                                      background: colorScheme.primary.withValues(alpha: 0.1),
                                    ),
                                    onSelectedItemChanged: (index) {
                                      setState(() {
                                        _endHour = hours[index % hours.length];
                                      });
                                    },
                                    children: hours.map((hour) {
                                      return Center(
                                        child: Text(
                                          hour.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 20,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Text(
                                  ':',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                // Минуты конца
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: _endMinuteController,
                                    itemExtent: 36,
                                    looping: true,
                                    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                                      capStartEdge: false,
                                      background: colorScheme.primary.withValues(alpha: 0.1),
                                    ),
                                    onSelectedItemChanged: (index) {
                                      setState(() {
                                        _endMinuteIndex = index % _minutes.length;
                                      });
                                    },
                                    children: _minutes.map((minute) {
                                      return Center(
                                        child: Text(
                                          minute.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 20,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Показать iOS-стиль пикер диапазона времени
///
/// [defaultDurationMinutes] - длительность по умолчанию (автоподстановка конца при изменении начала)
Future<TimeRange?> showIosTimeRangePicker({
  required BuildContext context,
  required TimeOfDay initialStartTime,
  required TimeOfDay initialEndTime,
  int minuteInterval = 5,
  int minHour = 0,
  int maxHour = 23,
  int defaultDurationMinutes = 60,
}) {
  return showModalBottomSheet<TimeRange>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => IosTimeRangePicker(
      initialStartTime: initialStartTime,
      initialEndTime: initialEndTime,
      minuteInterval: minuteInterval,
      minHour: minHour,
      maxHour: maxHour,
      defaultDurationMinutes: defaultDurationMinutes,
    ),
  );
}
