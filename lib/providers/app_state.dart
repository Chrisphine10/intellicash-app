import 'package:flutter/foundation.dart';

import '../data/models/enums.dart';
import '../data/models/group.dart';
import '../data/repositories/group_repository.dart';
import '../data/services/sync_service.dart';

enum AppStatus { loading, needsSetup, ready }

/// Root state: which group this device manages and the sync-queue badge.
class AppState extends ChangeNotifier {
  AppState({
    required GroupRepository groupRepository,
    required SyncService syncService,
  })  : _groupRepository = groupRepository,
        _syncService = syncService {
    _syncService.onQueueChanged = refreshPendingSync;
  }

  final GroupRepository _groupRepository;
  final SyncService _syncService;

  AppStatus _status = AppStatus.loading;
  Group? _group;
  int _pendingSync = 0;

  AppStatus get status => _status;
  Group? get group => _group;
  int get pendingSync => _pendingSync;
  SyncService get syncService => _syncService;

  Future<void> bootstrap() async {
    _group = await _groupRepository.currentGroup();
    _status = _group == null ? AppStatus.needsSetup : AppStatus.ready;
    await refreshPendingSync();
    _syncService.startWatchingConnectivity();
    notifyListeners();
  }

  /// Called by the setup wizard on finish: creates the group with its
  /// founding members and flips the app into the main shell.
  Future<void> createGroup({
    required String name,
    required int cycleNumber,
    required SavingsMode savingsMode,
    required double shareValue,
    required int maxSharesPerMeeting,
    required double socialFundAmount,
    required double interestRate,
    required InterestType interestType,
    required double loanMultiplier,
    required int defaultLoanTermMonths,
    required MeetingFrequency meetingFrequency,
    required List<int> meetingDays,
    required List<String> memberNames,
  }) async {
    await _groupRepository.createGroup(
      name: name,
      cycleNumber: cycleNumber,
      savingsMode: savingsMode,
      shareValue: shareValue,
      maxSharesPerMeeting: maxSharesPerMeeting,
      socialFundAmount: socialFundAmount,
      interestRate: interestRate,
      interestType: interestType,
      loanMultiplier: loanMultiplier,
      defaultLoanTermMonths: defaultLoanTermMonths,
      meetingFrequency: meetingFrequency,
      meetingDays: meetingDays,
      memberNames: memberNames,
    );
    await completeSetup();
  }

  /// Reloads the group after setup or settings changes.
  Future<void> completeSetup() async {
    _group = await _groupRepository.currentGroup();
    _status = AppStatus.ready;
    await refreshPendingSync();
    notifyListeners();
  }

  Future<void> updateGroup(Group group) async {
    await _groupRepository.updateGroup(group);
    _group = await _groupRepository.currentGroup();
    await refreshPendingSync();
    notifyListeners();
  }

  /// Re-reads the group from storage — used after an operation that writes the
  /// group directly (e.g. a share-out rolls the cycle).
  Future<void> reloadGroup() async {
    _group = await _groupRepository.currentGroup();
    // Status follows the group, always. It used to be left untouched here,
    // which was harmless while the only caller already had a group — but a
    // reload that FINDS a group (restoring one from the server onto a fresh
    // phone) left the app in needsSetup, so the root router kept showing
    // "set up your group" over a group that was now sitting in the database.
    _status = _group == null ? AppStatus.needsSetup : AppStatus.ready;
    await refreshPendingSync();
    notifyListeners();
  }

  Future<void> refreshPendingSync() async {
    _pendingSync = await _syncService.pendingCount();
    notifyListeners();
  }

  Future<int> syncNow() async {
    final synced = await _syncService.pushNow();
    await refreshPendingSync();
    return synced;
  }
}
