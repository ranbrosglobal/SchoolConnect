import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/export_service.dart';
import 'signature_pad_sheet.dart';

/// The period an attendance export should cover.
enum AttendanceExportPeriod { day, week, month, lastSixMonths, custom }

/// A picked export period. [from]/[to] are inclusive calendar days.
class AttendanceExportPeriodChoice {
  final AttendanceExportPeriod period;
  final DateTime from;
  final DateTime to;
  const AttendanceExportPeriodChoice(this.period, this.from, this.to);

  bool get isSingleDay => period == AttendanceExportPeriod.day;
}

/// First and last day of the calendar month containing [d].
(DateTime, DateTime) monthBounds(DateTime d) =>
    (DateTime(d.year, d.month, 1), DateTime(d.year, d.month + 1, 0));

/// Asks which period to export before anything is built: the day on screen,
/// this full week (Mon–Sun), this full month, the last six months including
/// the current one, or a custom range.
///
/// Returns null when the teacher dismisses the sheet. Days nobody marked stay
/// blank in the report — no status is ever invented for them.
Future<AttendanceExportPeriodChoice?> showAttendanceExportPeriodSheet(
  BuildContext context, {
  required DateTime day,
}) {
  final today = DateTime(day.year, day.month, day.day);
  final monday = today.subtract(Duration(days: today.weekday - DateTime.monday));
  final sunday = monday.add(const Duration(days: 6));
  final (monthStart, monthEnd) = monthBounds(today);
  final sixStart = DateTime(today.year, today.month - 5, 1);
  final df = DateFormat('d MMM yyyy');
  final dfShort = DateFormat('d MMM');

  Widget tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required AttendanceExportPeriodChoice choice,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A8A).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: () => Navigator.of(context).pop(choice),
    );
  }

  return showModalBottomSheet<AttendanceExportPeriodChoice>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export attendance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            Text(
              'Which period should the report cover?',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            tile(
              icon: Icons.today_outlined,
              title: 'This day',
              subtitle: DateFormat('EEE, d MMM yyyy').format(today),
              choice: AttendanceExportPeriodChoice(
                  AttendanceExportPeriod.day, today, today),
            ),
            tile(
              icon: Icons.view_week_outlined,
              title: 'This full week',
              subtitle: 'Mon ${dfShort.format(monday)} — Sun ${dfShort.format(sunday)}',
              choice: AttendanceExportPeriodChoice(
                  AttendanceExportPeriod.week, monday, sunday),
            ),
            tile(
              icon: Icons.calendar_month_outlined,
              title: 'This full month',
              subtitle: '${df.format(monthStart)} — ${df.format(monthEnd)}',
              choice: AttendanceExportPeriodChoice(
                  AttendanceExportPeriod.month, monthStart, monthEnd),
            ),
            tile(
              icon: Icons.calendar_view_month_outlined,
              title: 'Past 6 months',
              subtitle:
                  '${df.format(sixStart)} — ${df.format(monthEnd)} (includes this month)',
              choice: AttendanceExportPeriodChoice(
                  AttendanceExportPeriod.lastSixMonths, sixStart, monthEnd),
            ),
            tile(
              icon: Icons.date_range_outlined,
              title: 'Custom range',
              subtitle: 'Pick any start and end date',
              choice: AttendanceExportPeriodChoice(
                  AttendanceExportPeriod.custom, today, today),
            ),
            const SizedBox(height: 4),
            Text(
              'Days nobody marked are left blank in the report — no attendance '
              'is assumed for them.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows the export options sheet (Download PDF / Share PDF / Print PDF /
/// Share Excel / Share CSV) for [data]. Shared by the teacher's class roster
/// and attendance screens.
Future<void> showExportSheet(BuildContext context, AttendanceExportData data) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export — ${data.subject}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            Text(
              '${data.className} • ${DateFormat('dd MMM yyyy').format(data.date)} • ${data.rows.length} students',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            const _SectionLabel('Signed PDF'),
            _exportTile(
              icon: Icons.draw_rounded,
              color: const Color(0xFF2E7D32),
              title: 'Print Signed PDF',
              subtitle: 'Sign, then send to a printer',
              onTap: _signedJob(context, (sig) async {
                final bytes = await ExportService.instance
                    .buildPdf(data, signatureBytes: sig, signedByName: data.teacher);
                await ExportService.instance.printBytes(bytes);
                return 'Printing…';
              }),
            ),
            _exportTile(
              icon: Icons.download_rounded,
              color: const Color(0xFF2E7D32),
              title: 'Download Signed PDF',
              subtitle: 'Sign, then save to Downloads',
              onTap: _signedJob(context, (sig) async {
                final bytes = await ExportService.instance
                    .buildPdf(data, signatureBytes: sig, signedByName: data.teacher);
                return ExportService.instance
                    .saveToDownloads(bytes, _signedFileName(_fileName(data, 'pdf')));
              }),
            ),
            _exportTile(
              icon: Icons.mark_email_read_outlined,
              color: const Color(0xFF2E7D32),
              title: 'Share Signed PDF',
              subtitle: 'Sign, then share via WhatsApp, mail…',
              onTap: _signedJob(context, (sig) async {
                final bytes = await ExportService.instance
                    .buildPdf(data, signatureBytes: sig, signedByName: data.teacher);
                await ExportService.instance.shareBytes(
                  bytes,
                  _signedFileName(_fileName(data, 'pdf')),
                  'application/pdf',
                  text: 'Signed report ${data.subject} ${data.className}',
                );
                return 'Sharing…';
              }),
            ),
            const _SectionLabel('Unsigned PDF'),
            _exportTile(
              icon: Icons.picture_as_pdf,
              color: const Color(0xFFE53935),
              title: 'Download PDF',
              subtitle: 'Saved to your Downloads folder',
              onTap: () => _runExport(sheetCtx, () async {
                final bytes = await ExportService.instance.buildPdf(data);
                final msg = await ExportService.instance
                    .saveToDownloads(bytes, _fileName(data, 'pdf'));
                return msg;
              }),
            ),
            _exportTile(
              icon: Icons.share,
              color: const Color(0xFF1976D2),
              title: 'Share PDF',
              subtitle: 'WhatsApp, mail, files & more',
              onTap: () => _runExport(sheetCtx, () async {
                final bytes = await ExportService.instance.buildPdf(data);
                await ExportService.instance.shareBytes(
                  bytes,
                  _fileName(data, 'pdf'),
                  'application/pdf',
                  text: 'Report ${data.subject} ${data.className}',
                );
                return 'Sharing…';
              }),
            ),
            _exportTile(
              icon: Icons.print,
              color: const Color(0xFF2E7D32),
              title: 'Print PDF',
              subtitle: 'Send straight to a printer',
              onTap: () => _runExport(sheetCtx, () async {
                final bytes = await ExportService.instance.buildPdf(data);
                await ExportService.instance.printBytes(bytes);
                return 'Printing…';
              }),
            ),
            _exportTile(
              icon: Icons.table_chart,
              color: const Color(0xFF7C4DFF),
              title: 'Share Excel (.xlsx)',
              subtitle: 'Editable spreadsheet for records',
              onTap: () => _runExport(sheetCtx, () async {
                final bytes = await ExportService.instance.buildExcel(data);
                await ExportService.instance.shareBytes(
                  bytes,
                  _fileName(data, 'xlsx'),
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                );
                return 'Sharing…';
              }),
            ),
            _exportTile(
              icon: Icons.insert_drive_file,
              color: const Color(0xFF00897B),
              title: 'Share CSV',
              subtitle: 'Plain text table for any app',
              onTap: () => _runExport(sheetCtx, () async {
                final csv = await ExportService.instance.buildCsv(data);
                await ExportService.instance
                    .shareTextFile(csv, _fileName(data, 'csv'));
                return 'Sharing…';
              }),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _exportTile({
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    subtitle:
        Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
    onTap: onTap,
  );
}

String _fileName(AttendanceExportData data, String ext) {
  final date = DateFormat('yyyy-MM-dd').format(data.date);
  final safeClass = data.className.replaceAll(RegExp(r'[^\w]+'), '_');
  final safeSubject = data.subject.replaceAll(RegExp(r'[^\w]+'), '_');
  return 'Attendance_${safeClass}_${safeSubject}_$date.$ext';
}

/// Shows the export options sheet for a date-RANGE attendance report
/// (Download PDF / Share PDF / Print PDF), used by the teacher's
/// attendance history screen.
Future<void> showHistoryExportSheet(
    BuildContext context, AttendanceHistoryExportData data) {
  final rangeLabel =
      '${DateFormat('d MMM yyyy').format(data.from)} – ${DateFormat('d MMM yyyy').format(data.to)}';
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export — Attendance History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            Text(
              '${data.className} • $rangeLabel • ${data.days.length} marked day${data.days.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            const _SectionLabel('Signed PDF'),
            _exportTile(
              icon: Icons.draw_rounded,
              color: const Color(0xFF2E7D32),
              title: 'Print Signed PDF',
              subtitle: 'Sign, then send to a printer',
              onTap: _signedJob(context, (sig) async {
                final bytes = await ExportService.instance.buildHistoryPdf(
                    data,
                    signatureBytes: sig,
                    signedByName: data.teacher);
                await ExportService.instance.printBytes(bytes);
                return 'Printing…';
              }),
            ),
            _exportTile(
              icon: Icons.download_rounded,
              color: const Color(0xFF2E7D32),
              title: 'Download Signed PDF',
              subtitle: 'Sign, then save to Downloads',
              onTap: _signedJob(context, (sig) async {
                final bytes = await ExportService.instance.buildHistoryPdf(
                    data,
                    signatureBytes: sig,
                    signedByName: data.teacher);
                return ExportService.instance.saveToDownloads(
                    bytes, _signedFileName(_historyFileName(data, 'pdf')));
              }),
            ),
            _exportTile(
              icon: Icons.mark_email_read_outlined,
              color: const Color(0xFF2E7D32),
              title: 'Share Signed PDF',
              subtitle: 'Sign, then share via WhatsApp, mail…',
              onTap: _signedJob(context, (sig) async {
                final bytes = await ExportService.instance.buildHistoryPdf(
                    data,
                    signatureBytes: sig,
                    signedByName: data.teacher);
                await ExportService.instance.shareBytes(
                  bytes,
                  _signedFileName(_historyFileName(data, 'pdf')),
                  'application/pdf',
                  text:
                      'Signed attendance report ${data.className} ($rangeLabel)',
                );
                return 'Sharing…';
              }),
            ),
            const _SectionLabel('Unsigned PDF'),
            _exportTile(
              icon: Icons.picture_as_pdf,
              color: const Color(0xFFE53935),
              title: 'Download PDF',
              subtitle: 'Saved to your Downloads folder',
              onTap: () => _runExport(sheetCtx, () async {
                final bytes =
                    await ExportService.instance.buildHistoryPdf(data);
                final msg = await ExportService.instance
                    .saveToDownloads(bytes, _historyFileName(data, 'pdf'));
                return msg;
              }),
            ),
            _exportTile(
              icon: Icons.share,
              color: const Color(0xFF1976D2),
              title: 'Share PDF',
              subtitle: 'WhatsApp, mail, files & more',
              onTap: () => _runExport(sheetCtx, () async {
                final bytes =
                    await ExportService.instance.buildHistoryPdf(data);
                await ExportService.instance.shareBytes(
                  bytes,
                  _historyFileName(data, 'pdf'),
                  'application/pdf',
                  text:
                      'Attendance report ${data.className} ($rangeLabel)',
                );
                return 'Sharing…';
              }),
            ),
            _exportTile(
              icon: Icons.print,
              color: const Color(0xFF2E7D32),
              title: 'Print PDF',
              subtitle: 'Send straight to a printer',
              onTap: () => _runExport(sheetCtx, () async {
                final bytes =
                    await ExportService.instance.buildHistoryPdf(data);
                await ExportService.instance.printBytes(bytes);
                return 'Printing…';
              }),
            ),
          ],
        ),
      ),
    ),
  );
}

