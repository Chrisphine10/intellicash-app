import '../../core/network/api_client.dart';
import '../../core/utils/visit_assessment_scoring.dart';
import '../repositories/assessment_repository.dart';

/// The published scorecard, as the server serves it.
class RemoteTemplate {
  const RemoteTemplate({
    required this.snapshotId,
    required this.templateId,
    required this.version,
    required this.checksum,
    required this.maxPoints,
    required this.scoringContractVersion,
    required this.snapshotJson,
  });

  final String snapshotId;
  final String templateId;
  final int version;
  final String checksum;
  final double maxPoints;
  final String scoringContractVersion;
  final Map<String, dynamic> snapshotJson;
}

/// The server's verdict on an assessment.
class RemoteAssessmentResult {
  const RemoteAssessmentResult({
    required this.earnedPoints,
    required this.percentage,
    required this.checksumMismatch,
    this.bandKey,
    this.bandLabel,
  });

  final double earnedPoints;
  final double percentage;

  /// True when the phone scored against a form that has since been superseded.
  /// The visit still landed; the phone should refresh its cached form.
  final bool checksumMismatch;
  final String? bandKey;
  final String? bandLabel;
}

class RemoteAssessmentsApi {
  RemoteAssessmentsApi(this._client);

  final ApiClient _client;

  /// Fetches the current published form.
  ///
  /// Returns null when the server has none published yet — a state the app has
  /// to survive rather than crash on, because a fresh deployment genuinely has
  /// no scorecard until IWL publishes one.
  Future<RemoteTemplate?> fetchCurrent() async {
    final data = await _client.getData('/assessment-templates/current');
    if (data is! Map<String, dynamic>) return null;

    final snapshot = data['snapshot'];
    if (snapshot is! Map<String, dynamic>) return null;

    return RemoteTemplate(
      // The server keys a snapshot by the template it froze; the id travels
      // inside the document.
      snapshotId: '${data['snapshotId'] ?? snapshot['templateId']}',
      templateId: '${snapshot['templateId']}',
      version: (data['version'] as num?)?.toInt() ??
          (snapshot['version'] as num?)?.toInt() ??
          1,
      checksum: '${data['checksum']}',
      maxPoints: (data['maxPoints'] as num?)?.toDouble() ??
          (snapshot['maxPoints'] as num?)?.toDouble() ??
          0,
      scoringContractVersion: '${data['scoringContractVersion'] ?? visitAssessmentContractVersion}',
      snapshotJson: snapshot,
    );
  }

  /// Sends the answers. The server re-scores and its figure is authoritative.
  Future<RemoteAssessmentResult> submit(PendingAssessment pending) async {
    final data = await _client.putData(
      '/visits/${pending.visitId}/assessment',
      body: {
        'templateSnapshotId': pending.snapshotId,
        'expectedChecksum': pending.checksum,
        'answers': pending.answers.map((a) => a.toJson()).toList(),
      },
    );

    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final score = map['score'] as Map<String, dynamic>? ?? const {};

    return RemoteAssessmentResult(
      earnedPoints: (score['earnedPoints'] as num?)?.toDouble() ?? 0,
      percentage: (score['percentage'] as num?)?.toDouble() ?? 0,
      bandKey: score['bandKey'] as String?,
      bandLabel: score['bandLabel'] as String?,
      checksumMismatch: map['checksumMismatch'] == true,
    );
  }
}
