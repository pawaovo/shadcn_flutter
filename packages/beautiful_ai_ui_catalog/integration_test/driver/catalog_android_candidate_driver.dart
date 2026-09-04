// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

import '../support/android_candidate_protocol.dart';

/// Coordinates public VM observations and one independently checked native
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
  _NativeHost? host;
  Future<void>? responseTask;
  Response? response;
  Object? responseError;
  var acceptConnection = true;
  var active = true;
  var attempted = false;
  var attached = false;
  String? issuedLeaseId;
  final nonce = Platform.environment['ANDROID_CANDIDATE_NONCE'] ?? '';
  final sourceSha = Platform.environment['ANDROID_CANDIDATE_SOURCE_SHA'] ?? '';

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
    if (state['protocol_version'] != 1 ||
        state['nonce'] != nonce ||
        state['source_sha'] != sourceSha) {
      throw StateError(
        'The VM target does not match this exact run and source.',
      );
    }
    return state;
  }

  try {
    if (!RegExp(r'^[a-f0-9]{32,64}$').hasMatch(nonce) ||
        !RegExp(r'^[a-f0-9]{40}$').hasMatch(sourceSha)) {
      throw StateError('A fresh nonce and exact source SHA are required.');
    }
    report.addAll(<String, Object?>{'nonce': nonce, 'source_sha': sourceSha});
    host = _NativeHost.fromEnvironment();
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
      if (state['stage'] == 'failed') throw StateError('${state['failure']}');
      if (response != null) {
        if (!response!.allTestsPassed ||
            state['stage'] != 'passed' ||
            report['native_click_count'] != 1 ||
            state['native_click_acknowledged'] != true ||
            state['native_drained'] != true ||
            state['send_activation_checked'] != true) {
          throw StateError(
            'Original journey, native click, and protocol did not all pass.',
          );
        }
        report['final_state'] = state;
        report['status'] = 'passed';
        print(
          'All tests passed. Original complete Catalog journey with one real Android IME candidate.',
        );
        break;
      }
      if (state['stage'] == 'awaiting_candidate') {
        if (attempted || !active) {
          throw StateError('A repeated native candidate action was requested.');
        }
        attempted = true;
        final candidate = await host.request(
          'GET',
          '/native/inspect',
          null,
          timeout: bounded(const Duration(seconds: 5)),
        );
        report['native_candidate'] = candidate;
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
          values: <String, String>{'candidate_id': candidateId},
        );
        report['native_claim'] = claim;
        issuedLeaseId = claim['lease_id'] as String?;
        if (!active ||
            claimClock.elapsedMilliseconds > 500 ||
            claim['stage'] != 'action_claimed' ||
            claim['can_click'] != true ||
            claim['candidate_id'] != candidateId ||
            claim['lease_id'] is! String ||
            (claim['lease_remaining_ms']! as num) < 1500) {
          throw StateError('The candidate action claim is stale or invalid.');
        }
        // The host independently rechecks live VM state. Device-side deadline
        // checks do not bound a blocking public UiAutomation call. Success also
        // requires an actual native return acknowledgment; timeout is not drain.
        final click = await host.request(
          'POST',
          '/native/click',
          <String, Object?>{
            'nonce': nonce,
            'source_sha': sourceSha,
            'candidate': candidate,
            'claim': claim,
          },
          timeout: bounded(const Duration(seconds: 3)),
        );
        report['native_click'] = click;
        if (!active || response != null) {
          throw StateError(
            'The original journey ended during the native click.',
          );
        }
        final clicked = click['clicked'] == true;
        if (clicked) report['native_click_count'] = 1;
        await extension(
          'result',
          values: <String, String>{
            'candidate_id': candidateId,
            'lease_id': claim['lease_id']! as String,
            'clicked': '$clicked',
            'native_drained': '${click['native_drained'] == true}',
            if (!clicked) 'error': '${click['error']}',
          },
        );
        if (!clicked) {
          throw StateError('Native candidate failed: ${click['error']}');
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
    if (driver != null) {
      try {
        final aborted = await extension(
          'abort',
          values: <String, String>{'error': '$error'},
          cleanup: true,
        );
        report['vm_abort'] = aborted;
        issuedLeaseId ??= aborted['lease_id'] as String?;
      } catch (cleanupError) {
        cleanupErrors.add('VM abort: $cleanupError');
      }
    }
    if (host != null && attached) {
      try {
        final aborted = await host.request('POST', '/abort', <String, Object?>{
          'nonce': nonce,
          'source_sha': sourceSha,
          'error': '$error',
        }, timeout: const Duration(seconds: 40));
        report['native_abort'] = aborted;
        if (aborted['native_drained'] == true) {
          report['native_drain_confirmed'] = true;
          // A lost claim response must not lose the actual lease identity.
          // Query the same VM; never invent a lease or fake a drain receipt.
          if (issuedLeaseId == null && driver != null) {
            final current = await extension('state', cleanup: true);
            issuedLeaseId = current['lease_id'] as String?;
          }
          if (issuedLeaseId != null) {
            report['vm_native_drained'] = await extension(
              'drained',
              values: <String, String>{'lease_id': issuedLeaseId},
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

final class _NativeHost {
  _NativeHost(this.base, this.token) {
    client.findProxy = (_) => 'DIRECT';
    client.connectionTimeout = const Duration(seconds: 2);
  }

  factory _NativeHost.fromEnvironment() {
    final base = Uri.parse(
      Platform.environment['ANDROID_CANDIDATE_HOST_URL'] ?? '',
    );
    final token = Platform.environment['ANDROID_CANDIDATE_HOST_TOKEN'] ?? '';
    if (base.scheme != 'http' ||
        base.host != '127.0.0.1' ||
        !base.hasPort ||
        base.userInfo.isNotEmpty ||
        (base.path.isNotEmpty && base.path != '/') ||
        base.hasQuery ||
        base.hasFragment ||
        token.isEmpty) {
      throw StateError(
        'The native supervisor must be an authenticated loopback HTTP endpoint.',
      );
    }
    return _NativeHost(base, token);
  }

  final Uri base;
  final String token;
  final HttpClient client = HttpClient();

  Future<Map<String, Object?>> request(
    String method,
    String path,
    Map<String, Object?>? body, {
    required Duration timeout,
  }) async {
    HttpClientRequest? outgoing;
    try {
      return await (() async {
        outgoing = await client.openUrl(method, base.resolve(path));
        outgoing!.followRedirects = false;
        outgoing!.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        if (body != null) {
          outgoing!.headers.contentType = ContentType.json;
          outgoing!.write(jsonEncode(body));
        }
        final response = await outgoing!.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 1024 * 1024) {
            throw StateError('Native response is too large.');
          }
        }
        final result = Map<String, Object?>.from(
          jsonDecode(utf8.decode(bytes)) as Map,
        );
        if (response.statusCode != 200) {
          throw StateError(
            'Native supervisor $path failed (${response.statusCode}): $result',
          );
        }
        return result;
      })().timeout(timeout);
    } catch (_) {
      outgoing?.abort();
      rethrow;
    }
  }

  void close() => client.close(force: true);
}
