import 'package:flutter/widgets.dart';

String appText(
  BuildContext context, {
  required String km,
  required String en,
}) {
  return Localizations.localeOf(context).languageCode == 'en' ? en : km;
}
