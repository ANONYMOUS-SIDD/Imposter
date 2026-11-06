// word.dart
//
// Domain models for a word and its localized text and hint data.
//
// Three classes make up this file:
//
//   LocalizedText — a pair of (english, nepali) strings representing one
//   logical text value.
//
//   HintSet — three LocalizedText instances, one per difficulty tier.
//
//   Word — the playable entity: id, category, translation, and hints.
//
// Text rendering
// --------------
// LocalizedText exposes two rendering methods because the same underlying
// strings appear in both multi-line and single-line contexts:
//
//   resolve / singleLineResolve — English and Nepali joined with a
//   newline in `both` mode. Suitable for body text, dialog content,
//   tooltips, and empty states.
//
//   singleLineResolve — English and Nepali joined with ` — ` in `both`
//   mode. Required in any context with a single-line constraint (chip
//   labels, button text, AppBar titles, ListTile titles, tight rows). The
//   newline variant will either clip the second line or trigger a
//   RenderFlex overflow in those contexts.
//
// `resolve` falls back to English for unrecognized language modes rather
// than returning null, matching the behavior of `WordCategory.nameFor`.
// Callers that need to distinguish "no translation for this mode" from
// "translation exists" should use `resolveOrNull`.
//
// Equality
// --------
// Word uses content equality across every field — id, categoryId,
// english, nepali, and hints. Two words with the same id but different
// content are not equal, which is what allows Riverpod change detection
// to rebuild the reveal screen when a user edits a custom word's hints
// while keeping the same id.
//
// The trade-off is that `Set<Word>` de-duplicates only fully-identical
// instances. That is acceptable because the engine and session model
// operate on ordered `List<Word>` collections, never on sets.
//
// Performance note
// ----------------
// `Word.localized` allocates a new LocalizedText on every access. Cheap
// in isolation, but should not be called inside a build method's inner
// loop. If the same LocalizedText is needed multiple times on a screen,
// bind it to a local variable once; `word.english` and `word.nepali` are
// plain field reads and cost nothing.

import 'package:flutter/foundation.dart';

/// Difficulty tier for a hint. Ordered from easiest (largest giveaway) to
/// hardest (tightest).
enum HintDifficulty { easy, medium, hard }

/// A pair of (english, nepali) strings representing one logical text value.
@immutable
class LocalizedText {
  const LocalizedText({required this.english, required this.nepali});

  final String english;
  final String nepali;

  /// Returns the text for the given [languageMode], which must be one of
  /// `'english'`, `'nepali'`, or `'both'`.
  ///
  /// In `'both'` mode the two strings are joined with a newline; use
  /// [singleLineResolve] in contexts that require a single line. Unknown
  /// modes fall back to [english].
  String resolve(String languageMode) {
    return switch (languageMode) {
      'nepali' => nepali,
      'both' => '$english\n$nepali',
      _ => english,
    };
  }

  /// Strict variant of [resolve]: returns `null` for unrecognized modes
  /// instead of falling back to English.
  String? resolveOrNull(String languageMode) {
    return switch (languageMode) {
      'english' => english,
      'nepali' => nepali,
      'both' => '$english\n$nepali',
      _ => null,
    };
  }

  /// Returns the text for the given [languageMode], joining English and
  /// Nepali with ` — ` in `'both'` mode.
  ///
  /// Required in any context with a single-line constraint: chip labels,
  /// button text, AppBar titles, ListTile titles, and tight rows.
  String singleLineResolve(String languageMode) {
    return switch (languageMode) {
      'nepali' => nepali,
      'both' => '$english — $nepali',
      _ => english,
    };
  }

  LocalizedText copyWith({String? english, String? nepali}) =>
      LocalizedText(
        english: english ?? this.english,
        nepali: nepali ?? this.nepali,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is LocalizedText &&
              other.english == english &&
              other.nepali == nepali;

  @override
  int get hashCode => Object.hash(english, nepali);

  @override
  String toString() => 'LocalizedText(en: $english, ne: $nepali)';
}

/// The three hints a word provides, one per difficulty tier.
@immutable
class HintSet {
  const HintSet({
    required this.easy,
    required this.medium,
    required this.hard,
  });

  final LocalizedText easy;
  final LocalizedText medium;
  final LocalizedText hard;

  /// Returns the hint for the given [difficulty]. Mirrors [Word.hintFor] so
  /// callers holding a bare HintSet (such as tests) can look up without
  /// going through a Word.
  LocalizedText forDifficulty(HintDifficulty difficulty) {
    return switch (difficulty) {
      HintDifficulty.easy => easy,
      HintDifficulty.medium => medium,
      HintDifficulty.hard => hard,
    };
  }

  HintSet copyWith({
    LocalizedText? easy,
    LocalizedText? medium,
    LocalizedText? hard,
  }) =>
      HintSet(
        easy: easy ?? this.easy,
        medium: medium ?? this.medium,
        hard: hard ?? this.hard,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is HintSet &&
              other.easy == easy &&
              other.medium == medium &&
              other.hard == hard;

  @override
  int get hashCode => Object.hash(easy, medium, hard);

  @override
  String toString() =>
      'HintSet(easy: $easy, medium: $medium, hard: $hard)';
}

/// A playable word with its category, translation, and hint set.
@immutable
class Word {
  const Word({
    required this.id,
    required this.categoryId,
    required this.english,
    required this.nepali,
    required this.hints,
  })  : assert(id != '', 'Word.id must not be empty'),
        assert(english != '', 'Word.english must not be empty');

  /// Stable identifier for the word. Bundled words use `{category}_{NNN}`;
  /// custom words use the `custom_` prefix declared in
  /// `custom_words_repository.dart`.
  final String id;

  /// Category this word belongs to. For custom words this is the category
  /// chosen by the user, not necessarily the `custom` pseudo-category.
  final String categoryId;

  /// Canonical English form. Never empty.
  final String english;

  /// Nepali translation. Falls back to [english] when missing, matching the
  /// parsing policy used by `WordRepository`.
  final String nepali;

  final HintSet hints;

  /// Pairs [english] and [nepali] into a [LocalizedText].
  ///
  /// Allocates a new instance on each call. Repeated access should bind the
  /// result to a local variable rather than re-invoking the getter.
  LocalizedText get localized =>
      LocalizedText(english: english, nepali: nepali);

  /// Returns the hint for the given [difficulty].
  LocalizedText hintFor(HintDifficulty difficulty) =>
      hints.forDifficulty(difficulty);

  Word copyWith({
    String? id,
    String? categoryId,
    String? english,
    String? nepali,
    HintSet? hints,
  }) =>
      Word(
        id: id ?? this.id,
        categoryId: categoryId ?? this.categoryId,
        english: english ?? this.english,
        nepali: nepali ?? this.nepali,
        hints: hints ?? this.hints,
      );

  /// Content equality across all five fields. See the file header for why
  /// the id alone is insufficient.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Word &&
              other.id == id &&
              other.categoryId == categoryId &&
              other.english == english &&
              other.nepali == nepali &&
              other.hints == hints;

  @override
  int get hashCode => Object.hash(id, categoryId, english, nepali, hints);

  @override
  String toString() =>
      'Word(id: $id, category: $categoryId, en: $english, ne: $nepali)';
}