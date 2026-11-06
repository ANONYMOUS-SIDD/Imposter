// game_setup_providers.dart
//
// Draft state for the Game Setup screen plus the validation and start flow
// that hands the configured draft off to `gameSessionProvider`.
//
// State
// -----
// GameSetupState holds everything the user configures before a round
// begins: player names, language mode, hidden-imposter and hint options,
// category selection, and the include-custom-words toggle. It is a
// draft — nothing here is secret. Secret role and word assignment is
// performed by `gameSessionProvider` when `startGame` succeeds.
//
// Persistence
// -----------
// Two pieces of state survive between sessions:
//   • The selected category ids, saved as a string list under the key
//     `selected_categories_v1`. `build()` reads it back on first access.
//   • The in-game language mode, saved through `localeProvider`. This is
//     separate from the app's UI locale — a user can read the app in one
//     language while playing words in another.
//
// Reads of shared preferences are synchronous, so this notifier builds
// with fully populated state on the first frame. No loading state is
// required anywhere downstream.
//
// Validation
// ----------
// `validate()` returns a human-readable error string for the first
// problem it finds (fewer than three players, empty names, duplicate
// names, no category selected, or an imposter count outside the legal
// range) or `null` when the draft is ready. `startGame` calls `validate`
// before invoking the engine, and surfaces the engine's own error text
// when session creation fails.
//
// Note that `startGame` catches its own exceptions and returns them as
// strings. The caller is expected to display the returned error message
// and skip navigation on non-null returns.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../game/domain/entities/game_settings.dart';
import '../../../game/domain/entities/word.dart';
import '../../../game/presentation/providers/game_session_provider.dart';
import '../../../settings/presentation/providers/locale_provider.dart';

/// Draft state for the game being configured on the Setup screen.
class GameSetupState {
  const GameSetupState({
    required this.playerNames,
    required this.settings,
  });

  final List<String> playerNames;
  final GameSettings settings;

  GameSetupState copyWith({
    List<String>? playerNames,
    GameSettings? settings,
  }) =>
      GameSetupState(
        playerNames: playerNames ?? this.playerNames,
        settings: settings ?? this.settings,
      );

  /// Baseline state used by [GameSetupNotifier.build] before applying any
  /// persisted values.
  static GameSetupState initial() {
    return const GameSetupState(
      playerNames: <String>[],
      settings: GameSettings(
        languageMode: 'english',
        hiddenImposterMode: false,
        imposterHintEnabled: false,
        hintDifficulty: HintDifficulty.easy,
        multipleImposters: false,
        imposterCount: 1,
        selectedCategoryIds: <String>{},
        includeCustomWords: false,
      ),
    );
  }
}

class GameSetupNotifier extends Notifier<GameSetupState> {
  @override
  GameSetupState build() {
    final initial = GameSetupState.initial();
    final prefs = ref.watch(sharedPreferencesProvider);

    final savedMode =
        ref.read(localeProvider.notifier).inGameLanguageMode;

    final saved = prefs.getStringList('selected_categories_v1');
    if (saved == null || saved.isEmpty) {
      return initial.copyWith(
        settings: initial.settings.copyWith(languageMode: savedMode),
      );
    }
    return initial.copyWith(
      settings: initial.settings.copyWith(
        languageMode: savedMode,
        selectedCategoryIds: saved.toSet(),
      ),
    );
  }

  /// Appends a player with a default `Player N` name.
  ///
  /// The number is derived from the current player count. Callers that
  /// want to preserve a specific naming scheme should pass names through
  /// [addPlayerNamed] instead.
  void addPlayer() {
    final next = state.playerNames.length + 1;
    final updated = [...state.playerNames, 'Player $next'];
    state = state.copyWith(playerNames: updated);
    _recalcImposterCountIfNeeded();
  }

  /// Appends a player with an explicit name. Whitespace is trimmed; a
  /// whitespace-only name is ignored.
  void addPlayerNamed(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final updated = [...state.playerNames, trimmed];
    state = state.copyWith(playerNames: updated);
    _recalcImposterCountIfNeeded();
  }

  /// Removes the player at [index]. Out-of-range indices are ignored.
  void removePlayer(int index) {
    if (index < 0 || index >= state.playerNames.length) return;
    final updated = [...state.playerNames]..removeAt(index);
    state = state.copyWith(playerNames: updated);
    _recalcImposterCountIfNeeded();
  }

  /// Replaces the name at [index] without trimming. Use this only when
  /// the field is mid-edit — validation trims at the point of use.
  void updatePlayerName(int index, String name) {
    if (index < 0 || index >= state.playerNames.length) return;
    final updated = [...state.playerNames];
    updated[index] = name;
    state = state.copyWith(playerNames: updated);
  }

  /// Moves the player at [from] to position [to]. No-op if either index is
  /// out of range or the two indices are equal.
  void movePlayer(int from, int to) {
    if (from < 0 || from >= state.playerNames.length) return;
    if (to < 0 || to >= state.playerNames.length) return;
    if (from == to) return;
    final updated = [...state.playerNames];
    final item = updated.removeAt(from);
    updated.insert(to, item);
    state = state.copyWith(playerNames: updated);
  }

  /// Updates the in-game language mode and persists it for the next
  /// session. Unknown values are ignored.
  void setLanguageMode(String mode) {
    if (mode != 'english' && mode != 'nepali' && mode != 'both') return;
    state = state.copyWith(
      settings: state.settings.copyWith(languageMode: mode),
    );
    ref.read(localeProvider.notifier).setInGameLanguage(mode);
  }

