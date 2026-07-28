import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/group.dart';
import '../../data/models/loan.dart';
import '../../data/models/member.dart';
import '../../data/models/remote/group_report.dart';

/// Builds and shares real PDF reports — a formal document the group can
/// print, email or file, alongside the quick WhatsApp text share.
///
/// Everything is built from the local database, so it works offline; the PDF
/// is written to the app's temp directory and handed to the Android share
/// sheet (WhatsApp, email, Drive, printer — the user chooses).

final _green = PdfColor.fromInt(0xFF1E9E56);
final _ink = PdfColor.fromInt(0xFF14181B);
final _muted = PdfColor.fromInt(0xFF5B6770);

pw.Widget _title(String text) => pw.Text(text,
    style: pw.TextStyle(
        fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink));

pw.Widget _sectionHeader(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(text.toUpperCase(),
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _green,
              letterSpacing: 1.2)),
    );

pw.Widget _kv(String label, String value, {bool emphasize = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10.5, color: _muted)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: _ink)),
        ],
      ),
    );

pw.Widget _footer(pw.Context context) => pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'IntelliCash  -  page ${context.pageNumber} of ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 8.5, color: _muted),
      ),
    );

pw.Widget _headerBlock(String reportName, Group group) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _title(reportName),
        pw.SizedBox(height: 2),
        pw.Text(
          '${group.name}  -  Cycle ${group.cycleNumber}  -  '
          'Generated ${Formatters.fullDate(DateTime.now())}',
          style: pw.TextStyle(fontSize: 10, color: _muted),
        ),
        pw.Divider(color: _green, thickness: 1.2, height: 16),
      ],
    );

pw.Widget _table(List<String> headers, List<List<String>> rows) =>
    pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: _green),
      cellStyle: pw.TextStyle(fontSize: 9.5, color: _ink),
      cellAlignments: {
        for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight,
      },
      cellPadding:
          const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFD8DEE2)),
    );

/// Writes [bytes] to a temp file and opens the system share sheet.
Future<void> _sharePdf(String fileName, List<int> bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/pdf')],
    text: fileName.replaceAll('.pdf', '').replaceAll('_', ' '),
  );
}

String _safeFileName(String name) =>
    name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

/// The whole group's report as a PDF: money, members and meetings.
Future<void> shareGroupPdf({
  required Group group,
  required double totalSavings,
  required double socialFund,
  required double fines,
  required double loansGivenOut,
  required double loansRepaid,
  required double loansStillOwed,
  required double cashBox,
  required List<ReportMemberRow> members,
  required int meetingsThisCycle,
}) async {
  final bytes = await buildGroupPdfBytes(
    group: group,
    totalSavings: totalSavings,
    socialFund: socialFund,
    fines: fines,
    loansGivenOut: loansGivenOut,
    loansRepaid: loansRepaid,
    loansStillOwed: loansStillOwed,
    cashBox: cashBox,
    members: members,
    meetingsThisCycle: meetingsThisCycle,
  );
  await _sharePdf('Group_Report_${_safeFileName(group.name)}.pdf', bytes);
}

