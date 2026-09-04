import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

import '../integration_test/support/performance_suite.dart';
import '../integration_test/support/profile_timeline_codec.dart';
import 'profile_driver_adapter.dart';

/// Writes compact evidence separately from raw engine frames and VM timelines.
Future<void> main(List<String> arguments) async {
  if (arguments.length == 3 && arguments.first == '--finalize') {
    await _finalize(Directory(arguments[1]), int.parse(arguments[2]));
    return;
  }
  final directory = Directory(
    Platform.environment['P3_PERF_OUTPUT_DIR'] ??
        'build/p3-profile/${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}',
  );
  final capture = await captureNativeProfile(
    connect: () async => _NativeProfileTransport(await FlutterDriver.connect()),
    persist: (name, data) =>
        writeProfileArtifactAtomically(directory, name, data),
    inspectResponse: (raw) {
      final response = Response.fromJson(raw);
      if (!response.allTestsPassed) {
        throw StateError(response.formattedFailureDetails);
      }
    },
  );
  final status = await writeCapturedProfileEvidence(capture, directory);
  // A timed-out SDK Future is not cancellable and may still own sockets/timers.
  // Exit only after evidence and the primary/secondary failures are persisted.
  exit(status);
}

/// Recovery derives explicitly failed evidence from an untouched raw checkpoint.
Future<int> writeCapturedProfileEvidence(
  ProfileDriverCapture capture,
  Directory directory, {
  Future<void> Function(Map<String, dynamic>?, Directory)? writeEvidence,
}) async {
  Map<String, dynamic>? data;
  if (capture.response != null && capture.checkpoint?['terminal'] != true) {
    try {
      final response = Response.fromJson(capture.response!);
      data = response.data;
      if (!response.allTestsPassed &&
          !capture.failures.any(
            (failure) => failure.phase == 'response_validation',
          )) {
        capture.failures.add(
          ProfileDriverFailure(
            'native_test_response',
            StateError(response.formattedFailureDetails),
            StackTrace.current,
          ),
        );
      }
    } catch (error, stack) {
      capture.failures.add(
        ProfileDriverFailure('response_decode', error, stack),
      );
    }
  }
  final recovering = data == null && capture.checkpoint != null;
  if (recovering) {
    if (!capture.failed) {
      capture.failures.add(
        ProfileDriverFailure(
          'checkpoint_recovery',
          StateError(
            'No complete integration response data; recovering the last durable checkpoint.',
          ),
          StackTrace.current,
        ),
      );
    }
    data = Map<String, dynamic>.from(capture.checkpoint!['report_data'] as Map);
  }
  if (data != null &&
      data['p3_performance'] is Map &&
      (capture.failed || recovering)) {
    data = Map<String, dynamic>.from(data);
    final report = Map<String, dynamic>.from(data['p3_performance'] as Map);
    report['workload_status_before_transport_failure'] = report['status'];
    report['status'] = recovering
        ? 'failed_partial_transport'
        : 'failed_transport';
    report['transport_evidence_origin'] = <String, Object?>{
      'kind': recovering ? 'checkpoint_recovery' : 'integration_response',
      'partial': recovering,
      'checkpoint_file': recovering ? capture.checkpointFile : null,
    };
    data['p3_performance'] = report;
  }
  try {
    await (writeEvidence ?? writeProfilePerformanceEvidence)(data, directory);
  } catch (error, stack) {
    capture.failures.add(ProfileDriverFailure('evidence_write', error, stack));
  }
  try {
    await _write(directory, 'driver_transport.json', capture.toJson());
  } catch (error, stack) {
    capture.failures.add(
      ProfileDriverFailure('diagnostic_write', error, stack),
    );
    // Diagnostic persistence must not replace the original frame/transport
    // failure. Keep its exit status and report the ordered failures to stderr.
    try {
      for (var index = 0; index < capture.failures.length; index++) {
        final failure = capture.failures[index];
        stderr.writeln(
          'P3_PROFILE_DRIVER_${index == 0 ? 'PRIMARY' : 'SECONDARY'} '
          '[${failure.phase}]: ${failure.error}\n${failure.stack}',
        );
      }
    } catch (_) {
      // A closed diagnostic stream must not replace the primary failure either.
    }
  }
  return capture.failed || recovering ? 1 : 0;
}

final class _NativeProfileTransport implements ProfileDriverTransport {
  _NativeProfileTransport(this.driver);
  final FlutterDriver driver;

  @override
  Stream<Map<String, dynamic>> get checkpointEvents => driver
      .serviceClient
      .onExtensionEvent
      .where(
        (event) =>
            event.extensionKind == 'beautiful.profileCheckpoint' &&
            event.isolate?.id == driver.appIsolate.id,
      )
      .map((event) => Map<String, dynamic>.from(event.extensionData!.data));

  @override
  Future<void> get disconnected => driver.serviceClient.onDone;

  @override
  Future<void> listenForCheckpoints() =>
      driver.serviceClient.streamListen('Extension');

  @override
  Future<String> requestData() => driver.requestData(null);

