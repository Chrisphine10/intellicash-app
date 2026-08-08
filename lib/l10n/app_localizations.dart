import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ebu.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ki.dart';
import 'app_localizations_luo.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
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
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

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
    Locale('ebu'),
    Locale('en'),
    Locale('ki'),
    Locale('luo'),
    Locale('sw'),
  ];

  /// Splash screen strapline
  ///
  /// In en, this message translates to:
  /// **'Your VSLA in your pocket'**
  String get appTagline;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get navMeetings;

  /// No description provided for @navMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get navMembers;

  /// No description provided for @navLoans.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get navLoans;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Intelli-Cash'**
  String get welcomeTitle;

  /// No description provided for @welcomeCreateAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Create your account to get started.'**
  String get welcomeCreateAccountPrompt;

  /// No description provided for @welcomeAccountReady.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready.'**
  String get welcomeAccountReady;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New here? Set up an account for your group, yourself, or your work as an agent.'**
  String get createAccountSubtitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'I already have an Intelli-Cash account.'**
  String get signInSubtitle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}.'**
  String signedInAs(String name);

  /// No description provided for @setUpGroup.
  ///
  /// In en, this message translates to:
  /// **'Set up my group on this phone'**
  String get setUpGroup;

  /// No description provided for @setUpGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your group\'s savings, loans and meetings — works without internet once set up.'**
  String get setUpGroupSubtitle;

  /// No description provided for @whoIsThisAccountFor.
  ///
  /// In en, this message translates to:
  /// **'Who is this account for?'**
  String get whoIsThisAccountFor;

  /// No description provided for @pickOneLater.
  ///
  /// In en, this message translates to:
  /// **'Pick one — you can always add more accounts later.'**
  String get pickOneLater;

  /// No description provided for @accountTypeGroup.
  ///
  /// In en, this message translates to:
  /// **'Our Group'**
  String get accountTypeGroup;

  /// No description provided for @accountTypeGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This phone will keep our group\'s savings, loans and meetings.'**
  String get accountTypeGroupSubtitle;

  /// No description provided for @accountTypeMember.
  ///
  /// In en, this message translates to:
  /// **'Just Me'**
  String get accountTypeMember;

  /// No description provided for @accountTypeMemberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'I want to see my own savings, shares and loans.'**
  String get accountTypeMemberSubtitle;

  /// No description provided for @accountTypeAgent.
  ///
  /// In en, this message translates to:
  /// **'Field Agent'**
  String get accountTypeAgent;

  /// No description provided for @accountTypeAgentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'I support and monitor several groups.'**
  String get accountTypeAgentSubtitle;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameLabel;

  /// No description provided for @yourFullName.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get yourFullName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters — keep it secret.'**
  String get passwordHint;

  /// No description provided for @repeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get repeatPassword;

  /// No description provided for @emailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailOptional;

  /// No description provided for @countyOptional.
  ///
  /// In en, this message translates to:
  /// **'County (optional)'**
  String get countyOptional;

  /// No description provided for @createMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Create My Account'**
  String get createMyAccount;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account…'**
  String get creatingAccount;

  /// No description provided for @registerNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'Creating an account needs an internet connection. Your phone number is your sign-in.'**
  String get registerNeedsInternet;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone number and password.'**
  String get signInWithPhone;

  /// No description provided for @phoneOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Phone number or email'**
  String get phoneOrEmail;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @sessionNote.
  ///
  /// In en, this message translates to:
  /// **'Your session lasts 8 hours; the offline record book keeps working without signing in again.'**
  String get sessionNote;

  /// No description provided for @sectionGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get sectionGroup;

  /// No description provided for @sectionReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get sectionReports;

  /// No description provided for @sectionEndOfCycle.
  ///
  /// In en, this message translates to:
  /// **'End of cycle'**
  String get sectionEndOfCycle;

  /// No description provided for @sectionCloudBackup.
  ///
  /// In en, this message translates to:
  /// **'Cloud & backup'**
  String get sectionCloudBackup;

  /// No description provided for @sectionStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get sectionStore;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @groupSettings.
  ///
  /// In en, this message translates to:
  /// **'Group Settings'**
  String get groupSettings;

  /// No description provided for @groupSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Savings, loans and meeting days'**
  String get groupSettingsSubtitle;

  /// No description provided for @meetingSecurity.
  ///
  /// In en, this message translates to:
  /// **'Meeting Security'**
  String get meetingSecurity;

  /// No description provided for @memberAccounts.
  ///
  /// In en, this message translates to:
  /// **'Member Accounts'**
  String get memberAccounts;

  /// No description provided for @memberAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let members get their own sign-in to see their savings'**
  String get memberAccountsSubtitle;

  /// No description provided for @groupRules.
  ///
  /// In en, this message translates to:
  /// **'Group Rules'**
  String get groupRules;

  /// No description provided for @groupReport.
  ///
  /// In en, this message translates to:
  /// **'Group Report'**
  String get groupReport;

  /// No description provided for @groupReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Money, members and meetings — share text or PDF'**
  String get groupReportSubtitle;

  /// No description provided for @memberReports.
  ///
  /// In en, this message translates to:
  /// **'Member Reports'**
  String get memberReports;

  /// No description provided for @memberReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A statement for each member — share text or PDF'**
  String get memberReportsSubtitle;

  /// No description provided for @shareOut.
  ///
  /// In en, this message translates to:
  /// **'Share-Out'**
  String get shareOut;

  /// No description provided for @shareOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share the group fund back to members'**
  String get shareOutSubtitle;

  /// No description provided for @cloudAccount.
  ///
  /// In en, this message translates to:
  /// **'Cloud Account'**
  String get cloudAccount;

  /// No description provided for @syncBackup.
  ///
  /// In en, this message translates to:
  /// **'Sync & Backup'**
  String get syncBackup;

  /// No description provided for @intelliStores.
  ///
  /// In en, this message translates to:
  /// **'Intelli-Stores'**
  String get intelliStores;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the language for this phone'**
  String get languageSubtitle;

  /// No description provided for @languageNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'This translation is still being checked by native speakers. Anything not yet translated shows in English.'**
  String get languageNeedsReview;

  /// No description provided for @shareTextButton.
  ///
  /// In en, this message translates to:
  /// **'Share Text'**
  String get shareTextButton;

  /// No description provided for @savePdf.
  ///
  /// In en, this message translates to:
  /// **'Save PDF'**
  String get savePdf;

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get creating;

  /// No description provided for @startMeeting.
  ///
  /// In en, this message translates to:
  /// **'Start Meeting'**
  String get startMeeting;

  /// No description provided for @meetingInProgress.
  ///
  /// In en, this message translates to:
  /// **'A meeting is in progress'**
  String get meetingInProgress;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @signedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get signedOut;

  /// No description provided for @signOutKeepsRecords.
  ///
  /// In en, this message translates to:
  /// **'Your group\'s savings, loans and meetings stay saved on this phone, but nobody can open them until you sign in again. Your phone number will be remembered.'**
  String get signOutKeepsRecords;

  /// No description provided for @whoIsSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Who is signing in?'**
  String get whoIsSigningIn;

  /// No description provided for @whoIsSigningInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the kind of account you use, then enter your phone number and password.'**
  String get whoIsSigningInSubtitle;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ebu', 'en', 'ki', 'luo', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ebu':
      return L10nEbu();
    case 'en':
      return L10nEn();
    case 'ki':
      return L10nKi();
    case 'luo':
      return L10nLuo();
    case 'sw':
      return L10nSw();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
