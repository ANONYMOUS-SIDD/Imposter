// game_setup_screen.dart
//
// Game Setup screen. Collects player names, language mode, rule toggles,
// category selection, and custom words, then starts the round.
//
// Word loading
// ------------
// The bundled word list is provided by `allWordsProvider`, which is
// async. Instead of blocking the form behind a loading spinner while that
// provider resolves, this screen renders the form immediately with
// whatever data is available at the moment (`asData?.value` returns null
// while loading and the caller substitutes an empty list). Words populate
// on the next frame when the provider completes. Only genuine errors
// switch the screen into the error state.
//
// Warming `allWordsProvider` at app startup — for example via a post-frame
// callback in `main.dart` — means the provider is already resolved before
// the user navigates here, so the form renders with full category counts
// on the first frame.
//
// Layout
// ------
// The form is a scrolling list inside a `SafeArea`, offset by the
// AppBar height because the AppBar is transparent and the body extends
// behind it. Each section is wrapped in `_StaggeredFade`, which fades and
// slides the section into place on a short delay. The delays are staggered
// so the sections arrive in sequence rather than all at once. The START
// button is deliberately not wrapped in `_StaggeredFade` so it is visible
// and tappable from the first frame.
//
// All sub-widgets use `Expanded`, `Flexible`, `ConstrainedBox(minHeight)`,
// and `maxLines` + `TextOverflow.ellipsis` where text can grow, so the
// form is responsive across screen sizes and accessibility text scales.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../categories/data/category_repository.dart';
import '../../../custom_words/data/custom_words_repository.dart';
import '../../../game/data/word_repository.dart';
import '../../../game/domain/entities/word.dart';
import '../../../game/presentation/providers/game_session_provider.dart';
import '../providers/game_setup_providers.dart';
import '../widgets/categories_section.dart';
import '../widgets/language_toggle.dart';
import '../widgets/players_section.dart';

const Color _blueBright = Color(0xFF0F2250);
const Color _blueMid = Color(0xFF040A1C);
const Color _blueDeep = Color(0xFF000308);
const Color _blueGlow = Color(0xFF6BA5F0);

/// Counts of bundled and custom words, grouped by category id.
///
/// Custom words increment both their own category and the `custom`
/// pseudo-category so a category chip becomes enabled as soon as any
/// custom word exists. Bundled words are read from `asData?.value` so this
/// provider does not depend on the async state of `allWordsProvider`.
final Provider<Map<String, int>> setupWordCountsProvider =
Provider<Map<String, int>>((ref) {
  final bundled = ref.watch(allWordsProvider).asData?.value ?? const <Word>[];
  final custom = ref.watch(customWordsProvider);

  final Map<String, int> counts = <String, int>{};
  for (final w in bundled) {
    counts[w.categoryId] = (counts[w.categoryId] ?? 0) + 1;
  }
  for (final w in custom) {
    counts[w.categoryId] = (counts[w.categoryId] ?? 0) + 1;
    counts['custom'] = (counts['custom'] ?? 0) + 1;
  }
  return counts;
});

/// Bundled words as a synchronous list.
///
/// Empty until `allWordsProvider` resolves. Callers can treat this as a
/// stable list without null checks.
final Provider<List<Word>> setupBundledWordsProvider = Provider<List<Word>>(
      (ref) => ref.watch(allWordsProvider).asData?.value ?? const <Word>[],
);

class GameSetupScreen extends ConsumerWidget {
  const GameSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final wordsAsync = ref.watch(allWordsProvider);

    return Scaffold(
      backgroundColor: _blueDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(l10n.setupTitle, style: AppTypography.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('home');
            }
          },
          tooltip: 'Back',
        ),
      ),
      body: Stack(
        children: <Widget>[
          const _DeepBlueBackground(),
          // Render the form unconditionally; words populate from
          // `asData?.value` on a later frame. Only a genuine error swaps
          // the screen into the error state.
          if (wordsAsync.hasError)
            _ErrorState(
              message: l10n.setupFailedLoadWords,
              onRetry: () => ref.invalidate(allWordsProvider),
              retryLabel: l10n.retry,
            )
          else
            _SetupForm(
              bundledWords: ref.watch(setupBundledWordsProvider),
            ),
        ],
      ),
    );
  }
}

