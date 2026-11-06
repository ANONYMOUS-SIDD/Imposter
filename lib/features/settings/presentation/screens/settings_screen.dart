// settings_screen.dart
//
// App settings screen. Hosts four sections:
//   • Audio — sound effects toggle and volume slider.
//   • Feedback — haptic feedback toggle.
//   • Language — UI locale selection.
//   • About — app version, privacy policy, and about dialog.
//
// All state is held in providers; this widget is a pure view that reads
// from `audioSettingsProvider`, `hapticSettingsProvider`, and
// `localeProvider`, and writes back through each notifier. No local
// state is kept, so changes propagate everywhere the providers are
// watched.
//
// Provider writes are asynchronous. Each callback wraps the write in
// `unawaited(...)` so the returned future does not become an unhandled
// async error if it throws, and so the linter stays clean.
//
// Volume slider
// -------------
// The slider uses `divisions: 20`, snapping to 5-percent steps. Without
// divisions, `onChanged` fires on every pixel of a drag — several dozen
// SharedPreferences writes per gesture — which is expensive on the main
// isolate. The stepped value also gives a cleaner tactile feel.
//
// Layout
// ------
// The body is a `ListView` so the whole screen scrolls, and `SafeArea`
// keeps the last row clear of the home indicator on notched devices.
// Every text element that can be long — sound/haptic descriptions, the
// volume percentage, locale labels, and the app version — is bounded
// with `maxLines` + ellipsis. The volume percentage is placed in a
// fixed-width box sized to fit the longest possible value ("100%") at
// the app's maximum text scale.
//
// Info dialogs (Privacy and About) use `scrollable: true`. Both bodies
// are multi-paragraph and can exceed the dialog height at large text
// scales; without `scrollable`, they would clip.
//
// Locale labels are hardcoded in their own script ("English",
// "नेपाली") rather than pulled from `AppLocalizations`. This is the
// standard practice for a language picker: each name is shown in the
// script a speaker of that language would recognize, and translating
// them would defeat the purpose.
//
// Version
// -------
// The app version is a hardcoded constant. In a real release pipeline
// it should come from `package_info_plus` (or a build-time
// `--dart-define`) so it cannot drift from `pubspec.yaml`.
//
// Section spacing
// ---------------
// `_SectionHeader` uses a 4 dp left inset while the `ListTile`s below
// use 16 dp. The difference is intentional and matches the visual
// hierarchy used elsewhere in the app. Do not change it without also
// changing the Setup screen's section headers.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/providers/app_providers.dart';
import '../providers/locale_provider.dart';

/// App version shown in the About section.
///
/// Hardcoded for now. Should be sourced from `package_info_plus` or a
/// build-time define in a release pipeline.
const String _appVersion = '1.0.0';

/// Number of steps the volume slider snaps to. See the file header for
/// why divisions are required.
const int _volumeDivisions = 20;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final AudioSettings audio = ref.watch(audioSettingsProvider);
    final HapticSettings haptic = ref.watch(hapticSettingsProvider);
    final Locale locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.settings, style: AppTypography.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
      // Top inset is handled by AppBar; bottom inset keeps the final row
      // above the home indicator on notched devices.
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          children: <Widget>[
            _SectionHeader(label: l10n.sectionAudio),
            SwitchListTile(
              title: Text(l10n.soundEffects, style: AppTypography.body),
              subtitle: Text(
                l10n.soundEffectsDesc,
                style: AppTypography.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              value: audio.soundEnabled,
              activeThumbColor: AppColors.neonPurple,
              activeTrackColor:
              AppColors.primaryPurple.withValues(alpha: 0.55),
              onChanged: (bool v) => unawaited(
                ref
                    .read(audioSettingsProvider.notifier)
                    .setSoundEnabled(v),
              ),
            ),
            if (audio.soundEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    Text(l10n.volume, style: AppTypography.caption),
                    Expanded(
                      child: Slider(
                        value: audio.volume,
                        divisions: _volumeDivisions,
                        label:
                        '${(audio.volume * 100).round()}%',
                        activeColor: AppColors.neonPurple,
                        inactiveColor: AppColors.secondarySurface,
                        onChanged: (double v) => unawaited(
                          ref
                              .read(audioSettingsProvider.notifier)
                              .setVolume(v),
                        ),
                      ),
                    ),
                    SizedBox(
                      // Sized to fit "100%" at the maximum text scale the
                      // app allows.
                      width: 48,
                      child: Text(
                        '${(audio.volume * 100).round()}%',
                        style: AppTypography.caption,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            _SectionHeader(label: l10n.sectionFeedback),
            SwitchListTile(
              title: Text(l10n.hapticFeedback, style: AppTypography.body),
              subtitle: Text(
                l10n.hapticFeedbackDesc,
                style: AppTypography.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              value: haptic.enabled,
              activeThumbColor: AppColors.neonPurple,
              activeTrackColor:
              AppColors.primaryPurple.withValues(alpha: 0.55),
              onChanged: (bool v) => unawaited(
                ref
                    .read(hapticSettingsProvider.notifier)
                    .setEnabled(v),
              ),
            ),

            _SectionHeader(label: l10n.setupSectionLanguage),
            _LocaleOption(
              label: 'English',
              selected: locale.languageCode == 'en',
              onTap: () => unawaited(
                ref
                    .read(localeProvider.notifier)
                    .setLocale(const Locale('en')),
              ),
            ),
            _LocaleOption(
              label: 'नेपाली',
              selected: locale.languageCode == 'ne',
              onTap: () => unawaited(
                ref
                    .read(localeProvider.notifier)
                    .setLocale(const Locale('ne')),
              ),
            ),

            _SectionHeader(label: l10n.sectionAbout),
            ListTile(
              title: Text(l10n.appVersion, style: AppTypography.body),
              trailing: Text(
                _appVersion,
                style: AppTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            ListTile(
              title: Text(l10n.privacyPolicy, style: AppTypography.body),
              trailing: const Icon(Icons.chevron_right, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              onTap: () => _showInfoDialog(
                context,
                title: l10n.privacyPolicy,
                body: l10n.privacyBody,
                closeLabel: l10n.close,
              ),
            ),
            ListTile(
              title: Text(l10n.aboutImposter, style: AppTypography.body),
              trailing: const Icon(Icons.chevron_right, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              onTap: () => _showInfoDialog(
                context,
                title: l10n.aboutImposter,
                body: l10n.aboutBody,
                closeLabel: l10n.close,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Opens a scrollable info dialog.
  ///
  /// Used for both the Privacy Policy and About screens. The dialog is
  /// scrollable because both bodies are multi-paragraph and can exceed
  /// the available height at large text scales.
  void _showInfoDialog(
      BuildContext context, {
        required String title,
        required String body,
        required String closeLabel,
      }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.secondarySurface,
        scrollable: true,
        title: Text(
          title,
          style: AppTypography.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(body, style: AppTypography.body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(closeLabel),
          ),
        ],
      ),
    );
  }
}

/// Small section header used above each settings group.
///
/// Left inset matches the visual hierarchy used elsewhere in the app;
/// changing it would require a matching change on the Setup screen.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 20, bottom: 4),
      child: Text(
        label,
        style: AppTypography.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Tappable row for a UI language option.
///
/// Declares `Semantics(button, selected)` so screen readers announce the
/// row as a selectable button and identify the current selection.
class _LocaleOption extends StatelessWidget {
  const _LocaleOption({
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
      child: ListTile(
        title: Text(
          label,
          style: AppTypography.body,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: selected
            ? const Icon(Icons.check, color: AppColors.neonPurple)
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: onTap,
      ),
    );
  }
}