  @override
  Future<Map<String, dynamic>> checkpoint(String action, int sequence) async {
    final response = await driver.serviceClient.callServiceExtension(
      'ext.beautiful.profileCheckpoint',
      isolateId: driver.appIsolate.id,
      args: <String, String>{'action': action, 'sequence': '$sequence'},
    );
    return Map<String, dynamic>.from(response.json!);
  }

  @override
  Future<void> stopTimeline() async {
    await driver.serviceClient.setVMTimelineFlags(const <String>[]);
  }

  @override
  Future<void> close() => driver.close();
}

/// Saves independent evidence even when one timeline cannot be decoded.
Future<void> writeProfilePerformanceEvidence(
  Map<String, dynamic>? data,
  Directory directory, {
  Future<Map<String, Object?>> Function(Directory)? launcherMetadata,
  Future<Map<String, Object?>> Function()? sourceMetadata,
}) async {
  await directory.create(recursive: true);
  await _write(directory, 'p3_response_data.raw.json', data);
  if (data == null || data['p3_performance'] is! Map) {
    await _write(directory, 'p3_performance.json', <String, Object?>{
      'status': 'failed_missing_report_data',
      'received_data': data,
    });
    throw StateError('Missing p3_performance report data; the run is invalid.');
  }
  final report = Map<String, dynamic>.from(data['p3_performance'] as Map);
  final failures = <ProfileDriverFailure>[];
  void failed(String phase, Object error, StackTrace stack) =>
      failures.add(ProfileDriverFailure(phase, error, stack));
  Future<void> save(String name, Object? value) async {
    try {
      await _write(directory, name, value);
    } catch (error, stack) {
      failed('write_$name', error, stack);
    }
  }

  final rawFrames = <String, Object?>{};
  final rawMemory = <String, Object?>{};
  final scenarios = <Map<String, dynamic>>[];
  for (final value in (report['scenarios'] as List? ?? <Object>[])) {
    try {
      final scenario = Map<String, dynamic>.from(value as Map);
      final id = scenario['id'] as String;
      if (rawFrames.containsKey(id)) {
        throw StateError('Duplicate scenario $id.');
      }
      rawFrames[id] = scenario.remove('raw_frame_timings');
      rawMemory[id] = scenario.remove('rss_samples');
      scenario['raw_frame_file'] = 'p3_frame_samples.json';
      scenario['raw_memory_file'] = 'p3_memory_samples.json';
      scenarios.add(scenario);
    } catch (error, stack) {
      failed('scenario_evidence', error, stack);
    }
  }
  report['scenarios'] = scenarios;
  // These writes precede metadata commands and timeline decoding. The raw
  // response above also preserves malformed entries we cannot split safely.
  await save('p3_frame_samples.json', rawFrames);
  await save('p3_memory_samples.json', rawMemory);
  await save('p3_performance.json', report);
  final traces = <String, String>{};
  final traceFailures = <String, Object?>{};
  for (final entry in data.entries) {
    if (!entry.key.startsWith('p3_trace_')) continue;
    try {
      final timeline = decodeProfileTimeline(entry.value);
      final filename = '${entry.key}.timeline.json';
      await _write(directory, filename, timeline);
      traces[entry.key] = filename;
    } catch (error, stack) {
      failed('timeline_${entry.key}', error, stack);
      final filename = '${entry.key}.transport_failure.json';
      await save(filename, entry.value);
      traceFailures[entry.key] = <String, Object?>{
        'error': error.toString(),
        'original_payload_file': filename,
      };
    }
  }
  for (final scenario in scenarios) {
    scenario['timeline_file'] = traces[scenario['trace_report_key']];
  }
  try {
    await save(
      'launcher_metadata.json',
      await (launcherMetadata ?? _launcherMetadata)(directory),
    );
  } catch (error, stack) {
    failed('launcher_metadata', error, stack);
  }
  Map<String, Object?> source = <String, Object?>{};
  try {
    source = await (sourceMetadata ?? _sourceMetadata)();
  } catch (error, stack) {
    failed('source_metadata', error, stack);
  }
  report['driver'] = <String, Object?>{
    'written_at_utc': DateTime.now().toUtc().toIso8601String(),
    'host_os': Platform.operatingSystem,
    'host_os_version': Platform.operatingSystemVersion,
    ...source,
    'device_id_requested': Platform.environment['P3_PERF_DEVICE_ID'],
    'performance_suite': Platform.environment['P3_PERF_SUITE'] ?? 'p3',
    'launcher_metadata_file': 'launcher_metadata.json',
    'launch_log': 'launch.log',
    'timeline_decode_failures': traceFailures,
    'evidence_failures': failures.map((value) => value.toJson()).toList(),
    'launcher_notes': 'Files named here are created by tool/run_p3_profile.sh; direct flutter drive users should save the exact command, Flutter version and engine launch log themselves.',
  };
  if (traceFailures.isNotEmpty) {
    report['workload_status_before_timeline_decode_failure'] = report['status'];
    report['status'] = 'failed_timeline_decode';
  } else if (failures.isNotEmpty) {
    report['workload_status_before_evidence_failure'] = report['status'];
    report['status'] = 'failed_evidence_write';
  }
  await save('p3_performance.json', report);
  if (failures.isNotEmpty) {
    throw StateError(
      'Profile evidence failure: ${failures.first.error}. '
      'Independent samples and the raw response were preserved where writable; '
      '${failures.length - 1} secondary failure(s) are recorded.',
    );
  }
}

