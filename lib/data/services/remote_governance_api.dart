import '../../core/network/api_client.dart';

/// A saving cycle as the server sees it.
class RemoteCycle {
  const RemoteCycle({
    required this.id,
    required this.number,
    required this.status,
    required this.startedAt,
    required this.meetings,
    required this.ledgerEntries,
    required this.editable,
    this.closedAt,
  });

  final String id;
  final int number;
  final String status;
  final DateTime? startedAt;
  final DateTime? closedAt;
  final int meetings;
  final int ledgerEntries;

  /// False once closed. A closed cycle's records stay READABLE — archiving is
  /// not deletion — so this gates editing, never viewing.
  final bool editable;

  factory RemoteCycle.fromJson(Map<String, dynamic> j) => RemoteCycle(
        id: '${j['id']}',
        number: (j['number'] as num?)?.toInt() ?? 0,
        status: '${j['status'] ?? 'ACTIVE'}',
        startedAt: DateTime.tryParse('${j['startedAt']}'),
        closedAt: j['closedAt'] == null ? null : DateTime.tryParse('${j['closedAt']}'),
        meetings: (j['meetings'] as num?)?.toInt() ?? 0,
        ledgerEntries: (j['ledgerEntries'] as num?)?.toInt() ?? 0,
        editable: j['editable'] == true,
      );
}

class RemoteCycles {
  const RemoteCycles({
    required this.currentNumber,
    required this.cycles,
    required this.canManage,
  });

  final int currentNumber;
  final List<RemoteCycle> cycles;
  final bool canManage;

  factory RemoteCycles.fromJson(Map<String, dynamic> j) => RemoteCycles(
        currentNumber: (j['currentCycleNumber'] as num?)?.toInt() ?? 1,
        cycles: ((j['cycles'] as List?) ?? const [])
            .map((e) => RemoteCycle.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        canManage: j['canManage'] == true,
      );
}

/// A group's own rules.
///
/// Only two things are configurable — fines and welfare net off a payout
/// rather than barring share-out, and loans always net off, so neither an
/// eligibility gate nor a loan strategy exists to set.
class RemoteGroupPolicy {
  const RemoteGroupPolicy({
    required this.defaultLoanTermMonths,
    required this.expenseFundType,
    required this.configured,
    required this.canConfigure,
  });

  final int defaultLoanTermMonths;
  final String expenseFundType;

  /// False when the group is running on platform defaults.
  final bool configured;
  final bool canConfigure;

  factory RemoteGroupPolicy.fromJson(Map<String, dynamic> j) {
    final policy = (j['policy'] as Map?) ?? const {};
    return RemoteGroupPolicy(
      defaultLoanTermMonths: (policy['defaultLoanTermMonths'] as num?)?.toInt() ?? 1,
      expenseFundType: '${policy['expenseFundType'] ?? 'SOCIAL'}',
      configured: policy['configured'] == true,
      canConfigure: j['canConfigure'] == true,
    );
  }
}

class RemoteGovernanceApi {
  RemoteGovernanceApi(this._client);

  final ApiClient _client;

  Future<RemoteCycles> cycles(String groupId) async {
    final data = await _client.getData('/groups/$groupId/cycles');
    return RemoteCycles.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Closes the current cycle and opens the next. Refused by the server while
  /// any meeting is unsealed, so the phone does not need to check first.
  Future<String> closeCycle(String groupId) async {
    final data = await _client.postData('/groups/$groupId/cycles/close', body: const {});
    final map = Map<String, dynamic>.from(data as Map);
    return '${map['message'] ?? 'Cycle closed.'}';
  }

  Future<RemoteGroupPolicy> policy(String groupId) async {
    final data = await _client.getData('/groups/$groupId/policy');
    return RemoteGroupPolicy.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<String> savePolicy(
    String groupId, {
    int? defaultLoanTermMonths,
    String? expenseFundType,
  }) async {
    final data = await _client.putData('/groups/$groupId/policy', body: {
      if (defaultLoanTermMonths != null) 'defaultLoanTermMonths': defaultLoanTermMonths,
      if (expenseFundType != null) 'expenseFundType': expenseFundType,
    });
    final map = Map<String, dynamic>.from(data as Map);
    return '${map['message'] ?? 'Saved.'}';
  }
}
