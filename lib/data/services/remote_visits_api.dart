import '../../core/network/api_client.dart';

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
