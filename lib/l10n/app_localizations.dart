import 'package:flutter/widgets.dart';

/// Lightweight localization bridge used by screens already migrated from
/// Android V51 generated localization. It follows the app's active locale and
/// avoids requiring generated files at runtime while the remaining screens
/// continue to use GetX/appText localization.
class AppLocalizations {
  final String languageCode;
  const AppLocalizations._(this.languageCode);

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations._(Localizations.localeOf(context).languageCode);
  }

  bool get _en => languageCode == 'en';

  String get searchProducts => _en ? 'Search products...' : 'ស្វែងរកទំនិញ...';
}
