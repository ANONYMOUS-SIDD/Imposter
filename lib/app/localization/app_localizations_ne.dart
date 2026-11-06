// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Nepali (`ne`).
class AppLocalizationsNe extends AppLocalizations {
  AppLocalizationsNe([String locale = 'ne']) : super(locale);

  @override
  String get appTitle => 'इम्पोस्टर';

  @override
  String get tagline =>
      'कसैलाई विश्वास नगर्नुहोस्। इम्पोस्टर पत्ता लगाउनुहोस्।';

  @override
  String get startGame => 'खेल सुरु गर्नुहोस्';

  @override
  String get settings => 'सेटिङ';

  @override
  String get startNewGame => 'नयाँ खेल सुरु गर्नुहोस्';

  @override
  String get startNewGameDesc =>
      'नयाँ राउन्डका लागि खेलाडी र नियमहरू मिलाउनुहोस्।';

  @override
  String get continueLabel => 'अगाडि बढ्नुहोस्';

  @override
  String get cancel => 'रद्द गर्नुहोस्';

  @override
  String get retry => 'पुनः प्रयास';

  @override
  String get save => 'सुरक्षित गर्नुहोस्';

  @override
  String get close => 'बन्द गर्नुहोस्';

  @override
  String get delete => 'मेट्नुहोस्';

  @override
  String get edit => 'सम्पादन';

  @override
  String get notYet => 'अहिले होइन';

  @override
  String get setupTitle => 'खेल सेटअप';

  @override
  String get setupSectionLanguage => 'भाषा';

  @override
  String get setupSectionRules => 'खेलका नियमहरू';

  @override
  String get setupSectionCategories => 'शब्द श्रेणीहरू';

  @override
  String get setupSectionCustomWords => 'अनुकूलित शब्दहरू';

  @override
  String get setupSectionPlayers => 'खेलाडीहरू';

  @override
  String get setupStartButton => 'खेल सुरु गर्नुहोस्';

  @override
  String get setupErrorAtLeast3Players => 'कम्तीमा ३ खेलाडी चाहिन्छ';

  @override
  String get setupErrorEnterName => 'प्रत्येक खेलाडीको नाम लेख्नुहोस्';

  @override
  String get setupErrorDuplicateNames => 'खेलाडीको नाम फरक हुनुपर्छ';

  @override
  String get setupErrorSelectCategory => 'कम्तीमा एउटा श्रेणी छान्नुहोस्';

  @override
  String get setupFailedLoadWords => 'शब्दहरू लोड गर्न असफल';

  @override
  String get gameRules => 'खेलका नियमहरू';

  @override
  String get hiddenImposter => 'इम्पोस्टरलाई थाहा छैन';

  @override
  String get hiddenImposterDesc =>
      'इम्पोस्टरहरूलाई उनीहरू इम्पोस्टर हुन् भनेर बताइने छैन।';

  @override
  String get hiddenImposterDisabledDesc =>
      'इम्पोस्टरलाई थाहा छैन सक्रिय हुँदा अक्षम — लुकेको मोडले सधैं सजिलो संकेत प्रयोग गर्छ।';

  @override
  String get imposterHint => 'इम्पोस्टर संकेत';

  @override
  String get imposterHintDesc =>
      'मूल शब्द नदेखाई इम्पोस्टरहरूलाई संकेत दिनुहोस्।';

  @override
  String get multipleImposters => 'बहु इम्पोस्टरहरू';

  @override
  String get multipleImpostersDesc =>
      'खेल थप चुनौतीपूर्ण बनाउन एकभन्दा बढी इम्पोस्टर थप्नुहोस्।';

  @override
  String get hintDifficulty => 'संकेत कठिनाई';

  @override
  String get difficultyEasy => 'सजिलो';

  @override
  String get difficultyMedium => 'मध्यम';

  @override
  String get difficultyHard => 'कठिन';

  @override
  String stepperOfMax(int max) {
    return 'अधिकतम $max मध्ये';
  }

