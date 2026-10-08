import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show Rect;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'file_writer.dart' if (dart.library.html) 'file_writer_stub.dart'
    as fileio;
import '../config/api_config.dart';
import '../models/school_profile_model.dart';
import 'web_download_stub.dart' if (dart.library.html) 'web_download.dart'
    as webdl;

/// School branding shared by every export payload (single day and range).
///
/// [ExportService.applySchoolBranding] fills these from the signed-in school's
/// profile, so a report always prints the school's name, motto, contacts and
/// logo when that data is available.
mixin SchoolBrandedExport {
  String get schoolName;
  set schoolName(String value);
  String get schoolMotto;
  set schoolMotto(String value);
  String get schoolEmail;
  set schoolEmail(String value);
  String get schoolPhone;
  set schoolPhone(String value);
  String get schoolWebsite;
  set schoolWebsite(String value);
  String get schoolAddress;
  set schoolAddress(String value);
  Uint8List? get schoolLogoBytes;
  set schoolLogoBytes(Uint8List? value);
}

/// One student row in a report.
class AttendanceExportRow {
  final String roll;
  final String name;
  final String status;
  const AttendanceExportRow({
    required this.roll,
    required this.name,
    this.status = '',
  });
}

/// Everything needed to render a class report (PDF / CSV / Excel).
///
/// For an attendance sheet, [rows] carry statuses; for a plain class roster,
/// leave statuses empty and the Status column is omitted automatically.
/// School fields are filled automatically from the local DB when not set.
class AttendanceExportData with SchoolBrandedExport {
  final String className;
  final String subject;
  final String teacher;
  final String room;
  final DateTime date;
  final List<AttendanceExportRow> rows;

  // School profile (filled via ExportService.applySchoolBranding)
  @override
  String schoolName;
  @override
  String schoolMotto;
  @override
  String schoolEmail;
  @override
  String schoolPhone;
  @override
  String schoolWebsite;
  @override
  String schoolAddress;
  @override
  Uint8List? schoolLogoBytes;

  AttendanceExportData({
    required this.className,
    required this.subject,
    required this.teacher,
    this.room = '',
    required this.date,
    required this.rows,
    this.schoolName = '',
    this.schoolMotto = '',
    this.schoolEmail = '',
    this.schoolPhone = '',
    this.schoolWebsite = '',
    this.schoolAddress = '',
    this.schoolLogoBytes,
  });

  bool get hasStatus => rows.any((r) => r.status.isNotEmpty);

  int get presentCount =>
      rows.where((r) => r.status == 'Present').length;
  int get absentCount =>
      rows.where((r) => r.status == 'Absent').length;
  int get halfDayCount =>
      rows.where((r) => r.status == 'Half Day').length;
  int get leaveCount =>
      rows.where((r) => r.status == 'Leave').length;

  double get presentPercent =>
      rows.isEmpty ? 0 : (100 * presentCount / rows.length);
}

/// One day row in an attendance range report.
class AttendanceHistoryExportDay {
  final DateTime date;
  final int marked;
  final int present;
  final int absent;
  final int percentage;
  const AttendanceHistoryExportDay({
    required this.date,
    this.marked = 0,
    this.present = 0,
    this.absent = 0,
    this.percentage = 0,
  });
}

/// One student row in an attendance range report.
class AttendanceHistoryExportStudent {
  final String roll;
  final String name;
  final int total;
  final int present;
  final int absent;
  final int? percentage;
  const AttendanceHistoryExportStudent({
    required this.roll,
    required this.name,
    this.total = 0,
    this.present = 0,
    this.absent = 0,
    this.percentage,
  });
}

/// One raw record line in an attendance range report.
class AttendanceHistoryExportRecord {
  final DateTime date;
  final String name;
  final String status;
  const AttendanceHistoryExportRecord({
    required this.date,
    required this.name,
    required this.status,
  });
}

