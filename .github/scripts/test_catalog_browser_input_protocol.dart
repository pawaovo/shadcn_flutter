// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/common.dart';

import '../../packages/beautiful_ai_ui_catalog/integration_test/driver/catalog_browser_input_driver.dart';

/// This exercises the real HTTP boundary without launching a browser or GUI.
Future<void> main() async {
  final requests = <Map<String, Object?>>[];
  final pendingSnapshots = <Map<String, Object?>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var failNext = false;
  server.listen((request) async {
    final bytes = await request.fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    final body = utf8.decode(bytes);
    requests.add(<String, Object?>{
      'method': request.method,
      'path': request.uri.path,
      'body': body.isEmpty ? null : jsonDecode(body),
      'raw_body': body,
      'body_bytes': bytes.length,
      'content_length': request.contentLength,
      'transfer_encoding': request.headers.value(
        HttpHeaders.transferEncodingHeader,
      ),
    });
    request.response.headers.contentType = ContentType.json;
    if (failNext) {
      failNext = false;
      request.response.statusCode = 500;
      request.response.write(
        '{"value":{"error":"timeout","message":"real upstream failure"}}',
      );
    } else if (pendingSnapshots.isNotEmpty) {
      request.response.write(
        jsonEncode(<String, Object?>{'value': pendingSnapshots.removeAt(0)}),
      );
    } else {
      request.response.write('{"value":null}');
    }
    await request.response.close();
  });
  final driver = BrowserInputDriver(
    Uri.parse('http://127.0.0.1:${server.port}/session/actual/'),
  );
  void check(bool condition, String description) {
    if (!condition) throw StateError(description);
  }

  try {
    const navigation = <String, String>{
      'url': 'http://127.0.0.1/catalog?draft=中文🚀',
    };
    await driver.command('POST', 'url', navigation);
    final navigate = requests.single;
    final encodedNavigation = jsonEncode(navigation);
    final navigationBytes = utf8.encode(encodedNavigation).length;
    check(
      navigate['method'] == 'POST' && navigate['path'] == '/session/actual/url',
      'Navigation must send POST url to the existing session',
    );
    check(
      navigate['content_length'] == navigationBytes &&
          navigate['body_bytes'] == navigationBytes &&
          navigationBytes > encodedNavigation.length,
      'WebDriver must receive Content-Length measured in UTF-8 bytes',
    );
    check(
      navigate['transfer_encoding'] == null,
      'WebDriver requests must not use chunked transfer encoding',
    );
    check(
      navigate['raw_body'] == encodedNavigation &&
          (navigate['body'] as Map)['url'] == navigation['url'],
      'POST url must preserve its complete non-ASCII JSON body',
    );

    await driver.click(40, 80);
    final click = (requests.last['body'] as Map)['actions'] as List;
    check(
      click.single['type'] == 'pointer',
      'Clicks must use native W3C pointer actions',
    );
    check(
      click.single['actions'][0]['origin'] == 'viewport',
      'Coordinates must target the browser viewport',
    );
    check(
      click.single['actions'][1]['type'] == 'pointerDown',
      'Missing real pointer down',
    );
    check(
      click.single['actions'][2]['type'] == 'pointerUp',
      'Missing pointer release',
    );

    await driver.chord('\uE009', 'v');
    final keys =
        ((requests.last['body'] as Map)['actions'] as List).single['actions']
            as List;
    check(
      keys.map((key) => key['type']).join(',') == 'keyDown,keyDown,keyUp,keyUp',
      'Modifiers must be released',
    );
    check(
      keys.first['value'] == '\uE009' && keys.last['value'] == '\uE009',
      'Wrong modifier lifetime',
    );
    check(
      requests.last['path'] == '/session/actual/actions',
      'Commands must use the existing real session',
    );

    final before = requests.length;
    failNext = true;
    var failed = false;
    try {
      await driver.command('POST', 'window/rect', <String, int>{
        'width': 599,
        'height': 900,
      });
    } on StateError catch (error) {
      failed =
          error.message.contains('500') &&
          error.message.contains('real upstream failure');
    }
    check(failed, 'Upstream errors must fail acceptance unchanged');
    check(requests.length == before + 1, 'Failed operations must not retry');
    check(
      requests.every(
        (request) =>
            request['content_length'] == request['body_bytes'] &&
            request['transfer_encoding'] == null,
      ),
      'Every JSON command must retain explicit byte framing',
    );
    print(
      'Browser input protocol checks passed: UTF-8 byte framing, complete POST url, native events, balanced keys, existing session, original failure, no retry.',
    );
    await _exerciseReadOnlyMonitor(driver, requests, pendingSnapshots);
  } finally {
    driver.close();
    await server.close(force: true);
  }
  await _exerciseDriverMain();
}

