import 'package:flutter/material.dart';

import '../tokens/drivon_colors.dart';
import '../tokens/drivon_palette.dart';
import '../tokens/drivon_radii.dart';
import '../tokens/drivon_spacing.dart';
import '../tokens/drivon_typography.dart';

/// Builds Drivon's [ThemeData]. Dark is the primary theme; tokens are kept
/// semantic so a light theme can be added as a second builder later.
abstract final class DrivonTheme {
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: DrivonPalette.violet,
    onPrimary: Colors.white,
    primaryContainer: DrivonPalette.violetDeep,
    onPrimaryContainer: DrivonPalette.violetPale,
    secondary: DrivonPalette.mint,
    onSecondary: DrivonPalette.onLight,
    secondaryContainer: DrivonPalette.mintDeep,
    onSecondaryContainer: DrivonPalette.mintPale,
    tertiary: DrivonPalette.lavender,
    onTertiary: DrivonPalette.onLight,
    error: DrivonPalette.coral,
    onError: DrivonPalette.onLight,
    errorContainer: DrivonPalette.coralDeep,
    onErrorContainer: DrivonPalette.lavender,
    surface: DrivonPalette.ink900,
    onSurface: DrivonPalette.ink50,
    onSurfaceVariant: DrivonPalette.ink300,
    surfaceContainerLowest: DrivonPalette.ink950,
    surfaceContainerLow: DrivonPalette.ink850,
    surfaceContainer: DrivonPalette.ink800,
    surfaceContainerHigh: DrivonPalette.ink750,
    surfaceContainerHighest: DrivonPalette.ink700,
    outline: DrivonPalette.ink450,
    outlineVariant: DrivonPalette.ink750,
    inverseSurface: DrivonPalette.ink50,
    onInverseSurface: DrivonPalette.ink900,
    inversePrimary: DrivonPalette.violet,
    shadow: Colors.black,
    scrim: Colors.black,
    // Surfaces carry their own tone; no Material 3 tint overlay.
    surfaceTint: Colors.transparent,
  );

  /// Material roles for content placed directly on the light paper sheet.
  static const ColorScheme paperColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: DrivonPalette.violet,
    onPrimary: Colors.white,
    primaryContainer: DrivonPalette.violetPale,
    onPrimaryContainer: DrivonPalette.violetDeep,
    secondary: DrivonPalette.mint,
    onSecondary: DrivonPalette.onLight,
    secondaryContainer: DrivonPalette.mintPale,
    onSecondaryContainer: DrivonPalette.onLight,
    tertiary: DrivonPalette.lavender,
    onTertiary: DrivonPalette.onLight,
    error: DrivonPalette.coralInk,
    onError: Colors.white,
    errorContainer: DrivonPalette.lavender,
    onErrorContainer: DrivonPalette.onLight,
    surface: DrivonPalette.paper,
    onSurface: DrivonPalette.onLight,
    onSurfaceVariant: DrivonPalette.paperText2,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: DrivonPalette.paper,
    surfaceContainer: DrivonPalette.paper200,
    surfaceContainerHigh: DrivonPalette.paper200,
    surfaceContainerHighest: DrivonPalette.paper300,
    outline: DrivonPalette.paper600,
    outlineVariant: DrivonPalette.paper300,
    inverseSurface: DrivonPalette.ink850,
    onInverseSurface: DrivonPalette.ink50,
    inversePrimary: DrivonPalette.violetLight,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  /// The app theme: dark, Drivon's primary theme.
  static ThemeData dark() => _build(darkColorScheme, DrivonColors.dark);

  /// Theme for content placed directly on the light paper sheet. Built once,
  /// because every sheet applies it to its subtree.
  static ThemeData paper() => _paper;
  static final ThemeData _paper = _build(
    paperColorScheme,
    DrivonColors.paper,
  );

  static ThemeData _build(ColorScheme scheme, DrivonColors colors) {
    final textTheme = DrivonTypography.textTheme(
      primary: colors.textPrimary,
      secondary: colors.textSecondary,
    );
    const stadium = StadiumBorder();
    const buttonSize = Size(64, DrivonSpacing.minTouchTarget + 4);
    const buttonPadding = EdgeInsets.symmetric(horizontal: DrivonSpacing.xxl);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: DrivonTypography.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [colors],
      focusColor: scheme.primary.withValues(alpha: 0.24),
      splashFactory: InkSparkle.splashFactory,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accentText,
        selectionColor: scheme.primary.withValues(alpha: 0.4),
        selectionHandleColor: colors.accentText,
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: DrivonRadii.lgAll),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHigh,
          disabledForegroundColor: colors.textTertiary,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: stadium,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: stadium,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentText,
          minimumSize: const Size(
            DrivonSpacing.minTouchTarget,
            DrivonSpacing.minTouchTarget,
          ),
          shape: stadium,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size.square(DrivonSpacing.minTouchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DrivonSpacing.lg,
          vertical: DrivonSpacing.lg,
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
        hintStyle: textTheme.bodyLarge?.copyWith(color: colors.textTertiary),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: colors.danger),
        border: _inputBorder(scheme.outline),
        enabledBorder: _inputBorder(scheme.outline),
        focusedBorder: _inputBorder(colors.accentText, width: 2),
        errorBorder: _inputBorder(colors.danger),
        focusedErrorBorder: _inputBorder(colors.danger, width: 2),
        disabledBorder: _inputBorder(scheme.outlineVariant),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: colors.selectedFill,
        checkmarkColor: colors.onSelectedFill,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.onSelectedFill
                : colors.textPrimary,
          ),
        ),
        side: BorderSide.none,
        shape: stadium,
        padding: const EdgeInsets.symmetric(horizontal: DrivonSpacing.sm),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surfaceContainer,
          foregroundColor: colors.textSecondary,
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.outline),
          minimumSize: const Size(0, DrivonSpacing.minTouchTarget),
          textStyle: textTheme.labelLarge,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        minVerticalPadding: DrivonSpacing.md,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DrivonSpacing.lg,
        ),
        shape: const RoundedRectangleBorder(borderRadius: DrivonRadii.mdAll),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textPrimary,
        ),
        actionTextColor: colors.accentText,
        shape: const RoundedRectangleBorder(borderRadius: DrivonRadii.mdAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accentText,
        circularTrackColor: colors.gaugeTrack,
        linearTrackColor: colors.gaugeTrack,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DrivonRadii.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(borderRadius: DrivonRadii.xlAll),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.textPrimary
                : colors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : colors.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: colors.textSecondary),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colors.textPrimary,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colors.textSecondary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: DrivonRadii.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
