// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kikuyu Gikuyu (`ki`).
class L10nKi extends L10n {
  L10nKi([String locale = 'ki']) : super(locale);

  @override
  String get appTagline => 'VSLA yaku mũthithũ-inĩ waku';

  @override
  String get navDashboard => 'Mũhũthũ';

  @override
  String get navMeetings => 'Mĩcemanio';

  @override
  String get navMembers => 'Amemba';

  @override
  String get navLoans => 'Mĩkopo';

  @override
  String get navMore => 'Mangĩ';

  @override
  String get welcomeTitle => 'Wamũkĩro Intelli-Cash';

  @override
  String get welcomeCreateAccountPrompt =>
      'Ambĩrĩria na gũthondeka akaũnti yaku.';

  @override
  String get welcomeAccountReady => 'Akaũnti yaku nĩ yehaarĩirie.';

  @override
  String get createAccount => 'Thondeka Akaũnti';

  @override
  String get createAccountSubtitle =>
      'Nĩ mbere yaku? Thondeka akaũnti ya gĩkundi kĩanyu, yaku we mwene, kana ya wĩra waku ta mũrũgamĩrĩri.';

  @override
  String get signIn => 'Toonya';

  @override
  String get signInSubtitle => 'Ndĩ na akaũnti ya Intelli-Cash.';

  @override
  String get signOut => 'Uma';

  @override
  String signedInAs(String name) {
    return 'Wĩtoonyetie ta $name.';
  }

  @override
  String get setUpGroup => 'Thondeka gĩkundi gĩakwa thimũ-inĩ ĩno';

  @override
  String get setUpGroupSubtitle =>
      'Iga ũigi, mĩkopo na mĩcemanio ya gĩkundi kĩanyu — nĩ ĩrutaga wĩra o na hatarĩ ĩntaneti.';

  @override
  String get whoIsThisAccountFor => 'Akaũnti ĩno nĩ ya ũ?';

  @override
  String get pickOneLater => 'Thuura ĩmwe — no wongerere ingĩ thutha-inĩ.';

  @override
  String get accountTypeGroup => 'Gĩkundi Gĩitũ';

  @override
  String get accountTypeGroupSubtitle =>
      'Thimũ ĩno nĩyo ĩkũiga ũigi, mĩkopo na mĩcemanio ya gĩkundi gĩitũ.';

  @override
  String get accountTypeMember => 'Niĩ Nyiki';

  @override
  String get accountTypeMemberSubtitle =>
      'Nĩngwenda kuona ũigi, hisa na mĩkopo yakwa.';

  @override
  String get accountTypeAgent => 'Mũrũgamĩrĩri wa Mũgũnda';

  @override
  String get accountTypeAgentSubtitle =>
      'Mũrũgamĩrĩri wa Itũũra kana CBT — nĩndeithagia na ngarora ikundi nyingĩ.';

  @override
  String get change => 'Garũra';

  @override
  String get groupNameLabel => 'Rĩĩtwa rĩa gĩkundi';

  @override
  String get yourFullName => 'Rĩĩtwa rĩaku rĩothe';

  @override
  String get phoneNumber => 'Namba ya thimũ';

  @override
  String get password => 'Kĩhithe';

  @override
  String get passwordHint => 'Ndemwa 6 kana nyingĩ — kĩige kĩrĩ kĩhithe.';

  @override
  String get repeatPassword => 'Cookera kĩhithe';

  @override
  String get emailOptional => 'Barũa ya ĩntaneti (ti bata)';

  @override
  String get countyOptional => 'Kaũnti (ti bata)';

  @override
  String get createMyAccount => 'Thondeka Akaũnti Yakwa';

  @override
  String get creatingAccount => 'Nĩgũthondekwo akaũnti…';

  @override
  String get registerNeedsInternet =>
      'Gũthondeka akaũnti nĩkũbataraga ĩntaneti. Namba yaku ya thimũ nĩyo ũkũhũthĩra gũtoonya.';

  @override
  String get welcomeBack => 'Wamũkĩro rĩngĩ';

  @override
  String get signInWithPhone => 'Toonya na namba yaku ya thimũ na kĩhithe.';

  @override
  String get phoneOrEmail => 'Namba ya thimũ kana barũa ya ĩntaneti';

  @override
  String get signingIn => 'Nĩgũtoonywo…';

  @override
  String get sessionNote =>
      'Mahinda maku nĩ mathaa 8. Ibuku rĩa gĩkundi rĩthiaga na mbere kũruta wĩra o na hatarĩ ĩntaneti waarĩkia gũtoonya.';

  @override
  String get sectionGroup => 'Gĩkundi';

  @override
  String get sectionReports => 'Ripoti';

  @override
  String get sectionEndOfCycle => 'Mũthia wa mũthiũrũrũko';

  @override
  String get sectionCloudBackup => 'Matu na kũiga';

  @override
  String get sectionAppearance => 'Mũonekere';

  @override
  String get sectionLanguage => 'Rũthiomi';

  @override
  String get sectionAbout => 'Ũhoro';

  @override
  String get groupSettings => 'Mĩbango ya Gĩkundi';

  @override
  String get groupSettingsSubtitle => 'Ũigi, mĩkopo na mĩthenya ya mĩcemanio';

  @override
  String get meetingSecurity => 'Ũgitĩri wa Mũcemanio';

  @override
  String get memberAccounts => 'Akaũnti cia Amemba';

  @override
  String get memberAccountsSubtitle =>
      'Rekereria amemba magĩe na akaũnti ciao mone ũigi wao';

  @override
  String get groupRules => 'Mawatho ma Gĩkundi';

  @override
  String get groupReport => 'Ripoti ya Gĩkundi';

  @override
  String get groupReportSubtitle =>
      'Mbeca, amemba na mĩcemanio — tũma maandĩko kana PDF';

  @override
  String get memberReports => 'Ripoti cia Amemba';

  @override
  String get memberReportsSubtitle =>
      'Ũhoro wa o mũmemba — tũma maandĩko kana PDF';

  @override
  String get shareOut => 'Kũgayana';

  @override
  String get shareOutSubtitle => 'Gaĩra amemba mbeca cia gĩkundi';

  @override
  String get cloudAccount => 'Akaũnti ya Matu';

  @override
  String get syncBackup => 'Kũiganania na Kũiga';

  @override
  String get intelliStores => 'Intelli-Stores';

  @override
  String get language => 'Rũthiomi';

  @override
  String get languageSubtitle => 'Thuura rũthiomi rwa thimũ ĩno';

  @override
  String get languageNeedsReview =>
      'Ithangũ o rĩothe nĩrĩataũrwo, no mũndũ ũaragia rũthiomi rũrũ ndarĩ arorire ciugo. Kũngĩkorũo harĩ ũndũ ũtathomeka wega, tũmenyithie — no ũcooke Gĩthungũ kana Gĩthwahili hĩndĩ o yothe.';

  @override
  String get shareTextButton => 'Tũma Maandĩko';

  @override
  String get back => 'Cooka';

  @override
  String get cancel => 'Tiga';

  @override
  String get signedOut => 'Nĩwoima.';

