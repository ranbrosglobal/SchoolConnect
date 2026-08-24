import 'dart:typed_data';

/// Native (non-web) stub: file downloads go through `path_provider` and
/// sharing through `share_plus` instead.
void triggerDownload(Uint8List bytes, String filename) {}

/// Native stub: web-only API, always "not available".
Future<bool> shareViaWeb(
  Uint8List bytes,
  String filename,
  String mimeType, {
  String? text,
}) async {
  return false;
}
