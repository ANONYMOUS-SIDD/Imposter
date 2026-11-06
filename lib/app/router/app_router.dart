// app_router.dart
//
// Central navigation graph for the Imposter app, backed by go_router.
//
// Route map:
//   /           HomeScreen         – entry point
//   /setup      GameSetupScreen    – configure players, rules, categories
//   /reveal     SecretRevealScreen – pass-the-device secret distribution
//   /ready      GameReadyScreen    – pick who starts, then go to results
//   /result     ResultScreen       – reveal imposters and the original word
//   /settings   SettingsScreen     – audio, haptics, language, about
//
// All routes except `/ready` use a short (180ms) fade transition so the
// app feels responsive. `/ready` uses `NoTransitionPage` because both the
// source (`SecretRevealScreen`) and destination (`GameReadyScreen`) share
// the same dark blue background — an instant cut is visually seamless and
// avoids the black flash that a fade-from-zero produces between two
// identically-colored screens. Do not convert `/ready` back to a fade.
//
// Navigation is done via `context.goNamed(...)` (or `context.pushNamed`)
// using the constants in [AppRoutes]. Raw string paths should only appear
// where a `go_router` API requires a location string (deep links,
// redirect callbacks).
//
// Route destinations must remain free of async initState work that could
// delay their first frame. Asset/word preloading belongs in `main.dart`,
// not in route builders — the router is responsible for which screen to
// show, not how quickly it can render.
//
// Adding a route:
//   1. Add name/path constants to [AppRoutes].
//   2. Add a `GoRoute` entry to [_routes].
//   3. Import the screen at the top of this file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/game/presentation/screens/game_ready_screen.dart';
import '../../features/game/presentation/screens/secret_reveal_screen.dart';
import '../../features/game_setup/presentation/screens/game_setup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/results/presentation/screens/result_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

/// Route names and paths for every navigable destination in the app.
///
/// Names are used with `context.goNamed(...)` so route renames surface as
/// compile errors. Paths are used with `context.go(...)` and for deep-link
/// handling where a raw location string is unavoidable.
abstract final class AppRoutes {
  static const String home = 'home';
  static const String setup = 'setup';
  static const String reveal = 'reveal';
  static const String ready = 'ready';
  static const String result = 'result';
  static const String settings = 'settings';

  static const String homePath = '/';
  static const String setupPath = '/setup';
  static const String revealPath = '/reveal';
  static const String readyPath = '/ready';
  static const String resultPath = '/result';
  static const String settingsPath = '/settings';
}

/// Forward transition timing. Short enough to feel immediate on mid-range
/// devices; longer than ~220ms starts to read as lag.
const Duration _kPageTransitionDuration = Duration(milliseconds: 180);

/// Reverse transition timing. Slightly faster than forward, matching the
/// platform convention that back navigation feels snappier than forward.
const Duration _kPageReverseTransitionDuration = Duration(milliseconds: 140);

/// Provides the app's single [GoRouter] instance.
///
/// The router is created once per `ProviderScope` and cached for the app
/// lifetime — do not add `autoDispose`, and do not rebuild it from widget
/// code (that would reset navigation history).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.homePath,

    /// Emits navigation diagnostics to the console in debug builds only.
    /// Silent in release because [kDebugMode] is a compile-time constant.
    debugLogDiagnostics: kDebugMode,

    /// Fallback shown when a location cannot be resolved or a route builder
    /// throws. [\_RouteErrorScreen] is intentionally minimal and does not
    /// depend on providers, localization, or assets — those may themselves
    /// be the reason a route failed to build.
    errorBuilder: (context, state) => _RouteErrorScreen(error: state.error),

    /// Navigator observers (analytics, deep-link funnels) go here.
    observers: const <NavigatorObserver>[],

    routes: _routes,
  );
});

/// Complete route table.
///
/// Extracted from the provider body so tests can import the route list
/// without instantiating the provider container.
final List<GoRoute> _routes = <GoRoute>[
  GoRoute(
    path: AppRoutes.homePath,
    name: AppRoutes.home,
    pageBuilder: (context, state) => _fadePage(
      state: state,
      child: const HomeScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.setupPath,
    name: AppRoutes.setup,
    pageBuilder: (context, state) => _fadePage(
      state: state,
      child: const GameSetupScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.revealPath,
    name: AppRoutes.reveal,
    pageBuilder: (context, state) => _fadePage(
      state: state,
      child: const SecretRevealScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.readyPath,
    name: AppRoutes.ready,
    pageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: const GameReadyScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.resultPath,
    name: AppRoutes.result,
    pageBuilder: (context, state) => _fadePage(
      state: state,
      child: const ResultScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.settingsPath,
    name: AppRoutes.settings,
    pageBuilder: (context, state) => _fadePage(
      state: state,
      child: const SettingsScreen(),
    ),
  ),
];

/// Builds a [CustomTransitionPage] that fades between routes.
///
/// Used for every route except `/ready`. The fade curve accelerates out
/// so the destination feels like it "arrives" quickly and settles in. No
/// slide, scale, or shared-element motion is applied — those add perceived
/// latency without a matching UX benefit at these durations.
CustomTransitionPage<void> _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _kPageTransitionDuration,
    reverseTransitionDuration: _kPageReverseTransitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

/// Last-resort fallback rendered when [GoRouter] cannot resolve a location
/// or a route builder throws during build.
///
/// Intentionally self-contained:
///   • Layout is [Center] + [Padding] + [Column(mainAxisSize.min)] — no
///     fixed heights, safe on any screen size or text scale.
///   • Every [Text] has `maxLines` + `overflow: ellipsis` so long error
///     messages cannot overflow.
///   • Zero dependencies on providers, `AppLocalizations`, or `AppColors`
///     — those may be the reason the route failed to build.
class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.homePath),
                  child: const Text(
                    'Go Home',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}