  /// Toggles hidden imposter mode.
  ///
  /// Enabling hidden mode also disables the imposter hint, since a visible
  /// hint would tip the imposter off. Disabling hidden mode does not
  /// restore the previous hint setting — the user must re-enable the
  /// hint themselves.
  void setHiddenImposterMode(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        hiddenImposterMode: value,
        imposterHintEnabled:
        value ? false : state.settings.imposterHintEnabled,
      ),
    );
  }

  /// Toggles the imposter hint. Ignored while hidden imposter mode is on.
  void setImposterHintEnabled(bool value) {
    if (state.settings.hiddenImposterMode) return;
    state = state.copyWith(
      settings: state.settings.copyWith(imposterHintEnabled: value),
    );
  }

  /// Updates the hint difficulty.
  void setHintDifficulty(HintDifficulty difficulty) {
    state = state.copyWith(
      settings: state.settings.copyWith(hintDifficulty: difficulty),
    );
  }

  /// Toggles the "include custom words" flag.
  void setIncludeCustomWords(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(includeCustomWords: value),
    );
  }

  /// Toggles multiple-imposter mode. Turning it off forces the count to
  /// exactly one. Turning it on recalculates the count for the current
  /// player count.
  void setMultipleImposters(bool value) {
    final updated = state.settings.copyWith(
      multipleImposters: value,
      imposterCount: value ? state.settings.imposterCount : 1,
    );
    state = state.copyWith(settings: updated);
    if (value) _recalcImposterCountIfNeeded();
  }

  /// Sets the imposter count, clamped to the legal range for the current
  /// number of players. Ignored when fewer than three players are present.
  void setImposterCount(int count) {
    final max = _maxImposters(state.playerNames.length);
    if (max < 1) return;
    final clamped = count.clamp(1, max);
    state = state.copyWith(
      settings: state.settings.copyWith(imposterCount: clamped),
    );
  }

  /// Adds or removes a category from the selection and persists the result.
  void toggleCategory(String categoryId) {
    final current = Set<String>.from(state.settings.selectedCategoryIds);
    if (current.contains(categoryId)) {
      current.remove(categoryId);
    } else {
      current.add(categoryId);
    }
    state = state.copyWith(
      settings: state.settings.copyWith(selectedCategoryIds: current),
    );
    _persistCategories(current);
  }

  /// Replaces the category selection with [ids] and persists the result.
  void selectAllCategories(Iterable<String> ids) {
    final set = Set<String>.from(ids);
    state = state.copyWith(
      settings: state.settings.copyWith(selectedCategoryIds: set),
    );
    _persistCategories(set);
  }

  /// Clears the category selection and persists the empty result.
  void clearAllCategories() {
    state = state.copyWith(
      settings: state.settings.copyWith(selectedCategoryIds: <String>{}),
    );
    _persistCategories(<String>{});
  }

  /// Returns the first validation error in the current draft, or `null`
  /// when the draft is ready to start.
  ///
  /// Checks are ordered from most to least fundamental: player count,
  /// name integrity, then category and imposter count.
  String? validate() {
    final names = state.playerNames;

    if (names.length < 3) {
      return 'At least 3 players are required.';
    }

    final trimmed = names.map((n) => n.trim()).toList();
    if (trimmed.any((n) => n.isEmpty)) {
      return 'All players must have a name.';
    }

    final lowercased = trimmed.map((n) => n.toLowerCase()).toList();
    if (lowercased.toSet().length != lowercased.length) {
      return 'Player names must be unique.';
    }

    if (state.settings.selectedCategoryIds.isEmpty) {
      return 'Select at least one category.';
    }

    if (state.settings.multipleImposters) {
      final max = _maxImposters(names.length);
      if (state.settings.imposterCount < 1 ||
          state.settings.imposterCount > max) {
        return 'Imposter count must be between 1 and $max.';
      }
    }

    return null;
  }

  /// Validates the draft and starts a session with the given [availableWords].
  ///
  /// Returns `null` on success and a human-readable error string on
  /// failure. The error is either a validation message from [validate] or
  /// the message from the engine's own exception.
  String? startGame({required List<Word> availableWords}) {
    final err = validate();
    if (err != null) return err;

    final names = state.playerNames.map((n) => n.trim()).toList();
    final max = _maxImposters(names.length);
    final imposterCount = state.settings.multipleImposters
        ? state.settings.imposterCount.clamp(1, max)
        : 1;

    final finalSettings = state.settings.copyWith(
      imposterCount: imposterCount,
    );

    try {
      ref.read(gameSessionProvider.notifier).start(
        names: names,
        settings: finalSettings,
        availableWords: availableWords,
      );
      return null;
    } catch (e) {
      return 'Failed to start game: $e';
    }
  }

  void _persistCategories(Set<String> ids) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setStringList('selected_categories_v1', ids.toList());
  }

  /// Recalculates the imposter count when the player list changes and
  /// multiple-imposter mode is active. The count is set to the engine's
  /// default for the new player count, clamped to the legal range.
  void _recalcImposterCountIfNeeded() {
    if (!state.settings.multipleImposters) return;
    final engine = ref.read(gameEngineProvider);
    final suggested = engine.defaultImposterCount(state.playerNames.length);
    final max = engine.maxImposters(state.playerNames.length);
    if (max < 1) return;
    final clamped = suggested.clamp(1, max);
    state = state.copyWith(
      settings: state.settings.copyWith(imposterCount: clamped),
    );
  }

  int _maxImposters(int playerCount) {
    return ref.read(gameEngineProvider).maxImposters(playerCount);
  }
}

final gameSetupProvider = NotifierProvider<GameSetupNotifier, GameSetupState>(
  GameSetupNotifier.new,
);