import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Why a location could not be read. Each one needs a different sentence from
/// the app, and — crucially — none of them stops a visit being recorded.
enum LocationFailure {
  /// The person said no. Their choice; the visit still goes ahead.
  denied,

  /// Denied permanently, so asking again does nothing. Only Settings can undo it.
  deniedForever,

  /// Location is switched off on the device entirely.
  servicesDisabled,

  /// No fix within the time we were prepared to wait.
  timedOut,

  /// The platform refused for some other reason.
  unavailable,
}

class LocationReading {
  const LocationReading({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;

  /// Metres of uncertainty the device itself reports. Passed to the server,
  /// which uses it to decide whether the reading is precise enough to judge —
  /// a ±500 m fix proves nothing either way.
  final double accuracyM;
  final DateTime capturedAt;
}

class LocationResult {
  const LocationResult.success(LocationReading this.reading)
      : failure = null;
  const LocationResult.failed(LocationFailure this.failure) : reading = null;

  final LocationReading? reading;
  final LocationFailure? failure;

  bool get hasFix => reading != null;
}

/// Reads the device's position for a field visit.
///
/// Every failure is a result, never an exception, because none of them may
/// stop a visit being recorded. A group meeting in a valley with location
/// switched off is still a visit that happened; refusing to file it would
/// teach agents that the honest path is the one that loses their work, and
/// they would stop using the app. The server records "no fix" as a fact and
/// leaves the judgement to a human.
class LocationService {
  const LocationService();

  /// How long to wait for a fix. Long enough for a cold GPS start under a
  /// roof, short enough that an agent is not left staring at a spinner.
  static const Duration fixTimeout = Duration(seconds: 20);

  Future<LocationResult> current({Duration? timeout}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(LocationFailure.servicesDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failed(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failed(LocationFailure.denied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          // `high` rather than `best`: best keeps the radio on chasing metres
          // that make no difference to a 50 m geofence, on phones whose battery
          // has to last a day of visits.
          accuracy: LocationAccuracy.high,
          timeLimit: timeout ?? fixTimeout,
        ),
      );

      return LocationResult.success(
        LocationReading(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyM: position.accuracy,
          capturedAt: position.timestamp,
        ),
      );
    } on LocationServiceDisabledException {
      return const LocationResult.failed(LocationFailure.servicesDisabled);
    } on PermissionDeniedException {
      return const LocationResult.failed(LocationFailure.denied);
    } on TimeoutException {
      return const LocationResult.failed(LocationFailure.timedOut);
    } catch (_) {
      return const LocationResult.failed(LocationFailure.unavailable);
    }
  }

  /// Opens the OS screen where the person can undo a permanent refusal.
  Future<void> openSettings() => Geolocator.openAppSettings();
}
