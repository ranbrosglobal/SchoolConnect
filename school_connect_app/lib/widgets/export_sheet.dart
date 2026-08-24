import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/export_service.dart';

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
