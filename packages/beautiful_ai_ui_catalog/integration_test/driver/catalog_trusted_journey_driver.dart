// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/common.dart';

import 'catalog_browser_input_driver.dart' show BrowserInputDriver;

/// Retains the original full journey result and supplies exactly its two real
/// browser clipboard gestures. It cannot replace a product action with JS.
Future<void> main() async {
  final output = Directory(
    Platform.environment['BEAUTIFUL_INPUT_EVIDENCE'] ?? 'build/trusted-journey',
  )..createSync(recursive: true);
  final report = <String, Object?>{
    'status': 'started',
    'capabilities': jsonDecode(
      Platform.environment['DRIVER_SESSION_CAPABILITIES']!,
    ),
    'trusted_clipboard_clicks': <String>[],
    'other_inputs': 'Original Flutter-injected full Catalog journey',
  };
  final clicked = report['trusted_clipboard_clicks'] as List<String>;
  final driver = BrowserInputDriver.fromEnvironment();
  try {
    await driver.command('POST', 'url', <String, String>{
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
    final elapsed = Stopwatch()..start();
    while (true) {
      final values = await driver.script(
        r'return {stage: window.__beautifulInputAcceptance || null, result: window.$flutterDriverResult};',
      ) as Map;
      final encoded = values['result'];
      if (encoded is String) {
        final envelope = jsonDecode(encoded) as Map;
        if (envelope['isError'] != false) throw StateError('$envelope');
        final response = Response.fromJson(
          (envelope['response'] as Map)['message'] as String,
        );
        report['integration_data'] = response.data;
        if (!response.allTestsPassed) {
          throw StateError(response.formattedFailureDetails);
        }
        if (clicked.toSet().length != 2) {
          throw StateError(
            'The complete journey did not exercise both real copy gestures',
          );
        }
        report['status'] = 'passed';
        print(
          'All tests passed. Original complete Catalog journey with real browser clipboard gestures.',
        );
        break;
      }
      final stage = values['stage'];
      if (stage is Map &&
          <String>{
            'journey-code-copy',
            'journey-stream-copy',
          }.contains(stage['stage'])) {
        final id = stage['stage'] as String;
        if (!clicked.contains(id)) {
          await driver.click(
            (stage['x'] as num).round(),
            (stage['y'] as num).round(),
          );
          clicked.add(id);
          await driver.script(
            'window.__beautifulInputAcknowledgement = arguments[0]; return true;',
            <Object?>[id],
          );
        }
      }
      if (elapsed.elapsed > const Duration(minutes: 20)) {
        throw TimeoutException(
          'Original journey exceeded its completion deadline',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  } catch (error, stack) {
    report.addAll(<String, Object?>{
      'status': 'failed',
      'error': '$error',
      'stack': '$stack',
    });
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    driver.close();
    await File('${output.path}/trusted-journey.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  }
}
