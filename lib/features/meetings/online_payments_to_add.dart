import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/id_map_repository.dart';
import '../../data/services/remote_payments_api.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import 'online_charge.dart';

/// Share purchases paid online that are in the group's books on the server
/// but not yet in this phone's book — typically a payment that went through
/// after the phone stopped waiting for it.
///
/// Adding one records it here WITH its payment id, so the next sync links it
/// to the server's entry instead of writing the money a second time.
class OnlinePaymentsToAdd extends StatefulWidget {
  const OnlinePaymentsToAdd({super.key, required this.remoteGroupId});

  final String remoteGroupId;

  @override
  State<OnlinePaymentsToAdd> createState() => _OnlinePaymentsToAddState();
}

class _OnlinePaymentsToAddState extends State<OnlinePaymentsToAdd> {
  final _idMap = IdMapRepository(AppDatabase.instance);
  List<_Pending> _pending = const [];
  bool _adding = false;

  /// Asked once the phone is online; the connection often comes up after the
  /// meeting screen has opened.
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    // Online-only: a book used without the cloud (or a screen built without
    // it) simply has nothing to show here.
    final ConnectionProvider connection;
    final RemotePaymentsApi api;
    try {
      connection = context.read<ConnectionProvider>();
      api = context.read<RemotePaymentsApi>();
    } on ProviderNotFoundException {
      return;
    }
    if (!connection.isConnected) return;
    _asked = true;
    try {
      final payments = await api.unlinked(widget.remoteGroupId);
      final db = await AppDatabase.instance.database;
      // Linked from any of the four kinds of money row.
      final linkedRows = await db.rawQuery('''
        SELECT group_payment_id FROM share_purchases WHERE group_payment_id IS NOT NULL
        UNION SELECT group_payment_id FROM social_fund_entries WHERE group_payment_id IS NOT NULL
        UNION SELECT group_payment_id FROM fines WHERE group_payment_id IS NOT NULL
        UNION SELECT group_payment_id FROM loan_repayments WHERE group_payment_id IS NOT NULL
      ''');
      final linked = {for (final row in linkedRows) row['group_payment_id'] as String};
      // A restored book already holds the server's entries: offering those
      // payments again would put the money in this book twice.
      final restoredEntries = (await _idMap.mappings(MapEntity.importedEntry)).values.toSet();
      final localByRemote = {
        for (final entry in (await _idMap.mappings(MapEntity.member)).entries) entry.value: entry.key,
      };
      final pending = <_Pending>[
        for (final payment in payments)
          if (PaymentPurpose.fromWire(payment.purpose) != null &&
              !linked.contains(payment.id) &&
              !restoredEntries.contains(payment.ledgerEntryId))
            _Pending(payment, payment.memberId == null ? null : localByRemote[payment.memberId]),
      ];
      if (mounted) setState(() => _pending = pending);
    } on ApiException {
      // An older server has no such list; nothing to show.
    } catch (error) {
      // Never break the meeting screen over an extra, but never hide why:
      // a missing column once made this banner silently empty.
      AppLogger.instance.warn('online-payments', 'Could not list online payments to add', error);
    }
  }

  Future<void> _addAll() async {
    setState(() => _adding = true);
    var added = 0;
    final problems = <String>[];
    for (final item in _pending) {
      final payment = item.payment;
      if (item.localMemberId == null) {
        problems.add('${Formatters.money(payment.amountToGroup)}: the member is not on this phone');
        continue;
      }
      try {
        await recordOnlinePayment(
          context,
          purpose: PaymentPurpose.fromWire(payment.purpose)!,
          memberId: item.localMemberId!,
          amount: payment.amountToGroup,
          method: payment.provider == 'PAYSTACK' ? PaymentMethod.paystack : PaymentMethod.mpesa,
          reference: payment.providerTransactionId ?? payment.id,
          groupPaymentId: payment.id,
        );
        added += 1;
      } on DomainException catch (e) {
        problems.add('${Formatters.money(payment.amountToGroup)}: ${e.message}');
      }
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() => _adding = false);
    await _load();
    if (!mounted) return;
    showAppSnack(
      context,
      problems.isEmpty
          ? 'Added $added online payment(s) to this meeting.'
          : 'Added $added. Not added: ${problems.join('; ')}',
      error: problems.isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ask as soon as the phone comes online, if it was not when this opened.
    var online = false;
    try {
      online = context.select<ConnectionProvider, bool>((c) => c.isConnected);
    } on ProviderNotFoundException {
      // A screen built without the cloud (tests, an offline-only book).
    }
    if (online && !_asked) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    if (_pending.isEmpty) return const SizedBox.shrink();
    final l10n = L10n.of(context);
    final total = _pending.fold<double>(0, (sum, item) => sum + item.payment.amountToGroup);
    return Card(
      color: AppColors.primaryTint,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.onlinePaymentsNotInBook(_pending.length, Formatters.money(total)),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.onlinePaymentsExplain,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            for (final item in _pending)
              Text(
                '· ${item.payment.providerTransactionId ?? ''} ${Formatters.money(item.payment.amountToGroup)}'
                '${item.localMemberId == null ? ' (member not on this phone)' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _adding ? null : _addAll,
              icon: const Icon(Icons.playlist_add, size: 18),
              label: Text(_adding ? '…' : l10n.onlinePaymentsAddToMeeting),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pending {
  const _Pending(this.payment, this.localMemberId);

  final GroupPayment payment;
  final String? localMemberId;
}
