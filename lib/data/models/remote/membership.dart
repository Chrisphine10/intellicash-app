/// One group a person belongs to.
///
/// People commonly save with more than one VSLA at a time, so the app holds a
/// list of these and lets the member switch which one they are looking at.
class Membership {
  const Membership({
    required this.membershipId,
    required this.memberId,
    required this.groupId,
    required this.groupName,
    required this.memberName,
    required this.isActive,
    this.groupCode,
  });

  final String membershipId;
  final String memberId;
  final String groupId;
  final String groupName;
  final String memberName;

  /// Whether this is the group currently in view. Everything the API returns
  /// — passbook, ledger, meetings — is scoped to the active one.
  final bool isActive;

  final String? groupCode;

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        membershipId: '${json['membershipId'] ?? ''}',
        memberId: '${json['memberId'] ?? ''}',
        groupId: '${json['groupId'] ?? ''}',
        groupName: '${json['groupName'] ?? ''}',
        memberName: '${json['memberName'] ?? ''}',
        isActive: json['isActive'] == true,
        groupCode: json['groupCode']?.toString(),
      );
}

/// A member's outstanding request to be let into a group.
class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.requestedName,
    required this.phone,
    required this.status,
    this.reviewNotes,
    this.createdAt,
    this.willLinkToMemberId,
    this.willLinkToMemberName,
  });

  final String id;
  final String requestedName;
  final String phone;

  /// PENDING | APPROVED | REJECTED
  final String status;
  final String? reviewNotes;
  final DateTime? createdAt;

  /// Set when this phone is already on the group's roster.
  ///
  /// Nothing verifies the number someone types at sign-up, so a match is a
  /// claim rather than proof — accepting hands over that member's existing
  /// savings, and the official has to be told before they decide.
  final String? willLinkToMemberId;
  final String? willLinkToMemberName;

  bool get isPending => status == 'PENDING';

  /// Whether accepting would attach this login to savings already recorded.
  bool get takesOverExistingRecords => willLinkToMemberName != null;

  factory JoinRequest.fromJson(Map<String, dynamic> json) => JoinRequest(
        id: '${json['id'] ?? ''}',
        requestedName: '${json['requestedName'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
        status: '${json['status'] ?? 'PENDING'}',
        reviewNotes: json['reviewNotes']?.toString(),
        createdAt: DateTime.tryParse('${json['createdAt']}'),
        willLinkToMemberId: json['willLinkToMemberId']?.toString(),
        willLinkToMemberName: json['willLinkToMemberName']?.toString(),
      );
}

/// A group's shareable invite link, and the QR code drawn from it.
///
/// The token is deliberately NOT the group code. Codes read `IWL-KBU-0001` and
/// can be counted upwards, so a link built on one would let anybody enumerate
/// every group on the platform. This one is random and can be reissued, which
/// is what makes a printed poster revocable.
class GroupJoinLink {
  const GroupJoinLink({
    required this.groupId,
    required this.groupName,
    required this.token,
    required this.url,
  });

  final String groupId;
  final String groupName;
  final String token;

  /// The full address a QR code encodes and a person taps.
  final String url;

  factory GroupJoinLink.fromJson(Map<String, dynamic> json) {
    final group = json['group'];
    return GroupJoinLink(
      groupId: group is Map ? group['id']?.toString() ?? '' : '',
      groupName: group is Map ? group['name']?.toString() ?? '' : '',
      token: json['token']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}
