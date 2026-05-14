import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

String trIfExists(String key, {BuildContext? context}) {
  if (key.trim().isEmpty) {
    return key;
  }
  try {
    if (key.trExists(context: context)) {
      return key.tr(context: context);
    }
  } catch (_) {
    return key;
  }
  return key;
}