  @override
  String get wordCategories => 'शब्द श्रेणीहरू';

  @override
  String categoriesSelectedCount(int count) {
    return '$count चयन गरियो';
  }

  @override
  String get selectAll => 'सबै छान्नुहोस्';

  @override
  String get clearAll => 'सबै हटाउनुहोस्';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count शब्द',
      one: '१ शब्द',
    );
    return '$_temp0';
  }

  @override
  String get customWords => 'अनुकूलित शब्दहरू';

  @override
  String get customWordsInclude => 'खेलमा अनुकूलित शब्दहरू समावेश गर्नुहोस्';

  @override
  String get customWordsIncludeDesc =>
      'आफ्नै शब्दहरू थप्नुहोस् र साथीहरूसँग खेल्नुहोस्।';

  @override
  String get addWord => 'शब्द थप्नुहोस्';

  @override
  String get emptyCustomWordsTitle => 'अहिलेसम्म कुनै अनुकूलित शब्द छैन';

  @override
  String get emptyCustomWordsDesc =>
      'पहिलो शब्द बनाउन \"शब्द थप्नुहोस्\" ट्याप गर्नुहोस्।';

  @override
  String get toggleOnToPlay => 'यी शब्दहरूसँग खेल्न अन गर्नुहोस्।';

  @override
  String get deleteWordTitle => 'यो शब्द मेट्ने?';

  @override
  String deleteWordBody(String word) {
    return '\"$word\" तपाईंको अनुकूलित शब्दहरूबाट हटाइनेछ।';
  }

  @override
  String get players => 'खेलाडीहरू';

  @override
  String get requiredLabel => 'आवश्यक';

  @override
  String get duplicateNameLabel => 'नाम दोहोरिएको छ';

  @override
  String playerHint(int number) {
    return 'खेलाडी $number';
  }

  @override
  String get addPlayer => 'खेलाडी थप्नुहोस्';

  @override
  String get moveUp => 'माथि सार्नुहोस्';

  @override
  String get moveDown => 'तल सार्नुहोस्';

  @override
  String get remove => 'हटाउनुहोस्';

  @override
  String get playerOptions => 'खेलाडी विकल्पहरू';

  @override
  String get summaryTotal => 'कुल';

  @override
  String get summaryImposters => 'इम्पोस्टर';

  @override
  String get summaryCivilians => 'नागरिक';

  @override
  String get addCustomWordTitle => 'अनुकूलित शब्द थप्नुहोस्';

  @override
  String get editWordTitle => 'शब्द सम्पादन गर्नुहोस्';

  @override
  String get sectionWord => 'शब्द';

  @override
  String get fieldEnglish => 'अंग्रेजी';

  @override
  String get fieldNepali => 'नेपाली (वैकल्पिक)';

  @override
  String get hintEnglish => 'जस्तै: Guitar';

  @override
  String get hintNepali => 'जस्तै: गितार';

  @override
  String get sectionCategory => 'श्रेणी';

  @override
  String get sectionHints => 'संकेतहरू (वैकल्पिक)';

  @override
  String get hintsOptionalDesc =>
      'खाली छोड्नुहोस् भने अंग्रेजी शब्द संकेतको रूपमा प्रयोग हुनेछ।';

  @override
  String get fieldEasyHint => 'सजिलो संकेत';

  @override
  String get fieldMediumHint => 'मध्यम संकेत';

  @override
  String get fieldHardHint => 'कठिन संकेत';

  @override
  String get hintEasyHint => 'जस्तै: Instrument';

  @override
  String get hintMediumHint => 'जस्तै: Strings';

  @override
  String get hintHardHint => 'जस्तै: Frets';

  @override
  String get wordRequired => 'आवश्यक';

  @override
  String get wordExists => 'शब्द पहिले नै अवस्थित छ';

  @override
  String get currentPlayer => 'हालको खेलाडी';

  @override
  String get swipeUpToReveal => 'आफ्नो रहस्य देखाउन माथि स्वाइप गर्नुहोस्';

  @override
  String get swipeUp => 'माथि स्वाइप गर्नुहोस्';

  @override
  String get yourWord => 'तपाईंको शब्द';

  @override
  String get youAreImposter => 'तपाईं इम्पोस्टर हुनुहुन्छ';

  @override
  String get passToNext => 'अर्को खेलाडीलाई दिनुहोस्';

  @override
  String nextPlayer(String name) {
    return 'अर्को खेलाडी: $name';
  }

  @override
  String get lastPlayer =>
      'अन्तिम खेलाडी — सुरु गर्न अगाडि बढ्नुहोस् ट्याप गर्नुहोस्';

  @override
  String get everyoneHasSecret => 'सबैसँग उनीहरूको रहस्य छ';

  @override
  String get findImposter => 'खेल सुरु होस्। इम्पोस्टर पत्ता लगाउनुहोस्!';

  @override
  String get readyInstruction =>
      'आफ्नो शब्द प्रत्यक्ष नदेखाई पालैपालो वर्णन गर्नुहोस्।';

  @override
  String get showResult => 'नतिजा देखाउनुहोस्';

  @override
  String get readyToReveal => 'खुलासा गर्न तयार?';

  @override
  String get readyToRevealDesc =>
      'के तपाईं इम्पोस्टरहरू र गोप्य शब्द खुलासा गर्न निश्चित हुनुहुन्छ?';

  @override
  String get revealNow => 'अहिले खुलासा गर्नुहोस्';

  @override
  String get theImposter => 'इम्पोस्टर';

  @override
  String get originalWord => 'मूल शब्द';

  @override
  String get hintWord => 'संकेत शब्द';

  @override
  String get playAgain => 'फेरि खेल्नुहोस्';

  @override
  String get playAgainTitle => 'अर्को राउन्ड खेल्ने?';

  @override
  String get playAgainDesc => 'एही खेलाडी र सेटिङसँग नयाँ राउन्ड सुरु गर्ने?';

  @override
  String get backToHome => 'गृह पृष्ठमा फर्कनुहोस्';

  @override
  String get gameSessionNotFound => 'खेल सत्र फेला परेन';

  @override
  String get startNewGamePrompt => 'गृह स्क्रिनबाट नयाँ खेल सुरु गर्नुहोस्।';

  @override
  String get failedStartNewRound => 'नयाँ राउन्ड सुरु गर्न असफल';

  @override
  String get sectionAudio => 'अडियो';

  @override
  String get soundEffects => 'ध्वनि प्रभावहरू';

  @override
  String get soundEffectsDesc => 'कार्ड खुलासा, नतिजा, र बटन ध्वनिहरू';

  @override
  String get volume => 'भोल्युम';

  @override
  String get sectionFeedback => 'प्रतिक्रिया';

  @override
  String get hapticFeedback => 'ह्याप्टिक प्रतिक्रिया';

  @override
  String get hapticFeedbackDesc => 'कार्ड खुलासा र नतिजामा कम्पन';

  @override
  String get sectionAbout => 'बारेमा';

  @override
  String get appVersion => 'एप संस्करण';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get aboutImposter => 'इम्पोस्टरको बारेमा';

  @override
  String get privacyBody =>
      'इम्पोस्टर पूर्ण रूपमा तपाईंको यन्त्रमा चल्छ।\n\nकुनै व्यक्तिगत डेटा सङ्कलन, भण्डारण, वा प्रसारण गरिँदैन। एप पूर्ण रूपमा अफलाइन काम गर्छ, कुनै खाता आवश्यक छैन, र कुनै इन्टरनेट अनुमति अनुरोध गर्दैन।';

  @override
  String get aboutBody =>
      'एउटै फोनमा ३+ खेलाडीहरूका लागि प्रिमियम अफलाइन सामाजिक पार्टी खेल।\n\nकसैलाई विश्वास नगर्नुहोस्। इम्पोस्टर पत्ता लगाउनुहोस्।';
}