/// Everything needed to render an attendance report for a date RANGE
/// (week / month / quarter / year / custom), as built from the teacher's
/// attendance history screen.
class AttendanceHistoryExportData with SchoolBrandedExport {
  final String className;
  final String subject;
  final String teacher;
  final String room;
  final DateTime from;
  final DateTime to;
  final int totalRecords;
  final int markedDays;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;
  final int halfDayCount;
  final int percentage;
  final List<AttendanceHistoryExportDay> days;
  final List<AttendanceHistoryExportStudent> students;
  final List<AttendanceHistoryExportRecord> records;

  // School profile (filled via ExportService.applySchoolBranding)
  @override
  String schoolName;
  @override
  String schoolMotto;
  @override
  String schoolEmail;
  @override
  String schoolPhone;
  @override
  String schoolWebsite;
  @override
  String schoolAddress;
  @override
  Uint8List? schoolLogoBytes;

  AttendanceHistoryExportData({
    required this.className,
    required this.subject,
    required this.teacher,
    this.room = '',
    required this.from,
    required this.to,
    this.totalRecords = 0,
    this.markedDays = 0,
    this.presentCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.leaveCount = 0,
    this.halfDayCount = 0,
    this.percentage = 0,
    this.days = const [],
    this.students = const [],
    this.records = const [],
    this.schoolName = '',
    this.schoolMotto = '',
    this.schoolEmail = '',
    this.schoolPhone = '',
    this.schoolWebsite = '',
    this.schoolAddress = '',
    this.schoolLogoBytes,
  });
}

