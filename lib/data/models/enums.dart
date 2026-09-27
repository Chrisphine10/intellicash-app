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
  carriedForward('carried forward'),
  repaid('repaid'),
  defaulted('defaulted');

  const LoanStatus(this.label);
  final String label;
}

/// A member's office in the group. Officials (everything but [member]) count
/// towards the 3-key meeting unlock — the same set the server counts.
///
/// Stored on the phone by enum NAME, so adding offices is backward compatible;
/// never rename an existing value.
enum MemberRole {
  chairperson('Chairperson', 'CHAIRPERSON'),
  secretary('Secretary', 'SECRETARY'),
  treasurer('Treasurer', 'TREASURER'),
  keyHolder('Key holder', 'KEY_HOLDER'),
  moneyCounter('Money counter', 'MONEY_COUNTER'),
  member('Member', 'MEMBER');

  const MemberRole(this.label, this.serverName);
  final String label;

  /// The server's name for this office.
  final String serverName;

  /// Offices only one member may hold at a time. Giving it to someone steps
  /// the previous holder down to [member] — the server's rule too.
  bool get isSingleHolder =>
      this == chairperson || this == secretary || this == treasurer;

  /// The office for a server role name ("CHAIRPERSON"), or for a stored enum
  /// name ("chairperson"). Anything else is an ordinary member. Restores used
  /// to store the server's uppercase name, which matched nothing, so every
  /// restored official came back as a member.
  static MemberRole fromAny(String? value) {
    if (value == null) return MemberRole.member;
    for (final role in MemberRole.values) {
      if (role.name == value || role.serverName == value.toUpperCase()) return role;
    }
    return MemberRole.member;
  }
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
  /// A prompt on the member's phone; the receipt comes back from M-Pesa, so
  /// nobody types a code.
  mpesa('M-Pesa', 'phone_android', automated: true, needsReference: false),
  /// The member paid the group's Paybill / Till themselves; the treasurer
  /// types the confirmation code from their SMS.
  mpesaClassic('M-Pesa Classic', 'dialpad'),
  /// Card or mobile money through Paystack's checkout.
  paystack('Paystack', 'account_balance_wallet', automated: true, needsReference: false),
  /// No longer offered (Paystack takes cards). Kept so rows recorded with it
  /// still read.
  card('Card', 'credit_card', automated: true);

  /// What a member can pay with, in the order it is offered.
  static const offered = [cash, mpesa, mpesaClassic, paystack];

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
