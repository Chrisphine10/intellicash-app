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
    required this.loanInterestRateBps,
    required this.configured,
    required this.canConfigure,
  });

  final int defaultLoanTermMonths;
  final String expenseFundType;

  /// Basis points per month, FLAT on the original principal. 0 is legitimate —
  /// plenty of groups lend interest-free.
  final int loanInterestRateBps;

  /// False when the group is running on platform defaults.
  final bool configured;
  final bool canConfigure;

  factory RemoteGroupPolicy.fromJson(Map<String, dynamic> j) {
    final policy = (j['policy'] as Map?) ?? const {};
    return RemoteGroupPolicy(
      defaultLoanTermMonths: (policy['defaultLoanTermMonths'] as num?)?.toInt() ?? 1,
      expenseFundType: '${policy['expenseFundType'] ?? 'SOCIAL'}',
      loanInterestRateBps: (policy['loanInterestRateBps'] as num?)?.toInt() ?? 0,
      configured: policy['configured'] == true,
      canConfigure: j['canConfigure'] == true,
    );
  }
}

/// One payment out of the welfare fund.
class RemoteWelfareExpense {
  const RemoteWelfareExpense({
    required this.id,
    required this.category,
    required this.amountCents,
    required this.createdAt,
    this.payeeName,
    this.note,
  });

  final String id;
  final String category;
  final int amountCents;
  final DateTime? createdAt;

  /// Who received the money. Often NOT a member — welfare is commonly paid to
  /// a member's family or straight to a hospital.
  final String? payeeName;
  final String? note;

  factory RemoteWelfareExpense.fromJson(Map<String, dynamic> j) {
    // The amount lives on the ledger entry, not the expense row: the ledger is
    // the money, the expense record is the context around it.
    final ledger = (j['ledgerEntry'] as Map?) ?? const {};
    final payeeMember = (j['payeeMember'] as Map?) ?? const {};
    return RemoteWelfareExpense(
      id: '${j['id']}',
      category: '${j['category'] ?? 'OTHER'}',
      amountCents: (ledger['amountCents'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse('${ledger['createdAt'] ?? j['createdAt']}'),
      payeeName: (j['payeeName'] as String?) ?? (payeeMember['fullName'] as String?),
      note: j['note'] as String?,
    );
  }
}

/// Welfare spending, and — the figure that actually matters — what is LEFT.
class RemoteWelfare {
  const RemoteWelfare({
    required this.expenses,
    required this.spentCents,
    required this.balanceCents,
  });

  final List<RemoteWelfareExpense> expenses;
  final int spentCents;

  /// Contributions minus expenses. THIS is what share-out distributes, not the
  /// gross contributions — every shilling spent here is a shilling members do
  /// not receive at the end of the cycle.
  final int balanceCents;

  factory RemoteWelfare.fromJson(Map<String, dynamic> j) => RemoteWelfare(
        expenses: ((j['expenses'] as List?) ?? const [])
            .map((e) => RemoteWelfareExpense.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        spentCents: (j['spentCents'] as num?)?.toInt() ?? 0,
        balanceCents: (j['welfareBalanceCents'] as num?)?.toInt() ?? 0,
      );
}

class RemoteGovernanceApi {
  RemoteGovernanceApi(this._client);

  final ApiClient _client;

  Future<RemoteWelfare> welfare(String groupId) async {
    final data = await _client.getData('/groups/$groupId/welfare-expenses');
    return RemoteWelfare.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Records money paid out of the welfare fund.
  ///
  /// Goes straight to the server rather than into the offline queue, and that
  /// is deliberate: the fund balance is only knowable server-side, so two
  /// phones queueing expenses offline could each spend the same shilling. The
  /// server refuses an overdraw; a queue could not.
  ///
  /// Returns the welfare balance AFTER the payment — the money share-out will
  /// distribute if nothing else changes.
  Future<({String message, int balanceCents})> recordWelfareExpense(
    String groupId, {
    required int amountCents,
    required String category,
    // Required by the server: welfare leaves the fund in front of the members
    // it belongs to, during an open meeting — never between them.
    required String meetingId,
    String? payeeName,
    String? payeeMemberId,
    String? note,
  }) async {
    final data = await _client.postData('/groups/$groupId/welfare-expenses', body: {
      'amountCents': amountCents,
      'category': category,
      'meetingId': meetingId,
      if (payeeName != null && payeeName.isNotEmpty) 'payeeName': payeeName,
      if (payeeMemberId != null) 'payeeMemberId': payeeMemberId,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    final map = Map<String, dynamic>.from(data as Map);
    return (
      message: 'Welfare payment recorded.',
      balanceCents: (map['welfareBalanceCents'] as num?)?.toInt() ?? 0,
    );
  }

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
    int? loanInterestRateBps,
  }) async {
    final data = await _client.putData('/groups/$groupId/policy', body: {
      if (defaultLoanTermMonths != null) 'defaultLoanTermMonths': defaultLoanTermMonths,
      if (expenseFundType != null) 'expenseFundType': expenseFundType,
      if (loanInterestRateBps != null) 'loanInterestRateBps': loanInterestRateBps,
    });
    final map = Map<String, dynamic>.from(data as Map);
    return '${map['message'] ?? 'Saved.'}';
  }
}