Future<Map<String, Object?>> _sourceMetadata() async => <String, Object?>{
  'source_revision': await _command('git', <String>['rev-parse', 'HEAD']),
  'source_worktree_status': await _command('git', <String>[
    'status',
    '--porcelain',
  ]),
};

Future<String?> _command(String executable, List<String> arguments) async {
  Process? process;
  try {
    process = await Process.start(
      executable,
      arguments,
    ).timeout(const Duration(seconds: 3));
    final values = await Future.wait<Object?>(<Future<Object?>>[
      process.exitCode,
      process.stdout.transform(utf8.decoder).join(),
      process.stderr.drain<void>(),
    ]).timeout(const Duration(seconds: 3));
    return values[0] == 0 ? (values[1]! as String).trim() : null;
  } on ProcessException {
    return null;
  } on TimeoutException {
    process?.kill(ProcessSignal.sigkill);
    rethrow;
  }
}

Future<Map<String, Object?>> _launcherMetadata(Directory directory) async {
  final versionFile = File('${directory.path}/flutter_version.json');
  final commandFile = File('${directory.path}/launch_command.txt');
  final logFile = File('${directory.path}/launch.log');
  Object? flutterVersion;
  if (await versionFile.exists()) {
    try {
      flutterVersion = jsonDecode(await versionFile.readAsString());
    } on FormatException {
      flutterVersion = 'flutter_version.json could not be parsed';
    }
  }
  final engineEvidence = <String>[];
  if (await logFile.exists()) {
    for (final line in await logFile.readAsLines()) {
      if (RegExp(
        r'Using the .*rendering backend',
        caseSensitive: false,
      ).hasMatch(line)) {
        engineEvidence.add(line);
      }
    }
  }
  return <String, Object?>{
    'flutter_version': flutterVersion,
    'launch_command': await commandFile.exists()
        ? (await commandFile.readAsString()).trim()
        : null,
    'developer_dir': Platform.environment['DEVELOPER_DIR'],
    'host_hardware_model': Platform.isMacOS
        ? await _command('/usr/sbin/sysctl', <String>['-n', 'hw.model'])
        : null,
    'host_cpu': Platform.isMacOS
        ? await _command('/usr/sbin/sysctl', <String>[
            '-n',
            'machdep.cpu.brand_string',
          ])
        : null,
    'host_physical_memory_bytes': Platform.isMacOS
        ? await _command('/usr/sbin/sysctl', <String>['-n', 'hw.memsize'])
        : null,
    'engine_renderer_log_evidence': engineEvidence,
    'renderer_observation_status': engineEvidence.isEmpty
        ? 'No backend announcement found in the captured launch log; requested/default backend remains unverified.'
        : 'Exact engine backend announcement lines from launch.log are retained above.',
  };
}

Future<void> _write(Directory directory, String name, Object? data) =>
    writeProfileArtifactAtomically(
      directory,
      name,
      const JsonEncoder.withIndent('  ').convert(data),
    );

Future<void> _finalize(Directory directory, int driverExitCode) async {
  final file = File('${directory.path}/p3_performance.json');
  final report = await file.exists()
      ? Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map)
      : <String, dynamic>{'status': 'failed_missing_report_data'};
  report['workload_phase_status'] = report['status'];
  report['integration_driver_exit_code'] = driverExitCode;
  final scenarios = report['scenarios'] as List? ?? <Object>[];
  final suite = Platform.environment['P3_PERF_SUITE'] ?? 'p3';
  final expectedIds = expectedPerformanceScenarios(suite);
  final actualIds = scenarios.map((value) => (value as Map)['id']).toList();
  report['performance_suite'] = suite;
  report['expected_scenario_ids'] = expectedIds;
  final complete =
      driverExitCode == 0 &&
      report['workload_phase_status'] == 'workloads_complete' &&
      report['suite'] == 'beautiful_ai_ui_${suite}_native_profile' &&
      actualIds.length == expectedIds.length &&
      actualIds.toSet().length == expectedIds.length &&
      actualIds.every(expectedIds.contains) &&
      scenarios.every((value) => (value as Map)['status'] == 'complete');
  report['status'] = complete ? 'complete' : 'failed';
  report['finalized_at_utc'] = DateTime.now().toUtc().toIso8601String();
  if (!complete && driverExitCode != 0) {
    report['run_failure_note'] = 'The integration driver failed; inspect launch.log even if individual workloads captured valid samples. This run is not accepted as a complete profile run.';
  }
  await _write(directory, 'p3_performance.json', report);
  exitCode = complete ? 0 : (driverExitCode == 0 ? 1 : driverExitCode);
}