  @override
  String get signOutKeepsRecords =>
      'Ũigi, mĩkopo na mĩcemanio ya gĩkundi kĩanyu ĩgũtigwo ĩigĩtwo thimũ-inĩ ĩno, no gũtirĩ mũndũ ũngĩmĩhingũra ũtatoonyete rĩngĩ. Namba yaku ya thimũ nĩĩkũririkanwo.';

  @override
  String get signOutMemberNote =>
      'Nĩũkabatara gũtoonya rĩngĩ nĩguo wone ũigi waku. Namba yaku ya thimũ nĩĩkũririkanwo.';

  @override
  String get signOutAgentNote =>
      'Nĩũkabatara gũtoonya rĩngĩ nĩguo wone ikundi ciaku. Namba yaku ya thimũ nĩĩkũririkanwo.';

  @override
  String get whoIsSigningIn => 'Nũũ ũratoonya?';

  @override
  String get whoIsSigningInSubtitle =>
      'Thuura mũthemba wa akaũnti ũrahũthĩra, ũcooke wĩkĩre namba yaku ya thimũ na kĩhithe.';

  @override
  String get welfareRecordThisPayment => 'Andĩka irĩhi rĩrĩ?';

  @override
  String get welfareRecordPayment => 'Andĩka irĩhi';

  @override
  String get welfareWelfareFund => 'Mũthithũ wa Ũteithio';

  @override
  String get welfareCouldNotLoadTheWelfare =>
      'Mũthithũ wa ũteithio ndũnahota kũrutwo.';

  @override
  String get welfareTryAgain => 'Geria rĩngĩ';

  @override
  String get welfareLeftInTheWelfareFund =>
      'Kĩrĩa gĩtigarĩte mũthithũ-inĩ wa ũteithio';

  @override
  String get welfareRecordAWelfarePayment => 'Andĩka irĩhi rĩa ũteithio';

  @override
  String get welfarePaidOutThisCycle => 'Kĩrĩa kĩrĩhĩtwo mũthiũrũrũko-inĩ ũyũ';

  @override
  String get welfareNothingPaidOutYetThe =>
      'Gũtirĩ kĩrĩhĩtwo — mũthithũ wothe wa ũteithio nĩũkũgayanwo.';

  @override
  String get welfareRecordedInMeeting => 'Kwandĩkĩirwo mũcemanio-inĩ';

  @override
  String get welfareAmountKsh => 'Mũigana (KSh)';

  @override
  String get welfareWhatFor => 'Nĩ kwa ũndũ ũrĩkũ';

  @override
  String get welfarePaidTo => 'Aarĩhirwo';

  @override
  String get welfareAMemberAFamilyOr =>
      'Mũmemba, mũciĩ, kana thibitarĩ — mũndũ o wothe ũrĩa waamũkĩrire';

  @override
  String get welfareNoteOptional => 'Ũhoro (ti bata)';

  @override
  String get meetingHubEditAttendance => 'Garũra ũkinyu';

  @override
  String get meetingHubCloseLockMeeting => 'Hinga na Ũhingĩre Mũcemanio';

  @override
  String get meetingHubClosingLocksAllRecordsPermanently =>
      'Kũhinga kũhingaga maandĩko mothe nginya tene.';

  @override
  String get meetingHubKeepOpen => 'Tiga Ũhingũkĩte';

  @override
  String get meetingHubCloseLock => 'Hinga na Ũhingĩre';

  @override
  String get meetingHubSocialFund => 'Mũthithũ wa Ũteithio';

  @override
  String get meetingHubBuyShares => 'Gũra Hisa';

  @override
  String get meetingHubRecordFine => 'Andĩka Faini';

  @override
  String get meetingHubDisburseLoan => 'Heana Mũkopo';

  @override
  String get meetingHubRepayment => 'Kũrĩha';

  @override
  String get meetingHubShareRecords => 'Maandĩko ma Hisa';

  @override
  String get meetingHubVoting => 'Gũtua';

  @override
  String get meetingHubWelfare => 'Ũteithio';

  @override
  String get meetingHubIntelliStore => 'Intelli-Store';

  @override
  String get meetingHubExternalLoans => 'Mĩkopo ya Nja';

  @override
  String get groupSetupWizardAddTheMembersJoiningThis =>
      'Ongerera amemba arĩa marenyita mũthiũrũrũko ũyũ. No wongerere angĩ hĩndĩ ĩngĩ.';

  @override
  String get groupSetupWizardEveryoneBuysSharesAtOne =>
      'Mũndũ o wothe agũraga hisa na thogora ũmwe ũtagarũrũkaga';

  @override
  String get groupSetupWizardMembersSaveWhatTheyCan =>
      'Amemba maigaga kĩrĩa mangĩhota o mũcemanio';

  @override
  String get groupSetupWizardGroupName => 'Rĩĩtwa rĩa gĩkundi';

  @override
  String get groupSetupWizardCycleNumber => 'Namba ya Mũthiũrũrũko';

  @override
  String get groupSetupWizardWhichSavingsCycleIsThis =>
      'Gĩkundi gĩkĩ kĩrĩ mũthiũrũrũko ũrĩkũ wa ũigi?';

  @override
  String get groupSetupWizardMemberName => 'Rĩĩtwa rĩa mũmemba';

  @override
  String get groupSetupWizardAddMember => 'Ongerera mũmemba';

  @override
  String get groupSetupWizardRemove => 'Eheria';

  @override
  String get groupSetupWizardShareValueKsh => 'Thogora wa Hisa (KSh)';

  @override
  String get groupSetupWizardMaxSharesPerMeeting =>
      'Hisa Iria Nyingĩ o Mũcemanio';

  @override
  String get groupSetupWizardSocialFundPerMeetingKsh =>
      'Mũthithũ wa Ũteithio o Mũcemanio (KSh)';

  @override
  String get groupSetupWizardTrackedSeparatelyFromSavings =>
      'Ũrũmagĩrĩrwo mwanya na ũigi';

  @override
  String get groupSetupWizardInterestRatePerMonth => 'Ũcuuthi (% o mweri)';

  @override
  String get groupSetupWizardMaxLoanMultiplierSavings =>
      'Mũigana wa Mũkopo (× ũigi)';

  @override
  String get groupSetupWizardDefaultLoanTermMonths =>
      'Ihinda rĩa Mũkopo (mĩeri)';

  @override
  String get groupSyncBackUpToCloud => 'Iga Matu-inĩ';

  @override
  String get groupSyncUnlinkGroup => 'Eheria kĩohanio kĩa gĩkundi?';

  @override
  String get groupSyncUnlink => 'Eheria kĩohanio';

  @override
  String get groupSyncNotConnected => 'Ĩtiohanĩtio';

  @override
  String get groupSyncOpenServerConnection => 'Hingũra Kĩohanio kĩa Cheba';

  @override
  String get groupSyncLink => 'Ohania';

  @override
  String get groupSyncUnlinkGroup2 => 'Eheria Kĩohanio kĩa Gĩkundi';

  @override
  String get groupSyncNoBackendGroups => 'Gũtirĩ ikundi cheba-inĩ';

  @override
  String get groupSyncThisApiKeyCannotSee =>
      'Kĩhingũro gĩkĩ gĩtingĩona gĩkundi o na kĩmwe gĩa kuohania.';

  @override
  String get groupSyncBackendGroup => 'Gĩkundi kĩrĩa kĩrĩ cheba-inĩ';

