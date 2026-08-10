import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/services/group_restore_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Getting an existing group back onto a phone.
///
/// The failure this prevents: a treasurer reinstalls the app, is offered only
/// "Set up group", and creates a SECOND group with a second code. The savings
/// history is then split across two records that cannot be reconciled, and
/// nobody notices until a share-out does not add up.
void main() {
  late Directory tempDir;
  late GroupRepository groups;
  late MemberRepository members;
  late IdMapRepository idMap;
  late _FakeApi api;
  late GroupRestoreService service;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_restore');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;

    groups = GroupRepository(AppDatabase.instance);
    members = MemberRepository(AppDatabase.instance);
    idMap = IdMapRepository(AppDatabase.instance);
    api = _FakeApi();
    service = GroupRestoreService(
      api: api,
      groups: groups,
      members: members,
      idMap: idMap,
    );
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  test('brings the group and its members onto a phone that has neither',
      () async {
    final result = await service.restore('remote-g1');

    expect(result.alreadyPresent, isFalse);
    expect(result.group, isNotNull);
    expect(result.group!.name, 'Tujijenge Women');
    expect(result.group!.shareValue, 500);
    expect(result.group!.cycleNumber, 3);
    expect(result.membersRestored, 2);

    final local = await members.membersForGroup(result.group!.id);
    expect(local.map((m) => m.name), containsAll(['Mary Njeri', 'Jane Wanjiru']));
  });

  test('maps the local group to the remote one, so meetings can sync back',
      () async {
    final result = await service.restore('remote-g1');

    final mappings = await idMap.mappings(MapEntity.group);
    expect(mappings[result.group!.id], 'remote-g1');
  });

  test('maps every member, so a share purchase knows whose it is', () async {
    // Without member mappings the group restores but nothing it records can be
    // pushed — every entry would reference a member the server has never heard
    // of.
    final result = await service.restore('remote-g1');
    final local = await members.membersForGroup(result.group!.id);
    final mappings = await idMap.mappings(MapEntity.member);

    for (final member in local) {
      expect(mappings[member.id], isNotNull,
          reason: '${member.name} was restored without a remote id');
    }
  });

  test('restoring twice does not create a second group', () async {
    // A reconnect can legitimately trigger this twice, and duplicating the
    // group is the exact harm the feature exists to prevent.
    final first = await service.restore('remote-g1');
    final second = await service.restore('remote-g1');

    expect(second.alreadyPresent, isTrue);
    expect(second.group!.id, first.group!.id);

    final mappings = await idMap.mappings(MapEntity.group);
    expect(mappings.length, 1);
    expect(await members.membersForGroup(first.group!.id), hasLength(2));
  });

  test('a member fetch that fails still leaves the group mapped', () async {
    // Half a restore beats none: the group is on the phone and bound, so the
    // treasurer is not sent back to "Set up group". Members arrive next sync.
    api.membersThrow = true;

    final result = await service.restore('remote-g1');

    expect(result.group, isNotNull);
    expect(result.membersRestored, 0);
    final mappings = await idMap.mappings(MapEntity.group);
    expect(mappings[result.group!.id], 'remote-g1');
  });

  test('reports whether the phone already holds a remote group', () async {
    expect(await service.localIdFor('remote-g1'), isNull);

    final result = await service.restore('remote-g1');

    expect(await service.localIdFor('remote-g1'), result.group!.id);
    expect(await service.localIdFor('some-other-group'), isNull);
  });
}

class _FakeApi implements RemoteApiLike {
  bool membersThrow = false;

  @override
  Future<RemoteGroup> groupDetail(String groupId) async {
    return RemoteGroup.fromJson({
      'id': groupId,
      'name': 'Tujijenge Women',
      'code': 'IWL-KBU-0001',
      'phase': 'ACTIVE',
      'county': 'Kiambu',
      // The real wire field names. The server sends money in CENTS and spells
      // the share cap out per member — a fixture using the Dart field names
      // instead silently restored a group with a share value of zero.
      'shareValueCents': 50000,
      'maxSharesPerMemberPerMeeting': 5,
      'cycleNumber': 3,
    });
  }

  @override
  Future<List<RemoteMember>> groupMembers(String groupId) async {
    if (membersThrow) throw Exception('offline');
    return [
      RemoteMember.fromJson({
        'id': 'remote-m1',
        'fullName': 'Mary Njeri',
        'phone': '+254700000006',
        'role': 'MEMBER',
        'status': 'ACTIVE',
      }),
      RemoteMember.fromJson({
        'id': 'remote-m2',
        'fullName': 'Jane Wanjiru',
        'phone': '+254700000008',
        'role': 'MEMBER',
        'status': 'ACTIVE',
      }),
    ];
  }
}
