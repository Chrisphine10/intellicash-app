import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/domain_exception.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/id_map_repository.dart';
import '../../data/services/remote_payment_providers_api.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/payment_method_panel.dart';
import 'gateway_payment_sheet.dart';

/// What a member can pay online, and where the server books it: shares and
/// loan repayments into the loan fund, welfare contributions and fines into
/// the social fund. The meeting's own actions (Buy Shares, Social Fund,
/// Record Fine, Repayment) each charge their own kind.
enum PaymentPurpose {
  shares('SHARE_PURCHASE'),
  welfare('SOCIAL_FUND'),
  fine('FINE'),
  loanRepayment('LOAN_REPAYMENT');

  const PaymentPurpose(this.wire);
  final String wire;

  static PaymentPurpose? fromWire(String? wire) =>
      PaymentPurpose.values.where((p) => p.wire == wire).firstOrNull;
}

/// This book's link to the cloud, for charging a member online. Null when
/// the group is not backed up or the phone is offline — then everything is
/// recorded as cash, exactly as before.
class OnlineCharge {
  OnlineCharge._(this.remoteGroupId, this.remoteMembers, this.remoteMeetingId, this.switchedOff);

  final String remoteGroupId;
  final Map<String, String> remoteMembers;
  final String? remoteMeetingId;

  /// Online methods the group (or an admin) has switched off. The server
  /// refuses them anyway; this only stops the card offering them.
  final Set<PaymentMethod> switchedOff;

  bool canCharge(String? localMemberId) => localMemberId != null && remoteMembers.containsKey(localMemberId);

  static Future<OnlineCharge?> load(BuildContext context) async {
    final ConnectionProvider connection;
    try {
      connection = context.read<ConnectionProvider>();
    } on ProviderNotFoundException {
      return null;
    }
    if (!connection.isConnected) return null;
    final providersApi = providersApiOf(context);
    final group = context.read<AppState>().group;
    if (group == null) return null;
    final meeting = context.read<MeetingProvider>().activeMeeting;
    final idMap = IdMapRepository(AppDatabase.instance);
    final remoteGroup = await idMap.remoteId(MapEntity.group, group.id);
    if (remoteGroup == null) return null;
    final members = await idMap.mappings(MapEntity.member);
    final remoteMeeting = meeting == null
        ? null
        : await idMap.remoteId(MapEntity.meetingTwin, meeting.id) ?? await idMap.remoteId(MapEntity.meeting, meeting.id);
    return OnlineCharge._(remoteGroup, members, remoteMeeting, await switchedOffFor(providersApi, remoteGroup));
  }

  /// Read before any await: a sheet's context must not be used across one.
  static RemotePaymentProvidersApi? providersApiOf(BuildContext context) {
    try {
      return context.read<RemotePaymentProvidersApi>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  static Future<Set<PaymentMethod>> switchedOffFor(RemotePaymentProvidersApi? api, String remoteGroupId) async {
    if (api == null) return const {};
    try {
      final settings = await api.settings(remoteGroupId);
      return {
        if (!settings.isOn(GroupPaymentSettings.mpesa)) PaymentMethod.mpesa,
        if (!settings.isOn(GroupPaymentSettings.paystack)) PaymentMethod.paystack,
      };
    } catch (_) {
      // Unknown is not "off": offer both and let the server say no, in words.
      return const {};
    }
  }

  /// Sends the member the M-Pesa prompt (or a Paystack link) and returns once
  /// the server has confirmed the money; null if the treasurer backed out.
  Future<GatewayPaymentResult?> charge(
    BuildContext context, {
    required PaymentMethod method,
    required PaymentPurpose purpose,
    required double amount,
    required String localMemberId,
  }) {
    final member = context.read<MemberProvider>().members.where((m) => m.member.id == localMemberId).firstOrNull?.member;
    return showModalBottomSheet<GatewayPaymentResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => GatewayPaymentSheet.forGroup(
        sheetContext,
        groupRemoteId: remoteGroupId,
        method: method,
        amount: amount,
        purpose: purpose.wire,
        memberRemoteId: remoteMembers[localMemberId],
        meetingRemoteId: remoteMeetingId,
        memberName: member?.name,
        memberPhone: member?.phone,
      ),
    );
  }
}

/// How a payment was settled, ready to record: the method, the M-Pesa
/// Classic code a treasurer typed, or the confirmed online payment.
class SettledPayment {
  const SettledPayment(this.method, {this.reference, this.groupPaymentId});

