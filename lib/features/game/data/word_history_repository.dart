// word_history_repository.dart
//
// Persistence for per-word pick counts.
//
// Records how many times each word has been served as the secret so
// `GameEngine.selectWord` can down-weight frequently-repeated words.
// Picks remain completely random — every word stays eligible — but a
// word that has been used more often is less likely to appear next.
// This improves variety across many rounds without ever making any
// word impossible.
//
// Storage
// -------
// A single JSON object under `word_pick_counts_v1` maps `wordId` to
// `int` pick count. Bundled and custom words share the same map; the
// key is `Word.id` in both cases. A word never picked has no entry,
// which reads back as zero — so the map grows by one entry per word
// that has ever appeared, not per pick.
//
// Failures
// --------
// `getPickCounts` returns an empty map on missing or corrupt storage,
// which downstream consumers treat as "no history yet" and pick
// uniformly. `recordPick` swallows write errors: a lost write only
// slightly affects the next round's weighting.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/app_providers.dart';

class WordHistoryRepository {
  WordHistoryRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Versioned storage key. Changing this value requires a migration.
  static const String _storageKey = 'word_pick_counts_v1';

  /// Serializes writes so two rapid calls cannot lose updates.
  Future<void> _writeChain = Future<void>.value();

  /// Returns the pick count for each word. Words never picked are
  /// absent — treat a missing key as zero.
  Map<String, int> getPickCounts() {
    final String? raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const <String, int>{};

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const <String, int>{};

      final Map<String, int> result = <String, int>{};
      for (final MapEntry<String, dynamic> e in decoded.entries) {
        final Object? v = e.value;
        if (v is int && v > 0) result[e.key] = v;
      }
      return Map<String, int>.unmodifiable(result);
    } catch (_) {
      return const <String, int>{};
    }
  }

  /// Increments the pick count for [wordId] by one.
  ///
  /// Fire-and-forget: a lost write only slightly affects the next
  /// round's weighting, so callers do not need to await this.
  Future<void> recordPick(String wordId) async {
    try {
      await _enqueueWrite(() {
        final Map<String, int> current = Map<String, int>.of(getPickCounts());
        current[wordId] = (current[wordId] ?? 0) + 1;
        return current;
      });
    } catch (_) {
      // Intentionally swallowed — see the docstring.
    }
  }

  /// Clears all pick history. For tests and a possible future "reset
  /// history" UI; the normal game flow does not call it.
  Future<void> clear() => _enqueueWrite(() => const <String, int>{});

  Future<void> _enqueueWrite(Map<String, int> Function() computeNext) {
    final Future<void> job = _writeChain.then((_) async {
      final Map<String, int> next = computeNext();
      await _prefs.setString(_storageKey, jsonEncode(next));
    });
    _writeChain = job.catchError((Object _) {});
    return job;
  }
}

final wordHistoryRepositoryProvider = Provider<WordHistoryRepository>((ref) {
  return WordHistoryRepository(ref.watch(sharedPreferencesProvider));
});
