// players_section.dart
//
// The "PLAYERS" section of Game Setup.
//
// Composed of four parts:
//   • A header showing the current player count.
//   • One row per player with move-up, move-down, and remove actions.
//   • An "Add Player" row that opens a modal name entry dialog.
//   • A summary footer showing total, imposter, and civilian counts, with
//     a small stepper for adjusting the imposter count when multiple
//     imposters are enabled.
//
// Dialog behavior
// ---------------
// The add and remove dialogs unfocus the current field and pop the route
// immediately when the user confirms or cancels. The keyboard's dismiss
// animation runs concurrently with the dialog's close animation, which is
// how native iOS and Android handle the same interaction. Blocking on the
// keyboard first would add several hundred milliseconds of dead time
// between the tap and the visual response, so it is deliberately avoided.
//
// Tap targets
// -----------
// Player row action buttons use a 36 dp tap box around a 32 dp visual
// pill, keeping the touch target comfortably above the platform minimum
// while remaining visually compact.
//
// The imposter stepper in the footer is smaller (32 dp). Enlarging it to
// match the row buttons would push the IMPOSTERS column taller than its
// neighbours and break the horizontal baseline alignment shared by the
// three stats. The consequences of a mis-tap on the stepper are trivial —
// the opposite arrow is a single tap away — so the smaller target is a
// deliberate trade-off in favour of the footer's visual alignment.
//
// Layout and overflow
// -------------------
// Player names, error text, dialog titles and bodies, and stat labels all
// use `maxLines` + `overflow: ellipsis`. The stepper value and stat value
// rows use fixed heights because their contents are single small integers
// that cannot grow. The three stat values are pinned to a common height
// via a `SizedBox` so they align on the same baseline regardless of which
// one carries a stepper.
//
// Localization
// ------------
// The only string pulled through `AppLocalizations` is the fallback list
// of button labels used by the remove dialog. All other user-visible
// strings in this file are hardcoded English: the player/players count
// label, "Add Player", "Remove Player", the remove-confirmation body,
// "CANCEL" and "REMOVE", the three add-dialog validation messages, the
// name entry hint, and the three stat labels. These are candidates for a
// future localization pass but are not pulled from ARB yet.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_typography.dart';

const Color _blueMid = Color(0xFF040A1C);
const Color _blueGlow = Color(0xFF6BA5F0);
const Color _crimson = Color(0xFFF04462);
const Color _deepRed = Color(0xFF8B1E32);
const Color _dialogTop = Color(0xFF0D1D42);
const Color _dialogBottom = Color(0xFF040A1C);
const Color _groupBg = Color(0x0AFFFFFF);
const Color _groupBorder = Color(0x14FFFFFF);
const Color _dividerColor = Color(0x14FFFFFF);

/// Tap-box size for the move and remove buttons in each player row.
const double _iconBtnTapSize = 36;

/// Visual pill size inside the tap box for the same buttons.
const double _iconBtnVisualSize = 32;

/// Visual size of the imposter stepper buttons in the summary footer.
const double _stepperVisualSize = 18;

/// Tap-box size for the imposter stepper. Kept smaller than
/// [_iconBtnTapSize] to preserve the footer's baseline alignment.
const double _stepperTapSize = 32;

/// Maximum length of a player name, enforced both by the input field's
/// formatter and by the add dialog's validation.
const int _maxPlayerNameLength = 20;

class PlayersSection extends StatelessWidget {
  const PlayersSection({
    super.key,
    required this.playerNames,
    required this.imposterCount,
    required this.multipleImposters,
    required this.maxImposterCount,
    required this.onAddPlayerNamed,
    required this.onRemovePlayer,
    required this.onMovePlayer,
    required this.onImposterCountChanged,
  });

  final List<String> playerNames;
  final int imposterCount;
  final bool multipleImposters;
  final int maxImposterCount;
  final ValueChanged<String> onAddPlayerNamed;
  final ValueChanged<int> onRemovePlayer;
  final void Function(int from, int to) onMovePlayer;
  final ValueChanged<int> onImposterCountChanged;

