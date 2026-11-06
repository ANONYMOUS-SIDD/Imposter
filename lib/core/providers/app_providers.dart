// settings_providers.dart
//
// Persistence and service wiring for user settings (audio, haptics).
//
// Settings live in SharedPreferences and are exposed through synchronous
// Notifier-backed providers. Each notifier reads its persisted value once
// on build and writes back on every mutation, so reading or updating a
// setting is a synchronous operation from the UI's perspective — no
// AsyncValue.loading state, no spinner, no async gap on first frame.
//
// The [sharedPreferencesProvider] throws if not overridden. `main()` must
// await `SharedPreferences.getInstance()` before `runApp` and pass the
// loaded instance as a ProviderScope override:
//
//   Future<void> main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     final prefs = await SharedPreferences.getInstance();
//     runApp(ProviderScope(
//       overrides: [
//         sharedPreferencesProvider.overrideWithValue(prefs),
//       ],
//       child: const MyApp(),
//     ));
//   }
//
// If prefs were loaded lazily (for example via a FutureProvider), every
// consumer of [audioSettingsProvider] or [hapticSettingsProvider] would
// transition through a loading state on first access. Game Setup reads
// both providers for its toggle rows, so that loading state surfaces as a
// visible flash on navigation. Awaiting prefs before runApp eliminates
// the flash entirely.
//
// Consumers should watch only the field they need:
//
//   final volume = ref.watch(audioSettingsProvider.select((s) => s.volume));
//
// Watching the whole provider rebuilds on any settings change.
//
// Persisted pref keys ([_kSoundEnabled], [_kSoundVolume], [_kHapticEnabled])
// are stable. Changing their values would orphan saved settings on
// existing installs.
//
// The [audioServiceProvider] and [hapticServiceProvider] are not
// `autoDispose` — they own platform resources that must live for the app
// lifetime.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/audio_service.dart';
import '../services/haptic_service.dart';

// Persisted pref keys. Changing these values would break existing installs
// that already have data saved under the current keys.
const String _kSoundEnabled = 'sound_enabled';
const String _kSoundVolume = 'sound_volume';
const String _kHapticEnabled = 'haptic_enabled';

/// Provides the app's single [SharedPreferences] instance.
///
/// Must be overridden in `main()` with a loaded instance (see file header).
/// The UnimplementedError guard turns a missing override into an immediate
/// failure at first access rather than a silent null or a crash deeper in
/// the widget tree.
final sharedPreferencesProvider = Provider<SharedPreferences>(
      (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main(). '
        'Await SharedPreferences.getInstance() before runApp and pass it via '
        'ProviderScope(overrides: [...overrideWithValue(prefs)]).',
  ),
);

/// Immutable snapshot of the user's audio preferences.
///
/// Value equality on [soundEnabled] and [volume] means a write with the
/// same values is a true no-op: neither the notifier's state nor any
/// listener rebuilds. Without custom [==]/[hashCode], every assignment
/// would allocate a new instance and notify consumers even for unchanged
/// values.
@immutable
class AudioSettings {
  const AudioSettings({required this.soundEnabled, required this.volume});

  /// Fallback volume when no value has been persisted yet.
  static const double defaultVolume = 0.6;

  final bool soundEnabled;

  /// Playback volume, clamped to the range `[0.0, 1.0]`.
  final double volume;

  AudioSettings copyWith({bool? soundEnabled, double? volume}) {
    return AudioSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      volume: volume ?? this.volume,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AudioSettings &&
              other.soundEnabled == soundEnabled &&
              other.volume == volume;

  @override
  int get hashCode => Object.hash(soundEnabled, volume);
}

/// Immutable snapshot of the user's haptic preferences.
@immutable
class HapticSettings {
  const HapticSettings({required this.enabled});

  final bool enabled;

