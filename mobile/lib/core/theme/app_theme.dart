import 'package:flutter/material.dart';

import 'design_tokens.dart';

final class AppTheme {
  static ThemeData light({String? fontFamily}) =>
      _theme(Brightness.light, fontFamily: fontFamily);
  static ThemeData dark({String? fontFamily}) =>
      _theme(Brightness.dark, fontFamily: fontFamily);

  static ThemeData _theme(Brightness brightness, {String? fontFamily}) {
    fontFamily ??= 'Roboto';
    final bool dark = brightness == Brightness.dark;
    final ColorScheme scheme = dark ? _darkScheme : _lightScheme;
    final AppSemanticColors semantic = dark
        ? AppSemanticColors.dark
        : AppSemanticColors.light;
    final BorderRadius cardRadius = BorderRadius.circular(AppRadii.card);
    final BorderRadius buttonRadius = BorderRadius.circular(AppRadii.button);
    final BorderRadius inputRadius = BorderRadius.circular(AppRadii.input);
    final Color selectedGreen = dark
        ? scheme.primary
        : AppColorTokens.lightPrimaryDark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      textTheme: TextTheme(
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13.76,
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
        labelSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          color: scheme.onSurfaceVariant,
        ),
      ),
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[semantic],
      scaffoldBackgroundColor: semantic.background,
      canvasColor: semantic.background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0.5,
        shadowColor: scheme.shadow.withValues(alpha: dark ? 0.28 : 0.08),
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: selectedGreen,
          foregroundColor: dark ? scheme.onPrimary : Colors.white,
          disabledBackgroundColor: semantic.disabled.withValues(alpha: 0.5),
          minimumSize: const Size(
            AppDimensions.minimumTouchTarget,
            AppDimensions.minimumTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            AppDimensions.minimumTouchTarget,
            AppDimensions.minimumTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
          side: BorderSide(color: scheme.outline),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppDimensions.minimumTouchTarget,
            AppDimensions.minimumTouchTarget,
          ),
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppDimensions.minimumTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? selectedGreen : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            color: selected ? selectedGreen : scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: selectedGreen),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: selectedGreen,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurfaceVariant,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outline),
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? AppColorTokens.darkSurfaceVariant
            : AppColorTokens.lightTextPrimary,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: dark ? AppColorTokens.darkTextPrimary : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: inputRadius),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        minTileHeight: AppDimensions.minimumTouchTarget,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13.76,
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primaryContainer,
        selectionHandleColor: scheme.primary,
      ),
      focusColor: scheme.primary.withValues(alpha: 0.16),
      visualDensity: VisualDensity.standard,
    );
  }

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColorTokens.lightPrimary,
    onPrimary: Colors.white,
    primaryContainer: AppColorTokens.lightPrimaryContainer,
    onPrimaryContainer: AppColorTokens.lightPrimaryDark,
    primaryFixed: AppColorTokens.lightPrimaryContainer,
    primaryFixedDim: Color(0xFFC7EED8),
    onPrimaryFixed: Color(0xFF002112),
    onPrimaryFixedVariant: AppColorTokens.lightPrimaryDark,
    secondary: AppColorTokens.lightPrimaryDark,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD7EEE0),
    onSecondaryContainer: Color(0xFF173B28),
    tertiary: AppColorTokens.lightInformation,
    onTertiary: Colors.white,
    tertiaryContainer: AppColorTokens.lightInformationContainer,
    onTertiaryContainer: Color(0xFF0B315F),
    error: AppColorTokens.lightError,
    onError: Colors.white,
    errorContainer: AppColorTokens.lightErrorContainer,
    onErrorContainer: Color(0xFF410002),
    surface: AppColorTokens.lightSurface,
    onSurface: AppColorTokens.lightTextPrimary,
    surfaceDim: Color(0xFFE0E6E1),
    surfaceBright: AppColorTokens.lightSurface,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: AppColorTokens.lightBackground,
    surfaceContainer: AppColorTokens.lightSurfaceVariant,
    surfaceContainerHigh: Color(0xFFE8F0EA),
    surfaceContainerHighest: AppColorTokens.lightSurfaceVariant,
    onSurfaceVariant: AppColorTokens.lightTextSecondary,
    outline: AppColorTokens.lightOutline,
    outlineVariant: Color(0xFFE7EFE9),
    shadow: Color(0xFF15251B),
    scrim: Color(0xFF000000),
    inverseSurface: AppColorTokens.lightTextPrimary,
    onInverseSurface: Color(0xFFF0F6F1),
    inversePrimary: Color(0xFF58DE94),
    surfaceTint: AppColorTokens.lightPrimary,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColorTokens.darkPrimary,
    onPrimary: Color(0xFF00391F),
    primaryContainer: AppColorTokens.darkPrimaryContainer,
    onPrimaryContainer: Color(0xFFB7F3D0),
    primaryFixed: Color(0xFFB7F3D0),
    primaryFixedDim: Color(0xFF82DFA9),
    onPrimaryFixed: Color(0xFF002111),
    onPrimaryFixedVariant: Color(0xFF00522E),
    secondary: Color(0xFF9DD5B4),
    onSecondary: Color(0xFF063921),
    secondaryContainer: Color(0xFF214D35),
    onSecondaryContainer: Color(0xFFB9F2D0),
    tertiary: AppColorTokens.darkInformation,
    onTertiary: Color(0xFF06305F),
    tertiaryContainer: AppColorTokens.darkInformationContainer,
    onTertiaryContainer: Color(0xFFD8E6FF),
    error: AppColorTokens.darkError,
    onError: Color(0xFF690005),
    errorContainer: AppColorTokens.darkErrorContainer,
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColorTokens.darkSurface,
    onSurface: AppColorTokens.darkTextPrimary,
    surfaceDim: AppColorTokens.darkBackground,
    surfaceBright: Color(0xFF2D3D33),
    surfaceContainerLowest: Color(0xFF06100B),
    surfaceContainerLow: AppColorTokens.darkSurface,
    surfaceContainer: AppColorTokens.darkSurfaceVariant,
    surfaceContainerHigh: Color(0xFF20362A),
    surfaceContainerHighest: Color(0xFF263B2F),
    onSurfaceVariant: AppColorTokens.darkTextSecondary,
    outline: AppColorTokens.darkOutline,
    outlineVariant: Color(0xFF21372A),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColorTokens.darkTextPrimary,
    onInverseSurface: Color(0xFF24352B),
    inversePrimary: AppColorTokens.lightPrimary,
    surfaceTint: AppColorTokens.darkPrimary,
  );
}
