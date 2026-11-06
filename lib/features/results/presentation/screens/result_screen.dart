// result_screen.dart
//
// Final results screen. Presents the imposter names and the secret word
// after all players have seen their secret. The user reveals the results
// by swiping a covering card upward, and can then either play another
// round with the same players and settings or return to Home.
//
// Swipe interaction
// -----------------
// A card covers the results until the user drags it upward. Releasing the
// card above a threshold value snaps it fully open and leaves the results
// visible while the user reads them. Releasing below the threshold snaps
// the card back to closed. The reveal state is latched once the card
// crosses the threshold during the drag, so haptic feedback fires exactly
// once per reveal.
//
// The drag delta is normalised against the card's actual measured height
// (from a `LayoutBuilder` inside `SafeArea`) rather than the screen
// height, so the threshold and release animation feel consistent across
// devices with different safe-area insets.
//
// Play Again flow
// ---------------
// `_playAgain` builds the word pool from the previous session's settings,
// then starts a fresh session. Two details matter here:
//
//   1. Custom words must be included when EITHER the settings flag is on
//      OR the 'custom' category is selected. `includeCustomWords` and
//      `selectedCategoryIds` can drift: the Setup screen's `toggleCategory`
//      writes the set without touching the flag, so a session that starts
//      with "only custom words selected" would otherwise pass an empty
//      word pool to `startGame` on the second round and fail validation.
//      Checking both fields prevents that.
//
//   2. `start()` on the session notifier does not throw; it returns
//      whether the session was created and stores the reason on the
//      notifier when it was not. To detect failure across both the old
//      throwing implementation and the current returning implementation,
//      the old session instance is captured before the call and compared
//      to the current instance afterward. Any change means the session
//      was replaced; an identical reference means creation failed and the
//      user is shown an inline error instead of being navigated away
//      from the results.
//
// Layout and overflow
// -------------------
// The top 55% of the screen holds the swipe card and is clipped by
// `ClipRRect`, so the card's contents cannot overflow the layout. The
// bottom 45% is a `SingleChildScrollView` containing the info and action
// container, so tall content (imposter names plus word plus hint plus two
// actions) scrolls rather than pushing the layout off the screen.
//
// `_ImposterRevealContent` wraps its column in a `SingleChildScrollView`
// with a `Center` so that a large number of imposters or an extreme text
// scale scrolls instead of overflow. `_InfoRow` uses a fixed-width label
// column and a `_AutoShrinkWord` value column so long values shrink to
// fit instead of overflowing. Dialog buttons use a minimum height rather
// than a fixed height. All dialog and action labels carry `maxLines` with
// ellipsis.
//
// Localization
// ------------
// The error snackbar and the session-lost screen pull their strings from
// `AppLocalizations`. The following strings are still hardcoded English
// and are candidates for a future localization pass:
//   • "THE IMPOSTER", "ORIGINAL WORD", "HINT WORD"
//   • "PLAY AGAIN", "BACK TO HOME"
//   • Dialog titles, bodies, and button labels (Start A New Round, Ready
//     To Play Again, PLAY, CANCEL, Back To Home, Your Current Round Will
//     End, LEAVE)
//
// Audio
// -----
// The final-reveal sound effect is triggered in a post-frame callback so
// it does not delay the first render of this screen.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/audio_service.dart';
import '../../../custom_words/data/custom_words_repository.dart';
import '../../../game/data/word_repository.dart';
import '../../../game/domain/entities/game_engine.dart';
import '../../../game/domain/entities/player.dart';
import '../../../game/domain/entities/word.dart';
import '../../../game/presentation/providers/game_session_provider.dart';

const Color _blueBright = Color(0xFF0F2250);
const Color _blueMid = Color(0xFF040A1C);
const Color _blueDeep = Color(0xFF000308);
const Color _blueGlow = Color(0xFF6BA5F0);
const Color _cyanGlow = Color(0xFF22D3EE);
const Color _deepRed = Color(0xFF8B1E32);
const Color _darkRed = Color(0xFF4A0F1E);
const Color _dialogTop = Color(0xFF0D1D42);
const Color _dialogBottom = Color(0xFF040A1C);
const Color _dividerColor = Color(0x14FFFFFF);

/// Card value below which the drag counts as a full reveal. The card
/// snaps fully open above this threshold and back to fully closed below
/// it.
const double _revealThreshold = 0.55;

/// Lowest value the card can be dragged to. Ensures the card never
/// disappears completely off-screen during a drag.
const double _minCardValue = 0.15;

