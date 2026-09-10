// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

/// Web-only implementation: triggers a browser download of [bytes] as
/// [filename]. Imported via the conditional import in `export_service.dart`.
void triggerDownload(Uint8List bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.children.add(anchor);
  anchor.click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}

/// Shares [bytes] through the browser's **Web Share API** — opens the OS
/// share sheet with every app that accepts files (WhatsApp, Gmail, Drive,
/// Files, …). Returns `true` when the share sheet was opened.
///
/// Falls back to `false` when the browser doesn't support file sharing
/// (e.g. desktop Safari, older browsers) — callers should then trigger a
/// plain download instead.
Future<bool> shareViaWeb(
  Uint8List bytes,
  String filename,
  String mimeType, {
  String? text,
}) async {
  try {
    final nav = html.window.navigator;
    // `navigator.canShare` / `navigator.share` are newer Web Share API
    // members not exposed by dart:html — call them through js_util.
    if (!js_util.hasProperty(nav, 'canShare') ||
        !js_util.hasProperty(nav, 'share')) {
      return false;
    }

    final file = html.File([bytes], filename, {'type': mimeType});
    final data = js_util.jsify(<String, dynamic>{
      'files': [file],
      if (text != null && text.isNotEmpty) 'text': text,
      'title': filename,
    });

    final canShare = js_util.callMethod<bool>(nav, 'canShare', [data]);
    if (!canShare) return false;

    await js_util.promiseToFuture(
      js_util.callMethod(nav, 'share', [data]),
    );
    return true;
  } catch (_) {
    return false;
  }
}
