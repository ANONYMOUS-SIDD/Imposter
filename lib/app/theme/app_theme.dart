// app_theme.dart
//
// Material 3 theme definition for the Imposter app.
//
// The theme is built once per process and cached in [_dark]; [AppTheme.dark]
// returns that cached instance. Building the theme is relatively expensive
// because `ColorScheme.fromSeed` runs HCT tonal-palette generation, so the
// result must not be rebuilt from widget code — that would re-run the
// generation on every navigation.
//
// Text scaling is intentionally not handled here. Users' system font scale
// is clamped at the app root via `MediaQuery.withClampedTextScaling`, since
// [ThemeData] cannot influence it. See `main.dart`.
//
// Adding theme coverage: extend [_buildDark] rather than styling widgets
// locally, so every screen inherits the change. Do not rename or remove
// `AppTheme.dark` — call-sites across the app depend on it.

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Namespace for the app's theme definitions.
abstract final class AppTheme {
  /// Cached dark theme. Built once on first access, then reused.
  static final ThemeData _dark = _buildDark();

  /// Returns the app's dark [ThemeData].
  ///
  /// Safe and cheap to call from anywhere — returns the cached instance and
  /// never re-runs [ColorScheme.fromSeed] or font resolution.
  static ThemeData dark() => _dark;

  /// Constructs the [ThemeData] applied app-wide. Called exactly once by
  /// [_dark]; do not invoke from other code.
  static ThemeData _buildDark() {
    // `fromSeed` derives most color-scheme roles automatically. The explicit
    // `copyWith` pins the roles that would otherwise be desaturated or
    // hue-shifted away from the brand tokens — primarily button backgrounds,
    // error states, and icon-filled surfaces.
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryPurple,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ).copyWith(
      primary: AppColors.primaryPurple,
      onPrimary: AppColors.textBright,
      secondary: AppColors.neonPurple,
      onSecondary: AppColors.textBright,
      error: AppColors.imposterRed,
      onError: AppColors.textBright,
      surfaceContainerHighest: AppColors.secondarySurface,
      outline: AppColors.textSecondary,
    );

    // Apply Quicksand and the base text colors to the *entire* Material
    // text theme, then layer the app's explicit styles on top. Without the
    // base application, Material styles that the design system doesn't
    // override (labelLarge, titleSmall, …) would render in the default
    // font — a visible mismatch on every button in the app.
    final TextTheme baseText = ThemeData.dark().textTheme.apply(
      fontFamily: 'Quicksand',
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textBright,
    );
    final TextTheme textTheme = baseText.copyWith(
      displayLarge: AppTypography.display,
      headlineMedium: AppTypography.headline,
      titleMedium: AppTypography.title,
      bodyMedium: AppTypography.body,
      labelSmall: AppTypography.label,
      bodySmall: AppTypography.caption,
    );

    const BorderRadius inputRadius = BorderRadius.all(Radius.circular(16));
    const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(14));
    final BorderRadius cardRadius = BorderRadius.circular(20);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      fontFamily: 'Quicksand',
      textTheme: textTheme,

      /// Compact spacing on tablet and desktop; standard on phone.
      visualDensity: VisualDensity.adaptivePlatformDensity,

      /// InkRipple avoids the extra shader pass that M3's default
      /// InkSparkle introduces — smoother taps on mid-range Android.
      splashFactory: InkRipple.splashFactory,

      /// Applies a fast fade to Navigator routes not managed by go_router
      /// (modal sheets, programmatic pushes). Matches the go_router
      /// transition so navigation feels consistent regardless of which
      /// navigation API a screen uses.
      pageTransitionsTheme: _fastFadePageTransitionsTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.headline.copyWith(
          color: AppColors.textBright,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actionsIconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      /// Cards default to zero margin so callers own their spacing.
      /// The Material default is 4px on all sides, which produces
      /// unexpected overflow on tight phone layouts.
      cardTheme: CardThemeData(
        color: AppColors.secondarySurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondarySurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.neonPurple, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.imposterRed, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.crimson, width: 1.5),
        ),
        hintStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
        labelStyle: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
        ),
        errorStyle: AppTypography.caption.copyWith(color: AppColors.crimson),
      ),

      /// Primary action styling — used by "Start Game", "Continue",
      /// "Reveal Now", and other filled CTAs throughout the app.
      /// `minimumSize` rather than fixed size so the button can shrink
      /// when constrained, preventing overflow on small phones.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: AppColors.textBright,
          disabledBackgroundColor:
          AppColors.primaryPurple.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.textSecondary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: AppTypography.label,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.neonPurple,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: AppTypography.label,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: AppColors.textSecondary, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: AppTypography.label,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          /// 44dp is Material's minimum accessible touch-target size.
          minimumSize: const Size(44, 44),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.secondarySurface,
        contentTextStyle: AppTypography.body.copyWith(
          color: AppColors.textPrimary,
        ),
        actionTextColor: AppColors.neonPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 4,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: AppTypography.headline.copyWith(
          color: AppColors.textBright,
        ),
        contentTextStyle: AppTypography.body.copyWith(
          color: AppColors.textPrimary,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.secondarySurface,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.neonPurple,
        linearTrackColor: AppColors.secondarySurface,
        circularTrackColor: AppColors.secondarySurface,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.secondarySurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: AppTypography.caption.copyWith(color: AppColors.textPrimary),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    );
  }
}

/// Page-transition theme applied to every platform.
///
/// Ensures routes managed by Navigator (not go_router) use the same fast
/// fade that the app's go_router configuration uses, so navigation feels
/// identical regardless of which API triggered the transition.
final PageTransitionsTheme _fastFadePageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    for (final TargetPlatform platform in TargetPlatform.values)
      platform: const _FadePageTransitionsBuilder(),
  },
);

/// Minimal fade-only page transition.
///
/// Used for both forward and reverse navigation; the curves are chosen so
/// that pushing feels eager and popping feels snappy, matching the
/// go_router transition defined in `app_router.dart`.
class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    );
  }
}