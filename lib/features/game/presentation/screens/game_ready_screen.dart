// game_ready_screen.dart
//
// Interstitial screen shown after every player has seen their secret. The
// player whose name lands on the spinning wheel is declared as the starter
// for the round, then the "SHOW RESULT" button navigates to the results
// screen.
//
// The wheel is drawn with a CustomPainter and rotates as a single unit —
// wedges and player names move together, so the whole disc behaves like a
// real spinner. Idle rotation runs at a slow constant speed; a tap starts a
// decelerating spin that lands on a random wedge. The chosen name is shown
// below the wheel inside a fixed-height slot, so the wheel itself does not
// shift when a result appears.
//
// Layout is bounded: the wheel size is clamped based on the shortest screen
// dimension, everything sits inside a single scroll view so the content can
// never overflow on short screens, and the CTA button uses a minimum height
// rather than a fixed height so it grows gracefully with large text scales.
//
// The reveal confirmation dialog is deliberately compact. Its body text is
// wrapped in a FittedBox(scaleDown) so it stays on one line regardless of
// the screen width or accessibility text scale.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../game/presentation/providers/game_session_provider.dart';

const Color _blueBright = Color(0xFF0F2250);
const Color _blueMid = Color(0xFF040A1C);
const Color _blueDeep = Color(0xFF000308);
const Color _blueGlow = Color(0xFF6BA5F0);
const Color _dialogTop = Color(0xFF0D1D42);
const Color _dialogBottom = Color(0xFF040A1C);
const Color _dividerColor = Color(0x14FFFFFF);

const Duration _kEntranceDuration = Duration(milliseconds: 350);
const Duration _kPressFeedbackDuration = Duration(milliseconds: 110);
const Duration _kSpinDuration = Duration(milliseconds: 4500);

const String _kResultRouteName = 'result';

/// Fixed height reserved for the "STARTS FROM …" line below the wheel.
///
/// The slot is always present so the wheel does not jump when the result
/// text appears or disappears.
const double _kStartsSlotHeight = 30.0;

class GameReadyScreen extends ConsumerStatefulWidget {
  const GameReadyScreen({super.key});

  @override
  ConsumerState<GameReadyScreen> createState() => _GameReadyScreenState();
}

