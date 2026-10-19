import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadBytes(Uint8List bytes, String name, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  anchor.click();
  Timer(const Duration(seconds: 10), () => web.URL.revokeObjectURL(url));
}

void openUrl(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}

void Function() listenDrops(void Function(String, int) onFile) {
  final over = ((web.DragEvent e) {
    if (e.dataTransfer?.types.toDart.any((t) => t.toDart == 'Files') ?? false) {
      e.preventDefault();
    }
  }).toJS;
  final drop = ((web.DragEvent e) {
    final files = e.dataTransfer?.files;
    if (files == null || files.length == 0) return;
    e.preventDefault();
    for (var i = 0; i < files.length; i++) {
      final f = files.item(i)!;
      onFile(f.name, f.size);
    }
  }).toJS;
  web.window.addEventListener('dragover', over);
  web.window.addEventListener('drop', drop);
  return () {
    web.window.removeEventListener('dragover', over);
    web.window.removeEventListener('drop', drop);
  };
}

void Function() listenBeforeUnload(bool Function() hasChanges) {
  final handler = ((web.BeforeUnloadEvent event) {
    if (hasChanges()) {
      event.preventDefault();
      event.returnValue = '';
    }
  }).toJS;
  web.window.addEventListener('beforeunload', handler);
  return () => web.window.removeEventListener('beforeunload', handler);
}

void openHtmlDocument(Uint8List bytes) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  openUrl(url);
  Timer(const Duration(minutes: 2), () => web.URL.revokeObjectURL(url));
}
