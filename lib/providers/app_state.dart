import 'dart:async';

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
    Future<String?> Function(String localGroupId)? remoteGroupIdFor,
  })  : _groupRepository = groupRepository,
        _syncService = syncService,
        _remoteGroupIdFor = remoteGroupIdFor {
    _syncService.onQueueChanged = () {
      // Bumped on every finished sync so screens showing local figures (the
      // dashboard) know to reload: a sync can pull records down as well as
      // push them, and a screen left as it was reads as "nothing happened".
      _syncRevision++;
      refreshPendingSync();
      unawaited(refreshBoundRemoteGroup());
    };
  }

  /// Which server group a local group is linked to, from the id map. Optional
  /// so the many tests that build an AppState need not supply one.
  final Future<String?> Function(String localGroupId)? _remoteGroupIdFor;
  String? _boundRemoteGroupId;

  /// The server group the book on this phone is linked to, or null when it has
  /// never been linked. The root uses it to keep one group's book from opening
  /// for another group's account.
  String? get boundRemoteGroupId => _boundRemoteGroupId;

  Future<void> refreshBoundRemoteGroup() async {
    final lookup = _remoteGroupIdFor;
    final group = _group;
    String? next;
    if (lookup != null && group != null) {
      try {
        next = await lookup(group.id);
      } catch (_) {
        next = _boundRemoteGroupId;
      }
    }
    if (next != _boundRemoteGroupId) {
      _boundRemoteGroupId = next;
      notifyListeners();
    }
  }

  final GroupRepository _groupRepository;
  final SyncService _syncService;

  AppStatus _status = AppStatus.loading;
  Group? _group;
  int _pendingSync = 0;
  int _syncRevision = 0;

  AppStatus get status => _status;
  Group? get group => _group;
  int get pendingSync => _pendingSync;

  /// Increases after every completed sync.
  int get syncRevision => _syncRevision;
  SyncService get syncService => _syncService;

  Future<void> bootstrap() async {
    _group = await _groupRepository.currentGroup();
    _status = _group == null ? AppStatus.needsSetup : AppStatus.ready;
    await refreshBoundRemoteGroup();
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
    await refreshBoundRemoteGroup();
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
    await refreshBoundRemoteGroup();
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
