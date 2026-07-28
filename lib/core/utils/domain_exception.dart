/// A business-rule violation with a user-readable message
/// (e.g. "Meeting is closed", "Amount exceeds available limit").
class DomainException implements Exception {
  const DomainException(this.message);

  final String message;

  @override
  String toString() => message;
}
