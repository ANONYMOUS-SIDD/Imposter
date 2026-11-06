// custom_words_repository.dart
//
// Persistence and Riverpod wiring for user-created custom words.
//
// Storage
// -------
// Custom words are stored as JSON inside a single SharedPreferences string
// under the versioned key `custom_words_v1`. They reuse the standard `Word`
// model so that the game engine can treat them identically to bundled words.
// The only distinguishing marker is the `custom_` prefix on their IDs,
// which avoids collisions with bundled IDs such as `fruits_001`.
//
// JSON-in-prefs (rather than SQLite) is a deliberate choice. A few hundred
// words fit comfortably in a single preference value, and the app has no
// other database needs. If usage ever grows into thousands, this repository
// can be swapped for a SQLite-backed implementation without changing the
// notifier or any caller.
//
// Synchronous reads
// -----------------
// `getAll` is synchronous and returns a shared, unmodifiable list. Callers
// read it directly from `Notifier.build()`, so the Game Setup screen renders
// the custom-words section without an intermediate loading state. Do not
// convert `getAll` to an asynchronous operation — that would reintroduce
// the loading flash that the rest of the app avoids.
//
// Serialized writes
// -----------------
// All mutations are chained through an internal future queue so two rapid
// calls cannot lose updates. Each operation runs after the previous one
// completes, reading the latest persisted state before producing its own
// write.
//
// Data integrity
// --------------
// Corrupt stored data never crashes the setup screen. If the JSON root
// cannot be decoded, `getAll` returns an empty list. If an individual entry
// is malformed, it is skipped — missing Nepali text and missing hint fields
// fall back to the English word, matching the policy used by the bundled
// word loader. New IDs are collision-checked against the existing list.
// Debug builds additionally assert that every added word carries the
// `custom_` prefix.
//
// Versioning
// ----------
// The storage key is versioned. A future schema change should introduce a
// `_v2` key and migrate the contents of `_v1` on first launch, leaving the
// meaning of `_v1` untouched.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/app_providers.dart';
import '../../game/domain/entities/word.dart';

/// Prefix applied to every custom word ID so bundled and user-created words
/// can be distinguished. Exposed publicly so call-sites can compare against
/// it without duplicating the literal.
const String customWordIdPrefix = 'custom_';

class CustomWordsRepository {
  CustomWordsRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Versioned storage key. Changing this value requires a migration path.
  static const String _storageKey = 'custom_words_v1';

  /// Serializes mutations so concurrent add/update/delete calls cannot
  /// interleave reads and writes in a way that loses data.
  Future<void> _writeChain = Future<void>.value();

