// custom_word_editor_dialog.dart
//
// Modal dialog for creating or editing a custom word.
//
// The dialog presents a single-line text field for the word and a category
// picker row. Tapping the picker row opens a nested modal list of
// categories. Both modals use a zero-duration route transition so the
// dialog appears the instant the user taps "Add Word" — a fade or slide
// here reads as lag on a game flow where the user expects immediate
// response.
//
// Layout is bounded by a ConstrainedBox(maxWidth: 420) and a maximum
// height that shrinks when the software keyboard opens. The dialog fits
// phones and tablets, in portrait and landscape, with the keyboard
// visible. The bottom action row (Cancel / Save) lives outside the
// scrollable content, so it stays reachable no matter how tall the
// content gets. All interactive elements meet the Material 48dp
// touch-target minimum and use maxLines + ellipsis so labels cannot
// overflow at large accessibility text scales.
//
// The word field is capped at 20 characters via `maxLength` and its
// default character counter is suppressed. The duplicate check compares
// against a pre-normalized set of existing IDs so the lookup is O(1) per
// save.
//
// The TextEditingController used by the editor is created in [show] and
// disposed in a `finally` block, so it is always released even if the
// route builder throws. Callers must not pass their own controller.
//
// A set of strings in this dialog (picker title and placeholder, and the
// three field-validation messages) are hardcoded English. They are the
// remaining gap before the dialog is fully localized; every other label
// goes through AppLocalizations.
//
// [show] returns `null` on Cancel, barrier tap, or hardware back press.
// A successful save returns the resulting Word, with its ID either newly
// generated or preserved from the word being edited.

import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../categories/domain/word_category.dart';
import '../../../game/domain/entities/word.dart';

const Color _dialogTop = Color(0xFF0D1D42);
const Color _dialogBottom = Color(0xFF040A1C);
const Color _groupBg = Color(0x0AFFFFFF);
const Color _groupBorder = Color(0x14FFFFFF);
const Color _accentBlue = Color(0xFF3D7AE5);
const Color _deepBlue = Color(0xFF1E4DAF);
const Color _deepCyan = Color(0xFF0E7490);
const Color _blueGlow = Color(0xFF6BA5F0);
const Color _crimson = Color(0xFFF04462);
const Color _dividerColor = Color(0x14FFFFFF);

const BorderRadius _dialogRadius = BorderRadius.all(Radius.circular(20));
const BorderRadius _fieldRadius = BorderRadius.all(Radius.circular(14));
const BorderRadius _badgeRadius = BorderRadius.all(Radius.circular(9));

/// Public entry point and nested picker for the custom-word editor.
class CustomWordEditorDialog {
  const CustomWordEditorDialog._();

