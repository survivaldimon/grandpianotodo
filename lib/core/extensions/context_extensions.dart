import 'package:flutter/widgets.dart';
import 'package:kabinet/l10n/app_localizations.dart';

/// Extension для удобного доступа к локализованным строкам
extension LocalizationExtension on BuildContext {
  /// Получить локализованные строки: context.l10n.someString
  AppLocalizations get l10n => AppLocalizations.of(this);
}
