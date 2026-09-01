import 'package:flutter/widgets.dart';

/// Lightweight bilingual helper for screens that have not yet been migrated
/// to generated AppLocalizations keys.
String appText(
  BuildContext context, {
  required String km,
  required String en,
}) {
  return Localizations.localeOf(context).languageCode == 'en' ? en : km;
}