  /// Shows the custom-word editor and returns the saved [Word], or `null`
  /// if the user cancelled or dismissed the dialog.
  ///
  /// The [TextEditingController] is created and disposed inside this
  /// method; callers must not pass their own.
  static Future<Word?> show({
    required BuildContext context,
    required List<WordCategory> categories,
    required Set<String> existingIds,
    required String Function() generateId,
    Word? existingWord,
  }) async {
    final TextEditingController wordController = TextEditingController(
      text: existingWord?.english ?? '',
    );
    try {
      return await Navigator.of(context, rootNavigator: true).push<Word>(
        PageRouteBuilder<Word>(
          opaque: false,
          barrierColor: Colors.black.withValues(alpha: 0.72),
          barrierDismissible: true,
          pageBuilder: (dialogCtx, _, __) => _EditorPage(
            categories: categories,
            existingIds: existingIds,
            generateId: generateId,
            existingWord: existingWord,
            wordController: wordController,
          ),
          transitionsBuilder: (_, __, ___, child) => child,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } finally {
      wordController.dispose();
    }
  }

  /// Opens the nested category picker and returns the picked category id,
  /// or `null` if the user dismissed it.
  static Future<String?> _pickCategory(
      BuildContext context,
      List<WordCategory> categories,
      String? current,
      ) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      PageRouteBuilder<String>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.60),
        barrierDismissible: true,
        pageBuilder: (dialogCtx, _, __) {
          final Size size = MediaQuery.sizeOf(dialogCtx);
          final double maxDialogHeight = size.height * 0.62;

          return Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    maxHeight: maxDialogHeight,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    decoration: BoxDecoration(
                      borderRadius: _dialogRadius,
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
                      borderRadius: _dialogRadius,
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                12,
                              ),
                              child: Text(
                                'Choose Category',
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
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: categories.length,
                                separatorBuilder: (_, __) => Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                                itemBuilder: (context, i) {
                                  final WordCategory cat = categories[i];
                                  final bool isCurrent = cat.id == current;
                                  return Semantics(
                                    button: true,
                                    selected: isCurrent,
                                    label: cat.englishName,
                                    child: InkWell(
                                      onTap: () => Navigator.of(dialogCtx)
                                          .pop(cat.id),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                        color: isCurrent
                                            ? _accentBlue
                                            .withValues(alpha: 0.15)
                                            : Colors.transparent,
                                        child: Row(
                                          children: <Widget>[
                                            _SmallBadge(
                                              icon: cat.icon,
                                              highlighted: isCurrent,
                                              highlightCyan: true,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                cat.englishName,
                                                style: AppTypography.body
                                                    .copyWith(
                                                  fontSize: 14,
                                                  fontWeight: isCurrent
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: isCurrent
                                                      ? Colors.white
                                                      : Colors.white
                                                      .withValues(
                                                      alpha: 0.85),
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isCurrent)
                                              const Icon(
                                                Icons.verified,
                                                size: 18,
                                                color: _deepCyan,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
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
                              child: _IosDialogButton(
                                label: AppLocalizations.of(dialogCtx)
                                    ?.cancel
                                    .toUpperCase() ??
                                    'CANCEL',
                                onTap: () => Navigator.of(dialogCtx).pop(),
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
        },
        transitionsBuilder: (_, __, ___, child) => child,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}

/// Editor body. Owns the word controller, the selected category, and the
/// inline validation state.
class _EditorPage extends StatefulWidget {
  const _EditorPage({
    required this.categories,
    required this.existingIds,
    required this.generateId,
    required this.existingWord,
    required this.wordController,
  });

  final List<WordCategory> categories;
  final Set<String> existingIds;
  final String Function() generateId;
  final Word? existingWord;
  final TextEditingController wordController;

  @override
  State<_EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<_EditorPage> {
  String? _selectedCategoryId;
  String? _errorText;
  bool _busy = false;

  /// Normalized copy of [widget.existingIds] built once in [initState] so
  /// the duplicate check on save is O(1).
  late final Set<String> _normalizedExistingIds;

  /// Normalized form of the currently-edited word, if any. Used so that
  /// saving an unchanged edit does not flag itself as a duplicate.
  late final String _normalizedEditingKey;

  @override
  void initState() {
    super.initState();

    // Drop a stale incoming category id (from a word whose category was
    // removed) rather than showing an invalid badge.
    final String? incomingId = widget.existingWord?.categoryId;
    if (incomingId != null &&
        widget.categories.any((WordCategory c) => c.id == incomingId)) {
      _selectedCategoryId = incomingId;
    }

    _normalizedExistingIds = widget.existingIds
        .map((String id) => id.trim().toLowerCase())
        .toSet();
    _normalizedEditingKey =
        widget.existingWord?.english.trim().toLowerCase() ?? '';
  }

  Future<void> _handleCancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleSave() async {
    if (_busy) return;
    setState(() => _busy = true);

    final String text = widget.wordController.text.trim();
    if (text.length < 2) {
      _failValidation(
        text.isEmpty
            ? 'Enter a word'
            : 'At least 2 letters',
      );
      return;
    }
    if (text.length > 20) {
      _failValidation('Maximum 20 characters');
      return;
    }
    if (_selectedCategoryId == null) {
      _failValidation('Choose a category');
      return;
    }

    final String key = text.toLowerCase();
    if (key != _normalizedEditingKey &&
        _normalizedExistingIds.contains(key)) {
      _failValidation(
        AppLocalizations.of(context)?.wordExists ?? 'Word already exists',
      );
      return;
    }

    WordCategory? category;
    for (final WordCategory c in widget.categories) {
      if (c.id == _selectedCategoryId) {
        category = c;
        break;
      }
    }
    if (category == null) {
      _failValidation('Choose a category');
      return;
    }

    // Custom words have no per-difficulty hints; the category name is used
    // as a fallback for every difficulty level.
    final LocalizedText hint = LocalizedText(
      english: category.englishName,
      nepali: category.nepaliName,
    );
    final Word word = Word(
      id: widget.existingWord?.id ?? widget.generateId(),
      categoryId: _selectedCategoryId!,
      english: text,
      nepali: text,
      hints: HintSet(easy: hint, medium: hint, hard: hint),
    );

    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    Navigator.of(context).pop(word);
  }

  /// Clears the busy flag and shows [message] as an inline validation error.
  void _failValidation(String message) {
    setState(() {
      _errorText = message;
      _busy = false;
    });
  }

  Future<void> _handlePickCategory() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final String? picked = await CustomWordEditorDialog._pickCategory(
      context,
      widget.categories,
      _selectedCategoryId,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedCategoryId = picked;
      _errorText = null;
    });
  }

  WordCategory? get _currentCategory {
    final String? id = _selectedCategoryId;
    if (id == null) return null;
    for (final WordCategory c in widget.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final double maxDialogHeight =
        (size.height - keyboard - 48) * 0.92;
    final AppLocalizations? l10n = AppLocalizations.of(context);
    final WordCategory? currentCategory = _currentCategory;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard, top: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: maxDialogHeight,
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  borderRadius: _dialogRadius,
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
                  borderRadius: _dialogRadius,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: _fieldRadius,
                                        color: _groupBg,
                                        border: Border.all(
                                          color: _groupBorder,
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: _fieldRadius,
                                        child: Stack(
                                          children: <Widget>[
                                            Material(
                                              type:
                                              MaterialType.transparency,
                                              child: Column(
                                                children: <Widget>[
                                                  Padding(
                                                    padding:
                                                    const EdgeInsets.all(
                                                        10),
                                                    child: Row(
                                                      children: <Widget>[
                                                        const _SmallBadge(
                                                          icon: Icons
                                                              .text_fields,
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Expanded(
                                                          child: TextField(
                                                            maxLength: 20,
                                                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                                            controller: widget
                                                                .wordController,
                                                            cursorColor:
                                                            _blueGlow,
                                                            cursorWidth: 1.8,
                                                            cursorRadius:
                                                            const Radius
                                                                .circular(
                                                                2),
                                                            cursorHeight: 18,
                                                            textCapitalization:
                                                            TextCapitalization
                                                                .words,
                                                            autocorrect: false,
                                                            enableSuggestions:
                                                            false,
                                                            style: AppTypography
                                                                .body
                                                                .copyWith(
                                                              fontSize: 14,
                                                              fontWeight:
                                                              FontWeight
                                                                  .w600,
                                                              color: Colors
                                                                  .white,
                                                            ),
                                                            onChanged: (_) {
                                                              if (_errorText !=
                                                                  null) {
                                                                setState(() =>
                                                                _errorText =
                                                                null);
                                                              }
                                                            },
                                                            onTapOutside: (_) {
                                                              FocusManager
                                                                  .instance
                                                                  .primaryFocus
                                                                  ?.unfocus();
                                                            },
                                                            decoration:
                                                            InputDecoration(
                                                              hintText:
                                                              'Enter Custom Word',
                                                              hintStyle: AppTypography
                                                                  .body
                                                                  .copyWith(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                FontWeight
                                                                    .w500,
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                    alpha:
                                                                    0.35),
                                                              ),
                                                              filled: false,
                                                              isDense: true,
                                                              border:
                                                              InputBorder
                                                                  .none,
                                                              enabledBorder:
                                                              InputBorder
                                                                  .none,
                                                              focusedBorder:
                                                              InputBorder
                                                                  .none,
                                                              contentPadding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                vertical: 4,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    height: 1,
                                                    color: Colors.white
                                                        .withValues(
                                                        alpha: 0.06),
                                                  ),
                                                  InkWell(
                                                    onTap: _busy
                                                        ? null
                                                        : _handlePickCategory,
                                                    child: Padding(
                                                      padding:
                                                      const EdgeInsets
                                                          .all(10),
                                                      child: Row(
                                                        children: <Widget>[
                                                          _SmallBadge(
                                                            icon: currentCategory
                                                                ?.icon ??
                                                                Icons
                                                                    .category_outlined,
                                                            highlighted:
                                                            currentCategory !=
                                                                null,
                                                            highlightCyan:
                                                            true,
                                                          ),
                                                          const SizedBox(
                                                              width: 12),
                                                          Expanded(
                                                            child: Text(
                                                              currentCategory
                                                                  ?.englishName ??
                                                                  'Choose Category',
                                                              style: AppTypography
                                                                  .body
                                                                  .copyWith(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                                color: currentCategory !=
                                                                    null
                                                                    ? Colors
                                                                    .white
                                                                    : Colors.white
                                                                    .withValues(
                                                                    alpha:
                                                                    0.40),
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                            ),
                                                          ),
                                                          Icon(
                                                            Icons
                                                                .keyboard_arrow_down,
                                                            size: 20,
                                                            color: Colors.white
                                                                .withValues(
                                                                alpha:
                                                                0.50),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Positioned.fill(
                                              child: IgnorePointer(
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                    LinearGradient(
                                                      begin: Alignment
                                                          .topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                      colors: <Color>[
                                                        Colors.white
                                                            .withValues(
                                                            alpha: 0.06),
                                                        Colors.transparent,
                                                      ],
                                                      stops: const <double>[
                                                        0.0,
                                                        0.55
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
                                    AnimatedSize(
                                      duration:
                                      const Duration(milliseconds: 150),
                                      curve: Curves.easeOut,
                                      alignment: Alignment.topLeft,
                                      child: _errorText == null
                                          ? const SizedBox(
                                        width: double.infinity,
                                        height: 0,
                                      )
                                          : Padding(
                                        padding:
                                        const EdgeInsets.fromLTRB(
                                            4, 8, 4, 0),
                                        child: Align(
                                          alignment:
                                          Alignment.centerLeft,
                                          child: Text(
                                            _errorText!,
                                            style: AppTypography.caption
                                                .copyWith(
                                              color: _crimson,
                                              fontSize: 10,
                                              fontWeight:
                                              FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                            maxLines: 1,
                                            overflow:
                                            TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(height: 1, color: _dividerColor),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(
                              child: _IosDialogButton(
                                label: l10n?.cancel.toUpperCase() ?? 'CANCEL',
                                onTap: _busy ? null : _handleCancel,
                              ),
                            ),
                            Container(width: 1, color: _dividerColor),
                            Expanded(
                              child: _IosDialogButton(
                                label: widget.existingWord == null
                                    ? (l10n?.addWord.toUpperCase() ??
                                    'ADD WORD')
                                    : (l10n?.save.toUpperCase() ?? 'SAVE'),
                                primary: true,
                                isLoading: _busy,
                                onTap: _busy ? null : _handleSave,
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
          ),
        ),
      ),
    );
  }
}

/// Small rounded icon badge used for the field icon and category rows.
class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.icon,
    this.highlighted = false,
    this.highlightCyan = false,
  });

  final IconData icon;
  final bool highlighted;
  final bool highlightCyan;

  @override
  Widget build(BuildContext context) {
    final Color highlightColor = highlightCyan ? _deepCyan : _deepBlue;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: _badgeRadius,
        color: highlighted
            ? highlightColor.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: highlighted
              ? highlightColor.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Icon(
        icon,
        size: 16,
        color:
        highlighted ? _deepCyan : Colors.white.withValues(alpha: 0.72),
      ),
    );
  }
}

/// iOS-style flat dialog button used by the editor and the category picker.
///
/// Uses a minimum height rather than a fixed height so the button grows
/// with large text scales instead of clipping.
class _IosDialogButton extends StatelessWidget {
  const _IosDialogButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.isLoading = false,
  });

  final String label;

  /// Passing `null` disables the button.
  final VoidCallback? onTap;

  final bool primary;

  /// When `true`, a small spinner replaces the label.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null && !isLoading;
    final Color activeColor =
    primary ? Colors.white : Colors.white.withValues(alpha: 0.88);
    final Color textColor =
    enabled ? activeColor : Colors.white.withValues(alpha: 0.40);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Center(
              child: isLoading
                  ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primary
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.88),
                ),
              )
                  : Text(
                label,
                style: AppTypography.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: textColor,
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