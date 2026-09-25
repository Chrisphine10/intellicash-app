import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/remote/remote_models.dart';

/// Which optional modules (Intelli-Store, Voting) each server group can use.
///
/// An IWL admin switches them on per programme; both start off. The phone
/// learns the answer from the group's detail whenever it has signal and keeps
/// the last answer, so a meeting held offline shows the same tiles it showed
/// yesterday. A group the phone has never heard about, or a book not linked to
/// the server, gets neither: showing a module the server would refuse is worse
/// than hiding one it would allow.
class ModuleSwitches extends ChangeNotifier {
  ModuleSwitches({this.remoteIdFor});

  static const _kModules = 'group_modules_v1';

  /// Maps this phone's book to its server group, when it is linked.
  final Future<String?> Function(String localGroupId)? remoteIdFor;

  final Map<String, GroupModules> _byRemoteGroup = {};

  Future<void> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_kModules);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _byRemoteGroup
        ..clear()
        ..addAll({
          for (final entry in decoded.entries)
            if (entry.value is Map<String, dynamic>)
              entry.key: GroupModules.fromJson(entry.value as Map<String, dynamic>),
        });
      notifyListeners();
    } catch (_) {
      // A damaged cache means "not known yet": modules stay off until the
      // server answers again.
    }
  }

  /// The modules for a server group; off when unknown.
  GroupModules forRemoteGroup(String? remoteGroupId) =>
      (remoteGroupId == null ? null : _byRemoteGroup[remoteGroupId]) ?? const GroupModules();

  /// The modules for this phone's book, through its link to the server.
  Future<GroupModules> forLocalGroup(String localGroupId) async {
    final lookup = remoteIdFor;
    if (lookup == null) return const GroupModules();
    return forRemoteGroup(await lookup(localGroupId));
  }

  /// Records what the server said. Only a real answer ever lands here.
  Future<void> remember(String remoteGroupId, GroupModules modules) async {
    final known = _byRemoteGroup[remoteGroupId];
    if (known != null && known.store == modules.store && known.voting == modules.voting) return;
    _byRemoteGroup[remoteGroupId] = modules;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(
        _kModules,
        jsonEncode({for (final entry in _byRemoteGroup.entries) entry.key: entry.value.toJson()}),
      );
    } catch (_) {
      // Kept in memory for this session; the next sync writes it again.
    }
  }
}