/// How long to wait before showing the Lottie hint that teaches the
/// swipe gesture.
const Duration _inactivityDelay = Duration(milliseconds: 3200);

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cardController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1.0,
  );

  /// Set once the card has crossed the reveal threshold during this
  /// visit. Latches so haptic feedback fires exactly once per reveal.
  bool _hasRevealed = false;

  bool _showLottieHint = false;
  Timer? _inactivityTimer;

  /// Frozen copies of the word and hint, populated on the first build
  /// with a live session and never updated afterward.
  ///
  /// Why this exists: tapping "PLAY AGAIN" calls
  /// `gameSessionProvider.notifier.start(...)`, which synchronously
  /// replaces the session — including `originalWord` and `imposterHint`
  /// — before `context.goNamed('reveal')` swaps routes. Riverpod then
  /// notifies this widget, which rebuilds for one frame with the *new*
  /// word still painted in the `_ActionContainer`, producing a visible
  /// flash of the next round's secret before the reveal screen's card
  /// covers it.
  ///
  /// Freezing the displayed values at first build keeps the previous
  /// round's word on screen during that brief transition window, which
  /// is what the player already knows and expects to see. The result
  /// screen never legitimately needs the live values after mount: the
  /// only action that mutates the session is Play Again, and that
  /// navigates away immediately.
  String? _frozenOriginalWord;
  String? _frozenHintWord;

  @override
  void initState() {
    super.initState();
    _armInactivityTimer();
    // Play the reveal sound after the first frame so the audio call does
    // not delay the initial render of this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(audioServiceProvider).play(GameSound.finalReveal));
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _cardController.dispose();
    super.dispose();
  }

  void _armInactivityTimer() {
    _inactivityTimer?.cancel();
    _showLottieHint = false;
    _inactivityTimer = Timer(_inactivityDelay, () {
      if (mounted && !_hasRevealed) {
        setState(() => _showLottieHint = true);
      }
    });
  }

  void _disarmInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_showLottieHint) {
      setState(() => _showLottieHint = false);
    }
  }

  void _onDragStart(DragStartDetails d) {
    _cardController.stop();
    _disarmInactivityTimer();
  }

  /// Updates the card position during a drag.
  ///
  /// [cardHeight] is the card's actual measured height from the enclosing
  /// [LayoutBuilder], so the delta is normalised against the real card
  /// rather than the full screen. Reaching the reveal threshold latches
  /// [_hasRevealed] and fires haptic feedback exactly once.
  void _onDragUpdate(DragUpdateDetails d, double cardHeight) {
    if (cardHeight <= 0) return;
    final double delta = d.delta.dy / cardHeight;
    final double newValue =
    (_cardController.value + delta).clamp(_minCardValue, 1.0);
    _cardController.value = newValue;
    if (newValue < _revealThreshold && !_hasRevealed) {
      setState(() => _hasRevealed = true);
      HapticFeedback.heavyImpact();
    }
  }

  /// Completes the drag. Past the threshold the card snaps open and stays
  /// open so the user can read the results; below the threshold it snaps
  /// back to fully closed.
  void _onDragEnd(DragEndDetails d) {
    if (_cardController.value < _revealThreshold) {
      _cardController.animateTo(
        _minCardValue,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _cardController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInCubic,
      );
    }
  }

  /// Builds a fresh session with the same players and settings and
  /// navigates to the reveal screen.
  ///
  /// Custom words are included when EITHER `includeCustomWords` is true
  /// OR the `custom` category is selected — the two fields can drift (see
  /// the file header), and using OR prevents an empty word pool on the
  /// second round.
  ///
  /// Detects session-creation failure by comparing the session instance
  /// before and after the call: an identical reference means the notifier
  /// did not replace it, which signals that `start()` rejected the inputs.
  /// On failure, shows an inline error and leaves the current results on
  /// screen so the user can retry.
  Future<void> _playAgain() async {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    final GameSession? session = ref.read(gameSessionProvider);
    if (session == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: _ConfirmDialog(
          title: 'Start A New Round',
          body: 'Ready To Play Again',
          cancelLabel: 'CANCEL',
          confirmLabel: 'PLAY',
          onCancel: () => Navigator.pop(ctx, false),
          onConfirm: () => Navigator.pop(ctx, true),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final List<Word> bundledWords = await ref.read(allWordsProvider.future);
      if (!mounted) return;

      // Include custom words when either source says so. The two fields
      // can drift because `toggleCategory` writes `selectedCategoryIds`
      // without updating `includeCustomWords`, so a session created from
      // "only custom words selected" would otherwise pass an empty pool
      // to `startGame` on the second round.
      final bool includeCustom = session.settings.includeCustomWords ||
          session.settings.selectedCategoryIds.contains('custom');
      final List<Word> availableWords = includeCustom
          ? <Word>[...bundledWords, ...ref.read(customWordsProvider)]
          : bundledWords;

      final List<String> names =
      session.players.map((Player p) => p.name).toList();

      final GameSession? oldSession = ref.read(gameSessionProvider);
      ref.read(gameSessionProvider.notifier).start(
        names: names,
        settings: session.settings,
        availableWords: availableWords,
      );
      if (identical(oldSession, ref.read(gameSessionProvider))) {
        throw StateError('Failed to create new session');
      }

      if (mounted) context.goNamed('reveal');
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackbar(
        l10n?.failedStartNewRound.toUpperCase() ?? 'FAILED TO START NEW ROUND',
      );
    }
  }

  /// Shows the error snackbar used when starting a new round fails. The
  /// message is presented as a styled container rather than the default
  /// SnackBar background.
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[_dialogTop, _dialogBottom],
            ),
            border: Border.all(
              color: _deepRed.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 16,
                color: _deepRed,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.90),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Asks the user to confirm leaving the current round and, if they
  /// agree, navigates back to Home.
  Future<void> _confirmBackToHome() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: _ConfirmDialog(
          title: 'Back To Home',
          body: 'Your Current Round Will End',
          cancelLabel: 'CANCEL',
          confirmLabel: 'LEAVE',
          onCancel: () => Navigator.pop(ctx, false),
          onConfirm: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      context.goNamed('home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameSession? session = ref.watch(gameSessionProvider);

    if (session == null) {
      return _SessionLostScreen(
        onBackHome: () => context.goNamed('home'),
      );
    }

    final String mode = session.settings.languageMode;
    final List<Player> imposters = session.imposters;

    // Freeze word and hint on first build. See field docstring for why.
    _frozenOriginalWord ??= session.originalWord.localized.resolve(mode);
    _frozenHintWord ??= session.imposterHint.resolve(mode);
    final String originalWord = _frozenOriginalWord!;
    final String hintWord = _frozenHintWord!;
    final bool showHint = session.settings.imposterHintEnabled ||
        session.settings.hiddenImposterMode;

    return Scaffold(
      backgroundColor: _blueDeep,
      body: Stack(
        children: <Widget>[
          const _DeepBlueBackground(),
          SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  flex: 55,
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final double cardHeight = c.maxHeight;
                      return ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(32),
                        ),
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: _ImposterRevealContent(
                                  imposters: imposters,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: GestureDetector(
                                onVerticalDragStart: _onDragStart,
                                onVerticalDragUpdate:
                                    (DragUpdateDetails d) =>
                                    _onDragUpdate(d, cardHeight),
                                onVerticalDragEnd: _onDragEnd,
                                behavior: HitTestBehavior.opaque,
                                child: AnimatedBuilder(
                                  animation: _cardController,
                                  builder: (BuildContext context, Widget? child) {
                                    final double offset =
                                        -cardHeight *
                                            (1 - _cardController.value);
                                    return Transform.translate(
                                      offset: Offset(0, offset),
                                      child: child,
                                    );
                                  },
                                  // The card subtree is built once; only
                                  // the transform rebuilds each frame.
                                  child: _RevealCard(
                                    showLottieHint: _showLottieHint,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: 45,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: _ActionContainer(
                      originalWord: originalWord,
                      hintWord: showHint ? hintWord : null,
                      onPlayAgain: _playAgain,
                      onBackHome: _confirmBackToHome,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Covering card that the user swipes upward to reveal the results.
///
/// The card carries the background gradient, an image, several vignette
/// layers, and an optional Lottie hint that appears after inactivity.
class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.showLottieHint});
  final bool showLottieHint;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF1A1442),
              Color(0xFF0F0A28),
              Color(0xFF05030F),
            ],
            stops: <double>[0.0, 0.55, 1.0],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 32,
              spreadRadius: -6,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: _cyanGlow.withValues(alpha: 0.18),
              blurRadius: 52,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 260,
                child: Image.asset(
                  'assets/images/imposter2.png',
                  fit: BoxFit.contain,
                  errorBuilder:
                      (BuildContext context, Object e, StackTrace? s) {
                    return Center(
                      child: Icon(
                        Icons.person_search_rounded,
                        size: 120,
                        color: _blueGlow.withValues(alpha: 0.5),
                      ),
                    );
                  },
                ),
              ),

              if (showLottieHint)
                Positioned(
                  bottom: -80,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Lottie.asset(
                        'assets/animations/Scene.json',
                        height: 260,
                        fit: BoxFit.contain,
                        errorBuilder: (BuildContext context, Object e,
                            StackTrace? s) =>
                        const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),

              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(32),
                      ),
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: <Color>[
                          Colors.transparent,
                          const Color(0xFF243B52)
                              .withValues(alpha: 0.55),
                        ],
                        stops: const <double>[0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 100,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          _blueDeep.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Content shown underneath the swipe card — the imposter names on a
/// warning-themed background.
///
/// Uses `SingleChildScrollView` with a `Center` so that many imposters or
/// a large accessibility text scale scrolls inside the card rather than
/// overflowing.
class _ImposterRevealContent extends StatelessWidget {
  const _ImposterRevealContent({required this.imposters});

  final List<Player> imposters;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.3,
          colors: <Color>[_deepRed, _darkRed, _blueMid],
          stops: <double>[0.0, 0.5, 1.0],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[_deepRed, _darkRed],
                  ),
                  border: Border.all(
                    color: _deepRed.withValues(alpha: 0.8),
                    width: 2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _deepRed.withValues(alpha: 0.45),
                      blurRadius: 28,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'THE IMPOSTER',
                style: AppTypography.label.copyWith(
                  fontSize: 12,
                  letterSpacing: 3.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              for (final Player imposter in imposters) ...<Widget>[
                Text(
                  imposter.name.toUpperCase(),
                  style: AppTypography.display.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: const Color(0xFFDCDCE6),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Card below the swipe area containing the original word, the optional
/// hint, and the two actions.
class _ActionContainer extends StatelessWidget {
  const _ActionContainer({
    required this.originalWord,
    required this.hintWord,
    required this.onPlayAgain,
    required this.onBackHome,
  });

  final String originalWord;
  final String? hintWord;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.025),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: _blueMid.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _InfoRow(
                icon: Icons.text_fields_rounded,
                iconColor: _blueGlow,
                label: 'ORIGINAL WORD',
                value: originalWord,
              ),
              const _Divider(),
              if (hintWord != null) ...<Widget>[
                _InfoRow(
                  icon: Icons.lightbulb_outline_rounded,
                  iconColor: _deepRed,
                  label: 'HINT WORD',
                  value: hintWord!,
                ),
                const _Divider(),
              ],
              _ActionRow(
                icon: Icons.refresh_rounded,
                iconColor: _blueGlow,
                label: 'PLAY AGAIN',
                onTap: onPlayAgain,
              ),
              const _Divider(),
              _ActionRow(
                icon: Icons.home_rounded,
                iconColor: const Color(0xFFB39DFF),
                label: 'BACK TO HOME',
                onTap: onBackHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only row that pairs an icon and label with a right-aligned value.
///
/// The label column uses a fixed width so that "ORIGINAL WORD" and
/// "HINT WORD" occupy the same horizontal space. Without this, the
/// different label lengths would push their value columns to different
/// starting positions, and the right-aligned values would not end at the
/// same x-coordinate across rows. The value column is `Expanded` and uses
/// `_AutoShrinkWord` so long values shrink rather than overflow.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  /// Width reserved for the label column so both info rows align their
  /// value columns at the same x-coordinate.
  static const double _labelColumnWidth = 128;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = AppTypography.label.copyWith(
      fontSize: 11,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w800,
      color: Colors.white.withValues(alpha: 0.62),
    );
    final TextStyle valueStyle = AppTypography.label.copyWith(
      fontSize: 13,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w800,
      color: Colors.white.withValues(alpha: 0.72),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: _labelColumnWidth,
            child: Text(
              label,
              style: labelStyle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _AutoShrinkWord(
                text: value.toUpperCase(),
                baseFontSize: 13,
                minFontSize: 10,
                style: valueStyle,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text that shrinks to fit the available width rather than overflowing.
///
/// Measures the text at the base font size and, if it does not fit the
/// available width, computes the largest font size between [minFontSize]
/// and [baseFontSize] that does fit. If even [minFontSize] is too wide,
/// falls back to an ellipsized single line.
///
/// Allocates two `TextPainter` instances per build. That cost is
/// acceptable for the two uses on this screen (original word and hint
/// word) but should not be copied into a `ListView` without caching.
class _AutoShrinkWord extends StatelessWidget {
  const _AutoShrinkWord({
    required this.text,
    required this.baseFontSize,
    required this.minFontSize,
    required this.style,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final double baseFontSize;
  final double minFontSize;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final TextScaler textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        if (maxWidth <= 0 || !maxWidth.isFinite) {
          return Text(
            text,
            style: style.copyWith(fontSize: baseFontSize),
            textAlign: textAlign,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          );
        }

        final TextPainter basePainter = TextPainter(
          text: TextSpan(
            text: text,
            style: style.copyWith(fontSize: baseFontSize),
          ),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout();

        if (basePainter.width <= maxWidth) {
          return Text(
            text,
            style: style.copyWith(fontSize: baseFontSize),
            textAlign: textAlign,
            maxLines: 1,
            softWrap: false,
          );
        }

        final double ratio = maxWidth / basePainter.width;
        final double newSize =
        (baseFontSize * ratio).clamp(minFontSize, baseFontSize);

        final TextPainter shrunkPainter = TextPainter(
          text: TextSpan(
            text: text,
            style: style.copyWith(fontSize: newSize),
          ),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout();

        if (shrunkPainter.width <= maxWidth) {
          return Text(
            text,
            style: style.copyWith(fontSize: newSize),
            textAlign: textAlign,
            maxLines: 1,
            softWrap: false,
          );
        }

        return Text(
          text,
          style: style.copyWith(fontSize: minFontSize),
          textAlign: textAlign,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// Tappable row that performs an action — Play Again or Back to Home.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.label.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: iconColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

/// Shared confirmation dialog used for both "Play Again" and "Back to
/// Home" flows. The two flows differ only in their title, body, and
/// confirm label.
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_dialogTop, _dialogBottom],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.title.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(height: 1, color: _dividerColor),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _IosDialogButton(
                      label: cancelLabel,
                      onTap: onCancel,
                    ),
                  ),
                  Container(width: 1, color: _dividerColor),
                  Expanded(
                    child: _IosDialogButton(
                      label: confirmLabel,
                      primary: true,
                      onTap: onConfirm,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat action button used inside the confirmation dialogs.
///
/// Uses a minimum height rather than a fixed height so the label grows
/// with large text scales rather than clipping.
class _IosDialogButton extends StatelessWidget {
  const _IosDialogButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Center(
              child: Text(
                label,
                style: AppTypography.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: primary
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.88),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback shown when the results screen is reached without a session —
/// for example through a deep link, a restored state, or a misrouted
/// navigation. Explains the problem and provides a way back to Home.
class _SessionLostScreen extends StatelessWidget {
  const _SessionLostScreen({required this.onBackHome});
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    final String title = l10n?.gameSessionNotFound ?? 'Game Session Not Found';
    final String cta = (l10n?.backToHome ?? 'Back to Home').toUpperCase();

    return Scaffold(
      backgroundColor: _blueDeep,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  size: 56,
                  color: _blueGlow.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: AppTypography.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onBackHome,
                    borderRadius: BorderRadius.circular(14),
                    mouseCursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.transparent,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        cta,
                        style: AppTypography.title.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

/// Radial background gradient with a slow-drifting particle field.
class _DeepBlueBackground extends StatelessWidget {
  const _DeepBlueBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.30),
          radius: 1.40,
          colors: <Color>[_blueBright, _blueMid, _blueDeep],
          stops: <double>[0.0, 0.50, 1.0],
        ),
      ),
      child: const _ParticleField(),
    );
  }
}

class _ParticleField extends StatefulWidget {
  const _ParticleField();

  @override
  State<_ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<_ParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary keeps the particle repaints isolated from the rest
    // of the tree.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) => CustomPaint(
          painter: _ParticlePainter(_controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.progress);

  final double progress;

  static final List<Offset> _positions = List<Offset>.generate(26, (int i) {
    final double r = ((i * 37) % 100) / 100.0;
    final double g = ((i * 73) % 100) / 100.0;
    return Offset(r, g);
  });

  static final Paint _paint = Paint()
    ..color = _blueGlow.withValues(alpha: 0.18);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _positions.length; i++) {
      final Offset p = _positions[i];
      final double dy =
          (p.dy - progress * (0.015 + (i % 5) * 0.004)) % 1.0;
      final double radius = 1.5 + (i % 3);
      canvas.drawCircle(
        Offset(p.dx * size.width, dy * size.height),
        radius,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}