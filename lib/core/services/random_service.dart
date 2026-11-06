// random_service.dart
//
// Injectable source of randomness used for role assignment, word selection,
// and list shuffling.
//
// Routing every random operation through a provider-backed interface lets
// tests swap in a deterministic PRNG and assert exact outputs for a given
// seed. Production code uses the default time-seeded implementation.
//
// The RNG is not cryptographically secure. Do not use it for tokens,
// passwords, or anything security-sensitive.
//
// Both implementations of [RandomService] enforce `max > 0` with an assert.
// Passing 0 or a negative value is a programming error, not a runtime
// condition — callers must guard empty lists before calling
// `nextInt(list.length)`.
//
// The provider is intentionally not `autoDispose`. Its internal PRNG state
// must persist across screen rebuilds; recreating it on every frame would
// reset the "randomness" and bias small draws.

import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of randomness shared by the app.
///
/// Implementations hold PRNG state and are not safe to share across
/// isolates.
abstract interface class RandomService {
  /// Returns a uniformly distributed integer in the range `[0, max)`.
  ///
  /// `max` must be greater than zero; this is a programming-error check,
  /// not a recoverable runtime state. Callers must guard empty lists
  /// before calling `nextInt(list.length)`.
  int nextInt(int max);

  /// Shuffles [list] in place using the service's RNG.
  ///
  /// No-op for lists with zero or one element.
  void shuffle<T>(List<T> list);
}

/// Production implementation backed by `dart:math`'s [Random].
///
/// The optional [Random] parameter is intended for tests that want to share
/// a single seeded source; production code should use the no-argument
/// constructor so the seed comes from the clock.
class DefaultRandomService implements RandomService {
  DefaultRandomService({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  int nextInt(int max) {
    assert(max > 0, 'nextInt(max) requires max > 0 (got $max)');
    return _random.nextInt(max);
  }

  @override
  void shuffle<T>(List<T> list) => list.shuffle(_random);
}

/// Deterministic implementation for tests.
///
/// Two instances constructed with the same seed produce identical
/// sequences, so role assignment and word selection can be asserted
/// exactly.
@visibleForTesting
class SeededRandomService implements RandomService {
  SeededRandomService(int seed) : _random = Random(seed);

  final Random _random;

  @override
  int nextInt(int max) {
    assert(max > 0, 'nextInt(max) requires max > 0 (got $max)');
    return _random.nextInt(max);
  }

  @override
  void shuffle<T>(List<T> list) => list.shuffle(_random);
}

/// Provides the app-wide [RandomService].
///
/// Tests should override this provider with [SeededRandomService] to make
/// role assignment and word selection deterministic.
final randomServiceProvider = Provider<RandomService>(
      (ref) => DefaultRandomService(),
);