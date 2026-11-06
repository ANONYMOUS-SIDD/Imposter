// game_settings.dart
//
// Configuration snapshot for a single game round.
//
// A GameSettings instance captures everything the setup screen collects
// before the engine assigns roles: language mode, imposter mode, hint
// options, category selection, and the custom-words toggle. Once built,
// the instance is immutable — changes flow through `copyWith`, which
// returns a new instance so Riverpod can detect the change.
//
// Consistency requirements
// ------------------------
// Several fields must stay aligned with state elsewhere:
//
//   • `languageMode` must be one of `'english'`, `'nepali'`, or `'both'`,
//     matching the values used by `LanguageMode` in `word_category.dart`
//     and by the language selector on the setup screen. An unrecognized
//     value falls back to English at render time; a debug assert in the
//     constructor rejects invalid values during development.
//
//   • `selectedCategoryIds` and `includeCustomWords` represent the same
//     underlying choice. The engine reads only `selectedCategoryIds` when
//     deciding which words are eligible, so if the boolean and the set
//     disagree, custom words either fail to be selected or appear without
//     the UI toggle reflecting that. Call `normalized()` before passing a
//     GameSettings into the engine to enforce agreement at the boundary.
//
//   • `imposterCount` is intentionally not clamped by this class. The
//     setup screen may hold a value that is invalid for the current
//     player count while the user is still editing. Clamping happens in
//     `GameEngine.createSession` — display logic should compare against
//     `GameEngine.maxImposters(names.length)` before showing the value.
//
// Mutability
// ----------
// All fields are `final`, but a `const` constructor cannot wrap the
// `selectedCategoryIds` set in an unmodifiable wrapper. Callers must treat
// the set as read-only. To change a selection, use `copyWith` — mutating
// the set in place bypasses Riverpod's change detection and produces
// silently stale UI.
//
// Equality
// --------
// `==` and `hashCode` are implemented with content-based comparison for
// the category set, using `setEquals` and `Object.hashAllUnordered`
// respectively. This makes downstream `ref.watch(settings.select((s) =>
// s.someField))` calls rebuild only when the watched field actually
// changes, rather than on every settings mutation.

import 'package:flutter/foundation.dart';

import 'word.dart';

@immutable
class GameSettings {
  const GameSettings({
    required this.languageMode,
    required this.hiddenImposterMode,
    required this.imposterHintEnabled,
    required this.hintDifficulty,
    required this.multipleImposters,
    required this.imposterCount,
    required this.selectedCategoryIds,
    required this.includeCustomWords,
  }) : assert(
  languageMode == 'english' ||
      languageMode == 'nepali' ||
      languageMode == 'both',
  'languageMode must be one of: english, nepali, both '
      '(got "$languageMode")',
  );

  /// Active language mode. One of `'english'`, `'nepali'`, or `'both'`.
  final String languageMode;

  /// When `true`, imposters are not told they are imposters — they
  /// receive an easy hint and believe they are civilians.
  final bool hiddenImposterMode;

  /// When `true`, imposters receive an explicit hint describing the
  /// original word. When `false`, they receive no hint and the effective
  /// hint difficulty is forced to easy.
  final bool imposterHintEnabled;

  /// Difficulty of the imposter hint as selected by the user.
  ///
  /// Do not read this directly to decide what an imposter sees — always
  /// use [effectiveHintDifficulty], which accounts for the two override
  /// flags above.
  final HintDifficulty hintDifficulty;

  /// When `false`, a single imposter is assigned regardless of
  /// [imposterCount].
  final bool multipleImposters;

  /// Desired imposter count when [multipleImposters] is `true`. Not
  /// clamped here — `GameEngine.createSession` clamps to the legal range
  /// for the current player count.
  final int imposterCount;

  /// Categories to draw words from. Treat as read-only: use `copyWith` to
  /// change the selection, never mutate the set in place.
  final Set<String> selectedCategoryIds;

  /// UI-level toggle for the custom-words section. Must match
  /// `selectedCategoryIds.contains('custom')`; [normalized] enforces
  /// agreement.
  final bool includeCustomWords;

