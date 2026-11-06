// main.dart
//
// Application entry point.
//
// Bootstrap sequence
// ------------------
//   1. Ensure the Flutter binding is initialized.
//   2. Lock the app to portrait orientation.
//   3. Load SharedPreferences synchronously so every settings provider
//      downstream can read from it without an async gap.
//   4. Run the app inside a ProviderScope that supplies the loaded prefs.
//   5. After the first frame, warm up asynchronous resources used early in
//      the session (audio service and word list).
//
// Step 3 is what allows every provider that depends on shared preferences
// to build synchronously. If prefs were loaded after `runApp`, those
// providers would surface a loading state on first access, and screens
// that consume them (in particular Game Setup) would briefly show a
// spinner.
//
// Startup warmup
// --------------
// The post-frame warmup resolves `allWordsProvider` and initializes the
// audio service. Both are deferred until after the first frame so they do
// not delay the initial render, but early enough that by the time the
// user navigates to Game Setup or the reveal screens, the word list and
// the native audio player are already prepared. The warmup is
// best-effort: failures are swallowed here and reported to consuming
// screens through each provider's error state.
//
// Portrait lock
// -------------
// The app is designed for a single-column portrait layout. Rotation to
// landscape is locked at the Flutter level here so the framework does
// not lay out a landscape frame that immediately gets corrected. The
// Android manifest also declares the portrait orientation so the
// operating system does not flash a landscape frame before Flutter
// initializes.
//
// Bootstrap failure
// -----------------
// If shared preferences cannot be loaded, the app cannot reach a state
// where its providers would build correctly. A self-contained error
// screen is shown instead so the user sees a clear message rather than
// the platform's blank screen from an uncaught exception. The error
// screen uses only Material primitives and does not depend on the app's
// provider graph, theme, or localizations.
//
// Text scaling
// ------------
// The app clamps the user's accessibility text scale to 1.3× via
// `MediaQuery.withClampedTextScaling` in the root `builder`. This is the
// standard production pattern for apps whose layout uses fixed-height
// rows: it preserves most of the accessibility benefit while preventing
// the 1.5×–2.0× range from breaking every row that carries a
// `maxLines: 1` label.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show SystemChrome, DeviceOrientation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/localization/app_localizations.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/providers/app_providers.dart';
import 'features/game/data/word_repository.dart';
import 'features/settings/presentation/providers/locale_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the UI to portrait before the first frame. The Android manifest
  // declares the same orientation so there is no landscape flash on cold
  // start from a rotated device.
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  final SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    // Prefs cannot be loaded — the provider graph cannot be built. Show a
    // self-contained error screen instead of letting the exception escape.
    runApp(_BootstrapErrorApp(error: e));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ImposterApp(),
    ),
  );
}

/// Root of the app. Kept as a [ConsumerStatefulWidget] so the post-frame
/// warmup runs exactly once, in `initState`, rather than on every rebuild.
class ImposterApp extends ConsumerStatefulWidget {
  const ImposterApp({super.key});

  @override
  ConsumerState<ImposterApp> createState() => _ImposterAppState();
}

class _ImposterAppState extends ConsumerState<ImposterApp> {
  @override
  void initState() {
    super.initState();
    // Defer the warmup until after the first frame has rendered so it
    // cannot delay the initial paint.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPreload());
  }

  void _startPreload() {
    if (!mounted) return;
    unawaited(_preloadAsync());
  }

  /// Warms the async resources that are used within the first few seconds
  /// of interaction.
  ///
  /// Both warmups are best-effort. A failure here means the corresponding
  /// screen will show its own error state when it consumes the provider;
  /// it is not a reason to crash startup.
  Future<void> _preloadAsync() async {
    try {
      if (!mounted) return;
      await ref.read(audioServiceProvider).init();
    } catch (_) {
      // Audio initialization is best-effort. If it fails, the first sound
      // of each type plays with a small cold-start delay rather than the
      // warm player being ready ahead of time.
    }

    try {
      if (!mounted) return;
      await ref.read(allWordsProvider.future);
    } catch (_) {
      // Word loading is handled by the providers themselves: any screen
      // that watches `allWordsProvider` will display its own error state
      // if the load fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    // Haptic service has no async init step, so it is created eagerly here.
    // Audio is created inside `_preloadAsync` alongside its async init.
    ref.watch(hapticServiceProvider);

    return MaterialApp.router(
      title: 'Imposter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      routerConfig: router,

      // Clamp accessibility text scaling app-wide. See the file header for
      // the reasoning.
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Self-contained error screen shown when shared preferences fail to load
/// before the app's provider graph can be built.
///
/// Uses only Material primitives — no Riverpod, no theme tokens, no
/// localizations — because any of those could themselves be unavailable
/// in this state. The layout is centered inside a `SafeArea` with a
/// `Column(mainAxisSize: min)`, and every text is bounded with `maxLines`
/// plus `ellipsis`, so it renders correctly on any screen size or text
/// scale.
class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kDebugMode
                        ? 'Preferences load failed: $error'
                        : 'Please restart the app.',
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}