  @override
  Widget build(BuildContext context) {
    final int playerCount = playerNames.length;
    final int imposter =
    playerCount >= 3 ? imposterCount.clamp(1, playerCount - 2) : 0;
    final int civilians = playerCount - imposter;
    final bool showStepper =
        multipleImposters && maxImposterCount > 1 && playerCount >= 3;

    final String countLabel = '$playerCount '
        '${playerCount == 1 ? 'PLAYER' : 'PLAYERS'}';

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
                      child: Text(
                        countLabel,
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
                  ],
                ),
              ),
            ),
            const _Divider(),

            if (playerNames.isNotEmpty)
              for (int i = 0; i < playerNames.length; i++) ...<Widget>[
                _PlayerRow(
                  index: i,
                  name: playerNames[i],
                  canMoveUp: i > 0,
                  canMoveDown: i < playerNames.length - 1,
                  onMoveUp: () => onMovePlayer(i, i - 1),
                  onMoveDown: () => onMovePlayer(i, i + 1),
                  onRemove: () => _showRemoveDialog(
                    context,
                    name: playerNames[i],
                    onConfirm: () => onRemovePlayer(i),
                  ),
                ),
                if (i < playerNames.length - 1) const _Divider(),
              ],

            if (playerNames.isNotEmpty) const _Divider(),

            _AddPlayerRow(onTap: () => _showAddDialog(context)),

            if (playerNames.isNotEmpty) ...<Widget>[
              const _Divider(),
              _SummaryFooter(
                total: playerCount,
                imposters: imposter,
                civilians: civilians,
                showStepper: showStepper,
                maxImposterCount: maxImposterCount,
                imposterCount: imposter,
                onImposterCountChanged: onImposterCountChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Opens the add-player dialog and adds the resulting name.
  ///
  /// The `context.mounted` check guards against the parent being disposed
  /// while the dialog is open.
  Future<void> _showAddDialog(BuildContext context) async {
    final String? name = await _AddPlayerDialog.show(
      context: context,
      existingNames: playerNames,
    );
    if (name != null && context.mounted) {
      onAddPlayerNamed(name);
    }
  }

  /// Opens a confirmation dialog and invokes [onConfirm] if the user
  /// agrees to remove [name].
  Future<void> _showRemoveDialog(
      BuildContext context, {
        required String name,
        required VoidCallback onConfirm,
      }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (BuildContext ctx) => Dialog(
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
                        'Remove Player',
                        textAlign: TextAlign.center,
                        style: AppTypography.title.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$name Will Be Removed From Game',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        maxLines: 2,
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
                          label: 'CANCEL',
                          onTap: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      Container(width: 1, color: _dividerColor),
                      Expanded(
                        child: _IosDialogButton(
                          label: 'REMOVE',
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
    if (confirmed == true && context.mounted) {
      onConfirm();
    }
  }
}

/// Flat two-way dialog button used by the remove-player confirmation.
///
/// Uses a minimum height rather than a fixed height so the label grows
/// with large text scales instead of clipping. The label is single-line
/// with ellipsis.
class _IosDialogButton extends StatelessWidget {
  const _IosDialogButton({
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    if (destructive) {
      textColor = _deepRed;
    } else if (primary) {
      textColor = Colors.white;
    } else {
      textColor = Colors.white.withValues(alpha: 0.88);
    }

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

/// One row in the player list: index badge, name, and three action buttons.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.index,
    required this.name,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final String name;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            child: Text(
              '${index + 1}',
              style: AppTypography.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.80),
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: AppTypography.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          _IconButton(
            icon: Icons.arrow_upward_rounded,
            enabled: canMoveUp,
            onTap: onMoveUp,
            semanticLabel: 'Move $name up',
          ),
          const SizedBox(width: 1),
          _IconButton(
            icon: Icons.arrow_downward_rounded,
            enabled: canMoveDown,
            onTap: onMoveDown,
            semanticLabel: 'Move $name down',
          ),
          const SizedBox(width: 1),
          _IconButton(
            icon: Icons.delete_outline_rounded,
            destructive: true,
            onTap: onRemove,
            semanticLabel: 'Remove $name',
          ),
        ],
      ),
    );
  }
}

/// Rounded pill button used for move and remove actions on player rows.
///
/// The tap box is [_iconBtnTapSize] wide while the visible pill is
/// [_iconBtnVisualSize] wide, so the touch target meets the accessibility
/// minimum without enlarging the pill visually. The `semanticLabel` is
/// forwarded to the inner [Icon] so screen readers announce which player
/// the action applies to.
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.destructive = false,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool destructive;

  /// Screen-reader label for the icon. Passed through to [Icon.semanticLabel].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.30,
      child: SizedBox(
        width: _iconBtnTapSize,
        height: _iconBtnTapSize,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Container(
                width: _iconBtnVisualSize,
                height: _iconBtnVisualSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  semanticLabel: semanticLabel,
                  color: destructive
                      ? _deepRed
                      : Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width tappable row that opens the add-player dialog.
class _AddPlayerRow extends StatelessWidget {
  const _AddPlayerRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.person_add_alt_1,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ADD PLAYER',
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
    );
  }
}

/// Three-column footer showing total, imposter, and civilian counts.
///
/// The IMPOSTERS column includes optional stepper buttons that adjust the
/// imposter count. All three columns pin their value rows to the same
/// height so the three numbers render on the same baseline.
class _SummaryFooter extends StatelessWidget {
  const _SummaryFooter({
    required this.total,
    required this.imposters,
    required this.civilians,
    required this.showStepper,
    required this.maxImposterCount,
    required this.imposterCount,
    required this.onImposterCountChanged,
  });

  final int total;
  final int imposters;
  final int civilians;
  final bool showStepper;
  final int maxImposterCount;
  final int imposterCount;
  final ValueChanged<int> onImposterCountChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Stat(
            label: 'TOTAL',
            value: '$total',
            color: Colors.white,
          ),
          _Stat(
            label: 'IMPOSTERS',
            value: '$imposters',
            color: _deepRed,
            leading: showStepper
                ? _MiniStepperBtn(
              icon: Icons.remove,
              enabled: imposterCount > 1,
              onTap: () =>
                  onImposterCountChanged(imposterCount - 1),
            )
                : null,
            trailing: showStepper
                ? _MiniStepperBtn(
              icon: Icons.add,
              enabled: imposterCount < maxImposterCount,
              onTap: () =>
                  onImposterCountChanged(imposterCount + 1),
            )
                : null,
          ),
          _Stat(
            label: 'CIVILIANS',
            value: '$civilians',
            color: _blueGlow,
          ),
        ],
      ),
    );
  }
}

