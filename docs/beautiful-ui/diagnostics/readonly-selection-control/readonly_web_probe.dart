// Ignored diagnostic: listeners only observe. Input comes from a real user.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const documentText =
    'We should maybe order some more pistachio tubs soon. '
    'Confirm the supplier lead time before sending the order.';

@JS('document')
external JSObject get _document;

@JS('window')
external JSObject get _window;

@JS('window.__readonlyProbe')
external set _exportReport(JSAny? report);

JSObject? _active() {
  var active = _document.getProperty<JSObject?>('activeElement'.toJS);
  while (active != null) {
    final shadow = active.getProperty<JSObject?>('shadowRoot'.toJS);
    final nested = shadow?.getProperty<JSObject?>('activeElement'.toJS);
    if (nested == null) break;
    active = nested;
  }
  return active;
}

Map<String, Object?> _domState(JSObject? element) {
  if (element == null) return <String, Object?>{};
  final tag = element.getProperty<JSString?>('tagName'.toJS)?.toDart;
  final isInput = tag == 'INPUT' || tag == 'TEXTAREA';
  return <String, Object?>{
    'tag': tag,
    'id': element.getProperty<JSString?>('id'.toJS)?.toDart,
    if (tag != null)
      'label': element
          .callMethod<JSString?>('getAttribute'.toJS, 'aria-label'.toJS)
          ?.toDart,
    'active': identical(element, _active()),
    if (isInput) ...<String, Object?>{
      'readOnly': element.getProperty<JSBoolean>('readOnly'.toJS).toDart,
      'disabled': element.getProperty<JSBoolean>('disabled'.toJS).toDart,
      'text': element.getProperty<JSString>('value'.toJS).toDart,
      'selectionStart': element
          .getProperty<JSNumber?>('selectionStart'.toJS)
          ?.toDartInt,
      'selectionEnd': element
          .getProperty<JSNumber?>('selectionEnd'.toJS)
          ?.toDartInt,
      'selectionDirection': element
          .getProperty<JSString?>('selectionDirection'.toJS)
          ?.toDart,
    },
  };
}

