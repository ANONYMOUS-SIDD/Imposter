// word_repository.dart
//
// Loads the app's bundled word data from JSON files shipped as assets, one
// file per category under `assets/data/words/`. Each file is parsed,
// validated, and merged into a single list that the game engine consumes.
//
// File format
// -----------
// Each file is a JSON object with a `words` array. Each entry supplies an
// `id`, an `english` word, an optional `nepali` translation, and an
// optional `hints` object with easy/medium/hard entries. The `categoryId`
// of every word is derived from the filename — the filename always wins
// over any `categoryId` field embedded in the JSON.
//
// Categories are declared explicitly in [bundledCategoryIds]. Adding a
// category requires adding its id to that list and dropping the matching
// JSON file into the assets folder. The `custom` pseudo-category is
// intentionally excluded — custom words come from SharedPreferences via
// CustomWordsRepository.
//
// Parallel loading
// ----------------
// Every category file is loaded in parallel through `Future.wait`. Each
// asset read is an async platform-channel call, so running them
// concurrently makes total load time roughly equal to the slowest single
// file rather than the sum of all files. On typical devices this keeps
// the initial load under ~50 ms, which is what allows the Setup screen to
// render its word-dependent sections without a loading state.
//
// Fallbacks
// ---------
// Malformed data is handled on a per-item basis:
//   • A word with no `english` text is skipped.
//   • A word with no `nepali` text uses the `english` text for both
//     language slots.
//   • A hint object that is missing a language falls back to the neutral
//     placeholder for that language (`Mystery` / `रहस्य`), not to the
//     word's own answer.
//   • A malformed category file is skipped as a whole; its words simply
//     do not appear in the merged list. Only a fully empty result — every
//     category file failed or produced no words — throws.
//
// Loading is safe to invoke multiple times; the FutureProvider that wraps
// this repository caches the result so subsequent access is free. For a
// fully synchronous first-frame render on Game Setup, the provider can be
// warmed at app startup via a post-frame callback in `main.dart`.
//
// The repository accepts an injectable [AssetBundle], which lets tests
// substitute an in-memory bundle with fabricated JSON.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/word.dart';

class WordRepository {
  WordRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const String _basePath = 'assets/data/words/';

  /// Category ids that correspond to JSON files under [_basePath].
  ///
  /// The debug-only assert in [loadAll] fails fast if the same id appears
  /// twice, which is the most common configuration mistake when adding a
  /// category.
  static const List<String> bundledCategoryIds = <String>[
    'animals',
    'food',
    'places',
    'professions',
    'sports',
    'vehicles',
    'objects',
    'school',
    'technology',
    'clothing',
    'body',
    'nature',
    'entertainment',
    'music',
    'brands',
    'celebrities',
    'culture',
    'games',
  ];

  static const String _neutralFallbackEnglish = 'Mystery';
  static const String _neutralFallbackNepali = 'रहस्य';

  /// Loads every bundled category file and returns the merged, validated
  /// word list.
  ///
  /// Files are loaded in parallel. A single bad file is skipped; only a
  /// completely empty result throws a [StateError].
  Future<List<Word>> loadAll() async {
    assert(() {
      final Set<String> seen = <String>{};
      for (final String id in bundledCategoryIds) {
        if (!seen.add(id)) {
          throw StateError(
            'bundledCategoryIds contains duplicate id "$id"',
          );
        }
      }
      return true;
    }(), 'bundledCategoryIds must be unique');

    // Load each category concurrently. Per-category failures must not
    // cancel the other loads, so each future resolves independently.
    final List<Future<_CategoryResult>> futures =
    bundledCategoryIds.map(_loadCategorySafely).toList();

    final List<_CategoryResult> results = await Future.wait(futures);

    // Merge in the order declared by [bundledCategoryIds] so duplicate-ID
    // detection across categories is deterministic.
    final List<Word> merged = <Word>[];
    final Set<String> seenIds = <String>{};

    for (final _CategoryResult result in results) {
      if (result.error != null) continue;
      for (final Word word in result.words) {
        if (!seenIds.add(word.id)) continue;
        merged.add(word);
      }
    }

    if (merged.isEmpty) {
      throw StateError(
        'No words could be loaded from any category file.',
      );
    }

    return List<Word>.unmodifiable(merged);
  }

