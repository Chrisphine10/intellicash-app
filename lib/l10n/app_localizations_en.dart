// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Your VSLA in your pocket';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navMeetings => 'Meetings';

  @override
  String get navMembers => 'Members';

  @override
  String get navLoans => 'Loans';

  @override
  String get navMore => 'More';

  @override
  String get welcomeTitle => 'Welcome to Intelli-Cash';

  @override
  String get welcomeCreateAccountPrompt =>
      'Create your account to get started.';

  @override
  String get welcomeAccountReady => 'Your account is ready.';

  @override
  String get createAccount => 'Create Account';

  @override
  String get createAccountSubtitle =>
      'New here? Set up an account for your group, yourself, or your work as an agent.';

  @override
  String get signIn => 'Sign In';

  @override
  String get signInSubtitle => 'I already have an Intelli-Cash account.';

  @override
  String get signOut => 'Sign out';

  @override
  String signedInAs(String name) {
    return 'Signed in as $name.';
  }

  @override
  String get setUpGroup => 'Set up my group on this phone';

  @override
  String get setUpGroupSubtitle =>
      'Keep your group\'s savings, loans and meetings — works without internet once set up.';

  @override
  String get whoIsThisAccountFor => 'Who is this account for?';

  @override
  String get pickOneLater =>
      'Pick one — you can always add more accounts later.';

  @override
  String get accountTypeGroup => 'Our Group';

  @override
  String get accountTypeGroupSubtitle =>
      'This phone will keep our group\'s savings, loans and meetings.';

  @override
  String get accountTypeMember => 'Just Me';

  @override
  String get accountTypeMemberSubtitle =>
      'I want to see my own savings, shares and loans.';

  @override
  String get accountTypeAgent => 'Field Agent';

  @override
  String get accountTypeAgentSubtitle =>
      'I support and monitor several groups.';

  @override
  String get change => 'Change';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get yourFullName => 'Your full name';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'At least 6 characters — keep it secret.';

  @override
  String get repeatPassword => 'Repeat password';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get countyOptional => 'County (optional)';

  @override
  String get createMyAccount => 'Create My Account';

  @override
  String get creatingAccount => 'Creating account…';

  @override
  String get registerNeedsInternet =>
      'Creating an account needs an internet connection. Your phone number is your sign-in.';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInWithPhone => 'Sign in with your phone number and password.';

  @override
  String get phoneOrEmail => 'Phone number or email';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get sessionNote =>
      'Your session lasts 8 hours; the offline record book keeps working without signing in again.';

  @override
  String get sectionGroup => 'Group';

  @override
  String get sectionReports => 'Reports';

  @override
  String get sectionEndOfCycle => 'End of cycle';

  @override
  String get sectionCloudBackup => 'Cloud & backup';

  @override
  String get sectionStore => 'Store';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get sectionAbout => 'About';

  @override
  String get groupSettings => 'Group Settings';

  @override
  String get groupSettingsSubtitle => 'Savings, loans and meeting days';

  @override
  String get meetingSecurity => 'Meeting Security';

  @override
  String get memberAccounts => 'Member Accounts';

  @override
  String get memberAccountsSubtitle =>
      'Let members get their own sign-in to see their savings';

  @override
  String get groupRules => 'Group Rules';

  @override
  String get groupReport => 'Group Report';

  @override
  String get groupReportSubtitle =>
      'Money, members and meetings — share text or PDF';

  @override
  String get memberReports => 'Member Reports';

  @override
  String get memberReportsSubtitle =>
      'A statement for each member — share text or PDF';

  @override
  String get shareOut => 'Share-Out';

  @override
  String get shareOutSubtitle => 'Share the group fund back to members';

  @override
  String get cloudAccount => 'Cloud Account';

  @override
  String get syncBackup => 'Sync & Backup';

  @override
  String get intelliStores => 'Intelli-Stores';

  @override
  String get themeLabel => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'Choose the language for this phone';

  @override
  String get languageNeedsReview =>
      'This translation is still being checked by native speakers. Anything not yet translated shows in English.';

  @override
  String get shareTextButton => 'Share Text';

  @override
  String get savePdf => 'Save PDF';

  @override
  String get creating => 'Creating…';

  @override
  String get startMeeting => 'Start Meeting';

  @override
  String get meetingInProgress => 'A meeting is in progress';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get signedOut => 'Signed out.';

  @override
  String get signOutKeepsRecords =>
      'Your group\'s savings, loans and meetings stay saved on this phone, but nobody can open them until you sign in again. Your phone number will be remembered.';

  @override
  String get whoIsSigningIn => 'Who is signing in?';

  @override
  String get whoIsSigningInSubtitle =>
      'Choose the kind of account you use, then enter your phone number and password.';
}