/// Pure builder — returns the PDF bytes (also unit-testable).
Future<List<int>> buildGroupPdfBytes({
  required Group group,
  required double totalSavings,
  required double socialFund,
  required double fines,
  required double loansGivenOut,
  required double loansRepaid,
  required double loansStillOwed,
  required double cashBox,
  required List<ReportMemberRow> members,
  required int meetingsThisCycle,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      footer: _footer,
      build: (context) => [
        _headerBlock('Group Report', group),
        _sectionHeader('Group rules'),
        _kv('Share value', Formatters.money(group.shareValue)),
        _kv('Max shares per meeting', '${group.maxSharesPerMeeting}'),
        _kv('Social fund per meeting',
            Formatters.money(group.socialFundAmount)),
        _kv('Interest',
            '${group.interestRate.toStringAsFixed(0)}% ${group.interestType.label.toLowerCase()}'),
        _kv('Meets',
            '${group.meetingFrequency.label.toLowerCase()} on ${group.meetingDaysLabel}'),
        _sectionHeader('Money'),
        _kv('Total savings', Formatters.money(totalSavings)),
        _kv('Social fund', Formatters.money(socialFund)),
        _kv('Fines collected', Formatters.money(fines)),
        _kv('Loans given out', Formatters.money(loansGivenOut)),
        _kv('Loans repaid', Formatters.money(loansRepaid)),
        _kv('Loans still owed', Formatters.money(loansStillOwed)),
        _kv('Money in the box', Formatters.money(cashBox), emphasize: true),
        _sectionHeader('Members (${members.length})'),
        if (members.isEmpty)
          pw.Text('No members yet.',
              style: pw.TextStyle(fontSize: 10, color: _muted))
        else
          _table(
            ['Member', 'Shares', 'Saved', 'Loan owing'],
            [
              for (final m in members)
                [
                  '${m.name}${m.roleLabel != null ? ' (${m.roleLabel})' : ''}',
                  m.shares?.toString() ?? '-',
                  Formatters.money(m.savings),
                  m.owes > 0
                      ? Formatters.money(m.owes)
                      : '-',
                ],
            ],
          ),
        _sectionHeader('Meetings'),
        _kv('Meetings held this cycle', '$meetingsThisCycle'),
      ],
    ),
  );
  return doc.save();
}

/// One member's statement as a PDF — their position, contributions,
/// attendance and loan history.
Future<void> shareMemberPdf({
  required Group group,
  required Member member,
  required double totalSavings,
  required int totalShares,
  required double socialContributions,
  required double finesPaid,
  required double activeLoanBalance,
  required double attendanceRate,
  required List<Loan> loans,
}) async {
  final bytes = await buildMemberPdfBytes(
    group: group,
    member: member,
    totalSavings: totalSavings,
    totalShares: totalShares,
    socialContributions: socialContributions,
    finesPaid: finesPaid,
    activeLoanBalance: activeLoanBalance,
    attendanceRate: attendanceRate,
    loans: loans,
  );
  await _sharePdf('Member_Report_${_safeFileName(member.name)}.pdf', bytes);
}

/// Pure builder — returns the PDF bytes (also unit-testable).
Future<List<int>> buildMemberPdfBytes({
  required Group group,
  required Member member,
  required double totalSavings,
  required int totalShares,
  required double socialContributions,
  required double finesPaid,
  required double activeLoanBalance,
  required double attendanceRate,
  required List<Loan> loans,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      footer: _footer,
      build: (context) => [
        _headerBlock('Member Report', group),
        _sectionHeader('Member'),
        _kv('Name', member.name),
        _kv('Role', member.role.label),
        if (member.phone != null) _kv('Phone', member.phone!),
        _kv('Joined', Formatters.fullDate(member.joinedAt)),
        _sectionHeader('Savings & contributions'),
        _kv('Total savings', Formatters.money(totalSavings), emphasize: true),
        _kv('Shares held', '$totalShares'),
        _kv('Social fund contributed', Formatters.money(socialContributions)),
        _kv('Fines paid', Formatters.money(finesPaid)),
        _kv('Attendance', '${(attendanceRate * 100).round()}%'),
        _sectionHeader('Loans (${loans.length})'),
        if (loans.isEmpty)
          pw.Text('No loans taken.',
              style: pw.TextStyle(fontSize: 10, color: _muted))
        else
          _table(
            ['Taken on', 'Amount', 'Repaid', 'Outstanding', 'Status'],
            [
              for (final loan in loans)
                [
                  Formatters.shortDate(loan.disbursedAt),
                  Formatters.money(loan.principal),
                  Formatters.money(loan.amountRepaid),
                  loan.outstanding > 0
                      ? Formatters.money(loan.outstanding)
                      : '-',
                  loan.status.label,
                ],
            ],
          ),
        if (activeLoanBalance > 0) ...[
          pw.SizedBox(height: 6),
          _kv('Total still owed', Formatters.money(activeLoanBalance),
              emphasize: true),
        ],
      ],
    ),
  );
  return doc.save();
}
