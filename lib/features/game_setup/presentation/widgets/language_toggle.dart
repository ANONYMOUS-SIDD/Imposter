// language_toggle.dart
//
// Three-way language selector used on the Game Setup screen.
//
// Renders three equal-width segments (English, Nepali, Both). The selected
// segment is highlighted with a gradient fill, a thin border, and slightly
// brighter text. All three visual properties are animated together so the
// selection transitions smoothly instead of snapping.
//
// The AnimatedContainer's gradient and border are declared for both the
// selected and unselected states rather than being set to null when
// unselected. This lets Flutter lerp between the two decorations by
// interpolating alpha values instead of toggling properties on or off,
// which produces a smooth cross-fade in both directions.
//
// Layout is fixed: each segment is 30 logical pixels tall with a 3-pixel
// outer padding, keeping the control visually compact. The label in each
// segment is single-line with ellipsis, so long labels or large text
// scales truncate instead of overflowing the segment. Segment width is
// determined by `Expanded`, so the control fills its parent's width
// regardless of content.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

const Color _blueMid = Color(0xFF040A1C);
const String _englishMode = 'english';
const String _nepaliMode = 'nepali';
const String _bothMode = 'both';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: Colors.white.withValues(alpha: 0.025),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 10)),
          BoxShadow(color: _blueMid.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: -4),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: <Widget>[
            Expanded(child: _LanguageSegment(label: 'ENGLISH', semanticsLabel: 'English', selected: value == _englishMode, onTap: () => onChanged(_englishMode))),
            const SizedBox(width: 4),
            Expanded(child: _LanguageSegment(label: 'नेपाली', semanticsLabel: 'Nepali', selected: value == _nepaliMode, onTap: () => onChanged(_nepaliMode))),
            const SizedBox(width: 4),
            Expanded(child: _LanguageSegment(label: 'BOTH', semanticsLabel: 'Both languages', selected: value == _bothMode, onTap: () => onChanged(_bothMode))),
          ],
        ),
      ),
    );
  }
}

/// A single segment of the language selector.
///
/// Selection is expressed as a gradient fill, a light border, and a
/// slightly brighter text colour. All three fade in and out together over
/// 320 ms. The `semanticsLabel` provides a longer form for screen readers
/// so abbreviations like "BOTH" are announced as "Both languages".
class _LanguageSegment extends StatelessWidget {
  const _LanguageSegment({required this.label, required this.semanticsLabel, required this.selected, required this.onTap});
  final String label;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              // Both variants declare a gradient so Flutter can interpolate
              // between them by lerping alpha, producing a smooth cross-fade
              // instead of a hard switch from "no gradient" to "gradient".
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? const <Color>[Color(0xFF0F2E73), Color(0xFF020817)]
                    : const <Color>[Color(0x000F2E73), Color(0x00020817)],
              ),
              // Border is always present at width 1; only its alpha changes,
              // which lets it fade in and out without a size change.
              border: Border.all(
                color: selected
                    ? const Color(0xFF6BA5F0).withValues(alpha: 0.45)
                    : const Color(0xFF6BA5F0).withValues(alpha: 0.0),
                width: 1,
              ),
            ),
            child: Center(
              // Text colour is animated in sync with the gradient and border.
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                style: AppTypography.body.copyWith(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  letterSpacing: 0.8,
                  color: selected
                      ? const Color(0xFFB8B8C4)
                      : Colors.white.withValues(alpha: 0.45),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}