/// Domain enums, stored in SQLite by [name].
library;

enum SavingsMode {
  fixed('Fixed shares'),
  flexible('Flexible amounts');

  const SavingsMode(this.label);
  final String label;
}

enum InterestType {
  flat('Flat (simple interest)'),
  reducingBalance('Reducing balance');

  const InterestType(this.label);
  final String label;
}

enum MeetingFrequency {
  weekly('Weekly', 7),
  biweekly('Bi-weekly', 14),
  monthly('Monthly', 30);

  const MeetingFrequency(this.label, this.days);
  final String label;
  final int days;
}

enum MeetingStatus {
  open('in progress'),
  closed('closed');

  const MeetingStatus(this.label);
  final String label;
}

enum LoanStatus {
  active('active'),
  repaid('repaid'),
  defaulted('defaulted');

  const LoanStatus(this.label);
  final String label;
}

enum MemberRole {
  chairperson('Chairperson'),
  secretary('Secretary'),
  treasurer('Treasurer'),
  member('Member');

  const MemberRole(this.label);
  final String label;
}

/// How a member paid for a share purchase (or other contribution).
///
/// [needsReference] methods prompt for a transaction code (M-Pesa code,
/// Paystack/card reference, etc.) which is carried into the backend ledger
/// entry's `externalReference` on sync.
///
/// [automated] methods are charged through a payment gateway (Daraja STK for
/// M-Pesa, Paystack for card) once the backend payment module is live — see
/// `docs/specs/BACKEND_SPEC_payments.md`. Until then the app records the
/// confirmation reference the member provides.
enum PaymentMethod {
  cash('Cash', 'payments', needsReference: false),
  mpesa('M-Pesa', 'phone_android', automated: true),
  mpesaClassic('M-Pesa Classic', 'dialpad'),
  paystack('Paystack', 'account_balance_wallet', automated: true),
  card('Card', 'credit_card', automated: true);

  const PaymentMethod(
    this.label,
    this.iconKey, {
    this.needsReference = true,
    this.automated = false,
  });

  final String label;
  final String iconKey;
  final bool needsReference;

  /// Charged via a gateway (Daraja STK / Paystack) when the payment backend
  /// is configured.
  final bool automated;
}

T enumFromName<T extends Enum>(List<T> values, String name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);