List<Map<String, Object?>> _domEditors() {
  final result = <Map<String, Object?>>[];
  void scan(JSObject root) {
    final inputs = root.callMethod<JSObject>(
      'querySelectorAll'.toJS,
      'input,textarea'.toJS,
    );
    final length = inputs.getProperty<JSNumber>('length'.toJS).toDartInt;
    for (var index = 0; index < length; index++) {
      result.add(
        _domState(inputs.callMethod<JSObject>('item'.toJS, index.toJS)),
      );
    }
    final elements = root.callMethod<JSObject>(
      'querySelectorAll'.toJS,
      '*'.toJS,
    );
    final count = elements.getProperty<JSNumber>('length'.toJS).toDartInt;
    for (var index = 0; index < count; index++) {
      final shadow = elements
          .callMethod<JSObject>('item'.toJS, index.toJS)
          .getProperty<JSObject?>('shadowRoot'.toJS);
      if (shadow != null) scan(shadow);
    }
  }

  scan(_document);
  return result;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(
    WidgetsApp(
      color: const Color(0xfff3f5f7),
      builder: (context, _) => Overlay(
        initialEntries: <OverlayEntry>[
          OverlayEntry(
            builder: (_) => const BeautifulUiScope(
              motion: BeautifulMotionPolicy.none,
              child: _ReadOnlyProbe(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReadOnlyProbe extends StatefulWidget {
  const _ReadOnlyProbe();
  @override
  State<_ReadOnlyProbe> createState() => _ReadOnlyProbeState();
}

class _ReadOnlyProbeState extends State<_ReadOnlyProbe> {
  final _stockController = TextEditingController(text: documentText);
  final _stockFocus = FocusNode(debugLabel: 'Stock read-only document');
  final _stockKey = GlobalKey<EditableTextState>();
  final _productKey = GlobalKey();
  final _report = ValueNotifier<Map<String, Object?>>(<String, Object?>{});
  final _events = <Map<String, Object?>>[];
  final _listeners = <(JSObject, String, JSFunction)>[];
  final _clock = Stopwatch()..start();
  EditableTextState? _productEditor;

  @override
  void initState() {
    super.initState();
    _stockController.addListener(_stockChanged);
    _stockFocus.addListener(_stockFocusChanged);
    FocusManager.instance.addListener(_primaryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void visit(Element element) {
        if (element is StatefulElement &&
            element.state is EditableTextState &&
            (element.state as EditableTextState).widget.readOnly) {
          _productEditor = element.state as EditableTextState;
          return;
        }
        element.visitChildren(visit);
      }

      (_productKey.currentContext! as Element).visitChildren(visit);
      _productEditor!.widget.controller.addListener(_productChanged);
      _productEditor!.widget.focusNode.addListener(_productFocusChanged);
      for (final type in <String>['keydown', 'keyup']) {
        final callback = ((JSObject event) {
          _record('$type capture', event: event);
          _window.callMethod<JSAny?>(
            'setTimeout'.toJS,
            (() {
              if (mounted) _record('$type post-dispatch timeout', event: event);
            }).toJS,
            0.toJS,
          );
          _window.callMethod<JSAny?>(
            'requestAnimationFrame'.toJS,
            ((JSNumber _) {
              if (mounted)
                _record('$type post-dispatch animation frame', event: event);
            }).toJS,
          );
        }).toJS;
        _listen(_window, type, callback);
      }
      _listen(
        _document,
        'selectionchange',
        ((JSObject event) {
          _record('DOM selectionchange', event: event);
        }).toJS,
      );
      _record('initial: no automatic focus or selection');
    });
  }

  void _listen(JSObject target, String type, JSFunction callback) {
    target.callMethod<JSAny?>(
      'addEventListener'.toJS,
      type.toJS,
      callback,
      true.toJS,
    );
    _listeners.add((target, type, callback));
  }

  void _stockChanged() => _record('Flutter stock controller');
  void _stockFocusChanged() => _record('Flutter stock focus');
  void _productChanged() => _record('Flutter product controller');
  void _productFocusChanged() => _record('Flutter product focus');
  void _primaryChanged() => _record('Flutter primary focus');

  Map<String, Object?> _flutter(EditableTextState? state) {
    if (state == null || !state.mounted) return <String, Object?>{};
    final value = state.textEditingValue;
    return <String, Object?>{
      'text': value.text,
      'selectionStart': value.selection.start,
      'selectionEnd': value.selection.end,
      'readOnly': state.widget.readOnly,
      'primary': state.widget.focusNode.hasPrimaryFocus,
      'state_id': identityHashCode(state),
      'controller_id': identityHashCode(state.widget.controller),
    };
  }

  void _record(String phase, {JSObject? event}) {
    if (!mounted) return;
    final current = <String, Object?>{
      'stock': _flutter(_stockKey.currentState),
      'product': _flutter(_productEditor),
      'primary_focus_label': FocusManager.instance.primaryFocus?.debugLabel,
      'primary_focus': FocusManager.instance.primaryFocus?.toString(),
      'active_dom': _domState(_active()),
      'dom_editors': _domEditors(),
    };
    _events.add(<String, Object?>{
      'phase': phase,
      'elapsed_ms': _clock.elapsedMilliseconds,
      if (event != null)
        'event': <String, Object?>{
          'type': event.getProperty<JSString>('type'.toJS).toDart,
          'isTrusted': event.getProperty<JSBoolean>('isTrusted'.toJS).toDart,
          'defaultPrevented': event
              .getProperty<JSBoolean>('defaultPrevented'.toJS)
              .toDart,
          'key': event.getProperty<JSString?>('key'.toJS)?.toDart,
          'code': event.getProperty<JSString?>('code'.toJS)?.toDart,
          'shift': event.getProperty<JSBoolean?>('shiftKey'.toJS)?.toDart,
          'control': event.getProperty<JSBoolean?>('ctrlKey'.toJS)?.toDart,
          'meta': event.getProperty<JSBoolean?>('metaKey'.toJS)?.toDart,
          'alt': event.getProperty<JSBoolean?>('altKey'.toJS)?.toDart,
          'target': _domState(event.getProperty<JSObject?>('target'.toJS)),
        },
      ...current,
    });
    if (_events.length > 120) _events.removeAt(0);
    final report = <String, Object?>{
      'host': 'WidgetsApp + Overlay + BeautifulUiScope + semantics enabled',
      'text_length': documentText.length,
      'read_only_observers': true,
      'latest': current,
      'events': List<Map<String, Object?>>.of(_events),
    };
    _report.value = report;
    _exportReport = report.jsify();
  }

  @override
  void dispose() {
    for (final listener in _listeners) {
      listener.$1.callMethod<JSAny?>(
        'removeEventListener'.toJS,
        listener.$2.toJS,
        listener.$3,
        true.toJS,
      );
    }
    FocusManager.instance.removeListener(_primaryChanged);
    _productEditor?.widget.controller.removeListener(_productChanged);
    _productEditor?.widget.focusNode.removeListener(_productFocusChanged);
    _stockController.removeListener(_stockChanged);
    _stockFocus.removeListener(_stockFocusChanged);
    _stockController.dispose();
    _stockFocus.dispose();
    _report.dispose();
    super.dispose();
  }

  Widget _panel(String title, Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xffffffff),
      border: Border.all(color: const Color(0xff94a3b8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: const TextStyle(color: Color(0xff172033), fontSize: 15, height: 1.5),
    child: ColoredBox(
      color: const Color(0xfff3f5f7),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Read-only caret control',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            ),
            const Text(
              'For each field: click its text, press Meta/Ctrl+A, then press ArrowRight once. No automatic focus, selection, or key actions. All event listeners only observe.',
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _panel(
                    'Stock readonly EditableText',
                    AnimatedBuilder(
                      animation: _stockFocus,
                      builder: (context, _) => MergeSemantics(
                        child: Semantics(
                          label: 'Stock read-only document',
                          textField: true,
                          enabled: true,
                          readOnly: true,
                          focusable: true,
                          focused: _stockFocus.hasFocus,
                          onFocus: _stockFocus.requestFocus,
                          onTap: _stockFocus.requestFocus,
                          child: EditableText(
                            key: _stockKey,
                            controller: _stockController,
                            focusNode: _stockFocus,
                            readOnly: true,
                            showCursor: false,
                            minLines: 1,
                            maxLines: 8,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.7,
                              color: Color(0xff172033),
                            ),
                            cursorColor: const Color(0xff1d4ed8),
                            backgroundCursorColor: const Color(0xff94a3b8),
                            selectionColor: const Color(0xffbfdbfe),
                            keyboardType: TextInputType.multiline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _panel(
                    'BeautifulSelectionActions',
                    BeautifulSelectionActions(
                      key: _productKey,
                      documentId: 'readonly-control',
                      text: documentText,
                      onRequest: (_) =>
                          throw StateError('AI actions are outside this probe'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<Map<String, Object?>>(
              valueListenable: _report,
              builder: (context, report, _) => Text(
                const JsonEncoder.withIndent('  ').convert(<String, Object?>{
                  'latest': report['latest'],
                  'recent_events': _events.reversed.take(12).toList(),
                }),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
