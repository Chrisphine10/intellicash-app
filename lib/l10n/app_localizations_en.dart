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
      'Village Agent or CBT — I support and monitor several groups.';

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
      'Your session lasts 8 hours. The group\'s record book keeps working offline once you are signed in.';

  @override
  String get sectionGroup => 'Group';

  @override
  String get sectionReports => 'Reports';

  @override
  String get sectionEndOfCycle => 'End of cycle';

  @override
  String get sectionCloudBackup => 'Cloud & backup';

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
  String get language => 'Language';

  @override
  String get languageSubtitle => 'Choose the language for this phone';

  @override
  String get languageNeedsReview =>
      'Every screen is translated, but a speaker of this language has not checked the wording yet. If something reads wrongly, please tell us — you can switch back to English or Kiswahili at any time.';

  @override
  String get shareTextButton => 'Share Text';

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
  String get signOutMemberNote =>
      'You will need to sign in again to see your savings. Your phone number will be remembered.';

  @override
  String get signOutAgentNote =>
      'You will need to sign in again to see your groups. Your phone number will be remembered.';

  @override
  String get whoIsSigningIn => 'Who is signing in?';

  @override
  String get whoIsSigningInSubtitle =>
      'Choose the kind of account you use, then enter your phone number and password.';

  @override
  String get welfareRecordThisPayment => 'Record this payment?';

  @override
  String get welfareRecordPayment => 'Record payment';

  @override
  String get welfareWelfareFund => 'Welfare Fund';

  @override
  String get welfareCouldNotLoadTheWelfare =>
      'Could not load the welfare fund.';

  @override
  String get welfareTryAgain => 'Try again';

  @override
  String get welfareLeftInTheWelfareFund => 'Left in the welfare fund';

  @override
  String get welfareRecordAWelfarePayment => 'Record a welfare payment';

  @override
  String get welfarePaidOutThisCycle => 'Paid out this cycle';

  @override
  String get welfareNothingPaidOutYetThe =>
      'Nothing paid out yet — the whole welfare fund will be shared.';

  @override
  String get welfareRecordedInMeeting => 'Recorded in meeting';

  @override
  String get welfareAmountKsh => 'Amount (KSh)';

  @override
  String get welfareWhatFor => 'What for';

  @override
  String get welfarePaidTo => 'Paid to';

  @override
  String get welfareAMemberAFamilyOr =>
      'A member, a family, or a hospital — whoever received it';

  @override
  String get welfareNoteOptional => 'Note (optional)';

  @override
  String get meetingHubEditAttendance => 'Edit attendance';

  @override
  String get meetingHubCloseLockMeeting => 'Close & Lock Meeting';

  @override
  String get meetingHubClosingLocksAllRecordsPermanently =>
      'Closing locks all records permanently.';

  @override
  String get meetingHubKeepOpen => 'Keep Open';

  @override
  String get meetingHubCloseLock => 'Close & Lock';

  @override
  String get meetingHubSocialFund => 'Social Fund';

  @override
  String get meetingHubBuyShares => 'Buy Shares';

  @override
  String get meetingHubRecordFine => 'Record Fine';

  @override
  String get meetingHubDisburseLoan => 'Disburse Loan';

  @override
  String get meetingHubRepayment => 'Repayment';

  @override
  String get meetingHubShareRecords => 'Share Records';

  @override
  String get meetingHubVoting => 'Voting';

  @override
  String get meetingHubWelfare => 'Welfare';

  @override
  String get meetingHubIntelliStore => 'Intelli-Store';

  @override
  String get meetingHubExternalLoans => 'External Loans';

  @override
  String get groupSetupWizardAddTheMembersJoiningThis =>
      'Add the members joining this cycle. You can always add more later.';

  @override
  String get groupSetupWizardEveryoneBuysSharesAtOne =>
      'Everyone buys shares at one fixed price';

  @override
  String get groupSetupWizardMembersSaveWhatTheyCan =>
      'Members save what they can each meeting';

  @override
  String get groupSetupWizardGroupName => 'Group Name';

  @override
  String get groupSetupWizardCycleNumber => 'Cycle Number';

  @override
  String get groupSetupWizardWhichSavingsCycleIsThis =>
      'Which savings cycle is this group on?';

  @override
  String get groupSetupWizardMemberName => 'Member Name';

  @override
  String get groupSetupWizardAddMember => 'Add member';

  @override
  String get groupSetupWizardRemove => 'Remove';

  @override
  String get groupSetupWizardShareValueKsh => 'Share Value (KSh)';

  @override
  String get groupSetupWizardMaxSharesPerMeeting => 'Max Shares per Meeting';

  @override
  String get groupSetupWizardSocialFundPerMeetingKsh =>
      'Social Fund per Meeting (KSh)';

  @override
  String get groupSetupWizardTrackedSeparatelyFromSavings =>
      'Tracked separately from savings';

  @override
  String get groupSetupWizardInterestRatePerMonth =>
      'Interest Rate (% per month)';

  @override
  String get groupSetupWizardMaxLoanMultiplierSavings =>
      'Max Loan Multiplier (× savings)';

  @override
  String get groupSetupWizardDefaultLoanTermMonths =>
      'Default Loan Term (months)';

  @override
  String get groupSyncBackUpToCloud => 'Back Up to Cloud';

  @override
  String get groupSyncUnlinkGroup => 'Unlink group?';

  @override
  String get groupSyncUnlink => 'Unlink';

  @override
  String get groupSyncNotConnected => 'Not connected';

  @override
  String get groupSyncOpenServerConnection => 'Open Server Connection';

  @override
  String get groupSyncLink => 'Link';

  @override
  String get groupSyncUnlinkGroup2 => 'Unlink Group';

  @override
  String get groupSyncNoBackendGroups => 'No backend groups';

  @override
  String get groupSyncThisApiKeyCannotSee =>
      'This API key cannot see any groups to link to.';

  @override
  String get groupSyncBackendGroup => 'Backend group';

  @override
  String get createPollStartAVote => 'Start a Vote';

  @override
  String get createPollEveryonePresentVotesOnceNobody =>
      'Everyone present votes once. Nobody can vote twice.';

  @override
  String get createPollChooseALeader => 'Choose a leader';

  @override
  String get createPollDecideSomething => 'Decide something';

  @override
  String get createPollTickAtLeastTwoPeople => 'Tick at least two people.';

  @override
  String get createPollAddAnotherAnswer => 'Add another answer';

  @override
  String get createPollSecretVote => 'Secret vote';

  @override
  String get createPollOpenTheVote => 'Open the Vote';

  @override
  String get createPollWhichPosition => 'Which position?';

  @override
  String get createPollWhatIsTheQuestion => 'What is the question?';

  @override
  String get createPollShouldWeBuyAGroup => 'Should we buy a group water tank?';

  @override
  String get paymentProvidersLeaveABoxEmptyTo =>
      'Leave a box empty to keep what is already saved.';

  @override
  String get paymentProvidersSave => 'Save';

  @override
  String get paymentProvidersUseThePlatformAccount =>
      'Use the platform account?';

  @override
  String get paymentProvidersPaymentProviders => 'Payment Providers';

  @override
  String get paymentProvidersUsePlatform => 'Use platform';

  @override
  String get storeShopOnCredit => 'Shop on credit';

  @override
  String get storeLoanOffersFromLendingPartners =>
      'Loan offers from lending partners — apply as a group.';

  @override
  String get storeSeeAllExternalLoans => 'See all external loans';

  @override
  String get storeConnectToBrowseTheStore => 'Connect to browse the store';

  @override
  String get storeOpenCloudAccount => 'Open Cloud Account';

  @override
  String get storeAll => 'All';

  @override
  String get storeCouldNotLoadTheStore => 'Could not load the store';

  @override
  String get storeNoProductsInThisCategory => 'No products in this category';

  @override
  String get storeTryADifferentCategoryOr =>
      'Try a different category or check back later.';

  @override
  String get pollsNewVote => 'New Vote';

  @override
  String get pollsGroupVotes => 'Group votes';

  @override
  String get pollsSecret => 'Secret';

  @override
  String get pollsYouHaveVoted => 'You have voted';

  @override
  String get pollsConnectToVote => 'Connect to vote';

  @override
  String get pollsCouldNotLoadTheVotes => 'Could not load the votes';

  @override
  String get pollsNoVotesYet => 'No votes yet';

  @override
  String get memberPassbookMyPassbook => 'My Passbook';

  @override
  String get memberPassbookJoinAGroup => 'Join a group';

  @override
  String get memberPassbookMyReport => 'My report';

  @override
  String get memberPassbookMySavingsAcrossAllGroups =>
      'My savings across all groups';

  @override
  String get memberPassbookJoinAnotherGroup => 'Join another group';

  @override
  String get memberPassbookYouAreNotInA => 'You are not in a group yet';

  @override
  String get memberPassbookNoTransactionsYet => 'No transactions yet';

  @override
  String get memberPassbookYourSavingsAndLoanRecords =>
      'Your savings and loan records will appear here.';

  @override
  String get joinRequestsDecline => 'Decline';

  @override
  String get joinRequestsJoinRequests => 'Join Requests';

  @override
  String get joinRequestsPeopleAskingToJoin => 'People asking to join';

  @override
  String get joinRequestsApprove => 'Approve';

  @override
  String get joinRequestsReasonOptional => 'Reason (optional)';

  @override
  String get joinRequestsNoOneIsWaiting => 'No one is waiting';

  @override
  String get pollDetailCloseThisVote => 'Close this vote?';

  @override
  String get pollDetailCloseVote => 'Close Vote';

  @override
  String get pollDetailVote => 'Vote';

  @override
  String get pollDetailYourChoice => 'Your choice';

  @override
  String get pollDetailNoMembersLoadedForThis =>
      'No members loaded for this group yet.';

  @override
  String get pollDetailMemberCastingThisVote => 'Member casting this vote';

  @override
  String get groupPolicyHowLongALoanRuns => 'How long a loan runs';

  @override
  String get groupPolicyInterestCharged => 'Interest charged';

  @override
  String get groupPolicyExpensesArePaidFrom => 'Expenses are paid from';

  @override
  String get groupPolicyRulesThatAreFixed => 'Rules that are fixed';

  @override
  String get productDetailRequestOnCredit => 'Request on Credit';

  @override
  String get productDetailQuantity => 'Quantity';

  @override
  String get productDetailSubmitRequest => 'Submit Request';

  @override
  String get productDetailPricedAtTheStandardDeposit =>
      'Priced at the standard deposit — rating unavailable.';

  @override
  String get productDetailProgramme => 'Programme';

  @override
  String get productDetailCustomerName => 'Customer name';

  @override
  String get productDetailEmail => 'Email';

  @override
  String get productDetailGroupNameOptional => 'Group name (optional)';

  @override
  String get dashboardHello => 'Hello 👋';

  @override
  String get dashboardTotalSavings => 'Total Savings';

  @override
  String get dashboardActiveLoans => 'Active Loans';

  @override
  String get dashboardFinesCollected => 'Fines Collected';

  @override
  String get disburseLoanLoanEligibility => 'Loan Eligibility';

  @override
  String get disburseLoanSelectMember => 'Select Member';

  @override
  String get disburseLoanPrincipalAmountKsh => 'Principal Amount (KSh)';

  @override
  String get disburseLoanDueDate => 'Due Date';

  @override
  String get joinGroupRequestSent => 'Request sent';

  @override
  String get joinGroupDone => 'Done';

  @override
  String get joinGroupAskYourGroupToAdd => 'Ask your group to add you';

  @override
  String get joinGroupSendRequest => 'Send request';

  @override
  String get joinGroupViewing => 'Viewing';

  @override
  String get joinGroupGroupCode => 'Group code';

  @override
  String get memberDetailEditDetails => 'Edit details';

  @override
  String get memberDetailMemberReport => 'Member report';

  @override
  String get memberDetailNoLoansTaken => 'No loans taken';

  @override
  String get memberDetailStartingPassword => 'Starting password';

  @override
  String get memberDetailAtLeast6Characters => 'At least 6 characters.';

  @override
  String get cyclesCloseCycle => 'Close cycle';

  @override
  String get cyclesSavingCycles => 'Saving Cycles';

  @override
  String get cyclesCloseCycleAndStartThe => 'Close cycle and start the next';

  @override
  String get cyclesReadOnlyStillVisibleIn =>
      'Read-only — still visible in reports';

  @override
  String get externalLoansCreditVentures => 'Credit ventures';

  @override
  String get externalLoansConnectToSeeLoanOffers =>
      'Connect to see loan offers';

  @override
  String get externalLoansCouldNotLoadLoanOffers =>
      'Could not load loan offers';

  @override
  String get externalLoansNoLoanOffersRightNow => 'No loan offers right now';

  @override
  String get accountAccount => 'Account';

  @override
  String get accountServer => 'Server';

  @override
  String get accountAppVersion => 'App version';

  @override
  String get accountPhone => 'Phone';

  @override
  String get businessProfileGroupBusiness => 'Group business';

  @override
  String get businessProfileWhatDoesTheGroupRun =>
      'What does the group run together?';

  @override
  String get businessProfileTypeOfBusiness => 'Type of business';

  @override
  String get businessProfileEGPoultryCerealBuying =>
      'e.g. poultry, cereal buying';

  @override
  String get businessProfileMoneyInEachMonthKes => 'Money in each month (KES)';

  @override
  String get businessProfileCostsEachMonthKes => 'Costs each month (KES)';

  @override
  String get businessProfilePeopleItEmploys => 'People it employs';

  @override
  String get businessProfileBiggestProblemTheyFace =>
      'Biggest problem they face';

  @override
  String get recordVisitSettings => 'Settings';

  @override
  String get recordVisitScoreTheGroup => 'Score the group';

  @override
  String get recordVisitTheGroupSEnterprise => 'The group’s enterprise';

  @override
  String get recordVisitWhatTheyRunTogetherAnd =>
      'What they run together, and how it is doing.';

  @override
  String get recordVisitSavedOnThisPhoneFirst =>
      'Saved on this phone first, then sent when you have signal.';

  @override
  String get recordVisitWhyNotOptional => 'Why not? (optional)';

  @override
  String get recordVisitWhatYouFound => 'What you found';

  @override
  String get agentHomeMyGroups => 'My Groups';

  @override
  String get agentHomeCaseloadReport => 'Caseload report';

  @override
  String get agentHomeNoGroupsAssigned => 'No groups assigned';

  @override
  String get agentHomeGroups => 'Groups';

  @override
  String get agentHomeNeedSupport => 'Need support';

  @override
  String get loansLoanPortfolio => 'Loan Portfolio';

  @override
  String get loansActive => 'Active';

  @override
  String get loansSearchByMemberName => 'Search by member name';

  @override
  String get loansNoLoansHere => 'No loans here';

  @override
  String get threeKeyUnlockUnlockMeeting => 'Unlock Meeting';

  @override
  String get threeKeyUnlockVerified => 'Verified';

  @override
  String get threeKeyUnlockSendANewCode => 'Send a new code';

  @override
  String get threeKeyUnlockNoSmsUseMySaved =>
      'No SMS? Use my saved PIN instead';

  @override
  String get threeKeyUnlockOneTimeCode => 'One-time code';

  @override
  String get threeKeyUnlockRepeatPin => 'Repeat PIN';

  @override
  String get memberReportMyReport => 'My Report';

  @override
  String get memberReportShare => 'Share';

  @override
  String get memberReportNotSignedIn => 'Not signed in';

  @override
  String get memberReportSignInToYourAccount =>
      'Sign in to your account to see and share your report.';

  @override
  String get cloudDashboardCloudData => 'Cloud Data';

  @override
  String get cloudDashboardRefresh => 'Refresh';

  @override
  String get cloudDashboardSavingsFund => 'Savings Fund';

  @override
  String get cloudDashboardInternalLoans => 'Internal Loans';

  @override
  String get serverSettingsOrUseAGroupAccess => 'or use a group access key';

  @override
  String get serverSettingsViewOnlineRecords => 'View Online Records';

  @override
  String get serverSettingsBackUpThisGroup => 'Back Up This Group';

  @override
  String get serverSettingsAccessKey => 'Access key';

  @override
  String get shareOutDistribute => 'Distribute';

  @override
  String get shareOutFundToDistribute => 'Fund to distribute';

  @override
  String get shareOutSplitWelfareFundEqually => 'Split welfare fund equally';

  @override
  String get shareOutNothingToShareOutYet => 'Nothing to share out yet';

  @override
  String get visitAssessmentAssessment => 'Assessment';

  @override
  String get visitAssessmentFormNotAvailable => 'Form not available';

  @override
  String get visitMentorshipMentorship => 'Mentorship';

  @override
  String get visitMentorshipWhatDidYouCoachOn => 'What did you coach on?';

  @override
  String get visitMentorshipTapATopicToRecord =>
      'Tap a topic to record it, then add what you advised.';

  @override
  String get visitMentorshipNowHandThePhoneTo =>
      'Now hand the phone to the group';

  @override
  String get visitMentorshipWhatYouAdvised => 'What you advised';

  @override
  String get agentGroupDetailRecordAVisit => 'Record a visit';

  @override
  String get agentGroupDetailNoMembersLoaded => 'No members loaded.';

  @override
  String get agentGroupDetailNoMeetingsLoaded => 'No meetings loaded.';

  @override
  String get agentGroupDetailToImprove => 'To improve';

  @override
  String get agentGroupDetailGovernance => 'Governance';

  @override
  String get agentGroupDetailVslaCompliance => 'VSLA compliance';

  @override
  String get recordFineReason => 'Reason';

  @override
  String get recordFineSpecifyReason => 'Specify reason';

  @override
  String get addMemberAddMember => 'Add Member';

  @override
  String get addMemberRegisterMember => 'Register Member';

  @override
  String get addMemberFullName => 'Full Name';

  @override
  String get addMemberPhoneOptional => 'Phone (optional)';

  @override
  String get addMemberRole => 'Role';

  @override
  String get editMemberEditMember => 'Edit member';

  @override
  String get editMemberFullName => 'Full name';

  @override
  String get membersRequestsToJoin => 'Requests to join';

  @override
  String get membersSearchMembers => 'Search members';

  @override
  String get membersNoMembersFound => 'No members found';

  @override
  String get meetingSecurity3KeyUnlockBeforeMeetings =>
      '3-key unlock before meetings';

  @override
  String get meetingSecurityKeepPin => 'Keep PIN';

  @override
  String get meetingSecurityReset => 'Reset';

  @override
  String get agentReportCaseloadReport => 'Caseload Report';

  @override
  String get agentReportShareReport => 'Share Report';

  @override
  String get agentReportNeedsSupport => 'Needs support';

  @override
  String get agentReportNoRating => 'No rating';

  @override
  String get agentReportNoGroupsYet => 'No groups yet';

  @override
  String get groupReportNoGroupYet => 'No group yet';

  @override
  String get groupReportSetUpYourGroupFirst =>
      'Set up your group first, then come back for a report.';

  @override
  String get groupReportNoMembersYet => 'No members yet';

  @override
  String get groupReportMembersAppearHereOnceThey =>
      'Members appear here once they join the group.';

  @override
  String get memberReportLocalMemberReport => 'Member Report';

  @override
  String get memberReportLocalMemberNotFound => 'Member not found';

  @override
  String get memberReportLocalThisMemberIsNoLonger =>
      'This member is no longer in the group.';

  @override
  String get memberReportLocalLoansThisMemberTakesWill =>
      'Loans this member takes will appear here.';

  @override
  String get externalLoanApplyApplyForALoan => 'Apply for a Loan';

  @override
  String get externalLoanApplySubmitApplication => 'Submit Application';

  @override
  String get externalLoanApplyWhatIsTheLoanFor => 'What is the loan for?';

  @override
  String get externalLoanApplyEGBuyingMaizeSeed =>
      'e.g. Buying maize seed for the season';

  @override
  String get meetingsNoMeetingsYet => 'No meetings yet';

  @override
  String get repaymentRecordRepayment => 'Record Repayment';

  @override
  String get repaymentNoOutstandingLoansNothingTo =>
      'No outstanding loans — nothing to repay. 🎉';

  @override
  String get repaymentSelectLoan => 'Select Loan';

  @override
  String get moreWhoIsSignedInLanguage =>
      'Who is signed in, language, appearance and app details';

  @override
  String get moreIntelliCash => 'Intelli-Cash';

  @override
  String get mySavingsMySavings => 'My Savings';

  @override
  String get mySavingsOnceAGroupAcceptsYou =>
      'Once a group accepts you, your savings will show here.';

  @override
  String get buySharesEnterCodeByHand => 'Enter Code by Hand';

  @override
  String get buySharesRecordPurchase => 'Record Purchase';

  @override
  String get sharesLedgerNoPurchasesYet => 'No purchases yet';

  @override
  String get socialFundThisMeetingIsClosedThe =>
      'This meeting is closed — the record is read-only.';

  @override
  String get socialFundNoMembers => 'No members';

  @override
  String get socialFundAddMembersToTheGroup =>
      'Add members to the group first.';

  @override
  String get welcomeUseTheWebConsoleFor =>
      'Use the web console for this account';

  @override
  String get welcomeLoadYourGroupOntoThis => 'Load your group onto this phone';

  @override
  String get memberReportsTapAMemberToSee =>
      'Tap a member to see and share their report.';

  @override
  String get openActionItemsNothingOutstanding => 'Nothing outstanding';

  @override
  String get openActionItemsThisGroupHasNoOpen =>
      'This group has no open actions from previous visits.';

  @override
  String get openActionItemsFromTheLastVisit => 'From the last visit';

  @override
  String get loanDetailNoRepaymentsYet => 'No repayments yet';

  @override
  String get attendanceAttendance => 'Attendance';

  @override
  String get attendanceContinueToMeeting => 'Continue to Meeting';

  @override
  String get appearanceChooseHowIntelliCashLooks =>
      'Choose how Intelli-Cash looks on this phone.';

  @override
  String get gatewayPaymentOpenThisLinkToPay => 'Open this link to pay:';

  @override
  String get numericKeypadDelete => 'Delete';

  @override
  String get agentHomeWhenGroupsAreAssignedToYou =>
      'When groups are assigned to you, they appear here with their credit rating.';

  @override
  String get dashboardTheSavingsCurveAppearsAfterYour =>
      'The savings curve appears after your first two meetings.';

  @override
  String get disburseLoanThisMemberHasNoBorrowingHeadroom =>
      'This member has no borrowing headroom — savings must grow or the current loan must reduce first.';

  @override
  String get disburseLoanTheLoanFundIsEmptyCollect =>
      'The loan fund is empty. Collect share purchases or loan repayments before lending again.';

  @override
  String get loanDetailRepaymentsAreRecordedInsideMeetingsAnd =>
      'Repayments are recorded inside meetings and appear here instantly.';

  @override
  String get loansLoansAreDisbursedInsideAMeeting =>
      'Loans are disbursed inside a meeting — open a meeting and use Disburse Loan.';

  @override
  String get gatewayPaymentRequestSentAskTheMemberTo =>
      'Request sent. Ask the member to enter their M-Pesa PIN on their phone.';

  @override
  String get meetingHubThisMeetingIsClosedItsRecords =>
      'This meeting is closed. Its records are read-only and form part of the audit trail.';

  @override
  String get meetingHubAllRecordsInThisMeetingWill =>
      'All records in this meeting will be locked permanently. This cannot be undone.';

  @override
  String get meetings3KeyUnlockIsOnOfficials =>
      '3-key unlock is on: officials confirm their PINs before the meeting opens.';

  @override
  String get meetingsStartYourFirstMeetingToRecord =>
      'Start your first meeting to record attendance, savings, fines and loans.';

  @override
  String get meetingsClosedMeetingsAreLockedTheirRecords =>
      'Closed meetings are locked — their records form the group\'s permanent audit trail.';

  @override
  String get sharesLedgerSharePurchasesLandHereTheMoment =>
      'Share purchases land here the moment they are recorded.';

  @override
  String get joinGroupYourGroupHasACodeOn =>
      'Your group has a code on its records — ask the secretary if you do not know it. Sending a request does not open the group\'s books to you; an official has to accept you first.';

  @override
  String get memberPassbookAskYourGroupToAddYou =>
      'Ask your group to add you and your savings will show up here.';

  @override
  String get editMemberCorrectingASpellingOrAMistyped =>
      'Correcting a spelling or a mistyped number. Their savings, loans and attendance stay exactly as they are.';

  @override
  String get joinRequestsTheyWillNotBeAddedTo =>
      'They will not be added to the group. You can say why if you want to — it is not required.';

  @override
  String get joinRequestsThisListIsOutOfDate =>
      'This list is out of date. Pull down to refresh, then check the answer again.';

  @override
  String get joinRequestsWhenSomeoneAsksToJoinYour =>
      'When someone asks to join your group, their request will show up here for you to answer.';

  @override
  String get memberDetailToCreateASignInAccount =>
      'To create a sign-in account, first back this group up to the cloud (More → Sync & Backup) while online.';

  @override
  String get memberDetailLoansThisMemberTakesWillBe =>
      'Loans this member takes will be listed here with their live status.';

  @override
  String get membersAddMembersWithTheButtonBelow =>
      'Add members with the button below — each gets an individual savings and loan profile.';

  @override
  String get meetingSecurityAssignAChairpersonSecretaryAndTreasurer =>
      'Assign a chairperson, secretary and treasurer below so three officials can unlock meetings. Until then, most members\' PINs are needed instead.';

  @override
  String get meetingSecurityTheOldPinStopsWorkingThe =>
      'The old PIN stops working. The member chooses a new PIN the next time they turn their key at a meeting unlock.';

  @override
  String get moreYourGroupSSavingsAndLoans =>
      'Your group\'s savings and loans, right on your phone. Everything is saved on this phone first and backed up online when you have internet.\\n\\nIntelli-Wealth Limited · intelliwealth.org';

  @override
  String get moreNoInternetYourRecordsAreSafe =>
      'No internet — your records are safe on this phone and will back up later.';

  @override
  String get welcomeThePhoneAppIsForGroups =>
      'The phone app is for groups, members and field agents. Your account does not need to create a group here — sign in on the web console instead, or sign out to use a different account.';

  @override
  String get welcomeYourGroupIsAlreadyOnThe =>
      'Your group is already on the server. Load it here instead of creating a new one, so your savings history stays in one record.';

  @override
  String get agentReportWhenGroupsAreAssignedToYou =>
      'When groups are assigned to you, their report appears here.';

  @override
  String get groupReportFiguresFromThisPhoneOnlyWork =>
      'Figures from this phone only - work saved on other phones may not be included yet.';

  @override
  String get groupReportFromThisPhoneOnlyWorkSaved =>
      'From this phone only. Work saved on other phones may not be included yet.';

  @override
  String get memberReportLocalFiguresFromThisPhoneOnlyRecords =>
      'Figures from this phone only - records saved elsewhere may not be included yet.';

  @override
  String get mySavingsWhatYouOweIsCountedFor =>
      'What you owe is counted for each group on its own. Paying extra in one group does not reduce what you owe in another.';

  @override
  String get groupSyncThisClearsTheLocalBackendMapping =>
      'This clears the local↔backend mapping. Already-synced records stay on the server; nothing is deleted.';

  @override
  String get groupSyncConnectToTheIntellicashBackendBefore =>
      'Connect to the IntelliCash backend before linking and syncing this group.';

  @override
  String get groupSyncLinkingMatchesYourLocalMembersTo =>
      'Linking matches your local members to the backend roster by phone, then name. Unmatched members can be linked by hand afterwards.';

  @override
  String get groupSyncTheseLocalMembersHaveNoBackend =>
      'These local members have no backend match. Link them before their transactions can sync.';

  @override
  String get groupSyncUploadsAttendanceAndLedgerSharesSocial =>
      'Uploads attendance and ledger (shares, social fund, loans, repayments) for every closed meeting. Safe to re-run — already synced records are skipped. Fines and meeting sealing come in a later phase.';

  @override
  String get serverSettingsAskYourGroupAdministratorForAn =>
      'Ask your group administrator for an access key, then paste it here. It only lets this phone see and record your group\'s savings, loans and meetings.';

  @override
  String get cyclesPullDownToTryAgainIf =>
      'Pull down to try again. If it keeps happening, check the group is still selected under Cloud Account.';

  @override
  String get cyclesClosingACycleMakesItsRecords =>
      'Closing a cycle makes its records read-only. Nothing is deleted — past meetings and money stay in history and reports.';

  @override
  String get cyclesYouCanSeeTheCyclesBut =>
      'You can see the cycles but not close one. Only the group account or a platform admin can.';

  @override
  String get groupPolicyAppliesToNewLoansLoansAlready =>
      'Applies to new loans. Loans already given keep the term they were agreed with — changing this never changes what a member already owes.';

  @override
  String get groupPolicyFlatOnTheAmountBorrowedEach =>
      'Flat on the amount borrowed each month — it does not fall as the member repays, and it stops at the end of the agreed term. Zero is fine: many groups lend interest-free. Each loan keeps the rate it was made at, so changing this never reprices money already lent.';

  @override
  String get groupPolicyYouCanSeeTheseRulesBut =>
      'You can see these rules but not change them. Only the group account or a platform admin can.';

  @override
  String get groupPolicyUnpaidFinesAndWelfareAreTaken =>
      'Unpaid fines and welfare are taken off a member\'s share-out payout — they never stop a member from sharing out.\\n\\nOutstanding loans are taken off at share-out and are never carried into the next cycle.';

  @override
  String get paymentProvidersMPesaClassicNeedsNothingHere =>
      'M-Pesa Classic needs nothing here — the member types in the transaction code from their phone.';

  @override
  String get paymentProvidersYouCanSeeThisButNot =>
      'You can see this but not change it. Only the group account or a platform admin can move where money is received.';

  @override
  String get welfareYouAreOfflineWelfarePaymentsAre =>
      'You are offline. Welfare payments are recorded on the server so the fund cannot be overspent by two phones at once — reconnect to record one.';

  @override
  String get welfareNoMeetingIsOpenWelfareIs =>
      'No meeting is open. Welfare is paid out during a meeting, in front of the members — open one first, then record it there.';

  @override
  String get shareOutMembersHavenTBoughtSharesThis =>
      'Members haven\'t bought shares this cycle. Run meetings and collect shares first, then come back to distribute the fund.';

  @override
  String get externalLoanApplyCreditRatingUnavailableTheLenderChecks =>
      'Credit rating unavailable — the lender checks it when reviewing your application.';

  @override
  String get externalLoansCheckBackLaterPartnersAddNew =>
      'Check back later — partners add new loan offers from time to time.';

  @override
  String get externalLoansExternalLoansLoadFromTheIntelli =>
      'External loans load from the Intelli-Cash backend. Connect or sign in first.';

  @override
  String get storeFarmSolarHouseholdAndBusinessProducts =>
      'Farm, solar, household and business products — priced by your group\'s credit rating.';

  @override
  String get storeIntelliStoresLoadsFromTheIntelli =>
      'Intelli-Stores loads from the Intelli-Cash backend. Connect or sign in first.';

  @override
  String get businessProfileTheGroupSOwnEnterpriseNot =>
      'The group\'s own enterprise, not a member\'s. Leave blank if they do not run one.';

  @override
  String get businessProfileThisVisitHasNotSyncedYet =>
      'This visit has not synced yet, so the figures are saved against the group but not against this visit.';

  @override
  String get businessProfileSavedAgainstThisVisitSoNext =>
      'Saved against this visit, so next time you can see what changed.';

  @override
  String get recordVisitAVisitCanStillBeRecorded =>
      'A visit can still be recorded without a location. Whether it matches this group is decided by the office, not here.';

  @override
  String get recordVisitRecordWhatYouCoachedOnThen =>
      'Record what you coached on, then let the group score it.';

  @override
  String get visitAssessmentNoAssessmentFormHasBeenDownloaded =>
      'No assessment form has been downloaded yet. Connect once to fetch it, then it works offline.';

  @override
  String get visitMentorshipNotScoredYetAVisitCan =>
      'Not scored yet. A visit can be recorded without it, but the group\'s view is the only useful measure of the coaching.';

  @override
  String get createPollNoMembersLoadedForThisGroup =>
      'No members loaded for this group yet. Connect and open the group first.';

  @override
  String get createPollNobodySeesWhoVotedForWhat =>
      'Nobody sees who voted for what. The counts are still shown to everyone.';

  @override
  String get pollDetailNoMoreVotesCanBeCast =>
      'No more votes can be cast after this, and the result is written into the group records. This cannot be undone.';

  @override
  String get pollDetailClosingCountsTheVotesAndWrites =>
      'Closing counts the votes and writes the result into the group records.';

  @override
  String get pollDetailYouHaveVotedThisIsA =>
      'You have voted. This is a secret ballot, so your choice is not shown to anyone.';

  @override
  String get pollsElectYourLeadersAndDecideTogether =>
      'Elect your leaders and decide together. One member, one vote.';

  @override
  String get pollsTapNewVoteToElectA =>
      'Tap New Vote to elect a leader or put a question to the group.';

  @override
  String get pollsVotingIsKeptOnTheIntelli =>
      'Voting is kept on the Intelli-Cash backend so every member sees the same tally. Connect or sign in first.';

  @override
  String unlockOpensWhen(int officials, int members) {
    return 'The meeting opens when $officials officials — or $members members — each turn their key.';
  }

  @override
  String paymentProvidersStillNeeded(String fields) {
    return 'Not finished — still needed: $fields. Until then money still goes to the platform account.';
  }

  @override
  String welfareSharedOutExplainer(String paidOut) {
    return 'This is what gets shared out at the end of the cycle — not the total contributed. $paidOut has been paid out so far.';
  }

  @override
  String shareOutStartsNextCycle(int cycle) {
    return 'This records every payout, settles outstanding loans, and starts Cycle $cycle. It cannot be undone.';
  }

  @override
  String visitAssessmentPhotoCapReached(int max) {
    return 'This visit already has $max photos.';
  }

  @override
  String get languageDraftBadge => 'draft';

  @override
  String get enterpriseNothingRecordedYet =>
      'Nothing recorded yet. Add the first business this group runs together.';

  @override
  String get enterpriseAddAnotherBusiness => 'Add another business';

  @override
  String get enterpriseWhatTheyNeed => 'What they need';

  @override
  String get enterpriseAddSomethingTheyNeed => 'Add something they need';

  @override
  String get enterpriseEdit => 'Edit';

  @override
  String get enterpriseMoneyInEachMonth => 'Money in each month';

  @override
  String get enterpriseCostsEachMonth => 'Costs each month';

  @override
  String get enterpriseWhatIsLeft => 'What is left';

  @override
  String get enterpriseHowFarItSells => 'How far it sells';

  @override
  String get enterpriseBuyersLastMonth => 'Buyers last month';

  @override
  String get enterpriseWrittenAgreementWithBuyer =>
      'Written agreement with a buyer';

  @override
  String get enterpriseNotAsked => 'Not asked';

  @override
  String get enterpriseNotRecorded => 'Not recorded';

  @override
  String get enterpriseYes => 'Yes';

  @override
  String get enterpriseNoInformal => 'No, informal';

  @override
  String get enterpriseYesInWriting => 'Yes, in writing';

  @override
  String get enterpriseUrgent => 'urgent';

  @override
  String get enterpriseNewBusiness => 'New business';

  @override
  String get enterpriseEditBusiness => 'Edit business';

  @override
  String get enterpriseWhatIsItCalled => 'What is it called';

  @override
  String get enterpriseNameHint => 'Poultry unit';

  @override
  String get enterpriseWhereTheySell => 'Where they sell';

  @override
  String get enterpriseWhereTheySellHint =>
      'How far what they make actually travels, and how many people buy it.';

  @override
  String get enterpriseHowFarItReaches => 'How far it reaches';

  @override
  String get enterpriseHowManyBuyersLastMonth => 'How many buyers last month';

  @override
  String get enterpriseHowTheySell => 'How they sell';

  @override
  String get enterpriseIsThereWrittenAgreement =>
      'Is there a written agreement with a buyer';

  @override
  String get enterpriseMonthsTheySellIn => 'Months they sell in';

  @override
  String get enterpriseLeaveBlankIfAllYear =>
      'Leave blank if they sell all year.';

  @override
  String get enterpriseWhatDoesThisBusinessNeed =>
      'What does this business need?';

  @override
  String get enterpriseHowUrgentIsIt => 'How urgent is it?';

  @override
  String get enterpriseAskGroupToRank =>
      'Ask the group how they would rank it.';

  @override
  String get enterpriseAdd => 'Add';

  @override
  String get enterpriseSave => 'Save';

  @override
  String get enterpriseSaving => 'Saving…';

  @override
  String get enterpriseSaved => 'Saved.';

  @override
  String get enterpriseCouldNotLoad =>
      'Could not load. You need a connection for this one.';

  @override
  String get enterpriseCouldNotSave =>
      'Could not save. Check your connection and try again.';

  @override
  String get enterpriseCouldNotSaveNeed =>
      'Could not save that need. Check your connection.';

  @override
  String get enterpriseNameRequired =>
      'Give this business a name so it can be told apart.';

  @override
  String get enterpriseReadingsTaken => 'Times recorded';

  @override
  String get enterpriseRevenueSinceFirst => 'Change since the first visit';

  @override
  String get enterpriseNoBaselineYet => 'Only recorded once so far';

  @override
  String get enterpriseGroupNotYours =>
      'This group is not on your list. Ask your supervisor to assign it.';

  @override
  String get agreedActionsTitle => 'What the group agreed to do';

  @override
  String get agreedActionsNothingYet =>
      'Nothing agreed yet. Whatever you record here is on screen when you or another agent opens the next visit.';

  @override
  String agreedActionsRecordedCount(int count) {
    return '$count recorded at this visit.';
  }

  @override
  String get agreedActionsAgreeAnAction => 'Agree an action';

  @override
  String get agreedActionsReopen => 'Reopen';

  @override
  String get agreedActionsNotYetSent => 'Not yet sent';

  @override
  String get agreedActionsSheetIntro =>
      'Saved on this phone and sent with the visit. The next agent to open this group sees it before they start.';

  @override
  String get agreedActionsWhatWasAgreed => 'What was agreed';

  @override
  String get agreedActionsWhatWasAgreedHint =>
      'Write up the ledger to the last meeting';

  @override
  String get agreedActionsNeedTitle => 'Say what the group agreed to do.';

  @override
  String get agreedActionsWhoIsResponsible => 'Who is responsible';

  @override
  String get agreedActionsSetADate => 'Set a date (optional)';

  @override
  String agreedActionsDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get agreedActionsDetailOptional => 'Detail (optional)';

  @override
  String get agreedActionsAddToThePlan => 'Add to the plan';

  @override
  String get actionOwnerChairperson => 'Chairperson';

  @override
  String get actionOwnerSecretary => 'Secretary';

  @override
  String get actionOwnerTreasurer => 'Treasurer';

  @override
  String get actionOwnerMoneyCounter => 'Money counter';

  @override
  String get actionOwnerKeyHolder => 'Key holder';

  @override
  String get actionOwnerTheGroup => 'The group';

  @override
  String get actionDueToday => 'Due today';

  @override
  String get actionDueTomorrow => 'Due tomorrow';

  @override
  String actionDueInDays(int days) {
    return 'Due in $days days';
  }

  @override
  String actionDaysOverdue(int days) {
    return '$days days overdue';
  }

  @override
  String get actionOneDayOverdue => '1 day overdue';

  @override
  String get actionNoDueDate => 'No date';

  @override
  String get actionDropped => 'Dropped';
}
