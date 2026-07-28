/// DTOs for External Loans (Credit Ventures) — loan products offered by
/// external lending partners (banks, MFIs, SACCOs) that a VSLA group can
/// apply for through the app. Money is integer cents on the wire.
///
/// Shapes follow the `{ data, meta }` envelope of
/// `GET /external-loans/products` and `GET/POST /external-loans/applications`.
library;

double _kes(Object? v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0) / 100;

int _toInt(Object? v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

String _titleCase(String code) => code
    .split('_')
    .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
    .join(' ');

const Map<String, String> _kCategoryLabels = {
  'WORKING_CAPITAL': 'Working Capital',
  'ASSET_FINANCE': 'Asset Finance',
  'AGRI_INPUTS': 'Farm Inputs',
  'EMERGENCY': 'Emergency',
  'EDUCATION': 'Education',
  'BUSINESS_GROWTH': 'Business Growth',
};

String _categoryLabel(String category) =>
    _kCategoryLabels[category.toUpperCase()] ??
    (category.isEmpty ? 'General' : _titleCase(category));

/// `12% per year`, `3% per month`, `5% flat` — from basis points + period.
String _interestLabel(int rateBps, String period) {
  final percent = rateBps / 100;
  final rate = percent == percent.roundToDouble()
      ? percent.toStringAsFixed(0)
      : percent.toStringAsFixed(1);
  final suffix = switch (period.toUpperCase()) {
    'PER_YEAR' => ' per year',
    'PER_MONTH' => ' per month',
    'FLAT' => ' flat',
    _ => '',
  };
  return '$rate%$suffix';
}

String _frequencyLabel(String frequency) => switch (frequency.toUpperCase()) {
      'WEEKLY' => 'weekly',
      'BIWEEKLY' => 'every 2 weeks',
      'MONTHLY' => 'monthly',
      _ => _titleCase(frequency).toLowerCase(),
    };

/// True when [band] (A best … D worst) meets [minimum]. An unknown or
/// unrated band fails any minimum — the lender wants a proven rating.
bool creditBandMeets(String? band, String minimum) {
  const order = ['A', 'B', 'C', 'D'];
  final required = order.indexOf(minimum.toUpperCase());
  if (required < 0) return true;
  final actual = order.indexOf((band ?? '').toUpperCase());
  if (actual < 0) return false;
  return actual <= required;
}

/// The lending institution behind a loan product.
class ExternalLoanPartner {
  const ExternalLoanPartner({
    required this.id,
    required this.name,
    this.type,
  });

  final String id;
  final String name;
  final String? type; // BANK | MFI | SACCO | …

  factory ExternalLoanPartner.fromJson(Map<String, dynamic> j) =>
      ExternalLoanPartner(
        id: '${j['id']}',
        name: '${j['name'] ?? 'Partner'}',
        type: j['type'] as String?,
      );
}

/// A loan offer from a lending partner (`GET /external-loans/products`).
class ExternalLoanProduct {
  const ExternalLoanProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    this.description,
    required this.minAmount,
    required this.maxAmount,
    required this.interestRateBps,
    required this.interestPeriod,
    required this.termMonths,
    required this.repaymentFrequency,
    this.minCreditBand,
    this.requirements,
    required this.status,
    this.partner,
    required this.applicationsCount,
  });

  final String id;
  final String name;
  final String slug;
  final String category;
  final String? description;
  final double minAmount; // KES
  final double maxAmount; // KES
  final int interestRateBps;
  final String interestPeriod; // PER_YEAR | PER_MONTH | FLAT
  final int termMonths;
  final String repaymentFrequency; // WEEKLY | BIWEEKLY | MONTHLY
  final String? minCreditBand; // "A".."D" or null (open to all)
  final String? requirements;
  final String status;
  final ExternalLoanPartner? partner;
  final int applicationsCount;

  /// `12.5` for 1250 bps.
  double get interestRatePercent => interestRateBps / 100;

  /// `Working Capital`, `Farm Inputs`, … (title-cased fallback for new codes).
  String get categoryLabel => _categoryLabel(category);

  /// `12% per year`, `3% per month`, `5% flat`.
  String get interestLabel => _interestLabel(interestRateBps, interestPeriod);

  /// `weekly`, `every 2 weeks`, `monthly`.
  String get frequencyLabel => _frequencyLabel(repaymentFrequency);

  factory ExternalLoanProduct.fromJson(Map<String, dynamic> j) {
    final partner = j['partner'];
    final count = j['_count'];
    return ExternalLoanProduct(
      id: '${j['id']}',
      name: '${j['name'] ?? 'Loan'}',
      slug: '${j['slug'] ?? ''}',
      category: '${j['category'] ?? ''}',
      description: j['description'] as String?,
      minAmount: _kes(j['minAmountCents']),
      maxAmount: _kes(j['maxAmountCents']),
      interestRateBps: _toInt(j['interestRateBps']),
      interestPeriod: '${j['interestPeriod'] ?? 'PER_YEAR'}',
      termMonths: _toInt(j['termMonths']),
      repaymentFrequency: '${j['repaymentFrequency'] ?? 'MONTHLY'}',
      minCreditBand: j['minCreditBand'] as String?,
      requirements: j['requirements'] as String?,
      status: '${j['status'] ?? ''}',
      partner: partner is Map<String, dynamic>
          ? ExternalLoanPartner.fromJson(partner)
          : null,
      applicationsCount:
          count is Map ? _toInt(count['applications']) : _toInt(j['applicationsCount']),
    );
  }
}

