import 'package:flutter/material.dart';

/// Every theme the app can render.
///
/// Persisted by [name], so adding a theme later never breaks an install that
/// already has an older settings file.
enum AppThemeChoice {
  system('System', 'Follow your phone', Brightness.light),
  light('Clean', 'Bright, quiet, mint', Brightness.light),
  dark('Dark', 'Deep navy, mint accent', Brightness.dark),
  amoled('AMOLED', 'True black, battery first', Brightness.dark),
  halloween('Haunted', 'Pure black, pumpkin, spiders', Brightness.dark),
  christmas('Midwinter', 'Pine, gold and holly', Brightness.dark),
  ofrenda('Ofrenda', 'Marigold and candlelight', Brightness.dark);

  const AppThemeChoice(this.label, this.description, this.brightness);

  final String label;
  final String description;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  static AppThemeChoice fromName(Object? name) => values.firstWhere(
    (choice) => choice.name == name,
    orElse: () => AppThemeChoice.system,
  );

  /// Reads the pre-multi-theme `themeMode` value (`system`/`light`/`dark`) so
  /// existing installs keep the look they had.
  static AppThemeChoice fromLegacyThemeMode(Object? name) => switch (name) {
    'light' => AppThemeChoice.light,
    'dark' => AppThemeChoice.dark,
    _ => AppThemeChoice.system,
  };
}
