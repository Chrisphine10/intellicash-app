import 'package:flutter/foundation.dart';

import '../data/models/enums.dart';
import '../data/models/group.dart';
import '../data/models/meeting.dart';
import '../data/models/transactions.dart';
import '../data/repositories/meeting_repository.dart';

/// State for the meetings tab and the in-meeting session flow.
class MeetingProvider extends ChangeNotifier {
  MeetingProvider(this._repository);

  final MeetingRepository _repository;

  List<MeetingListItem> _meetings = [];
  Meeting? _activeMeeting;
  MeetingTotals _totals = MeetingTotals.empty;
  Map<String, bool> _attendance = {};
  bool _loading = false;

  List<MeetingListItem> get meetings => _meetings;
  Meeting? get activeMeeting => _activeMeeting;
  MeetingTotals get totals => _totals;
  Map<String, bool> get attendance => _attendance;
  bool get loading => _loading;

  int get presentCount => _attendance.values.where((p) => p).length;

  Future<void> load(String groupId) async {
    _loading = true;
    notifyListeners();
    _meetings = await _repository.meetingsForGroup(groupId);
    _activeMeeting = await _repository.openMeeting(groupId);
    if (_activeMeeting != null) {
      await _refreshSession();
    }
    _loading = false;
    notifyListeners();
  }

  Future<Meeting> startMeeting(Group group, {List<String>? unlockedBy}) async {
    final meeting =
        await _repository.startMeeting(group, unlockedBy: unlockedBy);
    _activeMeeting = meeting;
    await load(group.id);
    return meeting;
  }

  /// Loads a past meeting into the session view (read-only when closed).
  Future<void> openSession(Meeting meeting) async {
    _activeMeeting = meeting;
    await _refreshSession();
    notifyListeners();
  }

  Future<void> toggleAttendance(String memberId) async {
    final meeting = _requireMeeting();
    final present = !(_attendance[memberId] ?? false);
    await _repository.setAttendance(
      meeting: meeting,
      memberId: memberId,
      present: present,
    );
    _attendance[memberId] = present;
    _totals = await _repository.totals(meeting.id);
    notifyListeners();
  }

  Future<SharePurchase> buyShares({
    required Group group,
    required String memberId,
    required int shares,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    String? paymentReference,
  }) async {
    final meeting = _requireMeeting();
    final purchase = await _repository.recordSharePurchase(
      meeting: meeting,
      group: group,
      memberId: memberId,
      shares: shares,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
    );
    await _refreshSession();
    notifyListeners();
    return purchase;
  }

  Future<void> recordFine({
    required String memberId,
    required double amount,
    required String reason,
  }) async {
    final meeting = _requireMeeting();
    await _repository.recordFine(
      meeting: meeting,
      memberId: memberId,
      amount: amount,
      reason: reason,
    );
    await _refreshSession();
    notifyListeners();
  }

  Future<int> collectSocialFund(Group group) async {
    final meeting = _requireMeeting();
    final collected = await _repository.collectSocialFundFromPresent(
      meeting: meeting,
      group: group,
    );
    await _refreshSession();
    notifyListeners();
    return collected;
  }

  /// Member ids who have paid the social fund in the active meeting.
  Future<Set<String>> socialFundPayers() {
    final meeting = _requireMeeting();
    return _repository.socialFundPayers(meeting.id);
  }

  /// Marks a single member paid / not-paid for the social fund.
  Future<void> setSocialFundPaid({
    required Group group,
    required String memberId,
    required bool paid,
  }) async {
    final meeting = _requireMeeting();
    await _repository.setSocialFundPaid(
      meeting: meeting,
      group: group,
      memberId: memberId,
      paid: paid,
    );
    await _refreshSession();
    notifyListeners();
  }

  Future<List<LedgerEntry>> ledger() {
    final meeting = _requireMeeting();
    return _repository.ledger(meeting.id);
  }

  Future<void> closeMeeting(String groupId) async {
    final meeting = _requireMeeting();
    _activeMeeting = await _repository.closeMeeting(meeting);
    await load(groupId);
  }

  /// Re-pulls totals after a loan action recorded against this meeting.
  Future<void> refreshTotals() async {
    if (_activeMeeting == null) return;
    _totals = await _repository.totals(_activeMeeting!.id);
    notifyListeners();
  }

  Future<void> _refreshSession() async {
    final meeting = _activeMeeting;
    if (meeting == null) return;
    _totals = await _repository.totals(meeting.id);
    _attendance = await _repository.attendanceMap(meeting.id);
  }

  Meeting _requireMeeting() {
    final meeting = _activeMeeting;
    if (meeting == null) {
      throw StateError('No meeting session is loaded.');
    }
    return meeting;
  }
}
