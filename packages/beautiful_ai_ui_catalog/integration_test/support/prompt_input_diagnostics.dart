import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Passive evidence for the original Prompt actions. No event is consumed and
/// no input, focus, frame, delay, or component state is changed by this observer.
final class CatalogPromptInputObserver {
  CatalogPromptInputObserver(
    this.tester,
    this.prompt, {
    required String action,
    required Map<String, dynamic> reportData,
  }) {
    report = <String, Object?>{
      'action': action,
      'scope': 'passive observation of original framework Prompt action',
      'samples': samples,
      'observer_errors': errors,
    };
    try {
      final observations = reportData.putIfAbsent(
        'prompt_input_diagnostics',
        () => <Map<String, Object?>>[],
      ) as List;
      observations.add(report);
      final editor = tester.widget<EditableText>(_editorFinder);
      _controller = editor.controller;
      _focus = editor.focusNode;
      _controller!.addListener(_onInput);
      _focus!.addListener(_onFocus);
      HardwareKeyboard.instance.addHandler(_onKey);
      _keyboardAttached = true;
      sample('observer_started');
    } catch (error) {
      errors.add('observer_started: $error');
    }
  }

  final WidgetTester tester;
  final Finder prompt;
  final Stopwatch _clock = Stopwatch()..start();
  final List<Map<String, Object?>> samples = <Map<String, Object?>>[];
  final List<String> errors = <String>[];
  late final Map<String, Object?> report;
  TextEditingController? _controller;
  FocusNode? _focus;
  bool _keyboardAttached = false;
  bool _closed = false;

  Finder get _editorFinder =>
      find.descendant(of: prompt, matching: find.byType(EditableText));

  void sample(String phase, {bool? keyDownHandled}) {
    _record(phase, readWidgets: true, keyDownHandled: keyDownHandled);
  }

  void _onInput() => _record('controller_changed');
  void _onFocus() => _record('focus_changed');

  bool _onKey(KeyEvent event) {
    _record('keyboard_event', key: event);
    // Observing a key does not prove that Prompt's handler processed it.
    return false;
  }

  void _record(
    String phase, {
    bool readWidgets = false,
    bool? keyDownHandled,
    KeyEvent? key,
  }) {
    if (_closed) return;
    if (samples.length >= 128) {
      report['samples_truncated'] = true;
      return;
    }
    final sample = <String, Object?>{
      'phase': phase,
      'sequence': samples.length,
      'utc_epoch_us': DateTime.now().microsecondsSinceEpoch,
      'elapsed_us': _clock.elapsedMicroseconds,
    };
    try {
      final keyboard = HardwareKeyboard.instance;
      sample.addAll(<String, Object?>{
        'input': _controller?.value.toJSON(),
        'bound_controller_id': _controller == null
            ? null
            : identityHashCode(_controller),
        'bound_focus_id': _focus == null ? null : identityHashCode(_focus),
        'editor_has_focus': _focus?.hasFocus,
        'editor_primary_focus': _focus?.hasPrimaryFocus,
        'editor_focus_label': _focus?.debugLabel,
        'primary_focus_id': FocusManager.instance.primaryFocus == null
            ? null
            : identityHashCode(FocusManager.instance.primaryFocus),
        'primary_focus_label': FocusManager.instance.primaryFocus?.debugLabel,
        'shift_pressed': keyboard.isShiftPressed,
        'logical_keys_pressed': keyboard.logicalKeysPressed
            .map((key) => key.keyId)
            .toList(),
        'physical_keys_pressed': keyboard.physicalKeysPressed
            .map((key) => key.usbHidUsage)
            .toList(),
        'key_down_handled_by_framework': keyDownHandled,
        if (key != null)
          'key': <String, Object?>{
            'type': key.runtimeType.toString(),
            'logical_key': key.logicalKey.keyId,
            'logical_label': key.logicalKey.keyLabel,
            'physical_key': key.physicalKey.usbHidUsage,
            'character': key.character,
            'synthesized': key.synthesized,
            'timestamp_us': key.timeStamp.inMicroseconds,
          },
      });
      // Only explicit test-owned checkpoints use WidgetTester. Controller,
      // focus and keyboard callbacks above read held objects only, even when
      // delivered from another zone during a pending guarded pump.
      if (readWidgets) sample.addAll(_widgetSnapshot());
    } catch (error) {
      sample['observation_error'] = '$error';
      errors.add('$phase: $error');
    }
    samples.add(sample);
  }

  Map<String, Object?> _semantics(Finder finder) {
    final count = finder.evaluate().length;
    if (count != 1) return <String, Object?>{'count': count};
    final data = tester.getSemantics(finder).getSemanticsData();
    return <String, Object?>{
      'count': count,
      'label': data.label,
      'enabled': data.flagsCollection.isEnabled.name,
    };
  }

  Map<String, Object?> _widgetSnapshot() {
    final component = tester.widget<BeautifulPromptBar>(prompt);
    final editor = tester.widget<EditableText>(_editorFinder);
    Finder inside(Finder finder) =>
        find.descendant(of: prompt, matching: finder);
    return <String, Object?>{
      'composer_id': component.composerId,
      'editor_widget_id': identityHashCode(editor),
      'controller_id': identityHashCode(editor.controller),
      'focus_id': identityHashCode(editor.focusNode),
      'input': editor.controller.value.toJSON(),
      'editor_has_focus': editor.focusNode.hasFocus,
      'editor_primary_focus': editor.focusNode.hasPrimaryFocus,
      'editor_read_only': editor.readOnly,
      'prompt_enabled': component.enabled,
      'commands': <Map<String, String>>[
        for (final command in component.commands)
          <String, String>{'id': command.id, 'label': command.label},
      ],
      'commands_label_count': inside(find.text(component.commandsLabel))
          .evaluate()
          .length,
      'sources_label_count': inside(find.text(component.sourcesLabel))
          .evaluate()
          .length,
      'models_label_count': inside(find.text(component.modelsLabel))
          .evaluate()
          .length,
      'no_matches_count': inside(find.text(component.noMatchesLabel))
          .evaluate()
          .length,
      'restock_option': _semantics(
        inside(
          find.byKey(const Key('beautiful-prompt-option-command-restock')),
        ),
      ),
      'send_control': _semantics(
        inside(find.byKey(const Key('beautiful-prompt-send'))),
      ),
      'sending_label_count': inside(find.text(component.sendingLabel))
          .evaluate()
          .length,
      'view_insets_bottom_physical': tester.view.viewInsets.bottom,
      'host_prompt_received': <String>[
        for (final text in tester.widgetList<Text>(
          find.textContaining('Prompt received:'),
        ))
          if (text.data != null) text.data!,
      ],
    };
  }

  void finish() {
    if (_closed) return;
    sample('observer_finished');
    try {
      _controller?.removeListener(_onInput);
    } catch (error) {
      errors.add('controller cleanup: $error');
    }
    try {
      _focus?.removeListener(_onFocus);
    } catch (error) {
      errors.add('focus cleanup: $error');
    }
    try {
      if (_keyboardAttached) HardwareKeyboard.instance.removeHandler(_onKey);
    } catch (error) {
      errors.add('keyboard cleanup: $error');
    }
    _closed = true;
  }
}
