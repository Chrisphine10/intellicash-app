import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/services/remote_payments_api.dart';
import '../../l10n/app_localizations.dart';

/// Collects the money through a payment gateway before the purchase is
/// recorded: M-Pesa sends an STK prompt to the member's handset, Paystack
/// hands back a checkout link.
///
/// Pops the confirmation reference (the M-Pesa receipt) on success, or null
/// if the treasurer backs out — the caller then records the purchase with
/// that reference against the member's name.
class GatewayPaymentSheet extends StatefulWidget {
  const GatewayPaymentSheet({
    super.key,
    required this.groupRemoteId,
    required this.method,
    required this.amount,
    required this.purpose,
    this.memberRemoteId,
    this.memberName,
    this.memberPhone,
  });

  final String groupRemoteId;
  final PaymentMethod method;
  final double amount;
  final String purpose;
  final String? memberRemoteId;
  final String? memberName;
  final String? memberPhone;

  @override
  State<GatewayPaymentSheet> createState() => _GatewayPaymentSheetState();
}

class _GatewayPaymentSheetState extends State<GatewayPaymentSheet> {
  late final TextEditingController _contactCtrl;
  final _clientRequestId = const Uuid().v4();

  bool _sending = false;
  String? _error;
  GroupPayment? _payment;
  Timer? _poll;
  int _waited = 0;

  bool get _isMpesa => widget.method == PaymentMethod.mpesa;

  /// The STK prompt expires; stop polling rather than spinning forever.
  static const _timeoutSeconds = 90;

  @override
  void initState() {
    super.initState();
    _contactCtrl = TextEditingController(text: widget.memberPhone ?? '');
  }

  @override
  void dispose() {
    _poll?.cancel();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final contact = _contactCtrl.text.trim();
    if (_isMpesa && contact.replaceAll(RegExp(r'[^0-9]'), '').length < 9) {
      setState(() => _error = 'Enter the phone number to send the request to.');
      return;
    }
    if (!_isMpesa && !contact.contains('@')) {
      setState(() => _error = 'Enter an email address for the receipt.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    final api = context.read<RemotePaymentsApi>();
    try {
      final payment = await api.initiate(
        groupId: widget.groupRemoteId,
        provider: _isMpesa ? 'MPESA_DARAJA' : 'PAYSTACK',
        purpose: widget.purpose,
        amount: widget.amount,
        phoneNumber: _isMpesa ? contact : null,
        customerEmail: _isMpesa ? null : contact,
        memberId: widget.memberRemoteId,
        clientRequestId: _clientRequestId,
      );
      if (!mounted) return;
      setState(() => _payment = payment);
      if (payment.isPending) _startPolling(api);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startPolling(RemotePaymentsApi api) {
    _poll?.cancel();
    _waited = 0;
    _poll = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _waited += 3;
      try {
        final latest = await api.status(widget.groupRemoteId, _payment!.id);
        if (!mounted) return;
        setState(() => _payment = latest);
        if (latest.isComplete) {
          timer.cancel();
          Navigator.of(context)
              .pop(latest.providerTransactionId ?? latest.id);
          return;
        }
        if (latest.isFailed) {
          timer.cancel();
          setState(() => _error = latest.failureReason ?? 'Payment failed.');
          return;
        }
      } on ApiException {
        // A dropped poll isn't fatal — the next tick retries.
      }
      if (_waited >= _timeoutSeconds) {
        timer.cancel();
        if (mounted) {
          setState(() => _error =
              'No confirmation yet. If the member paid, record the code by hand instead.');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final payment = _payment;
    final waiting = payment != null && payment.isPending && _error == null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isMpesa ? 'Pay by M-Pesa' : 'Pay by Paystack',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            '${Formatters.money(widget.amount)}'
            '${widget.memberName != null ? ' for ${widget.memberName}' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (waiting) ...[
            Row(
              children: [
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isMpesa
                        ? l10n.gatewayPaymentRequestSentAskTheMemberTo
                        : 'Waiting for the payment to go through…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (payment.checkoutUrl != null) ...[
              const SizedBox(height: 12),
              Card(
                color: AppColors.surfaceRaised,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.gatewayPaymentOpenThisLinkToPay,
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      SelectableText(
                        payment.checkoutUrl!,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ] else ...[
            TextField(
              controller: _contactCtrl,
              autofocus: true,
              keyboardType:
                  _isMpesa ? TextInputType.phone : TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _isMpesa ? 'Phone number' : 'Email address',
                hintText: _isMpesa ? '07XX XXX XXX' : 'name@example.com',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _sending ? null : _start,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_isMpesa ? Icons.phone_android : Icons.open_in_new,
                      size: 18),
              label: Text(_sending
                  ? 'Sending…'
                  : _isMpesa
                      ? 'Send Request to Phone'
                      : 'Create Payment Link'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(waiting ? 'Cancel and enter code by hand' : 'Cancel'),
          ),
        ],
      ),
    );
  }
}
