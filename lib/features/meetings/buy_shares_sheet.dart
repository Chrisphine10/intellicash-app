import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../providers/app_state.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/member_provider.dart';
import '../../core/database/app_database.dart';
import '../../data/repositories/id_map_repository.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import 'gateway_payment_sheet.dart';

/// Icon for each payment method (enum stores a string key to stay
/// Flutter-free in the data layer).
IconData paymentIcon(PaymentMethod method) => switch (method) {
      PaymentMethod.cash => Icons.payments_outlined,
      PaymentMethod.mpesa => Icons.phone_android,
      PaymentMethod.mpesaClassic => Icons.dialpad,
      PaymentMethod.paystack => Icons.account_balance_wallet_outlined,
      PaymentMethod.card => Icons.credit_card,
    };

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

  String _refLabel(PaymentMethod method) => switch (method) {
        PaymentMethod.mpesa => 'M-Pesa transaction code',
        PaymentMethod.mpesaClassic => 'M-Pesa code (Paybill / Till)',
        PaymentMethod.paystack => 'Paystack reference',
        PaymentMethod.card => 'Card authorization reference',
        _ => 'Reference',
      };

  @override
  Widget build(BuildContext context) {
    final group = context.watch<AppState>().group!;
    final members = context.watch<MemberProvider>().members;
    final total = _shares * group.shareValue;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Buy Shares', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _memberId,
            decoration: const InputDecoration(labelText: 'Select Member'),
            dropdownColor: AppColors.surfaceRaised,
            items: [
              for (final financials in members)
                DropdownMenuItem(
                  value: financials.member.id,
                  child: Text(financials.member.name,
                      style: const TextStyle(fontSize: 14)),
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
          const SectionLabel('Payment method'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final method in PaymentMethod.values)
                ChoiceChip(
                  avatar: Icon(
                    paymentIcon(method),
                    size: 16,
                    color: _method == method
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  label: Text(method.label),
                  selected: _method == method,
                  selectedColor: AppColors.primaryTint,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _method == method
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                  onSelected: (_) => setState(() {
                    _method = method;
                    if (!method.needsReference) _refCtrl.clear();
                  }),
                ),
            ],
          ),
          if (_method.automated) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _canChargeOnline
                          ? 'Tap Charge ${_method.label} to send the request to '
                              'the member. The confirmation code is filled in '
                              'for you once they pay.'
                          : 'Automatic ${_method.label} needs this group backed '
                              'up to the cloud. For now, record the '
                              'confirmation code below by hand.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_method.needsReference) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _refCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: _refLabel(_method),
                hintText: _method == PaymentMethod.mpesa ? 'e.g. SLK4H2X9Y1' : null,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_method.automated && _canChargeOnline) ...[
            FilledButton.icon(
              onPressed: _memberId == null || _saving ? null : _charge,
              icon: Icon(
                  _method == PaymentMethod.mpesa
                      ? Icons.phone_android
                      : Icons.open_in_new,
                  size: 18),
              label: Text('Charge ${_method.label}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _memberId == null || _saving ? null : _record,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Enter Code by Hand'),
            ),
          ] else
            FilledButton.icon(
              onPressed: _memberId == null || _saving ? null : _record,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Record Purchase'),
            ),
        ],
      ),
    );
  }

  final _idMap = IdMapRepository(AppDatabase.instance);
  String? _remoteGroupId;
  Map<String, String> _remoteMemberIds = const {};

  /// Online charging needs a live connection AND this group mirrored to the
  /// backend — the gateway charges against the cloud group, not the local one.
  bool get _canChargeOnline =>
      context.read<ConnectionProvider>().isConnected && _remoteGroupId != null;

  Future<void> _loadCloudIds() async {
    final group = context.read<AppState>().group;
    if (group == null) return;
    final remoteGroupId = await _idMap.remoteId(MapEntity.group, group.id);
    final members = await _idMap.mappings(MapEntity.member);
    if (!mounted) return;
    setState(() {
      _remoteGroupId = remoteGroupId;
      _remoteMemberIds = members;
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
    final reference = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GatewayPaymentSheet(
        groupRemoteId: _remoteGroupId!,
        method: _method,
        amount: _shares * group.shareValue,
        purpose: 'SHARE_PURCHASE',
        memberRemoteId: _remoteMemberIds[_memberId],
        memberName: memberName?.name,
        memberPhone: memberName?.phone,
      ),
    );
    if (reference == null || !mounted) return;
    _refCtrl.text = reference;
    await _record();
  }

  Future<void> _record() async {
    final ref = _refCtrl.text.trim();
    if (_method.needsReference && ref.isEmpty) {
      showAppSnack(context, 'Enter the ${_refLabel(_method).toLowerCase()}.',
          error: true);
      return;
    }
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
      );
      await memberProvider.load(group.id);
      await appState.refreshPendingSync();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context,
          'Recorded $_shares share(s) via ${_method.label} — ${Formatters.money(_shares * group.shareValue)}.');
    } on DomainException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
