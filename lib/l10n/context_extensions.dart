import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

/// Extension to add the l10n getter to BuildContext
/// This provides the same functionality as the deprecated flutter_gen approach
extension AppLocalizationsX on BuildContext {
  /// The l10n object which holds all the localized strings for this context
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}