  /// Hint difficulty the engine will actually use for imposters.
  ///
  /// Overrides [hintDifficulty] in two cases:
  ///   1. [hiddenImposterMode] is `true` — the hint is always easy so the
  ///      imposter is not tipped off.
  ///   2. [imposterHintEnabled] is `false` — the hint is always easy as a
  ///      fallback, since no explicit hint is being shown.
  HintDifficulty get effectiveHintDifficulty {
    if (hiddenImposterMode) return HintDifficulty.easy;
    if (!imposterHintEnabled) return HintDifficulty.easy;
    return hintDifficulty;
  }

  GameSettings copyWith({
    String? languageMode,
    bool? hiddenImposterMode,
    bool? imposterHintEnabled,
    HintDifficulty? hintDifficulty,
    bool? multipleImposters,
    int? imposterCount,
    Set<String>? selectedCategoryIds,
    bool? includeCustomWords,
  }) =>
      GameSettings(
        languageMode: languageMode ?? this.languageMode,
        hiddenImposterMode: hiddenImposterMode ?? this.hiddenImposterMode,
        imposterHintEnabled: imposterHintEnabled ?? this.imposterHintEnabled,
        hintDifficulty: hintDifficulty ?? this.hintDifficulty,
        multipleImposters: multipleImposters ?? this.multipleImposters,
        imposterCount: imposterCount ?? this.imposterCount,
        selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
        includeCustomWords: includeCustomWords ?? this.includeCustomWords,
      );

  /// Returns a copy of this settings object where [includeCustomWords] and
  /// [selectedCategoryIds] agree.
  ///
  /// When [includeCustomWords] is `true`, `'custom'` is added to the set;
  /// when `false`, it is removed. When the two fields already agree, the
  /// original instance is returned without allocating a new one.
  ///
  /// Call this before passing settings into `GameEngine.createSession`.
  /// The engine consults only the set, so a diverging boolean would make
  /// the custom-words toggle appear to work without actually affecting
  /// which words are eligible.
  GameSettings normalized() {
    final bool hasCustom = selectedCategoryIds.contains('custom');
    if (hasCustom == includeCustomWords) return this;

    final Set<String> updated = <String>{...selectedCategoryIds};
    if (includeCustomWords) {
      updated.add('custom');
    } else {
      updated.remove('custom');
    }
    return copyWith(selectedCategoryIds: updated);
  }

  /// Content equality across all eight fields.
  ///
  /// The category set is compared with `setEquals` so iteration order does
  /// not affect equality. This is what allows `ref.watch` with a `select`
  /// on an individual field to skip rebuilds when that field has not
  /// changed.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GameSettings) return false;
    return other.languageMode == languageMode &&
        other.hiddenImposterMode == hiddenImposterMode &&
        other.imposterHintEnabled == imposterHintEnabled &&
        other.hintDifficulty == hintDifficulty &&
        other.multipleImposters == multipleImposters &&
        other.imposterCount == imposterCount &&
        setEquals(other.selectedCategoryIds, selectedCategoryIds) &&
        other.includeCustomWords == includeCustomWords;
  }

  /// Hash consistent with [==]. The category set uses an unordered hash so
  /// equal settings with different insertion order produce the same hash.
  @override
  int get hashCode => Object.hash(
    languageMode,
    hiddenImposterMode,
    imposterHintEnabled,
    hintDifficulty,
    multipleImposters,
    imposterCount,
    Object.hashAllUnordered(selectedCategoryIds),
    includeCustomWords,
  );

  @override
  String toString() =>
      'GameSettings(lang: $languageMode, '
          'hidden: $hiddenImposterMode, '
          'hintOn: $imposterHintEnabled, '
          'hintDifficulty: $hintDifficulty, '
          'multiImposter: $multipleImposters, '
          'imposterCount: $imposterCount, '
          'categories: ${selectedCategoryIds.length} selected, '
          'includeCustom: $includeCustomWords)';
}