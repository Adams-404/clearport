import 'package:flutter/material.dart';

/// Everything the user can change in Settings.
class AppSettings {
  const AppSettings({
    this.baseUrl = defaultBaseUrl,
    this.model = '',
    this.apiKey = '',
    this.systemPrompt = '',
    this.temperature = 0.7,
    this.themeMode = ThemeMode.system,
  });

  static const defaultBaseUrl = 'http://127.0.0.1:8080/v1';

  /// OpenAI-compatible base URL, e.g. `http://127.0.0.1:8080/v1`.
  final String baseUrl;

  /// Optional model id. Empty means "let the server decide".
  final String model;

  /// Optional bearer token for servers that ask for one.
  final String apiKey;

  /// Prepended as a system message when non-empty.
  final String systemPrompt;

  final double temperature;
  final ThemeMode themeMode;

  /// Trims trailing slashes and accepts a full chat-completions URL pasted
  /// from the server docs, so users don't have to know the exact shape.
  static String normalizeBaseUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return defaultBaseUrl;
    if (!value.contains('://')) value = 'http://$value';
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    const suffixes = ['/chat/completions', '/completions', '/models'];
    for (final suffix in suffixes) {
      if (value.endsWith(suffix)) {
        value = value.substring(0, value.length - suffix.length);
        break;
      }
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  AppSettings copyWith({
    String? baseUrl,
    String? model,
    String? apiKey,
    String? systemPrompt,
    double? temperature,
    ThemeMode? themeMode,
  }) => AppSettings(
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    apiKey: apiKey ?? this.apiKey,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    temperature: temperature ?? this.temperature,
    themeMode: themeMode ?? this.themeMode,
  );

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'model': model,
    'apiKey': apiKey,
    'systemPrompt': systemPrompt,
    'temperature': temperature,
    'themeMode': themeMode.name,
  };

  static AppSettings fromJson(Map<String, dynamic> json) => AppSettings(
    baseUrl: json['baseUrl'] as String? ?? defaultBaseUrl,
    model: json['model'] as String? ?? '',
    apiKey: json['apiKey'] as String? ?? '',
    systemPrompt: json['systemPrompt'] as String? ?? '',
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
    themeMode: ThemeMode.values.firstWhere(
      (mode) => mode.name == json['themeMode'],
      orElse: () => ThemeMode.system,
    ),
  );
}
