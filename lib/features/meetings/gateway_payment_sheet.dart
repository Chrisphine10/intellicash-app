import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/services/remote_payments_api.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/payment_method_button.dart';

/// What a completed online payment hands back to the screen that asked for it.
class GatewayPaymentResult {
  const GatewayPaymentResult({required this.reference, required this.paymentId});

  /// The M-Pesa receipt (or Paystack transaction id), for the record.
  final String reference;

  /// The server's payment id. The purchase is recorded with it so the phone's
  /// entry and the server's are one, never two.
  final String paymentId;
}

/// Who is paying: the treasurer charging a member in a meeting, or a member
/// paying from their own passbook. Same flow, different endpoints.
abstract class PaymentChannel {
  Future<PaymentQuote> quote(String provider);
  Future<GroupPayment> initiate(PaymentQuote quote, {String? phone, String? email, required String clientRequestId});
  Future<GroupPayment> status(String paymentId);
}

class GroupPaymentChannel implements PaymentChannel {
  GroupPaymentChannel(this.api, {required this.groupId, required this.purpose, required this.groupAmount, this.memberId, this.meetingId});

  final RemotePaymentsApi api;
  final String groupId;
  final String purpose;
  final double groupAmount;
  final String? memberId;
  final String? meetingId;

  @override
  Future<PaymentQuote> quote(String provider) => api.quote(
        groupId: groupId,
        provider: provider,
        purpose: purpose,
        groupAmount: groupAmount,
        memberId: memberId,
        meetingId: meetingId,
      );

  @override
  Future<GroupPayment> initiate(PaymentQuote quote, {String? phone, String? email, required String clientRequestId}) =>
      api.initiate(
        groupId: groupId,
        quote: quote,
        purpose: purpose,
        phoneNumber: phone,
        customerEmail: email,
        memberId: memberId,
        meetingId: meetingId,
        clientRequestId: clientRequestId,
      );

  @override
  Future<GroupPayment> status(String paymentId) => api.status(groupId, paymentId);
}

class SelfPaymentChannel implements PaymentChannel {
  SelfPaymentChannel(this.api, {required this.purpose, required this.groupAmount});

  final RemotePaymentsApi api;
  final String purpose;
  final double groupAmount;

  @override
  Future<PaymentQuote> quote(String provider) =>
      api.selfQuote(provider: provider, purpose: purpose, groupAmount: groupAmount);

  @override
  Future<GroupPayment> initiate(PaymentQuote quote, {String? phone, String? email, required String clientRequestId}) =>
      api.selfInitiate(quote: quote, purpose: purpose, phoneNumber: phone, customerEmail: email, clientRequestId: clientRequestId);

  @override
  Future<GroupPayment> status(String paymentId) => api.selfStatus(paymentId);
}

/// Collects the money through a payment gateway: M-Pesa sends an STK prompt
/// to the member's handset, Paystack opens a checkout page.
///
/// The member first sees what they will pay — the amount for the group, the
/// IWL fee and the payment charges — and agrees to that total. Once the
/// server has confirmed the payment with the provider it pops a
/// [GatewayPaymentResult]; null if the treasurer backs out first.
class GatewayPaymentSheet extends StatefulWidget {
  const GatewayPaymentSheet({
    super.key,
    required this.channel,
    required this.method,
    required this.amount,
    this.memberName,
    this.memberPhone,
    this.memberEmail,
  });

  /// Convenience for the meeting: the treasurer charging a member.
  factory GatewayPaymentSheet.forGroup(
    BuildContext context, {
    required String groupRemoteId,
    required PaymentMethod method,
    required double amount,
    required String purpose,
    String? memberRemoteId,
    String? meetingRemoteId,
    String? memberName,
    String? memberPhone,
  }) {
    return GatewayPaymentSheet(
      channel: GroupPaymentChannel(
        context.read<RemotePaymentsApi>(),
        groupId: groupRemoteId,
        purpose: purpose,
        groupAmount: amount,
        memberId: memberRemoteId,
        meetingId: meetingRemoteId,
      ),
      method: method,
      amount: amount,
      memberName: memberName,
      memberPhone: memberPhone,
    );
  }

  final PaymentChannel channel;
  final PaymentMethod method;

  /// What the GROUP receives.
  final double amount;
  final String? memberName;
  final String? memberPhone;
  final String? memberEmail;

  @override
  State<GatewayPaymentSheet> createState() => _GatewayPaymentSheetState();
}

class _GatewayPaymentSheetState extends State<GatewayPaymentSheet> {
  late final TextEditingController _contactCtrl;
  final _clientRequestId = const Uuid().v4();

  PaymentQuote? _quote;
  bool _quoting = true;
  bool _sending = false;
  String? _error;
  String? _notice;
  GroupPayment? _payment;
  Timer? _poll;
  int _waited = 0;

  bool get _isMpesa => widget.method == PaymentMethod.mpesa;

  /// A member paying from their own passbook: the copy speaks to them.
  bool get _isSelf => widget.channel is SelfPaymentChannel;
  String get _provider => _isMpesa ? 'MPESA_DARAJA' : 'PAYSTACK';

  /// The STK prompt expires; stop polling rather than spinning forever. The
  /// server keeps checking after this, so a late payment is not lost.
  static const _timeoutSeconds = 120;

  /// After the notice, keep asking — less often — for this long, so a late
  /// confirmation is still recorded here rather than left for the banner.
  static const _quietCheckSeconds = 600;

