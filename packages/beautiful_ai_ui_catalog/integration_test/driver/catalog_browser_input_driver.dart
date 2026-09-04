// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/common.dart';

/// Uses the actual session created by `flutter drive`; the SDK's original
/// window positioning/sizing and real browser identity checks remain in place.
Future<void> main() async {
  final evidence = Directory(
    Platform.environment['BEAUTIFUL_INPUT_EVIDENCE'] ?? 'build/browser-input',
  )..createSync(recursive: true);
  final report = <String, Object?>{
    'status': 'running',
    'input_delivery': 'W3C pointer and key actions, without JS text injection',
    'clipboard': 'real browser clipboard; no permission overrides or mocks',
    'os_ime': 'not tested; Unicode key insertion is not OS IME acceptance',
    'capabilities': jsonDecode(
      Platform.environment['DRIVER_SESSION_CAPABILITIES']!,
    ),
    'stages': <Object?>[],
  };
  final driver = BrowserInputDriver.fromEnvironment();
  try {
    final expectedBrowser = Platform.environment['BEAUTIFUL_INPUT_BROWSER'];
    final capabilities = report['capabilities'] as Map;
    final actualBrowser = capabilities['browserName'].toString().toLowerCase();
    final names = expectedBrowser == 'edge'
        ? <String>{'microsoftedge', 'msedge'}
        : <String>{expectedBrowser ?? actualBrowser};
    if (!names.contains(actualBrowser) ||
        capabilities['browserVersion'] == null) {
      throw StateError('Unexpected real browser identity: $capabilities');
    }
    await driver.command('POST', 'url', <String, Object?>{
      'url': Platform.environment['VM_SERVICE_URL']!,
    });
    await driver.waitFor(
      () async =>
          await driver.script(
            r'return typeof window.$flutterDriver === "function";',
          ) ==
          true,
      'integration_test extension',
    );
    await driver.script(
      r'window.$flutterDriver(arguments[0]); return true;',
      <Object?>[
        jsonEncode(<String, String>{
          'command': 'request_data',
          'timeout': '1200000',
        }),
      ],
    );
    final platform = (report['capabilities'] as Map)['platformName']
        .toString()
        .toLowerCase();
    final modifier = platform.contains('mac') ? '\uE03D' : '\uE009';
    final stages = report['stages'] as List<Object?>;
    final monitor = BrowserAcceptanceMonitor(driver, report);
    Future<Map<String, dynamic>> stage(String name) =>
        monitor.waitForStage(name);

    Future<void> clickStage(String name, {bool editor = false}) async {
      final state = await monitor.waitForStage(name);
      await driver.click(
        (state['x'] as num).round(),
        (state['y'] as num).round(),
      );
      if (editor) await monitor.waitForEditorReady(name);
    }

    Future<void> acknowledge(String name) => driver
        .script(
          'window.__beautifulInputAcknowledgement = arguments[0]; return true;',
          <Object?>[name],
        )
        .then((_) {});

    await clickStage('prompt-type', editor: true);
    await driver.keys('browser 中文 draft');
    await stage('shift-enter');
    await driver.chord('\uE008', '\uE006');
    await driver.keys('second line');
    await clickStage('model-open');
    await stage('model-escape');
    await driver.keys('\uE00C');
    await monitor.observe('after model Escape key acknowledgement');

    await stage('keyboard-copy');
    await driver.chord(modifier, 'a');
    await monitor.waitForFullSelection('keyboard-copy');
    await driver.chord(modifier, 'c');
    await monitor.observe('after keyboard copy key acknowledgement');
    await acknowledge('keyboard-copy');
    await monitor.observe('after keyboard-copy acknowledgement');
    await stage('keyboard-clear');
    await driver.chord(modifier, 'a');
    await driver.keys('\uE003');
    await stage('keyboard-paste');
    await driver.chord(modifier, 'v');
    await stage('select-before-resize');
    await driver.chord(modifier, 'a');
    for (final width in <int>[599, 600, 1023, 1024, 1440]) {
      await stage('resize-$width');
      final metrics = Map<String, dynamic>.from(
        await driver.script(
          'return {innerWidth, outerWidth, outerHeight, devicePixelRatio};',
        ) as Map,
      );
      final decoration =
          (metrics['outerWidth'] as num) - (metrics['innerWidth'] as num);
      final rectangle = await driver.command(
        'POST',
        'window/rect',
        <String, Object?>{'width': width + decoration.round(), 'height': 900},
      );
      (stages.last as Map)['actual_window_response'] = rectangle;
    }
    await stage('send');
    await driver.keys('\uE006');

    for (final source in <String>['code', 'stream']) {
      await clickStage('$source-copy');
      await acknowledge('$source-copy');
      await clickStage('$source-paste', editor: true);
      await driver.chord(modifier, 'v');
      await stage('$source-clear');
      await driver.chord(modifier, 'a');
      await driver.keys('\uE003');
    }
    await clickStage('readonly-copy');
    await monitor.waitForReadOnlyEditorReady('readonly-copy');
    await driver.chord(modifier, 'a');
    await monitor.waitForDocumentSelection('readonly-copy');
    await driver.chord(modifier, 'c');
    await monitor.observe('after readonly copy key acknowledgement');
    await driver.keys('\uE003');
    await monitor.observe('after readonly Backspace key acknowledgement');
    await acknowledge('readonly-copy');
    for (final operation in <String>['cut', 'paste']) {
      if (operation == 'paste') {
        await stage('readonly-caret');
        await driver.keys('\uE014');
      }
      final name = 'readonly-$operation-rejected';
      await stage(name);
      await driver.chord(modifier, operation == 'cut' ? 'x' : 'v');
      await acknowledge(name);
    }
    await clickStage('readonly-paste', editor: true);
    await driver.chord(modifier, 'v');
    await stage('complete');
    await acknowledge('complete');

    await monitor.waitForCompletion();
    report['status'] = 'passed';
    print('All tests passed. Real browser input acceptance completed.');
  } catch (error, stack) {
    report['status'] = 'failed';
    report['error'] = '$error';
    report['stack'] = '$stack';
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    driver.close();
    await File('${evidence.path}/browser-input.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  }
}

/// Read-only page snapshot. The active editor may be inside Flutter's shadow
/// root; a focused Flutter node alone does not prove browser text input is ready.
const browserAcceptanceSnapshotScript = r'''
let active = document.activeElement;
while (active && active.shadowRoot && active.shadowRoot.activeElement) {
  active = active.shadowRoot.activeElement;
}
function belongsToFlutter(element) {
  let node = element;
  while (node) {
    if (String(node.tagName || '').toLowerCase() === 'flutter-view' ||
        (node.classList && node.classList.contains('flt-text-editing'))) {
      return true;
    }
    const root = node.getRootNode ? node.getRootNode() : null;
    node = node.parentElement || (root && root.host) || null;
  }
  return false;
}
const tagName = String(active && active.tagName || '').toLowerCase();
const editable = tagName === 'input' || tagName === 'textarea' ||
  !!(active && active.isContentEditable);
const inFlutterView = belongsToFlutter(active);
const readOnly = !!(active && active.readOnly);
const disabled = !!(active && active.disabled);
return {
  stage: window.__beautifulInputAcceptance || null,
  result: window.$flutterDriverResult || null,
  acknowledgement: window.__beautifulInputAcknowledgement || null,
  activeEditor: {
    ready: inFlutterView && editable && !readOnly && !disabled,
    tagName, inFlutterView, readOnly, disabled,
    selectionStart: active && typeof active.selectionStart === 'number' ? active.selectionStart : null,
    selectionEnd: active && typeof active.selectionEnd === 'number' ? active.selectionEnd : null,
    value: inFlutterView && editable && typeof active.value === 'string' ? active.value : null
  }
};
''';

/// Watches page state and the original target result together. An early Flutter
/// failure must retain its assertion instead of becoming a later stage timeout.
final class BrowserAcceptanceMonitor {
  BrowserAcceptanceMonitor(this.driver, this.report);

  final BrowserInputDriver driver;
  final Map<String, Object?> report;

  Future<Map<String, dynamic>> _snapshot(
    String boundary, {
    bool allowTerminalSuccess = false,
  }) async {
    final value = Map<String, dynamic>.from(
      await driver.script(browserAcceptanceSnapshotScript) as Map,
    );
    report['last_snapshot'] = value;
    if (value['stage'] is Map) {
      report['last_non_null_state'] = value['stage'];
    }
    report['last_acknowledgement'] = value['acknowledgement'];
    if (value['result'] case final String encoded) {
      report['terminal_result_received_at_boundary'] = boundary;
      final envelope = jsonDecode(encoded) as Map<String, dynamic>;
      report['original_integration_result'] = envelope;
      if (envelope['isError'] != false) {
        final failure = 'Driver extension failed: $envelope';
        report['original_failure'] = failure;
        throw StateError(failure);
      }
      final response = Response.fromJson(
        (envelope['response'] as Map)['message'] as String,
      );
      report['integration_data'] = response.data;
      if (!response.allTestsPassed) {
        report['original_failure'] = response.formattedFailureDetails;
        throw StateError(response.formattedFailureDetails);
      }
      if (!allowTerminalSuccess) {
        throw StateError(
          'The integration target completed before the driver reached $boundary.',
        );
      }
    }
    return value;
  }

  Future<Map<String, dynamic>> waitForStage(String name) async {
    Map<String, dynamic>? state;
    await driver.waitFor(() async {
      final snapshot = await _snapshot(name);
      if (snapshot['stage'] case final Map stage when stage['stage'] == name) {
        state = Map<String, dynamic>.from(stage);
        return true;
      }
      return false;
    }, name);
    (report['stages'] as List<Object?>).add(<String, Object?>{
      'stage': name,
      'state': state,
      'observed_before_driver_actions': true,
    });
    return state!;
  }

  Future<void> waitForEditorReady(String name) async {
    await driver.waitFor(() async {
      final snapshot = await _snapshot('$name editor readiness');
      final state = snapshot['stage'];
      final active = snapshot['activeEditor'];
      return state is Map &&
          state['stage'] == name &&
          state['focused'] == true &&
          active is Map &&
          active['ready'] == true;
    }, '$name editor readiness after its single pointer click');
    _recordObservation('editor ready for $name');
  }

  Future<void> waitForFullSelection(String name) async {
    await driver.waitFor(() async {
      final snapshot = await _snapshot('$name select-all');
      final state = snapshot['stage'];
      return state is Map &&
          state['stage'] == name &&
          state['focused'] == true &&
          state['draft'] is String &&
          state['selectionStart'] == 0 &&
          state['selectionEnd'] == (state['draft'] as String).length;
    }, '$name exact selection after its single select-all action');
    _recordObservation('full selection for $name');
  }

  Future<void> waitForReadOnlyEditorReady(String name) async {
    await driver.waitFor(() async {
      final snapshot = await _snapshot('$name read-only document readiness');
      return _readOnlyDocumentReady(snapshot, name);
    }, '$name document focus after its single pointer click');
    _recordObservation('read-only document ready for $name');
  }

  bool _readOnlyDocumentReady(Map<String, dynamic> snapshot, String name) {
    final state = snapshot['stage'];
    final document = state is Map ? state['document'] : null;
    final active = snapshot['activeEditor'];
    return state is Map &&
        state['stage'] == name &&
        document is Map &&
        document['focused'] == true &&
        document['readOnly'] == true &&
        document['text'] is String &&
        active is Map &&
        active['inFlutterView'] == true &&
        active['readOnly'] == true &&
        active['disabled'] == false &&
        (active['tagName'] == 'input' || active['tagName'] == 'textarea') &&
        active['value'] == document['text'];
  }

  Future<void> waitForDocumentSelection(String name) async {
    await driver.waitFor(() async {
      final snapshot = await _snapshot('$name document select-all');
      if (!_readOnlyDocumentReady(snapshot, name)) return false;
      final document = (snapshot['stage'] as Map)['document'] as Map;
      final active = snapshot['activeEditor'] as Map;
      final length = (document['text'] as String).length;
      return length > 0 &&
          document['selectionStart'] == 0 &&
          document['selectionEnd'] == length &&
          active['selectionStart'] == 0 &&
          active['selectionEnd'] == length;
    }, '$name exact document selection after its single select-all action');
    _recordObservation('full document selection for $name');
  }

  Future<void> observe(String boundary) async {
    await _snapshot(boundary);
    _recordObservation(boundary);
  }

  void _recordObservation(String boundary) {
    final observations =
        report.putIfAbsent('observations', () => <Object?>[]) as List<Object?>;
    observations.add(<String, Object?>{
      'boundary': boundary,
      'snapshot': report['last_snapshot'],
    });
  }

  Future<void> waitForCompletion() => driver.waitFor(() async {
    final snapshot = await _snapshot(
      'original integration_test completion',
      allowTerminalSuccess: true,
    );
    return snapshot['result'] is String;
  }, 'original integration_test completion');
}

/// Small W3C client: any upstream status/error remains a test failure.
final class BrowserInputDriver {
  BrowserInputDriver(this.session);

  factory BrowserInputDriver.fromEnvironment() {
    final base = Uri.parse(Platform.environment['DRIVER_SESSION_URI']!);
    final id = Platform.environment['DRIVER_SESSION_ID']!;
    return BrowserInputDriver(base.resolve('session/$id/'));
  }

  final Uri session;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);

  Future<Object?> command(String method, String path, [Object? body]) async {
    final request = await _client.openUrl(method, session.resolve(path));
    request.headers.contentType = ContentType.json;
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close().timeout(const Duration(seconds: 60));
    final text = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 60));
    final data = jsonDecode(text) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('WebDriver $method $path: ${response.statusCode} $text');
    }
    return data['value'];
  }

  Future<Object?> script(
    String source, [
    List<Object?> arguments = const <Object?>[],
  ]) => command('POST', 'execute/sync', <String, Object?>{
    'script': source,
    'args': arguments,
  });

  Future<void> waitFor(
    Future<bool> Function() condition,
    String description,
  ) async {
    final elapsed = Stopwatch()..start();
    do {
      if (await condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    } while (elapsed.elapsed < const Duration(seconds: 65));
    throw TimeoutException('Browser acceptance did not reach $description');
  }

  Future<void> click(int x, int y) =>
      command('POST', 'actions', <String, Object?>{
        'actions': <Object?>[
          <String, Object?>{
            'type': 'pointer',
            'id': 'acceptance-pointer',
            'parameters': <String, String>{'pointerType': 'mouse'},
            'actions': <Object?>[
              <String, Object?>{
                'type': 'pointerMove',
                'origin': 'viewport',
                'x': x,
                'y': y,
                'duration': 0,
              },
              <String, Object?>{'type': 'pointerDown', 'button': 0},
              <String, Object?>{'type': 'pointerUp', 'button': 0},
            ],
          },
        ],
      }).then((_) {});

  Future<void> keys(String text) => _keys(<Map<String, String>>[
    for (final rune in text.runes) ...<Map<String, String>>[
      <String, String>{'type': 'keyDown', 'value': String.fromCharCode(rune)},
      <String, String>{'type': 'keyUp', 'value': String.fromCharCode(rune)},
    ],
  ]);

  Future<void> chord(String modifier, String key) =>
      _keys(<Map<String, String>>[
        <String, String>{'type': 'keyDown', 'value': modifier},
        <String, String>{'type': 'keyDown', 'value': key},
        <String, String>{'type': 'keyUp', 'value': key},
        <String, String>{'type': 'keyUp', 'value': modifier},
      ]);

  Future<void> _keys(List<Map<String, String>> actions) =>
      command('POST', 'actions', <String, Object?>{
        'actions': <Object?>[
          <String, Object?>{
            'type': 'key',
            'id': 'acceptance-keyboard',
            'actions': actions,
          },
        ],
      }).then((_) {});

  void close() => _client.close(force: true);
}