class _GameReadyScreenState extends ConsumerState<GameReadyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _kEntranceDuration,
  )..forward();

  /// Content opacity animation. Starts at 0.85 rather than 0 so the
  /// transition from the previous screen — which uses a NoTransitionPage
  /// hard cut — does not produce a visible dark flash. The final 15% is
  /// enough to read as a gentle "materialising" of the content.
  late final Animation<double> _contentOpacity = Tween<double>(
    begin: 0.85,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
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

  /// Name picked by the wheel, or `null` until the first spin completes.
  String? _resultName;

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Shows the reveal confirmation dialog and navigates to the results
  /// screen on confirm.
  Future<void> _showRevealDialog() async {
    final AppLocalizations? l10n = AppLocalizations.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: _RevealConfirmDialog(l10n: l10n),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (!context.mounted) return;
    context.goNamed(_kResultRouteName);
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double shortestSide = size.shortestSide;

    final session = ref.watch(gameSessionProvider);
    final List<String> playerNames =
        session?.players.map((p) => p.name).toList() ?? const <String>[];
    final bool hasWheel = playerNames.length >= 2;

    final double buttonMargin = (size.width * 0.11).clamp(28.0, 64.0);
    final double buttonHeight = (shortestSide * 0.108).clamp(42.0, 50.0);
    final double bottomPad = (size.height * 0.05).clamp(20.0, 48.0);

    final AppLocalizations? l10n = AppLocalizations.of(context);
    final String ctaLabel = l10n?.showResult ?? 'SHOW RESULT';

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
                      const double reserved = 40.0;
                      final double availH =
                      (c.maxHeight - reserved).clamp(150.0, 500.0);
                      final double availW = shortestSide * 0.88;
                      final double wheelSize =
                      (availH < availW ? availH : availW)
                          .clamp(200.0, 340.0);

                      return FadeTransition(
                        opacity: _contentOpacity,
                        child: ScaleTransition(
                          scale: const AlwaysStoppedAnimation<double>(1.0),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: c.maxHeight,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    if (hasWheel) ...<Widget>[
                                      _SpinWheel(
                                        names: playerNames,
                                        size: wheelSize,
                                        onResult: (String name) {
                                          setState(() => _resultName = name);
                                          HapticFeedback.mediumImpact();
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    SizedBox(
                                      height: _kStartsSlotHeight,
                                      child: _resultName == null
                                          ? const SizedBox.shrink()
                                          : Center(
                                        child: _AnimatedTagline(
                                          text: 'STARTS FROM '
                                              '${_resultName!.toUpperCase()}',
                                          fontSize: (shortestSide *
                                              0.032)
                                              .clamp(11.0, 14.0),
                                          horizontalPadding: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                        label: ctaLabel,
                        height: buttonHeight,
                        onPressed: _showRevealDialog,
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

/// Circular wheel that picks a random player to start the round.
///
/// Two animation controllers drive the rotation:
///   • [_idleController] runs a slow continuous rotation before the first
///     spin, giving the wheel a "ready to be touched" feel.
///   • [_spinController] runs a single decelerating spin per tap. After the
///     first spin the idle controller stays stopped and only the spin
///     controller is used.
class _SpinWheel extends StatefulWidget {
  const _SpinWheel({
    required this.names,
    required this.size,
    required this.onResult,
  });

  final List<String> names;
  final double size;
  final ValueChanged<String> onResult;

  @override
  State<_SpinWheel> createState() => _SpinWheelState();
}

class _SpinWheelState extends State<_SpinWheel>
    with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _spinController;
  late Animation<double> _spinAnimation;

  bool _isSpinning = false;
  bool _hasSpun = false;
  double _currentAngle = 0;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    // Defer the idle rotation until after the first frame. Starting it in
    // initState forces the wheel to rebuild on frame 1, which adds a
    // measurable delay to the first render of this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _idleController.repeat();
    });
    _spinController = AnimationController(
      vsync: this,
      duration: _kSpinDuration,
    );
    _spinAnimation = Tween<double>(begin: 0, end: 0).animate(_spinController);
    _spinController.addStatusListener(_handleSpinStatus);
    _idleController.addListener(() {
      if (!_hasSpun && mounted) {
        setState(() {
          _currentAngle = _idleController.value * 2 * math.pi;
        });
      }
    });
  }

  @override
  void dispose() {
    _idleController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  /// Resolves the winning wedge from the spin controller's final angle and
  /// reports it through [widget.onResult].
  void _handleSpinStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    final int count = widget.names.length;
    if (count == 0) {
      setState(() => _isSpinning = false);
      return;
    }

    final double segmentAngle = 2 * math.pi / count;
    final double finalAngle = _spinAnimation.value;
    final double normalized =
        (finalAngle % (2 * math.pi) + 2 * math.pi) % (2 * math.pi);
    final double rawIndex =
        ((-normalized / segmentAngle) % count + count) % count;
    final int index = rawIndex.floor() % count;

    setState(() {
      _isSpinning = false;
      _currentAngle = finalAngle;
    });

    widget.onResult(widget.names[index]);
  }

  /// Starts a spin. Only one spin can be in flight at a time.
  ///
  /// The target angle is calculated relative to the current angle so that
  /// every tap produces the same visual spin — several full rotations plus
  /// the delta needed to bring a randomly chosen wedge under the pointer.
  /// A small random offset is applied so the wheel does not always stop
  /// dead-centre on a wedge boundary.
  void _handleTap() {
    if (_isSpinning || widget.names.length < 2) return;

    _idleController.stop();

    final math.Random random = math.Random();
    final int count = widget.names.length;
    final double segmentAngle = 2 * math.pi / count;

    final int targetIndex = random.nextInt(count);
    final double offset = (random.nextDouble() - 0.5) * segmentAngle * 0.55;

    final double desiredAngle = -targetIndex * segmentAngle + offset;

    final double currentNorm = _currentAngle % (2 * math.pi);
    final double desiredNorm =
        (desiredAngle % (2 * math.pi) + 2 * math.pi) % (2 * math.pi);
    double delta = desiredNorm - currentNorm;
    if (delta < 0) delta += 2 * math.pi;

    final int fullRotations = 5 + random.nextInt(3);
    final double target =
        _currentAngle + delta + 2 * math.pi * fullRotations;

    _spinAnimation =
        Tween<double>(begin: _currentAngle, end: target).animate(
          CurvedAnimation(
            parent: _spinController,
            curve: Curves.easeOutCubic,
          ),
        );

    setState(() {
      _hasSpun = true;
      _isSpinning = true;
    });

    _spinController.reset();
    _spinController.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.names.isEmpty) return const SizedBox.shrink();

    final double size = widget.size;

    return Semantics(
      button: true,
      label: 'Spin the wheel to pick who starts',
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              AnimatedBuilder(
                animation: _spinController.isAnimating
                    ? _spinController
                    : _idleController,
                builder: (BuildContext context, Widget? child) {
                  final double angle = _hasSpun && _spinController.isAnimating
                      ? _spinAnimation.value
                      : (_hasSpun
                      ? _currentAngle
                      : _idleController.value * 2 * math.pi);
                  return Transform.rotate(
                    angle: angle,
                    child: child,
                  );
                },
                // Rasterized once and reused across rotation frames; the
                // wheel's wedges and names do not repaint while spinning.
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.square(size),
                    painter: _WheelPainter(names: widget.names),
                    isComplex: true,
                    willChange: false,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: const _OuterRingPainter(),
                  ),
                ),
              ),
              Positioned(
                top: -size * 0.015,
                child: SizedBox(
                  width: size * 0.048,
                  height: size * 0.072,
                  child: CustomPaint(
                    painter: const _IosPointerPainter(),
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

/// Paints the wheel's wedges and their radial player names.
///
/// Each wedge is drawn with a linear gradient from its inner edge to its
/// outer edge, giving the disc a subtle depth. Names are laid out along
/// the wedge's mid-radius so they follow the wedge's angle; on the left
/// half of the wheel the rotation is flipped so the text remains readable.
class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.names});

  final List<String> names;

  static const List<List<Color>> _pairs = <List<Color>>[
    <Color>[Color(0xFF6B2DB5), Color(0xFF1F0645)],
    <Color>[Color(0xFF2A5BC7), Color(0xFF061A4D)],
    <Color>[Color(0xFF1E9BBF), Color(0xFF042633)],
    <Color>[Color(0xFFB52238), Color(0xFF3D0512)],
    <Color>[Color(0xFF5C3A9E), Color(0xFF150A32)],
    <Color>[Color(0xFF11547A), Color(0xFF021725)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final int count = names.length;
    if (count == 0) return;

    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final double sweep = 2 * math.pi / count;

    for (int i = 0; i < count; i++) {
      final double startAngle = -math.pi / 2 + i * sweep;
      final double midAngle = startAngle + sweep / 2;
      final List<Color> pair = _pairs[i % _pairs.length];

      final Path path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle, sweep, false)
        ..close();

      final Alignment begin =
      Alignment(-math.cos(midAngle), -math.sin(midAngle));
      final Alignment end =
      Alignment(math.cos(midAngle), math.sin(midAngle));

      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: begin,
            end: end,
            colors: pair,
          ).createShader(rect),
      );

      final Offset lineEnd = Offset(
        center.dx + radius * math.cos(startAngle),
        center.dy + radius * math.sin(startAngle),
      );
      canvas.drawLine(
        center,
        lineEnd,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );

      if (names[i].isNotEmpty) {
        final double textRadius = radius * 0.62;
        final double textX = center.dx + textRadius * math.cos(midAngle);
        final double textY = center.dy + textRadius * math.sin(midAngle);

        double rotation = midAngle;
        if (math.cos(midAngle) < 0) {
          rotation += math.pi;
        }

        canvas.save();
        canvas.translate(textX, textY);
        canvas.rotate(rotation);

        final double fontSize = (radius * 0.072).clamp(11.0, 15.0);
        final TextStyle nameStyle = AppTypography.caption.copyWith(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          shadows: <Shadow>[
            Shadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        );

        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: names[i].toUpperCase(),
            style: nameStyle,
          ),
          maxLines: 1,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          ellipsis: '…',
        );
        textPainter.layout(maxWidth: radius * 0.55);
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) {
    if (oldDelegate.names.length != names.length) return true;
    for (int i = 0; i < names.length; i++) {
      if (oldDelegate.names[i] != names[i]) return true;
    }
    return false;
  }
}

/// Paints the ring around the wheel and the small hub at its centre.
class _OuterRingPainter extends CustomPainter {
  const _OuterRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      center,
      radius * 0.06,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      radius * 0.06,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(_OuterRingPainter oldDelegate) => false;
}

/// Paints the small pointer that hangs above the wheel.
class _IosPointerPainter extends CustomPainter {
  const _IosPointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Path path = Path()
      ..moveTo(w * 0.10, 0)
      ..lineTo(w * 0.90, 0)
      ..lineTo(w * 0.90, h * 0.55)
      ..quadraticBezierTo(w * 0.90, h * 0.85, w * 0.50, h)
      ..quadraticBezierTo(w * 0.10, h * 0.85, w * 0.10, h * 0.55)
      ..close();

    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: 0.55),
      2,
      false,
    );
    canvas.drawPath(path, Paint()..color = const Color(0xFF6BA5F0));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_IosPointerPainter oldDelegate) => false;
}

/// Confirmation dialog shown when the user taps "SHOW RESULT".
///
/// The body text is wrapped in a FittedBox(scaleDown) so it stays on a
/// single line at any screen width or accessibility text scale.
class _RevealConfirmDialog extends StatelessWidget {
  const _RevealConfirmDialog({required this.l10n});

  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    const String title = 'Ready To Reveal';
    const String body = 'Are You Sure Want To Reveal Imposter';
    final String cancelLabel = (l10n?.cancel ?? 'Cancel').toUpperCase();
    final String confirmLabel = (l10n?.revealNow ?? 'Reveal').toUpperCase();

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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      body,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
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
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  Container(width: 1, color: _dividerColor),
                  Expanded(
                    child: _IosDialogButton(
                      label: confirmLabel,
                      primary: true,
                      onTap: () => Navigator.pop(context, true),
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

/// Text with a slow-moving horizontal gradient sweep.
///
/// Used for the "STARTS FROM …" line below the wheel. The gradient is a
/// five-stop gradient that repeats on a 7-second cycle. The widget is
/// wrapped in a RepaintBoundary so the continuously animating shader does
/// not force surrounding widgets to repaint.
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
    final double spacing = (widget.fontSize * 0.18).clamp(1.6, 2.4);

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

/// Radial background gradient with a slowly drifting particle field.
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

/// Primary call-to-action button used on this screen.
///
/// Uses a three-stop horizontal gradient and a scale-based press feedback
/// instead of an ink ripple (which would be hidden under the gradient).
/// A [ConstrainedBox] with a minimum height keeps the button usable at
/// small text scales while still allowing it to grow with large ones.
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
            duration: _kPressFeedbackDuration,
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

/// Flat action button used inside the reveal confirmation dialog.
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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