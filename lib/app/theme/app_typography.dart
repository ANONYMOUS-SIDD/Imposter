// app_typography.dart
//
// Text style tokens for the Imposter app.
//
// Six tiers form the type scale: display, headline, title, body, caption,
// and label. Each style carries an explicit `height` so line spacing is
// deterministic — without it, custom fonts fall back to their own vertical
// metrics, which can crowd multi-line text and clip descenders on
// languages with taller glyphs (notably Devanagari).
//
// The font family is declared in two places and both must stay in sync:
//   1. `ThemeData.fontFamily` in `app_theme.dart` — covers unstyled widgets
//      that inherit through the theme.
//   2. [_fontFamily] in this file — covers direct use of these constants,
//      including `Text.rich` inline spans and `TextPainter` draws.
//   When the two diverge, the styles here win because they set
//   `fontFamily` explicitly on the resulting `TextStyle`.
//
// Font weight note: the bundled Quicksand family ships weights 300–700.
// [display] specifies `w800`, which Flutter resolves to the nearest
// available weight (700) at render time. To render true extra-bold, bundle
// the Quicksand Variable font or switch to a family that ships `w800`.
//
// Overflow is a layout concern, not a typography concern. Styles here set
// size, weight, and line height; they cannot prevent overflow on their
// own. Widgets using these styles must guard constrained text with
// `maxLines` + `overflow`, wrap flexible children in [Flexible]/[Expanded],
// and use [FittedBox] where a fixed-size box is unavoidable (chips, tags,
// single-line button labels).
//
// [responsive] scales a style by screen width against a 390dp reference,
// clamped to [0.85, 1.25]. It is optional: most screens should use the base
// styles directly and rely on constrained layout. The helper does not
// interact with accessibility text scaling — that is applied independently
// by the theme via `TextScaler`.

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Namespace for the app's typography tokens.
abstract final class AppTypography {
  /// Font family shared by every style below.
  ///
  /// Must match `ThemeData.fontFamily` in `app_theme.dart`. Referenced from
  /// each style so callers using these constants directly (rather than
  /// through the theme) still get the correct family.
  static const String _fontFamily = 'Quicksand';

  /// Hero text — splash titles, single-line emphatic headlines.
  /// Line height 1.15 gives tight leading without clipping descenders.
  static const display = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 34,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.5,
    color: AppColors.textPrimary,
  );

  /// Section-level titles — screen headers, dialog headings.
  static const headline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Subsection titles — card headers, list item titles, smaller dialog
  /// headings.
  static const title = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Primary reading text — descriptions, paragraphs, longer hint strings.
  /// Line height 1.45 optimizes readability at this size.
  static const body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Secondary text — field hints, helper strings, meta labels.
  /// Slightly tighter leading than [body] because captions are usually
  /// short and benefit from a more compact rhythm.
  static const caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.6,
    color: AppColors.textSecondary,
  );

  /// Small uppercase labels — section eyebrows, button labels, tags.
  /// Letter spacing of 1.4 keeps short uppercase runs legible.
  static const label = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppColors.neonPurple,
  );

  /// Scales [base] by screen width relative to [referenceWidth].
  ///
  /// The scale factor is clamped between [minScale] and [maxScale] so small
  /// phones stay legible and tablets stay proportional to the design
  /// reference. When the computed factor rounds to 1.0 (the common case on
  /// phones close to [referenceWidth]), [base] is returned unchanged so no
  /// allocation happens during rebuild.
  ///
  /// Example:
  /// ```dart
  /// Text('IMPOSTER',
  ///   style: AppTypography.responsive(context, AppTypography.display))
  /// ```
  ///
  /// This helper only adjusts for physical screen width. Accessibility
  /// text scaling (TextScaler) is applied separately by the framework and
  /// is not affected by the return value here.
  static TextStyle responsive(
      BuildContext context,
      TextStyle base, {
        double referenceWidth = 390,
        double minScale = 0.85,
        double maxScale = 1.25,
      }) {
    final double width = MediaQuery.sizeOf(context).width;
    final double factor =
    (width / referenceWidth).clamp(minScale, maxScale);

    if ((factor - 1.0).abs() < 0.02) return base;

    final double? baseSize = base.fontSize;
    if (baseSize == null) return base;
    return base.copyWith(fontSize: baseSize * factor);
  }
}