  /// Loads one category, converting any thrown error into a
  /// [_CategoryResult] carrying the error so [loadAll] can decide how to
  /// handle it without aborting the other parallel loads.
  Future<_CategoryResult> _loadCategorySafely(String categoryId) async {
    try {
      final List<Word> words = await _loadCategoryFile(categoryId);
      return _CategoryResult(categoryId: categoryId, words: words);
    } catch (e) {
      return _CategoryResult(
        categoryId: categoryId,
        words: const <Word>[],
        error: e,
      );
    }
  }

  Future<List<Word>> _loadCategoryFile(String categoryId) async {
    final String path = '$_basePath$categoryId.json';
    final String raw = await _bundle.loadString(path);
    final Object? decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw FormatException('$path root must be a JSON object');
    }

    final Object? list = decoded['words'];
    if (list is! List) {
      throw FormatException('$path must contain a top-level "words" array');
    }

    final List<Word> result = <Word>[];
    for (final Object? item in list) {
      final Word? word = _parseWord(item, filenameCategoryId: categoryId);
      if (word != null) result.add(word);
    }
    return result;
  }

  Word? _parseWord(Object? item, {required String filenameCategoryId}) {
    if (item is! Map<String, dynamic>) {
      return null;
    }

    final Object? id = item['id'];
    final Object? english = item['english'];
    final Object? nepali = item['nepali'];

    if (id is! String || id.isEmpty) return null;
    if (english is! String || english.isEmpty) return null;

    // Missing or empty Nepali uses the English word for both language slots.
    final String nepaliResolved =
    (nepali is String && nepali.isNotEmpty) ? nepali : english;

    final HintSet hints = _parseHints(item['hints'], wordId: id);

    return Word(
      id: id,
      categoryId: filenameCategoryId,
      english: english,
      nepali: nepaliResolved,
      hints: hints,
    );
  }

  HintSet _parseHints(Object? raw, {required String wordId}) {
    const LocalizedText fallback = LocalizedText(
      english: _neutralFallbackEnglish,
      nepali: _neutralFallbackNepali,
    );

    if (raw is! Map<String, dynamic>) {
      return const HintSet(easy: fallback, medium: fallback, hard: fallback);
    }

    return HintSet(
      easy: _parseLocalized(raw['easy'], wordId: wordId, difficulty: 'easy'),
      medium:
      _parseLocalized(raw['medium'], wordId: wordId, difficulty: 'medium'),
      hard: _parseLocalized(raw['hard'], wordId: wordId, difficulty: 'hard'),
    );
  }

  /// Parses a single localized hint, applying the fallback rules described
  /// in the file header.
  LocalizedText _parseLocalized(
      Object? raw, {
        required String wordId,
        required String difficulty,
      }) {
    const LocalizedText fallback = LocalizedText(
      english: _neutralFallbackEnglish,
      nepali: _neutralFallbackNepali,
    );

    if (raw is! Map<String, dynamic>) {
      return fallback;
    }

    final Object? en = raw['english'];
    final Object? ne = raw['nepali'];

    final String? enResolved = (en is String && en.isNotEmpty) ? en : null;
    final String? neResolved = (ne is String && ne.isNotEmpty) ? ne : enResolved;

    if (enResolved == null && neResolved == null) {
      return fallback;
    }

    return LocalizedText(
      english: enResolved ?? _neutralFallbackEnglish,
      nepali: neResolved ?? _neutralFallbackNepali,
    );
  }
}

/// Per-category load result. Carries either the parsed words or the error
/// from a failed load, so [WordRepository.loadAll] can process each category
/// without one failure aborting the others.
@immutable
class _CategoryResult {
  const _CategoryResult({
    required this.categoryId,
    required this.words,
    this.error,
  });

  final String categoryId;
  final List<Word> words;
  final Object? error;
}

final wordRepositoryProvider = Provider<WordRepository>(
      (ref) => WordRepository(),
);

/// Provides the full bundled-word list. Resolves once and remains cached
/// for the app lifetime.
///
/// Warm this provider at app startup (via a post-frame callback in
/// `main.dart`) so Game Setup can render its word-dependent sections on
/// the first frame without an intermediate loading state.
final allWordsProvider = FutureProvider<List<Word>>(
      (ref) async => ref.watch(wordRepositoryProvider).loadAll(),
);