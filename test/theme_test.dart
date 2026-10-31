import 'package:clearport/models/app_settings.dart';
import 'package:clearport/models/app_theme_choice.dart';
import 'package:clearport/services/chat_api.dart';
import 'package:clearport/theme.dart';
import 'package:clearport/widgets/empty_state.dart';
import 'package:clearport/widgets/theme_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every theme choice round-trips through settings JSON', () {
    for (final choice in AppThemeChoice.values) {
      final json = AppSettings(theme: choice).toJson();
      expect(json['theme'], choice.name);
      expect(AppSettings.fromJson(json).theme, choice);
    }
  });

  test('the legacy themeMode key still selects a theme', () {
    expect(
      AppSettings.fromJson({'themeMode': 'dark'}).theme,
      AppThemeChoice.dark,
    );
    expect(
      AppSettings.fromJson({'themeMode': 'light'}).theme,
      AppThemeChoice.light,
    );
    expect(
      AppSettings.fromJson({'themeMode': 'system'}).theme,
      AppThemeChoice.system,
    );
  });

  test('a new theme key wins over the legacy one', () {
    expect(
      AppSettings.fromJson({'theme': 'halloween', 'themeMode': 'light'}).theme,
      AppThemeChoice.halloween,
    );
  });

  test('an unknown theme name falls back to system', () {
    expect(
      AppSettings.fromJson({'theme': 'valentines'}).theme,
      AppThemeChoice.system,
    );
  });

  test('every theme exposes a palette matching its brightness', () {
    for (final choice in AppThemeChoice.values) {
      final theme = AppTheme.forChoice(
        choice,
        platformBrightness: Brightness.dark,
      );
      final palette = theme.extension<AppPalette>();
      expect(palette, isNotNull, reason: choice.name);
      if (choice != AppThemeChoice.system) {
        expect(theme.brightness, choice.brightness, reason: choice.name);
      }
    }
  });

  test('system follows the platform brightness', () {
    expect(
      AppTheme.forChoice(
        AppThemeChoice.system,
        platformBrightness: Brightness.light,
      ).brightness,
      Brightness.light,
    );
    expect(
      AppTheme.forChoice(
        AppThemeChoice.system,
        platformBrightness: Brightness.dark,
      ).brightness,
      Brightness.dark,
    );
  });

  test('haunted is pure black and carries the spider mark', () {
    final palette = AppPalette.forChoice(AppThemeChoice.halloween);
    expect(palette.bg, const Color(0xFF000000));
    expect(palette.spooky, isTrue);
    expect(palette.mark, ThemeMarkKind.pumpkin);
  });

  test('amoled is pure black without seasonal decoration', () {
    final palette = AppPalette.forChoice(AppThemeChoice.amoled);
    expect(palette.bg, const Color(0xFF000000));
    expect(palette.spooky, isFalse);
    expect(palette.mark, ThemeMarkKind.terminal);
  });

  testWidgets('haunted empty state paints webs and speaks spooky', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.halloween(),
        home: Scaffold(
          body: EmptyState(
            status: const ServerStatus(health: ServerHealth.offline),
            baseUrl: 'http://127.0.0.1:8080/v1',
            model: '',
            onRefresh: () {},
            onSuggestion: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Something is listening on 127.0.0.1.'), findsOneWidget);
    expect(find.byType(ThemeMark), findsOneWidget);

    final webPainters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<SpiderWebPainter>();
    expect(webPainters, isNotEmpty);
  });

  testWidgets('a non-haunted empty state stays quiet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: EmptyState(
            status: const ServerStatus(health: ServerHealth.offline),
            baseUrl: 'http://127.0.0.1:8080/v1',
            model: '',
            onRefresh: () {},
            onSuggestion: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('A quiet chat with your local models.'), findsOneWidget);
    final webPainters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<SpiderWebPainter>();
    expect(webPainters, isEmpty);
  });
}
