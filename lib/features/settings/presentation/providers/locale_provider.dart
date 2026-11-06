// locale_provider.dart
//
// Persistence and state for two related but distinct concepts.
//
//   • The app UI locale — driven by `localeProvider`, applied to
//     `MaterialApp.locale`, and reflected by every screen through
//     `AppLocalizations`. Changing it re-renders the whole app in the new
//     language.
//
//   • The in-game language mode — one of 'english', 'nepali', or 'both',
//     consumed by the game engine to decide how word content is rendered
//     on reveal cards. It is stored alongside the UI locale for
//     convenience but is otherwise independent. A user can read the app
//     in one language while displaying word content in another.
//
// Bootstrap requirement
// ---------------------
// `sharedPreferencesProvider` must be overridden with a loaded instance
// before `runApp` — see `main.dart`. `build()` reads from it
// synchronously, so if the override is missing or async, `MaterialApp`
// would fall back to its default locale and briefly flash the wrong
// language on cold start. Do not convert `localeProvider` to a
// `FutureProvider`.
//
// Persistence behaviour
// ---------------------
// `setLocale` reverts to the previous value if the write fails, so the
// app never displays a locale that will be forgotten on next launch.
//
// `setInGameLanguage` is best-effort: a failed write simply means the
// user reselects the same mode next session, which is not worth
// surfacing as an error. The write is also skipped when the persisted
// value already matches, so no-op selections do not touch disk.
//
// `inGameLanguageMode` is a synchronous getter rather than a reactive
// provider. Widgets that read it during build see the current persisted
// value, but nothing triggers a rebuild when the value changes. Callers
// that need reactive behaviour should watch `gameSetupProvider` and read
// `settings.languageMode` from there.
//
// Integration note
// ----------------
// The in-game language mode is stored here but is not yet wired into
// `GameSetupNotifier`. That notifier must persist the mode through
// `setInGameLanguage` on change and restore it via `inGameLanguageMode`
// in `build()`. Until that wiring exists, the Setup screen resets the
// mode to English each time it opens.
//
// Keys
// ----
// `_kAppLocaleKey` and `_kGameLanguageModeKey` are the persisted
// preference keys. Renaming either orphans saved preferences on existing
// installs.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';

const String _kAppLocaleKey = 'app_locale';
const String _kGameLanguageModeKey = 'game_language_mode';

const Set<String> _validGameModes = <String>{'english', 'nepali', 'both'};

const String _defaultLocaleCode = 'en';
const String _defaultGameMode = 'english';

/// Provides the app-level UI locale and persistence helpers for the
/// in-game language mode.
///
/// The two values are stored together for convenience but represent
/// different concepts — see the file header for the distinction.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final String? saved = prefs.getString(_kAppLocaleKey);
    // Treat an empty stored value as missing.
    final String code =
    (saved == null || saved.isEmpty) ? _defaultLocaleCode : saved;
    return Locale(code);
  }

  /// Sets the app UI locale and persists it.
  ///
  /// Only `Locale.languageCode` is stored; a value with a country or
  /// script code would load back as language-only on next launch.
  ///
  /// If persistence fails, `state` reverts to the previous locale so the
  /// UI never diverges from what will actually be loaded next time.
  Future<void> setLocale(Locale locale) async {
    if (state == locale) return;
    final Locale previous = state;
    state = locale;
    try {
      final bool ok = await ref
          .read(sharedPreferencesProvider)
          .setString(_kAppLocaleKey, locale.languageCode);
      if (!ok) {
        state = previous;
      }
    } catch (_) {
      state = previous;
    }
  }

  /// Persists the in-game language mode for the next Setup session.
  ///
  /// Does not modify `state` — the game mode is not the app locale. Invalid
  /// values are rejected by a debug assert and silently ignored in release.
  /// A write that fails is swallowed: the only consequence is that the user
  /// reselects the mode next session.
  Future<void> setInGameLanguage(String mode) async {
    assert(
    _validGameModes.contains(mode),
    'invalid game language mode: "$mode" (expected one of '
        '${_validGameModes.join(", ")})',
    );
    if (!_validGameModes.contains(mode)) return;

    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getString(_kGameLanguageModeKey) == mode) return;

    try {
      await prefs.setString(_kGameLanguageModeKey, mode);
    } catch (_) {
      // Best-effort persistence; see method doc.
    }
  }

  /// Returns the current persisted game language mode.
  ///
  /// Not reactive. Reads preferences synchronously on each access. Callers
  /// that need to react to changes should observe `gameSetupProvider`
  /// instead. Missing or unrecognised values fall back to [_defaultGameMode].
  String get inGameLanguageMode {
    final String? saved =
    ref.read(sharedPreferencesProvider).getString(_kGameLanguageModeKey);
    if (saved == null || !_validGameModes.contains(saved)) {
      return _defaultGameMode;
    }
    return saved;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);