  HapticSettings copyWith({bool? enabled}) {
    return HapticSettings(enabled: enabled ?? this.enabled);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is HapticSettings && other.enabled == enabled;

  @override
  int get hashCode => enabled.hashCode;
}

/// Owns the persisted audio settings and writes mutations back to disk.
///
/// State updates happen synchronously so the UI reacts on the same frame.
/// The returned [Future] from each setter resolves once the disk write
/// completes, which callers can await when they need to guarantee
/// persistence (tests, cleanup routines).
class AudioSettingsNotifier extends Notifier<AudioSettings> {
  @override
  AudioSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    // Clamp on read in case a previous version or manual edit ever wrote a
    // value outside the legal range.
    final double rawVolume =
        prefs.getDouble(_kSoundVolume) ?? AudioSettings.defaultVolume;
    return AudioSettings(
      soundEnabled: prefs.getBool(_kSoundEnabled) ?? true,
      volume: rawVolume.clamp(0.0, 1.0),
    );
  }

  /// Enables or disables sound effects. No-op if [value] is already the
  /// current state.
  Future<void> setSoundEnabled(bool value) async {
    if (state.soundEnabled == value) return;
    state = state.copyWith(soundEnabled: value);
    await ref.read(sharedPreferencesProvider).setBool(_kSoundEnabled, value);
  }

  /// Updates the playback volume. [value] is clamped to `[0.0, 1.0]`; the
  /// write is a no-op if the clamped value matches the current state.
  Future<void> setVolume(double value) async {
    final double clamped = value.clamp(0.0, 1.0);
    if (clamped == state.volume) return;
    state = state.copyWith(volume: clamped);
    await ref.read(sharedPreferencesProvider).setDouble(_kSoundVolume, clamped);
  }
}

final audioSettingsProvider =
NotifierProvider<AudioSettingsNotifier, AudioSettings>(
  AudioSettingsNotifier.new,
);

/// Owns the persisted haptic settings and writes mutations back to disk.
class HapticSettingsNotifier extends Notifier<HapticSettings> {
  @override
  HapticSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return HapticSettings(enabled: prefs.getBool(_kHapticEnabled) ?? true);
  }

  /// Enables or disables haptic feedback. No-op if [value] is already the
  /// current state.
  Future<void> setEnabled(bool value) async {
    if (state.enabled == value) return;
    state = HapticSettings(enabled: value);
    await ref.read(sharedPreferencesProvider).setBool(_kHapticEnabled, value);
  }
}

final hapticSettingsProvider =
NotifierProvider<HapticSettingsNotifier, HapticSettings>(
  HapticSettingsNotifier.new,
);

/// Owns the app-wide [AudioService] and keeps it in sync with persisted
/// settings.
///
/// Initialization order matters. The persisted state is applied
/// synchronously before the change listener is registered, so any sound
/// triggered on the first frame after this provider is read already plays
/// with the correct settings. The listener is registered for subsequent
/// changes only — `fireImmediately` is unnecessary since the current value
/// was applied directly above.
///
/// Not `autoDispose` — the service owns platform resources and must live
/// for the app lifetime.
final audioServiceProvider = Provider<AudioService>((ref) {
  final AudioService service = AudioService();
  ref.onDispose(service.dispose);

  final AudioSettings initial = ref.read(audioSettingsProvider);
  service.configure(enabled: initial.soundEnabled, volume: initial.volume);

  ref.listen<AudioSettings>(audioSettingsProvider, (_, next) {
    service.configure(enabled: next.soundEnabled, volume: next.volume);
  });

  return service;
});

/// Owns the app-wide [HapticService] and keeps it in sync with persisted
/// settings. Same initialization contract as [audioServiceProvider]:
/// initial state is applied synchronously, then a listener handles
/// subsequent changes.
final hapticServiceProvider = Provider<HapticService>((ref) {
  final HapticService service = HapticService();
  ref.onDispose(service.dispose);

  final HapticSettings initial = ref.read(hapticSettingsProvider);
  service.configure(enabled: initial.enabled);

  ref.listen<HapticSettings>(hapticSettingsProvider, (_, next) {
    service.configure(enabled: next.enabled);
  });

  return service;
});