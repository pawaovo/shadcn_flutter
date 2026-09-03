import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Writes compact evidence separately from raw engine frames and VM timelines.
Future<void> main(List<String> arguments) async {
  if (arguments.length == 3 && arguments.first == '--finalize') {
    await _finalize(Directory(arguments[1]), int.parse(arguments[2]));
    return;
  }
  await integrationDriver(
    timeout: const Duration(minutes: 25),
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final output =
          Platform.environment['P3_PERF_OUTPUT_DIR'] ??
          'build/p3-profile/${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}';
      final directory = Directory(output);
      await directory.create(recursive: true);
      if (data == null || data['p3_performance'] is! Map) {
        await _write(directory, 'p3_performance.json', <String, Object?>{
          'status': 'failed_missing_report_data',
          'received_data': data,
        });
        throw StateError(
          'Missing p3_performance report data; the run is invalid.',
        );
      }
      final report = Map<String, dynamic>.from(data['p3_performance'] as Map);
      await _write(
        directory,
        'launcher_metadata.json',
        await _launcherMetadata(directory),
      );
      final traces = <String, String>{};
      for (final entry in data.entries) {
        if (entry.key.startsWith('p3_trace_')) {
          final filename = '${entry.key}.timeline.json';
          await _write(directory, filename, entry.value);
          traces[entry.key] = filename;
        }
      }
      final rawFrames = <String, Object?>{};
      final rawMemory = <String, Object?>{};
      final scenarios = <Map<String, dynamic>>[];
      for (final value in (report['scenarios'] as List? ?? <Object>[])) {
        final scenario = Map<String, dynamic>.from(value as Map);
        final id = scenario['id'] as String;
        rawFrames[id] = scenario.remove('raw_frame_timings');
        rawMemory[id] = scenario.remove('rss_samples');
        scenario['raw_frame_file'] = 'p3_frame_samples.json';
        scenario['raw_memory_file'] = 'p3_memory_samples.json';
        scenario['timeline_file'] = traces[scenario['trace_report_key']];
        scenarios.add(scenario);
      }
      report['scenarios'] = scenarios;
      report['driver'] = <String, Object?>{
        'written_at_utc': DateTime.now().toUtc().toIso8601String(),
        'host_os': Platform.operatingSystem,
        'host_os_version': Platform.operatingSystemVersion,
        'source_revision': await _command('git', <String>['rev-parse', 'HEAD']),
        'source_worktree_status': await _command('git', <String>[
          'status',
          '--porcelain',
        ]),
        'device_id_requested': Platform.environment['P3_PERF_DEVICE_ID'],
        'launcher_metadata_file': 'launcher_metadata.json',
        'launch_log': 'launch.log',
        'launcher_notes': 'Files named here are created by tool/run_p3_profile.sh; direct flutter drive users should save the exact command, Flutter version and engine launch log themselves.',
      };
      await _write(directory, 'p3_frame_samples.json', rawFrames);
      await _write(directory, 'p3_memory_samples.json', rawMemory);
      await _write(directory, 'p3_performance.json', report);
      // ignore: avoid_print
      print('P3 profile evidence written to ${directory.absolute.path}');
    },
  );
}

Future<String?> _command(String executable, List<String> arguments) async {
  try {
    final result = await Process.run(executable, arguments);
    return result.exitCode == 0 ? result.stdout.toString().trim() : null;
  } on ProcessException {
    return null;
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
    File('${directory.path}/$name')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(data))
        .then((_) {});

Future<void> _finalize(Directory directory, int driverExitCode) async {
  final file = File('${directory.path}/p3_performance.json');
  final report = await file.exists()
      ? Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map)
      : <String, dynamic>{'status': 'failed_missing_report_data'};
  report['workload_phase_status'] = report['status'];
  report['integration_driver_exit_code'] = driverExitCode;
  final scenarios = report['scenarios'] as List? ?? <Object>[];
  final complete =
      driverExitCode == 0 &&
      scenarios.length == 7 &&
      scenarios.every((value) => (value as Map)['status'] == 'complete');
  report['status'] = complete ? 'complete' : 'failed';
  report['finalized_at_utc'] = DateTime.now().toUtc().toIso8601String();
  if (!complete && driverExitCode != 0) {
    report['run_failure_note'] = 'The integration driver failed; inspect launch.log even if individual workloads captured valid samples. This run is not accepted as a complete profile run.';
  }
  await _write(directory, 'p3_performance.json', report);
  exitCode = complete ? 0 : (driverExitCode == 0 ? 1 : driverExitCode);
}