  @override
  String get createPollStartAVote => 'Ambĩrĩria Itua';

  @override
  String get createPollEveryonePresentVotesOnceNobody =>
      'O mũndũ ũrĩ ho atuaga riita rĩmwe. Gũtirĩ ũngĩtua maita meerĩ.';

  @override
  String get createPollChooseALeader => 'Thuura mũtongoria';

  @override
  String get createPollDecideSomething => 'Tua ũndũ';

  @override
  String get createPollTickAtLeastTwoPeople => 'Thuura andũ eerĩ kana makĩria.';

  @override
  String get createPollAddAnotherAnswer => 'Ongerera macookio mangĩ';

  @override
  String get createPollSecretVote => 'Itua rĩa hitho';

  @override
  String get createPollOpenTheVote => 'Hingũra Itua';

  @override
  String get createPollWhichPosition => 'Nĩ nafathi ĩrĩkũ?';

  @override
  String get createPollWhatIsTheQuestion => 'Kĩũria nĩ kĩrĩkũ?';

  @override
  String get createPollShouldWeBuyAGroup => 'Nĩtũgũre tanki ya maĩ ya gĩkundi?';

  @override
  String get paymentProvidersLeaveABoxEmptyTo =>
      'Tiga gĩkabũ gĩtarĩ kĩndũ nĩguo ũtige kĩrĩa kĩigĩtwo.';

  @override
  String get paymentProvidersSave => 'Iga';

  @override
  String get paymentProvidersUseThePlatformAccount =>
      'Hũthĩra akaũnti ya kĩoneki?';

  @override
  String get paymentProvidersPaymentProviders => 'Aheani a Marĩhi';

  @override
  String get paymentProvidersUsePlatform => 'Hũthĩra kĩoneki';

  @override
  String get storeShopOnCredit => 'Gũra na mũkopo';

  @override
  String get storeLoanOffersFromLendingPartners =>
      'Mĩkopo kuuma kũrĩ athiritũ akombithania — hooya ta gĩkundi.';

  @override
  String get storeSeeAllExternalLoans => 'Ona mĩkopo yothe ya nja';

  @override
  String get storeConnectToBrowseTheStore => 'Ohania nĩguo wone thoko';

  @override
  String get storeOpenCloudAccount => 'Hingũra Akaũnti ya Matu';

  @override
  String get storeAll => 'Ciothe';

  @override
  String get storeCouldNotLoadTheStore => 'Thoko ndĩnahota kũrutwo';

  @override
  String get storeNoProductsInThisCategory => 'Gũtirĩ indo mũthemba-inĩ ũyũ';

  @override
  String get storeTryADifferentCategoryOr =>
      'Geria mũthemba ũngĩ kana ũcooke thutha-inĩ.';

  @override
  String get pollsNewVote => 'Itua Rĩerũ';

  @override
  String get pollsGroupVotes => 'Itua cia gĩkundi';

  @override
  String get pollsSecret => 'Hitho';

  @override
  String get pollsYouHaveVoted => 'Nĩwatua';

  @override
  String get pollsConnectToVote => 'Ohania nĩguo ũtue';

  @override
  String get pollsCouldNotLoadTheVotes => 'Itua itinahota kũrutwo';

  @override
  String get pollsNoVotesYet => 'Gũtirĩ itua';

  @override
  String get memberPassbookMyPassbook => 'Ibuku Rĩakwa';

  @override
  String get memberPassbookJoinAGroup => 'Ĩtĩkĩra gĩkundi';

  @override
  String get memberPassbookMyReport => 'Ripoti yakwa';

  @override
  String get memberPassbookMySavingsAcrossAllGroups =>
      'Ũigi wakwa ikundi-inĩ ciothe';

  @override
  String get memberPassbookJoinAnotherGroup => 'Ĩtĩkĩra gĩkundi kĩngĩ';

  @override
  String get memberPassbookYouAreNotInA => 'Ndũrĩ gĩkundi-inĩ o na rĩmwe';

  @override
  String get memberPassbookNoTransactionsYet => 'Gũtirĩ maũndũ mekĩtwo';

  @override
  String get memberPassbookYourSavingsAndLoanRecords =>
      'Maandĩko ma ũigi na mĩkopo yaku nĩmakonekaga haha.';

  @override
  String get joinRequestsDecline => 'Rega';

  @override
  String get joinRequestsJoinRequests => 'Mahooya ma Kwĩyũnganĩria';

  @override
  String get joinRequestsPeopleAskingToJoin =>
      'Andũ arĩa marahooya kwĩyũnganĩria';

  @override
  String get joinRequestsApprove => 'Ĩtĩkĩra';

  @override
  String get joinRequestsReasonOptional => 'Gĩtũmi (ti bata)';

  @override
  String get joinRequestsNoOneIsWaiting => 'Gũtirĩ mũndũ ũreteterera';

  @override
  String get pollDetailCloseThisVote => 'Hinga itua rĩrĩ?';

  @override
  String get pollDetailCloseVote => 'Hinga Itua';

  @override
  String get pollDetailVote => 'Tua';

  @override
  String get pollDetailYourChoice => 'Ũthuuri waku';

  @override
  String get pollDetailNoMembersLoadedForThis =>
      'Gũtirĩ amemba marutĩtwo gĩkundi gĩkĩ.';

  @override
  String get pollDetailMemberCastingThisVote => 'Mũmemba ũratua itua rĩrĩ';

  @override
  String get groupPolicyHowLongALoanRuns =>
      'Mũkopo ũikaraga ihinda rĩigana atĩa';

  @override
  String get groupPolicyInterestCharged => 'Ũcuuthi ũrĩa ũtozagwo';

  @override
  String get groupPolicyExpensesArePaidFrom => 'Thogora ũrĩhagwo kuuma';

  @override
  String get groupPolicyRulesThatAreFixed => 'Mawatho matagarũrũkaga';

  @override
  String get productDetailRequestOnCredit => 'Hooya na Mũkopo';

  @override
  String get productDetailQuantity => 'Mũigana';

  @override
  String get productDetailSubmitRequest => 'Tũma Ihooya';

  @override
  String get productDetailPricedAtTheStandardDeposit =>
      'Thogora wa mũthiĩ wa kawaida — gĩthimi gĩtirĩ ho.';

  @override
  String get productDetailProgramme => 'Mũbango';

  @override
  String get productDetailCustomerName => 'Rĩĩtwa rĩa mũgũri';

  @override
  String get productDetailEmail => 'Barũa ya ĩntaneti';

  @override
  String get productDetailGroupNameOptional => 'Rĩĩtwa rĩa gĩkundi (ti bata)';

  @override
  String get dashboardHello => 'Wĩ mwega 👋';

  @override
  String get dashboardTotalSavings => 'Mbeca Ciothe Iigĩtwo';

  @override
  String get dashboardActiveLoans => 'Mĩkopo Ĩrĩ Wĩra-inĩ';

  @override
  String get dashboardFinesCollected => 'Faini Iria Ciũnganĩtio';

  @override
  String get disburseLoanLoanEligibility => 'Ũhoti wa Kũheo Mũkopo';

  @override
  String get disburseLoanSelectMember => 'Thuura Mũmemba';

  @override
  String get disburseLoanPrincipalAmountKsh => 'Mbeca cia Kĩambĩrĩria (KSh)';