/// A group's loan application (`GET/POST /external-loans/applications`).
class ExternalLoanApplication {
  const ExternalLoanApplication({
    required this.id,
    required this.amount,
    required this.purpose,
    this.creditBand,
    required this.status,
    this.reviewNotes,
    this.decidedAt,
    this.disbursedAt,
    this.createdAt,
    this.productId,
    this.productName,
    this.productCategory,
    required this.interestRateBps,
    required this.interestPeriod,
    required this.termMonths,
    required this.repaymentFrequency,
    this.partnerName,
    this.groupId,
    this.groupName,
    this.groupCode,
  });

  final String id;
  final double amount; // KES
  final String purpose;
  final String? creditBand; // band at application time
  final String status; // PENDING | APPROVED | REJECTED | DISBURSED
  final String? reviewNotes;
  final DateTime? decidedAt;
  final DateTime? disbursedAt;
  final DateTime? createdAt;
  final String? productId;
  final String? productName;
  final String? productCategory;
  final int interestRateBps;
  final String interestPeriod;
  final int termMonths;
  final String repaymentFrequency;
  final String? partnerName;
  final String? groupId;
  final String? groupName;
  final String? groupCode;

  /// `12% per year`, `3% per month`, `5% flat`.
  String get interestLabel => _interestLabel(interestRateBps, interestPeriod);

  /// `weekly`, `every 2 weeks`, `monthly`.
  String get frequencyLabel => _frequencyLabel(repaymentFrequency);

  factory ExternalLoanApplication.fromJson(Map<String, dynamic> j) {
    final product = j['product'];
    final partner = product is Map ? product['partner'] : null;
    final group = j['group'];
    return ExternalLoanApplication(
      id: '${j['id']}',
      amount: _kes(j['amountCents']),
      purpose: '${j['purpose'] ?? ''}',
      creditBand: j['creditBand'] as String?,
      status: '${j['status'] ?? ''}',
      reviewNotes: j['reviewNotes'] as String?,
      decidedAt: _date(j['decidedAt']),
      disbursedAt: _date(j['disbursedAt']),
      createdAt: _date(j['createdAt']),
      productId: product is Map ? '${product['id']}' : null,
      productName: product is Map ? product['name'] as String? : null,
      productCategory: product is Map ? product['category'] as String? : null,
      interestRateBps: _toInt(product is Map ? product['interestRateBps'] : null),
      interestPeriod:
          '${(product is Map ? product['interestPeriod'] : null) ?? 'PER_YEAR'}',
      termMonths: _toInt(product is Map ? product['termMonths'] : null),
      repaymentFrequency:
          '${(product is Map ? product['repaymentFrequency'] : null) ?? 'MONTHLY'}',
      partnerName: partner is Map ? partner['name'] as String? : null,
      groupId: group is Map ? '${group['id']}' : null,
      groupName: group is Map ? group['name'] as String? : null,
      groupCode: group is Map ? group['code'] as String? : null,
    );
  }
}
