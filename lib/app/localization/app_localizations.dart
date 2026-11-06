import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ne.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ne'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'IMPOSTER'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Trust No One. Find the Imposter.'**
  String get tagline;

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start Game'**
  String get startGame;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @startNewGame.
  ///
  /// In en, this message translates to:
  /// **'Start a New Game'**
  String get startNewGame;

  /// No description provided for @startNewGameDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure players and rules for a new round.'**
  String get startNewGameDesc;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @notYet.
  ///
  /// In en, this message translates to:
  /// **'Not Yet'**
  String get notYet;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Game Setup'**
  String get setupTitle;

  /// No description provided for @setupSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get setupSectionLanguage;

  /// No description provided for @setupSectionRules.
  ///
  /// In en, this message translates to:
  /// **'GAME RULES'**
  String get setupSectionRules;

  /// No description provided for @setupSectionCategories.
  ///
  /// In en, this message translates to:
  /// **'WORD CATEGORIES'**
  String get setupSectionCategories;

  /// No description provided for @setupSectionCustomWords.
  ///
  /// In en, this message translates to:
  /// **'CUSTOM WORDS'**
  String get setupSectionCustomWords;

  /// No description provided for @setupSectionPlayers.
  ///
  /// In en, this message translates to:
  /// **'PLAYERS'**
  String get setupSectionPlayers;

  /// No description provided for @setupStartButton.
  ///
  /// In en, this message translates to:
  /// **'START GAME'**
  String get setupStartButton;

  /// No description provided for @setupErrorAtLeast3Players.
  ///
  /// In en, this message translates to:
  /// **'At least 3 players required'**
  String get setupErrorAtLeast3Players;

  /// No description provided for @setupErrorEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for every player'**
  String get setupErrorEnterName;

  /// No description provided for @setupErrorDuplicateNames.
  ///
  /// In en, this message translates to:
  /// **'Player names must be unique'**
  String get setupErrorDuplicateNames;

  /// No description provided for @setupErrorSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select at least one category'**
  String get setupErrorSelectCategory;

  /// No description provided for @setupFailedLoadWords.
  ///
  /// In en, this message translates to:
  /// **'Failed to load words'**
  String get setupFailedLoadWords;

  /// No description provided for @gameRules.
  ///
  /// In en, this message translates to:
  /// **'GAME RULES'**
  String get gameRules;

  /// No description provided for @hiddenImposter.
  ///
  /// In en, this message translates to:
  /// **'Imposter Doesn\'t Know'**
  String get hiddenImposter;

  /// No description provided for @hiddenImposterDesc.
  ///
  /// In en, this message translates to:
  /// **'Imposters will not be told that they are imposters.'**
  String get hiddenImposterDesc;

  /// No description provided for @hiddenImposterDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Disabled while Imposter Doesn\'t Know is on — hidden mode always uses an Easy hint.'**
  String get hiddenImposterDisabledDesc;

  /// No description provided for @imposterHint.
  ///
  /// In en, this message translates to:
  /// **'Imposter Hint'**
  String get imposterHint;

  /// No description provided for @imposterHintDesc.
  ///
  /// In en, this message translates to:
  /// **'Give imposters a hint instead of revealing the original word.'**
  String get imposterHintDesc;

  /// No description provided for @multipleImposters.
  ///
  /// In en, this message translates to:
  /// **'Multiple Imposters'**
  String get multipleImposters;

  /// No description provided for @multipleImpostersDesc.
  ///
  /// In en, this message translates to:
  /// **'Add more than one imposter to make the game more challenging.'**
  String get multipleImpostersDesc;

  /// No description provided for @hintDifficulty.
  ///
  /// In en, this message translates to:
  /// **'HINT DIFFICULTY'**
  String get hintDifficulty;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// No description provided for @stepperOfMax.
  ///
  /// In en, this message translates to:
  /// **'of max {max}'**
  String stepperOfMax(int max);

  /// No description provided for @wordCategories.
  ///
  /// In en, this message translates to:
  /// **'WORD CATEGORIES'**
  String get wordCategories;

  /// No description provided for @categoriesSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String categoriesSelectedCount(int count);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @wordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word} other{{count} words}}'**
  String wordCount(int count);

  /// No description provided for @customWords.
  ///
  /// In en, this message translates to:
  /// **'CUSTOM WORDS'**
  String get customWords;

  /// No description provided for @customWordsInclude.
  ///
  /// In en, this message translates to:
  /// **'Include custom words in game'**
  String get customWordsInclude;

  /// No description provided for @customWordsIncludeDesc.
  ///
  /// In en, this message translates to:
  /// **'Add your own words and play with your friends.'**
  String get customWordsIncludeDesc;

  /// No description provided for @addWord.
  ///
  /// In en, this message translates to:
  /// **'Add Word'**
  String get addWord;

  /// No description provided for @emptyCustomWordsTitle.
  ///
  /// In en, this message translates to:
  /// **'No custom words yet'**
  String get emptyCustomWordsTitle;

  /// No description provided for @emptyCustomWordsDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add Word\" to create your first one.'**
  String get emptyCustomWordsDesc;

  /// No description provided for @toggleOnToPlay.
  ///
  /// In en, this message translates to:
  /// **'Toggle on to play with these words.'**
  String get toggleOnToPlay;

  /// No description provided for @deleteWordTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this word?'**
  String get deleteWordTitle;

  /// No description provided for @deleteWordBody.
  ///
  /// In en, this message translates to:
  /// **'\"{word}\" will be removed from your custom words.'**
  String deleteWordBody(String word);

  /// No description provided for @players.
  ///
  /// In en, this message translates to:
  /// **'PLAYERS'**
  String get players;

  /// No description provided for @requiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredLabel;

  /// No description provided for @duplicateNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Duplicate name'**
  String get duplicateNameLabel;

  /// No description provided for @playerHint.
  ///
  /// In en, this message translates to:
  /// **'Player {number}'**
  String playerHint(int number);

  /// No description provided for @addPlayer.
  ///
  /// In en, this message translates to:
  /// **'Add Player'**
  String get addPlayer;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get moveDown;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @playerOptions.
  ///
  /// In en, this message translates to:
  /// **'Player options'**
  String get playerOptions;

  /// No description provided for @summaryTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get summaryTotal;

  /// No description provided for @summaryImposters.
  ///
  /// In en, this message translates to:
  /// **'IMPOSTERS'**
  String get summaryImposters;

  /// No description provided for @summaryCivilians.
  ///
  /// In en, this message translates to:
  /// **'CIVILIANS'**
  String get summaryCivilians;

  /// No description provided for @addCustomWordTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Word'**
  String get addCustomWordTitle;

  /// No description provided for @editWordTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Word'**
  String get editWordTitle;

  /// No description provided for @sectionWord.
  ///
  /// In en, this message translates to:
  /// **'WORD'**
  String get sectionWord;

  /// No description provided for @fieldEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get fieldEnglish;

  /// No description provided for @fieldNepali.
  ///
  /// In en, this message translates to:
  /// **'Nepali (optional)'**
  String get fieldNepali;

  /// No description provided for @hintEnglish.
  ///
  /// In en, this message translates to:
  /// **'e.g. Guitar'**
  String get hintEnglish;

  /// No description provided for @hintNepali.
  ///
  /// In en, this message translates to:
  /// **'e.g. गितार'**
  String get hintNepali;

  /// No description provided for @sectionCategory.
  ///
  /// In en, this message translates to:
  /// **'CATEGORY'**
  String get sectionCategory;

  /// No description provided for @sectionHints.
  ///
  /// In en, this message translates to:
  /// **'HINTS (OPTIONAL)'**
  String get sectionHints;

  /// No description provided for @hintsOptionalDesc.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use the English word as the hint.'**
  String get hintsOptionalDesc;

  /// No description provided for @fieldEasyHint.
  ///
  /// In en, this message translates to:
  /// **'Easy hint'**
  String get fieldEasyHint;

  /// No description provided for @fieldMediumHint.
  ///
  /// In en, this message translates to:
  /// **'Medium hint'**
  String get fieldMediumHint;

  /// No description provided for @fieldHardHint.
  ///
  /// In en, this message translates to:
  /// **'Hard hint'**
  String get fieldHardHint;

  /// No description provided for @hintEasyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Instrument'**
  String get hintEasyHint;

  /// No description provided for @hintMediumHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Strings'**
  String get hintMediumHint;

  /// No description provided for @hintHardHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Frets'**
  String get hintHardHint;

  /// No description provided for @wordRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get wordRequired;

  /// No description provided for @wordExists.
  ///
  /// In en, this message translates to:
  /// **'Word already exists'**
  String get wordExists;

  /// No description provided for @currentPlayer.
  ///
  /// In en, this message translates to:
  /// **'CURRENT PLAYER'**
  String get currentPlayer;

  /// No description provided for @swipeUpToReveal.
  ///
  /// In en, this message translates to:
  /// **'Swipe up to reveal your secret'**
  String get swipeUpToReveal;

  /// No description provided for @swipeUp.
  ///
  /// In en, this message translates to:
  /// **'Swipe up'**
  String get swipeUp;

  /// No description provided for @yourWord.
  ///
  /// In en, this message translates to:
  /// **'YOUR WORD'**
  String get yourWord;

  /// No description provided for @youAreImposter.
  ///
  /// In en, this message translates to:
  /// **'YOU ARE THE IMPOSTER'**
  String get youAreImposter;

  /// No description provided for @passToNext.
  ///
  /// In en, this message translates to:
  /// **'Pass to the next player'**
  String get passToNext;

  /// No description provided for @nextPlayer.
  ///
  /// In en, this message translates to:
  /// **'Next Player: {name}'**
  String nextPlayer(String name);

  /// No description provided for @lastPlayer.
  ///
  /// In en, this message translates to:
  /// **'Last player — tap Continue to begin'**
  String get lastPlayer;

  /// No description provided for @everyoneHasSecret.
  ///
  /// In en, this message translates to:
  /// **'Everyone Has Their Secret'**
  String get everyoneHasSecret;

  /// No description provided for @findImposter.
  ///
  /// In en, this message translates to:
  /// **'Let the game begin. Find the imposter!'**
  String get findImposter;

  /// No description provided for @readyInstruction.
  ///
  /// In en, this message translates to:
  /// **'Take turns describing your word without revealing it directly.'**
  String get readyInstruction;

  /// No description provided for @showResult.
  ///
  /// In en, this message translates to:
  /// **'SHOW RESULT'**
  String get showResult;

  /// No description provided for @readyToReveal.
  ///
  /// In en, this message translates to:
  /// **'Ready to Reveal?'**
  String get readyToReveal;

  /// No description provided for @readyToRevealDesc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reveal the imposters and the secret word?'**
  String get readyToRevealDesc;

  /// No description provided for @revealNow.
  ///
  /// In en, this message translates to:
  /// **'Reveal Now'**
  String get revealNow;

  /// No description provided for @theImposter.
  ///
  /// In en, this message translates to:
  /// **'THE IMPOSTER'**
  String get theImposter;

  /// No description provided for @originalWord.
  ///
  /// In en, this message translates to:
  /// **'ORIGINAL WORD'**
  String get originalWord;

  /// No description provided for @hintWord.
  ///
  /// In en, this message translates to:
  /// **'HINT WORD'**
  String get hintWord;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'PLAY AGAIN'**
  String get playAgain;

  /// No description provided for @playAgainTitle.
  ///
  /// In en, this message translates to:
  /// **'Play Another Round?'**
  String get playAgainTitle;

  /// No description provided for @playAgainDesc.
  ///
  /// In en, this message translates to:
  /// **'Start a new round with the same players and settings?'**
  String get playAgainDesc;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @gameSessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Game session not found'**
  String get gameSessionNotFound;

  /// No description provided for @startNewGamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Start a new game from the home screen.'**
  String get startNewGamePrompt;

  /// No description provided for @failedStartNewRound.
  ///
  /// In en, this message translates to:
  /// **'Failed to start new round'**
  String get failedStartNewRound;

  /// No description provided for @sectionAudio.
  ///
  /// In en, this message translates to:
  /// **'AUDIO'**
  String get sectionAudio;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects'**
  String get soundEffects;

  /// No description provided for @soundEffectsDesc.
  ///
  /// In en, this message translates to:
  /// **'Card reveals, results, and button sounds'**
  String get soundEffectsDesc;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @sectionFeedback.
  ///
  /// In en, this message translates to:
  /// **'FEEDBACK'**
  String get sectionFeedback;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback'**
  String get hapticFeedback;

  /// No description provided for @hapticFeedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on card reveals and results'**
  String get hapticFeedbackDesc;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get sectionAbout;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @aboutImposter.
  ///
  /// In en, this message translates to:
  /// **'About Imposter'**
  String get aboutImposter;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Imposter runs entirely on your device.\n\nNo personal data is collected, stored, or transmitted. The app works fully offline, requires no account, and requests no internet permission.'**
  String get privacyBody;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'A premium offline social party game for 3+ players on one phone.\n\nTrust no one. Find the imposter.'**
  String get aboutBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ne'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ne':
      return AppLocalizationsNe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
