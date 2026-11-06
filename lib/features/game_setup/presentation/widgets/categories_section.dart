// categories_section.dart
//
// The "WORD CATEGORIES" section of the Game Setup screen.
//
// Renders a category grid in a 3-2-3-2 alternating column pattern, with
// short-named categories grouped into the 3-column rows and long-named
// categories grouped into the 2-column rows. The "Custom Word" category
// is pulled out of the grid and rendered as a full-width trailing row,
// and two action rows below the grid open the custom-word editor.
//
// Layout and overflow
// -------------------
// The grid's Row widgets use the default centre cross-axis alignment
// rather than `stretch`. This Row lives inside a Column inside a ListView,
// so it receives an unbounded height constraint. `stretch` would force
// each child to size to the Row's own height — which is infinity —
// throwing "BoxConstraints forces an infinite height". With centre
// alignment, each card sizes to its own content; every card is
// structurally identical (icon plus one line of text), so they render at
// the same height at any realistic text scale, and the
// `ConstrainedBox(minHeight: 32)` enforces the minimum.
//
// Every text element uses `maxLines: 1` with `TextOverflow.ellipsis`,
// the header row uses `Expanded` to split available width evenly, and
// the Add/Edit Word rows wrap their label in `Expanded`. Dialog and
// header action buttons use `ConstrainedBox(minHeight: 44)` so their tap
// targets stay usable at large text scales without clipping the label.
//
// Editor reentrancy
// -----------------
// The class is a ConsumerStatefulWidget so it can hold an `_editorOpen`
// flag. Tapping "Add Word" while the editor dialog is open is a no-op,
// which prevents a fast double-tap from stacking two dialogs. All `await`
// points after opening a dialog check `mounted` before touching `ref`.
//
// Localization
// ------------
// Two strings in this file are hardcoded English: the "Edit Custom Words"
// row label and the "Unknown" fallback used when a custom word's category
// is not in the repository. Every other user-visible string comes from
// AppLocalizations.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../categories/data/category_repository.dart';
import '../../../categories/domain/word_category.dart';
import '../../../custom_words/data/custom_words_repository.dart';
import '../../../custom_words/presentation/widgets/custom_word_editor_dialog.dart';
import '../../../game/domain/entities/word.dart';

const Color _blueMid = Color(0xFF040A1C);
const Color _blueGlow = Color(0xFF6BA5F0);
const Color _deepCyan = Color(0xFF0E7490);
const Color _dialogTop = Color(0xFF0D1D42);
const Color _dialogBottom = Color(0xFF040A1C);

class CategoriesSection extends ConsumerStatefulWidget {
  const CategoriesSection({
    super.key,
    required this.categories,
    required this.selectedIds,
    required this.wordCountsByCategory,
    required this.languageMode,
    required this.onToggleCategory,
    required this.onSelectAll,
    required this.onClearAll,
  });

