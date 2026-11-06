// app_colors.dart
//
// Color tokens for the Imposter app.
//
// The palette is a dark theme built around three roles:
//   • Backgrounds — three steps of elevation from near-black to dark violet.
//   • Brand — purple family, used for primary actions and selection states.
//   • Imposter — red family, reserved exclusively for reveal and result
//     screens where the imposter must stand out from the purple brand.
//
// Text tones are chosen for contrast against [background] and [surface].
// Two tokens, [primaryPurple] and [imposterRed], sit below the WCAG AA
// threshold for body text and must only be used as backgrounds (with
// [textBright] painted on top) or as decorative fills — never as the
// foreground color of text drawn directly on a dark surface.
//
// All tokens are `const`, so referencing them from widget code produces
// no runtime allocation. Gradients are prebuilt as `const LinearGradient`
// values for the same reason.
//
// When adding new colors: prefer extending this class over introducing
// literals in widgets. The palette stays centralized, easy to audit for
// contrast, and consistent across screens.

import 'package:flutter/material.dart';

/// Namespace for the app's color constants.
///
/// `abstract final` prevents both instantiation and subclassing — the class
/// exists purely to group the `static const` fields below.
abstract final class AppColors {
  // ── Backgrounds and surfaces ─────────────────────────────────────────────
  // Layered by elevation: [background] is the app shell, [surface] is the
  // default card/sheet, [secondarySurface] is for elements nested above a
  // card (chips, focused inputs, selected states).

  /// App-wide backdrop. Near-black with a violet undertone.
  static const background       = Color(0xFF0B0714);

  /// Default card and sheet surface.
  static const surface          = Color(0xFF151024);

  /// Elevated surface for elements above a [surface] (nested cards, chips,
  /// focused input fields, selected states).
  static const secondarySurface = Color(0xFF201632);

  // ── Brand accent (purple) ────────────────────────────────────────────────

  /// Primary brand color. Intended as a background/fill; not suitable as
  /// text on [background] due to insufficient contrast for body copy.
  static const primaryPurple    = Color(0xFF7138D8);

  /// Brightest purple in the palette. Used for glows, focus rings, and
  /// high-emphasis accent text.
  static const neonPurple       = Color(0xFFA56BFF);

  /// Dark violet used as the second stop of [gradientPrimary] and for
  /// pressed/disabled states of brand-colored controls.
  static const deepPurple       = Color(0xFF38146D);

  // ── Imposter accent (red) ────────────────────────────────────────────────
  // Used only during reveal and result screens, where the semantic shift
  // from "purple brand" to "red danger" reinforces the reveal moment.

  /// Deep red used as a background on imposter reveal screens.
  static const imposterRed      = Color(0xFFB51F38);

  /// Bright crimson for imposter highlights, borders, and glow effects.
  static const crimson          = Color(0xFFF04462);

  // ── Text ─────────────────────────────────────────────────────────────────

  /// Body text. Soft off-white with a subtle lavender tint that reduces
  /// glare against the dark background without sacrificing contrast.
  static const textPrimary      = Color(0xFFCFCFD9);

  /// High-emphasis text for headlines and labels on colored fills
  /// (buttons, tags). Pure white for maximum legibility.
  static const textBright       = Color(0xFFFFFFFF);

  /// Secondary text for captions, field hints, and helper strings.
  static const textSecondary    = Color(0xFFAAA1B8);

  // ── Gradients ────────────────────────────────────────────────────────────
  // Prebuilt as `const` so widget code can reference them without
  // constructing a new `LinearGradient` on every rebuild.

  /// Brand gradient for primary buttons and hero surfaces.
  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPurple, deepPurple],
  );

  /// Imposter gradient for reveal and result screens.
  static const gradientImposter = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [imposterRed, crimson],
  );
}