String _historyFileName(AttendanceHistoryExportData data, String ext) {
  final from = DateFormat('yyyyMMdd').format(data.from);
  final to = DateFormat('yyyyMMdd').format(data.to);
  final safeClass = data.className.replaceAll(RegExp(r'[^\w]+'), '_');
  return 'Attendance_History_${safeClass}_${from}_$to.$ext';
}

/// Opens the signature pad first; if the signer confirms, runs [job] with
/// the captured PNG. Uses the OUTER [context] so the pad stacks on top of
/// the still-open export sheet, and capture survives the sheet closing.
void Function() _signedJob(
    BuildContext context, Future<String> Function(Uint8List sig) job) {
  return () async {
    final sig = await showSignaturePadSheet(context);
    if (sig == null) return; // signer cancelled — stay on the sheet
    await _runExport(context, () => job(sig));
  };
}

String _signedFileName(String baseName) =>
    'Signed_${baseName.replaceAll(' ', '_')}';

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

Future<void> _runExport(
    BuildContext sheetCtx, Future<String> Function() job) async {
  Navigator.of(sheetCtx).pop(); // close the sheet, show progress instead
  final messenger = ScaffoldMessenger.of(sheetCtx);
  messenger.showSnackBar(
    const SnackBar(
      content: Row(children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 14),
        Text('Preparing export…'),
      ]),
      duration: Duration(seconds: 30),
    ),
  );
  try {
    final msg = await job();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
    );
  }
}
