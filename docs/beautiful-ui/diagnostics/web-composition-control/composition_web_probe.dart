// Ignored browser diagnostic. No product code or acceptance assertion changes.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

@JS('window.__compositionProbe')
external set _browserReport(JSAny? value);

@JS('document.activeElement')
external JSObject? get _activeElement;

JSObject _activeDomEditor() {
  var element = _activeElement;
  while (element != null) {
    final shadow = element.getProperty<JSObject?>('shadowRoot'.toJS);
    final nested = shadow?.getProperty<JSObject?>('activeElement'.toJS);
    if (nested == null) break;
    element = nested;
  }
  final tag = element
      ?.getProperty<JSString>('tagName'.toJS)
      .toDart
      .toLowerCase();
  if (element == null || (tag != 'input' && tag != 'textarea')) {
    throw StateError('No active DOM input/textarea: $tag');
  }
  if (element.getProperty<JSBoolean>('disabled'.toJS).toDart ||
      element.getProperty<JSBoolean>('readOnly'.toJS).toDart) {
    throw StateError('The active DOM editor is disabled or read-only');
  }
  return element;
}

Map<String, Object?> _dispatchDomEvent(
  JSObject element,
  String constructor,
  String type,
  Map<String, Object?> properties,
) {
  final event = globalContext
      .getProperty<JSFunction>(constructor.toJS)
      .callAsConstructor<JSObject>(
        type.toJS,
        <String, Object?>{
          'bubbles': true,
          'cancelable': true,
          'composed': true,
          ...properties,
        }.jsify(),
      );
  final trusted = event.getProperty<JSBoolean>('isTrusted'.toJS).toDart;
  element.callMethod<JSAny?>('dispatchEvent'.toJS, event);
  return <String, Object?>{'type': type, 'isTrusted': trusted, ...properties};
}

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.ensureSemantics();
  runApp(
    WidgetsApp(
      color: const Color(0xfff3f5f7),
      builder: (context, _) => Overlay(
        initialEntries: <OverlayEntry>[
          OverlayEntry(
            builder: (context) => const BeautifulUiScope(
              motion: BeautifulMotionPolicy.none,
              child: _CompositionProbe(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompositionProbe extends StatefulWidget {
  const _CompositionProbe();

  @override
  State<_CompositionProbe> createState() => _CompositionProbeState();
}

class _CompositionProbeState extends State<_CompositionProbe> {
  final _stockKey = GlobalKey<EditableTextState>();
  final _promptKey = GlobalKey();
  final _stockController = TextEditingController();
  final _stockFocus = FocusNode(debugLabel: 'Stock composition probe');
  final _runs = <Map<String, Object?>>[];
  bool _running = false;
  String _status = 'Ready. Run stock, then BeautifulPromptBar.';

  @override
  void initState() {
    super.initState();
    _stockFocus.addListener(_stockFocusChanged);
  }

  void _stockFocusChanged() {
    if (mounted) setState(() {});
  }

  EditableTextState _editor(bool stock) {
    if (stock) return _stockKey.currentState!;
    EditableTextState? found;
    void visit(Element element) {
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visit);
    }

    (_promptKey.currentContext! as Element).visitChildren(visit);
    return found!;
  }

  void _publish() {
    _browserReport = <String, Object?>{
      'platform': defaultTargetPlatform.name,
      'is_web': kIsWeb,
      'semantics_enabled': WidgetsBinding.instance.semanticsEnabled,
      'running': _running,
      'status': _status,
      'runs': _runs,
    }.jsify();
  }

  Future<void> _run(bool stock) async {
    if (_running) return;
    final name = stock ? 'stock EditableText' : 'BeautifulPromptBar';
    final run = <String, Object?>{
      'control': name,
      'delivery': 'Dart userUpdateTextEditingValue; no OS IME',
      'samples': <Map<String, Object?>>[],
    };
    setState(() {
      _running = true;
      _status = 'Running $name';
      _runs.add(run);
    });
    final editor = _editor(stock);
    try {
      editor.requestKeyboard();
      await WidgetsBinding.instance.endOfFrame;
      const injected = TextEditingValue(
        text: '中文',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      final elapsed = Stopwatch()..start();
      void sample(String phase) {
        final value = editor.textEditingValue;
        (run['samples']! as List<Map<String, Object?>>).add(<String, Object?>{
          'phase': phase,
          'elapsed_ms': elapsed.elapsedMilliseconds,
          'text': value.text,
          'selection': <int>[value.selection.start, value.selection.end],
          'composing': <int>[value.composing.start, value.composing.end],
          'primary_focus': editor.widget.focusNode.hasPrimaryFocus,
        });
        setState(() {});
        _publish();
      }

      editor.userUpdateTextEditingValue(
        injected,
        SelectionChangedCause.keyboard,
      );
      sample('immediate');
      await WidgetsBinding.instance.endOfFrame;
      sample('next frame');
      for (final milliseconds in <int>[100, 500]) {
        final remaining = milliseconds - elapsed.elapsedMilliseconds;
        if (remaining > 0) {
          await Future<void>.delayed(Duration(milliseconds: remaining));
        }
        sample('${milliseconds}ms');
      }
      _status = 'Finished $name';
    } catch (error, stack) {
      run['error'] = '$error';
      run['stack'] = '$stack';
      _status = 'Failed $name: $error';
    } finally {
      setState(() => _running = false);
      _publish();
    }
  }

  Future<void> _runDom(bool stock) async {
    if (_running) return;
    final name = stock ? 'stock EditableText' : 'BeautifulPromptBar';
    final events = <Map<String, Object?>>[];
    final samples = <Map<String, Object?>>[];
    final failures = <String>[];
    final run = <String, Object?>{
      'control': name,
      'delivery':
          'Synthetic DOM composition events; isTrusted=false; NOT OS IME',
      'events': events,
      'samples': samples,
      'failures': failures,
    };
    setState(() {
      _running = true;
      _status = 'Running synthetic DOM composition on $name';
      _runs.add(run);
    });
    try {
      final editor = _editor(stock);
      editor.requestKeyboard();
      await WidgetsBinding.instance.endOfFrame;
      final element = _activeDomEditor();
      final elapsed = Stopwatch()..start();
      void sample(String phase, {TextRange? expectedComposition}) {
        final value = editor.textEditingValue;
        final matches =
            value.text == '中文' &&
            value.selection == const TextSelection.collapsed(offset: 2) &&
            editor.widget.focusNode.hasPrimaryFocus &&
            (expectedComposition == null ||
                value.composing == expectedComposition);
        samples.add(<String, Object?>{
          'phase': phase,
          'elapsed_ms': elapsed.elapsedMilliseconds,
          'text': value.text,
          'selection': <int>[value.selection.start, value.selection.end],
          'composing': <int>[value.composing.start, value.composing.end],
          'primary_focus': editor.widget.focusNode.hasPrimaryFocus,
          'dom_text': element.getProperty<JSString>('value'.toJS).toDart,
          if (expectedComposition != null) ...<String, Object?>{
            'expected_composing': <int>[
              expectedComposition.start,
              expectedComposition.end,
            ],
            'text_selection_focus_and_composition_match': matches,
          },
        });
        if (expectedComposition != null && !matches) {
          failures.add(
            '$phase did not preserve the expected text, caret, focus and composing range',
          );
        }
        setState(() {});
        _publish();
      }

      events.add(
        _dispatchDomEvent(
          element,
          'CompositionEvent',
          'compositionstart',
          <String, Object?>{'data': ''},
        ),
      );
      events.add(
        _dispatchDomEvent(
          element,
          'CompositionEvent',
          'compositionupdate',
          <String, Object?>{'data': '中文'},
        ),
      );
      element.setProperty('value'.toJS, '中文'.toJS);
      element.callMethod<JSAny?>('setSelectionRange'.toJS, 2.toJS, 2.toJS);
      events.add(
        _dispatchDomEvent(element, 'InputEvent', 'input', <String, Object?>{
          'data': '中文',
          'inputType': 'insertCompositionText',
          'isComposing': true,
        }),
      );
      sample('immediate after composition input');
      await WidgetsBinding.instance.endOfFrame;
      sample(
        'next frame',
        expectedComposition: const TextRange(start: 0, end: 2),
      );
      for (final milliseconds in <int>[100, 500]) {
        final remaining = milliseconds - elapsed.elapsedMilliseconds;
        if (remaining > 0)
          await Future<void>.delayed(Duration(milliseconds: remaining));
        sample(
          '${milliseconds}ms',
          expectedComposition: const TextRange(start: 0, end: 2),
        );
      }
      events.add(
        _dispatchDomEvent(
          element,
          'CompositionEvent',
          'compositionend',
          <String, Object?>{'data': '中文'},
        ),
      );
      events.add(
        _dispatchDomEvent(element, 'InputEvent', 'input', <String, Object?>{
          'data': '中文',
          'inputType': 'insertText',
          'isComposing': false,
        }),
      );
      await WidgetsBinding.instance.endOfFrame;
      sample('after compositionend', expectedComposition: TextRange.empty);
      run['status'] = failures.isEmpty ? 'passed' : 'failed';
      _status = '${run['status']}: synthetic DOM composition on $name';
    } catch (error, stack) {
      run['status'] = 'failed';
      run['error'] = '$error';
      run['stack'] = '$stack';
      _status = 'Failed synthetic DOM composition on $name: $error';
    } finally {
      setState(() => _running = false);
      _publish();
    }
  }

  @override
  void dispose() {
    _stockController.dispose();
    _stockFocus.removeListener(_stockFocusChanged);
    _stockFocus.dispose();
    super.dispose();
  }

  Widget _button(String text, VoidCallback onTap) => Semantics(
    button: true,
    label: text,
    enabled: !_running,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _running ? null : onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _running ? const Color(0xff7a8798) : const Color(0xff1d4ed8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: ExcludeSemantics(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xffffffff)),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _panel(
    String label,
    Widget child,
    VoidCallback run,
    VoidCallback runDom,
  ) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xffffffff),
      border: Border.all(color: const Color(0xffcbd5e1)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        child,
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _button('Run $label', run),
            _button('DOM composition: $label', runDom),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: const TextStyle(color: Color(0xff172033), fontSize: 15, height: 1.4),
    child: ColoredBox(
      color: const Color(0xfff3f5f7),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Composition round-trip probe',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dart buttons inject 中文 with caret [2,2] and composing [0,2] once. '
              'DOM buttons dispatch synthetic compositionstart, compositionupdate, input, '
              'compositionend and input through the real browser engine. '
              'These events have isTrusted=false and are NOT operating-system IME acceptance.',
            ),
            const SizedBox(height: 20),
            _panel(
              'stock EditableText',
              MergeSemantics(
                child: Semantics(
                  label: 'Stock prompt',
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
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xff172033),
                    ),
                    cursorColor: const Color(0xff1d4ed8),
                    backgroundCursorColor: const Color(0xff94a3b8),
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
              ),
              () => unawaited(_run(true)),
              () => unawaited(_runDom(true)),
            ),
            const SizedBox(height: 20),
            _panel(
              'BeautifulPromptBar',
              BeautifulPromptBar(
                key: _promptKey,
                composerId: 'composition-web-probe',
                onSend: (_) {},
              ),
              () => unawaited(_run(false)),
              () => unawaited(_runDom(false)),
            ),
            const SizedBox(height: 24),
            Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final run in _runs)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(run),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
