import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../core/utils/app_logger.dart';
import '../data/models/member.dart';
import '../data/models/remote/remote_models.dart';
import '../data/repositories/id_map_repository.dart';
import '../data/repositories/meeting_repository.dart';
import '../data/repositories/member_repository.dart';
import '../data/services/remote_api.dart';
import '../data/services/write_sync_service.dart';

/// Drives Phase 2a write-path sync: binding the local group to a backend
/// group, matching members, and pushing closed meetings.
class SyncProvider extends ChangeNotifier {
  SyncProvider({
    required IdMapRepository idMap,
    required RemoteApi remoteApi,
    required WriteSyncService syncService,
    required MemberRepository memberRepository,
    required MeetingRepository meetingRepository,
  })  : _idMap = idMap,
        _remoteApi = remoteApi,
        _syncService = syncService,
        _members = memberRepository,
        _meetings = meetingRepository;

  final IdMapRepository _idMap;
  final RemoteApi _remoteApi;
  final WriteSyncService _syncService;
  final MemberRepository _members;
  final MeetingRepository _meetings;

  bool _busy = false;
  String? _error;
  String? _remoteGroupId;
  int _mappedMembers = 0;
  int _localMembers = 0;
  List<Member> _unmatched = [];
  String? _lastSummary;

  bool get busy => _busy;
  String? get error => _error;
  bool get isGroupBound => _remoteGroupId != null;
  String? get remoteGroupId => _remoteGroupId;
  int get mappedMembers => _mappedMembers;
  int get localMembers => _localMembers;
  List<Member> get unmatchedMembers => _unmatched;
  String? get lastSummary => _lastSummary;
  bool get allMembersMapped => _localMembers > 0 && _unmatched.isEmpty;

  /// Loads the current binding state for a local group.
  Future<void> loadStatus(String localGroupId) async {
    _remoteGroupId = await _idMap.remoteId(MapEntity.group, localGroupId);
    final local = await _members.membersForGroup(localGroupId);
    _localMembers = local.length;
    final memberMap = await _idMap.mappings(MapEntity.member);
    _unmatched =
        local.where((m) => !memberMap.containsKey(m.id)).toList();
    _mappedMembers = _localMembers - _unmatched.length;
    notifyListeners();
  }

  /// Binds the local group to [remoteGroup] and auto-matches members by
  /// phone (last 9 digits) then exact name.
  Future<void> bindGroupAndMatch(
    String localGroupId,
    RemoteGroup remoteGroup,
  ) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _idMap.put(MapEntity.group, localGroupId, remoteGroup.id,
          groupId: remoteGroup.id);
      _remoteGroupId = remoteGroup.id;

      final remoteMembers = await _remoteApi.groupMembers(remoteGroup.id);
      final localMembers = await _members.membersForGroup(localGroupId);

      final byPhone = <String, RemoteMember>{};
      final byName = <String, RemoteMember>{};
      for (final r in remoteMembers) {
        final p = _phoneKey(r.phone);
        if (p != null) byPhone[p] = r;
        byName[r.fullName.toLowerCase().trim()] = r;
      }

      var matched = 0;
      final unmatched = <Member>[];
      for (final m in localMembers) {
        final phoneKey = _phoneKey(m.phone);
        final remote = (phoneKey != null ? byPhone[phoneKey] : null) ??
            byName[m.name.toLowerCase().trim()];
        if (remote != null) {
          await _idMap.put(MapEntity.member, m.id, remote.id,
              groupId: remoteGroup.id);
          matched++;
        } else {
          unmatched.add(m);
        }
      }

      _localMembers = localMembers.length;
      _mappedMembers = matched;
      _unmatched = unmatched;
      log.info('sync',
          'Bound group -> ${remoteGroup.code}: matched $matched/${localMembers.length} members');
    } on ApiException catch (e) {
      _error = e.message;
      log.error('sync', 'Bind failed', e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Manually links one local member to a backend member.
  Future<void> linkMember(Member local, RemoteMember remote) async {
    await _idMap.put(MapEntity.member, local.id, remote.id,
        groupId: _remoteGroupId);
    _unmatched = _unmatched.where((m) => m.id != local.id).toList();
    _mappedMembers++;
    notifyListeners();
  }

  Future<List<RemoteMember>> remoteMembers() async {
    final gid = _remoteGroupId;
    if (gid == null) return const [];
    return _remoteApi.groupMembers(gid);
  }

  /// Syncs every closed local meeting for the group. Returns a summary.
  Future<String> syncClosedMeetings(String localGroupId) async {
    if (_remoteGroupId == null) {
      _error = 'Link the group to the backend first.';
      notifyListeners();
      return _error!;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final items = await _meetings.meetingsForGroup(localGroupId);
      final closed = items.where((i) => !i.meeting.isOpen).toList();
      var meetingsSynced = 0;
      var records = 0;
      var conflicts = 0;
      var skippedFines = 0;
      for (final item in closed) {
        try {
          final result = await _syncService.syncMeeting(item.meeting);
          meetingsSynced++;
          records += result.syncedCount;
          conflicts += result.conflicts.length;
          skippedFines += result.skippedFines;
        } on ApiException catch (e) {
          _error = e.message;
          log.error('sync', 'Meeting ${item.meeting.number} sync failed', e);
        }
      }
      _lastSummary =
          'Synced $records record(s) across $meetingsSynced meeting(s)'
          '${conflicts > 0 ? ' · $conflicts conflict(s)' : ''}'
          '${skippedFines > 0 ? ' · $skippedFines fine(s) skipped' : ''}.';
      return _lastSummary!;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> unlink(String localGroupId) async {
    await _idMap.clearAll();
    _remoteGroupId = null;
    _mappedMembers = 0;
    _unmatched = [];
    _lastSummary = null;
    await loadStatus(localGroupId);
  }

  /// Last 9 digits of a phone, ignoring country code / formatting.
  static String? _phoneKey(String? phone) {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return null;
    return digits.substring(digits.length - 9);
  }
}
