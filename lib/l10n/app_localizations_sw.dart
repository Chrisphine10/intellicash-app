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
  String get language => 'Lugha';

  @override
  String get languageSubtitle => 'Chagua lugha ya simu hii';

  @override
  String get languageNeedsReview =>
      'Kila skrini imetafsiriwa, lakini mzungumzaji wa lugha hii bado hajakagua maneno. Kama kitu hakisomeki vizuri, tuambie — unaweza kurudi kwa Kiingereza au Kiswahili wakati wowote.';

  @override
  String get shareTextButton => 'Tuma Maandishi';

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
  String get signOutMemberNote =>
      'Utahitaji kuingia tena ili kuona akiba yako. Nambari yako ya simu itakumbukwa.';

  @override
  String get signOutAgentNote =>
      'Utahitaji kuingia tena ili kuona vikundi vyako. Nambari yako ya simu itakumbukwa.';

  @override
  String get whoIsSigningIn => 'Nani anaingia?';

  @override
  String get whoIsSigningInSubtitle =>
      'Chagua aina ya akaunti unayotumia, kisha weka nambari yako ya simu na nenosiri.';

  @override
  String get welfareRecordThisPayment => 'Rekodi malipo haya?';

  @override
  String get welfareRecordPayment => 'Rekodi malipo';

  @override
  String get welfareWelfareFund => 'Mfuko wa Jamii';

  @override
  String get welfareCouldNotLoadTheWelfare =>
      'Imeshindwa kupakia mfuko wa jamii.';

  @override
  String get welfareTryAgain => 'Jaribu tena';

  @override
  String get welfareLeftInTheWelfareFund => 'Kilichobaki kwenye mfuko wa jamii';

  @override
  String get welfareRecordAWelfarePayment => 'Rekodi malipo ya jamii';

  @override
  String get welfarePaidOutThisCycle => 'Kilicholipwa mzunguko huu';

  @override
  String get welfareNothingPaidOutYetThe =>
      'Hakuna kilicholipwa bado — mfuko wote wa jamii utagawanywa.';

  @override
  String get welfareRecordedInMeeting => 'Imerekodiwa kwenye mkutano';

  @override
  String get welfareAmountKsh => 'Kiasi (KSh)';

  @override
  String get welfareWhatFor => 'Kwa ajili gani';

  @override
  String get welfarePaidTo => 'Amelipwa';

  @override
  String get welfareAMemberAFamilyOr =>
      'Mwanachama, familia au hospitali — yeyote aliyepokea';

  @override
  String get welfareNoteOptional => 'Maelezo (si lazima)';

  @override
  String get meetingHubEditAttendance => 'Badilisha mahudhurio';

  @override
  String get meetingHubCloseLockMeeting => 'Funga na Ufunge Mkutano';

  @override
  String get meetingHubClosingLocksAllRecordsPermanently =>
      'Kufunga hufunga rekodi zote milele.';

  @override
  String get meetingHubKeepOpen => 'Acha Wazi';

  @override
  String get meetingHubCloseLock => 'Funga na Ufunge';

  @override
  String get meetingHubSocialFund => 'Mfuko wa Jamii';

  @override
  String get meetingHubBuyShares => 'Nunua Hisa';

  @override
  String get meetingHubRecordFine => 'Rekodi Faini';

  @override
  String get meetingHubDisburseLoan => 'Toa Mkopo';

  @override
  String get meetingHubRepayment => 'Marejesho';

  @override
  String get meetingHubShareRecords => 'Rekodi za Hisa';

  @override
  String get meetingHubVoting => 'Kupiga Kura';

  @override
  String get meetingHubWelfare => 'Jamii';

  @override
  String get meetingHubIntelliStore => 'Intelli-Store';

  @override
  String get meetingHubExternalLoans => 'Mikopo ya Nje';

  @override
  String get groupSetupWizardAddTheMembersJoiningThis =>
      'Ongeza wanachama wanaojiunga na mzunguko huu. Unaweza kuongeza wengine baadaye.';

  @override
  String get groupSetupWizardEveryoneBuysSharesAtOne =>
      'Kila mtu ananunua hisa kwa bei moja isiyobadilika';

  @override
  String get groupSetupWizardMembersSaveWhatTheyCan =>
      'Wanachama huweka akiba kadri wawezavyo kila mkutano';

  @override
  String get groupSetupWizardGroupName => 'Jina la Kikundi';

  @override
  String get groupSetupWizardCycleNumber => 'Namba ya Mzunguko';

  @override
  String get groupSetupWizardWhichSavingsCycleIsThis =>
      'Kikundi hiki kiko kwenye mzunguko upi wa akiba?';

  @override
  String get groupSetupWizardMemberName => 'Jina la Mwanachama';

  @override
  String get groupSetupWizardAddMember => 'Ongeza mwanachama';

  @override
  String get groupSetupWizardRemove => 'Ondoa';

  @override
  String get groupSetupWizardShareValueKsh => 'Thamani ya Hisa (KSh)';

  @override
  String get groupSetupWizardMaxSharesPerMeeting => 'Hisa za Juu Kila Mkutano';

  @override
  String get groupSetupWizardSocialFundPerMeetingKsh =>
      'Mfuko wa Jamii Kila Mkutano (KSh)';

  @override
  String get groupSetupWizardTrackedSeparatelyFromSavings =>
      'Hufuatiliwa tofauti na akiba';

  @override
  String get groupSetupWizardInterestRatePerMonth => 'Riba (% kwa mwezi)';

  @override
  String get groupSetupWizardMaxLoanMultiplierSavings =>
      'Kikomo cha Mkopo (× akiba)';

  @override
  String get groupSetupWizardDefaultLoanTermMonths =>
      'Muda wa Kawaida wa Mkopo (miezi)';

  @override
  String get groupSyncBackUpToCloud => 'Hifadhi Kwenye Wingu';

  @override
  String get groupSyncUnlinkGroup => 'Ondoa kiungo cha kikundi?';

  @override
  String get groupSyncUnlink => 'Ondoa kiungo';

  @override
  String get groupSyncNotConnected => 'Haijaunganishwa';

  @override
  String get groupSyncOpenServerConnection => 'Fungua Muunganisho wa Seva';

  @override
  String get groupSyncLink => 'Unganisha';

  @override
  String get groupSyncUnlinkGroup2 => 'Ondoa Kiungo cha Kikundi';

  @override
  String get groupSyncNoBackendGroups => 'Hakuna vikundi kwenye seva';

  @override
  String get groupSyncThisApiKeyCannotSee =>
      'Ufunguo huu hauwezi kuona kikundi chochote cha kuunganisha.';

  @override
  String get groupSyncBackendGroup => 'Kikundi kwenye seva';

  @override
  String get createPollStartAVote => 'Anzisha Kura';

  @override
  String get createPollEveryonePresentVotesOnceNobody =>
      'Kila aliyepo hupiga kura mara moja. Hakuna anayeweza kupiga mara mbili.';

  @override
  String get createPollChooseALeader => 'Chagua kiongozi';

  @override
  String get createPollDecideSomething => 'Amua jambo';

  @override
  String get createPollTickAtLeastTwoPeople => 'Chagua angalau watu wawili.';

  @override
  String get createPollAddAnotherAnswer => 'Ongeza jibu lingine';

  @override
  String get createPollSecretVote => 'Kura ya siri';

  @override
  String get createPollOpenTheVote => 'Fungua Kura';

  @override
  String get createPollWhichPosition => 'Nafasi ipi?';

  @override
  String get createPollWhatIsTheQuestion => 'Swali ni lipi?';

  @override
  String get createPollShouldWeBuyAGroup =>
      'Je, tununue tanki la maji la kikundi?';

  @override
  String get paymentProvidersLeaveABoxEmptyTo =>
      'Acha kisanduku wazi ili kubaki na kilichohifadhiwa.';

  @override
  String get paymentProvidersSave => 'Hifadhi';

  @override
  String get paymentProvidersUseThePlatformAccount =>
      'Tumia akaunti ya jukwaa?';

  @override
  String get paymentProvidersPaymentProviders => 'Watoa Huduma za Malipo';

  @override
  String get paymentProvidersUsePlatform => 'Tumia jukwaa';

  @override
  String get storeShopOnCredit => 'Nunua kwa mkopo';

  @override
  String get storeLoanOffersFromLendingPartners =>
      'Mikopo kutoka kwa washirika wa kukopesha — omba kama kikundi.';

  @override
  String get storeSeeAllExternalLoans => 'Ona mikopo yote ya nje';

  @override
  String get storeConnectToBrowseTheStore => 'Unganisha ili kutazama duka';

  @override
  String get storeOpenCloudAccount => 'Fungua Akaunti ya Wingu';

  @override
  String get storeAll => 'Zote';

  @override
  String get storeCouldNotLoadTheStore => 'Imeshindwa kupakia duka';

  @override
  String get storeNoProductsInThisCategory => 'Hakuna bidhaa katika kundi hili';

  @override
  String get storeTryADifferentCategoryOr =>
      'Jaribu kundi lingine au rudi baadaye.';

  @override
  String get pollsNewVote => 'Kura Mpya';

  @override
  String get pollsGroupVotes => 'Kura za kikundi';

  @override
  String get pollsSecret => 'Siri';

  @override
  String get pollsYouHaveVoted => 'Umepiga kura';

  @override
  String get pollsConnectToVote => 'Unganisha ili kupiga kura';

  @override
  String get pollsCouldNotLoadTheVotes => 'Imeshindwa kupakia kura';

  @override
  String get pollsNoVotesYet => 'Hakuna kura bado';

  @override
  String get memberPassbookMyPassbook => 'Kitabu Changu';

  @override
  String get memberPassbookJoinAGroup => 'Jiunge na kikundi';

  @override
  String get memberPassbookMyReport => 'Ripoti yangu';

  @override
  String get memberPassbookMySavingsAcrossAllGroups =>
      'Akiba yangu katika vikundi vyote';

  @override
  String get memberPassbookJoinAnotherGroup => 'Jiunge na kikundi kingine';

  @override
  String get memberPassbookYouAreNotInA => 'Bado hujajiunga na kikundi';

  @override
  String get memberPassbookNoTransactionsYet => 'Hakuna miamala bado';

  @override
  String get memberPassbookYourSavingsAndLoanRecords =>
      'Rekodi za akiba na mikopo yako zitaonekana hapa.';

  @override
  String get joinRequestsDecline => 'Kataa';

  @override
  String get joinRequestsJoinRequests => 'Maombi ya Kujiunga';

  @override
  String get joinRequestsPeopleAskingToJoin => 'Watu wanaoomba kujiunga';

  @override
  String get joinRequestsApprove => 'Kubali';

  @override
  String get joinRequestsReasonOptional => 'Sababu (si lazima)';

  @override
  String get joinRequestsNoOneIsWaiting => 'Hakuna anayesubiri';

  @override
  String get pollDetailCloseThisVote => 'Funga kura hii?';

  @override
  String get pollDetailCloseVote => 'Funga Kura';

  @override
  String get pollDetailVote => 'Piga Kura';

  @override
  String get pollDetailYourChoice => 'Chaguo lako';

  @override
  String get pollDetailNoMembersLoadedForThis =>
      'Hakuna wanachama waliopakiwa kwa kikundi hiki bado.';

  @override
  String get pollDetailMemberCastingThisVote => 'Mwanachama anayepiga kura hii';

  @override
  String get groupPolicyHowLongALoanRuns => 'Mkopo hudumu muda gani';

  @override
  String get groupPolicyInterestCharged => 'Riba inayotozwa';

  @override
  String get groupPolicyExpensesArePaidFrom => 'Gharama hulipwa kutoka';

  @override
  String get groupPolicyRulesThatAreFixed => 'Sheria zisizobadilika';

  @override
  String get productDetailRequestOnCredit => 'Omba kwa Mkopo';

  @override
  String get productDetailQuantity => 'Idadi';

  @override
  String get productDetailSubmitRequest => 'Wasilisha Ombi';

  @override
  String get productDetailPricedAtTheStandardDeposit =>
      'Bei ya amana ya kawaida — kiwango hakipatikani.';

  @override
  String get productDetailProgramme => 'Programu';

  @override
  String get productDetailCustomerName => 'Jina la mteja';

  @override
  String get productDetailEmail => 'Barua pepe';

  @override
  String get productDetailGroupNameOptional => 'Jina la kikundi (si lazima)';

  @override
  String get dashboardHello => 'Habari 👋';

  @override
  String get dashboardTotalSavings => 'Jumla ya Akiba';

  @override
  String get dashboardActiveLoans => 'Mikopo Hai';

  @override
  String get dashboardFinesCollected => 'Faini Zilizokusanywa';

  @override
  String get disburseLoanLoanEligibility => 'Ustahili wa Mkopo';

  @override
  String get disburseLoanSelectMember => 'Chagua Mwanachama';

  @override
  String get disburseLoanPrincipalAmountKsh => 'Kiasi cha Msingi (KSh)';

  @override
  String get disburseLoanDueDate => 'Tarehe ya Mwisho';

  @override
  String get joinGroupRequestSent => 'Ombi limetumwa';

  @override
  String get joinGroupDone => 'Imekamilika';

  @override
  String get joinGroupAskYourGroupToAdd => 'Omba kikundi chako kikuongeze';

  @override
  String get joinGroupSendRequest => 'Tuma ombi';

  @override
  String get joinGroupViewing => 'Unatazama';

  @override
  String get joinGroupGroupCode => 'Msimbo wa kikundi';

  @override
  String get memberDetailEditDetails => 'Badilisha maelezo';

  @override
  String get memberDetailMemberReport => 'Ripoti ya mwanachama';

  @override
  String get memberDetailNoLoansTaken => 'Hakuna mkopo uliochukuliwa';

  @override
  String get memberDetailStartingPassword => 'Nenosiri la kuanzia';

  @override
  String get memberDetailAtLeast6Characters => 'Angalau herufi 6.';

  @override
  String get cyclesCloseCycle => 'Funga mzunguko';

  @override
  String get cyclesSavingCycles => 'Mizunguko ya Akiba';

  @override
  String get cyclesCloseCycleAndStartThe => 'Funga mzunguko na uanze ujao';

  @override
  String get cyclesReadOnlyStillVisibleIn =>
      'Kusoma tu — bado inaonekana kwenye ripoti';

  @override
  String get externalLoansCreditVentures => 'Miradi ya mkopo';

  @override
  String get externalLoansConnectToSeeLoanOffers =>
      'Unganisha ili kuona mikopo iliyopo';

  @override
  String get externalLoansCouldNotLoadLoanOffers =>
      'Imeshindwa kupakia mikopo iliyopo';

  @override
  String get externalLoansNoLoanOffersRightNow => 'Hakuna mkopo kwa sasa';

  @override
  String get accountAccount => 'Akaunti';

  @override
  String get accountServer => 'Seva';

  @override
  String get accountAppVersion => 'Toleo la programu';

  @override
  String get accountPhone => 'Simu';

  @override
  String get businessProfileGroupBusiness => 'Biashara ya kikundi';

  @override
  String get businessProfileWhatDoesTheGroupRun =>
      'Kikundi kinaendesha biashara gani pamoja?';

  @override
  String get businessProfileTypeOfBusiness => 'Aina ya biashara';

  @override
  String get businessProfileEGPoultryCerealBuying =>
      'mfano: kuku, ununuzi wa nafaka';

  @override
  String get businessProfileMoneyInEachMonthKes => 'Mapato kila mwezi (KES)';

  @override
  String get businessProfileCostsEachMonthKes => 'Gharama kila mwezi (KES)';

  @override
  String get businessProfilePeopleItEmploys => 'Watu inaowaajiri';

  @override
  String get businessProfileBiggestProblemTheyFace =>
      'Tatizo kubwa wanalokabiliana nalo';

  @override
  String get recordVisitSettings => 'Mipangilio';

  @override
  String get recordVisitScoreTheGroup => 'Pima kikundi';

  @override
  String get recordVisitTheGroupSEnterprise => 'Biashara ya kikundi';

  @override
  String get recordVisitWhatTheyRunTogetherAnd =>
      'Wanachoendesha pamoja, na kinavyokwenda.';

  @override
  String get recordVisitSavedOnThisPhoneFirst =>
      'Huhifadhiwa kwenye simu hii kwanza, kisha hutumwa ukipata mtandao.';

  @override
  String get recordVisitWhyNotOptional => 'Kwa nini hapana? (si lazima)';

  @override
  String get recordVisitWhatYouFound => 'Uliyoyakuta';

  @override
  String get agentHomeMyGroups => 'Vikundi Vyangu';

  @override
  String get agentHomeCaseloadReport => 'Ripoti ya vikundi';

  @override
  String get agentHomeNoGroupsAssigned => 'Hakuna kikundi ulichopewa';

  @override
  String get agentHomeGroups => 'Vikundi';

  @override
  String get agentHomeNeedSupport => 'Vinahitaji msaada';

  @override
  String get loansLoanPortfolio => 'Jalada la Mikopo';

  @override
  String get loansActive => 'Hai';

  @override
  String get loansSearchByMemberName => 'Tafuta kwa jina la mwanachama';

  @override
  String get loansNoLoansHere => 'Hakuna mikopo hapa';

  @override
  String get threeKeyUnlockUnlockMeeting => 'Fungua Mkutano';

  @override
  String get threeKeyUnlockVerified => 'Imethibitishwa';

  @override
  String get threeKeyUnlockSendANewCode => 'Tuma msimbo mpya';

  @override
  String get threeKeyUnlockNoSmsUseMySaved =>
      'Hakuna SMS? Tumia PIN yangu iliyohifadhiwa';

  @override
  String get threeKeyUnlockOneTimeCode => 'Msimbo wa mara moja';

  @override
  String get threeKeyUnlockRepeatPin => 'Rudia PIN';

  @override
  String get memberReportMyReport => 'Ripoti Yangu';

  @override
  String get memberReportShare => 'Shiriki';

  @override
  String get memberReportNotSignedIn => 'Hujaingia';

  @override
  String get memberReportSignInToYourAccount =>
      'Ingia kwenye akaunti yako ili kuona na kushiriki ripoti yako.';

  @override
  String get cloudDashboardCloudData => 'Data ya Wingu';

  @override
  String get cloudDashboardRefresh => 'Onyesha upya';

  @override
  String get cloudDashboardSavingsFund => 'Mfuko wa Akiba';

  @override
  String get cloudDashboardInternalLoans => 'Mikopo ya Ndani';

  @override
  String get serverSettingsOrUseAGroupAccess => 'au tumia ufunguo wa kikundi';

  @override
  String get serverSettingsViewOnlineRecords => 'Ona Rekodi za Mtandaoni';

  @override
  String get serverSettingsBackUpThisGroup => 'Hifadhi Kikundi Hiki';

  @override
  String get serverSettingsAccessKey => 'Ufunguo wa kuingia';

  @override
  String get shareOutDistribute => 'Gawanya';

  @override
  String get shareOutFundToDistribute => 'Mfuko wa kugawanya';

  @override
  String get shareOutSplitWelfareFundEqually => 'Gawanya mfuko wa jamii sawa';

  @override
  String get shareOutNothingToShareOutYet => 'Hakuna cha kugawanya bado';

  @override
  String get visitAssessmentAssessment => 'Tathmini';

  @override
  String get visitAssessmentFormNotAvailable => 'Fomu haipatikani';

  @override
  String get visitMentorshipMentorship => 'Ushauri';

  @override
  String get visitMentorshipWhatDidYouCoachOn => 'Ulifundisha nini?';

  @override
  String get visitMentorshipTapATopicToRecord =>
      'Gusa mada ili kuirekodi, kisha andika ulichoshauri.';

  @override
  String get visitMentorshipNowHandThePhoneTo => 'Sasa mpe kikundi simu';

  @override
  String get visitMentorshipWhatYouAdvised => 'Ulichoshauri';

  @override
  String get agentGroupDetailRecordAVisit => 'Rekodi ziara';

  @override
  String get agentGroupDetailNoMembersLoaded => 'Hakuna wanachama waliopakiwa.';

  @override
  String get agentGroupDetailNoMeetingsLoaded => 'Hakuna mikutano iliyopakiwa.';

  @override
  String get agentGroupDetailToImprove => 'Ya kuboresha';

  @override
  String get agentGroupDetailGovernance => 'Uongozi';

  @override
  String get agentGroupDetailVslaCompliance => 'Ufuataji wa kanuni za VSLA';

  @override
  String get recordFineReason => 'Sababu';

  @override
  String get recordFineSpecifyReason => 'Eleza sababu';

  @override
  String get addMemberAddMember => 'Ongeza Mwanachama';

  @override
  String get addMemberRegisterMember => 'Sajili Mwanachama';

  @override
  String get addMemberFullName => 'Jina Kamili';

  @override
  String get addMemberPhoneOptional => 'Simu (si lazima)';

  @override
  String get addMemberRole => 'Nafasi';

  @override
  String get editMemberEditMember => 'Badilisha mwanachama';

  @override
  String get editMemberFullName => 'Jina kamili';

  @override
  String get membersRequestsToJoin => 'Maombi ya kujiunga';

  @override
  String get membersSearchMembers => 'Tafuta wanachama';

  @override
  String get membersNoMembersFound => 'Hakuna mwanachama aliyepatikana';

  @override
  String get meetingSecurity3KeyUnlockBeforeMeetings =>
      'Funguo 3 kabla ya mikutano';

  @override
  String get meetingSecurityKeepPin => 'Baki na PIN';

  @override
  String get meetingSecurityReset => 'Weka upya';

  @override
  String get agentReportCaseloadReport => 'Ripoti ya Vikundi';

  @override
  String get agentReportShareReport => 'Shiriki Ripoti';

  @override
  String get agentReportNeedsSupport => 'Kinahitaji msaada';

  @override
  String get agentReportNoRating => 'Hakuna kiwango';

  @override
  String get agentReportNoGroupsYet => 'Hakuna vikundi bado';

  @override
  String get groupReportNoGroupYet => 'Hakuna kikundi bado';

  @override
  String get groupReportSetUpYourGroupFirst =>
      'Sajili kikundi chako kwanza, kisha urudi kwa ripoti.';

  @override
  String get groupReportNoMembersYet => 'Hakuna wanachama bado';

  @override
  String get groupReportMembersAppearHereOnceThey =>
      'Wanachama huonekana hapa wanapojiunga na kikundi.';

  @override
  String get memberReportLocalMemberReport => 'Ripoti ya Mwanachama';

  @override
  String get memberReportLocalMemberNotFound => 'Mwanachama hakupatikana';

  @override
  String get memberReportLocalThisMemberIsNoLonger =>
      'Mwanachama huyu hayupo tena kwenye kikundi.';

  @override
  String get memberReportLocalLoansThisMemberTakesWill =>
      'Mikopo atakayochukua mwanachama huyu itaonekana hapa.';

  @override
  String get externalLoanApplyApplyForALoan => 'Omba Mkopo';

  @override
  String get externalLoanApplySubmitApplication => 'Wasilisha Ombi';

  @override
  String get externalLoanApplyWhatIsTheLoanFor => 'Mkopo ni wa nini?';

  @override
  String get externalLoanApplyEGBuyingMaizeSeed =>
      'mfano: kununua mbegu za mahindi kwa msimu';

  @override
  String get meetingsNoMeetingsYet => 'Hakuna mikutano bado';

  @override
  String get repaymentRecordRepayment => 'Rekodi Marejesho';

  @override
  String get repaymentNoOutstandingLoansNothingTo =>
      'Hakuna mkopo unaodaiwa — hakuna cha kurejesha. 🎉';

  @override
  String get repaymentSelectLoan => 'Chagua Mkopo';

  @override
  String get moreWhoIsSignedInLanguage =>
      'Aliyeingia, lugha, mwonekano na maelezo ya programu';

  @override
  String get moreIntelliCash => 'Intelli-Cash';

  @override
  String get mySavingsMySavings => 'Akiba Yangu';

  @override
  String get mySavingsOnceAGroupAcceptsYou =>
      'Kikundi kikikukubali, akiba yako itaonekana hapa.';

  @override
  String get buySharesEnterCodeByHand => 'Weka Msimbo kwa Mkono';

  @override
  String get buySharesRecordPurchase => 'Rekodi Ununuzi';

  @override
  String get sharesLedgerNoPurchasesYet => 'Hakuna ununuzi bado';

  @override
  String get socialFundThisMeetingIsClosedThe =>
      'Mkutano huu umefungwa — rekodi ni ya kusoma tu.';

  @override
  String get socialFundNoMembers => 'Hakuna wanachama';

  @override
  String get socialFundAddMembersToTheGroup =>
      'Ongeza wanachama kwenye kikundi kwanza.';

  @override
  String get welcomeUseTheWebConsoleFor => 'Tumia tovuti kwa akaunti hii';

  @override
  String get welcomeLoadYourGroupOntoThis =>
      'Pakia kikundi chako kwenye simu hii';

  @override
  String get memberReportsTapAMemberToSee =>
      'Gusa mwanachama ili kuona na kushiriki ripoti yake.';

  @override
  String get openActionItemsNothingOutstanding => 'Hakuna lililobaki';

  @override
  String get openActionItemsThisGroupHasNoOpen =>
      'Kikundi hiki hakina kazi zilizobaki kutoka ziara zilizopita.';

  @override
  String get openActionItemsFromTheLastVisit => 'Kutoka ziara iliyopita';

  @override
  String get loanDetailNoRepaymentsYet => 'Hakuna marejesho bado';

  @override
  String get attendanceAttendance => 'Mahudhurio';

  @override
  String get attendanceContinueToMeeting => 'Endelea kwenye Mkutano';

  @override
  String get appearanceChooseHowIntelliCashLooks =>
      'Chagua jinsi Intelli-Cash inavyoonekana kwenye simu hii.';

  @override
  String get gatewayPaymentOpenThisLinkToPay => 'Fungua kiungo hiki kulipa:';

  @override
  String get numericKeypadDelete => 'Futa';

  @override
  String get agentHomeWhenGroupsAreAssignedToYou =>
      'Vikundi vikikabidhiwa kwako, vitaonekana hapa pamoja na kiwango chao cha mkopo.';

  @override
  String get dashboardTheSavingsCurveAppearsAfterYour =>
      'Mchoro wa akiba huonekana baada ya mikutano yako miwili ya kwanza.';

  @override
  String get disburseLoanThisMemberHasNoBorrowingHeadroom =>
      'Mwanachama huyu hana nafasi ya kukopa — akiba lazima iongezeke au mkopo wa sasa upungue kwanza.';

  @override
  String get disburseLoanTheLoanFundIsEmptyCollect =>
      'Mfuko wa mikopo ni tupu. Kusanya ununuzi wa hisa au marejesho ya mikopo kabla ya kukopesha tena.';

  @override
  String get loanDetailRepaymentsAreRecordedInsideMeetingsAnd =>
      'Marejesho hurekodiwa ndani ya mikutano na huonekana hapa mara moja.';

  @override
  String get loansLoansAreDisbursedInsideAMeeting =>
      'Mikopo hutolewa ndani ya mkutano — fungua mkutano kisha tumia Toa Mkopo.';

  @override
  String get gatewayPaymentRequestSentAskTheMemberTo =>
      'Ombi limetumwa. Mwambie mwanachama aweke PIN yake ya M-Pesa kwenye simu yake.';

  @override
  String get meetingHubThisMeetingIsClosedItsRecords =>
      'Mkutano huu umefungwa. Rekodi zake ni za kusoma tu na ni sehemu ya kumbukumbu za ukaguzi.';

  @override
  String get meetingHubAllRecordsInThisMeetingWill =>
      'Rekodi zote za mkutano huu zitafungwa milele. Hili haliwezi kutenguliwa.';

  @override
  String get meetings3KeyUnlockIsOnOfficials =>
      'Funguo 3 zimewashwa: viongozi huthibitisha PIN zao kabla mkutano kufunguliwa.';

  @override
  String get meetingsStartYourFirstMeetingToRecord =>
      'Anzisha mkutano wako wa kwanza ili kurekodi mahudhurio, akiba, faini na mikopo.';

  @override
  String get meetingsClosedMeetingsAreLockedTheirRecords =>
      'Mikutano iliyofungwa imefungwa — rekodi zake ni kumbukumbu za kudumu za kikundi.';

  @override
  String get sharesLedgerSharePurchasesLandHereTheMoment =>
      'Ununuzi wa hisa huonekana hapa mara tu unaporekodiwa.';

  @override
  String get joinGroupYourGroupHasACodeOn =>
      'Kikundi chako kina msimbo kwenye rekodi zake — muulize katibu kama hukijui. Kutuma ombi hakukufungulii vitabu vya kikundi; kiongozi lazima akukubali kwanza.';

  @override
  String get memberPassbookAskYourGroupToAddYou =>
      'Omba kikundi chako kikuongeze na akiba yako itaonekana hapa.';

  @override
  String get editMemberCorrectingASpellingOrAMistyped =>
      'Kurekebisha herufi au namba iliyokosewa. Akiba, mikopo na mahudhurio yao hubaki kama yalivyo.';

  @override
  String get joinRequestsTheyWillNotBeAddedTo =>
      'Hataongezwa kwenye kikundi. Unaweza kueleza sababu ukitaka — si lazima.';

  @override
  String get joinRequestsThisListIsOutOfDate =>
      'Orodha hii si ya sasa. Vuta chini ili kuonyesha upya, kisha angalia jibu tena.';

  @override
  String get joinRequestsWhenSomeoneAsksToJoinYour =>
      'Mtu akiomba kujiunga na kikundi chako, ombi lake litaonekana hapa ili ulijibu.';

  @override
  String get memberDetailToCreateASignInAccount =>
      'Ili kutengeneza akaunti ya kuingia, kwanza hifadhi kikundi hiki kwenye wingu (Mangine → Sync & Backup) ukiwa mtandaoni.';

  @override
  String get memberDetailLoansThisMemberTakesWillBe =>
      'Mikopo atakayochukua mwanachama huyu itaorodheshwa hapa na hali yake ya sasa.';

  @override
  String get membersAddMembersWithTheButtonBelow =>
      'Ongeza wanachama kwa kitufe kilicho chini — kila mmoja hupata rekodi yake ya akiba na mikopo.';

  @override
  String get meetingSecurityAssignAChairpersonSecretaryAndTreasurer =>
      'Teua mwenyekiti, katibu na mweka hazina hapa chini ili viongozi watatu waweze kufungua mikutano. Hadi hapo, PIN za wanachama wengi ndizo zitahitajika.';

  @override
  String get meetingSecurityTheOldPinStopsWorkingThe =>
      'PIN ya zamani huacha kufanya kazi. Mwanachama huchagua PIN mpya wakati mwingine atakapotumia ufunguo wake kufungua mkutano.';

  @override
  String get moreYourGroupSSavingsAndLoans =>
      'Akiba na mikopo ya kikundi chako, hapo hapo kwenye simu yako. Kila kitu huhifadhiwa kwenye simu hii kwanza, kisha hufanyiwa nakala mtandaoni ukipata intaneti.\n\nIntelli-Wealth Limited · intelliwealth.org';

  @override
  String get moreNoInternetYourRecordsAreSafe =>
      'Hakuna intaneti — rekodi zako ziko salama kwenye simu hii na zitahifadhiwa baadaye.';

  @override
  String get welcomeThePhoneAppIsForGroups =>
      'Programu ya simu ni ya vikundi, wanachama na maafisa wa uwandani. Akaunti yako haihitaji kuunda kikundi hapa — ingia kwenye tovuti badala yake, au toka ili kutumia akaunti nyingine.';

  @override
  String get welcomeYourGroupIsAlreadyOnThe =>
      'Kikundi chako tayari kiko kwenye seva. Kipakie hapa badala ya kuunda kipya, ili historia ya akiba yako ibaki rekodi moja.';

  @override
  String get agentReportWhenGroupsAreAssignedToYou =>
      'Vikundi vikikabidhiwa kwako, ripoti yake itaonekana hapa.';

  @override
  String get groupReportFiguresFromThisPhoneOnlyWork =>
      'Takwimu za simu hii pekee - kazi iliyohifadhiwa kwenye simu nyingine huenda bado haijajumuishwa.';

  @override
  String get groupReportFromThisPhoneOnlyWorkSaved =>
      'Kutoka simu hii pekee. Kazi iliyohifadhiwa kwenye simu nyingine huenda bado haijajumuishwa.';

  @override
  String get memberReportLocalFiguresFromThisPhoneOnlyRecords =>
      'Takwimu za simu hii pekee - rekodi zilizohifadhiwa kwingine huenda bado hazijajumuishwa.';

  @override
  String get mySavingsWhatYouOweIsCountedFor =>
      'Deni lako huhesabiwa kwa kila kikundi peke yake. Kulipa zaidi katika kikundi kimoja hakupunguzi deni lako katika kingine.';

  @override
  String get groupSyncThisClearsTheLocalBackendMapping =>
      'Hii huondoa uhusiano kati ya simu na seva. Rekodi zilizokwisha sawazishwa hubaki kwenye seva; hakuna kinachofutwa.';

  @override
  String get groupSyncConnectToTheIntellicashBackendBefore =>
      'Unganisha kwenye seva ya IntelliCash kabla ya kuunganisha na kusawazisha kikundi hiki.';

  @override
  String get groupSyncLinkingMatchesYourLocalMembersTo =>
      'Kuunganisha hulinganisha wanachama wa simu hii na orodha ya seva kwa namba ya simu, kisha kwa jina. Wasiolingana wanaweza kuunganishwa kwa mkono baadaye.';

  @override
  String get groupSyncTheseLocalMembersHaveNoBackend =>
      'Wanachama hawa wa simu hii hawana wenzao kwenye seva. Waunganishe kabla miamala yao haijaweza kusawazishwa.';

  @override
  String get groupSyncUploadsAttendanceAndLedgerSharesSocial =>
      'Hupakia mahudhurio na daftari (hisa, mfuko wa jamii, mikopo, marejesho) kwa kila mkutano uliofungwa. Ni salama kurudia — rekodi zilizokwisha sawazishwa huachwa. Faini na kufunga mikutano huja katika hatua ijayo.';

  @override
  String get serverSettingsAskYourGroupAdministratorForAn =>
      'Omba msimamizi wa kikundi chako ufunguo wa kuingia, kisha ubandike hapa. Unaruhusu simu hii kuona na kurekodi akiba, mikopo na mikutano ya kikundi chako tu.';

  @override
  String get cyclesPullDownToTryAgainIf =>
      'Vuta chini ujaribu tena. Ikiendelea, hakikisha kikundi bado kimechaguliwa chini ya Akaunti ya Wingu.';

  @override
  String get cyclesClosingACycleMakesItsRecords =>
      'Kufunga mzunguko hufanya rekodi zake ziwe za kusoma tu. Hakuna kinachofutwa — mikutano na fedha zilizopita hubaki kwenye historia na ripoti.';

  @override
  String get cyclesYouCanSeeTheCyclesBut =>
      'Unaweza kuona mizunguko lakini huwezi kufunga. Ni akaunti ya kikundi au msimamizi wa jukwaa pekee anayeweza.';

  @override
  String get groupPolicyAppliesToNewLoansLoansAlready =>
      'Hutumika kwa mikopo mipya. Mikopo iliyokwisha tolewa hubaki na muda iliokubaliwa — kubadilisha hili hakubadilishi deni la mwanachama.';

  @override
  String get groupPolicyFlatOnTheAmountBorrowedEach =>
      'Ni kiwango kimoja juu ya kiasi kilichokopwa kila mwezi — hakipungui mwanachama anapolipa, na huisha mwisho wa muda uliokubaliwa. Sifuri ni sawa: vikundi vingi hukopesha bila riba. Kila mkopo hubaki na riba uliotolewa nayo, kwa hivyo kubadilisha hili hakubadilishi fedha zilizokwisha kopeshwa.';

  @override
  String get groupPolicyYouCanSeeTheseRulesBut =>
      'Unaweza kuona sheria hizi lakini huwezi kuzibadilisha. Ni akaunti ya kikundi au msimamizi wa jukwaa pekee anayeweza.';

  @override
  String get groupPolicyUnpaidFinesAndWelfareAreTaken =>
      'Faini na michango ya jamii ambayo haijalipwa hukatwa kwenye mgao wa mwanachama — kamwe hazimzuii mwanachama kushiriki mgao.\n\nMikopo ambayo haijalipwa hukatwa wakati wa mgao na kamwe haipelekwi mzunguko unaofuata.';

  @override
  String get paymentProvidersMPesaClassicNeedsNothingHere =>
      'M-Pesa Classic haihitaji chochote hapa — mwanachama huandika msimbo wa muamala kutoka simu yake.';

  @override
  String get paymentProvidersYouCanSeeThisButNot =>
      'Unaweza kuona hili lakini huwezi kulibadilisha. Ni akaunti ya kikundi au msimamizi wa jukwaa pekee anayeweza kuhamisha mahali fedha zinapopokelewa.';

  @override
  String get welfareYouAreOfflineWelfarePaymentsAre =>
      'Huna mtandao. Malipo ya jamii hurekodiwa kwenye seva ili mfuko usitumike kupita kiasi na simu mbili kwa wakati mmoja — unganisha ili kurekodi.';

  @override
  String get welfareNoMeetingIsOpenWelfareIs =>
      'Hakuna mkutano ulio wazi. Fedha za jamii hulipwa wakati wa mkutano, mbele ya wanachama — fungua mkutano kwanza, kisha rekodi hapo.';

  @override
  String get shareOutMembersHavenTBoughtSharesThis =>
      'Wanachama hawajanunua hisa mzunguko huu. Endesha mikutano na kusanya hisa kwanza, kisha urudi kugawanya mfuko.';

  @override
  String get externalLoanApplyCreditRatingUnavailableTheLenderChecks =>
      'Kiwango cha mkopo hakipatikani — mkopeshaji hukiangalia anapopitia ombi lako.';

  @override
  String get externalLoansCheckBackLaterPartnersAddNew =>
      'Rudi baadaye — washirika huongeza mikopo mipya mara kwa mara.';

  @override
  String get externalLoansExternalLoansLoadFromTheIntelli =>
      'Mikopo ya nje hupakiwa kutoka seva ya Intelli-Cash. Unganisha au ingia kwanza.';

  @override
  String get storeFarmSolarHouseholdAndBusinessProducts =>
      'Bidhaa za shamba, sola, nyumbani na biashara — bei kulingana na kiwango cha mkopo cha kikundi chako.';

  @override
  String get storeIntelliStoresLoadsFromTheIntelli =>
      'Intelli-Stores hupakiwa kutoka seva ya Intelli-Cash. Unganisha au ingia kwanza.';

  @override
  String get businessProfileTheGroupSOwnEnterpriseNot =>
      'Biashara ya kikundi chenyewe, si ya mwanachama. Acha wazi kama hawana.';

  @override
  String get businessProfileThisVisitHasNotSyncedYet =>
      'Ziara hii bado haijasawazishwa, kwa hivyo takwimu zimehifadhiwa kwa kikundi lakini si kwa ziara hii.';

  @override
  String get businessProfileSavedAgainstThisVisitSoNext =>
      'Imehifadhiwa kwa ziara hii, ili wakati ujao uone kilichobadilika.';

  @override
  String get recordVisitAVisitCanStillBeRecorded =>
      'Ziara bado inaweza kurekodiwa bila mahali. Kama inalingana na kikundi hiki huamuliwa na ofisi, si hapa.';

  @override
  String get recordVisitRecordWhatYouCoachedOnThen =>
      'Rekodi ulichofundisha, kisha waache kikundi kikipime.';

  @override
  String get visitAssessmentNoAssessmentFormHasBeenDownloaded =>
      'Hakuna fomu ya tathmini iliyopakuliwa bado. Unganisha mara moja ili kuipata, kisha itafanya kazi bila mtandao.';

  @override
  String get visitMentorshipNotScoredYetAVisitCan =>
      'Bado haijapimwa. Ziara inaweza kurekodiwa bila hii, lakini maoni ya kikundi ndiyo kipimo pekee muhimu cha ushauri.';

  @override
  String get createPollNoMembersLoadedForThisGroup =>
      'Hakuna wanachama waliopakiwa kwa kikundi hiki bado. Unganisha na ufungue kikundi kwanza.';

  @override
  String get createPollNobodySeesWhoVotedForWhat =>
      'Hakuna anayeona nani alipiga kura kwa nini. Idadi bado huonyeshwa kwa kila mtu.';

  @override
  String get pollDetailNoMoreVotesCanBeCast =>
      'Hakuna kura zaidi zitakazopigwa baada ya hii, na matokeo huandikwa kwenye rekodi za kikundi. Hili haliwezi kutenguliwa.';

  @override
  String get pollDetailClosingCountsTheVotesAndWrites =>
      'Kufunga huhesabu kura na kuandika matokeo kwenye rekodi za kikundi.';

  @override
  String get pollDetailYouHaveVotedThisIsA =>
      'Umepiga kura. Hii ni kura ya siri, kwa hivyo chaguo lako halionyeshwi kwa mtu yeyote.';

  @override
  String get pollsElectYourLeadersAndDecideTogether =>
      'Chagua viongozi wenu na muamue pamoja. Mwanachama mmoja, kura moja.';

  @override
  String get pollsTapNewVoteToElectA =>
      'Gusa Kura Mpya ili kuchagua kiongozi au kuuliza kikundi swali.';

  @override
  String get pollsVotingIsKeptOnTheIntelli =>
      'Kura huhifadhiwa kwenye seva ya Intelli-Cash ili kila mwanachama aone idadi ile ile. Unganisha au ingia kwanza.';

  @override
  String unlockOpensWhen(int officials, int members) {
    return 'Mkutano hufunguliwa viongozi $officials — au wanachama $members — wanapotumia funguo zao.';
  }

  @override
  String paymentProvidersStillNeeded(String fields) {
    return 'Haijakamilika — bado inahitajika: $fields. Hadi hapo fedha bado huenda kwenye akaunti ya jukwaa.';
  }

  @override
  String welfareSharedOutExplainer(String paidOut) {
    return 'Hiki ndicho kitakachogawanywa mwisho wa mzunguko — si jumla iliyochangwa. $paidOut imelipwa hadi sasa.';
  }

  @override
  String shareOutStartsNextCycle(int cycle) {
    return 'Hii hurekodi kila malipo, humaliza mikopo iliyobaki, na huanzisha Mzunguko $cycle. Haiwezi kutenguliwa.';
  }

  @override
  String visitAssessmentPhotoCapReached(int max) {
    return 'Ziara hii tayari ina picha $max.';
  }

  @override
  String get languageDraftBadge => 'rasimu';
}
