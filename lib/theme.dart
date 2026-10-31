import 'package:flutter/material.dart';

import 'models/app_theme_choice.dart';

/// The glyph shown in the empty state, per theme.
enum ThemeMarkKind { terminal, pumpkin, snowflake, marigold }

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
    required this.secondary,
    required this.codeBg,
    this.mark = ThemeMarkKind.terminal,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color secondary;
  final Color codeBg;

  /// Which seasonal mark the empty state draws. [ThemeMarkKind.pumpkin] also
  /// turns on the spider webs.
  final ThemeMarkKind mark;

  bool get spooky => mark == ThemeMarkKind.pumpkin;

  static const dark = AppPalette(
    bg: Color(0xFF0B0E12),
    surface: Color(0xFF11151B),
    surfaceAlt: Color(0xFF171C24),
    border: Color(0xFF242B36),
    muted: Color(0xFF8A94A6),
    accent: Color(0xFF5FD6B4),
    accentSoft: Color(0x1F5FD6B4),
    secondary: Color(0xFF9BB4FF),
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
    secondary: Color(0xFF3D5AFE),
    codeBg: Color(0xFFF4F6F9),
  );

  /// True black. On an OLED panel every pixel that is off costs nothing, so
  /// surfaces stay black and separation comes from hairlines, not elevation.
  static const amoled = AppPalette(
    bg: Color(0xFF000000),
    surface: Color(0xFF000000),
    surfaceAlt: Color(0xFF0C0C0E),
    border: Color(0xFF1E1E22),
    muted: Color(0xFF8B8B94),
    accent: Color(0xFF7CE0C3),
    accentSoft: Color(0x1A7CE0C3),
    secondary: Color(0xFFA9C1FF),
    codeBg: Color(0xFF08080A),
  );

  /// Haunted: pure black ground, pumpkin light, one spider on the web.
  static const halloween = AppPalette(
    bg: Color(0xFF000000),
    surface: Color(0xFF07060A),
    surfaceAlt: Color(0xFF100D16),
    border: Color(0xFF221C2C),
    muted: Color(0xFF8E879B),
    accent: Color(0xFFFF7A18),
    accentSoft: Color(0x1FFF7A18),
    secondary: Color(0xFFB07CFF),
    codeBg: Color(0xFF08060C),
    mark: ThemeMarkKind.pumpkin,
  );

  static const christmas = AppPalette(
    bg: Color(0xFF070D14),
    surface: Color(0xFF0D1724),
    surfaceAlt: Color(0xFF132234),
    border: Color(0xFF1E344D),
    muted: Color(0xFF7F9DBE),
    accent: Color(0xFF6AE4FF),
    accentSoft: Color(0x1F6AE4FF),
    secondary: Color(0xFFA6D0FF),
    codeBg: Color(0xFF09111A),
    mark: ThemeMarkKind.snowflake,
  );

  static const ofrenda = AppPalette(
    bg: Color(0xFF12060F),
    surface: Color(0xFF1C0B17),
    surfaceAlt: Color(0xFF261022),
    border: Color(0xFF3A1B32),
    muted: Color(0xFFB79AA8),
    accent: Color(0xFFFFB020),
    accentSoft: Color(0x1FFFB020),
    secondary: Color(0xFFE0559A),
    codeBg: Color(0xFF16080F),
    mark: ThemeMarkKind.marigold,
  );

  static AppPalette forChoice(AppThemeChoice choice) => switch (choice) {
    AppThemeChoice.system => dark,
    AppThemeChoice.light => light,
    AppThemeChoice.dark => dark,
    AppThemeChoice.amoled => amoled,
    AppThemeChoice.halloween => halloween,
    AppThemeChoice.christmas => christmas,
    AppThemeChoice.ofrenda => ofrenda,
  };

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? muted,
    Color? accent,
    Color? accentSoft,
    Color? secondary,
    Color? codeBg,
    ThemeMarkKind? mark,
  }) => AppPalette(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    border: border ?? this.border,
    muted: muted ?? this.muted,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    secondary: secondary ?? this.secondary,
    codeBg: codeBg ?? this.codeBg,
    mark: mark ?? this.mark,
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
      secondary: Color.lerp(secondary, other.secondary, t)!,
      codeBg: Color.lerp(codeBg, other.codeBg, t)!,
      mark: t < 0.5 ? mark : other.mark,
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

  static ThemeData amoled() => _build(
    brightness: Brightness.dark,
    palette: AppPalette.amoled,
    fg: const Color(0xFFEDEDF0),
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF7CE0C3),
      onPrimary: Color(0xFF00130E),
      primaryContainer: Color(0xFF0A2A22),
      onPrimaryContainer: Color(0xFFCFF7EB),
      secondary: Color(0xFFA9C1FF),
      onSecondary: Color(0xFF06122E),
      error: Color(0xFFFF7B72),
      onError: Color(0xFF2A0A08),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFEDEDF0),
      outline: Color(0xFF232327),
      outlineVariant: Color(0xFF141417),
      surfaceContainerHighest: Color(0xFF0C0C0E),
    ),
  );

  static ThemeData halloween() => _build(
    brightness: Brightness.dark,
    palette: AppPalette.halloween,
    fg: const Color(0xFFF4EFE7),
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFF7A18),
      onPrimary: Color(0xFF1A0A00),
      primaryContainer: Color(0xFF3A1A05),
      onPrimaryContainer: Color(0xFFFFD9BC),
      secondary: Color(0xFFB07CFF),
      onSecondary: Color(0xFF150029),
      error: Color(0xFFFF5C5C),
      onError: Color(0xFF2A0606),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFF4EFE7),
      outline: Color(0xFF2A2333),
      outlineVariant: Color(0xFF17121D),
      surfaceContainerHighest: Color(0xFF100D16),
    ),
  );

  static ThemeData christmas() => _build(
    brightness: Brightness.dark,
    palette: AppPalette.christmas,
    fg: const Color(0xFFEEF6FC),
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF6AE4FF),
      onPrimary: Color(0xFF00222B),
      primaryContainer: Color(0xFF083A48),
      onPrimaryContainer: Color(0xFFC7F3FF),
      secondary: Color(0xFFA6D0FF),
      onSecondary: Color(0xFF001E3C),
      error: Color(0xFFFF6B6B),
      onError: Color(0xFF2A0606),
      surface: Color(0xFF0D1724),
      onSurface: Color(0xFFEEF6FC),
      outline: Color(0xFF1E344D),
      outlineVariant: Color(0xFF132234),
      surfaceContainerHighest: Color(0xFF132234),
    ),
  );

  static ThemeData ofrenda() => _build(
    brightness: Brightness.dark,
    palette: AppPalette.ofrenda,
    fg: const Color(0xFFF6E9EF),
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFB020),
      onPrimary: Color(0xFF1A1000),
      primaryContainer: Color(0xFF3A2606),
      onPrimaryContainer: Color(0xFFFFE3AE),
      secondary: Color(0xFFE0559A),
      onSecondary: Color(0xFF24000F),
      error: Color(0xFFFF6B8B),
      onError: Color(0xFF2A0610),
      surface: Color(0xFF1C0B17),
      onSurface: Color(0xFFF6E9EF),
      outline: Color(0xFF43213A),
      outlineVariant: Color(0xFF2B1222),
      surfaceContainerHighest: Color(0xFF261022),
    ),
  );

  /// Resolves a choice to a theme. [platformBrightness] is only consulted for
  /// [AppThemeChoice.system].
  static ThemeData forChoice(
    AppThemeChoice choice, {
    Brightness platformBrightness = Brightness.dark,
  }) => switch (choice) {
    AppThemeChoice.system =>
      platformBrightness == Brightness.dark ? dark() : light(),
    AppThemeChoice.light => light(),
    AppThemeChoice.dark => dark(),
    AppThemeChoice.amoled => amoled(),
    AppThemeChoice.halloween => halloween(),
    AppThemeChoice.christmas => christmas(),
    AppThemeChoice.ofrenda => ofrenda(),
  };

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
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: palette.spooky
                ? palette.accent.withValues(alpha: 0.45)
                : palette.border,
            width: 1.2,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
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
