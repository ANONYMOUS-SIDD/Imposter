// home_screen.dart
//
// Home screen — the entry point of the app. Shows a hero imposter image,
// an animated "NEVER TRUST ANYONE" tagline, and a primary START GAME
// button that navigates to the Game Setup screen.
//
// Navigation
// ----------
// The START GAME button uses `pushNamed` rather than `goNamed` so that
// pressing the system back button from Game Setup returns to Home instead
// of exiting the app. `pushNamed` returns a Future that completes when
// the pushed route pops; a reentrancy flag is set for the duration of
// that Future so a rapid double-tap cannot push two Setup screens onto
// the stack. Once the Future completes and Home is visible again, the
// flag is cleared and the button accepts input once more.
//
// Startup performance
// -------------------
// This screen performs no async work of its own. Anything the Setup
// screen needs on its first frame — prefs, word list, audio service — is
// warmed by `main.dart` after `runApp` returns, so by the time the user
// taps START GAME, all of it is already resolved. The result is that the
// Setup screen appears instantly with populated data rather than with a
// brief loading state.
//
// Layout
// ------
// Hero image size is computed from both screen width and available
// height, clamped to a reasonable range, so it stays proportional on
// small phones and does not dominate tablets. The button uses a minimum
// height and a Flexible label, so at large accessibility text scales it
// grows rather than clipping. The tagline is single-line with ellipsis.
// No dimension in the content column is fixed except the icon inside the
// button, which is an icon (not text) and therefore cannot overflow.
//
// The tagline is intentionally hardcoded English. It is a stylized
// Quicksand w900 hero line; Devanagari does not render that weight and
// visual treatment gracefully, so localizing it would degrade the design.
// The START GAME button label, by contrast, is fully localized.
//
// All decorative animations (tagline gradient sweep, drifting particle
// field) are wrapped in RepaintBoundary so their 60fps repaints do not
// invalidate the rest of the widget tree. The entrance animation is a
// one-shot staggered fade + scale + slide; it does not loop.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_typography.dart';

const Color _blueBright = Color(0xFF0F2250);
const Color _blueMid = Color(0xFF040A1C);
const Color _blueDeep = Color(0xFF000308);
const Color _blueGlow = Color(0xFF6BA5F0);

