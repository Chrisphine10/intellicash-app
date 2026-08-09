import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

/// Why a PIN check did not pass. Kept as a type rather than a message so the
/// UI can respond differently to "wrong" (try again) and "locked" (stop).
enum VisitPinFailure { wrong, locked, notSet, offline, unknown }

class VisitPinResult {
  const VisitPinResult.ok()
      : verified = true,
        failure = null,
        message = null;
  const VisitPinResult.failed(this.failure, this.message) : verified = false;

  final bool verified;
  final VisitPinFailure? failure;
  final String? message;
}

/// A visit as the server has recorded it.
class RemoteVisit {
  const RemoteVisit({
    required this.id,
    required this.groupId,
    required this.clientRequestId,
    required this.visitType,
    required this.status,
    required this.startedAt,
    required this.locationOutcome,
    required this.withinGeofence,
    this.distanceFromGroupM,
    this.groupName,
    this.notes,
  });

  final String id;
  final String groupId;
  final String clientRequestId;
  final String visitType;
  final String status;
  final DateTime? startedAt;

  /// The SERVER's verdict, not the phone's. The phone reports a coordinate;
  /// where the visit happened is decided centrally.
  final String locationOutcome;
  final bool withinGeofence;
  final double? distanceFromGroupM;
  final String? groupName;
  final String? notes;

  factory RemoteVisit.fromJson(Map<String, dynamic> j) {
    final location = j['location'] as Map<String, dynamic>? ?? const {};
    final group = j['group'] as Map<String, dynamic>?;
    return RemoteVisit(
      id: '${j['id']}',
      groupId: '${j['groupId']}',
      clientRequestId: '${j['clientRequestId']}',
      visitType: '${j['visitType'] ?? 'FOLLOW_UP'}',
      status: '${j['status'] ?? 'SUBMITTED'}',
      startedAt: DateTime.tryParse('${j['startedAt']}'),
      locationOutcome: '${location['outcome'] ?? 'NO_DEVICE_FIX'}',
      withinGeofence: location['withinGeofence'] == true,
      distanceFromGroupM: (location['distanceFromGroupM'] as num?)?.toDouble(),
      groupName: group == null ? null : '${group['name']}',
      notes: j['notes'] as String?,
    );
  }
}

/// Field-visit endpoints.
class RemoteVisitsApi {
  RemoteVisitsApi(this._client);

  final ApiClient _client;

  /// Checks the group's 4-digit PIN.
  ///
  /// Distinguishes the failures because they mean different things to the
  /// person holding the phone: a wrong PIN invites another try, a locked one
  /// means stop, and "not set" is not their fault at all — an official has to
  /// set one before any visit can be recorded here.
  Future<VisitPinResult> verifyPin({
    required String groupId,
    required String pin,
  }) async {
    try {
      await _client.postData('/groups/$groupId/visit-pin/verify', body: {'pin': pin});
      return const VisitPinResult.ok();
    } on ApiException catch (error) {
      return switch (error.code) {
        'VISIT_PIN_INCORRECT' => const VisitPinResult.failed(
            VisitPinFailure.wrong, 'That PIN is not correct.'),
        'VISIT_PIN_LOCKED' => VisitPinResult.failed(VisitPinFailure.locked, error.message),
        'VISIT_PIN_NOT_SET' => VisitPinResult.failed(VisitPinFailure.notSet, error.message),
        _ => VisitPinResult.failed(VisitPinFailure.unknown, error.message),
      };
    } catch (_) {
      // No signal. The PIN cannot be checked centrally right now, which is a
      // fact about the network rather than about the PIN.
      return const VisitPinResult.failed(
          VisitPinFailure.offline, 'No connection — the PIN cannot be checked yet.');
    }
  }

  /// Whether this group has a visit PIN at all, so the flow can say so before
  /// the agent has typed anything.
  Future<bool> pinConfigured(String groupId) async {
    final data = await _client.getData('/groups/$groupId/visit-pin');
    return data['configured'] == true;
  }

  /// Submits a visit.
  ///
  /// Safe to call repeatedly with the same [clientRequestId]: the server
  /// returns the visit it already holds rather than recording a second.
  Future<RemoteVisit> submit({
    required String groupId,
    required String clientRequestId,
    required String visitType,
    required DateTime startedAt,
    DateTime? completedAt,
    double? latitude,
    double? longitude,
    double? accuracyM,
    DateTime? locationCapturedAt,
    String? locationNote,
    String? deviceId,
    String? notes,
  }) async {
    final data = await _client.postData(
      '/groups/$groupId/visits',
      body: {
        'clientRequestId': clientRequestId,
        'visitType': visitType,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt.toUtc().toIso8601String(),
        if (latitude != null && longitude != null)
          'location': {
            'latitude': latitude,
            'longitude': longitude,
            if (accuracyM != null) 'accuracyM': accuracyM,
            if (locationCapturedAt != null)
              'capturedAt': locationCapturedAt.toUtc().toIso8601String(),
          },
        if (locationNote != null && locationNote.isNotEmpty) 'locationNote': locationNote,
        if (deviceId != null) 'deviceId': deviceId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return RemoteVisit.fromJson(data['visit'] as Map<String, dynamic>);
  }

  /// This agent's visits across their caseload.
  Future<List<RemoteVisit>> myVisits() async {
    final data = await _client.getData('/agents/me/visits');
    final list = data['visits'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(RemoteVisit.fromJson)
        .toList();
  }

  Future<List<RemoteVisit>> forGroup(String groupId) async {
    final data = await _client.getData('/groups/$groupId/visits');
    final list = data['visits'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(RemoteVisit.fromJson)
        .toList();
  }
}
