import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:school_connect_app/services/export_service.dart';

/// Stand-in path provider so the delivery tests write into a temp folder
/// instead of the developer's real Downloads/Documents directories.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider({this.downloads, this.documents});

  final String? downloads;
  final String? documents;

  @override
  Future<String?> getDownloadsPath() async => downloads;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('export delivery mime types', () {
    test('PDF reports are shared as application/pdf', () {
      expect(
        ExportService.instance.mimeTypeForFile('Attendance_8A_2026-10-19.pdf'),
        'application/pdf',
      );
    });

    test('spreadsheets and CSV keep their editable types', () {
      expect(
        ExportService.instance.mimeTypeForFile('attendance.xlsx'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(ExportService.instance.mimeTypeForFile('attendance.CSV'), 'text/csv');
    });

    test('unknown extensions fall back to a generic binary type', () {
      expect(
        ExportService.instance.mimeTypeForFile('report'),
        'application/octet-stream',
      );
    });
  });

  group('desktop delivery', () {
    late Directory temp;
    late PathProviderPlatform original;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('export_delivery_test');
      original = PathProviderPlatform.instance;
    });

    tearDown(() {
      PathProviderPlatform.instance = original;
      debugDefaultTargetPlatformOverride = null;
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('saves the exported file into the system Downloads folder', () async {
      final downloads = Directory('${temp.path}/Downloads')..createSync();
      PathProviderPlatform.instance = _FakePathProvider(downloads: downloads.path);

      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final message =
          await ExportService.instance.saveToDownloads(bytes, 'Attendance.pdf');

      final saved = File('${downloads.path}/Attendance.pdf');
      expect(message, 'Saved to Downloads');
      expect(saved.existsSync(), isTrue);
      expect(saved.readAsBytesSync(), bytes);
    });

    test('falls back to app files when Downloads is unavailable', () async {
      final documents = Directory('${temp.path}/Documents')..createSync();
      PathProviderPlatform.instance =
          _FakePathProvider(downloads: null, documents: documents.path);

      final message = await ExportService.instance
          .saveToDownloads(Uint8List.fromList([9]), 'Report.pdf');

      expect(message, 'Saved to app files');
      expect(File('${documents.path}/Report.pdf').existsSync(), isTrue);
    });

    test('exportToDevice keeps the file in Downloads even if sharing fails',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final downloads = Directory('${temp.path}/Downloads')..createSync();
      PathProviderPlatform.instance = _FakePathProvider(downloads: downloads.path);

      final message = await ExportService.instance.exportToDevice(
        Uint8List.fromList([7, 7, 7]),
        'Attendance_Report.pdf',
        mimeType: 'application/pdf',
      );

      expect(File('${downloads.path}/Attendance_Report.pdf').existsSync(), isTrue);
      expect(message, contains('Saved to Downloads'));
    });
  });
}