Future<void> _exerciseReadOnlyMonitor(
  BrowserInputDriver driver,
  List<Map<String, Object?>> requests,
  List<Map<String, Object?>> pendingSnapshots,
) async {
  const documentText = 'Read-only document 中文';
  const promptText = 'Unrelated Prompt draft';
  const stageName = 'readonly-copy';
  final report = <String, Object?>{'stages': <Object?>[]};
  final monitor = BrowserAcceptanceMonitor(driver, report);

  Map<String, Object?> snapshot({
    bool documentFocused = true,
    bool documentReadOnly = true,
    bool documentSelected = false,
    bool domReadOnly = true,
    bool domInFlutterView = true,
    bool domDisabled = false,
    String domTag = 'textarea',
    bool domSelected = false,
    String domText = documentText,
  }) => <String, Object?>{
    'stage': <String, Object?>{
      'stage': stageName,
      // Deliberately ready and fully selected: these fields describe Prompt,
      // not the document the read-only actions are meant to exercise.
      'focused': true,
      'draft': promptText,
      'selectionStart': 0,
      'selectionEnd': promptText.length,
      'document': <String, Object?>{
        'text': documentText,
        'focused': documentFocused,
        'readOnly': documentReadOnly,
        'selectionStart': 0,
        'selectionEnd': documentSelected ? documentText.length : 0,
        'state_id': 41,
        'controller_id': 42,
      },
    },
    'result': null,
    'acknowledgement': null,
    'activeEditor': <String, Object?>{
      // The general writable-editor flag is false for a valid read-only field.
      'ready': !domReadOnly && domInFlutterView && !domDisabled,
      'tagName': domTag,
      'inFlutterView': domInFlutterView,
      'readOnly': domReadOnly,
      'disabled': domDisabled,
      'value': domText,
      'selectionStart': 0,
      'selectionEnd': domSelected ? documentText.length : 0,
    },
  };

  Future<void> consume(
    String description,
    List<Map<String, Object?>> snapshots,
    Future<void> Function() wait,
  ) async {
    final before = requests.length;
    pendingSnapshots.addAll(snapshots);
    await wait().timeout(const Duration(seconds: 3));
    if (pendingSnapshots.isNotEmpty) {
      throw StateError(
        '$description accepted an invalid earlier snapshot; '
        '${pendingSnapshots.length} required snapshots were not consumed',
      );
    }
    final observed = requests.skip(before).toList();
    if (observed.length != snapshots.length ||
        observed.any(
          (request) =>
              request['method'] != 'POST' ||
              request['path'] != '/session/actual/execute/sync' ||
              (request['body'] as Map)['script'] !=
                  browserAcceptanceSnapshotScript,
        )) {
      throw StateError('$description must only poll the read-only snapshot');
    }
  }

  await consume('Read-only document readiness', <Map<String, Object?>>[
    snapshot(documentFocused: false),
    snapshot(documentReadOnly: false),
    snapshot(domReadOnly: false),
    snapshot(domInFlutterView: false),
    snapshot(domDisabled: true),
    snapshot(domTag: 'div'),
    snapshot(),
  ], () => monitor.waitForReadOnlyEditorReady(stageName));
  await consume('Exact read-only document selection', <Map<String, Object?>>[
    snapshot(domSelected: true),
    snapshot(documentSelected: true),
    snapshot(documentSelected: true, domSelected: true, domText: promptText),
    snapshot(documentSelected: true, domSelected: true),
  ], () => monitor.waitForDocumentSelection(stageName));
  final document = (report['last_non_null_state'] as Map)['document'] as Map;
  if (document['state_id'] != 41 || document['controller_id'] != 42) {
    throw StateError('Read-only observations must retain document identities');
  }
  print(
    'Read-only monitor checks passed: document focus, native read-only field, '
    'matching Flutter/DOM text and full selection; Prompt state cannot satisfy either wait.',
  );
}

