import 'package:flutter/material.dart';

/// Размеры и отступы
class AppSizes {
  AppSizes._();

  // Padding
  static const double paddingXS = 4;
  static const double paddingS = 8;
  static const double paddingM = 16;
  static const double paddingL = 24;
  static const double paddingXL = 32;

  // Border radius
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXL = 24;

  // Icon sizes
  static const double iconS = 16;
  static const double iconM = 24;
  static const double iconL = 32;
  static const double iconXL = 48;

  // Button heights
  static const double buttonHeight = 52;
  static const double buttonHeightSmall = 40;

  // Card
  static const double cardElevation = 0;

  // Lesson block
  static const double lessonBlockMinHeight = 48;
  static const double timeGridWidth = 50;

  // Common EdgeInsets
  static const EdgeInsets paddingAllM = EdgeInsets.all(paddingM);
  static const EdgeInsets paddingAllL = EdgeInsets.all(paddingL);
  static const EdgeInsets paddingHorizontalM = EdgeInsets.symmetric(horizontal: paddingM);
  static const EdgeInsets paddingHorizontalL = EdgeInsets.symmetric(horizontal: paddingL);
  static const EdgeInsets paddingVerticalM = EdgeInsets.symmetric(vertical: paddingM);
  static const EdgeInsets paddingVerticalL = EdgeInsets.symmetric(vertical: paddingL);
}
