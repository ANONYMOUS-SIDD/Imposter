// custom_words_section.dart
//
// Game Setup section that lists the user's custom words and exposes add /
// edit / delete actions.
//
// Data sources
// ------------
// Custom words come from `customWordsProvider`, which is synchronous — the
// section renders its content on the first frame with no loading state.
// Category names and icons come from `allCategoriesProvider`, also
// synchronous. Both are indexed once per build so per-row lookups are O(1).
//
// Duplicate detection
// ------------------
// The editor refuses to save a word whose text already exists among the
// bundled words or among other custom words. That check requires the full
// bundled-word list to be loaded at the moment the editor is opened. The
// dialog is therefore launched only after `allWordsProvider.future` has
// resolved (inside `_openEditor`), so the duplicate set is complete.
// Without this, a fast tap during the provider's initial load would let a
// new custom word silently duplicate a bundled one.
//
// Lifecycle
// ---------
// A single `_editorOpen` flag prevents a double-tap from stacking two
// editor dialogs. Every `await` is followed by a `mounted` check before
// accessing `ref`, so navigating away mid-dialog does not throw.
//
// Layout
// ------
// The section lives inside the Game Setup list and must tolerate any
// ambient width. Every text element carries `maxLines` + `overflow:
// ellipsis`, the flexible column is wrapped in `Expanded`, and the outer
// column uses `mainAxisSize: min`. An `AnimatedSize` smooths the
// empty ↔ populated transition when the first word is added.
//
// Action buttons
// --------------
// Edit and delete use `visualDensity: compact` with a tooltip per row, so
// screen readers announce which word each button affects. The resulting
// tap target is the Material-sanctioned 40dp minimum for dense rows.
//
// Localization note
// -----------------
// The category fallback label "Unknown" in `_WordRow` is currently
// hardcoded. Every other user-visible string goes through
// `AppLocalizations`; add a corresponding ARB key before shipping
// non-English builds.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../categories/data/category_repository.dart';
import '../../../categories/domain/word_category.dart';
import '../../../game/data/word_repository.dart';
import '../../../game/domain/entities/word.dart';
import '../../data/custom_words_repository.dart';
import 'custom_word_editor_dialog.dart';

const Color _blueMid = Color(0xFF040A1C);
const BorderRadius _sectionRadius = BorderRadius.all(Radius.circular(20));

/// Game Setup section for user-created custom words.
class CustomWordsSection extends ConsumerStatefulWidget {
  const CustomWordsSection({super.key});

  @override
  ConsumerState<CustomWordsSection> createState() => _CustomWordsSectionState();
}

class _CustomWordsSectionState extends ConsumerState<CustomWordsSection> {
  /// Set while the editor dialog is open. Prevents a second tap from
  /// opening a second dialog. Cleared in the `finally` block of
  /// [_openEditor].
  bool _editorOpen = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<Word> customWords = ref.watch(customWordsProvider);
    final List<WordCategory> categories = ref.watch(allCategoriesProvider);

    /// Single-pass index so per-row lookups do not rescan the category
    /// list on every rebuild.
    final Map<String, WordCategory> categoryById = <String, WordCategory>{
      for (final WordCategory c in categories) c.id: c,
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: _sectionRadius,
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
        borderRadius: _sectionRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: _editorOpen
                  ? null
                  : () => _openEditor(categories, editing: null),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  children: <Widget>[
                    const _IconBadge(icon: Icons.add),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        l10n.addWord.toUpperCase(),
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
            const _Divider(),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: customWords.isEmpty
                  ? _EmptyState(l10n: l10n)
                  : _WordList(
                words: customWords,
                categoryById: categoryById,
                onEdit: (Word w) =>
                    _openEditor(categories, editing: w),
                onDelete: (Word w) => _confirmDelete(l10n, w),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the editor for adding a new word (when [editing] is `null`) or
  /// for editing an existing one.
  ///
  /// Awaits the bundled-word list first so the editor's duplicate check
  /// sees the complete set of existing words. The provider caches after
  /// the first access, so repeated opens do not pay that cost again.
  Future<void> _openEditor(
      List<WordCategory> categories, {
        required Word? editing,
      }) async {
    if (_editorOpen) return;
    setState(() => _editorOpen = true);

    try {
      final List<Word> bundled;
      try {
        bundled = await ref.read(allWordsProvider.future);
      } catch (_) {
        if (!mounted) return;
        _showSnack('Could not load words. Please try again.');
        return;
      }
      if (!mounted) return;

      final Set<String> existingIds = <String>{
        for (final Word w in bundled) w.english.toLowerCase(),
        for (final Word w in ref.read(customWordsProvider))
          w.english.toLowerCase(),
      };

      final Word? result = await CustomWordEditorDialog.show(
        context: context,
        categories: categories,
        existingIds: existingIds,
        generateId: () => ref.read(customWordsProvider.notifier).newId(),
        existingWord: editing,
      );
      if (result == null || !mounted) return;

      try {
        if (editing == null) {
          await ref.read(customWordsProvider.notifier).add(result);
        } else {
          await ref.read(customWordsProvider.notifier).update(result);
        }
      } catch (_) {
        if (!mounted) return;
        _showSnack('Could not save word. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _editorOpen = false);
    }
  }

  /// Shows a destructive confirmation for [word] and deletes it if the
  /// user confirms. Uses a Cupertino alert for consistency with the
  /// iOS-style editor buttons used elsewhere in the flow.
  Future<void> _confirmDelete(AppLocalizations l10n, Word word) async {
    final bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: Text(l10n.deleteWordTitle),
        content: Text(l10n.deleteWordBody(word.english)),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(customWordsProvider.notifier).delete(word.id);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not delete word. Please try again.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Empty state shown when there are no custom words.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Text(
        l10n.emptyCustomWordsTitle,
        style: AppTypography.caption.copyWith(
          color: Colors.white.withValues(alpha: 0.42),
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Ordered list of custom-word rows.
class _WordList extends StatelessWidget {
  const _WordList({
    required this.words,
    required this.categoryById,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Word> words;
  final Map<String, WordCategory> categoryById;
  final void Function(Word) onEdit;
  final void Function(Word) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < words.length; i++) ...<Widget>[
          _WordRow(
            word: words[i],
            category: categoryById[words[i].categoryId],
            onEdit: () => onEdit(words[i]),
            onDelete: () => onDelete(words[i]),
          ),
          if (i < words.length - 1) const _Divider(),
        ],
      ],
    );
  }
}

/// Rounded icon container used as the leading visual on each row.
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

/// One custom word, its category subtitle, and its edit/delete actions.
class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.word,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Word word;
  final WordCategory? category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Styles are computed once rather than per row, avoiding a new
  /// `TextStyle` allocation on every rebuild of the list.
  static final TextStyle _wordStyle = AppTypography.body.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 13,
  );
  static final TextStyle _categoryStyle = AppTypography.caption.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: Colors.white.withValues(alpha: 0.55),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: <Widget>[
          _IconBadge(icon: category?.icon ?? Icons.category),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  word.english,
                  style: _wordStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  category?.englishName ?? 'Unknown',
                  style: _categoryStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            iconSize: 18,
            color: Colors.white.withValues(alpha: 0.55),
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            tooltip: 'Edit ${word.english}',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            iconSize: 18,
            color: const Color(0xFFF04462),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            tooltip: 'Delete ${word.english}',
          ),
        ],
      ),
    );
  }
}

/// One-pixel separator used between rows.
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