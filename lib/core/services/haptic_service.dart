// haptic_service.dart
//
// Wrapper around the `vibration` plugin for game haptic feedback.
//
// Exposes two semantic intensities, [light] and [heavy], backed by two
// duration/amplitude pairs. Device capabilities (has vibrator, has
// amplitude control) are detected once and cached for the service
// lifetime so subsequent haptics do not pay a `MethodChannel` round-trip.
//
// Platform behavior:
//   • Android — distinct amplitudes (40 vs 180 out of 1–255) take effect on
//     devices that report amplitude control (API 26+). On devices without
//     amplitude control, the amplitude parameter is ignored by the platform
//     and the vibration fires at the system default strength, so light and
//     heavy may feel identical. This is a hardware limitation, not a bug.
//   • iOS — the plugin maps vibrate to the system haptic, which ignores both
//     duration and amplitude. Light and heavy therefore produce the same
//     single-tap feedback. If distinct iOS intensities are ever required,
//     use `HapticFeedback` from `flutter/services.dart` instead.
//   • Web, desktop, and tests — `hasVibrator` returns null or throws; the
//     service no-ops cleanly in those environments.
//
// `configure` is synchronous by design — it is called from a Riverpod
// listener on the UI thread and must not introduce a frame gap.
//
// `dispose` is synchronous so it can be passed directly to
// `ref.onDispose` (which expects `void Function()`), avoiding a discarded
// future.
//
// All failures are captured in [HapticService.lastError] and swallowed.
// Haptics must never block gameplay.

import 'package:vibration/vibration.dart';

/// One-shot haptic feedback with two semantic intensities.
class HapticService {
  bool _enabled = true;

  /// Set to `true` by [dispose]. All public methods become no-ops once this
  /// is set, so a call racing provider teardown cannot throw.
  bool _disposed = false;

  /// Cached result of `Vibration.hasVibrator()`. `null` means the capability
  /// has not been queried yet; once resolved, the value is kept for the
  /// service lifetime (a device does not gain or lose a vibrator at runtime).
  bool? _hasVibrator;

  /// Cached result of `Vibration.hasAmplitudeControl()`. Same lifecycle as
  /// [_hasVibrator].
  bool? _hasAmplitude;

  /// The most recent error caught by [_vibrate], or `null` if none occurred.
  /// Available for on-device diagnostics.
  Object? _lastError;
  Object? get lastError => _lastError;

  /// Applies the haptic enabled/disabled setting from the settings provider.
  ///
  /// Synchronous by contract: called from a Riverpod listener on the UI
  /// thread, so it must not introduce an await or a frame gap.
  void configure({required bool enabled}) => _enabled = enabled;

  /// Short, subtle feedback — button presses, chip selections, small
  /// confirmations.
  Future<void> light() => _vibrate(durationMs: 20, amplitude: 40);

  /// Stronger, longer feedback — imposter reveal, results, important
  /// confirmations.
  Future<void> heavy() => _vibrate(durationMs: 60, amplitude: 180);

  Future<void> _vibrate({
    required int durationMs,
    required int amplitude,
  }) async {
    if (_disposed || !_enabled) return;

    try {
      // Cache the vibrator capability after the first successful read.
      _hasVibrator ??= await Vibration.hasVibrator();
      if (_hasVibrator != true) return;

      // Amplitude is a no-op on devices without amplitude control. Passing
      // -1 to `Vibration.vibrate` tells the platform to use its default
      // strength — which is what those devices do anyway when an amplitude
      // is provided, so this makes the fallback explicit rather than
      // silently ignored.
      _hasAmplitude ??= await Vibration.hasAmplitudeControl();

      await Vibration.vibrate(
        duration: durationMs,
        amplitude: _hasAmplitude == true ? amplitude : -1,
      );
    } catch (e) {
      // Haptics must never block gameplay. Record and continue.
      _lastError = e;
    }
  }

  /// Marks the service as disposed.
  ///
  /// No platform resources are held today; the flag exists so a stray
  /// [light] or [heavy] call during provider teardown becomes a no-op. If a
  /// future implementation acquires resources, release them here without
  /// making this method async — the provider teardown contract expects
  /// `void Function()`.
  void dispose() {
    _disposed = true;
    _enabled = false;
  }
}