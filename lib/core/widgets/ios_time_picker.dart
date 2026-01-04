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
    final hours = List.generate(
      widget.maxHour - widget.minHour + 1,
      (i) => widget.minHour + i,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
                  const Text(
                    'Выберите время',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
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
            const Divider(height: 1),
            // Пикеры
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  // Часы
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _hourController,
                      itemExtent: 44,
                      looping: true,
                      selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                        capEndEdge: false,
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
                            style: const TextStyle(fontSize: 22),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Разделитель
                  const Text(
                    ':',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Минуты
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _minuteController,
                      itemExtent: 44,
                      looping: true,
                      selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                        capStartEdge: false,
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
                            style: const TextStyle(fontSize: 22),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
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