/// Route name used for the START GAME navigation. Must match the `name`
/// field of the setup route in `app_router.dart`.
const String _kSetupRouteName = 'setup';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the one-shot entrance of the content and the button. Content
  /// begins fading and scaling in immediately; the button begins its fade
  /// and slide partway through, creating a staggered arrival.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..forward();

  late final Animation<double> _contentOpacity = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
  );

  late final Animation<double> _contentScale = Tween<double>(
    begin: 0.94,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
  ));

  late final Animation<double> _buttonOpacity = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
  );

  late final Animation<Offset> _buttonSlide = Tween<Offset>(
    begin: const Offset(0, 0.25),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
  ));

  /// Set while the Setup route is on the stack. Prevents a second tap on
  /// START GAME from pushing another instance of Setup before the first
  /// one pops.
  bool _navigating = false;

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Navigates to the Setup screen and clears the navigation lock once the
  /// user returns to Home.
  Future<void> _handleStart() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    try {
      await context.pushNamed(_kSetupRouteName);
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final shortestSide = size.shortestSide;

    final taglineMargin = (size.width * 0.08).clamp(20.0, 48.0);
    final buttonMargin = (size.width * 0.11).clamp(28.0, 64.0);
    final buttonHeight = (shortestSide * 0.108).clamp(42.0, 50.0);
    final bottomPad = (size.height * 0.05).clamp(20.0, 48.0);

    return Scaffold(
      backgroundColor: _blueDeep,
      body: Stack(
        children: <Widget>[
          const _DeepBlueBackground(),
          SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final maxBySide = shortestSide * 0.85;
                      final maxByHeight = c.maxHeight * 0.80;
                      final imageSize =
                      (maxBySide < maxByHeight ? maxBySide : maxByHeight)
                          .clamp(100.0, 480.0);
                      final taglineGap =
                      (size.height * 0.028).clamp(8.0, 32.0);

                      return FadeTransition(
                        opacity: _contentOpacity,
                        child: ScaleTransition(
                          scale: _contentScale,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Transform.translate(
                                  offset: const Offset(0, 22),
                                  child: _ImposterImage(size: imageSize),
                                ),
                                SizedBox(height: taglineGap),
                                Transform.translate(
                                  offset: const Offset(8, 0),
                                  child: _AnimatedTagline(
                                    text: 'NEVER TRUST ANYONE',
                                    fontSize: (shortestSide * 0.030)
                                        .clamp(10.0, 13.0),
                                    horizontalPadding: taglineMargin,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                FadeTransition(
                  opacity: _buttonOpacity,
                  child: SlideTransition(
                    position: _buttonSlide,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: buttonMargin,
                        right: buttonMargin,
                        bottom: bottomPad,
                      ),
                      child: _BlueGradientButton(
                        label: l10n.startGame.toUpperCase(),
                        height: buttonHeight,
                        onPressed: _handleStart,
                      ),
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

/// Single-line tagline with a slow horizontal gradient sweep.
///
/// The gradient cycles every 7 seconds and is isolated behind a
/// `RepaintBoundary` so its continuous repaints do not invalidate the
/// surrounding widget tree. The text is single-line with ellipsis, so it
/// never wraps or pushes its container past the available width.
class _AnimatedTagline extends StatefulWidget {
  const _AnimatedTagline({
    required this.text,
    required this.fontSize,
    required this.horizontalPadding,
  });

  final String text;
  final double fontSize;
  final double horizontalPadding;

  @override
  State<_AnimatedTagline> createState() => _AnimatedTaglineState();
}

class _AnimatedTaglineState extends State<_AnimatedTagline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  static const Color _colorSlate = Color(0xFF8F9DBA);
  static const Color _colorLavender = Color(0xFFA48EE0);
  static const Color _colorBlue = Color(0xFF6B95E0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double spacing = (widget.fontSize * 0.25).clamp(2.4, 3.4);

    final TextStyle style = AppTypography.caption.copyWith(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: spacing,
      height: 1.3,
    );

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
        child: Center(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? _) {
                final double shift = -1.5 + 3.0 * _controller.value;
                return ShaderMask(
                  shaderCallback: (Rect bounds) => LinearGradient(
                    begin: Alignment(shift - 1, 0),
                    end: Alignment(shift + 1, 0),
                    colors: const <Color>[
                      _colorSlate,
                      _colorLavender,
                      _colorBlue,
                      _colorLavender,
                      _colorSlate,
                    ],
                    stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
                  ).createShader(bounds),
                  child: Text(
                    widget.text,
                    textAlign: TextAlign.center,
                    style: style.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Radial background gradient with a slow-drifting particle field overlaid.
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
    // RepaintBoundary keeps the 60fps particle repaints isolated from the
    // rest of the tree.
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

/// Hero imposter image with a graceful fallback.
///
/// `cacheWidth` is derived from the display size and device pixel ratio so
/// the image is decoded at approximately its on-screen resolution rather
/// than at the asset's native resolution. If the asset is missing or fails
/// to load, a glowing icon is shown in its place, sized and themed to match
/// the layout.
class _ImposterImage extends StatelessWidget {
  const _ImposterImage({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int cacheWidth = (size * dpr).round();

    return Semantics(
      image: true,
      label: 'Imposter character',
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'assets/images/imposter1.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.medium,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stack) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: <Color>[_blueGlow, _blueMid],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _blueGlow.withValues(alpha: 0.55),
                    blurRadius: 50,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.visibility_rounded,
                size: 100,
                color: Colors.white70,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Primary CTA on the Home screen.
///
/// Uses a horizontal three-stop gradient for its fill and a scale/opacity
/// animation for press feedback. The ripple would be drawn behind the
/// gradient and be effectively invisible, so it is disabled and the scale
/// animation carries the feedback instead. The button's minimum height is
/// provided by the caller; the label uses a Flexible row with ellipsis so
/// long or localized labels truncate instead of pushing the row past the
/// button's width.
class _BlueGradientButton extends StatefulWidget {
  const _BlueGradientButton({
    required this.label,
    required this.height,
    required this.onPressed,
  });

  final String label;
  final double height;
  final VoidCallback onPressed;

  @override
  State<_BlueGradientButton> createState() => _BlueGradientButtonState();
}

class _BlueGradientButtonState extends State<_BlueGradientButton> {
  bool _pressed = false;

  static const Color _gradLeft = Color(0xFF020817);
  static const Color _gradMid = Color(0xFF0F2E73);
  static const Color _gradRight = Color(0xFF020817);

  void _handleTap() {
    HapticFeedback.mediumImpact();
    widget.onPressed();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: BorderRadius.circular(14),
          mouseCursor: SystemMouseCursors.click,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _pressed ? 0.88 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                constraints: BoxConstraints(minHeight: widget.height),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[_gradLeft, _gradMid, _gradRight],
                    stops: <double>[0.0, 0.5, 1.0],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _blueDeep,
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: _blueMid.withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: Offset.zero,
                    ),
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.label,
                            style: AppTypography.title.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}