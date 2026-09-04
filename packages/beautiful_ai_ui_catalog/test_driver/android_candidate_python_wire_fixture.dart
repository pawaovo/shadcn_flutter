import 'dart:convert';
import 'dart:io';

import '../integration_test/driver/android_candidate_host.dart';
import '../integration_test/driver/catalog_android_candidate_driver.dart'
    show AndroidCandidateDriverStage;

/// Real Dart HTTP client and production request builders against the Python
/// Runner routes. The Python harness supplies explicit VM/native HTTP fixtures;
/// this executable never represents their responses as application acceptance.
Future<void> main(List<String> arguments) async {
  final calls = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'scope': 'production Dart request builders and actual Python Runner routes',
    'vm_and_native_peers': 'explicit HTTP fixtures only',
    'application_acceptance': 'not_exercised',
    'status': 'failed',
    'calls': calls,
  };
  AndroidCandidateHost? host;
  try {
    if (arguments.length != 1) {
      throw ArgumentError('Provide one wire fixture configuration JSON path.');
    }
    final configuration = Map<String, Object?>.from(
      jsonDecode(await File(arguments.single).readAsString()) as Map,
    );
    String setting(String key) {
      final value = configuration[key];
      if (value is! String || value.isEmpty) {
        throw ArgumentError('A nonempty string $key is required.');
      }
      return value;
    }

    final mode = setting('mode');
    if (!<String>['success', 'old_nested', 'wrong_stage'].contains(mode)) {
      throw ArgumentError('Unknown wire fixture mode: $mode');
    }
    report['mode'] = mode;
    final uri = Uri.parse(setting('host_url'));
    if (uri.scheme != 'http' ||
        uri.host != '127.0.0.1' ||
        !uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError(
        'The fixture requires an explicit loopback HTTP peer.',
      );
    }
    final connected = AndroidCandidateHost(uri, setting('token'));
    host = connected;
    final runNonce = setting('nonce');
    final sourceSha = setting('source_sha');
    final stage = AndroidCandidateDriverStage(
      setting('stage_id'),
      setting('stage_nonce'),
    );
    final candidateId = setting('candidate_id');
    final leaseId = setting('lease_id');

    Future<Map<String, Object?>> request(
      String path,
      Map<String, Object?> body,
      Duration timeout,
    ) async {
      final call = <String, Object?>{'path': path, 'body': body};
      calls.add(call);
      try {
        final response = await connected.request(
          'POST',
          path,
          body,
          timeout: timeout,
        );
        call['response'] = response;
        return response;
      } catch (error) {
        call['error'] = '$error';
        rethrow;
      }
    }

    stage.beginAttempt();
    final prepared = await request(
      '/native/prepare',
      stage.requestBody(runNonce, sourceSha),
      const Duration(seconds: 30),
    );
    stage.verify(prepared);
    if (prepared['ok'] != true) {
      throw StateError('The stage helper did not prepare.');
    }
    final candidate = await request(
      '/native/inspect',
      stage.requestBody(runNonce, sourceSha),
      const Duration(seconds: 5),
    );
    stage.verify(candidate);
    if (candidate['candidate_id'] != candidateId) {
      throw StateError('The actual inspection returned a different candidate.');
    }

    final clickBody = mode == 'old_nested'
        ? <String, Object?>{
            ...stage.requestBody(runNonce, sourceSha),
            'candidate': <String, Object?>{'candidate_id': candidateId},
            'claim': <String, Object?>{'lease_id': leaseId},
          }
        : stage.clickBody(
            runNonce,
            sourceSha,
            candidateId: candidateId,
            leaseId: leaseId,
          );
    if (mode == 'wrong_stage') {
      clickBody['stage_nonce'] =
          '${stage.nonce.startsWith('0') ? '1' : '0'}${stage.nonce.substring(1)}';
    }
    Map<String, Object?> click;
    try {
      click = await request(
        '/native/click',
        clickBody,
        const Duration(seconds: 3),
      );
    } on StateError catch (error) {
      if (mode == 'success' ||
          !error.toString().contains(
            'Native supervisor /native/click failed (409):',
          )) {
        rethrow;
      }
      report.addAll(<String, Object?>{
        'status': 'passed',
        'expected_rejection': true,
        'outcome': 'click_rejected_409',
        'rejection': '$error',
      });
      return;
    }
    if (mode != 'success') {
      throw StateError(
        'The real Python route accepted a rejected-shape fixture.',
      );
    }
    stage.acceptClick(click, candidateId: candidateId);
    final finished = await request(
      '/native/finish',
      stage.requestBody(runNonce, sourceSha),
      const Duration(seconds: 40),
    );
    stage.verify(finished);
    if (finished['native_drained'] != true ||
        finished['helper_stopped'] != true ||
        finished['cleanup_verified'] != true) {
      throw StateError('The Python route did not confirm stage cleanup.');
    }
    report.addAll(<String, Object?>{
      'status': 'passed',
      'expected_rejection': false,
      'outcome': 'flat_request_completed',
    });
  } catch (error, stack) {
    report['error'] = '$error';
    report['stack'] = '$stack';
    exitCode = 1;
  } finally {
    host?.close();
    stdout.writeln(jsonEncode(report));
  }
}
