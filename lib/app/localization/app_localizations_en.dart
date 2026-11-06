// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'IMPOSTER';

  @override
  String get tagline => 'Trust No One. Find the Imposter.';

  @override
  String get startGame => 'Start Game';

  @override
  String get settings => 'Settings';

  @override
  String get startNewGame => 'Start a New Game';

  @override
  String get startNewGameDesc => 'Configure players and rules for a new round.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get notYet => 'Not Yet';

  @override
  String get setupTitle => 'Game Setup';

  @override
  String get setupSectionLanguage => 'LANGUAGE';

  @override
  String get setupSectionRules => 'GAME RULES';

  @override
  String get setupSectionCategories => 'WORD CATEGORIES';

  @override
  String get setupSectionCustomWords => 'CUSTOM WORDS';

  @override
  String get setupSectionPlayers => 'PLAYERS';

  @override
  String get setupStartButton => 'START GAME';

  @override
  String get setupErrorAtLeast3Players => 'At least 3 players required';

  @override
  String get setupErrorEnterName => 'Enter a name for every player';

  @override
  String get setupErrorDuplicateNames => 'Player names must be unique';

  @override
  String get setupErrorSelectCategory => 'Select at least one category';

  @override
  String get setupFailedLoadWords => 'Failed to load words';

  @override
  String get gameRules => 'GAME RULES';

  @override
  String get hiddenImposter => 'Imposter Doesn\'t Know';

  @override
  String get hiddenImposterDesc =>
      'Imposters will not be told that they are imposters.';

  @override
  String get hiddenImposterDisabledDesc =>
      'Disabled while Imposter Doesn\'t Know is on — hidden mode always uses an Easy hint.';

  @override
  String get imposterHint => 'Imposter Hint';

  @override
  String get imposterHintDesc =>
      'Give imposters a hint instead of revealing the original word.';

  @override
  String get multipleImposters => 'Multiple Imposters';

  @override
  String get multipleImpostersDesc =>
      'Add more than one imposter to make the game more challenging.';

  @override
  String get hintDifficulty => 'HINT DIFFICULTY';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String stepperOfMax(int max) {
    return 'of max $max';
  }

  @override
  String get wordCategories => 'WORD CATEGORIES';

  @override
  String categoriesSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectAll => 'Select All';

  @override
  String get clearAll => 'Clear All';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String get customWords => 'CUSTOM WORDS';

  @override
  String get customWordsInclude => 'Include custom words in game';

  @override
  String get customWordsIncludeDesc =>
      'Add your own words and play with your friends.';

  @override
  String get addWord => 'Add Word';

  @override
  String get emptyCustomWordsTitle => 'No custom words yet';

  @override
  String get emptyCustomWordsDesc =>
      'Tap \"Add Word\" to create your first one.';

  @override
  String get toggleOnToPlay => 'Toggle on to play with these words.';

  @override
  String get deleteWordTitle => 'Delete this word?';

  @override
  String deleteWordBody(String word) {
    return '\"$word\" will be removed from your custom words.';
  }

  @override
  String get players => 'PLAYERS';

  @override
  String get requiredLabel => 'Required';

  @override
  String get duplicateNameLabel => 'Duplicate name';

  @override
  String playerHint(int number) {
    return 'Player $number';
  }

  @override
  String get addPlayer => 'Add Player';

  @override
  String get moveUp => 'Move Up';

  @override
  String get moveDown => 'Move Down';

  @override
  String get remove => 'Remove';

  @override
  String get playerOptions => 'Player options';

  @override
  String get summaryTotal => 'TOTAL';

  @override
  String get summaryImposters => 'IMPOSTERS';

  @override
  String get summaryCivilians => 'CIVILIANS';

  @override
  String get addCustomWordTitle => 'Add Custom Word';

  @override
  String get editWordTitle => 'Edit Word';

  @override
  String get sectionWord => 'WORD';

  @override
  String get fieldEnglish => 'English';

  @override
  String get fieldNepali => 'Nepali (optional)';

  @override
  String get hintEnglish => 'e.g. Guitar';

  @override
  String get hintNepali => 'e.g. गितार';

  @override
  String get sectionCategory => 'CATEGORY';

  @override
  String get sectionHints => 'HINTS (OPTIONAL)';

  @override
  String get hintsOptionalDesc =>
      'Leave blank to use the English word as the hint.';

  @override
  String get fieldEasyHint => 'Easy hint';

  @override
  String get fieldMediumHint => 'Medium hint';

  @override
  String get fieldHardHint => 'Hard hint';

  @override
  String get hintEasyHint => 'e.g. Instrument';

  @override
  String get hintMediumHint => 'e.g. Strings';

  @override
  String get hintHardHint => 'e.g. Frets';

  @override
  String get wordRequired => 'Required';

  @override
  String get wordExists => 'Word already exists';

  @override
  String get currentPlayer => 'CURRENT PLAYER';

  @override
  String get swipeUpToReveal => 'Swipe up to reveal your secret';

  @override
  String get swipeUp => 'Swipe up';

  @override
  String get yourWord => 'YOUR WORD';

  @override
  String get youAreImposter => 'YOU ARE THE IMPOSTER';

  @override
  String get passToNext => 'Pass to the next player';

  @override
  String nextPlayer(String name) {
    return 'Next Player: $name';
  }

  @override
  String get lastPlayer => 'Last player — tap Continue to begin';

  @override
  String get everyoneHasSecret => 'Everyone Has Their Secret';

  @override
  String get findImposter => 'Let the game begin. Find the imposter!';

  @override
  String get readyInstruction =>
      'Take turns describing your word without revealing it directly.';

  @override
  String get showResult => 'SHOW RESULT';

  @override
  String get readyToReveal => 'Ready to Reveal?';

  @override
  String get readyToRevealDesc =>
      'Are you sure you want to reveal the imposters and the secret word?';

  @override
  String get revealNow => 'Reveal Now';

  @override
  String get theImposter => 'THE IMPOSTER';

  @override
  String get originalWord => 'ORIGINAL WORD';

  @override
  String get hintWord => 'HINT WORD';

  @override
  String get playAgain => 'PLAY AGAIN';

  @override
  String get playAgainTitle => 'Play Another Round?';

  @override
  String get playAgainDesc =>
      'Start a new round with the same players and settings?';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get gameSessionNotFound => 'Game session not found';

  @override
  String get startNewGamePrompt => 'Start a new game from the home screen.';

  @override
  String get failedStartNewRound => 'Failed to start new round';

  @override
  String get sectionAudio => 'AUDIO';

  @override
  String get soundEffects => 'Sound Effects';

  @override
  String get soundEffectsDesc => 'Card reveals, results, and button sounds';

  @override
  String get volume => 'Volume';

  @override
  String get sectionFeedback => 'FEEDBACK';

  @override
  String get hapticFeedback => 'Haptic Feedback';

  @override
  String get hapticFeedbackDesc => 'Vibrate on card reveals and results';

  @override
  String get sectionAbout => 'ABOUT';

  @override
  String get appVersion => 'App Version';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get aboutImposter => 'About Imposter';

  @override
  String get privacyBody =>
      'Imposter runs entirely on your device.\n\nNo personal data is collected, stored, or transmitted. The app works fully offline, requires no account, and requests no internet permission.';

  @override
  String get aboutBody =>
      'A premium offline social party game for 3+ players on one phone.\n\nTrust no one. Find the imposter.';
}
