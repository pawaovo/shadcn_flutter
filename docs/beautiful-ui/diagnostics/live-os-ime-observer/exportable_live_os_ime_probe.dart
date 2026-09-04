// Manual export wrapper. Keep the historical observer source unchanged.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'live_os_ime_probe.dart' as observer;

@JS('document')
external JSObject get _document;

@JS('window')
external JSObject get _window;

@JS('window.__liveOsImeProbe')
external JSObject? get _publishedReport;

@JS('JSON.stringify')
external JSString? _stringify(JSAny? value, JSAny? replacer, JSAny? space);

@JS('Blob')
extension type _JsonBlob._(JSObject _) implements JSObject {
  external factory _JsonBlob(JSArray<JSAny?> parts, JSObject options);
}

@JS('URL.createObjectURL')
external JSString _createObjectUrl(_JsonBlob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(JSString url);

JSObject _element(String tag) =>
    _document.callMethod<JSObject>('createElement'.toJS, tag.toJS);

void _text(JSObject element, String text) =>
    element.setProperty('textContent'.toJS, text.toJS);

void _style(JSObject element, String css) => element
    .getProperty<JSObject>('style'.toJS)
    .setProperty('cssText'.toJS, css.toJS);

void main() {
  observer.main();
  final body = _document.getProperty<JSObject?>('body'.toJS);
  if (body == null) {
    throw StateError('The export wrapper requires the web document body.');
  }
  final panel = _element('div');
  panel.setProperty('id'.toJS, 'live-ime-export'.toJS);
  _style(
    panel,
    'position:fixed;right:16px;bottom:16px;z-index:2147483647;'
    'max-width:300px;padding:12px;border:1px solid #94a3b8;'
    'border-radius:8px;background:#fff;color:#172033;'
    'font:13px/1.4 system-ui,sans-serif;box-shadow:0 2px 12px #0002;',
  );
  final button = _element('button');
  button.setProperty('type'.toJS, 'button'.toJS);
  _text(button, 'Save observed trace');
  _style(
    button,
    'padding:8px 12px;border:1px solid #1d4ed8;border-radius:5px;'
    'background:#1d4ed8;color:white;font:inherit;cursor:pointer;',
  );
  final status = _element('div');
  status.callMethod<JSAny?>('setAttribute'.toJS, 'role'.toJS, 'status'.toJS);
  _style(status, 'margin-top:6px;overflow-wrap:anywhere;');
  _text(status, 'Saves the current published JSON; no input is generated.');

  // Prevent the export button's default DOM focus transfer. A native input
  // method can have separate commit behavior, which this wrapper does not alter.
  button.callMethod<JSAny?>(
    'addEventListener'.toJS,
    'pointerdown'.toJS,
    ((JSObject event) {
      event.callMethod<JSAny?>('preventDefault'.toJS);
    }).toJS,
  );
  button.callMethod<JSAny?>(
    'addEventListener'.toJS,
    'click'.toJS,
    ((JSObject _) {
      JSString? url;
      JSObject? anchor;
      try {
        final report = _publishedReport;
        if (report == null) {
          _text(status, 'Trace not ready yet. Wait for the observer to load.');
          return;
        }
        final json = _stringify(report, null, 2.toJS);
        if (json == null) {
          throw StateError('The published trace could not be serialized.');
        }
        final options = JSObject();
        options.setProperty('type'.toJS, 'application/json;charset=utf-8'.toJS);
        final blob = _JsonBlob(<JSAny?>[json].toJS, options);
        url = _createObjectUrl(blob);
        final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
          ':',
          '-',
        );
        final filename = 'live-os-ime-observed-$stamp.json';
        anchor = _element('a');
        anchor.setProperty('href'.toJS, url);
        anchor.setProperty('download'.toJS, filename.toJS);
        anchor.setProperty('hidden'.toJS, true.toJS);
        body.callMethod<JSAny?>('appendChild'.toJS, anchor);
        anchor.callMethod<JSAny?>('click'.toJS);
        _text(status, 'Download requested: $filename');
      } catch (error) {
        _text(status, 'Could not save trace: $error');
      } finally {
        anchor?.callMethod<JSAny?>('remove'.toJS);
        if (url != null) {
          final exportedUrl = url;
          // Allow the browser to consume this user-triggered download first.
          _window.callMethod<JSAny?>(
            'setTimeout'.toJS,
            (() => _revokeObjectUrl(exportedUrl)).toJS,
            1000.toJS,
          );
        }
      }
    }).toJS,
  );
  panel.callMethod<JSAny?>('appendChild'.toJS, button);
  panel.callMethod<JSAny?>('appendChild'.toJS, status);
  body.callMethod<JSAny?>('appendChild'.toJS, panel);
}