  @override
  void initState() {
    super.initState();
    // Only M-Pesa needs anything typed: the number to prompt. Paystack's
    // receipt email comes from the system (the member's or the group's
    // login), so the member is never asked for one.
    _contactCtrl = TextEditingController(text: _isMpesa ? (widget.memberPhone ?? '') : '');
    _loadQuote();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final quote = await widget.channel.quote(_provider);
      if (mounted) setState(() => _quote = quote);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _start() async {
    final quote = _quote;
    if (quote == null) return;
    final contact = _contactCtrl.text.trim();
    if (_isMpesa && contact.replaceAll(RegExp(r'[^0-9]'), '').length < 9) {
      setState(() => _error = 'Enter the phone number to send the request to.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final payment = await widget.channel.initiate(
        quote,
        phone: _isMpesa ? contact : null,
        email: _isMpesa ? null : widget.memberEmail,
        clientRequestId: _clientRequestId,
      );
      if (!mounted) return;
      setState(() => _payment = payment);
      if (payment.checkoutUrl != null) await _openCheckout(payment.checkoutUrl!);
      if (payment.isPending) _startPolling();
      if (payment.isComplete) _finish(payment);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      // The charges moved since the quote: show the new total, never charge it silently.
      if (e.code == 'QUOTE_CHANGED' || e.code == 'QUOTE_EXPIRED') await _loadQuote();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openCheckout(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // The link stays on screen to open by hand.
    }
  }

  void _finish(GroupPayment payment) {
    Navigator.of(context).pop(
      GatewayPaymentResult(reference: payment.providerTransactionId ?? payment.id, paymentId: payment.id),
    );
  }

  void _startPolling() {
    _poll?.cancel();
    _waited = 0;
    _poll = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _waited += 3;
      // Past the notice: check every 12 seconds, not every 3.
      if (_waited > _timeoutSeconds && _waited % 12 != 0) return;
      try {
        final latest = await widget.channel.status(_payment!.id);
        if (!mounted) return;
        setState(() => _payment = latest);
        if (latest.isComplete) {
          timer.cancel();
          _finish(latest);
          return;
        }
        if (latest.isHeld) {
          timer.cancel();
          final l10n = L10n.of(context);
          setState(() => _notice = l10n.paymentHeldNotice);
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
      if (_waited >= _timeoutSeconds && _notice == null && mounted) {
        final l10n = L10n.of(context);
        setState(() => _notice = l10n.paymentNoConfirmationYet);
      }
      if (_waited >= _quietCheckSeconds) timer.cancel();
    });
  }

  Widget _breakdown(PaymentQuote quote) {
    final l10n = L10n.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    Widget line(String label, double value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(label, style: strong ? const TextStyle(fontWeight: FontWeight.w700) : small)),
              Text(
                Formatters.money(value),
                style: strong
                    ? TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)
                    : small,
              ),
            ],
          ),
        );
    return Card(
      color: AppColors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            line(l10n.paymentToTheGroup, quote.groupAmount),
            line(l10n.paymentPlatformFee, quote.platformFee),
            line(l10n.paymentCharges, quote.providerFee),
            const Divider(height: 12),
            line(_isSelf ? l10n.paymentYouPay : l10n.paymentMemberPays, quote.total, strong: true),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final payment = _payment;
    final quote = _quote;
    final waiting = payment != null && payment.isPending && _error == null && _notice == null;
    final started = payment != null;

    return SingleChildScrollView(
      // A small phone cannot fit the whole sheet: let it scroll.
      child: Padding(
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
            Row(
              children: [
                Expanded(
                  child: Text(_isMpesa ? 'Pay by M-Pesa' : 'Pay by Paystack', style: Theme.of(context).textTheme.titleMedium),
                ),
                PaymentLogo(widget.method, height: 20),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${l10n.paymentAmountToGroup(Formatters.money(widget.amount))}'
              '${widget.memberName != null ? ' · ${widget.memberName}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_quoting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (quote != null)
              _breakdown(quote),
            const SizedBox(height: 12),
            if (_notice != null) ...[
              Text(_notice!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
            ],
            if (waiting) ...[
              Row(
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isMpesa
                          ? (_isSelf ? l10n.paymentEnterYourPin : l10n.gatewayPaymentRequestSentAskTheMemberTo)
                          : l10n.paymentWaitingForCheckout,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (payment.checkoutUrl != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openCheckout(payment.checkoutUrl!),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.gatewayPaymentOpenThisLinkToPay),
                ),
                const SizedBox(height: 4),
                SelectableText(payment.checkoutUrl!, style: TextStyle(fontSize: 12, color: AppColors.primary)),
              ],
            ] else if (!started) ...[
              if (_isMpesa)
                TextField(
                  controller: _contactCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    hintText: '07XX XXX XXX',
                    errorText: _error,
                  ),
                )
              else if (_error != null)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _sending || quote == null ? null : _start,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_isMpesa ? Icons.phone_android : Icons.open_in_new, size: 18),
                label: Text(_sending
                    ? 'Sending…'
                    : quote == null
                        ? 'Pay'
                        : l10n.paymentPayAmount(Formatters.money(quote.total))),
              ),
              if (quote == null && !_quoting)
                TextButton(onPressed: _loadQuote, child: Text(l10n.paymentTryAgain)),
            ] else if (_error != null) ...[
              Text(_error!, style: TextStyle(color: AppColors.defaulted, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              // Once a charge has been sent, closing never cancels it: the
              // server keeps waiting for the provider and books it when it lands.
              child: Text(started ? l10n.paymentClose : l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