  @override
  String get disburseLoanDueDate => 'Mũthenya wa Kũrĩha';

  @override
  String get joinGroupRequestSent => 'Ihooya nĩrĩatũmwo';

  @override
  String get joinGroupDone => 'Nĩ kũhĩte';

  @override
  String get joinGroupAskYourGroupToAdd => 'Hooya gĩkundi gĩaku gĩkuongerere';

  @override
  String get joinGroupSendRequest => 'Tũma ihooya';

  @override
  String get joinGroupViewing => 'Ũroroa';

  @override
  String get joinGroupGroupCode => 'Kĩmenyithia kĩa gĩkundi';

  @override
  String get memberDetailEditDetails => 'Garũra ũhoro';

  @override
  String get memberDetailMemberReport => 'Ripoti ya mũmemba';

  @override
  String get memberDetailNoLoansTaken => 'Gũtirĩ mũkopo woetwo';

  @override
  String get memberDetailStartingPassword => 'Kĩhithe kĩa kwambĩrĩria';

  @override
  String get memberDetailAtLeast6Characters => 'Ndemwa 6 kana nyingĩ.';

  @override
  String get cyclesCloseCycle => 'Hinga mũthiũrũrũko';

  @override
  String get cyclesSavingCycles => 'Mĩthiũrũrũko ya Ũigi';

  @override
  String get cyclesCloseCycleAndStartThe =>
      'Hinga mũthiũrũrũko wambĩrĩrie ũrĩa ũngĩ';

  @override
  String get cyclesReadOnlyStillVisibleIn =>
      'Gũthomwo tu — no ũronekaga ripoti-inĩ';

  @override
  String get externalLoansCreditVentures => 'Mĩbango ya mũkopo';

  @override
  String get externalLoansConnectToSeeLoanOffers =>
      'Ohania nĩguo wone mĩkopo ĩrĩa ĩrĩ ho';

  @override
  String get externalLoansCouldNotLoadLoanOffers => 'Mĩkopo ĩtinahota kũrutwo';

  @override
  String get externalLoansNoLoanOffersRightNow => 'Gũtirĩ mũkopo rĩu';

  @override
  String get accountAccount => 'Akaũnti';

  @override
  String get accountServer => 'Cheba';

  @override
  String get accountAppVersion => 'Mũthemba wa app';

  @override
  String get accountPhone => 'Thimũ';

  @override
  String get businessProfileGroupBusiness => 'Wonjoria wa gĩkundi';

  @override
  String get businessProfileWhatDoesTheGroupRun =>
      'Nĩ wonjoria ũrĩkũ gĩkundi kĩrutaga hamwe?';

  @override
  String get businessProfileTypeOfBusiness => 'Mũthemba wa wonjoria';

  @override
  String get businessProfileEGPoultryCerealBuying => 'ta: ngũkũ, kũgũra mbembe';

  @override
  String get businessProfileMoneyInEachMonthKes =>
      'Mbeca itonyaga o mweri (KES)';

  @override
  String get businessProfileCostsEachMonthKes => 'Thogora o mweri (KES)';

  @override
  String get businessProfilePeopleItEmploys => 'Andũ arĩa ũheaga wĩra';

  @override
  String get businessProfileBiggestProblemTheyFace =>
      'Thĩna mũnene ũrĩa mahĩtũkagĩra';

  @override
  String get recordVisitSettings => 'Mĩbango';

  @override
  String get recordVisitScoreTheGroup => 'Thima gĩkundi';

  @override
  String get recordVisitTheGroupSEnterprise => 'Wonjoria wa gĩkundi';

  @override
  String get recordVisitWhatTheyRunTogetherAnd =>
      'Kĩrĩa marutaga hamwe, na ũrĩa gĩgũthiĩ.';

  @override
  String get recordVisitSavedOnThisPhoneFirst =>
      'Kĩigagwo thimũ-inĩ ĩno mbere, gĩcooke gĩtũmwo wagĩa na mũtandao.';

  @override
  String get recordVisitWhyNotOptional => 'Nĩkĩ gĩtirĩ? (ti bata)';

  @override
  String get recordVisitWhatYouFound => 'Kĩrĩa wonire';

  @override
  String get agentHomeMyGroups => 'Ikundi Ciakwa';

  @override
  String get agentHomeCaseloadReport => 'Ripoti ya ikundi';

  @override
  String get agentHomeNoGroupsAssigned => 'Gũtirĩ gĩkundi ũheetwo';

  @override
  String get agentHomeGroups => 'Ikundi';

  @override
  String get agentHomeNeedSupport => 'Ĩrabatara ũteithio';

  @override
  String get loansLoanPortfolio => 'Ibuku rĩa Mĩkopo';

  @override
  String get loansActive => 'Ĩrĩ Wĩra';

  @override
  String get loansSearchByMemberName => 'Caria na rĩĩtwa rĩa mũmemba';

  @override
  String get loansNoLoansHere => 'Gũtirĩ mĩkopo haha';

  @override
  String get threeKeyUnlockUnlockMeeting => 'Hingũra Mũcemanio';

  @override
  String get threeKeyUnlockVerified => 'Nĩ gwĩkĩrĩtwo hinya';

  @override
  String get threeKeyUnlockSendANewCode => 'Tũma kĩmenyithia kĩerũ';

  @override
  String get threeKeyUnlockNoSmsUseMySaved =>
      'Gũtirĩ SMS? Hũthĩra PIN yakwa ĩrĩa ĩigĩtwo';

  @override
  String get threeKeyUnlockOneTimeCode => 'Kĩmenyithia kĩa riita rĩmwe';

  @override
  String get threeKeyUnlockRepeatPin => 'Cookera PIN';

  @override
  String get memberReportMyReport => 'Ripoti Yakwa';

  @override
  String get memberReportShare => 'Gaĩra';

  @override
  String get memberReportNotSignedIn => 'Ndũtoonyete';

  @override
  String get memberReportSignInToYourAccount =>
      'Toonya akaũnti-inĩ yaku nĩguo wone na ũgaĩre ripoti yaku.';

  @override
  String get cloudDashboardCloudData => 'Ũhoro wa Matu';

  @override
  String get cloudDashboardRefresh => 'Erũhia';

  @override
  String get cloudDashboardSavingsFund => 'Mũthithũ wa Ũigi';

  @override
  String get cloudDashboardInternalLoans => 'Mĩkopo ya Thĩinĩ';

  @override
  String get serverSettingsOrUseAGroupAccess =>
      'kana hũthĩra kĩhingũro kĩa gĩkundi';

  @override
  String get serverSettingsViewOnlineRecords => 'Ona Maandĩko ma Mũtandao-inĩ';

  @override
  String get serverSettingsBackUpThisGroup => 'Iga Gĩkundi Gĩkĩ';

  @override
  String get serverSettingsAccessKey => 'Kĩhingũro';

  @override
  String get shareOutDistribute => 'Gaĩra';

  @override
  String get shareOutFundToDistribute => 'Mbeca cia kũgayanwo';

  @override
  String get shareOutSplitWelfareFundEqually =>
      'Gayania mũthithũ wa ũteithio o ũndũ ũmwe';

  @override
  String get shareOutNothingToShareOutYet => 'Gũtirĩ kĩndũ gĩa kũgayanwo';

