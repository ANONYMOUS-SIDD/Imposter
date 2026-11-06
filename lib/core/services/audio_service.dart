// audio_service.dart
//
// Wrapper around the `audioplayers` plugin for short, one-shot game sound
// effects.
//
// The service owns a single native `AudioPlayer` for the app lifetime.
// Playback calls are serialized through a future chain so rapid taps
// produce a clean sequence of SFX rather than overlapping interruptions
// that some platforms reject. The native player is kept warm between
// playbacks (`ReleaseMode.stop`) so replayed sounds start with minimal
// latency, and asset bytes are preloaded once at startup so the first
// tap of any sound is not noticeably slow.
//
// `init` should be invoked exactly once during startup, before the first
// `play`. Calling `play` without `init` still works, but the first
// playback of each sound will be slower because the assets are loaded on
// demand. The recommended call-site is a post-frame callback in
// `main.dart` so the initialization does not delay the first frame.
//
// `configure` is synchronous by design — it is called from a Riverpod
// listener on the UI thread and must not introduce a frame gap.
//
// All failures are captured in [AudioService.lastError] and swallowed.
// Audio must never block gameplay or crash the caller.
//
// The service is created and disposed by `audioServiceProvider`; callers
// must not dispose it manually.

import 'package:audioplayers/audioplayers.dart';

/// Toggles whether any audio is attempted at all.
///
/// The app currently ships without the mp3 sound-effect files. While this
/// flag is `false`, `init` and `play` return immediately without touching
/// the native player or the asset bundle — no missing-asset warnings and
/// no console noise on startup.
///
/// To enable audio:
///   1. Place the mp3s under `assets/audio/` (button_tap, card_reveal,
///      card_close, game_ready, final_reveal).
///   2. Confirm `pubspec.yaml` lists `- assets/audio/` under
///      `flutter: assets:`.
///   3. Change this constant to `true` and run `flutter pub get`.
const bool kAudioAvailable = false;

/// Short sound effects bundled under `assets/audio/`.
enum GameSound {
  buttonTap('audio/button_tap.mp3'),
  cardReveal('audio/card_reveal.mp3'),
  cardClose('audio/card_close.mp3'),
  gameReady('audio/game_ready.mp3'),
  finalReveal('audio/final_reveal.mp3');

  const GameSound(this.assetPath);

  /// Asset-bundle path, e.g. `audio/button_tap.mp3`.
  final String assetPath;
}

/// One-shot sound-effect player shared across the app.
class AudioService {
  AudioService() : _player = AudioPlayer();

  final AudioPlayer _player;

  /// Whether playback is currently permitted. Mirrors the audio-settings
  /// provider — `configure` keeps this in sync with the persisted state.
  bool _enabled = true;

  /// Current volume, `[0.0, 1.0]`.
  double _volume = 0.6;

  /// Last volume actually pushed to the native player. Used to skip
  /// redundant `MethodChannel` round-trips when the volume has not changed
  /// between playbacks.
  double? _appliedVolume;

  /// Set to `true` by [dispose]. All public methods become no-ops once this
  /// is set, so a play call racing teardown cannot throw.
  bool _disposed = false;

  /// Serializes calls into [_doPlay]. Each `play` chains onto the previous
  /// one so two rapid taps run strictly sequentially.
  Future<void> _playChain = Future<void>.value();

  /// The most recent error encountered by [init], [play], or [dispose], or
  /// `null` if none occurred. Available for on-device diagnostics.
  Object? _lastError;
  Object? get lastError => _lastError;

  bool get enabled => _enabled;
  double get volume => _volume;

  /// Applies audio settings from the audio-settings provider.
  ///
  /// Synchronous by contract: called from a Riverpod listener on the UI
  /// thread, so it must not introduce an await or a frame gap.
  void configure({required bool enabled, required double volume}) {
    _enabled = enabled;
    _volume = volume.clamp(0.0, 1.0);
  }

  /// Warms up the native player and preloads every asset in [GameSound].
  ///
  /// Idempotent — safe to call multiple times. Returns immediately if the
  /// service has been disposed or if [kAudioAvailable] is `false`.
  Future<void> init() async {
    if (!kAudioAvailable) return;
    if (_disposed) return;
    try {
      // Keep the native player alive between playbacks so replayed sounds
      // do not pay the plugin's default release-and-reacquire cost.
      await _player.setReleaseMode(ReleaseMode.stop);

      // Preload every asset into the shared AudioCache so the first
      // playback of each sound is not slowed by bundle decoding.
      for (final GameSound sound in GameSound.values) {
        await AudioCache.instance.load(sound.assetPath);
      }
    } catch (e) {
      // Init is best-effort. A failure means the first play of each sound
      // will be slower, not that audio is broken — record and continue.
      _lastError = e;
    }
  }

  /// Plays [sound] once, serialized after any in-flight playback.
  ///
  /// Never throws — failures are recorded in [lastError] and swallowed.
  ///
  /// Concurrency note: calls are queued rather than overlapping. The
  /// `audioplayers` plugin offers `AudioPool` for truly simultaneous
  /// playback (one native player per source), but with only five short
  /// SFX the serialized single-player approach is lighter and adequate
  /// for this game's tap / reveal pattern.
  Future<void> play(GameSound sound) {
    if (!kAudioAvailable) return Future<void>.value();
    if (_disposed || !_enabled) return Future<void>.value();

    // Chain onto the previous call. The tail-swallowing catchError keeps
    // a single failed playback from permanently poisoning the chain.
    final Future<void> job = _playChain.then((_) => _doPlay(sound));
    _playChain = job.catchError((Object _) {});
    return job;
  }

  Future<void> _doPlay(GameSound sound) async {
    // Re-check after awaiting the chain — dispose may have run meanwhile.
    if (_disposed || !_enabled) return;
    try {
      await _player.stop();

      // Skip the MethodChannel round-trip when the volume has not changed
      // since the last successful apply.
      if (_appliedVolume != _volume) {
        await _player.setVolume(_volume);
        _appliedVolume = _volume;
      }

      await _player.play(AssetSource(sound.assetPath));
    } catch (e) {
      _lastError = e;
    }
  }

  /// Releases the native player. Idempotent.
  ///
  /// The synchronous part (setting [_disposed]) happens immediately so any
  /// in-flight [play] becomes a no-op on its next await; the actual
  /// native dispose continues in the background.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _player.dispose();
    } catch (_) {
      // Swallow — the service is already marked disposed and callers
      // cannot recover from a dispose failure.
    }
  }
}