  final PaymentMethod method;
  final String? reference;
  final String? groupPaymentId;
}

/// Completes a payment chosen on a [PaymentMethodPanel]. Cash and M-Pesa
/// Classic need nothing more; M-Pesa and Paystack prompt the member and wait
/// for the server to confirm the money. Null if the treasurer backed out.
Future<SettledPayment?> settlePayment(
  BuildContext context, {
  required OnlineCharge? online,
  required PaymentMethod method,
  required PaymentPurpose purpose,
  required double amount,
  required String localMemberId,
  String? typedCode,
}) async {
  if (!method.automated) {
    return SettledPayment(method, reference: method.needsReference ? typedCode?.trim().toUpperCase() : null);
  }
  if (online == null || !online.canCharge(localMemberId)) {
    final l10n = L10n.of(context);
    showAppSnack(context, l10n.requestPaymentMemberNotOnline, error: true);
    return null;
  }
  final result = await online.charge(context, method: method, purpose: purpose, amount: amount, localMemberId: localMemberId);
  if (result == null) return null;
  return SettledPayment(method, reference: result.reference, groupPaymentId: result.paymentId);
}

/// "How did X pay?" for the Social Fund switch: the payment card in a sheet,
/// then the payment itself when it is M-Pesa or Paystack.
Future<SettledPayment?> askHowPaid(
  BuildContext context, {
  required String memberName,
  required String localMemberId,
  required double amount,
  required OnlineCharge? online,
}) async {
  final chosen = await showModalBottomSheet<(PaymentMethod, String)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HowPaidSheet(
      memberName: memberName,
      online: online != null && online.canCharge(localMemberId),
      switchedOff: online?.switchedOff ?? const {},
    ),
  );
  if (chosen == null || !context.mounted) return null;
  return settlePayment(
    context,
    online: online,
    method: chosen.$1,
    purpose: PaymentPurpose.welfare,
    amount: amount,
    localMemberId: localMemberId,
    typedCode: chosen.$2,
  );
}

class _HowPaidSheet extends StatefulWidget {
  const _HowPaidSheet({required this.memberName, required this.online, required this.switchedOff});

  final String memberName;
  final bool online;
  final Set<PaymentMethod> switchedOff;

  @override
  State<_HowPaidSheet> createState() => _HowPaidSheetState();
}

class _HowPaidSheetState extends State<_HowPaidSheet> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaymentMethodPanel(
              title: l10n.howDidMemberPay(widget.memberName),
              value: _method,
              online: widget.online,
              switchedOff: widget.switchedOff,
              codeController: _code,
              onChanged: (m) => setState(() => _method = m),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: Icon(paymentActionIcon(_method), size: 18),
              label: Text(paymentActionLabel(l10n, _method, l10n.payConfirm)),
              onPressed: () {
                if (_method.needsReference && !(_formKey.currentState?.validate() ?? false)) return;
                Navigator.of(context).pop((_method, _code.text));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Record a confirmed online payment in this meeting's book, carrying the
/// server's payment id so the next sync links it instead of booking it again.
/// Used by the "online payments to add" banner.
Future<void> recordOnlinePayment(
  BuildContext context, {
  required PaymentPurpose purpose,
  required String memberId,
  required double amount,
  required PaymentMethod method,
  required String reference,
  required String groupPaymentId,
}) async {
  final appState = context.read<AppState>();
  final meetings = context.read<MeetingProvider>();
  final loans = context.read<LoanProvider>();
  final members = context.read<MemberProvider>();
  final group = appState.group!;
  switch (purpose) {
    case PaymentPurpose.shares:
      final shares = group.shareValue > 0 ? amount / group.shareValue : 0;
      if (shares < 1 || shares != shares.roundToDouble()) {
        throw const DomainException('That amount is not a whole number of shares.');
      }
      await meetings.buyShares(
        group: group,
        memberId: memberId,
        shares: shares.round(),
        paymentMethod: method,
        paymentReference: reference,
        groupPaymentId: groupPaymentId,
      );
    case PaymentPurpose.welfare:
      await meetings.setSocialFundPaid(group: group, memberId: memberId, paid: true, groupPaymentId: groupPaymentId);
    case PaymentPurpose.fine:
      await meetings.recordFine(
        memberId: memberId,
        amount: amount,
        reason: 'Paid online ($reference)',
        groupPaymentId: groupPaymentId,
      );
    case PaymentPurpose.loanRepayment:
      final open = (await loans.loansForMember(memberId))
          .where((l) => l.status == LoanStatus.active || l.status == LoanStatus.defaulted)
          .toList()
        ..sort((a, b) => a.disbursedAt.compareTo(b.disbursedAt));
      if (open.isEmpty) throw const DomainException('This member has no open loan on this phone.');
      await loans.repay(loan: open.first, amount: amount, meetingId: meetings.activeMeeting?.id, groupPaymentId: groupPaymentId);
  }
  await members.load(group.id);
  await appState.refreshPendingSync();
}
