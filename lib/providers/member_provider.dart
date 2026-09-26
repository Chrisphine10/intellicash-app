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
    // The same rule as handing an office over: a new chairperson steps the
    // sitting one down, so the group never has two.
    if (role.isSingleHolder) {
      final current = await _repository.membersForGroup(groupId);
      for (final other in current) {
        if (other.role == role) {
          await _repository.updateMember(other.copyWith(role: MemberRole.member));
        }
      }
    }
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
    // One chairperson, one secretary, one treasurer: handing an office over
    // steps the previous holder down, as the server does when it syncs. Left
    // alone, the phone would show two chairpeople and count both towards the
    // meeting unlock.
    if (member.role.isSingleHolder) {
      final current = await _repository.membersForGroup(member.groupId);
      for (final other in current) {
        if (other.id != member.id && other.role == member.role) {
          await _repository.updateMember(other.copyWith(role: MemberRole.member));
        }
      }
    }
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
