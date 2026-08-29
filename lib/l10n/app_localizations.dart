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
  /// **'Village Agent or CBT — I support and monitor several groups.'**
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
  /// **'Your session lasts 8 hours. The group\'s record book keeps working offline once you are signed in.'**
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
  /// **'Every screen is translated, but a speaker of this language has not checked the wording yet. If something reads wrongly, please tell us — you can switch back to English or Kiswahili at any time.'**
  String get languageNeedsReview;

  /// No description provided for @shareTextButton.
  ///
  /// In en, this message translates to:
  /// **'Share Text'**
  String get shareTextButton;

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

  /// No description provided for @signOutMemberNote.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to see your savings. Your phone number will be remembered.'**
  String get signOutMemberNote;

  /// No description provided for @signOutAgentNote.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to see your groups. Your phone number will be remembered.'**
  String get signOutAgentNote;

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

  /// No description provided for @welfareRecordThisPayment.
  ///
  /// In en, this message translates to:
  /// **'Record this payment?'**
  String get welfareRecordThisPayment;

  /// No description provided for @welfareRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get welfareRecordPayment;

  /// No description provided for @welfareWelfareFund.
  ///
  /// In en, this message translates to:
  /// **'Welfare Fund'**
  String get welfareWelfareFund;

  /// No description provided for @welfareCouldNotLoadTheWelfare.
  ///
  /// In en, this message translates to:
  /// **'Could not load the welfare fund.'**
  String get welfareCouldNotLoadTheWelfare;

  /// No description provided for @welfareTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get welfareTryAgain;

  /// No description provided for @welfareLeftInTheWelfareFund.
  ///
  /// In en, this message translates to:
  /// **'Left in the welfare fund'**
  String get welfareLeftInTheWelfareFund;

  /// No description provided for @welfareRecordAWelfarePayment.
  ///
  /// In en, this message translates to:
  /// **'Record a welfare payment'**
  String get welfareRecordAWelfarePayment;

  /// No description provided for @welfarePaidOutThisCycle.
  ///
  /// In en, this message translates to:
  /// **'Paid out this cycle'**
  String get welfarePaidOutThisCycle;

  /// No description provided for @welfareNothingPaidOutYetThe.
  ///
  /// In en, this message translates to:
  /// **'Nothing paid out yet — the whole welfare fund will be shared.'**
  String get welfareNothingPaidOutYetThe;

  /// No description provided for @welfareRecordedInMeeting.
  ///
  /// In en, this message translates to:
  /// **'Recorded in meeting'**
  String get welfareRecordedInMeeting;

  /// No description provided for @welfareAmountKsh.
  ///
  /// In en, this message translates to:
  /// **'Amount (KSh)'**
  String get welfareAmountKsh;

  /// No description provided for @welfareWhatFor.
  ///
  /// In en, this message translates to:
  /// **'What for'**
  String get welfareWhatFor;

  /// No description provided for @welfarePaidTo.
  ///
  /// In en, this message translates to:
  /// **'Paid to'**
  String get welfarePaidTo;

  /// No description provided for @welfareAMemberAFamilyOr.
  ///
  /// In en, this message translates to:
  /// **'A member, a family, or a hospital — whoever received it'**
  String get welfareAMemberAFamilyOr;

  /// No description provided for @welfareNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get welfareNoteOptional;

  /// No description provided for @meetingHubEditAttendance.
  ///
  /// In en, this message translates to:
  /// **'Edit attendance'**
  String get meetingHubEditAttendance;

  /// No description provided for @meetingHubCloseLockMeeting.
  ///
  /// In en, this message translates to:
  /// **'Close & Lock Meeting'**
  String get meetingHubCloseLockMeeting;

  /// No description provided for @meetingHubClosingLocksAllRecordsPermanently.
  ///
  /// In en, this message translates to:
  /// **'Closing locks all records permanently.'**
  String get meetingHubClosingLocksAllRecordsPermanently;

  /// No description provided for @meetingHubKeepOpen.
  ///
  /// In en, this message translates to:
  /// **'Keep Open'**
  String get meetingHubKeepOpen;

  /// No description provided for @meetingHubCloseLock.
  ///
  /// In en, this message translates to:
  /// **'Close & Lock'**
  String get meetingHubCloseLock;

  /// No description provided for @meetingHubSocialFund.
  ///
  /// In en, this message translates to:
  /// **'Social Fund'**
  String get meetingHubSocialFund;

  /// No description provided for @meetingHubBuyShares.
  ///
  /// In en, this message translates to:
  /// **'Buy Shares'**
  String get meetingHubBuyShares;

  /// No description provided for @meetingHubRecordFine.
  ///
  /// In en, this message translates to:
  /// **'Record Fine'**
  String get meetingHubRecordFine;

  /// No description provided for @meetingHubDisburseLoan.
  ///
  /// In en, this message translates to:
  /// **'Disburse Loan'**
  String get meetingHubDisburseLoan;

  /// No description provided for @meetingHubRepayment.
  ///
  /// In en, this message translates to:
  /// **'Repayment'**
  String get meetingHubRepayment;

  /// No description provided for @meetingHubShareRecords.
  ///
  /// In en, this message translates to:
  /// **'Share Records'**
  String get meetingHubShareRecords;

  /// No description provided for @meetingHubVoting.
  ///
  /// In en, this message translates to:
  /// **'Voting'**
  String get meetingHubVoting;

  /// No description provided for @meetingHubWelfare.
  ///
  /// In en, this message translates to:
  /// **'Welfare'**
  String get meetingHubWelfare;

  /// No description provided for @meetingHubIntelliStore.
  ///
  /// In en, this message translates to:
  /// **'Intelli-Store'**
  String get meetingHubIntelliStore;

  /// No description provided for @meetingHubExternalLoans.
  ///
  /// In en, this message translates to:
  /// **'External Loans'**
  String get meetingHubExternalLoans;

  /// No description provided for @groupSetupWizardAddTheMembersJoiningThis.
  ///
  /// In en, this message translates to:
  /// **'Add the members joining this cycle. You can always add more later.'**
  String get groupSetupWizardAddTheMembersJoiningThis;

  /// No description provided for @groupSetupWizardEveryoneBuysSharesAtOne.
  ///
  /// In en, this message translates to:
  /// **'Everyone buys shares at one fixed price'**
  String get groupSetupWizardEveryoneBuysSharesAtOne;

  /// No description provided for @groupSetupWizardMembersSaveWhatTheyCan.
  ///
  /// In en, this message translates to:
  /// **'Members save what they can each meeting'**
  String get groupSetupWizardMembersSaveWhatTheyCan;

  /// No description provided for @groupSetupWizardGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupSetupWizardGroupName;

  /// No description provided for @groupSetupWizardCycleNumber.
  ///
  /// In en, this message translates to:
  /// **'Cycle Number'**
  String get groupSetupWizardCycleNumber;

  /// No description provided for @groupSetupWizardWhichSavingsCycleIsThis.
  ///
  /// In en, this message translates to:
  /// **'Which savings cycle is this group on?'**
  String get groupSetupWizardWhichSavingsCycleIsThis;

  /// No description provided for @groupSetupWizardMemberName.
  ///
  /// In en, this message translates to:
  /// **'Member Name'**
  String get groupSetupWizardMemberName;

  /// No description provided for @groupSetupWizardAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get groupSetupWizardAddMember;

  /// No description provided for @groupSetupWizardRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get groupSetupWizardRemove;

  /// No description provided for @groupSetupWizardShareValueKsh.
  ///
  /// In en, this message translates to:
  /// **'Share Value (KSh)'**
  String get groupSetupWizardShareValueKsh;

  /// No description provided for @groupSetupWizardMaxSharesPerMeeting.
  ///
  /// In en, this message translates to:
  /// **'Max Shares per Meeting'**
  String get groupSetupWizardMaxSharesPerMeeting;

  /// No description provided for @groupSetupWizardSocialFundPerMeetingKsh.
  ///
  /// In en, this message translates to:
  /// **'Social Fund per Meeting (KSh)'**
  String get groupSetupWizardSocialFundPerMeetingKsh;

  /// No description provided for @groupSetupWizardTrackedSeparatelyFromSavings.
  ///
  /// In en, this message translates to:
  /// **'Tracked separately from savings'**
  String get groupSetupWizardTrackedSeparatelyFromSavings;

  /// No description provided for @groupSetupWizardInterestRatePerMonth.
  ///
  /// In en, this message translates to:
  /// **'Interest Rate (% per month)'**
  String get groupSetupWizardInterestRatePerMonth;

  /// No description provided for @groupSetupWizardMaxLoanMultiplierSavings.
  ///
  /// In en, this message translates to:
  /// **'Max Loan Multiplier (× savings)'**
  String get groupSetupWizardMaxLoanMultiplierSavings;

  /// No description provided for @groupSetupWizardDefaultLoanTermMonths.
  ///
  /// In en, this message translates to:
  /// **'Default Loan Term (months)'**
  String get groupSetupWizardDefaultLoanTermMonths;

  /// No description provided for @groupSyncBackUpToCloud.
  ///
  /// In en, this message translates to:
  /// **'Back Up to Cloud'**
  String get groupSyncBackUpToCloud;

  /// No description provided for @groupSyncUnlinkGroup.
  ///
  /// In en, this message translates to:
  /// **'Unlink group?'**
  String get groupSyncUnlinkGroup;

  /// No description provided for @groupSyncUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get groupSyncUnlink;

  /// No description provided for @groupSyncNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get groupSyncNotConnected;

  /// No description provided for @groupSyncOpenServerConnection.
  ///
  /// In en, this message translates to:
  /// **'Open Server Connection'**
  String get groupSyncOpenServerConnection;

  /// No description provided for @groupSyncLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get groupSyncLink;

  /// No description provided for @groupSyncUnlinkGroup2.
  ///
  /// In en, this message translates to:
  /// **'Unlink Group'**
  String get groupSyncUnlinkGroup2;

  /// No description provided for @groupSyncNoBackendGroups.
  ///
  /// In en, this message translates to:
  /// **'No backend groups'**
  String get groupSyncNoBackendGroups;

  /// No description provided for @groupSyncThisApiKeyCannotSee.
  ///
  /// In en, this message translates to:
  /// **'This API key cannot see any groups to link to.'**
  String get groupSyncThisApiKeyCannotSee;

  /// No description provided for @groupSyncBackendGroup.
  ///
  /// In en, this message translates to:
  /// **'Backend group'**
  String get groupSyncBackendGroup;

  /// No description provided for @createPollStartAVote.
  ///
  /// In en, this message translates to:
  /// **'Start a Vote'**
  String get createPollStartAVote;

  /// No description provided for @createPollEveryonePresentVotesOnceNobody.
  ///
  /// In en, this message translates to:
  /// **'Everyone present votes once. Nobody can vote twice.'**
  String get createPollEveryonePresentVotesOnceNobody;

  /// No description provided for @createPollChooseALeader.
  ///
  /// In en, this message translates to:
  /// **'Choose a leader'**
  String get createPollChooseALeader;

  /// No description provided for @createPollDecideSomething.
  ///
  /// In en, this message translates to:
  /// **'Decide something'**
  String get createPollDecideSomething;

  /// No description provided for @createPollTickAtLeastTwoPeople.
  ///
  /// In en, this message translates to:
  /// **'Tick at least two people.'**
  String get createPollTickAtLeastTwoPeople;

  /// No description provided for @createPollAddAnotherAnswer.
  ///
  /// In en, this message translates to:
  /// **'Add another answer'**
  String get createPollAddAnotherAnswer;

  /// No description provided for @createPollSecretVote.
  ///
  /// In en, this message translates to:
  /// **'Secret vote'**
  String get createPollSecretVote;

  /// No description provided for @createPollOpenTheVote.
  ///
  /// In en, this message translates to:
  /// **'Open the Vote'**
  String get createPollOpenTheVote;

  /// No description provided for @createPollWhichPosition.
  ///
  /// In en, this message translates to:
  /// **'Which position?'**
  String get createPollWhichPosition;

  /// No description provided for @createPollWhatIsTheQuestion.
  ///
  /// In en, this message translates to:
  /// **'What is the question?'**
  String get createPollWhatIsTheQuestion;

  /// No description provided for @createPollShouldWeBuyAGroup.
  ///
  /// In en, this message translates to:
  /// **'Should we buy a group water tank?'**
  String get createPollShouldWeBuyAGroup;

  /// No description provided for @paymentProvidersLeaveABoxEmptyTo.
  ///
  /// In en, this message translates to:
  /// **'Leave a box empty to keep what is already saved.'**
  String get paymentProvidersLeaveABoxEmptyTo;

  /// No description provided for @paymentProvidersSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get paymentProvidersSave;

  /// No description provided for @paymentProvidersUseThePlatformAccount.
  ///
  /// In en, this message translates to:
  /// **'Use the platform account?'**
  String get paymentProvidersUseThePlatformAccount;

  /// No description provided for @paymentProvidersPaymentProviders.
  ///
  /// In en, this message translates to:
  /// **'Payment Providers'**
  String get paymentProvidersPaymentProviders;

  /// No description provided for @paymentProvidersUsePlatform.
  ///
  /// In en, this message translates to:
  /// **'Use platform'**
  String get paymentProvidersUsePlatform;

  /// No description provided for @storeShopOnCredit.
  ///
  /// In en, this message translates to:
  /// **'Shop on credit'**
  String get storeShopOnCredit;

  /// No description provided for @storeLoanOffersFromLendingPartners.
  ///
  /// In en, this message translates to:
  /// **'Loan offers from lending partners — apply as a group.'**
  String get storeLoanOffersFromLendingPartners;

  /// No description provided for @storeSeeAllExternalLoans.
  ///
  /// In en, this message translates to:
  /// **'See all external loans'**
  String get storeSeeAllExternalLoans;

  /// No description provided for @storeConnectToBrowseTheStore.
  ///
  /// In en, this message translates to:
  /// **'Connect to browse the store'**
  String get storeConnectToBrowseTheStore;

  /// No description provided for @storeOpenCloudAccount.
  ///
  /// In en, this message translates to:
  /// **'Open Cloud Account'**
  String get storeOpenCloudAccount;

  /// No description provided for @storeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get storeAll;

  /// No description provided for @storeCouldNotLoadTheStore.
  ///
  /// In en, this message translates to:
  /// **'Could not load the store'**
  String get storeCouldNotLoadTheStore;

  /// No description provided for @storeNoProductsInThisCategory.
  ///
  /// In en, this message translates to:
  /// **'No products in this category'**
  String get storeNoProductsInThisCategory;

  /// No description provided for @storeTryADifferentCategoryOr.
  ///
  /// In en, this message translates to:
  /// **'Try a different category or check back later.'**
  String get storeTryADifferentCategoryOr;

  /// No description provided for @pollsNewVote.
  ///
  /// In en, this message translates to:
  /// **'New Vote'**
  String get pollsNewVote;

  /// No description provided for @pollsGroupVotes.
  ///
  /// In en, this message translates to:
  /// **'Group votes'**
  String get pollsGroupVotes;

  /// No description provided for @pollsSecret.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get pollsSecret;

  /// No description provided for @pollsYouHaveVoted.
  ///
  /// In en, this message translates to:
  /// **'You have voted'**
  String get pollsYouHaveVoted;

  /// No description provided for @pollsConnectToVote.
  ///
  /// In en, this message translates to:
  /// **'Connect to vote'**
  String get pollsConnectToVote;

  /// No description provided for @pollsCouldNotLoadTheVotes.
  ///
  /// In en, this message translates to:
  /// **'Could not load the votes'**
  String get pollsCouldNotLoadTheVotes;

  /// No description provided for @pollsNoVotesYet.
  ///
  /// In en, this message translates to:
  /// **'No votes yet'**
  String get pollsNoVotesYet;

  /// No description provided for @memberPassbookMyPassbook.
  ///
  /// In en, this message translates to:
  /// **'My Passbook'**
  String get memberPassbookMyPassbook;

  /// No description provided for @memberPassbookJoinAGroup.
  ///
  /// In en, this message translates to:
  /// **'Join a group'**
  String get memberPassbookJoinAGroup;

  /// No description provided for @memberPassbookMyReport.
  ///
  /// In en, this message translates to:
  /// **'My report'**
  String get memberPassbookMyReport;

  /// No description provided for @memberPassbookMySavingsAcrossAllGroups.
  ///
  /// In en, this message translates to:
  /// **'My savings across all groups'**
  String get memberPassbookMySavingsAcrossAllGroups;

  /// No description provided for @memberPassbookJoinAnotherGroup.
  ///
  /// In en, this message translates to:
  /// **'Join another group'**
  String get memberPassbookJoinAnotherGroup;

  /// No description provided for @memberPassbookYouAreNotInA.
  ///
  /// In en, this message translates to:
  /// **'You are not in a group yet'**
  String get memberPassbookYouAreNotInA;

  /// No description provided for @memberPassbookNoTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get memberPassbookNoTransactionsYet;

  /// No description provided for @memberPassbookYourSavingsAndLoanRecords.
  ///
  /// In en, this message translates to:
  /// **'Your savings and loan records will appear here.'**
  String get memberPassbookYourSavingsAndLoanRecords;

  /// No description provided for @joinRequestsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get joinRequestsDecline;

  /// No description provided for @joinRequestsJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'Join Requests'**
  String get joinRequestsJoinRequests;

  /// No description provided for @joinRequestsPeopleAskingToJoin.
  ///
  /// In en, this message translates to:
  /// **'People asking to join'**
  String get joinRequestsPeopleAskingToJoin;

  /// No description provided for @joinRequestsApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get joinRequestsApprove;

  /// No description provided for @joinRequestsReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get joinRequestsReasonOptional;

  /// No description provided for @joinRequestsNoOneIsWaiting.
  ///
  /// In en, this message translates to:
  /// **'No one is waiting'**
  String get joinRequestsNoOneIsWaiting;

  /// No description provided for @pollDetailCloseThisVote.
  ///
  /// In en, this message translates to:
  /// **'Close this vote?'**
  String get pollDetailCloseThisVote;

  /// No description provided for @pollDetailCloseVote.
  ///
  /// In en, this message translates to:
  /// **'Close Vote'**
  String get pollDetailCloseVote;

  /// No description provided for @pollDetailVote.
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get pollDetailVote;

  /// No description provided for @pollDetailYourChoice.
  ///
  /// In en, this message translates to:
  /// **'Your choice'**
  String get pollDetailYourChoice;

  /// No description provided for @pollDetailNoMembersLoadedForThis.
  ///
  /// In en, this message translates to:
  /// **'No members loaded for this group yet.'**
  String get pollDetailNoMembersLoadedForThis;

  /// No description provided for @pollDetailMemberCastingThisVote.
  ///
  /// In en, this message translates to:
  /// **'Member casting this vote'**
  String get pollDetailMemberCastingThisVote;

  /// No description provided for @groupPolicyHowLongALoanRuns.
  ///
  /// In en, this message translates to:
  /// **'How long a loan runs'**
  String get groupPolicyHowLongALoanRuns;

  /// No description provided for @groupPolicyInterestCharged.
  ///
  /// In en, this message translates to:
  /// **'Interest charged'**
  String get groupPolicyInterestCharged;

  /// No description provided for @groupPolicyExpensesArePaidFrom.
  ///
  /// In en, this message translates to:
  /// **'Expenses are paid from'**
  String get groupPolicyExpensesArePaidFrom;

  /// No description provided for @groupPolicyRulesThatAreFixed.
  ///
  /// In en, this message translates to:
  /// **'Rules that are fixed'**
  String get groupPolicyRulesThatAreFixed;

  /// No description provided for @productDetailRequestOnCredit.
  ///
  /// In en, this message translates to:
  /// **'Request on Credit'**
  String get productDetailRequestOnCredit;

  /// No description provided for @productDetailQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get productDetailQuantity;

  /// No description provided for @productDetailSubmitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get productDetailSubmitRequest;

  /// No description provided for @productDetailPricedAtTheStandardDeposit.
  ///
  /// In en, this message translates to:
  /// **'Priced at the standard deposit — rating unavailable.'**
  String get productDetailPricedAtTheStandardDeposit;

  /// No description provided for @productDetailProgramme.
  ///
  /// In en, this message translates to:
  /// **'Programme'**
  String get productDetailProgramme;

  /// No description provided for @productDetailCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get productDetailCustomerName;

  /// No description provided for @productDetailEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get productDetailEmail;

  /// No description provided for @productDetailGroupNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Group name (optional)'**
  String get productDetailGroupNameOptional;

  /// No description provided for @dashboardHello.
  ///
  /// In en, this message translates to:
  /// **'Hello 👋'**
  String get dashboardHello;

  /// No description provided for @dashboardTotalSavings.
  ///
  /// In en, this message translates to:
  /// **'Total Savings'**
  String get dashboardTotalSavings;

  /// No description provided for @dashboardActiveLoans.
  ///
  /// In en, this message translates to:
  /// **'Active Loans'**
  String get dashboardActiveLoans;

  /// No description provided for @dashboardFinesCollected.
  ///
  /// In en, this message translates to:
  /// **'Fines Collected'**
  String get dashboardFinesCollected;

  /// No description provided for @disburseLoanLoanEligibility.
  ///
  /// In en, this message translates to:
  /// **'Loan Eligibility'**
  String get disburseLoanLoanEligibility;

  /// No description provided for @disburseLoanSelectMember.
  ///
  /// In en, this message translates to:
  /// **'Select Member'**
  String get disburseLoanSelectMember;

  /// No description provided for @disburseLoanPrincipalAmountKsh.
  ///
  /// In en, this message translates to:
  /// **'Principal Amount (KSh)'**
  String get disburseLoanPrincipalAmountKsh;

  /// No description provided for @disburseLoanDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get disburseLoanDueDate;

  /// No description provided for @joinGroupRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get joinGroupRequestSent;

  /// No description provided for @joinGroupDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get joinGroupDone;

  /// No description provided for @joinGroupAskYourGroupToAdd.
  ///
  /// In en, this message translates to:
  /// **'Ask your group to add you'**
  String get joinGroupAskYourGroupToAdd;

  /// No description provided for @joinGroupSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get joinGroupSendRequest;

  /// No description provided for @joinGroupViewing.
  ///
  /// In en, this message translates to:
  /// **'Viewing'**
  String get joinGroupViewing;

  /// No description provided for @joinGroupGroupCode.
  ///
  /// In en, this message translates to:
  /// **'Group code'**
  String get joinGroupGroupCode;

  /// No description provided for @memberDetailEditDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get memberDetailEditDetails;

  /// No description provided for @memberDetailMemberReport.
  ///
  /// In en, this message translates to:
  /// **'Member report'**
  String get memberDetailMemberReport;

  /// No description provided for @memberDetailNoLoansTaken.
  ///
  /// In en, this message translates to:
  /// **'No loans taken'**
  String get memberDetailNoLoansTaken;

  /// No description provided for @memberDetailStartingPassword.
  ///
  /// In en, this message translates to:
  /// **'Starting password'**
  String get memberDetailStartingPassword;

  /// No description provided for @memberDetailAtLeast6Characters.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters.'**
  String get memberDetailAtLeast6Characters;

  /// No description provided for @cyclesCloseCycle.
  ///
  /// In en, this message translates to:
  /// **'Close cycle'**
  String get cyclesCloseCycle;

  /// No description provided for @cyclesSavingCycles.
  ///
  /// In en, this message translates to:
  /// **'Saving Cycles'**
  String get cyclesSavingCycles;

  /// No description provided for @cyclesCloseCycleAndStartThe.
  ///
  /// In en, this message translates to:
  /// **'Close cycle and start the next'**
  String get cyclesCloseCycleAndStartThe;

  /// No description provided for @cyclesReadOnlyStillVisibleIn.
  ///
  /// In en, this message translates to:
  /// **'Read-only — still visible in reports'**
  String get cyclesReadOnlyStillVisibleIn;

  /// No description provided for @externalLoansCreditVentures.
  ///
  /// In en, this message translates to:
  /// **'Credit ventures'**
  String get externalLoansCreditVentures;

  /// No description provided for @externalLoansConnectToSeeLoanOffers.
  ///
  /// In en, this message translates to:
  /// **'Connect to see loan offers'**
  String get externalLoansConnectToSeeLoanOffers;

  /// No description provided for @externalLoansCouldNotLoadLoanOffers.
  ///
  /// In en, this message translates to:
  /// **'Could not load loan offers'**
  String get externalLoansCouldNotLoadLoanOffers;

  /// No description provided for @externalLoansNoLoanOffersRightNow.
  ///
  /// In en, this message translates to:
  /// **'No loan offers right now'**
  String get externalLoansNoLoanOffersRightNow;

  /// No description provided for @accountAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountAccount;

  /// No description provided for @accountServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get accountServer;

  /// No description provided for @accountAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get accountAppVersion;

  /// No description provided for @accountPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get accountPhone;

  /// No description provided for @businessProfileGroupBusiness.
  ///
  /// In en, this message translates to:
  /// **'Group business'**
  String get businessProfileGroupBusiness;

  /// No description provided for @businessProfileWhatDoesTheGroupRun.
  ///
  /// In en, this message translates to:
  /// **'What does the group run together?'**
  String get businessProfileWhatDoesTheGroupRun;

  /// No description provided for @businessProfileTypeOfBusiness.
  ///
  /// In en, this message translates to:
  /// **'Type of business'**
  String get businessProfileTypeOfBusiness;

  /// No description provided for @businessProfileEGPoultryCerealBuying.
  ///
  /// In en, this message translates to:
  /// **'e.g. poultry, cereal buying'**
  String get businessProfileEGPoultryCerealBuying;

  /// No description provided for @businessProfileMoneyInEachMonthKes.
  ///
  /// In en, this message translates to:
  /// **'Money in each month (KES)'**
  String get businessProfileMoneyInEachMonthKes;

  /// No description provided for @businessProfileCostsEachMonthKes.
  ///
  /// In en, this message translates to:
  /// **'Costs each month (KES)'**
  String get businessProfileCostsEachMonthKes;

  /// No description provided for @businessProfilePeopleItEmploys.
  ///
  /// In en, this message translates to:
  /// **'People it employs'**
  String get businessProfilePeopleItEmploys;

  /// No description provided for @businessProfileBiggestProblemTheyFace.
  ///
  /// In en, this message translates to:
  /// **'Biggest problem they face'**
  String get businessProfileBiggestProblemTheyFace;

  /// No description provided for @recordVisitSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get recordVisitSettings;

  /// No description provided for @recordVisitScoreTheGroup.
  ///
  /// In en, this message translates to:
  /// **'Score the group'**
  String get recordVisitScoreTheGroup;

  /// No description provided for @recordVisitTheGroupSEnterprise.
  ///
  /// In en, this message translates to:
  /// **'The group’s enterprise'**
  String get recordVisitTheGroupSEnterprise;

  /// No description provided for @recordVisitWhatTheyRunTogetherAnd.
  ///
  /// In en, this message translates to:
  /// **'What they run together, and how it is doing.'**
  String get recordVisitWhatTheyRunTogetherAnd;

  /// No description provided for @recordVisitSavedOnThisPhoneFirst.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone first, then sent when you have signal.'**
  String get recordVisitSavedOnThisPhoneFirst;

  /// No description provided for @recordVisitWhyNotOptional.
  ///
  /// In en, this message translates to:
  /// **'Why not? (optional)'**
  String get recordVisitWhyNotOptional;

  /// No description provided for @recordVisitWhatYouFound.
  ///
  /// In en, this message translates to:
  /// **'What you found'**
  String get recordVisitWhatYouFound;

  /// No description provided for @agentHomeMyGroups.
  ///
  /// In en, this message translates to:
  /// **'My Groups'**
  String get agentHomeMyGroups;

  /// No description provided for @agentHomeCaseloadReport.
  ///
  /// In en, this message translates to:
  /// **'Caseload report'**
  String get agentHomeCaseloadReport;

  /// No description provided for @agentHomeNoGroupsAssigned.
  ///
  /// In en, this message translates to:
  /// **'No groups assigned'**
  String get agentHomeNoGroupsAssigned;

  /// No description provided for @agentHomeGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get agentHomeGroups;

  /// No description provided for @agentHomeNeedSupport.
  ///
  /// In en, this message translates to:
  /// **'Need support'**
  String get agentHomeNeedSupport;

  /// No description provided for @loansLoanPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Loan Portfolio'**
  String get loansLoanPortfolio;

  /// No description provided for @loansActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get loansActive;

  /// No description provided for @loansSearchByMemberName.
  ///
  /// In en, this message translates to:
  /// **'Search by member name'**
  String get loansSearchByMemberName;

  /// No description provided for @loansNoLoansHere.
  ///
  /// In en, this message translates to:
  /// **'No loans here'**
  String get loansNoLoansHere;

  /// No description provided for @threeKeyUnlockUnlockMeeting.
  ///
  /// In en, this message translates to:
  /// **'Unlock Meeting'**
  String get threeKeyUnlockUnlockMeeting;

  /// No description provided for @threeKeyUnlockVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get threeKeyUnlockVerified;

  /// No description provided for @threeKeyUnlockSendANewCode.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get threeKeyUnlockSendANewCode;

  /// No description provided for @threeKeyUnlockNoSmsUseMySaved.
  ///
  /// In en, this message translates to:
  /// **'No SMS? Use my saved PIN instead'**
  String get threeKeyUnlockNoSmsUseMySaved;

  /// No description provided for @threeKeyUnlockOneTimeCode.
  ///
  /// In en, this message translates to:
  /// **'One-time code'**
  String get threeKeyUnlockOneTimeCode;

  /// No description provided for @threeKeyUnlockRepeatPin.
  ///
  /// In en, this message translates to:
  /// **'Repeat PIN'**
  String get threeKeyUnlockRepeatPin;

  /// No description provided for @memberReportMyReport.
  ///
  /// In en, this message translates to:
  /// **'My Report'**
  String get memberReportMyReport;

  /// No description provided for @memberReportShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get memberReportShare;

  /// No description provided for @memberReportNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get memberReportNotSignedIn;

  /// No description provided for @memberReportSignInToYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account to see and share your report.'**
  String get memberReportSignInToYourAccount;

  /// No description provided for @cloudDashboardCloudData.
  ///
  /// In en, this message translates to:
  /// **'Cloud Data'**
  String get cloudDashboardCloudData;

  /// No description provided for @cloudDashboardRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get cloudDashboardRefresh;

  /// No description provided for @cloudDashboardSavingsFund.
  ///
  /// In en, this message translates to:
  /// **'Savings Fund'**
  String get cloudDashboardSavingsFund;

  /// No description provided for @cloudDashboardInternalLoans.
  ///
  /// In en, this message translates to:
  /// **'Internal Loans'**
  String get cloudDashboardInternalLoans;

  /// No description provided for @serverSettingsOrUseAGroupAccess.
  ///
  /// In en, this message translates to:
  /// **'or use a group access key'**
  String get serverSettingsOrUseAGroupAccess;

  /// No description provided for @serverSettingsViewOnlineRecords.
  ///
  /// In en, this message translates to:
  /// **'View Online Records'**
  String get serverSettingsViewOnlineRecords;

  /// No description provided for @serverSettingsBackUpThisGroup.
  ///
  /// In en, this message translates to:
  /// **'Back Up This Group'**
  String get serverSettingsBackUpThisGroup;

  /// No description provided for @serverSettingsAccessKey.
  ///
  /// In en, this message translates to:
  /// **'Access key'**
  String get serverSettingsAccessKey;

  /// No description provided for @shareOutDistribute.
  ///
  /// In en, this message translates to:
  /// **'Distribute'**
  String get shareOutDistribute;

  /// No description provided for @shareOutFundToDistribute.
  ///
  /// In en, this message translates to:
  /// **'Fund to distribute'**
  String get shareOutFundToDistribute;

  /// No description provided for @shareOutSplitWelfareFundEqually.
  ///
  /// In en, this message translates to:
  /// **'Split welfare fund equally'**
  String get shareOutSplitWelfareFundEqually;

  /// No description provided for @shareOutNothingToShareOutYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing to share out yet'**
  String get shareOutNothingToShareOutYet;

  /// No description provided for @visitAssessmentAssessment.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get visitAssessmentAssessment;

  /// No description provided for @visitAssessmentFormNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Form not available'**
  String get visitAssessmentFormNotAvailable;

  /// No description provided for @visitMentorshipMentorship.
  ///
  /// In en, this message translates to:
  /// **'Mentorship'**
  String get visitMentorshipMentorship;

  /// No description provided for @visitMentorshipWhatDidYouCoachOn.
  ///
  /// In en, this message translates to:
  /// **'What did you coach on?'**
  String get visitMentorshipWhatDidYouCoachOn;

  /// No description provided for @visitMentorshipTapATopicToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap a topic to record it, then add what you advised.'**
  String get visitMentorshipTapATopicToRecord;

  /// No description provided for @visitMentorshipNowHandThePhoneTo.
  ///
  /// In en, this message translates to:
  /// **'Now hand the phone to the group'**
  String get visitMentorshipNowHandThePhoneTo;

  /// No description provided for @visitMentorshipWhatYouAdvised.
  ///
  /// In en, this message translates to:
  /// **'What you advised'**
  String get visitMentorshipWhatYouAdvised;

  /// No description provided for @agentGroupDetailRecordAVisit.
  ///
  /// In en, this message translates to:
  /// **'Record a visit'**
  String get agentGroupDetailRecordAVisit;

  /// No description provided for @agentGroupDetailNoMembersLoaded.
  ///
  /// In en, this message translates to:
  /// **'No members loaded.'**
  String get agentGroupDetailNoMembersLoaded;

  /// No description provided for @agentGroupDetailNoMeetingsLoaded.
  ///
  /// In en, this message translates to:
  /// **'No meetings loaded.'**
  String get agentGroupDetailNoMeetingsLoaded;

  /// No description provided for @agentGroupDetailToImprove.
  ///
  /// In en, this message translates to:
  /// **'To improve'**
  String get agentGroupDetailToImprove;

  /// No description provided for @agentGroupDetailGovernance.
  ///
  /// In en, this message translates to:
  /// **'Governance'**
  String get agentGroupDetailGovernance;

  /// No description provided for @agentGroupDetailVslaCompliance.
  ///
  /// In en, this message translates to:
  /// **'VSLA compliance'**
  String get agentGroupDetailVslaCompliance;

  /// No description provided for @recordFineReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get recordFineReason;

  /// No description provided for @recordFineSpecifyReason.
  ///
  /// In en, this message translates to:
  /// **'Specify reason'**
  String get recordFineSpecifyReason;

  /// No description provided for @addMemberAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add Member'**
  String get addMemberAddMember;

  /// No description provided for @addMemberRegisterMember.
  ///
  /// In en, this message translates to:
  /// **'Register Member'**
  String get addMemberRegisterMember;

  /// No description provided for @addMemberFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get addMemberFullName;

  /// No description provided for @addMemberPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get addMemberPhoneOptional;

  /// No description provided for @addMemberRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get addMemberRole;

  /// No description provided for @editMemberEditMember.
  ///
  /// In en, this message translates to:
  /// **'Edit member'**
  String get editMemberEditMember;

  /// No description provided for @editMemberFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get editMemberFullName;

  /// No description provided for @membersRequestsToJoin.
  ///
  /// In en, this message translates to:
  /// **'Requests to join'**
  String get membersRequestsToJoin;

  /// No description provided for @membersSearchMembers.
  ///
  /// In en, this message translates to:
  /// **'Search members'**
  String get membersSearchMembers;

  /// No description provided for @membersNoMembersFound.
  ///
  /// In en, this message translates to:
  /// **'No members found'**
  String get membersNoMembersFound;

  /// No description provided for @meetingSecurity3KeyUnlockBeforeMeetings.
  ///
  /// In en, this message translates to:
  /// **'3-key unlock before meetings'**
  String get meetingSecurity3KeyUnlockBeforeMeetings;

  /// No description provided for @meetingSecurityKeepPin.
  ///
  /// In en, this message translates to:
  /// **'Keep PIN'**
  String get meetingSecurityKeepPin;

  /// No description provided for @meetingSecurityReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get meetingSecurityReset;

  /// No description provided for @agentReportCaseloadReport.
  ///
  /// In en, this message translates to:
  /// **'Caseload Report'**
  String get agentReportCaseloadReport;

  /// No description provided for @agentReportShareReport.
  ///
  /// In en, this message translates to:
  /// **'Share Report'**
  String get agentReportShareReport;

  /// No description provided for @agentReportNeedsSupport.
  ///
  /// In en, this message translates to:
  /// **'Needs support'**
  String get agentReportNeedsSupport;

  /// No description provided for @agentReportNoRating.
  ///
  /// In en, this message translates to:
  /// **'No rating'**
  String get agentReportNoRating;

  /// No description provided for @agentReportNoGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get agentReportNoGroupsYet;

  /// No description provided for @groupReportNoGroupYet.
  ///
  /// In en, this message translates to:
  /// **'No group yet'**
  String get groupReportNoGroupYet;

  /// No description provided for @groupReportSetUpYourGroupFirst.
  ///
  /// In en, this message translates to:
  /// **'Set up your group first, then come back for a report.'**
  String get groupReportSetUpYourGroupFirst;

  /// No description provided for @groupReportNoMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No members yet'**
  String get groupReportNoMembersYet;

  /// No description provided for @groupReportMembersAppearHereOnceThey.
  ///
  /// In en, this message translates to:
  /// **'Members appear here once they join the group.'**
  String get groupReportMembersAppearHereOnceThey;

  /// No description provided for @memberReportLocalMemberReport.
  ///
  /// In en, this message translates to:
  /// **'Member Report'**
  String get memberReportLocalMemberReport;

  /// No description provided for @memberReportLocalMemberNotFound.
  ///
  /// In en, this message translates to:
  /// **'Member not found'**
  String get memberReportLocalMemberNotFound;

  /// No description provided for @memberReportLocalThisMemberIsNoLonger.
  ///
  /// In en, this message translates to:
  /// **'This member is no longer in the group.'**
  String get memberReportLocalThisMemberIsNoLonger;

  /// No description provided for @memberReportLocalLoansThisMemberTakesWill.
  ///
  /// In en, this message translates to:
  /// **'Loans this member takes will appear here.'**
  String get memberReportLocalLoansThisMemberTakesWill;

  /// No description provided for @externalLoanApplyApplyForALoan.
  ///
  /// In en, this message translates to:
  /// **'Apply for a Loan'**
  String get externalLoanApplyApplyForALoan;

  /// No description provided for @externalLoanApplySubmitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get externalLoanApplySubmitApplication;

  /// No description provided for @externalLoanApplyWhatIsTheLoanFor.
  ///
  /// In en, this message translates to:
  /// **'What is the loan for?'**
  String get externalLoanApplyWhatIsTheLoanFor;

  /// No description provided for @externalLoanApplyEGBuyingMaizeSeed.
  ///
  /// In en, this message translates to:
  /// **'e.g. Buying maize seed for the season'**
  String get externalLoanApplyEGBuyingMaizeSeed;

  /// No description provided for @meetingsNoMeetingsYet.
  ///
  /// In en, this message translates to:
  /// **'No meetings yet'**
  String get meetingsNoMeetingsYet;

  /// No description provided for @repaymentRecordRepayment.
  ///
  /// In en, this message translates to:
  /// **'Record Repayment'**
  String get repaymentRecordRepayment;

  /// No description provided for @repaymentNoOutstandingLoansNothingTo.
  ///
  /// In en, this message translates to:
  /// **'No outstanding loans — nothing to repay. 🎉'**
  String get repaymentNoOutstandingLoansNothingTo;

  /// No description provided for @repaymentSelectLoan.
  ///
  /// In en, this message translates to:
  /// **'Select Loan'**
  String get repaymentSelectLoan;

  /// No description provided for @moreWhoIsSignedInLanguage.
  ///
  /// In en, this message translates to:
  /// **'Who is signed in, language, appearance and app details'**
  String get moreWhoIsSignedInLanguage;

  /// No description provided for @moreIntelliCash.
  ///
  /// In en, this message translates to:
  /// **'Intelli-Cash'**
  String get moreIntelliCash;

  /// No description provided for @mySavingsMySavings.
  ///
  /// In en, this message translates to:
  /// **'My Savings'**
  String get mySavingsMySavings;

  /// No description provided for @mySavingsOnceAGroupAcceptsYou.
  ///
  /// In en, this message translates to:
  /// **'Once a group accepts you, your savings will show here.'**
  String get mySavingsOnceAGroupAcceptsYou;

  /// No description provided for @buySharesEnterCodeByHand.
  ///
  /// In en, this message translates to:
  /// **'Enter Code by Hand'**
  String get buySharesEnterCodeByHand;

  /// No description provided for @buySharesRecordPurchase.
  ///
  /// In en, this message translates to:
  /// **'Record Purchase'**
  String get buySharesRecordPurchase;

  /// No description provided for @sharesLedgerNoPurchasesYet.
  ///
  /// In en, this message translates to:
  /// **'No purchases yet'**
  String get sharesLedgerNoPurchasesYet;

  /// No description provided for @socialFundThisMeetingIsClosedThe.
  ///
  /// In en, this message translates to:
  /// **'This meeting is closed — the record is read-only.'**
  String get socialFundThisMeetingIsClosedThe;

  /// No description provided for @socialFundNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No members'**
  String get socialFundNoMembers;

  /// No description provided for @socialFundAddMembersToTheGroup.
  ///
  /// In en, this message translates to:
  /// **'Add members to the group first.'**
  String get socialFundAddMembersToTheGroup;

  /// No description provided for @welcomeUseTheWebConsoleFor.
  ///
  /// In en, this message translates to:
  /// **'Use the web console for this account'**
  String get welcomeUseTheWebConsoleFor;

  /// No description provided for @welcomeLoadYourGroupOntoThis.
  ///
  /// In en, this message translates to:
  /// **'Load your group onto this phone'**
  String get welcomeLoadYourGroupOntoThis;

  /// No description provided for @memberReportsTapAMemberToSee.
  ///
  /// In en, this message translates to:
  /// **'Tap a member to see and share their report.'**
  String get memberReportsTapAMemberToSee;

  /// No description provided for @openActionItemsNothingOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Nothing outstanding'**
  String get openActionItemsNothingOutstanding;

  /// No description provided for @openActionItemsThisGroupHasNoOpen.
  ///
  /// In en, this message translates to:
  /// **'This group has no open actions from previous visits.'**
  String get openActionItemsThisGroupHasNoOpen;

  /// No description provided for @openActionItemsFromTheLastVisit.
  ///
  /// In en, this message translates to:
  /// **'From the last visit'**
  String get openActionItemsFromTheLastVisit;

  /// No description provided for @loanDetailNoRepaymentsYet.
  ///
  /// In en, this message translates to:
  /// **'No repayments yet'**
  String get loanDetailNoRepaymentsYet;

  /// No description provided for @attendanceAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendanceAttendance;

  /// No description provided for @attendanceContinueToMeeting.
  ///
  /// In en, this message translates to:
  /// **'Continue to Meeting'**
  String get attendanceContinueToMeeting;

  /// No description provided for @appearanceChooseHowIntelliCashLooks.
  ///
  /// In en, this message translates to:
  /// **'Choose how Intelli-Cash looks on this phone.'**
  String get appearanceChooseHowIntelliCashLooks;

  /// No description provided for @gatewayPaymentOpenThisLinkToPay.
  ///
  /// In en, this message translates to:
  /// **'Open this link to pay:'**
  String get gatewayPaymentOpenThisLinkToPay;

  /// No description provided for @numericKeypadDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get numericKeypadDelete;

  /// No description provided for @agentHomeWhenGroupsAreAssignedToYou.
  ///
  /// In en, this message translates to:
  /// **'When groups are assigned to you, they appear here with their credit rating.'**
  String get agentHomeWhenGroupsAreAssignedToYou;

  /// No description provided for @dashboardTheSavingsCurveAppearsAfterYour.
  ///
  /// In en, this message translates to:
  /// **'The savings curve appears after your first two meetings.'**
  String get dashboardTheSavingsCurveAppearsAfterYour;

  /// No description provided for @disburseLoanThisMemberHasNoBorrowingHeadroom.
  ///
  /// In en, this message translates to:
  /// **'This member has no borrowing headroom — savings must grow or the current loan must reduce first.'**
  String get disburseLoanThisMemberHasNoBorrowingHeadroom;

  /// No description provided for @disburseLoanTheLoanFundIsEmptyCollect.
  ///
  /// In en, this message translates to:
  /// **'The loan fund is empty. Collect share purchases or loan repayments before lending again.'**
  String get disburseLoanTheLoanFundIsEmptyCollect;

  /// No description provided for @loanDetailRepaymentsAreRecordedInsideMeetingsAnd.
  ///
  /// In en, this message translates to:
  /// **'Repayments are recorded inside meetings and appear here instantly.'**
  String get loanDetailRepaymentsAreRecordedInsideMeetingsAnd;

  /// No description provided for @loansLoansAreDisbursedInsideAMeeting.
  ///
  /// In en, this message translates to:
  /// **'Loans are disbursed inside a meeting — open a meeting and use Disburse Loan.'**
  String get loansLoansAreDisbursedInsideAMeeting;

  /// No description provided for @gatewayPaymentRequestSentAskTheMemberTo.
  ///
  /// In en, this message translates to:
  /// **'Request sent. Ask the member to enter their M-Pesa PIN on their phone.'**
  String get gatewayPaymentRequestSentAskTheMemberTo;

  /// No description provided for @meetingHubThisMeetingIsClosedItsRecords.
  ///
  /// In en, this message translates to:
  /// **'This meeting is closed. Its records are read-only and form part of the audit trail.'**
  String get meetingHubThisMeetingIsClosedItsRecords;

  /// No description provided for @meetingHubAllRecordsInThisMeetingWill.
  ///
  /// In en, this message translates to:
  /// **'All records in this meeting will be locked permanently. This cannot be undone.'**
  String get meetingHubAllRecordsInThisMeetingWill;

  /// No description provided for @meetings3KeyUnlockIsOnOfficials.
  ///
  /// In en, this message translates to:
  /// **'3-key unlock is on: officials confirm their PINs before the meeting opens.'**
  String get meetings3KeyUnlockIsOnOfficials;

  /// No description provided for @meetingsStartYourFirstMeetingToRecord.
  ///
  /// In en, this message translates to:
  /// **'Start your first meeting to record attendance, savings, fines and loans.'**
  String get meetingsStartYourFirstMeetingToRecord;

  /// No description provided for @meetingsClosedMeetingsAreLockedTheirRecords.
  ///
  /// In en, this message translates to:
  /// **'Closed meetings are locked — their records form the group\'s permanent audit trail.'**
  String get meetingsClosedMeetingsAreLockedTheirRecords;

  /// No description provided for @sharesLedgerSharePurchasesLandHereTheMoment.
  ///
  /// In en, this message translates to:
  /// **'Share purchases land here the moment they are recorded.'**
  String get sharesLedgerSharePurchasesLandHereTheMoment;

  /// No description provided for @joinGroupYourGroupHasACodeOn.
  ///
  /// In en, this message translates to:
  /// **'Your group has a code on its records — ask the secretary if you do not know it. Sending a request does not open the group\'s books to you; an official has to accept you first.'**
  String get joinGroupYourGroupHasACodeOn;

  /// No description provided for @memberPassbookAskYourGroupToAddYou.
  ///
  /// In en, this message translates to:
  /// **'Ask your group to add you and your savings will show up here.'**
  String get memberPassbookAskYourGroupToAddYou;

  /// No description provided for @editMemberCorrectingASpellingOrAMistyped.
  ///
  /// In en, this message translates to:
  /// **'Correcting a spelling or a mistyped number. Their savings, loans and attendance stay exactly as they are.'**
  String get editMemberCorrectingASpellingOrAMistyped;

  /// No description provided for @joinRequestsTheyWillNotBeAddedTo.
  ///
  /// In en, this message translates to:
  /// **'They will not be added to the group. You can say why if you want to — it is not required.'**
  String get joinRequestsTheyWillNotBeAddedTo;

  /// No description provided for @joinRequestsThisListIsOutOfDate.
  ///
  /// In en, this message translates to:
  /// **'This list is out of date. Pull down to refresh, then check the answer again.'**
  String get joinRequestsThisListIsOutOfDate;

  /// No description provided for @joinRequestsWhenSomeoneAsksToJoinYour.
  ///
  /// In en, this message translates to:
  /// **'When someone asks to join your group, their request will show up here for you to answer.'**
  String get joinRequestsWhenSomeoneAsksToJoinYour;

  /// No description provided for @memberDetailToCreateASignInAccount.
  ///
  /// In en, this message translates to:
  /// **'To create a sign-in account, first back this group up to the cloud (More → Sync & Backup) while online.'**
  String get memberDetailToCreateASignInAccount;

  /// No description provided for @memberDetailLoansThisMemberTakesWillBe.
  ///
  /// In en, this message translates to:
  /// **'Loans this member takes will be listed here with their live status.'**
  String get memberDetailLoansThisMemberTakesWillBe;

  /// No description provided for @membersAddMembersWithTheButtonBelow.
  ///
  /// In en, this message translates to:
  /// **'Add members with the button below — each gets an individual savings and loan profile.'**
  String get membersAddMembersWithTheButtonBelow;

  /// No description provided for @meetingSecurityAssignAChairpersonSecretaryAndTreasurer.
  ///
  /// In en, this message translates to:
  /// **'Assign a chairperson, secretary and treasurer below so three officials can unlock meetings. Until then, most members\' PINs are needed instead.'**
  String get meetingSecurityAssignAChairpersonSecretaryAndTreasurer;

  /// No description provided for @meetingSecurityTheOldPinStopsWorkingThe.
  ///
  /// In en, this message translates to:
  /// **'The old PIN stops working. The member chooses a new PIN the next time they turn their key at a meeting unlock.'**
  String get meetingSecurityTheOldPinStopsWorkingThe;

  /// No description provided for @moreYourGroupSSavingsAndLoans.
  ///
  /// In en, this message translates to:
  /// **'Your group\'s savings and loans, right on your phone. Everything is saved on this phone first and backed up online when you have internet.\\n\\nIntelli-Wealth Limited · intelliwealth.org'**
  String get moreYourGroupSSavingsAndLoans;

  /// No description provided for @moreNoInternetYourRecordsAreSafe.
  ///
  /// In en, this message translates to:
  /// **'No internet — your records are safe on this phone and will back up later.'**
  String get moreNoInternetYourRecordsAreSafe;

  /// No description provided for @welcomeThePhoneAppIsForGroups.
  ///
  /// In en, this message translates to:
  /// **'The phone app is for groups, members and field agents. Your account does not need to create a group here — sign in on the web console instead, or sign out to use a different account.'**
  String get welcomeThePhoneAppIsForGroups;

  /// No description provided for @welcomeYourGroupIsAlreadyOnThe.
  ///
  /// In en, this message translates to:
  /// **'Your group is already on the server. Load it here instead of creating a new one, so your savings history stays in one record.'**
  String get welcomeYourGroupIsAlreadyOnThe;

  /// No description provided for @agentReportWhenGroupsAreAssignedToYou.
  ///
  /// In en, this message translates to:
  /// **'When groups are assigned to you, their report appears here.'**
  String get agentReportWhenGroupsAreAssignedToYou;

  /// No description provided for @groupReportFiguresFromThisPhoneOnlyWork.
  ///
  /// In en, this message translates to:
  /// **'Figures from this phone only - work saved on other phones may not be included yet.'**
  String get groupReportFiguresFromThisPhoneOnlyWork;

  /// No description provided for @groupReportFromThisPhoneOnlyWorkSaved.
  ///
  /// In en, this message translates to:
  /// **'From this phone only. Work saved on other phones may not be included yet.'**
  String get groupReportFromThisPhoneOnlyWorkSaved;

  /// No description provided for @memberReportLocalFiguresFromThisPhoneOnlyRecords.
  ///
  /// In en, this message translates to:
  /// **'Figures from this phone only - records saved elsewhere may not be included yet.'**
  String get memberReportLocalFiguresFromThisPhoneOnlyRecords;

  /// No description provided for @mySavingsWhatYouOweIsCountedFor.
  ///
  /// In en, this message translates to:
  /// **'What you owe is counted for each group on its own. Paying extra in one group does not reduce what you owe in another.'**
  String get mySavingsWhatYouOweIsCountedFor;

  /// No description provided for @groupSyncThisClearsTheLocalBackendMapping.
  ///
  /// In en, this message translates to:
  /// **'This clears the local↔backend mapping. Already-synced records stay on the server; nothing is deleted.'**
  String get groupSyncThisClearsTheLocalBackendMapping;

  /// No description provided for @groupSyncConnectToTheIntellicashBackendBefore.
  ///
  /// In en, this message translates to:
  /// **'Connect to the IntelliCash backend before linking and syncing this group.'**
  String get groupSyncConnectToTheIntellicashBackendBefore;

  /// No description provided for @groupSyncLinkingMatchesYourLocalMembersTo.
  ///
  /// In en, this message translates to:
  /// **'Linking matches your local members to the backend roster by phone, then name. Unmatched members can be linked by hand afterwards.'**
  String get groupSyncLinkingMatchesYourLocalMembersTo;

  /// No description provided for @groupSyncTheseLocalMembersHaveNoBackend.
  ///
  /// In en, this message translates to:
  /// **'These local members have no backend match. Link them before their transactions can sync.'**
  String get groupSyncTheseLocalMembersHaveNoBackend;

  /// No description provided for @groupSyncUploadsAttendanceAndLedgerSharesSocial.
  ///
  /// In en, this message translates to:
  /// **'Uploads attendance and ledger (shares, social fund, loans, repayments) for every closed meeting. Safe to re-run — already synced records are skipped. Fines and meeting sealing come in a later phase.'**
  String get groupSyncUploadsAttendanceAndLedgerSharesSocial;

  /// No description provided for @serverSettingsAskYourGroupAdministratorForAn.
  ///
  /// In en, this message translates to:
  /// **'Ask your group administrator for an access key, then paste it here. It only lets this phone see and record your group\'s savings, loans and meetings.'**
  String get serverSettingsAskYourGroupAdministratorForAn;

  /// No description provided for @cyclesPullDownToTryAgainIf.
  ///
  /// In en, this message translates to:
  /// **'Pull down to try again. If it keeps happening, check the group is still selected under Cloud Account.'**
  String get cyclesPullDownToTryAgainIf;

  /// No description provided for @cyclesClosingACycleMakesItsRecords.
  ///
  /// In en, this message translates to:
  /// **'Closing a cycle makes its records read-only. Nothing is deleted — past meetings and money stay in history and reports.'**
  String get cyclesClosingACycleMakesItsRecords;

  /// No description provided for @cyclesYouCanSeeTheCyclesBut.
  ///
  /// In en, this message translates to:
  /// **'You can see the cycles but not close one. Only the group account or a platform admin can.'**
  String get cyclesYouCanSeeTheCyclesBut;

  /// No description provided for @groupPolicyAppliesToNewLoansLoansAlready.
  ///
  /// In en, this message translates to:
  /// **'Applies to new loans. Loans already given keep the term they were agreed with — changing this never changes what a member already owes.'**
  String get groupPolicyAppliesToNewLoansLoansAlready;

  /// No description provided for @groupPolicyFlatOnTheAmountBorrowedEach.
  ///
  /// In en, this message translates to:
  /// **'Flat on the amount borrowed each month — it does not fall as the member repays, and it stops at the end of the agreed term. Zero is fine: many groups lend interest-free. Each loan keeps the rate it was made at, so changing this never reprices money already lent.'**
  String get groupPolicyFlatOnTheAmountBorrowedEach;

  /// No description provided for @groupPolicyYouCanSeeTheseRulesBut.
  ///
  /// In en, this message translates to:
  /// **'You can see these rules but not change them. Only the group account or a platform admin can.'**
  String get groupPolicyYouCanSeeTheseRulesBut;

  /// No description provided for @groupPolicyUnpaidFinesAndWelfareAreTaken.
  ///
  /// In en, this message translates to:
  /// **'Unpaid fines and welfare are taken off a member\'s share-out payout — they never stop a member from sharing out.\\n\\nOutstanding loans are taken off at share-out and are never carried into the next cycle.'**
  String get groupPolicyUnpaidFinesAndWelfareAreTaken;

  /// No description provided for @paymentProvidersMPesaClassicNeedsNothingHere.
  ///
  /// In en, this message translates to:
  /// **'M-Pesa Classic needs nothing here — the member types in the transaction code from their phone.'**
  String get paymentProvidersMPesaClassicNeedsNothingHere;

  /// No description provided for @paymentProvidersYouCanSeeThisButNot.
  ///
  /// In en, this message translates to:
  /// **'You can see this but not change it. Only the group account or a platform admin can move where money is received.'**
  String get paymentProvidersYouCanSeeThisButNot;

  /// No description provided for @welfareYouAreOfflineWelfarePaymentsAre.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Welfare payments are recorded on the server so the fund cannot be overspent by two phones at once — reconnect to record one.'**
  String get welfareYouAreOfflineWelfarePaymentsAre;

  /// No description provided for @welfareNoMeetingIsOpenWelfareIs.
  ///
  /// In en, this message translates to:
  /// **'No meeting is open. Welfare is paid out during a meeting, in front of the members — open one first, then record it there.'**
  String get welfareNoMeetingIsOpenWelfareIs;

  /// No description provided for @shareOutMembersHavenTBoughtSharesThis.
  ///
  /// In en, this message translates to:
  /// **'Members haven\'t bought shares this cycle. Run meetings and collect shares first, then come back to distribute the fund.'**
  String get shareOutMembersHavenTBoughtSharesThis;

  /// No description provided for @externalLoanApplyCreditRatingUnavailableTheLenderChecks.
  ///
  /// In en, this message translates to:
  /// **'Credit rating unavailable — the lender checks it when reviewing your application.'**
  String get externalLoanApplyCreditRatingUnavailableTheLenderChecks;

  /// No description provided for @externalLoansCheckBackLaterPartnersAddNew.
  ///
  /// In en, this message translates to:
  /// **'Check back later — partners add new loan offers from time to time.'**
  String get externalLoansCheckBackLaterPartnersAddNew;

  /// No description provided for @externalLoansExternalLoansLoadFromTheIntelli.
  ///
  /// In en, this message translates to:
  /// **'External loans load from the Intelli-Cash backend. Connect or sign in first.'**
  String get externalLoansExternalLoansLoadFromTheIntelli;

  /// No description provided for @storeFarmSolarHouseholdAndBusinessProducts.
  ///
  /// In en, this message translates to:
  /// **'Farm, solar, household and business products — priced by your group\'s credit rating.'**
  String get storeFarmSolarHouseholdAndBusinessProducts;

  /// No description provided for @storeIntelliStoresLoadsFromTheIntelli.
  ///
  /// In en, this message translates to:
  /// **'Intelli-Stores loads from the Intelli-Cash backend. Connect or sign in first.'**
  String get storeIntelliStoresLoadsFromTheIntelli;

  /// No description provided for @businessProfileTheGroupSOwnEnterpriseNot.
  ///
  /// In en, this message translates to:
  /// **'The group\'s own enterprise, not a member\'s. Leave blank if they do not run one.'**
  String get businessProfileTheGroupSOwnEnterpriseNot;

  /// No description provided for @businessProfileThisVisitHasNotSyncedYet.
  ///
  /// In en, this message translates to:
  /// **'This visit has not synced yet, so the figures are saved against the group but not against this visit.'**
  String get businessProfileThisVisitHasNotSyncedYet;

  /// No description provided for @businessProfileSavedAgainstThisVisitSoNext.
  ///
  /// In en, this message translates to:
  /// **'Saved against this visit, so next time you can see what changed.'**
  String get businessProfileSavedAgainstThisVisitSoNext;

  /// No description provided for @recordVisitAVisitCanStillBeRecorded.
  ///
  /// In en, this message translates to:
  /// **'A visit can still be recorded without a location. Whether it matches this group is decided by the office, not here.'**
  String get recordVisitAVisitCanStillBeRecorded;

  /// No description provided for @recordVisitRecordWhatYouCoachedOnThen.
  ///
  /// In en, this message translates to:
  /// **'Record what you coached on, then let the group score it.'**
  String get recordVisitRecordWhatYouCoachedOnThen;

  /// No description provided for @visitAssessmentNoAssessmentFormHasBeenDownloaded.
  ///
  /// In en, this message translates to:
  /// **'No assessment form has been downloaded yet. Connect once to fetch it, then it works offline.'**
  String get visitAssessmentNoAssessmentFormHasBeenDownloaded;

  /// No description provided for @visitMentorshipNotScoredYetAVisitCan.
  ///
  /// In en, this message translates to:
  /// **'Not scored yet. A visit can be recorded without it, but the group\'s view is the only useful measure of the coaching.'**
  String get visitMentorshipNotScoredYetAVisitCan;

  /// No description provided for @createPollNoMembersLoadedForThisGroup.
  ///
  /// In en, this message translates to:
  /// **'No members loaded for this group yet. Connect and open the group first.'**
  String get createPollNoMembersLoadedForThisGroup;

  /// No description provided for @createPollNobodySeesWhoVotedForWhat.
  ///
  /// In en, this message translates to:
  /// **'Nobody sees who voted for what. The counts are still shown to everyone.'**
  String get createPollNobodySeesWhoVotedForWhat;

  /// No description provided for @pollDetailNoMoreVotesCanBeCast.
  ///
  /// In en, this message translates to:
  /// **'No more votes can be cast after this, and the result is written into the group records. This cannot be undone.'**
  String get pollDetailNoMoreVotesCanBeCast;

  /// No description provided for @pollDetailClosingCountsTheVotesAndWrites.
  ///
  /// In en, this message translates to:
  /// **'Closing counts the votes and writes the result into the group records.'**
  String get pollDetailClosingCountsTheVotesAndWrites;

  /// No description provided for @pollDetailYouHaveVotedThisIsA.
  ///
  /// In en, this message translates to:
  /// **'You have voted. This is a secret ballot, so your choice is not shown to anyone.'**
  String get pollDetailYouHaveVotedThisIsA;

  /// No description provided for @pollsElectYourLeadersAndDecideTogether.
  ///
  /// In en, this message translates to:
  /// **'Elect your leaders and decide together. One member, one vote.'**
  String get pollsElectYourLeadersAndDecideTogether;

  /// No description provided for @pollsTapNewVoteToElectA.
  ///
  /// In en, this message translates to:
  /// **'Tap New Vote to elect a leader or put a question to the group.'**
  String get pollsTapNewVoteToElectA;

  /// No description provided for @pollsVotingIsKeptOnTheIntelli.
  ///
  /// In en, this message translates to:
  /// **'Voting is kept on the Intelli-Cash backend so every member sees the same tally. Connect or sign in first.'**
  String get pollsVotingIsKeptOnTheIntelli;

  /// No description provided for @unlockOpensWhen.
  ///
  /// In en, this message translates to:
  /// **'The meeting opens when {officials} officials — or {members} members — each turn their key.'**
  String unlockOpensWhen(int officials, int members);

  /// No description provided for @paymentProvidersStillNeeded.
  ///
  /// In en, this message translates to:
  /// **'Not finished — still needed: {fields}. Until then money still goes to the platform account.'**
  String paymentProvidersStillNeeded(String fields);

  /// No description provided for @welfareSharedOutExplainer.
  ///
  /// In en, this message translates to:
  /// **'This is what gets shared out at the end of the cycle — not the total contributed. {paidOut} has been paid out so far.'**
  String welfareSharedOutExplainer(String paidOut);

  /// No description provided for @shareOutStartsNextCycle.
  ///
  /// In en, this message translates to:
  /// **'This records every payout, settles outstanding loans, and starts Cycle {cycle}. It cannot be undone.'**
  String shareOutStartsNextCycle(int cycle);

  /// No description provided for @visitAssessmentPhotoCapReached.
  ///
  /// In en, this message translates to:
  /// **'This visit already has {max} photos.'**
  String visitAssessmentPhotoCapReached(int max);

  /// No description provided for @languageDraftBadge.
  ///
  /// In en, this message translates to:
  /// **'draft'**
  String get languageDraftBadge;

  /// No description provided for @enterpriseNothingRecordedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet. Add the first business this group runs together.'**
  String get enterpriseNothingRecordedYet;

  /// No description provided for @enterpriseAddAnotherBusiness.
  ///
  /// In en, this message translates to:
  /// **'Add another business'**
  String get enterpriseAddAnotherBusiness;

  /// No description provided for @enterpriseWhatTheyNeed.
  ///
  /// In en, this message translates to:
  /// **'What they need'**
  String get enterpriseWhatTheyNeed;

  /// No description provided for @enterpriseAddSomethingTheyNeed.
  ///
  /// In en, this message translates to:
  /// **'Add something they need'**
  String get enterpriseAddSomethingTheyNeed;

  /// No description provided for @enterpriseEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get enterpriseEdit;

  /// No description provided for @enterpriseMoneyInEachMonth.
  ///
  /// In en, this message translates to:
  /// **'Money in each month'**
  String get enterpriseMoneyInEachMonth;

  /// No description provided for @enterpriseCostsEachMonth.
  ///
  /// In en, this message translates to:
  /// **'Costs each month'**
  String get enterpriseCostsEachMonth;

  /// No description provided for @enterpriseWhatIsLeft.
  ///
  /// In en, this message translates to:
  /// **'What is left'**
  String get enterpriseWhatIsLeft;

  /// No description provided for @enterpriseHowFarItSells.
  ///
  /// In en, this message translates to:
  /// **'How far it sells'**
  String get enterpriseHowFarItSells;

  /// No description provided for @enterpriseBuyersLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Buyers last month'**
  String get enterpriseBuyersLastMonth;

  /// No description provided for @enterpriseWrittenAgreementWithBuyer.
  ///
  /// In en, this message translates to:
  /// **'Written agreement with a buyer'**
  String get enterpriseWrittenAgreementWithBuyer;

  /// No description provided for @enterpriseNotAsked.
  ///
  /// In en, this message translates to:
  /// **'Not asked'**
  String get enterpriseNotAsked;

  /// No description provided for @enterpriseNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get enterpriseNotRecorded;

  /// No description provided for @enterpriseYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get enterpriseYes;

  /// No description provided for @enterpriseNoInformal.
  ///
  /// In en, this message translates to:
  /// **'No, informal'**
  String get enterpriseNoInformal;

  /// No description provided for @enterpriseYesInWriting.
  ///
  /// In en, this message translates to:
  /// **'Yes, in writing'**
  String get enterpriseYesInWriting;

  /// No description provided for @enterpriseUrgent.
  ///
  /// In en, this message translates to:
  /// **'urgent'**
  String get enterpriseUrgent;

  /// No description provided for @enterpriseNewBusiness.
  ///
  /// In en, this message translates to:
  /// **'New business'**
  String get enterpriseNewBusiness;

  /// No description provided for @enterpriseEditBusiness.
  ///
  /// In en, this message translates to:
  /// **'Edit business'**
  String get enterpriseEditBusiness;

  /// No description provided for @enterpriseWhatIsItCalled.
  ///
  /// In en, this message translates to:
  /// **'What is it called'**
  String get enterpriseWhatIsItCalled;

  /// No description provided for @enterpriseNameHint.
  ///
  /// In en, this message translates to:
  /// **'Poultry unit'**
  String get enterpriseNameHint;

  /// No description provided for @enterpriseWhereTheySell.
  ///
  /// In en, this message translates to:
  /// **'Where they sell'**
  String get enterpriseWhereTheySell;

  /// No description provided for @enterpriseWhereTheySellHint.
  ///
  /// In en, this message translates to:
  /// **'How far what they make actually travels, and how many people buy it.'**
  String get enterpriseWhereTheySellHint;

  /// No description provided for @enterpriseHowFarItReaches.
  ///
  /// In en, this message translates to:
  /// **'How far it reaches'**
  String get enterpriseHowFarItReaches;

  /// No description provided for @enterpriseHowManyBuyersLastMonth.
  ///
  /// In en, this message translates to:
  /// **'How many buyers last month'**
  String get enterpriseHowManyBuyersLastMonth;

  /// No description provided for @enterpriseHowTheySell.
  ///
  /// In en, this message translates to:
  /// **'How they sell'**
  String get enterpriseHowTheySell;

  /// No description provided for @enterpriseIsThereWrittenAgreement.
  ///
  /// In en, this message translates to:
  /// **'Is there a written agreement with a buyer'**
  String get enterpriseIsThereWrittenAgreement;

  /// No description provided for @enterpriseMonthsTheySellIn.
  ///
  /// In en, this message translates to:
  /// **'Months they sell in'**
  String get enterpriseMonthsTheySellIn;

  /// No description provided for @enterpriseLeaveBlankIfAllYear.
  ///
  /// In en, this message translates to:
  /// **'Leave blank if they sell all year.'**
  String get enterpriseLeaveBlankIfAllYear;

  /// No description provided for @enterpriseWhatDoesThisBusinessNeed.
  ///
  /// In en, this message translates to:
  /// **'What does this business need?'**
  String get enterpriseWhatDoesThisBusinessNeed;

  /// No description provided for @enterpriseHowUrgentIsIt.
  ///
  /// In en, this message translates to:
  /// **'How urgent is it?'**
  String get enterpriseHowUrgentIsIt;

  /// No description provided for @enterpriseAskGroupToRank.
  ///
  /// In en, this message translates to:
  /// **'Ask the group how they would rank it.'**
  String get enterpriseAskGroupToRank;

  /// No description provided for @enterpriseAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get enterpriseAdd;

  /// No description provided for @enterpriseSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get enterpriseSave;

  /// No description provided for @enterpriseSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get enterpriseSaving;

  /// No description provided for @enterpriseSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get enterpriseSaved;

  /// No description provided for @enterpriseCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load. You need a connection for this one.'**
  String get enterpriseCouldNotLoad;

  /// No description provided for @enterpriseCouldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Check your connection and try again.'**
  String get enterpriseCouldNotSave;

  /// No description provided for @enterpriseCouldNotSaveNeed.
  ///
  /// In en, this message translates to:
  /// **'Could not save that need. Check your connection.'**
  String get enterpriseCouldNotSaveNeed;

  /// No description provided for @enterpriseNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give this business a name so it can be told apart.'**
  String get enterpriseNameRequired;

  /// No description provided for @enterpriseReadingsTaken.
  ///
  /// In en, this message translates to:
  /// **'Times recorded'**
  String get enterpriseReadingsTaken;

  /// No description provided for @enterpriseRevenueSinceFirst.
  ///
  /// In en, this message translates to:
  /// **'Change since the first visit'**
  String get enterpriseRevenueSinceFirst;

  /// No description provided for @enterpriseNoBaselineYet.
  ///
  /// In en, this message translates to:
  /// **'Only recorded once so far'**
  String get enterpriseNoBaselineYet;

  /// No description provided for @enterpriseGroupNotYours.
  ///
  /// In en, this message translates to:
  /// **'This group is not on your list. Ask your supervisor to assign it.'**
  String get enterpriseGroupNotYours;

  /// No description provided for @agreedActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'What the group agreed to do'**
  String get agreedActionsTitle;

  /// No description provided for @agreedActionsNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing agreed yet. Whatever you record here is on screen when you or another agent opens the next visit.'**
  String get agreedActionsNothingYet;

  /// No description provided for @agreedActionsRecordedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} recorded at this visit.'**
  String agreedActionsRecordedCount(int count);

  /// No description provided for @agreedActionsAgreeAnAction.
  ///
  /// In en, this message translates to:
  /// **'Agree an action'**
  String get agreedActionsAgreeAnAction;

  /// No description provided for @agreedActionsReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get agreedActionsReopen;

  /// No description provided for @agreedActionsNotYetSent.
  ///
  /// In en, this message translates to:
  /// **'Not yet sent'**
  String get agreedActionsNotYetSent;

  /// No description provided for @agreedActionsSheetIntro.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone and sent with the visit. The next agent to open this group sees it before they start.'**
  String get agreedActionsSheetIntro;

  /// No description provided for @agreedActionsWhatWasAgreed.
  ///
  /// In en, this message translates to:
  /// **'What was agreed'**
  String get agreedActionsWhatWasAgreed;

  /// No description provided for @agreedActionsWhatWasAgreedHint.
  ///
  /// In en, this message translates to:
  /// **'Write up the ledger to the last meeting'**
  String get agreedActionsWhatWasAgreedHint;

  /// No description provided for @agreedActionsNeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Say what the group agreed to do.'**
  String get agreedActionsNeedTitle;

  /// No description provided for @agreedActionsWhoIsResponsible.
  ///
  /// In en, this message translates to:
  /// **'Who is responsible'**
  String get agreedActionsWhoIsResponsible;

  /// No description provided for @agreedActionsSetADate.
  ///
  /// In en, this message translates to:
  /// **'Set a date (optional)'**
  String get agreedActionsSetADate;

  /// No description provided for @agreedActionsDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String agreedActionsDueOn(String date);

  /// No description provided for @agreedActionsDetailOptional.
  ///
  /// In en, this message translates to:
  /// **'Detail (optional)'**
  String get agreedActionsDetailOptional;

  /// No description provided for @agreedActionsAddToThePlan.
  ///
  /// In en, this message translates to:
  /// **'Add to the plan'**
  String get agreedActionsAddToThePlan;

  /// No description provided for @actionOwnerChairperson.
  ///
  /// In en, this message translates to:
  /// **'Chairperson'**
  String get actionOwnerChairperson;

  /// No description provided for @actionOwnerSecretary.
  ///
  /// In en, this message translates to:
  /// **'Secretary'**
  String get actionOwnerSecretary;

  /// No description provided for @actionOwnerTreasurer.
  ///
  /// In en, this message translates to:
  /// **'Treasurer'**
  String get actionOwnerTreasurer;

  /// No description provided for @actionOwnerMoneyCounter.
  ///
  /// In en, this message translates to:
  /// **'Money counter'**
  String get actionOwnerMoneyCounter;

  /// No description provided for @actionOwnerKeyHolder.
  ///
  /// In en, this message translates to:
  /// **'Key holder'**
  String get actionOwnerKeyHolder;

  /// No description provided for @actionOwnerTheGroup.
  ///
  /// In en, this message translates to:
  /// **'The group'**
  String get actionOwnerTheGroup;

  /// No description provided for @actionDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get actionDueToday;

  /// No description provided for @actionDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get actionDueTomorrow;

  /// No description provided for @actionDueInDays.
  ///
  /// In en, this message translates to:
  /// **'Due in {days} days'**
  String actionDueInDays(int days);

  /// No description provided for @actionDaysOverdue.
  ///
  /// In en, this message translates to:
  /// **'{days} days overdue'**
  String actionDaysOverdue(int days);

  /// No description provided for @actionOneDayOverdue.
  ///
  /// In en, this message translates to:
  /// **'1 day overdue'**
  String get actionOneDayOverdue;

  /// No description provided for @actionNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get actionNoDueDate;

  /// No description provided for @actionDropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get actionDropped;

  /// No description provided for @recordVisitDiscardVisit.
  ///
  /// In en, this message translates to:
  /// **'Discard this visit'**
  String get recordVisitDiscardVisit;

  /// No description provided for @recordVisitDiscardVisitBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded here has been sent yet, and it will not be kept. Use this when a visit was opened by mistake.'**
  String get recordVisitDiscardVisitBody;

  /// No description provided for @recordVisitDiscardVisitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get recordVisitDiscardVisitConfirm;

  /// No description provided for @openActionItemsStillOpen.
  ///
  /// In en, this message translates to:
  /// **'{count} still open.'**
  String openActionItemsStillOpen(int count);

  /// No description provided for @openActionItemsStillOpenOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count} still open, {overdue} overdue. Go through these first.'**
  String openActionItemsStillOpenOverdue(int count, int overdue);

  /// No description provided for @joinRequestsTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Requests to join'**
  String get joinRequestsTileTitle;

  /// No description provided for @joinRequestsTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Answer people who have asked to join this group'**
  String get joinRequestsTileSubtitle;

  /// No description provided for @joinRequestsNoneWaiting.
  ///
  /// In en, this message translates to:
  /// **'Nobody is waiting'**
  String get joinRequestsNoneWaiting;

  /// No description provided for @joinRequestsWaitingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting for your answer'**
  String joinRequestsWaitingCount(int count);

  /// No description provided for @joinRequestsOneWaiting.
  ///
  /// In en, this message translates to:
  /// **'1 waiting for your answer'**
  String get joinRequestsOneWaiting;

  /// No description provided for @joinRequestsFilterWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get joinRequestsFilterWaiting;

  /// No description provided for @joinRequestsFilterAnswered.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get joinRequestsFilterAnswered;

  /// No description provided for @joinRequestsNoneAnswered.
  ///
  /// In en, this message translates to:
  /// **'Nothing answered yet'**
  String get joinRequestsNoneAnswered;

  /// No description provided for @joinRequestsNoneAnsweredBody.
  ///
  /// In en, this message translates to:
  /// **'Requests you approve or decline stay here, so the group can see who was let in and who was not.'**
  String get joinRequestsNoneAnsweredBody;

  /// No description provided for @joinRequestsAlreadyApproved.
  ///
  /// In en, this message translates to:
  /// **'Already approved'**
  String get joinRequestsAlreadyApproved;

  /// No description provided for @joinRequestsAlreadyDeclined.
  ///
  /// In en, this message translates to:
  /// **'Already declined'**
  String get joinRequestsAlreadyDeclined;

  /// No description provided for @joinRequestsCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load requests. Check your connection and pull down to try again.'**
  String get joinRequestsCouldNotLoad;

  /// No description provided for @joinRequestsAskedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get joinRequestsAskedJustNow;

  /// No description provided for @joinRequestsCouldNotLoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load'**
  String get joinRequestsCouldNotLoadTitle;
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