/// Builds and delivers attendance reports: PDF (download / share / print),
/// CSV and Excel (share). Works on mobile, desktop and web.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  static const _teal = PdfColor.fromInt(0xFF0D9488);
  static const _navy = PdfColor.fromInt(0xFF1E3A8A);

  String _fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  String _fmtDateShort(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d);

  String _fmtTimestamp(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);

  /// Detailed-records rows are capped so a full-year range still generates
  /// quickly on a low-end phone; the day & student tables always cover the
  /// whole range regardless.
  static const _maxRecordRows = 800;

  /// Days listed in a range report's daily table (a full year fits).
  static const _maxRangeDays = 366;

  /// Copies the school's name, motto, contacts, address and logo onto an
  /// export payload. Best effort: a missing profile or logo never blocks the
  /// report.
  Future<void> applySchoolBranding(
    SchoolBrandedExport data,
    SchoolProfileModel? profile,
  ) async {
    if (profile != null) {
      data.schoolName = profile.schoolName;
      data.schoolMotto = profile.motto ?? '';
      data.schoolEmail = profile.contactEmail ?? '';
      data.schoolPhone = profile.contactNumber ?? '';
      data.schoolWebsite = profile.website ?? '';
      data.schoolAddress = profile.address ?? '';
    }
    data.schoolLogoBytes =
        await fetchLogoBytes(profile?.logoUrlFor(ApiConfig.webAdminUrl));
  }

  /// Best-effort download of the school logo so printed reports carry the
  /// school's branding. Returns null on any failure — reports render fine
  /// without a logo.
  Future<Uint8List?> fetchLogoBytes(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  /// Fills [data]'s school-profile fields — in the main app these are
  /// passed as parameters; this is a no-op placeholder.
  Future<void> _fillSchool(AttendanceExportData data) async {
    // School profile data is passed via AttendanceExportData parameters.
    // No local DB needed for the main app.
  }

  // ------------------------------------------------------------------
  // PDF
  // ------------------------------------------------------------------
  Future<Uint8List> buildPdf(
    AttendanceExportData data, {
    Uint8List? signatureBytes,
    String? signedByName,
  }) async {
    await _fillSchool(data);
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    if (data.schoolLogoBytes != null)
                      pw.Container(
                        width: 36,
                        height: 36,
                        margin: const pw.EdgeInsets.only(right: 10),
                        child: pw.Image(pw.MemoryImage(data.schoolLogoBytes!)),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(data.schoolName,
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: _teal)),
                        if (data.schoolMotto.isNotEmpty)
                          pw.Text(data.schoolMotto,
                              style: pw.TextStyle(
                                  fontSize: 8, color: PdfColors.grey600)),
                      ],
                    ),
                  ],
                ),
                pw.Text('Attendance Report',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold, color: _navy)),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: _teal, thickness: 1.2),
          pw.SizedBox(height: 6),
          if (data.schoolPhone.isNotEmpty || data.schoolEmail.isNotEmpty || data.schoolWebsite.isNotEmpty)
            pw.Text(
              [
                if (data.schoolPhone.isNotEmpty) 'Phone: ${data.schoolPhone}',
                if (data.schoolEmail.isNotEmpty) 'Email: ${data.schoolEmail}',
                if (data.schoolWebsite.isNotEmpty) data.schoolWebsite,
              ].join('  |  '),
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          if (data.schoolAddress.isNotEmpty)
            pw.Text('Address: ${data.schoolAddress}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _meta('Class', data.className),
              _meta('Subject', data.subject),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              _meta('Date', _fmtDate(data.date)),
              _meta('Teacher', data.teacher),
              if (data.room.isNotEmpty) _meta('Room', data.room),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: _teal),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              if (data.hasStatus) 3: pw.Alignment.center,
            },
            headers: [
              '#',
              'Roll No',
              'Student Name',
              if (data.hasStatus) 'Status',
            ],
            data: [
              for (var i = 0; i < data.rows.length; i++)
                [
                  '${i + 1}',
                  data.rows[i].roll,
                  data.rows[i].name,
                  if (data.hasStatus) data.rows[i].status,
                ],
            ],
            border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
          ),
          pw.SizedBox(height: 20),
          _summaryBox(data),
          pw.SizedBox(height: 28),
          // Handwritten electronic signature — always the LAST block of the
          // report, per the school's e-signature spec.
          _signatureBlock(
              signatureBytes: signatureBytes, signedByName: signedByName),
        ],
      ),
    );
    return doc.save();
  }

  // ------------------------------------------------------------------
  // Range PDF (attendance history: week / month / quarter / year / custom)
  // ------------------------------------------------------------------

  /// Builds a multi-page attendance report for a date range: summary,
  /// daily breakdown, per-student breakdown and (optionally) the raw
  /// record list. Printed via the system print dialog or shared as PDF.
  Future<Uint8List> buildHistoryPdf(
    AttendanceHistoryExportData data, {
    Uint8List? signatureBytes,
    String? signedByName,
  }) async {
    final doc = pw.Document();

    final records = [...data.records]
      ..sort((a, b) => a.date.compareTo(b.date));
    final shown = records.length > _maxRecordRows
        ? records.sublist(0, _maxRecordRows)
        : records;

    // One row per calendar day of the period. Days nobody marked stay blank
    // (—): the register must never invent a status for a day that was never
    // taken, but the teacher still needs to see the day is missing.
    final markedByDay = {
      for (final d in data.days)
        DateTime(d.date.year, d.date.month, d.date.day): d,
    };
    final rangeFirst =
        DateTime(data.from.year, data.from.month, data.from.day);
    final rangeLast = DateTime(data.to.year, data.to.month, data.to.day);
    final totalDays = rangeLast.isBefore(rangeFirst)
        ? 0
        : rangeLast.difference(rangeFirst).inDays + 1;
    final dayRows = <List<String>>[];
    for (var i = 0; i < totalDays && i < _maxRangeDays; i++) {
      final day = DateTime(rangeFirst.year, rangeFirst.month, rangeFirst.day + i);
      final marked = markedByDay[day];
      dayRows.add([
        _fmtDateShort(day),
        marked == null ? '—' : '${marked.marked}',
        marked == null ? '—' : '${marked.present}',
        marked == null ? '—' : '${marked.absent}',
        marked == null ? '—' : '${marked.percentage}%',
      ]);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('School Connect • Page ${ctx.pageNumber}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  if (data.schoolLogoBytes != null)
                    pw.Container(
                      width: 36,
                      height: 36,
                      margin: const pw.EdgeInsets.only(right: 10),
                      child: pw.Image(pw.MemoryImage(data.schoolLogoBytes!)),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          data.schoolName.isEmpty ? 'School' : data.schoolName,
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: _teal)),
                      if (data.schoolMotto.isNotEmpty)
                        pw.Text(data.schoolMotto,
                            style: pw.TextStyle(
                                fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.Text('Attendance Report',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: _teal, thickness: 1.2),
          pw.SizedBox(height: 6),
          if (data.schoolPhone.isNotEmpty ||
              data.schoolEmail.isNotEmpty ||
              data.schoolWebsite.isNotEmpty)
            pw.Text(
              [
                if (data.schoolPhone.isNotEmpty)
                  'Phone: ${data.schoolPhone}',
                if (data.schoolEmail.isNotEmpty)
                  'Email: ${data.schoolEmail}',
                if (data.schoolWebsite.isNotEmpty) data.schoolWebsite,
              ].join('  |  '),
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          if (data.schoolAddress.isNotEmpty)
            pw.Text('Address: ${data.schoolAddress}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _meta('Class', data.className),
              _meta('Subject', data.subject),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              _meta('Period', '${_fmtDate(data.from)} — ${_fmtDate(data.to)}'),
              _meta('Teacher', data.teacher),
              if (data.room.isNotEmpty) _meta('Room', data.room),
            ],
          ),
          pw.SizedBox(height: 18),
          _historySummaryBox(data),
          pw.SizedBox(height: 18),
          _sectionTitle('Daily Breakdown'),
          pw.SizedBox(height: 2),
          pw.Text(
            'Days marked: ${data.markedDays} of $totalDays in the period.',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          if (data.days.isEmpty)
            _emptyNote('No attendance was marked in this period — every day below '
                'is left blank.')
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: _teal),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              headers: ['Date', 'Marked', 'Present', 'Absent', 'Present %'],
              data: dayRows,
              border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
            ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Text(
              dayRows.length < totalDays
                  ? 'Showing the first $_maxRangeDays days of this $totalDays-day '
                      'period — narrow the range for the rest.'
                  : 'Days without a mark (—) were never taken, so they carry no status.',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey600),
            ),
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Student Breakdown'),
          pw.SizedBox(height: 6),
          if (data.students.isEmpty)
            _emptyNote('No student records in this period.')
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: _teal),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
              },
              headers: [
                'Roll No',
                'Student Name',
                'Total',
                'Present',
                'Absent',
                'Attendance %',
              ],
              data: [
                for (final s in data.students)
                  [
                    s.roll,
                    s.name,
                    '${s.total}',
                    '${s.present}',
                    '${s.absent}',
                    s.percentage == null ? '—' : '${s.percentage}%',
                  ],
              ],
              border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
            ),
          if (shown.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _sectionTitle('Detailed Records'),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: _teal),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
              },
              headers: ['#', 'Date', 'Student', 'Status'],
              data: [
                for (var i = 0; i < shown.length; i++)
                  [
                    '${i + 1}',
                    _fmtDateShort(shown[i].date),
                    shown[i].name,
                    shown[i].status,
                  ],
              ],
              border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
            ),
            if (records.length > shown.length)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Text(
                  '…and ${records.length - shown.length} more records — narrow the date range to see full detail.',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600),
                ),
              ),
          ],
          pw.SizedBox(height: 26),
          // Handwritten electronic signature — always the LAST block of the
          // report, per the school's e-signature spec.
          _signatureBlock(
              signatureBytes: signatureBytes, signedByName: signedByName),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _historySummaryBox(AttendanceHistoryExportData data) {
    final cells = <(String, String)>[
      ('Total Records', '${data.totalRecords}'),
      ('Marked Days', '${data.markedDays}'),
      ('Present', '${data.presentCount}'),
      ('Absent', '${data.absentCount}'),
      ('Late', '${data.lateCount}'),
      ('Half Day', '${data.halfDayCount}'),
      ('Leave', '${data.leaveCount}'),
      ('Attendance %', '${data.percentage}%'),
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF0FDFA),
        border: pw.Border.all(color: _teal, width: 0.8),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Summary',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold, color: _teal)),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 22,
            runSpacing: 6,
            children: [
              for (final (label, value) in cells)
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text('$label: ',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(value,
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _navy)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _teal, width: 1)),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: _navy)),
    );
  }

  pw.Widget _emptyNote(String text) {
    return pw.Text(text,
        style: pw.TextStyle(
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey600));
  }

  /// Bottom-of-report signature block. With a drawn signature: the ink
  /// image sits on the rule line, with the signer name and a
  /// "Signed electronically on `date, time`" note. Without one it degrades
  /// to the plain "Teacher Signature" line.
  pw.Widget _signatureBlock({Uint8List? signatureBytes, String? signedByName}) {
    final has = signatureBytes != null && signatureBytes.isNotEmpty;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (has) ...[
              pw.Image(
                pw.MemoryImage(signatureBytes),
                height: 58,
                fit: pw.BoxFit.contain,
                alignment: pw.Alignment.bottomLeft,
              ),
              pw.SizedBox(height: 2),
              if (signedByName != null && signedByName.isNotEmpty)
                pw.Text(signedByName,
                    style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy)),
              pw.Text(
                  'Signed electronically on ${_fmtTimestamp(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ] else
              pw.Text('Teacher Signature',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 20),
            pw.Container(width: 200, child: pw.Divider(color: PdfColors.grey400)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Generated: ${_fmtDate(DateTime.now())}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(has ? 'Digitally signed' : 'School Connect',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    );
  }

  pw.Widget _meta(String label, String value) {
    return pw.Expanded(
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(
              text: '$label:  ',
              style: pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
          pw.TextSpan(
              text: value,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
        ]),
      ),
    );
  }

  pw.Widget _summaryBox(AttendanceExportData data) {
    final cells = <(String, String)>[
      ('Total Students', '${data.rows.length}'),
      if (data.hasStatus) ...[
        ('Present', '${data.presentCount}'),
        ('Absent', '${data.absentCount}'),
        ('Half Day', '${data.halfDayCount}'),
        ('Leave', '${data.leaveCount}'),
        ('Present %', '${data.presentPercent.toStringAsFixed(1)}%'),
      ],
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF0FDFA),
        border: pw.Border.all(color: _teal, width: 0.8),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Summary',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold, color: _teal)),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 22,
            runSpacing: 6,
            children: [
              for (final (label, value) in cells)
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text('$label: ',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(value,
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // CSV
  // ------------------------------------------------------------------
  Future<String> buildCsv(AttendanceExportData data) async {
    await _fillSchool(data);
    final rows = <List<dynamic>>[
      ['School', data.schoolName],
      if (data.schoolMotto.isNotEmpty) ['Motto', data.schoolMotto],
      if (data.schoolPhone.isNotEmpty) ['Phone', data.schoolPhone],
      if (data.schoolEmail.isNotEmpty) ['Email', data.schoolEmail],
      if (data.schoolWebsite.isNotEmpty) ['Website', data.schoolWebsite],
      if (data.schoolAddress.isNotEmpty) ['Address', data.schoolAddress],
      ['Class', data.className],
      ['Subject', data.subject],
      ['Teacher', data.teacher],
      if (data.room.isNotEmpty) ['Room', data.room],
      ['Date', _fmtDate(data.date)],
      [],
      [
        '#',
        'Roll No',
        'Student Name',
        if (data.hasStatus) 'Status',
      ],
      for (var i = 0; i < data.rows.length; i++)
        [
          i + 1,
          data.rows[i].roll,
          data.rows[i].name,
          if (data.hasStatus) data.rows[i].status,
        ],
      [],
      ['Total Students', data.rows.length],
      ['Present', data.presentCount],
      ['Absent', data.absentCount],
      ['Half Day', data.halfDayCount],
      ['Leave', data.leaveCount],
      ['Present %', '${data.presentPercent.toStringAsFixed(1)}%'],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  // ------------------------------------------------------------------
  // Excel
  // ------------------------------------------------------------------
  Future<Uint8List> buildExcel(AttendanceExportData data) async {
    await _fillSchool(data);
    final excel = Excel.createExcel();
    final sheet = excel['Attendance'];
    excel.setDefaultSheet('Attendance');

    final headerStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('FF0D9488'),
        fontSize: 12);

    void meta(String label, String value) {
      sheet.appendRow([TextCellValue('$label:'), TextCellValue(value)]);
    }

    meta('School', data.schoolName);
    if (data.schoolPhone.isNotEmpty) meta('Phone', data.schoolPhone);
    if (data.schoolEmail.isNotEmpty) meta('Email', data.schoolEmail);
    if (data.schoolWebsite.isNotEmpty) meta('Website', data.schoolWebsite);
    if (data.schoolAddress.isNotEmpty) meta('Address', data.schoolAddress);
    meta('Class', data.className);
    meta('Subject', data.subject);
    meta('Teacher', data.teacher);
    if (data.room.isNotEmpty) meta('Room', data.room);
    meta('Date', _fmtDate(data.date));
    sheet.appendRow([]);

    sheet.appendRow([
      TextCellValue('#'),
      TextCellValue('Roll No'),
      TextCellValue('Student Name'),
      if (data.hasStatus) TextCellValue('Status'),
    ]);
    for (final c in sheet.rows.last) {
      c?.cellStyle = headerStyle;
    }

    for (var i = 0; i < data.rows.length; i++) {
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(data.rows[i].roll),
        TextCellValue(data.rows[i].name),
        if (data.hasStatus) TextCellValue(data.rows[i].status),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('Summary')]);
    sheet.appendRow([TextCellValue('Total Students'), IntCellValue(data.rows.length)]);
    sheet.appendRow([TextCellValue('Present'), IntCellValue(data.presentCount)]);
    sheet.appendRow([TextCellValue('Absent'), IntCellValue(data.absentCount)]);
    sheet.appendRow([TextCellValue('Half Day'), IntCellValue(data.halfDayCount)]);
    sheet.appendRow([TextCellValue('Leave'), IntCellValue(data.leaveCount)]);
    sheet.appendRow([
      TextCellValue('Present %'),
      TextCellValue('${data.presentPercent.toStringAsFixed(1)}%'),
    ]);

    final saved = excel.save();
    if (saved == null) {
      throw Exception('Excel export failed');
    }
    return Uint8List.fromList(saved);
  }

  // ------------------------------------------------------------------
  // Delivery: downloads / share / print
  // ------------------------------------------------------------------

  /// Saves [bytes] to the system Downloads folder (desktop), the browser
  /// download (web) or the app documents (mobile fallback).
  /// Returns a human-readable location message.
  Future<String> saveToDownloads(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      webdl.triggerDownload(bytes, filename);
      return 'Downloading $filename…';
    }
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) {
        final path = await fileio.writeBytesToDir(dir.path, filename, bytes);
        return 'Saved to $path';
      }
    } catch (_) {}
    final docs = await getApplicationDocumentsDirectory();
    final path = await fileio.writeBytesToDir(docs.path, filename, bytes);
    return 'Saved to $path';
  }

  /// Shares [bytes] via the platform share sheet — on mobile this opens the
  /// system sheet with **every installed app that accepts files** (WhatsApp,
  /// Gmail, Drive, Files, …); on web it uses the Web Share API (same OS
  /// sheet on mobile browsers / Chrome & Edge), falling back to a browser
  /// download where the API isn't available.
  Future<void> shareBytes(
    Uint8List bytes,
    String filename,
    String mimeType, {
    String? text,
  }) async {
    if (kIsWeb) {
      final shared = await webdl.shareViaWeb(
        bytes,
        filename,
        mimeType,
        text: text,
      );
      if (!shared) webdl.triggerDownload(bytes, filename);
      return;
    }
    final xfile = XFile.fromData(bytes, mimeType: mimeType, name: filename);
    await Share.shareXFiles(
      [xfile],
      text: text,
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 200, 200),
    );
  }

  /// Shares a plain-text file (e.g. CSV) — same share-sheet behaviour as
  /// [shareBytes].
  Future<void> shareTextFile(String content, String filename) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (kIsWeb) {
      final shared = await webdl.shareViaWeb(
        bytes,
        filename,
        'text/csv',
        text: 'Attendance report $filename',
      );
      if (!shared) webdl.triggerDownload(bytes, filename);
      return;
    }
    final xfile = XFile.fromData(bytes, mimeType: 'text/csv', name: filename);
    await Share.shareXFiles(
      [xfile],
      text: 'Attendance report $filename',
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 200, 200),
    );
  }

  /// Opens the system print dialog for [bytes].
  Future<void> printBytes(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }
}

