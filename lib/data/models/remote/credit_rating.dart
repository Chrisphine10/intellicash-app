/// A group's credit rating from the backend rating contract
/// (`GET /groups/:id/credit-score`).
library;

int _toInt(Object? v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

double _toDouble(Object? v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

class RemoteCreditFactor {
  const RemoteCreditFactor({
    required this.label,
    required this.pillar,
    required this.weight,
    required this.points,
    required this.evidence,
    required this.guideline,
  });

  final String label;
  final String pillar; // GOVERNANCE | COMPLIANCE
  final int weight;
  final double points;
  final String evidence;
  final String guideline;

  factory RemoteCreditFactor.fromJson(Map<String, dynamic> j) =>
      RemoteCreditFactor(
        label: '${j['label'] ?? ''}',
        pillar: '${j['pillar'] ?? ''}',
        weight: _toInt(j['weight']),
        points: _toDouble(j['points']),
        evidence: '${j['evidence'] ?? ''}',
        guideline: '${j['guideline'] ?? ''}',
      );
}

class RemoteCreditRating {
  const RemoteCreditRating({
    required this.score,
    required this.band,
    required this.bandLabel,
    required this.rated,
    required this.governance,
    required this.compliance,
    required this.termsSummary,
    required this.depositRateBps,
    required this.factors,
    required this.recommendations,
  });

  final int score; // 0-100
  final String band; // A|B|C|D|UNRATED
  final String bandLabel;
  final bool rated;
  final double governance; // out of 40
  final double compliance; // out of 60
  final String termsSummary;
  final int depositRateBps;
  final List<RemoteCreditFactor> factors;
  final List<String> recommendations;

  /// Deposit percentage the band unlocks in the store (e.g. 20 for band B).
  double get depositPercent => depositRateBps / 100;

  factory RemoteCreditRating.fromJson(Map<String, dynamic> j) {
    final pillars = j['pillars'] as Map<String, dynamic>?;
    final terms = j['terms'] as Map<String, dynamic>?;
    return RemoteCreditRating(
      score: _toInt(j['score']),
      band: '${j['band'] ?? 'UNRATED'}',
      bandLabel: '${j['bandLabel'] ?? ''}',
      rated: j['rated'] == true,
      governance: _toDouble(pillars?['governance']),
      compliance: _toDouble(pillars?['compliance']),
      termsSummary: '${terms?['summary'] ?? ''}',
      depositRateBps: _toInt(terms?['depositRateBps']),
      factors: (j['factors'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(RemoteCreditFactor.fromJson)
              .toList() ??
          const [],
      recommendations:
          (j['recommendations'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }
}