  @override
  String get visitAssessmentAssessment => 'Gĩthimi';

  @override
  String get visitAssessmentFormNotAvailable => 'Fomu ndĩrĩ ho';

  @override
  String get visitMentorshipMentorship => 'Ũtaari';

  @override
  String get visitMentorshipWhatDidYouCoachOn => 'Nĩ ũndũ ũrĩkũ warutire?';

  @override
  String get visitMentorshipTapATopicToRecord =>
      'Hutia ũndũ nĩguo ũwandĩke, ũcooke wandĩke kĩrĩa wataarire.';

  @override
  String get visitMentorshipNowHandThePhoneTo => 'Rĩu nengera gĩkundi thimũ';

  @override
  String get visitMentorshipWhatYouAdvised => 'Kĩrĩa wataarire';

  @override
  String get agentGroupDetailRecordAVisit => 'Andĩka rũgendo';

  @override
  String get agentGroupDetailNoMembersLoaded => 'Gũtirĩ amemba marutĩtwo.';

  @override
  String get agentGroupDetailNoMeetingsLoaded => 'Gũtirĩ mĩcemanio ĩrutĩtwo.';

  @override
  String get agentGroupDetailToImprove => 'Cia kwagĩrithia';

  @override
  String get agentGroupDetailGovernance => 'Ũtongoria';

  @override
  String get agentGroupDetailVslaCompliance => 'Kũrũmĩrĩra mawatho ma VSLA';

  @override
  String get recordFineReason => 'Gĩtũmi';

  @override
  String get recordFineSpecifyReason => 'Taarĩria gĩtũmi';

  @override
  String get addMemberAddMember => 'Ongerera Mũmemba';

  @override
  String get addMemberRegisterMember => 'Andĩkithia Mũmemba';

  @override
  String get addMemberFullName => 'Rĩĩtwa Rĩothe';

  @override
  String get addMemberPhoneOptional => 'Thimũ (ti bata)';

  @override
  String get addMemberRole => 'Nafathi';

  @override
  String get editMemberEditMember => 'Garũra mũmemba';

  @override
  String get editMemberFullName => 'Rĩĩtwa rĩothe';

  @override
  String get membersRequestsToJoin => 'Mahooya ma kwĩyũnganĩria';

  @override
  String get membersSearchMembers => 'Caria amemba';

  @override
  String get membersNoMembersFound => 'Gũtirĩ mũmemba wonekire';

  @override
  String get meetingSecurity3KeyUnlockBeforeMeetings =>
      'Cabi 3 mbere ya mĩcemanio';

  @override
  String get meetingSecurityKeepPin => 'Tiga PIN';

  @override
  String get meetingSecurityReset => 'Cookia rĩngĩ';

  @override
  String get agentReportCaseloadReport => 'Ripoti ya Ikundi';

  @override
  String get agentReportShareReport => 'Gaĩra Ripoti';

  @override
  String get agentReportNeedsSupport => 'Ĩrabatara ũteithio';

  @override
  String get agentReportNoRating => 'Gũtirĩ gĩthimi';

  @override
  String get agentReportNoGroupsYet => 'Gũtirĩ ikundi';

  @override
  String get groupReportNoGroupYet => 'Gũtirĩ gĩkundi';

  @override
  String get groupReportSetUpYourGroupFirst =>
      'Thondeka gĩkundi gĩaku mbere, ũcooke ũũke kũrĩ ripoti.';

  @override
  String get groupReportNoMembersYet => 'Gũtirĩ amemba';

  @override
  String get groupReportMembersAppearHereOnceThey =>
      'Amemba monekaga haha maarĩkia kwĩyũnganĩria na gĩkundi.';

  @override
  String get memberReportLocalMemberReport => 'Ripoti ya Mũmemba';

  @override
  String get memberReportLocalMemberNotFound => 'Mũmemba ndonekire';

  @override
  String get memberReportLocalThisMemberIsNoLonger =>
      'Mũmemba ũyũ ndarĩ gĩkundi-inĩ rĩngĩ.';

  @override
  String get memberReportLocalLoansThisMemberTakesWill =>
      'Mĩkopo ĩrĩa mũmemba ũyũ akoya nĩĩkonekaga haha.';

  @override
  String get externalLoanApplyApplyForALoan => 'Hooya Mũkopo';

  @override
  String get externalLoanApplySubmitApplication => 'Tũma Ihooya';

  @override
  String get externalLoanApplyWhatIsTheLoanFor => 'Mũkopo nĩ wa ũndũ ũrĩkũ?';

  @override
  String get externalLoanApplyEGBuyingMaizeSeed =>
      'ta: kũgũra mbegũ cia mbembe cia kĩmera';

  @override
  String get meetingsNoMeetingsYet => 'Gũtirĩ mĩcemanio';

  @override
  String get repaymentRecordRepayment => 'Andĩka Irĩhi';

  @override
  String get repaymentNoOutstandingLoansNothingTo =>
      'Gũtirĩ mũkopo ũrĩ na thiirĩ — gũtirĩ kĩa kũrĩhwo. 🎉';

  @override
  String get repaymentSelectLoan => 'Thuura Mũkopo';

  @override
  String get moreWhoIsSignedInLanguage =>
      'Ũrĩa ũtoonyete, rũthiomi, mũonekere na ũhoro wa app';

  @override
  String get moreIntelliCash => 'Intelli-Cash';

  @override
  String get mySavingsMySavings => 'Ũigi Wakwa';

  @override
  String get mySavingsOnceAGroupAcceptsYou =>
      'Gĩkundi kĩngĩgwĩtĩkĩra, ũigi waku nĩũkonekaga haha.';

  @override
  String get buySharesEnterCodeByHand => 'Andĩka Kĩmenyithia na Guoko';

  @override
  String get buySharesRecordPurchase => 'Andĩka Ũgũri';

  @override
  String get sharesLedgerNoPurchasesYet => 'Gũtirĩ ũgũri';

  @override
  String get socialFundThisMeetingIsClosedThe =>
      'Mũcemanio ũyũ nĩmũhinge — maandĩko no ma gũthomwo tu.';

  @override
  String get socialFundNoMembers => 'Gũtirĩ amemba';

  @override
  String get socialFundAddMembersToTheGroup =>
      'Ongerera amemba gĩkundi-inĩ mbere.';

  @override
  String get welcomeUseTheWebConsoleFor => 'Hũthĩra ĩntaneti kũrĩ akaũnti ĩno';

  @override
  String get welcomeLoadYourGroupOntoThis => 'Ruta gĩkundi gĩaku thimũ-inĩ ĩno';

  @override
  String get memberReportsTapAMemberToSee =>
      'Hutia mũmemba nĩguo wone na ũgaĩre ripoti yake.';

  @override
  String get openActionItemsNothingOutstanding => 'Gũtirĩ kĩrĩa gĩtigarĩte';

  @override
  String get openActionItemsThisGroupHasNoOpen =>
      'Gĩkundi gĩkĩ gĩtirĩ na wĩra ũtigarĩte kuuma ngendo iria ciathirire.';

  @override
  String get openActionItemsFromTheLastVisit => 'Kuuma rũgendo rũrĩa rwa mũico';

