import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/theme/dark_theme.dart';
import 'package:clothes_inventory/core/theme/light_theme.dart';

abstract final class AppTheme {
  static ThemeData get light => buildLightTheme();
  static ThemeData get dark => buildDarkTheme();
}