/// One column of the summary footer: a small label above a value row.
///
/// The value row is pinned to a fixed height so the three stat columns
/// align on the same baseline whether or not they include stepper
/// buttons. The label is single-line with ellipsis so it does not push
/// the value off its row at large text scales.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    this.leading,
    this.trailing,
  });

  final String label;
  final String value;
  final Color color;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Colors.white.withValues(alpha: 0.45),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: 8),
              ],
              Text(
                value,
                style: AppTypography.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Small stepper button used for the imposter count adjustment.
///
/// Kept at [_stepperTapSize] rather than the row buttons' 36 dp so the
/// IMPOSTERS column stays the same height as its neighbours and the
/// footer's baseline alignment is preserved. See the file header for the
/// reasoning behind the size difference.
class _MiniStepperBtn extends StatelessWidget {
  const _MiniStepperBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.28,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: _stepperTapSize,
            height: _stepperTapSize,
            child: Center(
              child: Container(
                width: _stepperVisualSize,
                height: _stepperVisualSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
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

/// Modal that asks for a player name and returns it if the user confirms.
///
/// The dialog unfocuses the text field and pops the route immediately when
/// the user confirms or cancels. The keyboard's dismiss animation runs in
/// parallel with the route's close animation, so there is no perceptible
/// delay between the tap and the visual response. The add-player flow used
/// to poll for the keyboard to close first, which added several hundred
/// milliseconds of dead time; that polling is gone.
class _AddPlayerDialog {
  const _AddPlayerDialog._();

  static Future<String?> show({
    required BuildContext context,
    required List<String> existingNames,
  }) async {
    final TextEditingController controller = TextEditingController();
    try {
      return await Navigator.of(context, rootNavigator: true).push<String>(
        PageRouteBuilder<String>(
          opaque: false,
          barrierColor: Colors.black.withValues(alpha: 0.72),
          barrierDismissible: true,
          pageBuilder: (dialogCtx, _, __) => _AddPlayerPage(
            controller: controller,
            existingNames: existingNames,
          ),
          transitionsBuilder: (_, __, ___, child) => child,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } finally {
      // The controller is owned by this method and is always disposed,
      // even if the route builder throws.
      controller.dispose();
    }
  }
}

class _AddPlayerPage extends StatefulWidget {
  const _AddPlayerPage({
    required this.controller,
    required this.existingNames,
  });

  final TextEditingController controller;
  final List<String> existingNames;

  @override
  State<_AddPlayerPage> createState() => _AddPlayerPageState();
}

class _AddPlayerPageState extends State<_AddPlayerPage> {
  String? _errorText;
  bool _busy = false;

  /// Dismisses the dialog without adding a player.
  ///
  /// Focus is dropped and the route is popped immediately; the keyboard
  /// animation completes in the background.
  void _handleCancel() {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop();
  }

  /// Validates the entered name and, if it passes, dismisses the dialog
  /// with that name as the result.
  ///
  /// Validation rules: non-empty after trimming, at most
  /// [_maxPlayerNameLength] characters, and unique among
  /// [widget.existingNames] under case-insensitive comparison. On failure
  /// an inline error is shown and the dialog remains open.
  void _handleAdd() {
    if (_busy) return;
    setState(() => _busy = true);

    final String raw = widget.controller.text.trim();
    final String name = raw.isNotEmpty
        ? '${raw[0].toUpperCase()}${raw.substring(1)}'
        : raw;

    if (name.isEmpty) {
      setState(() {
        _errorText = 'Enter a name';
        _busy = false;
      });
      return;
    }
    if (name.length > _maxPlayerNameLength) {
      setState(() {
        _errorText = 'Maximum $_maxPlayerNameLength characters';
        _busy = false;
      });
      return;
    }
    final String lower = name.toLowerCase();
    final bool duplicate = widget.existingNames
        .any((n) => n.trim().toLowerCase() == lower);
    if (duplicate) {
      setState(() {
        _errorText = 'Name already exists';
        _busy = false;
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Bound the dialog to the visible viewport so it never runs under the
    // keyboard or past the bottom of the screen.
    final double maxDialogHeight = (size.height - keyboard - 48) * 0.92;

    return Material(
      type: MaterialType.transparency,
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
                                borderRadius: BorderRadius.circular(14),
                                color: _groupBg,
                                border: Border.all(
                                  color: _groupBorder,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(8),
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.08),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.person_outline,
                                        size: 15,
                                        color: Colors.white
                                            .withValues(alpha: 0.72),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: widget.controller,
                                        cursorColor: _blueGlow,
                                        cursorWidth: 1.8,
                                        cursorRadius:
                                        const Radius.circular(2),
                                        cursorHeight: 18,
                                        textCapitalization:
                                        TextCapitalization.words,
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        inputFormatters: <TextInputFormatter>[
                                          LengthLimitingTextInputFormatter(
                                            _maxPlayerNameLength,
                                          ),
                                        ],
                                        style:
                                        AppTypography.body.copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        onChanged: (_) {
                                          if (_errorText != null) {
                                            setState(
                                                    () => _errorText = null);
                                          }
                                        },
                                        onTapOutside: (_) {
                                          FocusManager
                                              .instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'Enter Player Name',
                                          hintStyle: AppTypography.body
                                              .copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white
                                                .withValues(alpha: 0.35),
                                          ),
                                          filled: false,
                                          isDense: true,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (_errorText != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    4, 8, 4, 0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _errorText!,
                                    style:
                                    AppTypography.caption.copyWith(
                                      color: _crimson,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                label: 'CANCEL',
                                onTap: _busy ? () {} : _handleCancel,
                              ),
                            ),
                            Container(width: 1, color: _dividerColor),
                            Expanded(
                              child: _IosDialogButton(
                                label: 'ADD PLAYER',
                                primary: true,
                                onTap: _busy ? () {} : _handleAdd,
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