  @override
  String get loanDetailNoRepaymentsYet => 'Gũtirĩ marĩhi';

  @override
  String get attendanceAttendance => 'Ũkinyu';

  @override
  String get attendanceContinueToMeeting => 'Thiĩ na mbere Mũcemanio-inĩ';

  @override
  String get appearanceChooseHowIntelliCashLooks =>
      'Thuura ũrĩa Intelli-Cash ĩkuoneka thimũ-inĩ ĩno.';

  @override
  String get gatewayPaymentOpenThisLinkToPay => 'Hingũra kĩohanio gĩkĩ ũrĩhe:';

  @override
  String get numericKeypadDelete => 'Theria';

  @override
  String get agentHomeWhenGroupsAreAssignedToYou =>
      'Ikundi ciangĩneanwo kũrĩ we, nĩikonekaga haha hamwe na gĩthimi kĩao kĩa mũkopo.';

  @override
  String get dashboardTheSavingsCurveAppearsAfterYour =>
      'Mũharo wa ũigi ũronekaga thutha wa mĩcemanio yaku ĩĩrĩ ya mbere.';

  @override
  String get disburseLoanThisMemberHasNoBorrowingHeadroom =>
      'Mũmemba ũyũ ndarĩ na ũhoti wa kũhooya mũkopo — ũigi no mũhaka wongerereke kana mũkopo ũrĩa arĩ naguo ũnyihanyiihe mbere.';

  @override
  String get disburseLoanTheLoanFundIsEmptyCollect =>
      'Mũthithũ wa mĩkopo nĩ ũtheri. Ũnganĩria ũgũri wa hisa kana marĩhi ma mĩkopo mbere ya gũkombithania rĩngĩ.';

  @override
  String get loanDetailRepaymentsAreRecordedInsideMeetingsAnd =>
      'Marĩhi mandĩkagwo thĩinĩ wa mĩcemanio na monekaga haha o rĩmwe.';

  @override
  String get loansLoansAreDisbursedInsideAMeeting =>
      'Mĩkopo ĩheanagwo thĩinĩ wa mũcemanio — hingũra mũcemanio ũcooke ũhũthĩre Heana Mũkopo.';

  @override
  String get gatewayPaymentRequestSentAskTheMemberTo =>
      'Ihooya nĩrĩatũmwo. Ĩra mũmemba ekĩre PIN yake ya M-Pesa thimũ-inĩ yake.';

  @override
  String get meetingHubThisMeetingIsClosedItsRecords =>
      'Mũcemanio ũyũ nĩmũhinge. Maandĩko maguo no ma gũthomwo tu na nĩ gĩcunjĩ kĩa ũrorio.';

  @override
  String get meetingHubAllRecordsInThisMeetingWill =>
      'Maandĩko mothe ma mũcemanio ũyũ nĩmakũhingwo nginya tene. Ũndũ ũyũ ndũngĩcookererio.';

  @override
  String get meetings3KeyUnlockIsOnOfficials =>
      'Cabi 3 nĩ ciarutithio wĩra: atongoria nĩmakũhingĩria PIN ciao mbere ya mũcemanio kũhingũrwo.';

  @override
  String get meetingsStartYourFirstMeetingToRecord =>
      'Ambĩrĩria mũcemanio waku wa mbere nĩguo wandĩke ũkinyu, ũigi, faini na mĩkopo.';

  @override
  String get meetingsClosedMeetingsAreLockedTheirRecords =>
      'Mĩcemanio ĩrĩa ĩhinge nĩ ĩhingĩre — maandĩko mayo nĩmo ũrorio wa gĩkundi wa nginya tene.';

  @override
  String get sharesLedgerSharePurchasesLandHereTheMoment =>
      'Ũgũri wa hisa ũronekaga haha o rĩrĩa wandĩkwo.';

  @override
  String get joinGroupYourGroupHasACodeOn =>
      'Gĩkundi gĩaku kĩrĩ na kĩmenyithia maandĩko-inĩ makĩo — ũria mwandĩki angĩkorũo ndũũĩ. Gũtũma ihooya gũtikũhingũragĩra mabuku ma gĩkundi; mũtongoria no mũhaka akwĩtĩkĩre mbere.';

  @override
  String get memberPassbookAskYourGroupToAddYou =>
      'Hooya gĩkundi gĩaku gĩkuongerere na ũigi waku nĩũkonekaga haha.';

  @override
  String get editMemberCorrectingASpellingOrAMistyped =>
      'Kũrũngĩrĩria ndemwa kana namba ĩrĩa ĩhĩtĩtie. Ũigi, mĩkopo na ũkinyu wake ũtigwo o ũrĩa ũrĩ.';

  @override
  String get joinRequestsTheyWillNotBeAddedTo =>
      'Ndegũongererwo gĩkundi-inĩ. No woige gĩtũmi ũngĩenda — ti bata.';

  @override
  String get joinRequestsThisListIsOutOfDate =>
      'Rũtaratara rũrũ ti rwa rĩu. Guucia na thĩ nĩguo rwerũhio, ũcooke ũrore macookio rĩngĩ.';

  @override
  String get joinRequestsWhenSomeoneAsksToJoinYour =>
      'Mũndũ angĩhooya kwĩyũnganĩria na gĩkundi gĩaku, ihooya rĩake nĩrĩkonekaga haha nĩguo ũrĩcookerie.';

  @override
  String get memberDetailToCreateASignInAccount =>
      'Nĩguo ũthondeke akaũnti ya gũtoonya, amba wĩgĩe gĩkundi gĩkĩ matu-inĩ (Mangĩ → Sync & Backup) ũrĩ na ĩntaneti.';

  @override
  String get memberDetailLoansThisMemberTakesWillBe =>
      'Mĩkopo ĩrĩa mũmemba ũyũ akoya nĩĩkwandĩkwo haha hamwe na ũrĩa ĩhaana.';

  @override
  String get membersAddMembersWithTheButtonBelow =>
      'Ongerera amemba na batani ĩrĩa ĩrĩ na thĩ — o ũmwe agĩaga na maandĩko make ma ũigi na mĩkopo.';

  @override
  String get meetingSecurityAssignAChairpersonSecretaryAndTreasurer =>
      'Thuura mũtongoria, mwandĩki na mũigi mbeca haha na thĩ nĩguo atongoria atatũ mahote kũhingũra mĩcemanio. Nginya hĩndĩ ĩyo, PIN cia amemba aingĩ nĩcio ikũbatarania.';

  @override
  String get meetingSecurityTheOldPinStopsWorkingThe =>
      'PIN ya tene ĩtigaga kũruta wĩra. Mũmemba athuuraga PIN njerũ hĩndĩ ĩrĩa akũhũthĩra cabi yake kũhingũra mũcemanio.';

  @override
  String get moreYourGroupSSavingsAndLoans =>
      'Ũigi na mĩkopo ya gĩkundi gĩaku, o thimũ-inĩ yaku. Kĩndũ o gĩothe kĩigagwo thimũ-inĩ ĩno mbere, gĩcooke kĩigwo ĩntaneti-inĩ wagĩa na mũtandao.\n\nIntelli-Wealth Limited · intelliwealth.org';

  @override
  String get moreNoInternetYourRecordsAreSafe =>
      'Gũtirĩ ĩntaneti — maandĩko maku marĩ mũgitĩre thimũ-inĩ ĩno na nĩmakũigwo thutha-inĩ.';