  final List<WordCategory> categories;
  final Set<String> selectedIds;
  final Map<String, int> wordCountsByCategory;
  final String languageMode;
  final ValueChanged<String> onToggleCategory;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  @override
  ConsumerState<CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends ConsumerState<CategoriesSection> {
  /// Guards against a second "Add Word" tap while the editor dialog is
  /// already open. Set when the dialog is launched, cleared in a `finally`
  /// block after it closes or fails to open.
  bool _editorOpen = false;

  /// Categories whose name is longer than this many characters are placed
  /// in the two-column rows of the grid. The threshold is a character
  /// count rather than a measured width, so Devanagari names may be
  /// classified slightly differently than their visual width would
  /// suggest. The effect is cosmetic — row composition only.
  static const int _longNameThreshold = 9;

  /// Returns `true` when every playable category that has at least one
  /// word is currently selected.
  ///
  /// Categories with zero words are skipped, so the "Select All" button
  /// correctly reports `allSelected` even when some categories are empty.
  bool _isAllPlayableSelected(List<WordCategory> nonCustom) {
    if (nonCustom.isEmpty) return false;
    for (final WordCategory c in nonCustom) {
      if ((widget.wordCountsByCategory[c.id] ?? 0) == 0) continue;
      if (!widget.selectedIds.contains(c.id)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final customWords = ref.watch(customWordsProvider);

    // Custom Word is rendered as a full-width trailing row instead of
    // participating in the grid pattern.
    WordCategory? customCategory;
    final nonCustom = <WordCategory>[];
    for (final cat in widget.categories) {
      if (cat.id == 'custom') {
        customCategory = cat;
      } else {
        nonCustom.add(cat);
      }
    }

    // Split non-custom categories into short and long name buckets. Only
    // the first line of a multi-line name is measured, so `both` mode
    // does not skew the classification.
    final shorts = <WordCategory>[];
    final longs = <WordCategory>[];
    for (final cat in nonCustom) {
      final name = cat.nameFor(widget.languageMode).split('\n').first;
      if (name.length > _longNameThreshold) {
        longs.add(cat);
      } else {
        shorts.add(cat);
      }
    }

    final allSelected = _isAllPlayableSelected(nonCustom);
    final noneSelected = widget.selectedIds.isEmpty;

    // Local final so Dart promotes to non-null inside nested closures.
    final custom = customCategory;

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
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n
                              .categoriesSelectedCount(widget.selectedIds.length)
                              .toUpperCase(),
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _HeaderActionButton(
                          label: l10n.selectAll.toUpperCase(),
                          enabled: !allSelected,
                          onTap: widget.onSelectAll,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _HeaderActionButton(
                          label: l10n.clearAll.toUpperCase(),
                          enabled: !noneSelected,
                          onTap: widget.onClearAll,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const _Divider(),

            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ..._buildRows(shorts, longs),

                  if (custom != null) ...<Widget>[
                    const SizedBox(height: 9),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: _CategoryCard(
                        category: custom,
                        displayName: custom
                            .nameFor(widget.languageMode)
                            .split('\n')
                            .first,
                        isSelected: widget.selectedIds.contains(custom.id),
                        isDisabled:
                        (widget.wordCountsByCategory[custom.id] ?? 0) == 0,
                        onTap:
                        (widget.wordCountsByCategory[custom.id] ?? 0) == 0
                            ? null
                            : () => widget.onToggleCategory(custom.id),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const _Divider(),

            _AddWordRow(
              label: l10n.addWord.toUpperCase(),
              onTap: _editorOpen ? null : _openEditor,
            ),
            if (customWords.isNotEmpty) ...<Widget>[
              const _Divider(),
              _AddWordRow(
                label: 'Edit Custom Words'.toUpperCase(),
                icon: Icons.edit_outlined,
                onTap: _openEditWords,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Opens the custom-word editor for a new word and saves the result.
  ///
  /// The duplicate-check set is built from existing custom words only, so
  /// a user may create a custom word that matches a bundled word. The
  /// editor is guarded by `_editorOpen` so a double-tap does not stack
  /// two dialogs, and every `await` after the dialog closes checks
  /// `mounted` before touching `ref` or the messenger.
  Future<void> _openEditor() async {
    if (_editorOpen) return;
    setState(() => _editorOpen = true);

    try {
      final customWords = ref.read(customWordsProvider);
      final existingIds = <String>{
        for (final w in customWords) w.english.toLowerCase(),
      };

      final result = await CustomWordEditorDialog.show(
        context: context,
        categories: widget.categories,
        existingIds: existingIds,
        generateId: () => ref.read(customWordsProvider.notifier).newId(),
      );
      if (result == null || !mounted) return;

      try {
        await ref.read(customWordsProvider.notifier).add(result);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save word. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _editorOpen = false);
    }
  }

  /// Opens the "Edit Custom Words" dialog, which lists existing custom
  /// words and allows deleting them.
  Future<void> _openEditWords() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.60),
        pageBuilder: (dialogCtx, _, __) => const _EditWordsDialog(),
        transitionsBuilder: (_, __, ___, child) => child,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    if (!mounted) return;
  }

  /// Builds the grid rows for the short- and long-named category buckets.
  ///
  /// Rows alternate between 3 columns (short names) and 2 columns (long
  /// names). Whichever bucket runs out first is backfilled from the other
  /// bucket, so every row is filled to its column count except possibly
  /// the last one.
  List<Widget> _buildRows(
      List<WordCategory> shorts,
      List<WordCategory> longs,
      ) {
    final rows = <Widget>[];
    const spacing = 9.0;
    const pattern = <int>[3, 2];
    var shortIdx = 0;
    var longIdx = 0;
    var rowNumber = 0;

    while (shortIdx < shorts.length || longIdx < longs.length) {
      final cols = pattern[rowNumber % pattern.length];
      final rowItems = <WordCategory>[];

      if (cols == 2) {
        while (rowItems.length < cols && longIdx < longs.length) {
          rowItems.add(longs[longIdx++]);
        }
      } else {
        while (rowItems.length < cols && shortIdx < shorts.length) {
          rowItems.add(shorts[shortIdx++]);
        }
      }

      while (rowItems.length < cols && shortIdx < shorts.length) {
        rowItems.add(shorts[shortIdx++]);
      }
      while (rowItems.length < cols && longIdx < longs.length) {
        rowItems.add(longs[longIdx++]);
      }

      if (rowItems.isEmpty) break;

      rows.add(_buildRow(rowItems));
      rowNumber++;

      if (shortIdx < shorts.length || longIdx < longs.length) {
        rows.add(const SizedBox(height: spacing));
      }
    }

    return rows;
  }

  /// Builds a single row of the grid with the given [items].
  ///
  /// Uses the default centre cross-axis alignment. Do not switch to
  /// `stretch`: the row lives inside an unbounded-height Column, and
  /// stretching would force infinite constraints on each child.
  Widget _buildRow(List<WordCategory> items) {
    const spacing = 9.0;
    return Row(
      children: <Widget>[
        for (var j = 0; j < items.length; j++) ...<Widget>[
          if (j > 0) const SizedBox(width: spacing),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: _CategoryCard(
                category: items[j],
                displayName:
                items[j].nameFor(widget.languageMode).split('\n').first,
                isSelected: widget.selectedIds.contains(items[j].id),
                isDisabled:
                (widget.wordCountsByCategory[items[j].id] ?? 0) == 0,
                onTap: (widget.wordCountsByCategory[items[j].id] ?? 0) == 0
                    ? null
                    : () => widget.onToggleCategory(items[j].id),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Small text button used for the "Select All" and "Clear All" actions in
/// the section header.
///
/// Uses a minimum height so the tap target meets the WCAG 2.5.5 guidance
/// while keeping the visual density compact. When [enabled] is `false`,
/// the button is rendered with muted text and a disabled `onPressed`.
class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: enabled ? _blueGlow : Colors.white.withValues(alpha: 0.30),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// One tappable category card in the grid, or the full-width custom-word
/// row.
///
/// Selection is indicated by a coloured border and a slightly brighter
/// icon and text. Disabled cards — categories that have no words — are
/// rendered at reduced opacity and ignore taps.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.displayName,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final WordCategory category;
  final String displayName;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected
        ? Colors.white.withValues(alpha: 0.68)
        : Colors.white.withValues(alpha: 0.42);
    final textColor = isSelected
        ? Colors.white.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.48);

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: !isDisabled && onTap != null,
      label: displayName,
      excludeSemantics: true,
      child: Opacity(
        opacity: isDisabled ? 0.35 : 1.0,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isSelected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: isSelected
                    ? _deepCyan.withValues(alpha: 0.90)
                    : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: Center(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Icon(category.icon, size: 15, color: iconColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        displayName,
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          height: 1.1,
                          color: textColor,
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
    );
  }
}

/// Full-width action row used for "Add Word" and "Edit Custom Words".
///
/// Passing `null` for [onTap] disables the row: it renders at reduced
/// opacity and does not respond to taps.
class _AddWordRow extends StatelessWidget {
  const _AddWordRow({
    required this.label,
    required this.onTap,
    this.icon = Icons.add,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: <Widget>[
                _IconBadge(icon: icon),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded square container for a leading icon.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
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

/// Dialog that lists all custom words and allows deleting them.
///
/// Uses a `ConstrainedBox` with a `maxHeight` derived from the screen
/// height so it never overflows on short screens, and places the close
/// button below the scrolling list so it remains reachable.
class _EditWordsDialog extends ConsumerStatefulWidget {
  const _EditWordsDialog();

  @override
  ConsumerState<_EditWordsDialog> createState() => _EditWordsDialogState();
}

class _EditWordsDialogState extends ConsumerState<_EditWordsDialog> {
  /// Set while a delete is in progress. Disables the delete button on
  /// every row so a second tap cannot start a second delete flow.
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final customWords = ref.watch(customWordsProvider);
    final categories = ref.watch(allCategoriesProvider);
    final categoryById = <String, WordCategory>{
      for (final c in categories) c.id: c,
    };

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.sizeOf(context).height * 0.70,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
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
                  BoxShadow(
                    color: _blueGlow.withValues(alpha: 0.18),
                    blurRadius: 28,
                    spreadRadius: -8,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Text(
                          'Edit Custom Words',
                          style: AppTypography.title.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      Flexible(
                        child: customWords.isEmpty
                            ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.emptyCustomWordsTitle,
                            style: AppTypography.body.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                              Colors.white.withValues(alpha: 0.62),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                            : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: customWords.length,
                          separatorBuilder: (_, __) => Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                          itemBuilder: (context, i) {
                            final word = customWords[i];
                            final cat = categoryById[word.categoryId];
                            return _EditWordRow(
                              word: word,
                              category: cat,
                              onDelete: _deleting
                                  ? null
                                  : () => _showDeleteDialog(word),
                            );
                          },
                        ),
                      ),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: _EditDialogButton(
                          label: l10n.close.toUpperCase(),
                          onTap: () => Navigator.of(context).pop(),
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
    );
  }

  /// Shows a destructive confirmation for [word] and deletes it if the
  /// user confirms. The `_deleting` flag is held while the delete is in
  /// flight so the delete buttons on every row stay disabled.
  Future<void> _showDeleteDialog(Word word) async {
    if (_deleting) return;
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
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
                        'Delete Word',
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
                        '${word.english} Will Be Removed',
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
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: _EditDialogButton(
                          label: (l10n?.cancel ?? 'Cancel').toUpperCase(),
                          onTap: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      Container(
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      Expanded(
                        child: _EditDialogButton(
                          label: (l10n?.delete ?? 'Delete').toUpperCase(),
                          destructive: true,
                          onTap: () => Navigator.pop(ctx, true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(customWordsProvider.notifier).delete(word.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete word. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

/// One row inside the "Edit Custom Words" dialog: icon, word, category,
/// and a delete button.
class _EditWordRow extends StatelessWidget {
  const _EditWordRow({
    required this.word,
    required this.category,
    required this.onDelete,
  });

  final Word word;
  final WordCategory? category;

  /// Passing `null` disables the delete button — used while a delete is
  /// already in flight.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: <Widget>[
          _IconBadge(icon: category?.icon ?? Icons.category_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  word.english,
                  style: AppTypography.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  category?.englishName ?? 'Unknown',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            iconSize: 15,
            onPressed: onDelete,
            color: const Color(0xFF8B1E32),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            tooltip: 'Delete ${word.english}',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat action button used inside the edit and delete dialogs.
///
/// Uses a minimum height rather than a fixed height so the label grows
/// with large text scales instead of clipping.
class _EditDialogButton extends StatelessWidget {
  const _EditDialogButton({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
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
                  color: destructive
                      ? const Color(0xFF8B1E32)
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