/// Run the actual entry point against an HTTP fixture, including its reporting
/// and process exit behavior. No browser, clipboard, or product action runs.
Future<void> _exerciseDriverMain() async {
  final root = File.fromUri(Platform.script).parent.parent.parent;
  final entryPoint =
      Platform.environment['BROWSER_PROTOCOL_DRIVER_UNDER_TEST'] ??
      '${root.path}/packages/beautiful_ai_ui_catalog/integration_test/driver/'
          'catalog_browser_input_driver.dart';
  final evidence = await Directory.systemTemp.createTemp(
    'catalog-browser-input-protocol-',
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  const originalFailure = 'Original Flutter assertion: exact selected text 中文';
  const acknowledgement = 'fixture-copy-ack';
  const typedText = 'browser 中文 draft';
  final terminalResult = jsonEncode(<String, Object?>{
    'isError': false,
    'response': <String, Object?>{
      'message': Response.someTestsFailed(
        <Failure>[Failure('real browser input fixture', originalFailure)],
        data: <String, dynamic>{'fixture_target_failure': true},
      ).toJson(),
    },
  });
  var clicks = 0;
  var readinessSamplesAfterClick = 0;
  var ready = false;
  var typedBeforeReady = false;
  var terminalAvailable = false;
  var terminalSnapshots = 0;
  final typedBatches = <String>[];
  final fixtureErrors = <String>[];

  Map<String, Object?> state() => <String, Object?>{
    'stage': 'prompt-type',
    'x': 40,
    'y': 80,
    'width': 1440,
    'height': 900,
    'draft': '',
    'focused': readinessSamplesAfterClick > 1,
    'selectionStart': 0,
    'selectionEnd': 0,
  };

  server.listen((request) async {
    request.response.headers.contentType = ContentType.json;
    try {
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      Object? value;
      if (request.uri.path == '/session/fixture/url') {
        value = null;
      } else if (request.uri.path == '/session/fixture/actions') {
        final source = (body['actions'] as List).single as Map;
        if (source['type'] == 'pointer') {
          clicks++;
        } else if (source['type'] == 'key') {
          if (!ready) {
            typedBeforeReady = true;
            throw StateError('Fixture rejected typing before focus was ready');
          }
          final actions = source['actions'] as List;
          final expectedActions = <Map<String, String>>[
            for (final rune in typedText.runes) ...<Map<String, String>>[
              <String, String>{
                'type': 'keyDown',
                'value': String.fromCharCode(rune),
              },
              <String, String>{
                'type': 'keyUp',
                'value': String.fromCharCode(rune),
              },
            ],
          ];
          if (jsonEncode(actions) != jsonEncode(expectedActions)) {
            throw StateError(
              'Expected one complete, balanced initial text batch',
            );
          }
          typedBatches.add(
            actions
                .where((action) => action['type'] == 'keyDown')
                .map((action) => action['value'] as String)
                .join(),
          );
          terminalAvailable = true;
        } else {
          throw StateError('Unexpected W3C input source: $source');
        }
      } else if (request.uri.path == '/session/fixture/execute/sync') {
        final script = body['script'] as String;
        if (script.contains(r'typeof window.$flutterDriver') ||
            script.startsWith(r'window.$flutterDriver(arguments[0])')) {
          value = true;
        } else if (script.contains('__beautifulInputAcceptance')) {
          if (clicks > 0 && !terminalAvailable) {
            readinessSamplesAfterClick++;
            // Flutter focus can arrive before the active DOM editor is ready.
            ready = readinessSamplesAfterClick > 2;
          }
          final snapshot = <String, Object?>{
            'stage': terminalAvailable ? null : state(),
            'result': terminalAvailable ? terminalResult : null,
            'acknowledgement': terminalAvailable ? acknowledgement : null,
            'activeEditor': <String, Object?>{
              'ready': ready,
              'tagName': 'TEXTAREA',
              'value': terminalAvailable ? typedText : '',
              'selectionStart': terminalAvailable ? typedText.length : 0,
              'selectionEnd': terminalAvailable ? typedText.length : 0,
            },
          };
          if (script.contains(r'$flutterDriverResult')) {
            if (terminalAvailable) terminalSnapshots++;
            value = snapshot;
          } else {
            // Keep the pre-fix driver's stage-only polling supported so the
            // same fixture catches its missing readiness wait.
            value = snapshot['stage'];
          }
        } else {
          throw StateError('Unexpected driver script: $script');
        }
      } else {
        throw StateError('Unexpected WebDriver route: ${request.uri.path}');
      }
      request.response.write(jsonEncode(<String, Object?>{'value': value}));
    } catch (error) {
      fixtureErrors.add('$error');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(
        jsonEncode(<String, Object?>{
          'value': <String, Object?>{
            'error': 'unknown error',
            'message': '$error',
          },
        }),
      );
    } finally {
      await request.response.close();
    }
  });

  Process? process;
  var exited = false;
  try {
    final elapsed = Stopwatch()..start();
    process = await Process.start(
      Platform.resolvedExecutable,
      <String>[
        '--packages=${root.path}/.dart_tool/package_config.json',
        entryPoint,
      ],
      workingDirectory: root.path,
      environment: <String, String>{
        'DRIVER_SESSION_URI': 'http://127.0.0.1:${server.port}/',
        'DRIVER_SESSION_ID': 'fixture',
        'DRIVER_SESSION_CAPABILITIES': jsonEncode(<String, String>{
          'browserName': 'firefox',
          'browserVersion': 'fixture',
          'platformName': 'linux',
        }),
        'BEAUTIFUL_INPUT_BROWSER': 'firefox',
        'BEAUTIFUL_INPUT_EVIDENCE': evidence.path,
        'VM_SERVICE_URL': 'http://127.0.0.1/catalog-fixture',
      },
    );
    final stdoutText = utf8.decoder.bind(process.stdout).join();
    final stderrText = utf8.decoder.bind(process.stderr).join();
    final code = await process.exitCode.timeout(const Duration(seconds: 10));
    exited = true;
    final output = '${await stdoutText}\n${await stderrText}';
    void check(bool condition, String description) {
      if (!condition) throw StateError('$description\nDriver output: $output');
    }

    check(
      !typedBeforeReady,
      'Driver typed before focus readiness was observed',
    );
    check(fixtureErrors.isEmpty, 'Unexpected fixture errors: $fixtureErrors');
    check(clicks == 1, 'Initial input must click exactly once, saw $clicks');
    check(
      readinessSamplesAfterClick >= 3,
      'Driver must wait for both Flutter focus and active DOM editor readiness',
    );
    check(
      typedBatches.length == 1 && typedBatches.single == typedText,
      'Driver must send the original text once after readiness: $typedBatches',
    );
    check(code != 0, 'Original Flutter failure must make driver.main fail');
    check(
      terminalSnapshots == 1 && elapsed.elapsed < const Duration(seconds: 10),
      'Driver must stop on the first terminal failure instead of polling 65s',
    );
    final report = jsonDecode(
      await File('${evidence.path}/browser-input.json').readAsString(),
    ) as Map<String, dynamic>;
    check(report['status'] == 'failed', 'Evidence must retain failed status');
    check(
      '${report['error']}'.contains(originalFailure) &&
          '${report['original_failure']}'.contains(originalFailure),
      'Evidence must preserve the original Flutter failure details',
    );
    check(
      (report['integration_data'] as Map?)?['fixture_target_failure'] == true,
      'Evidence must retain the original integration response data',
    );
    final lastState = report['last_non_null_state'] as Map?;
    check(
      lastState?['stage'] == 'prompt-type' && lastState?['focused'] == true,
      'A null terminal stage must retain the last ready Flutter state',
    );
    check(
      report['last_acknowledgement'] == acknowledgement,
      'Evidence must retain the terminal acknowledgement',
    );
    check(
      (report['last_snapshot'] as Map?)?['result'] == terminalResult,
      'Evidence must retain the original terminal snapshot',
    );
    print(
      'Driver main checks passed: one click, delayed focus readiness, exact '
      'text once, immediate original failure, retained state and acknowledgement.',
    );
  } on TimeoutException {
    throw StateError('Driver ignored the early terminal result for 10 seconds');
  } finally {
    try {
      if (process != null && !exited) {
        process.kill();
        try {
          await process.exitCode.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          process.kill(ProcessSignal.sigkill);
          await process.exitCode.timeout(const Duration(seconds: 2));
        }
      }
    } finally {
      await server.close(force: true);
      await evidence.delete(recursive: true);
    }
  }
}
