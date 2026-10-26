import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<void> copyImage(Uint8List bytes) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final item = web.ClipboardItem({'image/png': blob}.jsify() as JSObject);
  await web.window.navigator.clipboard.write([item].toJS).toDart;
}

Future<void> saveExport(String name, String mime, Uint8List bytes) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}

Future<({String name, Uint8List bytes})?> pickFile() async {
  final result = Completer<({String name, Uint8List bytes})?>();
  final input = web.HTMLInputElement()..type = 'file';
  Future<void> readFile() async {
    try {
      final file = input.files?.item(0);
      if (file == null) {
        result.complete(null);
        return;
      }
      if (file.size > 20 * 1024 * 1024) {
        throw const FormatException('Files must be 20 MB or smaller.');
      }
      final buffer = await file.arrayBuffer().toDart;
      result.complete((name: file.name, bytes: buffer.toDart.asUint8List()));
    } catch (e, stack) {
      result.completeError(e, stack);
    } finally {
      input.remove();
    }
  }

  input.onchange = ((web.Event _) {
    unawaited(readFile());
  }).toJS;
  input.oncancel = ((web.Event _) {
    input.remove();
    result.complete(null);
  }).toJS;
  input.click();
  return result.future;
}
