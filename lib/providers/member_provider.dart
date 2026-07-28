import 'package:flutter/foundation.dart';

import '../data/models/enums.dart';
import '../data/models/member.dart';
import '../data/repositories/member_repository.dart';

class MemberProvider extends ChangeNotifier {
  MemberProvider(this._repository);

  final MemberRepository _repository;

  List<MemberFinancials> _members = [];
  bool _loading = false;

  List<MemberFinancials> get members => _members;
  bool get loading => _loading;

  Future<void> load(String groupId) async {
    _loading = true;
    notifyListeners();
    _members = await _repository.financialsForGroup(groupId);
    _loading = false;
    notifyListeners();
  }

  Future<Member> addMember({
    required String groupId,
    required String name,
    String? phone,
    MemberRole role = MemberRole.member,
  }) async {
    final member = await _repository.addMember(
      groupId: groupId,
      name: name,
      phone: phone,
      role: role,
    );
    await load(groupId);
    return member;
  }

  Future<void> updateMember(Member member) async {
    await _repository.updateMember(member);
    await load(member.groupId);
  }

  /// Clears a member's meeting PIN — they set a fresh one at the next
  /// meeting unlock.
  Future<void> clearPin(Member member) async {
    await _repository.setPinHash(member.id, null);
    await load(member.groupId);
  }

  Future<double> attendanceRate(String memberId) =>
      _repository.attendanceRate(memberId);
}
