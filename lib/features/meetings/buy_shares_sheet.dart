import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/user_message.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/id_map_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/payment_method_panel.dart';
import 'gateway_payment_sheet.dart';
import 'online_charge.dart';

/// Pick a member, a share count, and how they paid — the total computes
/// itself before the purchase is committed to the ledger.
class BuySharesSheet extends StatefulWidget {
  const BuySharesSheet({super.key});

  @override
  State<BuySharesSheet> createState() => _BuySharesSheetState();
}

class _BuySharesSheetState extends State<BuySharesSheet> {
  String? _memberId;
  int _shares = 1;
  PaymentMethod _method = PaymentMethod.cash;
  final _refCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCloudIds());
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final group = context.watch<AppState>().group!;
    final members = context.watch<MemberProvider>().members;
    final attendance = context.watch<MeetingProvider>().attendance;
    final total = _shares * group.shareValue;

    return SingleChildScrollView(
      // A small phone cannot fit the whole sheet: let it scroll.
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.meetingHubBuyShares, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _memberId,
              decoration: InputDecoration(labelText: l10n.disburseLoanSelectMember),
              dropdownColor: AppColors.surfaceRaised,
              items: [
                for (final financials in members)
                  DropdownMenuItem(
                    value: financials.member.id,
                    // A member marked absent may still pay (by M-Pesa, or through
                    // someone), so they are not hidden - but the treasurer sees
                    // it before recording, rather than finding out from the
                    // attendance list afterwards.
                    child: Text(
                      (attendance[financials.member.id] ?? false)
                          ? financials.member.name
                          : '${financials.member.name} · ${l10n.buySharesAbsentTag}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _memberId = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Shares (1–${group.maxSharesPerMeeting})',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                IconButton.outlined(
                  onPressed: _shares > 1
                      ? () => setState(() => _shares--)
                      : null,
                  icon: const Icon(Icons.remove, size: 18),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$_shares',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton.filled(
                  onPressed: _shares < group.maxSharesPerMeeting
                      ? () => setState(() => _shares++)
                      : null,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: AppColors.surfaceRaised,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_shares share(s) × ${Formatters.money(group.shareValue)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: ${Formatters.money(total)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: PaymentMethodPanel(
                value: _method,
                online: _canChargeOnline,
                switchedOff: _switchedOff,
                codeController: _refCtrl,
                onChanged: (method) => setState(() {
                  _method = method;
                  if (!method.needsReference) _refCtrl.clear();
                }),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _memberId == null || _saving
                  ? null
                  : (_method.automated ? _charge : () => _record()),
              icon: Icon(paymentActionIcon(_method), size: 18),
              label: Text(paymentActionLabel(l10n, _method, l10n.buySharesRecordPurchase)),
            ),
          ],
        ),
      ),
    );
  }

  final _idMap = IdMapRepository(AppDatabase.instance);
  String? _remoteGroupId;
  Map<String, String> _remoteMemberIds = const {};
  Set<PaymentMethod> _switchedOff = const {};

  /// Online charging needs a live connection AND this group mirrored to the
  /// backend — the gateway charges against the cloud group, not the local one.
  bool get _canChargeOnline =>
      context.read<ConnectionProvider>().isConnected && _remoteGroupId != null;

  Future<void> _loadCloudIds() async {
    final group = context.read<AppState>().group;
    if (group == null) return;
    final connected = context.read<ConnectionProvider>().isConnected;
    final providersApi = OnlineCharge.providersApiOf(context);
    final remoteGroupId = await _idMap.remoteId(MapEntity.group, group.id);
    final members = await _idMap.mappings(MapEntity.member);
    if (!mounted) return;
    final switchedOff = remoteGroupId == null || !connected
        ? const <PaymentMethod>{}
        : await OnlineCharge.switchedOffFor(providersApi, remoteGroupId);
    if (!mounted) return;
    setState(() {
      _remoteGroupId = remoteGroupId;
      _remoteMemberIds = members;
      _switchedOff = switchedOff;
    });
  }

  /// Sends the member an M-Pesa prompt (or makes a Paystack link). When it
  /// settles, the confirmation code drops into the reference field and the
  /// purchase is recorded against it.
  Future<void> _charge() async {
    final group = context.read<AppState>().group!;
    final memberName = context
        .read<MemberProvider>()
        .members
        .where((f) => f.member.id == _memberId)
        .firstOrNull
        ?.member;
    final meeting = context.read<MeetingProvider>().activeMeeting;
    final meetingRemoteId = meeting == null
        ? null
        : await _idMap.remoteId(MapEntity.meetingTwin, meeting.id) ??
            await _idMap.remoteId(MapEntity.meeting, meeting.id);
    if (!mounted) return;
    final result = await showModalBottomSheet<GatewayPaymentResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => GatewayPaymentSheet.forGroup(
        sheetContext,
        groupRemoteId: _remoteGroupId!,
        method: _method,
        amount: _shares * group.shareValue,
        purpose: 'SHARE_PURCHASE',
        memberRemoteId: _remoteMemberIds[_memberId],
        meetingRemoteId: meetingRemoteId,
        memberName: memberName?.name,
        memberPhone: memberName?.phone,
      ),
    );
    if (result == null || !mounted) return;
    _refCtrl.text = result.reference;
    // The server has already put this payment in the group's books; the id
    // makes this phone's record of it the same entry, not a second one.
    await _record(groupPaymentId: result.paymentId);
  }

  Future<void> _record({String? groupPaymentId}) async {
    final ref = _refCtrl.text.trim().toUpperCase();
    // M-Pesa Classic: the code from the member's SMS is the proof of payment.
    if (_method.needsReference && !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final meetingProvider = context.read<MeetingProvider>();
    final memberProvider = context.read<MemberProvider>();
    final group = appState.group!;
    try {
      await meetingProvider.buyShares(
        group: group,
        memberId: _memberId!,
        shares: _shares,
        paymentMethod: _method,
        paymentReference: ref,
        groupPaymentId: groupPaymentId,
      );
      await memberProvider.load(group.id);
      await appState.refreshPendingSync();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context,
          'Recorded $_shares share(s) via ${_method.label} — ${Formatters.money(_shares * group.shareValue)}.');
    } on DomainException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (e) {
      // Anything else (a storage fault) must say so, never fail silently.
      if (mounted) showAppSnack(context, userMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
