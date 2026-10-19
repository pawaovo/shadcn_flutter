import 'dart:typed_data';

void downloadBytes(Uint8List bytes, String name, String mime) =>
    throw UnsupportedError('请在 Web 版本中导出文件。');
void openUrl(String url) => throw UnsupportedError('请在浏览器中打开 $url');
void Function() listenDrops(void Function(String, int) onFile) => () {};

void Function() listenBeforeUnload(bool Function() hasChanges) => () {};
void openHtmlDocument(Uint8List bytes) =>
    throw UnsupportedError('请先导出 HTML 文件再打印。');
