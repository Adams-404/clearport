import 'package:flutter_test/flutter_test.dart';
import 'package:clearport/models/app_settings.dart';

void main() {
  group('generation settings', () {
    test('round-trips optional generation controls', () {
      const settings = AppSettings(maxOutputTokens: 2048, topP: 0.85);
      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.maxOutputTokens, 2048);
      expect(restored.topP, 0.85);
    });

    test('keeps optional controls unset by default', () {
      const settings = AppSettings();
      expect(settings.maxOutputTokens, isNull);
      expect(settings.topP, isNull);
      expect(settings.toJson(), isNot(contains('maxOutputTokens')));
    });

    test('ignores invalid persisted generation values', () {
      final restored = AppSettings.fromJson({
        'maxOutputTokens': 0,
        'topP': 1.5,
      });

      expect(restored.maxOutputTokens, isNull);
      expect(restored.topP, isNull);
    });

    test('supports clearing optional controls with copyWith', () {
      const settings = AppSettings(maxOutputTokens: 512, topP: 0.9);
      final cleared = settings.copyWith(
        clearMaxOutputTokens: true,
        clearTopP: true,
      );

      expect(cleared.maxOutputTokens, isNull);
      expect(cleared.topP, isNull);
    });
  });
}
