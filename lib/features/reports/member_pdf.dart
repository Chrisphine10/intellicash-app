import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/remote/member_overview.dart';
import '../../data/models/remote/member_passbook.dart';

/// PDFs a member can produce for themselves, from the server's own figures.
///
/// Separate from `pdf_report.dart`, which builds from the local database for
/// a group official. These take the remote passbook, so a member downloading
/// their statement gets exactly what the server holds, with no on-phone
/// arithmetic that could drift from it.
///
/// Helvetica has no Unicode, so every string here stays ASCII: an em-dash or
/// a middle dot renders as a blank box.

const _ink = PdfColor.fromInt(0xFF16202A);
const _muted = PdfColor.fromInt(0xFF64727F);

pw.Widget _heading(String title, String subtitle) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 17, fontWeight: pw.FontWeight.bold, color: _ink)),
        pw.SizedBox(height: 2),
        pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: _muted)),
        pw.SizedBox(height: 14),
      ],
    );

pw.Widget _sectionLabel(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(text.toUpperCase(),
          style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted)),
    );

pw.Widget _row(String label, String value, {bool strong = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10.5, color: _ink)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10.5,
                  color: _ink,
                  fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );

pw.Widget _footer(pw.Context context) => pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'IntelliCash  -  page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8.5, color: _muted),
      ),
    );

Future<void> _share(String fileName, List<int> bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/pdf')],
    text: fileName.replaceAll('.pdf', '').replaceAll('_', ' '),
  );
}

String _safe(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

/// One group's statement, from that group's passbook.
Future<List<int>> buildPassbookPdfBytes(MemberPassbook book) async {
  final doc = pw.Document();
  final owing = book.loanOutstanding;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
      footer: _footer,
      build: (context) => [
        _heading(
          'My Savings Statement',
          '${book.memberName}  -  ${book.groupName ?? 'Group'}  -  '
              '${Formatters.fullDate(DateTime.now())}',
        ),
        _sectionLabel('What I have paid in'),
        _row('Shares bought', Formatters.money(book.shares)),
        _row('Social fund', Formatters.money(book.social)),
        if (book.fines > 0) _row('Fines paid', Formatters.money(book.fines)),
        pw.Divider(height: 14),
        _row('Total paid in', Formatters.money(book.totalPaidIn), strong: true),
        _sectionLabel('My loans'),
        _row('Loans received', Formatters.money(book.loansReceived)),
        _row('Repaid', Formatters.money(book.loansRepaid)),
        // Shown separately so "still owing" is not larger than received minus
        // repaid for reasons the member cannot see on the page.
        if (book.loanInterest > 0)
          _row('Interest charged', Formatters.money(book.loanInterest)),
        pw.Divider(height: 14),
        _row('Still owing', Formatters.money(owing), strong: true),
        if (book.attendanceTotal > 0) ...[
          _sectionLabel('Attendance'),
          _row('Meetings attended',
              '${book.attendancePresent} of ${book.attendanceTotal}'),
        ],
        pw.SizedBox(height: 18),
        pw.Text(
          'Figures confirmed by the IntelliCash server.',
          style: const pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
      ],
    ),
  );
  return doc.save();
}

Future<void> sharePassbookPdf(MemberPassbook book) async {
  final bytes = await buildPassbookPdfBytes(book);
  await _share(
    'My_Statement_${_safe(book.groupName ?? 'Group')}.pdf',
    bytes,
  );
}

/// Every group at once: a combined total, then each group on its own.
Future<List<int>> buildOverviewPdfBytes(MemberOverview overview) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
      footer: _footer,
      build: (context) => [
        _heading(
          'My Savings - All Groups',
          '${overview.memberName}  -  ${overview.groupCount} '
              '${overview.groupCount == 1 ? 'group' : 'groups'}  -  '
              '${Formatters.fullDate(DateTime.now())}',
        ),
        _sectionLabel('Everything together'),
        _row('Shares bought', Formatters.money(overview.shares)),
        _row('Social fund', Formatters.money(overview.social)),
        if (overview.fines > 0) _row('Fines paid', Formatters.money(overview.fines)),
        pw.Divider(height: 14),
        _row('Total paid in', Formatters.money(overview.totalPaidIn), strong: true),
        pw.SizedBox(height: 6),
        _row('Loans received', Formatters.money(overview.loansReceived)),
        _row('Repaid', Formatters.money(overview.loansRepaid)),
        if (overview.loanInterest > 0)
          _row('Interest charged', Formatters.money(overview.loanInterest)),
        pw.Divider(height: 14),
        _row('Still owing', Formatters.money(overview.loanOutstanding), strong: true),
        // Money the member has RECEIVED, which a statement of contributions
        // alone would leave out entirely.
        if (overview.welfareReceived > 0)
          _row('Welfare received', Formatters.money(overview.welfareReceived)),
        if (overview.shareOutReceived > 0)
          _row('Share-outs paid to me', Formatters.money(overview.shareOutReceived)),

        // Then each group on its own, so the totals above can be checked.
        for (final position in overview.groups) ...[
          _sectionLabel(position.groupName),
          _row('Shares bought', Formatters.money(position.passbook.shares)),
          _row('Social fund', Formatters.money(position.passbook.social)),
          if (position.passbook.fines > 0)
            _row('Fines paid', Formatters.money(position.passbook.fines)),
          _row('Total paid in', Formatters.money(position.passbook.totalPaidIn),
              strong: true),
          _row('Loans received', Formatters.money(position.passbook.loansReceived)),
          _row('Repaid', Formatters.money(position.passbook.loansRepaid)),
          _row('Still owing', Formatters.money(position.passbook.loanOutstanding),
              strong: true),
        ],

        pw.SizedBox(height: 18),
        pw.Text(
          'Amounts owed are counted per group. Paying extra in one group does '
          'not reduce what is owed in another.',
          style: const pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Figures confirmed by the IntelliCash server.',
          style: const pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
      ],
    ),
  );
  return doc.save();
}

Future<void> shareOverviewPdf(MemberOverview overview) async {
  final bytes = await buildOverviewPdfBytes(overview);
  await _share('My_Savings_All_Groups_${_safe(overview.memberName)}.pdf', bytes);
}
