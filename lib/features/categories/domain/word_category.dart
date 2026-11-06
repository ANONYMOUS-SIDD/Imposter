// word_category.dart
//
// Model for a word category.
//
// Categories are defined in code rather than loaded from JSON because the
// set is small, stable, and each entry carries an `IconData` that must be
// a compile-time constant. Words reference categories by `id` and live in
// their own JSON files. If a user-extensible category system is ever
// required, this model can be extended with a `fromJson` constructor the
// same way `Word` is.
//
// Value semantics are based on `id` only. All other fields are declared
// once alongside the id in `CategoryRepository`, so id equality is
// equivalent to full equality. This keeps `Set`, `Map`, Riverpod `select`,
// and `didUpdateWidget` comparisons working without per-call-site
// workarounds.
//
// Two name-rendering methods are provided because the same string is used
// in both multi-line and single-line contexts:
//   • `nameFor` / `nameForMode` — uses a newline between English and
//     Nepali in `both` mode. Suitable for body text, tooltips, and any
//     context that allows multiple lines.
//   • `singleLineNameFor` / `singleLineNameForMode` — uses ` — ` as the
//     separator. Required in any context with a single-line constraint
//     (chip labels, button text, AppBar titles, tight rows), where a
//     newline would either clip the second line or trigger a
//     `RenderFlex` overflow.
//
// `LanguageMode` is an enum so the mode can be checked at compile time.
// The legacy `String`-based variants of the name methods remain for
// backward compatibility with existing call-sites; new code should prefer
// the enum-based variants. An unrecognized string falls back to English;
// the enum path has no fallback because unknown values cannot be
// constructed.

import 'package:flutter/widgets.dart';

/// In-game language mode.
///
/// The string form persisted in settings is exposed as [raw] so the enum
/// can be converted to and from the value stored on disk.
enum LanguageMode {
  english('english'),
  nepali('nepali'),
  both('both');

  const LanguageMode(this.raw);

  /// The string form persisted in settings and used by legacy call-sites.
  final String raw;

  /// Converts a raw settings string into a [LanguageMode].
  ///
  /// Unknown values fall back to [english], matching the historical default
  /// of [WordCategory.nameFor].
  static LanguageMode fromRaw(String value) {
    return switch (value) {
      'nepali' => LanguageMode.nepali,
      'both' => LanguageMode.both,
      _ => LanguageMode.english,
    };
  }
}

/// Immutable category model.
@immutable
class WordCategory {
  const WordCategory({
    required this.id,
    required this.englishName,
    required this.nepaliName,
    required this.icon,
  });

  /// Stable identifier referenced by [Word] records and by persisted
  /// selections. Must be unique within the category repository. Changing
  /// an existing id breaks any previously-persisted state that references
  /// it.
  final String id;

  final String englishName;
  final String nepaliName;

  /// Category icon. Compile-time constant by construction.
  final IconData icon;

  /// Returns the display name for the given [languageMode], using a
  /// newline between English and Nepali in `both` mode.
  ///
  /// Use [singleLineNameFor] in any context with a single-line constraint;
  /// a newline inside a height-constrained parent will clip the second
  /// line or cause an overflow.
  ///
  /// Retained for backward compatibility with existing call-sites. New
  /// code should prefer [nameForMode].
  String nameFor(String languageMode) =>
      nameForMode(LanguageMode.fromRaw(languageMode));

  /// Enum-typed variant of [nameFor]. Preferred for all new call-sites.
  String nameForMode(LanguageMode mode) => switch (mode) {
    LanguageMode.nepali => nepaliName,
    LanguageMode.both => '$englishName\n$nepaliName',
    LanguageMode.english => englishName,
  };

  /// Returns the display name for the given [languageMode], joining
  /// English and Nepali with ` — ` in `both` mode.
  ///
  /// Use this in any height- or width-constrained context — chip labels,
  /// button text, AppBar titles, list tile titles, and tight rows.
  String singleLineNameFor(String languageMode) =>
      singleLineNameForMode(LanguageMode.fromRaw(languageMode));

  /// Enum-typed variant of [singleLineNameFor].
  String singleLineNameForMode(LanguageMode mode) => switch (mode) {
    LanguageMode.nepali => nepaliName,
    LanguageMode.both => '$englishName — $nepaliName',
    LanguageMode.english => englishName,
  };

  WordCategory copyWith({
    String? id,
    String? englishName,
    String? nepaliName,
    IconData? icon,
  }) {
    return WordCategory(
      id: id ?? this.id,
      englishName: englishName ?? this.englishName,
      nepaliName: nepaliName ?? this.nepaliName,
      icon: icon ?? this.icon,
    );
  }

  /// Equality is based on [id] only. See the file header for reasoning.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is WordCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WordCategory(id: $id, en: $englishName, ne: $nepaliName)';
}