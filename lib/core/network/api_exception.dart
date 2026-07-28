/// A failed API call, carrying a user-readable message and the HTTP status
/// (0 for transport/offline failures).
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode = 0,
    this.details,
    this.code,
  });

  final String message;
  final int statusCode;

  /// The backend's machine-readable reason, e.g. `ALREADY_DECIDED`.
  ///
  /// One status can mean several different things — a 409 on a join decision
  /// is "someone answered first", "confirm the member first", or "that member
  /// already has an account" — and only this tells them apart.
  final String? code;

  /// Field-level validation messages from the backend, when present.
  final Map<String, List<String>>? details;

  bool get isNetworkError => statusCode == 0;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}
