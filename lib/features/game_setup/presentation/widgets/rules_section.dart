// rules_section.dart
//
// Game rules configuration: hidden imposter mode, imposter hint plus
// difficulty selection, and multiple imposters plus an optional count
// stepper.
//
// Usage note
// ----------
// This widget is not currently imported by `game_setup_screen.dart`. That
// screen renders its own inline `_RulesContainer` with the blue theme
// palette and a different visual treatment. If this file is unused, it
// should be removed to prevent the two implementations from drifting
// apart. If it is being used — for example by a settings-style screen
// showing the current rule set — the purple `AppColors` palette it uses
// here is intentional and should not be replaced with the blue palette
// without confirming where the widget renders.
//
// Layout and overflow
// -------------------
// Titles and the difficulty labels are single-line with ellipsis. The
// subtitle wraps to at most three lines, which fits the longest
// translation currently in the ARB (`hiddenImposterDisabledDesc`) and
// leaves room for a defensive ellipsis if a longer one ever lands. The
// difficulty cards sit in a three-way `Expanded` row so their widths
// always sum to the available width. The stepper's numeric label is
// single-line, and its caption row is single-line with ellipsis.
//
// The stepper's +/- buttons keep the default `IconButton` tap target of
// 48 dp, which already exceeds the 44 dp accessibility minimum. The
// difficulty cards carry explicit `Semantics` with the button role and
// selected state so their selection is announced to screen readers.
//
// Localization
// ------------
// Every user-visible string is pulled from `AppLocalizations`. There are
// no hardcoded display strings in this file.

import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../game/domain/entities/word.dart';

class RulesSection extends StatelessWidget {
  const RulesSection({
    super.key,
    required this.hiddenImposterMode,
    required this.imposterHintEnabled,
    required this.hintDifficulty,
    required this.multipleImposters,
    required this.imposterCount,
    required this.maxImposterCount,
    required this.onHiddenImposterChanged,
    required this.onImposterHintChanged,
    required this.onHintDifficultyChanged,
    required this.onMultipleImpostersChanged,
    required this.onImposterCountChanged,
  });

  final bool hiddenImposterMode;
  final bool imposterHintEnabled;
  final HintDifficulty hintDifficulty;
  final bool multipleImposters;
  final int imposterCount;
  final int maxImposterCount;
  final ValueChanged<bool> onHiddenImposterChanged;
  final ValueChanged<bool> onImposterHintChanged;
  final ValueChanged<HintDifficulty> onHintDifficultyChanged;
  final ValueChanged<bool> onMultipleImpostersChanged;
  final ValueChanged<int> onImposterCountChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool hintToggleEnabled = !hiddenImposterMode;
    final bool difficultyEnabled =
        imposterHintEnabled && !hiddenImposterMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _RuleTile(
          title: l10n.hiddenImposter,
          subtitle: l10n.hiddenImposterDesc,
          value: hiddenImposterMode,
          enabled: true,
          onChanged: onHiddenImposterChanged,
        ),
        const _Divider(),
        _RuleTile(
          title: l10n.imposterHint,
          subtitle: hiddenImposterMode
              ? l10n.hiddenImposterDisabledDesc
              : l10n.imposterHintDesc,
          value: imposterHintEnabled,
          enabled: hintToggleEnabled,
          onChanged: onImposterHintChanged,
        ),
        if (difficultyEnabled) ...<Widget>[
          const SizedBox(height: 10),
          Text(l10n.hintDifficulty, style: AppTypography.label),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _DifficultyCard(
                  label: l10n.difficultyEasy,
                  selected: hintDifficulty == HintDifficulty.easy,
                  onTap: () =>
                      onHintDifficultyChanged(HintDifficulty.easy),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DifficultyCard(
                  label: l10n.difficultyMedium,
                  selected: hintDifficulty == HintDifficulty.medium,
                  onTap: () =>
                      onHintDifficultyChanged(HintDifficulty.medium),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DifficultyCard(
                  label: l10n.difficultyHard,
                  selected: hintDifficulty == HintDifficulty.hard,
                  onTap: () =>
                      onHintDifficultyChanged(HintDifficulty.hard),
                ),
              ),
            ],
          ),
        ],
        const _Divider(),
        _RuleTile(
          title: l10n.multipleImposters,
          subtitle: l10n.multipleImpostersDesc,
          value: multipleImposters,
          enabled: true,
          onChanged: onMultipleImpostersChanged,
        ),
        if (multipleImposters) ...<Widget>[
          const SizedBox(height: 10),
          _ImposterStepper(
            count: imposterCount,
            max: maxImposterCount,
            maxLabel: l10n.stepperOfMax(
              maxImposterCount < 1 ? 1 : maxImposterCount,
            ),
            onChanged: onImposterCountChanged,
          ),
        ],
      ],
    );
  }
}

/// Row containing a rule's title and subtitle on the left and a switch on
/// the right.
///
/// When [enabled] is `false`, the row is rendered at reduced opacity and
/// the switch becomes non-interactive. The title is single-line with
/// ellipsis; the subtitle wraps to at most three lines with ellipsis.
class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTypography.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Switch(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeThumbColor: AppColors.neonPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: 1,
        color: AppColors.textSecondary.withValues(alpha: 0.15),
      ),
    );
  }
}

/// Tappable difficulty selector card.
///
/// The selected state is expressed as a brand gradient fill, a highlighted
/// border, and a soft outer shadow. The unselected state uses the surface
/// colour and a matching border. The transition between the two is handled
/// by an `AnimatedContainer` over 200 ms.
///
/// `InkWell` is used (rather than a raw `GestureDetector`) so keyboard
/// activation and desktop hover cursor work; its ripple would be drawn
/// behind the gradient and be invisible, which is why the gradient
/// transition itself provides the press feedback. `Semantics` carries the
/// button role and selected state.
class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          mouseCursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 8,
            ),
            decoration: BoxDecoration(
              color: selected ? null : AppColors.secondarySurface,
              gradient: selected ? AppColors.gradientPrimary : null,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.neonPurple
                    : AppColors.secondarySurface,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.primaryPurple
                      .withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
  }
}

/// Stepper for adjusting the number of imposters in the current round.
///
/// Both buttons are disabled at the boundaries: the decrement button when
/// the count is at 1, and the increment button when the count reaches
/// [max]. The numeric label is centred between the two buttons with the
/// "of max N" caption below it.
class _ImposterStepper extends StatelessWidget {
  const _ImposterStepper({
    required this.count,
    required this.max,
    required this.maxLabel,
    required this.onChanged,
  });

  final int count;
  final int max;
  final String maxLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final int safeMax = max < 1 ? 1 : max;
    final bool canDecrement = count > 1;
    final bool canIncrement = count < safeMax;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed:
            canDecrement ? () => onChanged(count - 1) : null,
            color: AppColors.textPrimary,
            disabledColor:
            AppColors.textSecondary.withValues(alpha: 0.4),
            tooltip: 'Decrease imposter count',
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$count',
                  style: AppTypography.headline,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  maxLabel,
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed:
            canIncrement ? () => onChanged(count + 1) : null,
            color: AppColors.textPrimary,
            disabledColor:
            AppColors.textSecondary.withValues(alpha: 0.25),
            tooltip: 'Increase imposter count',
          ),
        ],
      ),
    );
  }
}