import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/core/theme/app_colors.dart';

/// Предустановленные цвета для выбора
const List<String> kPresetColors = [
  '#4CAF50', // Green
  '#2196F3', // Blue
  '#FF9800', // Orange
  '#9C27B0', // Purple
  '#F44336', // Red
  '#00BCD4', // Cyan
  '#795548', // Brown
  '#607D8B', // Blue Grey
  '#E91E63', // Pink
  '#009688', // Teal
  '#3F51B5', // Indigo
  '#FFEB3B', // Yellow
];

/// Возвращает случайный цвет из пресетов
String getRandomPresetColor() {
  final random = Random();
  return kPresetColors[random.nextInt(kPresetColors.length)];
}

/// Конвертирует hex строку в Color
Color hexToColor(String hex) {
  final cleanHex = hex.replaceAll('#', '');
  return Color(int.parse('FF$cleanHex', radix: 16));
}

/// Конвертирует Color в hex строку (без #)
String colorToHex(Color color) {
  final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '$r$g$b'.toUpperCase();
}

/// Виджет выбора цвета с пресетами и кнопкой палитры
class ColorPickerField extends StatelessWidget {
  final String? selectedColor;
  final ValueChanged<String?> onColorChanged;
  final String? label;
  final bool showReset;

  const ColorPickerField({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
    this.label,
    this.showReset = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // Пресетные цвета
            ...kPresetColors.map((colorHex) {
              final color = hexToColor(colorHex);
              final isSelected = selectedColor?.toUpperCase().replaceAll('#', '') ==
                  colorHex.toUpperCase().replaceAll('#', '');

              return _ColorCircle(
                color: color,
                isSelected: isSelected,
                onTap: () => onColorChanged(colorHex),
              );
            }),
            // Кнопка палитры
            _PaletteButton(
              currentColor: selectedColor != null ? hexToColor(selectedColor!) : null,
              onColorSelected: (color) {
                onColorChanged('#${colorToHex(color)}');
              },
              onReset: showReset ? () => onColorChanged(null) : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// Круглая кнопка цвета
class _ColorCircle extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

/// Кнопка открытия полной палитры
class _PaletteButton extends StatelessWidget {
  final Color? currentColor;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback? onReset;

  const _PaletteButton({
    required this.currentColor,
    required this.onColorSelected,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullColorPicker(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.cyan,
              Colors.blue,
              Colors.purple,
              Colors.red,
            ],
          ),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.palette,
          color: Colors.white,
          size: 20,
          shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
        ),
      ),
    );
  }

  void _showFullColorPicker(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Color selectedColor = currentColor ?? Colors.blue;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.selectColor),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: selectedColor,
              onColorChanged: (color) => setState(() => selectedColor = color),
              enableAlpha: false,
              hexInputBar: true,
              labelTypes: const [],
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            if (onReset != null && currentColor != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onReset!();
                },
                child: Text(l10n.reset, style: const TextStyle(color: AppColors.warning)),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onColorSelected(selectedColor);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

/// Показывает диалог выбора цвета и возвращает выбранный цвет
Future<String?> showColorPickerDialog(
  BuildContext context, {
  String? currentColor,
  bool showReset = false,
}) async {
  final l10n = AppLocalizations.of(context);
  String? result;
  Color selectedColor = currentColor != null ? hexToColor(currentColor) : Colors.blue;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.selectColor),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Пресеты
              Text(
                l10n.quickSelect,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kPresetColors.map((colorHex) {
                  final color = hexToColor(colorHex);
                  final isSelected = colorToHex(selectedColor).toUpperCase() ==
                      colorHex.toUpperCase().replaceAll('#', '');

                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // Полная палитра
              Text(
                l10n.palette,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              ColorPicker(
                pickerColor: selectedColor,
                onColorChanged: (color) => setState(() => selectedColor = color),
                enableAlpha: false,
                hexInputBar: true,
                labelTypes: const [],
                pickerAreaHeightPercent: 0.7,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          if (showReset && currentColor != null)
            TextButton(
              onPressed: () {
                result = '';
                Navigator.pop(dialogContext);
              },
              child: Text(l10n.reset, style: const TextStyle(color: AppColors.warning)),
            ),
          ElevatedButton(
            onPressed: () {
              result = '#${colorToHex(selectedColor)}';
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    ),
  );

  return result;
}
