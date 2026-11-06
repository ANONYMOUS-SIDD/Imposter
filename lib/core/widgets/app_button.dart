// app_button.dart
//
// Primary call-to-action widget used across the app for anything that
// triggers a game action: starting a game, revealing secrets, submitting
// forms. Two visual variants share one widget so call-sites stay consistent
// and the layout logic lives in one place.
//
// Variants:
//   • Primary — brand gradient with a soft purple shadow. Used for the main
//     action on a screen.
//   • Secondary — flat surface color. Used for adjacent or lower-priority
//     actions.
//
// Press feedback is a short scale animation rather than an ink ripple. The
// ripple would render underneath the custom gradient and be effectively
// invisible, so the scale provides crisper feedback on touch. Ripple
// suppression is intentional.
//
// The button supports three states that must remain visually and
// semantically distinct:
//   • Enabled — full color, accepts taps.
//   • Disabled (`onPressed == null`) — muted colors, no interaction, cursor
//     stays default on desktop.
//   • Loading (`isLoading == true`) — interaction is blocked and a spinner
//     overlays the label. The label stays laid out underneath so the button
//     does not resize when loading toggles.
//
// The label is single-line by design. It truncates with ellipsis when the
// available width is too narrow, and the button grows vertically to meet
// the minimum 52dp touch target. Combined with the `Flexible` wrapper
// around the label, this widget will not overflow in narrow containers or
// at large accessibility text scales.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.icon,
  });

  /// Single-line label shown inside the button. Long labels are ellipsized,
  /// so CTAs should stay short.
  final String label;

  /// Tap handler. Passing `null` disables the button: colors are muted, the
  /// button does not respond to taps, and the cursor returns to default on
  /// desktop.
  final VoidCallback? onPressed;

  /// `true` for the brand-gradient primary variant, `false` for the muted
  /// secondary variant.
  final bool isPrimary;

  /// When `true`, interaction is blocked and a spinner fades in over the
  /// label. The label remains in the layout so the button does not resize.
  final bool isLoading;

  /// Optional leading icon rendered to the left of the label.
  final IconData? icon;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.96,
    upperBound: 1.0,
  )..value = 1.0;

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isLoading || widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  void _handleTapDown(TapDownDetails _) => _scale.animateTo(0.96);
  void _handleTapUp(TapUpDetails _) => _scale.animateTo(1.0);
  void _handleTapCancel() => _scale.animateTo(1.0);

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.isLoading;
    final bool isPrimary = widget.isPrimary;

    final Color activeColor =
    isPrimary ? AppColors.textBright : AppColors.textPrimary;
    final Color contentColor =
    enabled ? activeColor : AppColors.textSecondary;

    final TextStyle labelStyle = AppTypography.title.copyWith(
      color: contentColor,
    );

    final Color spinnerColor =
    isPrimary ? AppColors.textBright : AppColors.neonPurple;

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? _handleTap : null,
          onTapDown: enabled ? _handleTapDown : null,
          onTapUp: enabled ? _handleTapUp : null,
          onTapCancel: enabled ? _handleTapCancel : null,
          borderRadius: BorderRadius.circular(18),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          mouseCursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: AnimatedBuilder(
            animation: _scale,
            builder: (context, child) => Transform.scale(
              scale: _scale.value,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                gradient: isPrimary && enabled
                    ? AppColors.gradientPrimary
                    : null,
                color: isPrimary
                    ? (enabled
                    ? null
                    : AppColors.primaryPurple.withValues(alpha: 0.35))
                    : AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: isPrimary && enabled
                    ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primaryPurple
                        .withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: widget.isLoading ? 0.0 : 1.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (widget.icon != null) ...<Widget>[
                          Icon(
                            widget.icon,
                            size: 20,
                            color: contentColor,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            style: labelStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: widget.isLoading
                        ? SizedBox(
                      key: const ValueKey<String>('__spinner__'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: spinnerColor,
                      ),
                    )
                        : const SizedBox.shrink(
                      key: ValueKey<String>('__empty__'),
                    ),
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