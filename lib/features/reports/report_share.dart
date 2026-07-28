import 'package:share_plus/share_plus.dart';

/// Opens the phone's share sheet (WhatsApp, SMS, email…) with a
/// plain-text report. [title] becomes the subject where the target
/// app supports one (e.g. email).
Future<void> shareReport(String title, String body) async {
  await Share.share(body, subject: title);
}

/// One labelled line of a plain-text report, e.g. `Total savings: KSh 500`.
/// Kept deliberately simple so the text stays readable in WhatsApp.
String reportLine(String label, String value) => '$label: $value';