  @override
  String get welcomeThePhoneAppIsForGroups =>
      'App ya thimũ nĩ ya ikundi, amemba na arũgamĩrĩri a mũgũnda. Akaũnti yaku ndĩbataire gũthondeka gĩkundi haha — toonya ĩntaneti-inĩ handũ ha ũguo, kana uma nĩguo ũhũthĩre akaũnti ĩngĩ.';

  @override
  String get welcomeYourGroupIsAlreadyOnThe =>
      'Gĩkundi gĩaku nĩ kĩrĩ cheba-inĩ. Kĩrute haha handũ ha gũthondeka kĩngĩ, nĩguo ũhoro wa ũigi waku ũtige ũrĩ handũ hamwe.';

  @override
  String get agentReportWhenGroupsAreAssignedToYou =>
      'Ikundi ciangĩneanwo kũrĩ we, ripoti yacio nĩyonekaga haha.';

  @override
  String get groupReportFiguresFromThisPhoneOnlyWork =>
      'Namba cia thimũ ĩno tu - wĩra ũrĩa ũigĩtwo thimũ ingĩ no ũkorũo ũtarĩ thĩinĩ.';

  @override
  String get groupReportFromThisPhoneOnlyWorkSaved =>
      'Kuuma thimũ ĩno tu. Wĩra ũrĩa ũigĩtwo thimũ ingĩ no ũkorũo ũtarĩ thĩinĩ.';

  @override
  String get memberReportLocalFiguresFromThisPhoneOnlyRecords =>
      'Namba cia thimũ ĩno tu - maandĩko marĩa maigĩtwo kũndũ kũngĩ no makorũo matarĩ thĩinĩ.';

  @override
  String get mySavingsWhatYouOweIsCountedFor =>
      'Thiirĩ waku ũtaragwo o gĩkundi kĩrĩ kĩnyiki. Kũrĩha makĩria gĩkundi-inĩ kĩmwe gũtinyihagia thiirĩ waku gĩkundi-inĩ kĩngĩ.';

  @override
  String get groupSyncThisClearsTheLocalBackendMapping =>
      'Ũndũ ũyũ nĩũtheragia kĩohanio gatagatĩ ka thimũ na cheba. Maandĩko marĩa marĩkĩtie kũiganania matigagwo cheba-inĩ; gũtirĩ kĩndũ gĩgũtherio.';

  @override
  String get groupSyncConnectToTheIntellicashBackendBefore =>
      'Ohania na cheba ya IntelliCash mbere ya kuohania na kũiganania gĩkundi gĩkĩ.';

  @override
  String get groupSyncLinkingMatchesYourLocalMembersTo =>
      'Kuohania kũringithanagia amemba a thimũ ĩno na rũtaratara rwa cheba na namba ya thimũ, gũcooka na rĩĩtwa. Arĩa matarĩngithanie no maohanio na guoko thutha-inĩ.';

  @override
  String get groupSyncTheseLocalMembersHaveNoBackend =>
      'Amemba aya a thimũ ĩno matirĩ arĩa maringaine nao cheba-inĩ. Maohanie mbere ya maũndũ mao kũiganania.';

  @override
  String get groupSyncUploadsAttendanceAndLedgerSharesSocial =>
      'Ĩtwaraga ũkinyu na ibuku (hisa, mũthithũ wa ũteithio, mĩkopo, marĩhi) rĩa o mũcemanio ũrĩa ũhinge. Nĩ mwega gũcookera — maandĩko marĩa marĩkĩtie kũiganania nĩmatigagwo. Faini na kũhinga mĩcemanio ikinyaga thutha-inĩ.';

  @override
  String get serverSettingsAskYourGroupAdministratorForAn =>
      'Hooya mũrori wa gĩkundi gĩaku kĩhingũro, ũcooke ũgĩkĩre haha. Kĩrekagĩria thimũ ĩno kuona na kwandĩka ũigi, mĩkopo na mĩcemanio ya gĩkundi gĩaku tu.';

  @override
  String get cyclesPullDownToTryAgainIf =>
      'Guucia na thĩ ũgerie rĩngĩ. Ũngĩthiĩ na mbere, rora kana gĩkundi no kĩthuurĩtwo harĩ Akaũnti ya Matu.';

  @override
  String get cyclesClosingACycleMakesItsRecords =>
      'Kũhinga mũthiũrũrũko gũtũmaga maandĩko maguo makorũo ma gũthomwo tu. Gũtirĩ kĩndũ gĩgũtherio — mĩcemanio na mbeca cia tene itigagwo ũhoro-inĩ na ripoti-inĩ.';

  @override
  String get cyclesYouCanSeeTheCyclesBut =>
      'No wone mĩthiũrũrũko no ndũngĩhota kũhinga. Nĩ akaũnti ya gĩkundi kana mũrori wa kĩoneki tu ũngĩhota.';

  @override
  String get groupPolicyAppliesToNewLoansLoansAlready =>
      'Ũhũthĩkaga harĩ mĩkopo mĩerũ. Mĩkopo ĩrĩa ĩrĩkĩtie kũheanwo ĩtigagwo na ihinda rĩrĩa rĩetĩkanĩirio — kũgarũra ũndũ ũyũ gũtigarũraga thiirĩ ũrĩa mũmemba arĩ naguo.';

  @override
  String get groupPolicyFlatOnTheAmountBorrowedEach =>
      'Nĩ gĩthimi kĩmwe harĩ mbeca iria ciakombirwo o mweri — gĩtinyihanyiihaga mũmemba akĩrĩha, na gĩthiraga mũthia wa ihinda rĩrĩa rĩetĩkanĩirio. Naili nĩ wega: ikundi nyingĩ ikombithanagia hatarĩ ũcuuthi. O mũkopo ũtigagwo na ũcuuthi ũrĩa waheanirwo naguo, nĩ ũndũ ũcio kũgarũra ũndũ ũyũ gũtigarũraga mbeca iria ciarĩkĩtie gũkombithanio.';

  @override
  String get groupPolicyYouCanSeeTheseRulesBut =>
      'No wone mawatho maya no ndũngĩhota kũmagarũra. Nĩ akaũnti ya gĩkundi kana mũrori wa kĩoneki tu ũngĩhota.';

  @override
  String get groupPolicyUnpaidFinesAndWelfareAreTaken =>
      'Faini na mbeca cia ũteithio iria itarĩhĩtwo iruthagio kuuma kĩgayo-inĩ kĩa mũmemba — itingĩgiria mũmemba kũgayana.\n\nMĩkopo ĩrĩa ĩtarĩhĩtwo ĩruthagio hĩndĩ ya kũgayana na ndĩtwaragwo mũthiũrũrũko-inĩ ũrĩa ũngĩ.';

  @override
  String get paymentProvidersMPesaClassicNeedsNothingHere =>
      'M-Pesa Classic ndĩbataire kĩndũ haha — mũmemba nĩwe wandĩkaga kĩmenyithia kĩa muamala kuuma thimũ-inĩ yake.';

  @override
  String get paymentProvidersYouCanSeeThisButNot =>
      'No wone ũndũ ũyũ no ndũngĩhota kũũgarũra. Nĩ akaũnti ya gĩkundi kana mũrori wa kĩoneki tu ũngĩhota kũgarũra harĩa mbeca ciamũkĩragĩrwo.';

