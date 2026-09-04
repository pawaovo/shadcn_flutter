// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

import '../support/android_candidate_protocol.dart';
import 'android_candidate_host.dart';

/// Coordinates public VM observations and three independently checked native
/// action. requestData remains the authority for the original full journey.
Future<void> main() async {
  final output = Directory(
    Platform.environment['BEAUTIFUL_INPUT_EVIDENCE'] ??
        'build/android-candidate',
  )..createSync(recursive: true);
  final clock = Stopwatch()..start();
  final observations = <Map<String, Object?>>[];
  final cleanupErrors = <String>[];
  final report = <String, Object?>{
    'status': 'started',
    'vm_observations': observations,
    'cleanup_errors': cleanupErrors,
    'native_click_count': 0,
  };
  FlutterDriver? driver;
  AndroidCandidateHost? host;
  Future<void>? responseTask;
  Response? response;
  Object? responseError;
  var acceptConnection = true;
  var active = true;
  var attached = false;
  final nonce = Platform.environment['ANDROID_CANDIDATE_NONCE'] ?? '';
  final sourceSha = Platform.environment['ANDROID_CANDIDATE_SOURCE_SHA'] ?? '';
  final stages = AndroidCandidateDriverStages(nonce, sourceSha);
  AndroidCandidateDriverStage? currentStage;
  AndroidCandidateDriverStage? nativeStage;
  report['stages'] = stages.records;

  Duration bounded(Duration limit) {
    final remaining = const Duration(seconds: 600) - clock.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException(
        'Original full journey exceeded its driver deadline.',
      );
    }
    return remaining < limit ? remaining : limit;
  }

  Future<Map<String, Object?>> extension(
    String action, {
    Map<String, String> values = const <String, String>{},
    AndroidCandidateDriverStage? binding,
    bool cleanup = false,
  }) async {
    final result = await driver!.serviceClient
        .callServiceExtension(
          AndroidCandidateProtocol.extensionName,
          isolateId: driver.appIsolate.id,
          args: <String, String>{
            'action': action,
            'nonce': nonce,
            'source_sha': sourceSha,
            if (binding != null) ...binding.identity,
            ...values,
          },
        )
        .timeout(
          cleanup
              ? const Duration(seconds: 2)
              : bounded(const Duration(seconds: 2)),
        );
    final state = Map<String, Object?>.from(result.json!);
    observations.add(<String, Object?>{
      'driver_elapsed_ms': clock.elapsedMilliseconds,
      'action': action,
      'response': state,
    });
    if (state['protocol_version'] != 2 ||
        state['nonce'] != nonce ||
        state['source_sha'] != sourceSha) {
      throw StateError(
        'The VM target does not match this exact run and source.',
      );
    }
    binding?.verify(state);
    return state;
  }

  try {
    if (!RegExp(r'^[a-f0-9]{32,64}$').hasMatch(nonce) ||
        !RegExp(r'^[a-f0-9]{40}$').hasMatch(sourceSha)) {
      throw StateError('A fresh nonce and exact source SHA are required.');
    }
    report.addAll(<String, Object?>{'nonce': nonce, 'source_sha': sourceSha});
    host = AndroidCandidateHost.fromEnvironment();
    final connection = FlutterDriver.connect();
    // FlutterDriver.connect's own slow-operation timeout only warns. This
    // outer deadline rejects the run and closes any connection arriving late.
    final observedConnection = connection.then((value) async {
      if (!acceptConnection) {
        try {
          await value.close().timeout(const Duration(seconds: 3));
        } catch (error) {
          cleanupErrors.add('late VM connection close: $error');
        }
      }
      return value;
    });
    try {
      driver = await observedConnection.timeout(
        bounded(const Duration(seconds: 30)),
      );
    } catch (_) {
      acceptConnection = false;
      rethrow;
    }

    // Install error handling immediately. Native integration_test requestData
    // completes only after tearDownAll and cannot serve as a stage RPC.
    responseTask = driver
        .requestData(null, timeout: bounded(const Duration(seconds: 570)))
        .then<void>(
          (raw) {
            report['request_data_raw'] = raw;
            try {
              response = Response.fromJson(raw);
              report['all_tests_passed'] = response!.allTestsPassed;
              report['integration_data'] = response!.data;
              if (!response!.allTestsPassed) {
                responseError = StateError(response!.formattedFailureDetails);
                active = false;
              }
            } catch (error) {
              responseError = error;
              active = false;
            }
          },
          onError: (Object error, StackTrace stack) {
            responseError = error;
            report['request_data_error'] = '$error';
            report['request_data_stack'] = '$stack';
            active = false;
          },
        );
    final vm = await driver.serviceClient.getVM().timeout(
      bounded(const Duration(seconds: 2)),
    );
    if (vm.pid == null || driver.appIsolate.id == null) {
      throw StateError('The actual VM PID and app isolate are required.');
    }
    await extension('state');
    report['attach'] = await host.request('POST', '/attach', <String, Object?>{
      'vm_service_url': Platform.environment['VM_SERVICE_URL'],
      'isolate_id': driver.appIsolate.id,
      'vm_pid': vm.pid,
      'nonce': nonce,
      'source_sha': sourceSha,
    }, timeout: bounded(const Duration(seconds: 5)));
    attached = true;

    while (true) {
      bounded(const Duration(seconds: 1));
      if (responseError != null) throw responseError!;
      final state = await extension('state');
      currentStage = stages.observe(state);
      if (state['stage'] == 'failed' || state['journey_status'] == 'failed') {
        throw StateError('${state['failure']}');
      }
      for (final stage in stages.completedWithoutFinish) {
        // Preserve the original final helper lifetime through the complete
        // integration_test response. Failed runs use the owned abort/drain path.
        if (stage.id == AndroidCandidateDriverStages.ids.last &&
            response == null) {
          continue;
        }
        final finished = await host.request(
          'POST',
          '/native/finish',
          <String, Object?>{
            'nonce': nonce,
            'source_sha': sourceSha,
            ...stage.identity,
          },
          timeout: bounded(const Duration(seconds: 40)),
        );
        stage.acceptFinish(finished);
        if (identical(nativeStage, stage)) nativeStage = null;
      }
      if (response != null) {
        stages.requireComplete(state, allTestsPassed: response!.allTestsPassed);
        report['final_state'] = state;
        report['native_click_count'] = stages.clickCount;
        report['status'] = 'passed';
        print(
          'All tests passed. Original complete Catalog journey with three ordered Android IME candidates.',
        );
        break;
      }
      if (state['stage'] == 'awaiting_candidate') {
        if (!active || currentStage == null) {
          throw StateError('No active candidate stage is available.');
        }
        final stage = currentStage;
        stages.requirePredecessorsFinished(stage);
        stage.beginAttempt();
        nativeStage = stage;
        final prepared = await host.request(
          'POST',
          '/native/prepare',
          <String, Object?>{
            'nonce': nonce,
            'source_sha': sourceSha,
            ...stage.identity,
          },
          timeout: bounded(const Duration(seconds: 30)),
        );
        stage.verify(prepared);
        stage.record['native_prepare'] = prepared;
        if (prepared['ok'] != true || !active || response != null) {
          throw StateError(
            'The stage helper did not prepare during an active journey.',
          );
        }
        final candidate = await host.request(
          'POST',
          '/native/inspect',
          <String, Object?>{
            'nonce': nonce,
            'source_sha': sourceSha,
            ...stage.identity,
          },
          timeout: bounded(const Duration(seconds: 5)),
        );
        stage.verify(candidate);
        stage.record['native_candidate'] = candidate;
        if (!active || response != null) {
          throw StateError(
            'The original journey ended during native inspection.',
          );
        }
        final candidateId = candidate['candidate_id'];
        if (candidateId is! String || candidateId.isEmpty) {
          throw StateError(
            'Native inspection did not provide a candidate identity.',
          );
        }
        final claimClock = Stopwatch()..start();
        final claim = await extension(
          'claim',
          binding: stage,
          values: <String, String>{'candidate_id': candidateId},
        );
        stage.record['native_claim'] = claim;
        stage.leaseId = claim['lease_id'] as String?;
        if (!active ||
            claimClock.elapsedMilliseconds > 500 ||
            claim['stage'] != 'action_claimed' ||
            claim['can_click'] != true ||
            claim['candidate_id'] != candidateId ||
            stage.leaseId == null ||
            stage.leaseId!.isEmpty ||
            claim['lease_remaining_ms'] is! num ||
            (claim['lease_remaining_ms']! as num) < 1500) {
          throw StateError('The candidate action claim is stale or invalid.');
        }
        // A matching native return is required. Neither the device ticket nor
        // a host HTTP timeout proves that Android finished delivering input.
        final click = await host.request(
          'POST',
          '/native/click',
          <String, Object?>{
            'nonce': nonce,
            'source_sha': sourceSha,
            ...stage.identity,
            'candidate_id': candidateId,
            'lease_id': stage.leaseId,
          },
          timeout: bounded(const Duration(seconds: 3)),
        );
        stage.verify(click);
        stage.record['native_click'] = click;
        if (!active || response != null) {
          throw StateError(
            'The original journey ended during the native click.',
          );
        }
        stage.acceptClick(click, candidateId: candidateId);
        report['native_click_count'] = stages.clickCount;
        final acknowledged = await extension(
          'result',
          binding: stage,
          values: <String, String>{
            'candidate_id': candidateId,
            'lease_id': stage.leaseId!,
            'clicked': 'true',
            'native_drained': 'true',
          },
        );
        stage.record['result_acknowledgement'] = acknowledged;
        if (acknowledged['stage'] != 'awaiting_commit' ||
            acknowledged['native_click_acknowledged'] != true ||
            acknowledged['native_drained'] != true) {
          throw StateError(
            'The VM did not acknowledge the exact native stage result.',
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  } catch (error, stack) {
    active = false;
    report.addAll(<String, Object?>{
      'status': 'failed',
      'error': '$error',
      'stack': '$stack',
    });
    stderr.writeln(error);
    exitCode = 1;
    // Discover the actual stage even when a claim response was lost. Never
    // reuse the preceding stage's lease to drain a different native action.
    if (driver != null) {
      try {
        final discovered = await extension('state', cleanup: true);
        currentStage = stages.discoverForCleanup(discovered);
      } catch (cleanupError) {
        cleanupErrors.add('VM cleanup stage discovery: $cleanupError');
      }
      if (currentStage != null) {
        try {
          final aborted = await extension(
            'abort',
            binding: currentStage,
            values: <String, String>{'error': '$error'},
            cleanup: true,
          );
          report['vm_abort'] = aborted;
          currentStage.leaseId ??= aborted['lease_id'] as String?;
        } catch (cleanupError) {
          cleanupErrors.add('VM abort: $cleanupError');
        }
      }
    }
    if (host != null && attached && nativeStage != null) {
      try {
        final stage = nativeStage;
        final aborted = await host.request('POST', '/abort', <String, Object?>{
          'nonce': nonce,
          'source_sha': sourceSha,
          ...stage.identity,
          'reason': '$error',
        }, timeout: const Duration(seconds: 40));
        stage.verify(aborted);
        report['native_abort'] = aborted;
        if (aborted['native_drained'] == true) {
          report['native_drain_confirmed'] = true;
          final matchesCurrent = identical(stage, currentStage);
          if (matchesCurrent && stage.leaseId == null && driver != null) {
            final current = await extension(
              'state',
              binding: stage,
              cleanup: true,
            );
            stage.leaseId = current['lease_id'] as String?;
          }
          if (matchesCurrent && stage.leaseId != null) {
            report['vm_native_drained'] = await extension(
              'drained',
              binding: stage,
              values: <String, String>{'lease_id': stage.leaseId!},
              cleanup: true,
            );
          }
        } else {
          report['unverified_native_drain'] = true;
          cleanupErrors.add(
            'Native call drain was not confirmed; outer owned teardown is required.',
          );
        }
      } catch (cleanupError) {
        report['unverified_native_drain'] = true;
        cleanupErrors.add('native abort: $cleanupError');
      }
    }
    if (responseTask != null) {
      try {
        await responseTask.timeout(const Duration(seconds: 10));
      } catch (cleanupError) {
        cleanupErrors.add('original failure response: $cleanupError');
      }
    }
  } finally {
    acceptConnection = false;
    active = false;
    if (driver != null) {
      try {
        await driver.close().timeout(const Duration(seconds: 3));
      } catch (error) {
        cleanupErrors.add('VM close: $error');
      }
    }
    host?.close();
    report['elapsed_ms'] = clock.elapsedMilliseconds;
    if (cleanupErrors.isNotEmpty && report['status'] == 'passed') {
      report['status'] = 'failed';
      report['error'] = 'Cleanup did not complete without errors.';
      exitCode = 1;
    }
    final raw = report['request_data_raw'];
    if (raw is String) {
      await File('${output.path}/request-data.json').writeAsString(raw);
    }
    await File('${output.path}/driver-summary.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  }
}

/// Host evidence bookkeeping only: these checks cannot create native input or
/// turn fixture responses into application acceptance.
final class AndroidCandidateDriverStages {
  AndroidCandidateDriverStages(this.runNonce, this.sourceSha);

  static const ids = <String>['chat_send', 'prompt_command', 'prompt_send'];
  static const texts = <String>[
    'Check cone inventory',
    '/rest',
    'Prepare the seasonal restock',
  ];
  static const candidates = <String>['inventory', 'rest', 'restock'];
  static const composingBases = <int>[11, 1, 21];
  static const composingExtents = <int>[20, 5, 28];
  final String runNonce;
  final String sourceSha;
  final records = <Map<String, Object?>>[];
  final _stages = <String, AndroidCandidateDriverStage>{};
  int _completedCount = 0;

  int get clickCount => _stages.values.where((stage) => stage.clicked).length;
  Iterable<AndroidCandidateDriverStage> get completedWithoutFinish => ids
      .take(_completedCount)
      .map((id) => _stages[id]!)
      .where((stage) => !stage.finished);

  void _verifyRun(Map<String, Object?> state) {
    if (state['protocol_version'] != 2 ||
        state['nonce'] != runNonce ||
        state['run_nonce'] != runNonce ||
        state['source_sha'] != sourceSha) {
      throw StateError(
        'The VM ledger belongs to a different protocol, run or source.',
      );
    }
  }

  AndroidCandidateDriverStage? _bind(Map<String, Object?> state) {
    _verifyRun(state);
    final id = state['stage_id'];
    final nonce = state['stage_nonce'];
    if (id == null &&
        nonce == null &&
        _stages.isEmpty &&
        state['stage'] == 'preparing') {
      return null;
    }
    final index = ids.indexOf(id is String ? id : '');
    if (index < 0 ||
        nonce is! String ||
        !RegExp(r'^[a-f0-9]{32,64}$').hasMatch(nonce)) {
      throw StateError(
        'The VM returned an unknown stage or invalid stage nonce.',
      );
    }
    if (state['expected_text'] != texts[index] ||
        state['candidate_text'] != candidates[index] ||
        state['composing_base'] != composingBases[index] ||
        state['composing_extent'] != composingExtents[index] ||
        state['selection_offset'] != composingExtents[index]) {
      throw StateError('The fixed candidate stage text changed.');
    }
    final known = _stages[id];
    if (known != null) {
      known.verify(state);
      return known;
    }
    if (index != _stages.length || nonce == runNonce ||
        _stages.values.any((stage) => stage.nonce == nonce)) {
      throw StateError(
        'Candidate stages were reordered or reused a stage nonce.',
      );
    }
    final stage = AndroidCandidateDriverStage(id! as String, nonce);
    _stages[stage.id] = stage;
    records.add(stage.record);
    return stage;
  }

  AndroidCandidateDriverStage? observe(Map<String, Object?> state) {
    final stage = _bind(state);
    final completed = state['completed_stage_ids'];
    final results = state['stage_results'];
    if (completed is! List ||
        results is! List ||
        completed.length != results.length ||
        completed.length > ids.length ||
        completed.length < _completedCount) {
      throw StateError(
        'The VM completed-stage ledger is missing or moved backwards.',
      );
    }
    for (var index = 0; index < completed.length; index++) {
      final result = results[index];
      final known = _stages[ids[index]];
      if (completed[index] != ids[index] ||
          result is! Map ||
          known == null ||
          !known.clicked) {
        throw StateError(
          'A stage completed without its ordered native click receipt.',
        );
      }
      final receipt = Map<String, Object?>.from(result);
      known.verify(receipt);
      if (receipt['stage'] != 'stage_done' ||
          receipt['original_action_passed'] != true ||
          receipt['native_click_acknowledged'] != true ||
          receipt['native_drained'] != true ||
          receipt['send_activation_checked'] != true ||
          receipt['lease_id'] != known.leaseId ||
          receipt['candidate_id'] != known.candidateId) {
        throw StateError(
          'A stage is missing its original action, activation or drain evidence.',
        );
      }
      // The actual VM record includes a live elapsed/deadline sample. Validate
      // its immutable identities and predicates, without freezing that clock.
      known.record['vm_original_action'] ??= receipt;
    }
    _completedCount = completed.length;
    if (stage != null) {
      final index = ids.indexOf(stage.id);
      final expectedIndex = state['stage'] == 'stage_done'
          ? _completedCount - 1
          : _completedCount;
      if (index != expectedIndex && state['stage'] != 'failed') {
        throw StateError(
          'The live stage does not follow the completed-stage ledger.',
        );
      }
    }
    return stage;
  }

  AndroidCandidateDriverStage? discoverForCleanup(Map<String, Object?> state) =>
      _bind(state);

  void requirePredecessorsFinished(AndroidCandidateDriverStage stage) {
    final index = ids.indexOf(stage.id);
    if (_completedCount != index ||
        ids.take(index).any((id) => _stages[id]?.finished != true)) {
      throw StateError(
        'The previous original action and native helper have not finished.',
      );
    }
  }

  void requireComplete(
    Map<String, Object?> state, {
    required bool allTestsPassed,
  }) {
    observe(state);
    if (!allTestsPassed ||
        state['journey_status'] != 'passed' ||
        _completedCount != ids.length ||
        clickCount != ids.length ||
        _stages.values.any((stage) => !stage.finished)) {
      throw StateError(
        'The complete original journey and all three native stages did not pass.',
      );
    }
  }
}

final class AndroidCandidateDriverStage {
  AndroidCandidateDriverStage(this.id, this.nonce)
    : record = <String, Object?>{
        'stage_id': id,
        'stage_nonce': nonce,
        'native_click_count': 0,
      };

  final String id;
  final String nonce;
  final Map<String, Object?> record;
  bool _attempted = false;
  bool clicked = false;
  bool finished = false;
  String? leaseId;
  String? candidateId;
  Map<String, String> get identity => <String, String>{
    'stage_id': id,
    'stage_nonce': nonce,
  };

  void verify(Map<String, Object?> response) {
    if (response['stage_id'] != id || response['stage_nonce'] != nonce) {
      throw StateError(
        'A late or mismatched response belongs to another candidate stage.',
      );
    }
  }

  void beginAttempt() {
    if (_attempted) {
      throw StateError('A stage candidate action may never be retried.');
    }
    _attempted = true;
    record['attempt_started'] = true;
  }

  void acceptClick(
    Map<String, Object?> response, {
    required String candidateId,
  }) {
    verify(response);
    if (!_attempted ||
        clicked ||
        response['clicked'] != true ||
        response['native_drained'] != true ||
        response['used_candidate_id'] != candidateId) {
      throw StateError(
        'The native stage did not return its unique matching click and drain receipt.',
      );
    }
    clicked = true;
    this.candidateId = candidateId;
    record['native_click_count'] = 1;
    record['native_click'] = response;
  }

  void acceptFinish(Map<String, Object?> response) {
    verify(response);
    if (!clicked ||
        record['vm_original_action'] == null ||
        finished ||
        response['native_drained'] != true ||
        response['helper_stopped'] != true ||
        response['cleanup_verified'] != true) {
      throw StateError(
        'The completed original action has no verified native helper cleanup.',
      );
    }
    finished = true;
    record['native_finish'] = response;
  }
}
