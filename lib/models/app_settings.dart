import 'app_theme_choice.dart';

/// Everything the user can change in Settings.
class AppSettings {
  const AppSettings({
    this.baseUrl = defaultBaseUrl,
    this.model = '',
    this.apiKey = '',
    this.systemPrompt = '',
    this.temperature = 0.7,
    this.maxOutputTokens,
    this.topP,
    this.theme = AppThemeChoice.system,
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

  /// Optional output-token limit. Null leaves the server default in control.
  final int? maxOutputTokens;

  /// Optional nucleus-sampling probability (0.0–1.0).
  final double? topP;

  final AppThemeChoice theme;

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
    int? maxOutputTokens,
    bool clearMaxOutputTokens = false,
    double? topP,
    bool clearTopP = false,
    AppThemeChoice? theme,
  }) => AppSettings(
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    apiKey: apiKey ?? this.apiKey,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    temperature: temperature ?? this.temperature,
    maxOutputTokens: clearMaxOutputTokens
        ? null
        : maxOutputTokens ?? this.maxOutputTokens,
    topP: clearTopP ? null : topP ?? this.topP,
    theme: theme ?? this.theme,
  );

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'model': model,
    'systemPrompt': systemPrompt,
    'temperature': temperature,
    'maxOutputTokens': maxOutputTokens,
    'topP': topP,
    'theme': theme.name,
  };

  static int? _readMaxOutputTokens(Object? value) {
    if (value is! num || value is double && value % 1 != 0) return null;
    final tokens = value.toInt();
    return tokens >= 1 && tokens <= 32768 ? tokens : null;
  }

  static double? _readTopP(Object? value) {
    if (value is! num) return null;
    final topP = value.toDouble();
    return topP >= 0 && topP <= 1 ? topP : null;
  }

  static AppSettings fromJson(Map<String, dynamic> json) => AppSettings(
    baseUrl: json['baseUrl'] as String? ?? defaultBaseUrl,
    model: json['model'] as String? ?? '',
    systemPrompt: json['systemPrompt'] as String? ?? '',
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
    maxOutputTokens: _readMaxOutputTokens(json['maxOutputTokens']),
    topP: _readTopP(json['topP']),
    theme: json['theme'] != null
        ? AppThemeChoice.fromName(json['theme'])
        : AppThemeChoice.fromLegacyThemeMode(json['themeMode']),
  );
}
