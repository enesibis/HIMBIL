import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// `AppLocalizations.of(context)` tekrarını kısaltan yardımcı:
/// `context.l10n.gameSlamButton` gibi kullanılır.
extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