  /// Loads every saved custom word.
  ///
  /// Never throws. Corrupt or missing storage yields an empty list; invalid
  /// individual entries are skipped. Suitable for calling from
  /// `Notifier.build()` — synchronous and cheap for typical word counts.
  List<Word> getAll() {
    final String? raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const <Word>[];

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <Word>[];

      final List<Word> result = <Word>[];
      for (final Object? item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final Word? word = _fromJson(item);
        if (word != null) result.add(word);
      }
      return List<Word>.unmodifiable(result);
    } catch (_) {
      return const <Word>[];
    }
  }

  /// Appends [word] to the stored list.
  ///
  /// Asserts in debug builds that [Word.id] begins with [customWordIdPrefix]
  /// — a bundled word entering custom storage would break the ID-prefix
  /// disambiguation used elsewhere in the app.
  Future<void> add(Word word) {
    assert(
    word.id.startsWith(customWordIdPrefix),
    'Custom word id must start with "$customWordIdPrefix" '
        '(got "${word.id}")',
    );
    return _enqueueWrite(() => <Word>[...getAll(), word]);
  }

  /// Replaces the word whose ID matches [word.id]. No-op if no match exists.
  Future<void> update(Word word) {
    return _enqueueWrite(() {
      final List<Word> all = getAll().toList();
      final int idx = all.indexWhere((Word w) => w.id == word.id);
      if (idx == -1) return all;
      all[idx] = word;
      return all;
    });
  }

  /// Removes the word whose ID matches [id]. No-op if no match exists.
  Future<void> delete(String id) {
    return _enqueueWrite(
          () => getAll().where((Word w) => w.id != id).toList(),
    );
  }

  /// Removes every custom word. Used by tests and by app-reset flows.
  Future<void> clear() => _enqueueWrite(() => const <Word>[]);

  /// Returns a unique ID for a new custom word.
  ///
  /// The base is the current microsecond timestamp, prefixed with
  /// [customWordIdPrefix]. If the timestamp happens to collide with an
  /// existing ID (unlikely but not impossible across rapid saves), a numeric
  /// suffix is appended until the value is free.
  String generateId() {
    final Set<String> existing = getAll().map((Word w) => w.id).toSet();
    String candidate =
        '$customWordIdPrefix${DateTime.now().microsecondsSinceEpoch}';
    int suffix = 0;
    while (existing.contains(candidate)) {
      suffix++;
      candidate =
      '$customWordIdPrefix${DateTime.now().microsecondsSinceEpoch}_$suffix';
    }
    return candidate;
  }

  /// Parses a single JSON entry into a [Word], or returns `null` if the
  /// entry is malformed.
  Word? _fromJson(Map<String, dynamic> json) {
    try {
      final Object? id = json['id'];
      final Object? categoryId = json['categoryId'];
      final Object? english = json['english'];
      final Object? nepali = json['nepali'];
      final Object? hints = json['hints'];

      if (id is! String || id.isEmpty) return null;
      if (categoryId is! String || categoryId.isEmpty) return null;
      if (english is! String || english.isEmpty) return null;

      // Missing or empty Nepali falls back to the English word, matching
      // the fallback policy used when loading bundled words.
      final String nepaliStr =
      (nepali is String && nepali.isNotEmpty) ? nepali : english;

      LocalizedText parseLocalized(Object? raw, String fallback) {
        if (raw is! Map<String, dynamic>) {
          return LocalizedText(english: fallback, nepali: fallback);
        }
        final Object? en = raw['english'];
        final Object? ne = raw['nepali'];
        return LocalizedText(
          english: (en is String && en.isNotEmpty) ? en : fallback,
          nepali: (ne is String && ne.isNotEmpty) ? ne : fallback,
        );
      }

      final Map<String, dynamic> hintsMap =
      hints is Map<String, dynamic> ? hints : <String, dynamic>{};

      return Word(
        id: id,
        categoryId: categoryId,
        english: english,
        nepali: nepaliStr,
        hints: HintSet(
          easy: parseLocalized(hintsMap['easy'], english),
          medium: parseLocalized(hintsMap['medium'], english),
          hard: parseLocalized(hintsMap['hard'], english),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Serializes a [Word] back into the on-disk JSON shape.
  Map<String, dynamic> _toJson(Word w) => <String, dynamic>{
    'id': w.id,
    'categoryId': w.categoryId,
    'english': w.english,
    'nepali': w.nepali,
    'hints': <String, dynamic>{
      'easy': <String, dynamic>{
        'english': w.hints.easy.english,
        'nepali': w.hints.easy.nepali,
      },
      'medium': <String, dynamic>{
        'english': w.hints.medium.english,
        'nepali': w.hints.medium.nepali,
      },
      'hard': <String, dynamic>{
        'english': w.hints.hard.english,
        'nepali': w.hints.hard.nepali,
      },
    },
  };

  /// Persists [words] to the preference store as a single JSON string.
  Future<void> _write(List<Word> words) async {
    final String json = jsonEncode(words.map(_toJson).toList());
    await _prefs.setString(_storageKey, json);
  }

  /// Schedules a mutation to run after any in-flight write.
  ///
  /// The `computeNext` callback runs inside the queue so it observes the
  /// latest persisted state. The returned future resolves when the write
  /// completes, or completes with an error if the write fails. The internal
  /// chain swallows errors so a single failure cannot permanently poison
  /// subsequent writes.
  Future<void> _enqueueWrite(List<Word> Function() computeNext) {
    final Future<void> job = _writeChain.then((_) async {
      await _write(computeNext());
    });
    _writeChain = job.catchError((Object _) {});
    return job;
  }
}

/// Provides the app-wide [CustomWordsRepository].
final customWordsRepositoryProvider = Provider<CustomWordsRepository>((ref) {
  return CustomWordsRepository(ref.watch(sharedPreferencesProvider));
});

/// Holds the in-memory list of custom words.
///
/// Reads the persisted list once during `build` and keeps `state` in sync
/// after each mutation. All state assignments are guarded against
/// post-disposal so an async mutation that completes after the notifier is
/// torn down does not throw.
class CustomWordsNotifier extends Notifier<List<Word>> {
  bool _disposed = false;

  @override
  List<Word> build() {
    ref.onDispose(() => _disposed = true);
    // `watch` (rather than `read`) keeps the notifier in sync if the
    // repository instance ever changes. In practice the repository is
    // stable for the app lifetime, but watch avoids losing state if that
    // assumption is ever relaxed.
    return ref.watch(customWordsRepositoryProvider).getAll();
  }

  Future<void> add(Word word) async {
    await ref.read(customWordsRepositoryProvider).add(word);
    if (_disposed) return;
    state = <Word>[...state, word];
  }

  Future<void> update(Word word) async {
    await ref.read(customWordsRepositoryProvider).update(word);
    if (_disposed) return;
    state = state
        .map((Word w) => w.id == word.id ? word : w)
        .toList(growable: false);
  }

  Future<void> delete(String id) async {
    await ref.read(customWordsRepositoryProvider).delete(id);
    if (_disposed) return;
    state = state.where((Word w) => w.id != id).toList(growable: false);
  }

  Future<void> clear() async {
    await ref.read(customWordsRepositoryProvider).clear();
    if (_disposed) return;
    state = const <Word>[];
  }

  /// Returns a new unique ID for a word being created.
  String newId() => ref.read(customWordsRepositoryProvider).generateId();
}

final customWordsProvider =
NotifierProvider<CustomWordsNotifier, List<Word>>(CustomWordsNotifier.new);