  @override
  String get welfareYouAreOfflineWelfarePaymentsAre =>
      'Ndũrĩ na mũtandao. Marĩhi ma ũteithio mandĩkagwo cheba-inĩ nĩguo mũthithũ ndũkahũthĩrwo makĩria nĩ thimũ igĩrĩ hamwe — ohania nĩguo wandĩke.';

  @override
  String get welfareNoMeetingIsOpenWelfareIs =>
      'Gũtirĩ mũcemanio ũhingũre. Mbeca cia ũteithio irĩhagwo hĩndĩ ya mũcemanio, mbere ya amemba — hingũra mũcemanio mbere, ũcooke wandĩke ho.';

  @override
  String get shareOutMembersHavenTBoughtSharesThis =>
      'Amemba matigũrĩte hisa mũthiũrũrũko-inĩ ũyũ. Rutithia mĩcemanio na ũũnganĩrie hisa mbere, ũcooke ũũke kũgayana mbeca.';

  @override
  String get externalLoanApplyCreditRatingUnavailableTheLenderChecks =>
      'Gĩthimi kĩa mũkopo gĩtirĩ ho — mũkombithania nĩwe ũgĩroraga akĩrora ihooya rĩaku.';

  @override
  String get externalLoansCheckBackLaterPartnersAddNew =>
      'Cooka thutha-inĩ — athiritũ mongereragĩra mĩkopo mĩerũ hĩndĩ na hĩndĩ.';

  @override
  String get externalLoansExternalLoansLoadFromTheIntelli =>
      'Mĩkopo ya nja ĩrutagwo cheba-inĩ ya Intelli-Cash. Ohania kana ũtoonye mbere.';

  @override
  String get storeFarmSolarHouseholdAndBusinessProducts =>
      'Indo cia mũgũnda, riũa, nyũmba na wonjoria — thogora kũringana na gĩthimi kĩa mũkopo kĩa gĩkundi gĩaku.';

  @override
  String get storeIntelliStoresLoadsFromTheIntelli =>
      'Intelli-Stores ĩrutagwo cheba-inĩ ya Intelli-Cash. Ohania kana ũtoonye mbere.';

  @override
  String get businessProfileTheGroupSOwnEnterpriseNot =>
      'Wonjoria wa gĩkundi kĩene, ti wa mũmemba. Tiga hatarĩ kĩndũ mangĩkorũo matarĩ naguo.';

  @override
  String get businessProfileThisVisitHasNotSyncedYet =>
      'Rũgendo rũrũ rũtirĩ rwaiganania, nĩ ũndũ ũcio namba ciigĩtwo harĩ gĩkundi no ti harĩ rũgendo rũrũ.';

  @override
  String get businessProfileSavedAgainstThisVisitSoNext =>
      'Nĩ ciigĩtwo harĩ rũgendo rũrũ, nĩguo hĩndĩ ĩngĩ wone kĩrĩa kĩagarũrũkire.';

  @override
  String get recordVisitAVisitCanStillBeRecorded =>
      'Rũgendo no rũngĩandĩkwo o na hatarĩ handũ. Kana nĩrũringaine na gĩkundi gĩkĩ gũtuagwo nĩ ofisi, ti haha.';

  @override
  String get recordVisitRecordWhatYouCoachedOnThen =>
      'Andĩka kĩrĩa warutire, ũcooke ũreke gĩkundi gĩgĩthime.';

  @override
  String get visitAssessmentNoAssessmentFormHasBeenDownloaded =>
      'Gũtirĩ fomu ya gĩthimi ĩrutĩtwo. Ohania riita rĩmwe nĩguo ũmĩrute, ĩcooke ĩrute wĩra hatarĩ mũtandao.';

  @override
  String get visitMentorshipNotScoredYetAVisitCan =>
      'Rũtirĩ rwathimwo. Rũgendo no rũngĩandĩkwo hatarĩ ũguo, no mawoni ma gĩkundi nĩmo gĩthimi kĩrĩa kĩrĩ bata kĩa ũtaari.';

  @override
  String get createPollNoMembersLoadedForThisGroup =>
      'Gũtirĩ amemba marutĩtwo gĩkundi gĩkĩ. Ohania na ũhingũre gĩkundi mbere.';

  @override
  String get createPollNobodySeesWhoVotedForWhat =>
      'Gũtirĩ mũndũ ũkuona nũũ watuire kũrĩ ũ. Namba nĩcionagio andũ othe.';

  @override
  String get pollDetailNoMoreVotesCanBeCast =>
      'Gũtirĩ itua rĩngĩ rĩgũtuo thutha wa ũyũ, na macookio mandĩkagwo maandĩko-inĩ ma gĩkundi. Ũndũ ũyũ ndũngĩcookererio.';

  @override
  String get pollDetailClosingCountsTheVotesAndWrites =>
      'Kũhinga gũtaraga itua na gũkandĩka macookio maandĩko-inĩ ma gĩkundi.';

  @override
  String get pollDetailYouHaveVotedThisIsA =>
      'Nĩwatua. Rĩrĩ nĩ itua rĩa hitho, nĩ ũndũ ũcio ũthuuri waku ndwĩonagio mũndũ o na ũrĩkũ.';

  @override
  String get pollsElectYourLeadersAndDecideTogether =>
      'Thuurai atongoria anyu na mũtue hamwe. Mũmemba ũmwe, itua rĩmwe.';

  @override
  String get pollsTapNewVoteToElectA =>
      'Hutia Itua Rĩerũ nĩguo ũthuure mũtongoria kana ũũrie gĩkundi kĩũria.';

  @override
  String get pollsVotingIsKeptOnTheIntelli =>
      'Itua ciigagwo cheba-inĩ ya Intelli-Cash nĩguo o mũmemba one namba o ĩyo. Ohania kana ũtoonye mbere.';

  @override
  String unlockOpensWhen(int officials, int members) {
    return 'Mũcemanio ũhingũragwo rĩrĩa atongoria $officials — kana amemba $members — mahũthĩra cabi ciao.';
  }

  @override
  String paymentProvidersStillNeeded(String fields) {
    return 'Gũtirĩ kwarĩkia — no kũbataraga: $fields. Nginya hĩndĩ ĩyo mbeca ithiaga akaũnti-inĩ ya kĩoneki.';
  }

  @override
  String welfareSharedOutExplainer(String paidOut) {
    return 'Ĩno nĩyo ĩkũgayanwo mũthia wa mũthiũrũrũko — ti mbeca ciothe iria ciarutirwo. $paidOut nĩcirĩhĩtwo nginya rĩu.';
  }

  @override
  String shareOutStartsNextCycle(int cycle) {
    return 'Ũndũ ũyũ nĩwandĩkaga o irĩhi, ũkarĩhia mĩkopo ĩrĩa ĩtigarĩte, na ũkambĩrĩria Mũthiũrũrũko $cycle. Ndũngĩcookererio.';
  }

  @override
  String visitAssessmentPhotoCapReached(int max) {
    return 'Rũgendo rũrũ nĩrũrĩ na mbica $max.';
  }

  @override
  String get languageDraftBadge => 'rasimu';
}
