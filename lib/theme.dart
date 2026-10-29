import 'package:flutter/material.dart';

/// The app's custom surface colours, layered on top of [ColorScheme].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.codeBg,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color codeBg;

  static const dark = AppPalette(
    bg: Color(0xFF0B0E12),
    surface: Color(0xFF11151B),
    surfaceAlt: Color(0xFF171C24),
    border: Color(0xFF242B36),
    muted: Color(0xFF8A94A6),
    accent: Color(0xFF5FD6B4),
    accentSoft: Color(0x1F5FD6B4),
    codeBg: Color(0xFF0D1117),
  );

  static const light = AppPalette(
    bg: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F3F7),
    border: Color(0xFFE3E7EE),
    muted: Color(0xFF6B7484),
    accent: Color(0xFF0E9F86),
    accentSoft: Color(0x140E9F86),
    codeBg: Color(0xFFF4F6F9),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? muted,
    Color? accent,
    Color? accentSoft,
    Color? codeBg,
  }) => AppPalette(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    border: border ?? this.border,
    muted: muted ?? this.muted,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    codeBg: codeBg ?? this.codeBg,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      codeBg: Color.lerp(codeBg, other.codeBg, t)!,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}

class AppTheme {
  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    palette: AppPalette.dark,
    fg: const Color(0xFFE9EDF3),
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF5FD6B4),
      onPrimary: Color(0xFF04211A),
      primaryContainer: Color(0xFF123A32),
      onPrimaryContainer: Color(0xFFC9F7E9),
      secondary: Color(0xFF9BB4FF),
      onSecondary: Color(0xFF0B1530),
      error: Color(0xFFFF7B72),
      onError: Color(0xFF2A0A08),
      surface: Color(0xFF11151B),
      onSurface: Color(0xFFE9EDF3),
      outline: Color(0xFF2C3441),
      outlineVariant: Color(0xFF1D242E),
      surfaceContainerHighest: Color(0xFF1B2129),
    ),
  );

  static ThemeData light() => _build(
    brightness: Brightness.light,
    palette: AppPalette.light,
    fg: const Color(0xFF12171D),
    scheme: const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF0E9F86),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFD7F5EE),
      onPrimaryContainer: Color(0xFF04352C),
      secondary: Color(0xFF3D5AFE),
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFD93A32),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF12171D),
      outline: Color(0xFFD7DCE5),
      outlineVariant: Color(0xFFE8ECF2),
      surfaceContainerHighest: Color(0xFFF1F3F7),
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette palette,
    required Color fg,
    required ColorScheme scheme,
  }) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = base.textTheme
        .apply(bodyColor: fg, displayColor: fg)
        .copyWith(
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: fg,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: fg,
          ),
          titleSmall: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
          bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: fg),
          bodySmall: TextStyle(fontSize: 12.5, color: palette.muted),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: palette.muted,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.bg,
      canvasColor: palette.bg,
      textTheme: textTheme,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      iconTheme: IconThemeData(color: palette.muted, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: TextStyle(fontSize: 14.5, color: palette.muted),
        labelStyle: TextStyle(fontSize: 14, color: palette.muted),
        floatingLabelStyle: TextStyle(fontSize: 13, color: palette.accent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.accent, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.accent,
        inactiveTrackColor: palette.border,
        thumbColor: palette.accent,
        overlayColor: palette.accentSoft,
        trackHeight: 3,
        valueIndicatorColor: palette.surfaceAlt,
        valueIndicatorTextStyle: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.surfaceAlt,
        contentTextStyle: TextStyle(color: fg, fontSize: 13.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: palette.accentSoft,
        selectionHandleColor: palette.accent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
