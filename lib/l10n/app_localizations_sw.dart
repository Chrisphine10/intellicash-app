// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class L10nSw extends L10n {
  L10nSw([String locale = 'sw']) : super(locale);

  @override
  String get appTagline => 'VSLA yako mfukoni mwako';

  @override
  String get navDashboard => 'Muhtasari';

  @override
  String get navMeetings => 'Mikutano';

  @override
  String get navMembers => 'Wanachama';

  @override
  String get navLoans => 'Mikopo';

  @override
  String get navMore => 'Zaidi';

  @override
  String get welcomeTitle => 'Karibu Intelli-Cash';

  @override
  String get welcomeCreateAccountPrompt => 'Fungua akaunti yako ili uanze.';

  @override
  String get welcomeAccountReady => 'Akaunti yako iko tayari.';

  @override
  String get createAccount => 'Fungua Akaunti';

  @override
  String get createAccountSubtitle =>
      'Ni mara yako ya kwanza? Fungua akaunti ya kikundi chenu, yako binafsi, au ya kazi yako kama wakala.';

  @override
  String get signIn => 'Ingia';

  @override
  String get signInSubtitle => 'Tayari nina akaunti ya Intelli-Cash.';

  @override
  String get signOut => 'Toka';

  @override
  String signedInAs(String name) {
    return 'Umeingia kama $name.';
  }

  @override
  String get setUpGroup => 'Sajili kikundi changu kwenye simu hii';

  @override
  String get setUpGroupSubtitle =>
      'Weka akiba, mikopo na mikutano ya kikundi chenu — hufanya kazi bila intaneti baada ya kusajili.';

  @override
  String get whoIsThisAccountFor => 'Akaunti hii ni ya nani?';

  @override
  String get pickOneLater =>
      'Chagua moja — unaweza kuongeza akaunti nyingine baadaye.';

  @override
  String get accountTypeGroup => 'Kikundi Chetu';

  @override
  String get accountTypeGroupSubtitle =>
      'Simu hii itatunza akiba, mikopo na mikutano ya kikundi chetu.';

  @override
  String get accountTypeMember => 'Mimi Peke Yangu';

  @override
  String get accountTypeMemberSubtitle =>
      'Nataka kuona akiba, hisa na mikopo yangu.';

  @override
  String get accountTypeAgent => 'Wakala wa Ugani';

  @override
  String get accountTypeAgentSubtitle =>
      'Wakala wa Kijiji au CBT — nasaidia na kufuatilia vikundi kadhaa.';

  @override
  String get change => 'Badilisha';

  @override
  String get groupNameLabel => 'Jina la kikundi';

  @override
  String get yourFullName => 'Jina lako kamili';

  @override
  String get phoneNumber => 'Nambari ya simu';

  @override
  String get password => 'Nenosiri';

  @override
  String get passwordHint => 'Angalau herufi 6 — liweke siri.';

  @override
  String get repeatPassword => 'Rudia nenosiri';

  @override
  String get emailOptional => 'Barua pepe (si lazima)';

  @override
  String get countyOptional => 'Kaunti (si lazima)';

  @override
  String get createMyAccount => 'Fungua Akaunti Yangu';

  @override
  String get creatingAccount => 'Inafungua akaunti…';

  @override
  String get registerNeedsInternet =>
      'Kufungua akaunti kunahitaji intaneti. Nambari yako ya simu ndiyo utakayotumia kuingia.';

  @override
  String get welcomeBack => 'Karibu tena';

  @override
  String get signInWithPhone => 'Ingia kwa nambari yako ya simu na nenosiri.';

  @override
  String get phoneOrEmail => 'Nambari ya simu au barua pepe';

  @override
  String get signingIn => 'Inaingia…';

  @override
  String get sessionNote =>
      'Kipindi chako hudumu saa 8; daftari la nje ya mtandao huendelea kufanya kazi bila kuingia tena.';

  @override
  String get sectionGroup => 'Kikundi';

  @override
  String get sectionReports => 'Ripoti';

  @override
  String get sectionEndOfCycle => 'Mwisho wa mzunguko';

  @override
  String get sectionCloudBackup => 'Wingu na hifadhi';

  @override
  String get sectionStore => 'Duka';

  @override
  String get sectionAppearance => 'Muonekano';

  @override
  String get sectionLanguage => 'Lugha';

  @override
  String get sectionAbout => 'Kuhusu';

  @override
  String get groupSettings => 'Mipangilio ya Kikundi';

  @override
  String get groupSettingsSubtitle => 'Akiba, mikopo na siku za mikutano';

  @override
  String get meetingSecurity => 'Usalama wa Mkutano';

  @override
  String get memberAccounts => 'Akaunti za Wanachama';

  @override
  String get memberAccountsSubtitle =>
      'Ruhusu wanachama wapate akaunti zao kuona akiba zao';

  @override
  String get groupRules => 'Sheria za Kikundi';

  @override
  String get groupReport => 'Ripoti ya Kikundi';

  @override
  String get groupReportSubtitle =>
      'Pesa, wanachama na mikutano — tuma maandishi au PDF';

  @override
  String get memberReports => 'Ripoti za Wanachama';

  @override
  String get memberReportsSubtitle =>
      'Taarifa ya kila mwanachama — tuma maandishi au PDF';

  @override
  String get shareOut => 'Mgao wa Mwisho';

  @override
  String get shareOutSubtitle => 'Gawa pesa za kikundi kwa wanachama';

  @override
  String get cloudAccount => 'Akaunti ya Wingu';

  @override
  String get syncBackup => 'Sawazisha na Hifadhi';

  @override
  String get intelliStores => 'Intelli-Stores';

  @override
  String get themeLabel => 'Mandhari';

  @override
  String get language => 'Lugha';

  @override
  String get languageSubtitle => 'Chagua lugha ya simu hii';

  @override
  String get languageNeedsReview =>
      'Tafsiri hii bado inakaguliwa na wazungumzaji wa lugha hii. Maneno ambayo hayajatafsiriwa yataonekana kwa Kiingereza.';

  @override
  String get shareTextButton => 'Tuma Maandishi';

  @override
  String get savePdf => 'Hifadhi PDF';

  @override
  String get creating => 'Inatengeneza…';

  @override
  String get startMeeting => 'Anza Mkutano';

  @override
  String get meetingInProgress => 'Kuna mkutano unaoendelea';

  @override
  String get next => 'Endelea';

  @override
  String get back => 'Rudi';

  @override
  String get cancel => 'Ghairi';

  @override
  String get signedOut => 'Umetoka.';

  @override
  String get signOutKeepsRecords =>
      'Akiba, mikopo na mikutano ya kikundi chenu vitabaki vimehifadhiwa kwenye simu hii, lakini hakuna atakayeweza kuvifungua hadi uingie tena. Nambari yako ya simu itakumbukwa.';

  @override
  String get whoIsSigningIn => 'Nani anaingia?';

  @override
  String get whoIsSigningInSubtitle =>
      'Chagua aina ya akaunti unayotumia, kisha weka nambari yako ya simu na nenosiri.';
}