class _SetupForm extends ConsumerWidget {
  const _SetupForm({required this.bundledWords});

  final List<Word> bundledWords;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(gameSetupProvider);
    final notifier = ref.read(gameSetupProvider.notifier);

    final categories = ref.watch(allCategoriesProvider);
    final engine = ref.read(gameEngineProvider);
    final customWords = ref.watch(customWordsProvider);
    final wordCountsByCategory = ref.watch(setupWordCountsProvider);

    final playerCount = state.playerNames.length;
    final maxImposters = engine.maxImposters(playerCount);
    final effectiveImposters = state.settings.multipleImposters
        ? state.settings.imposterCount.clamp(
      1,
      maxImposters < 1 ? 1 : maxImposters,
    )
        : 1;

    final namesTrimmed = state.playerNames.map((n) => n.trim()).toList();
    final hasEmptyName = namesTrimmed.any((n) => n.isEmpty);
    final hasDuplicateName =
        namesTrimmed.map((n) => n.toLowerCase()).toSet().length !=
            namesTrimmed.length;
    final noCategorySelected = state.settings.selectedCategoryIds.isEmpty;

    final canStart = !hasEmptyName &&
        !hasDuplicateName &&
        !noCategorySelected &&
        playerCount >= 3;

    final reason = _startDisabledReason(
      l10n: l10n,
      hasEmptyName: hasEmptyName,
      hasDuplicateName: hasDuplicateName,
      noCategorySelected: noCategorySelected,
      playerCount: playerCount,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, kToolbarHeight - 24, 16, 32),
        children: <Widget>[
          _StaggeredFade(
            child: _RulesContainer(
              hiddenImposterMode: state.settings.hiddenImposterMode,
              imposterHintEnabled: state.settings.imposterHintEnabled,
              hintDifficulty: state.settings.hintDifficulty,
              multipleImposters: state.settings.multipleImposters,
              imposterCount: effectiveImposters,
              l10n: l10n,
              onHiddenImposterChanged: notifier.setHiddenImposterMode,
              onImposterHintChanged: notifier.setImposterHintEnabled,
              onHintDifficultyChanged: notifier.setHintDifficulty,
              onMultipleImpostersChanged: notifier.setMultipleImposters,
            ),
          ),
          const SizedBox(height: 16),
          _StaggeredFade(
            child: LanguageToggle(
              value: state.settings.languageMode,
              onChanged: notifier.setLanguageMode,
            ),
          ),
          const SizedBox(height: 16),
          _StaggeredFade(
            child: CategoriesSection(
              categories: categories,
              selectedIds: state.settings.selectedCategoryIds,
              wordCountsByCategory: wordCountsByCategory,
              languageMode: state.settings.languageMode,
              onToggleCategory: notifier.toggleCategory,
              onSelectAll: () {
                final ids = categories
                    .where((c) => (wordCountsByCategory[c.id] ?? 0) > 0)
                    .map((c) => c.id);
                notifier.selectAllCategories(ids);
              },
              onClearAll: notifier.clearAllCategories,
            ),
          ),
          const SizedBox(height: 16),
          _StaggeredFade(
            child: PlayersSection(
              playerNames: state.playerNames,
              imposterCount: effectiveImposters,
              multipleImposters: state.settings.multipleImposters,
              maxImposterCount: maxImposters,
              onAddPlayerNamed: notifier.addPlayerNamed,
              onRemovePlayer: notifier.removePlayer,
              onMovePlayer: notifier.movePlayer,
              onImposterCountChanged: notifier.setImposterCount,
            ),
          ),
          const SizedBox(height: 28),
          _StartButton(
            label: l10n.setupStartButton,
            enabled: canStart,
            reason: reason,
            onPressed: () {
              final availableWords = <Word>[
                ...bundledWords,
                ...customWords,
              ];

              final err =
              notifier.startGame(availableWords: availableWords);
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFB51F38),
                    content: Text(err, style: AppTypography.body),
                  ),
                );
              } else {
                context.goNamed('reveal');
              }
            },
          ),
        ],
      ),
    );
  }

  /// Capitalizes the first letter of every space-separated word.
  ///
  /// Used to render the localized validation messages in Title Case
  /// rather than sentence case, matching the rest of the screen's
  /// button-style labels.
  String _titleCase(String s) {
    return s
        .split(' ')
        .map((w) =>
    w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Returns the first reason the START button is disabled, or `null` if
  /// the current draft passes every check. The reason is displayed above
  /// the button so the user knows what to fix.
  String? _startDisabledReason({
    required AppLocalizations l10n,
    required bool hasEmptyName,
    required bool hasDuplicateName,
    required bool noCategorySelected,
    required int playerCount,
  }) {
    if (playerCount < 3) {
      return _titleCase(l10n.setupErrorAtLeast3Players);
    }
    if (hasEmptyName) return _titleCase(l10n.setupErrorEnterName);
    if (hasDuplicateName) return _titleCase(l10n.setupErrorDuplicateNames);
    if (noCategorySelected) {
      return _titleCase(l10n.setupErrorSelectCategory);
    }
    return null;
  }
}

/// Keeps a child alive when it scrolls off-screen.
///
/// No entrance animation — the section renders at full opacity from the
/// first frame. The wrapper exists purely so the `ListView` sliver does
/// not dispose the subtree on scroll-out, which would otherwise restart
/// any animation inside it (most visibly the difficulty segmented
/// control, whose reveal would replay every time the user scrolled back).
class _StaggeredFade extends StatefulWidget {
  const _StaggeredFade({required this.child});

  final Widget child;

  @override
  State<_StaggeredFade> createState() => _StaggeredFadeState();
}

class _StaggeredFadeState extends State<_StaggeredFade>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _RulesContainer extends StatelessWidget {
  const _RulesContainer({
    required this.hiddenImposterMode,
    required this.imposterHintEnabled,
    required this.hintDifficulty,
    required this.multipleImposters,
    required this.imposterCount,
    required this.l10n,
    required this.onHiddenImposterChanged,
    required this.onImposterHintChanged,
    required this.onHintDifficultyChanged,
    required this.onMultipleImpostersChanged,
  });

  final bool hiddenImposterMode;
  final bool imposterHintEnabled;
  final HintDifficulty hintDifficulty;
  final bool multipleImposters;
  final int imposterCount;
  final AppLocalizations l10n;
  final ValueChanged<bool> onHiddenImposterChanged;
  final ValueChanged<bool> onImposterHintChanged;
  final ValueChanged<HintDifficulty> onHintDifficultyChanged;
  final ValueChanged<bool> onMultipleImpostersChanged;

  @override
  Widget build(BuildContext context) {
    final hintToggleEnabled = !hiddenImposterMode;
    final difficultyEnabled = imposterHintEnabled && !hiddenImposterMode;

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
        child: Column(
          children: <Widget>[
            _RuleTile(
              icon: Icons.remove_red_eye_rounded,
              title: 'BLIND MODE',
              subtitle: "Imposter Doesn't Know Their Role",
              value: hiddenImposterMode,
              enabled: true,
              onChanged: onHiddenImposterChanged,
            ),
            const _RuleDivider(),
            Column(
              children: <Widget>[
                _RuleTile(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'IMPOSTER HINT',
                  subtitle: hiddenImposterMode
                      ? 'Off While Blind Mode Is On'
                      : 'Give Imposter A Hint Word',
                  value: imposterHintEnabled,
                  enabled: hintToggleEnabled,
                  onChanged: onImposterHintChanged,
                ),
                // Difficulty control slides and fades in when the hint
                // toggle is turned on, and slides and fades out when it is
                // turned off. Height and opacity are driven by a single
                // animated value so both properties are always in sync.
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: difficultyEnabled ? 1.0 : 0.0,
                  ),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeInOutCubic,
                  builder: (
                      BuildContext context,
                      double value,
                      Widget? child,
                      ) {
                    if (value <= 0.001) {
                      return const SizedBox(
                        width: double.infinity,
                        height: 0,
                      );
                    }
                    return ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: value,
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 3, 18, 14),
                    child: _DifficultySegmented(
                      l10n: l10n,
                      current: hintDifficulty,
                      onChanged: onHintDifficultyChanged,
                    ),
                  ),
                ),
              ],
            ),
            const _RuleDivider(),
            _RuleTile(
              icon: Icons.groups_outlined,
              title: 'MULTIPLE IMPOSTERS',
              subtitle: multipleImposters
                  ? 'Multiple Imposters Enabled'
                  : 'Add More Than One Imposter',
              value: multipleImposters,
              enabled: true,
              onChanged: onMultipleImpostersChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _AnimatedToggle(
            value: value,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _RuleDivider extends StatelessWidget {
  const _RuleDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _AnimatedToggle extends StatefulWidget {
  const _AnimatedToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  State<_AnimatedToggle> createState() => _AnimatedToggleState();
}

class _AnimatedToggleState extends State<_AnimatedToggle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.35,
      child: GestureDetector(
        onTapDown: widget.enabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.enabled
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel: widget.enabled
            ? () => setState(() => _pressed = false)
            : null,
        onTap: widget.enabled
            ? () => widget.onChanged(!widget.value)
            : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: 36,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: widget.value
                ? const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Color(0xFF1E4DAF),
                Color(0xFF2860C8),
              ],
            )
                : null,
            color: widget.value ? null : const Color(0xFF141B2E),
            boxShadow: widget.value
                ? <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF2860C8)
                    .withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ]
                : <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: widget.value
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: AnimatedScale(
                scale: _pressed ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFC8C8D2),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
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

class _DifficultySegmented extends StatelessWidget {
  const _DifficultySegmented({
    required this.l10n,
    required this.current,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final HintDifficulty current;
  final ValueChanged<HintDifficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 30),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          color: Colors.white.withValues(alpha: 0.025),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _Segment(
                  label: l10n.difficultyEasy.toUpperCase(),
                  selected: current == HintDifficulty.easy,
                  onTap: () => onChanged(HintDifficulty.easy),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _Segment(
                  label: l10n.difficultyMedium.toUpperCase(),
                  selected: current == HintDifficulty.medium,
                  onTap: () => onChanged(HintDifficulty.medium),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _Segment(
                  label: l10n.difficultyHard.toUpperCase(),
                  selected: current == HintDifficulty.hard,
                  onTap: () => onChanged(HintDifficulty.hard),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: selected
                    ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFF0F2E73),
                    Color(0xFF020817),
                  ],
                )
                    : null,
                border: selected
                    ? Border.all(
                  color:
                  const Color(0xFF6BA5F0).withValues(alpha: 0.45),
                  width: 1,
                )
                    : null,
              ),
              child: Center(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontSize: 9,
                      fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w700,
                      letterSpacing: 0.5,
                      color: selected
                          ? const Color(0xFFB8B8C4)
                          : Colors.white.withValues(alpha: 0.45),
                    ),
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
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.label,
    required this.enabled,
    required this.reason,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final String? reason;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final extraMargin =
    ((MediaQuery.sizeOf(context).width * 0.11)
        .clamp(32.0, 64.0) -
        16)
        .clamp(0.0, double.infinity);

    return Column(
      children: <Widget>[
        if (reason != null) ...<Widget>[
          Text(
            reason!,
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: extraMargin),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: GestureDetector(
              onTap: enabled ? onPressed : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 42),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[
                      Color(0xFF020817),
                      Color(0xFF0F2E73),
                      Color(0xFF020817),
                    ],
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
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
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
                          label,
                          style: AppTypography.title.copyWith(
                            fontSize: 14,
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
      ],
    );
  }
}

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
        builder: (context, _) => CustomPaint(
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
      final p = _positions[i];
      final dy =
          (p.dy - progress * (0.015 + (i % 5) * 0.004)) % 1.0;
      final radius = 1.5 + (i % 3);
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.error_outline,
                size: 56,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: AppTypography.body,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  retryLabel,
                  style: AppTypography.title.copyWith(color: _blueGlow),
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
}