import '../models/remote/remote_models.dart';

/// Digits in a Kenyan subscriber number, after the 254 country code.
const _localDigits = 9;

/// Kenyan mobile numbers get written many ways — often by the same person on
/// different days, and often copied off a letterhead:
///
///   0712345678        +254712345678         254712345678
///   712345678         +254 (0)712 345 678   00254 712 345 678
///
/// Must stay in step with `apps/api/src/lib/phone.ts` on the server: if the
/// two disagree, the phone and the backend reach different conclusions about
/// who a person is.
String normalisePhone(String? phone) {
  var digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';

  // `00` is the international access code — the dialled equivalent of a `+`.
  if (digits.startsWith('00')) digits = digits.substring(2);

  if (digits.startsWith('254')) {
    var rest = digits.substring(3);
    // "+254 (0)712…" — the national trunk `0` is redundant after the country
    // code, but people write it constantly. Dropping it is safe because no
    // real Kenyan number has ten digits after 254.
    if (rest.startsWith('0')) rest = rest.substring(1);
    return rest.length == _localDigits ? '254$rest' : digits;
  }

  if (digits.startsWith('0')) {
    final rest = digits.substring(1);
    return rest.length == _localDigits ? '254$rest' : digits;
  }

  if (digits.length == _localDigits) return '254$digits';

  // Not recognisably Kenyan (a foreign number, or simply too short). Return
  // the digits unchanged rather than inventing a country code — two different
  // lines must never collapse into one.
  return digits;
}

/// Whether an entered string could be a phone number at all.
///
/// Judges the digits, not the punctuation — people type `+254 712 345 678`
/// and `0712-345-678`, and refusing those for their spacing tells a member
/// their own number is invalid. Mirrors `looksLikePhone` on the server so the
/// app never accepts something the backend will reject.
bool looksLikePhone(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length >= 9 && digits.length <= 15;
}

/// True when two differently-written numbers belong to the same line.
///
/// An unrecognisable number matches nothing, including another unrecognisable
/// one — better to refuse than to merge two people.
bool samePhone(String? a, String? b) {
  final left = normalisePhone(a);
  final right = normalisePhone(b);
  return left.isNotEmpty && left == right;
}

/// Finds the server's record for a member the phone knows locally.
///
/// Members created on the handset carry a client-side UUID that the server has
/// never seen, so the only way across is the phone number.
///
/// This is deliberately strict: it returns a match only when the phone is
/// known AND exactly one member on the server has it. A near-enough guess here
/// would show one member's savings and loans under another member's name, so
/// an ambiguous or missing phone yields null and the caller falls back to the
/// figures held on this phone.
RemoteMember? matchRemoteMember(String? localPhone, List<RemoteMember> roster) {
  final wanted = normalisePhone(localPhone);
  if (wanted.isEmpty) return null;

  RemoteMember? found;
  for (final candidate in roster) {
    if (normalisePhone(candidate.phone) != wanted) continue;
    // Two people on the same number — we cannot tell them apart, so refuse.
    if (found != null) return null;
    found = candidate;
  }
  return found;
}
