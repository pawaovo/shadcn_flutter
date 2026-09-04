// Ignored live OS IME observer. No synthetic inputs or system setting changes.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

@JS('document')
external JSObject get _document;

@JS('window')
external JSObject get _window;

@JS('window.__liveOsImeProbe')
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
  final _stockController = TextEditingController();
  final _stockFocus = FocusNode(debugLabel: 'Stock live IME input');
  final _stockKey = GlobalKey<EditableTextState>();
  final _productKey = GlobalKey();
  final _report = ValueNotifier<Map<String, Object?>>(<String, Object?>{});
  final _events = <Map<String, Object?>>[];
  final _submissions = <Map<String, Object?>>[];
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
        if (element is StatefulElement && element.state is EditableTextState) {
          _productEditor = element.state as EditableTextState;
          return;
        }
        element.visitChildren(visit);
      }

      (_productKey.currentContext! as Element).visitChildren(visit);
      _productEditor!.widget.controller.addListener(_productChanged);
      _productEditor!.widget.focusNode.addListener(_productFocusChanged);
      for (final type in <String>[
        'keydown',
        'keyup',
        'compositionstart',
        'compositionupdate',
        'compositionend',
        'beforeinput',
        'input',
      ]) {
        final callback = ((JSObject event) {
          final path = event.callMethod<JSObject>('composedPath'.toJS);
          final deepTarget = path.getProperty<JSObject?>('0'.toJS);
          _record('$type capture', event: event, deepTarget: deepTarget);
          _window.callMethod<JSAny?>(
            'setTimeout'.toJS,
            (() {
              if (mounted)
                _record(
                  '$type post-dispatch timeout',
                  event: event,
                  deepTarget: deepTarget,
                );
            }).toJS,
            0.toJS,
          );
          _window.callMethod<JSAny?>(
            'requestAnimationFrame'.toJS,
            ((JSNumber _) {
              if (mounted)
                _record(
                  '$type post-dispatch animation frame',
                  event: event,
                  deepTarget: deepTarget,
                );
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
      <String, bool>{'capture': true, 'passive': true}.jsify(),
    );
    _listeners.add((target, type, callback));
  }

  void _stockChanged() => _sampleController('Flutter stock controller');
  void _stockFocusChanged() => _record('Flutter stock focus');
  void _productChanged() => _sampleController('Flutter Prompt controller');
  void _productFocusChanged() => _record('Flutter product focus');
  void _primaryChanged() => _record('Flutter primary focus');

  void _sampleController(String phase) {
    _record(phase);
    _window.callMethod<JSAny?>(
      'setTimeout'.toJS,
      (() {
        if (mounted) _record('$phase timer');
      }).toJS,
      0.toJS,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _record('$phase post-frame');
    });
  }

  Map<String, Object?> _flutter(EditableTextState? state) {
    if (state == null || !state.mounted) return <String, Object?>{};
    final value = state.textEditingValue;
    return <String, Object?>{
      'text': value.text,
      'selectionStart': value.selection.start,
      'selectionEnd': value.selection.end,
      'selectionBase': value.selection.baseOffset,
      'selectionExtent': value.selection.extentOffset,
      'composingStart': value.composing.start,
      'composingEnd': value.composing.end,
      'readOnly': state.widget.readOnly,
      'primary': state.widget.focusNode.hasPrimaryFocus,
      'state_id': identityHashCode(state),
      'controller_id': identityHashCode(state.widget.controller),
    };
  }

  void _record(String phase, {JSObject? event, JSObject? deepTarget}) {
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
          'keyCode': event.getProperty<JSNumber?>('keyCode'.toJS)?.toDartInt,
          'isComposing': event
              .getProperty<JSBoolean?>('isComposing'.toJS)
              ?.toDart,
          'inputType': event.getProperty<JSString?>('inputType'.toJS)?.toDart,
          'data': event.getProperty<JSString?>('data'.toJS)?.toDart,
          'shift': event.getProperty<JSBoolean?>('shiftKey'.toJS)?.toDart,
          'control': event.getProperty<JSBoolean?>('ctrlKey'.toJS)?.toDart,
          'meta': event.getProperty<JSBoolean?>('metaKey'.toJS)?.toDart,
          'alt': event.getProperty<JSBoolean?>('altKey'.toJS)?.toDart,
          'target': _domState(event.getProperty<JSObject?>('target'.toJS)),
          'deep_target_from_capture': _domState(deepTarget),
        },
      ...current,
    });
    if (_events.length > 300) _events.removeAt(0);
    final report = <String, Object?>{
      'host': 'WidgetsApp + Overlay + BeautifulUiScope + semantics enabled',
      'probe': 'Passive live OS IME observation; no automatic input or composition injection',
      'build_mode': kReleaseMode ? 'release' : 'debug',
      'submissions': List<Map<String, Object?>>.of(_submissions),
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
              'Live OS IME: stock EditableText and Prompt',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Click one empty field and use the existing OS input method normally. No synthetic buttons, injected text, automatic selection, or system-setting changes. Prompt Send logs actual submissions; normal product submission may clear its draft.',
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _panel(
                    'Stock EditableText — live OS input',
                    AnimatedBuilder(
                      animation: _stockFocus,
                      builder: (context, _) => MergeSemantics(
                        child: Semantics(
                          label: 'Stock live IME input',
                          textField: true,
                          enabled: true,
                          readOnly: false,
                          focusable: true,
                          focused: _stockFocus.hasFocus,
                          onFocus: _stockFocus.requestFocus,
                          onTap: _stockFocus.requestFocus,
                          child: EditableText(
                            key: _stockKey,
                            controller: _stockController,
                            focusNode: _stockFocus,
                            readOnly: false,
                            showCursor: true,
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
                    'BeautifulPromptBar — live OS input',
                    BeautifulPromptBar(
                      key: _productKey,
                      composerId: 'live-os-ime-probe',
                      onSend: (submission) {
                        _submissions.add(<String, Object?>{
                          'elapsed_ms': _clock.elapsedMilliseconds,
                          'text': submission.text,
                        });
                        _record('Actual Prompt onSend callback');
                      },
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
                  'submissions': report['submissions'],
                  'native_composition_events': _events
                      .where((entry) {
                        final event = entry['event'];
                        return entry['phase'].toString().endsWith(' capture') &&
                            event is Map &&
                            (event['type'].toString().startsWith(
                                  'composition',
                                ) ||
                                event['type'] == 'beforeinput' ||
                                event['type'] == 'input');
                      })
                      .toList()
                      .reversed
                      .take(24)
                      .toList(),
                  'recent_events': _events.reversed.take(24).toList(),
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
