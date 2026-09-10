import 'dart:io';
import 'dart:typed_data';

/// Native implementation: writes [bytes] to `dirPath/<filename>`.
/// Only compiled for non-web platforms (conditional import).
Future<String> writeBytesToDir(
    String dirPath, String filename, Uint8List bytes) async {
  final file = File('$dirPath${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
