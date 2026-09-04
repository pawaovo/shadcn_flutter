import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../integration_test/driver/android_candidate_host.dart';

/// Real HTTP framing only. No VM, Android, native input or acceptance is mocked
/// into a successful application result by this standalone host regression.
Future<void> main() async {
  const token = 'fixture-token';
  final requests = <Map<String, Object?>>[
    <String, Object?>{
      'method': 'POST',
      'path': '/attach',
      'body': <String, Object?>{
        'vm_service_url': 'http://127.0.0.1:12345/token/',
        'nonce': 'fixture-nonce',
        'note': '你',
      },
    },
    <String, Object?>{'method': 'GET', 'path': '/native/inspect', 'body': null},
    <String, Object?>{
      'method': 'POST',
      'path': '/native/click',
      'body': <String, Object?>{
        'candidate': <String, Object?>{'candidate_id': 'exact-candidate'},
        'claim': <String, Object?>{'lease_id': 'exact-lease'},
        'note': '你🙂',
      },
    },
    <String, Object?>{
      'method': 'POST',
      'path': '/abort',
      'body': <String, Object?>{
        'error': 'ASCII: preserve the original failure',
      },
    },
  ];
  final observed = <Map<String, Object?>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final client = AndroidCandidateHost(
    Uri.parse('http://127.0.0.1:${server.port}'),
    token,
  );
  final completed = Completer<void>();
  final subscription = server.listen((incoming) async {
    try {
      final expected = requests[observed.length];
      final expectedBody = expected['body'] as Map<String, Object?>?;
      final bytes = await incoming.fold<List<int>>(
        <int>[],
        (value, part) => value..addAll(part),
      );
      final expectedBytes = expectedBody == null
          ? <int>[]
          : utf8.encode(jsonEncode(expectedBody));
      final record = <String, Object?>{
        'method': incoming.method,
        'path': incoming.uri.path,
        'authorization': incoming.headers.value(
          HttpHeaders.authorizationHeader,
        ),
        'content_length': incoming.contentLength,
        'received_bytes': bytes.length,
        'transfer_encoding': incoming.headers.value(
          HttpHeaders.transferEncodingHeader,
        ),
        'expected_bytes': expectedBytes.length,
        'decoded_body': utf8.decode(bytes),
      };
      observed.add(record);
      final framing = expectedBody == null
          ? bytes.isEmpty
          : incoming.contentLength == expectedBytes.length &&
                incoming.headers.value(HttpHeaders.transferEncodingHeader) ==
                    null;
      final sameBytes =
          bytes.length == expectedBytes.length &&
          List<int>.generate(
            bytes.length,
            (index) => index,
          ).every((index) => bytes[index] == expectedBytes[index]);
      final passed =
          framing &&
          sameBytes &&
          incoming.method == expected['method'] &&
          incoming.uri.path == expected['path'] &&
          incoming.headers.value(HttpHeaders.authorizationHeader) ==
              'Bearer $token';
      incoming.response.statusCode = passed ? 200 : 400;
      incoming.response.headers.contentType = ContentType.json;
      incoming.response.write(
        jsonEncode(<String, Object?>{
          'ok': passed,
          if (!passed)
            'error': 'Invalid protocol Content-Length, method, auth or bytes',
          'observed': record,
        }),
      );
      await incoming.response.close();
      if (observed.length == requests.length && !completed.isCompleted) {
        completed.complete();
      }
    } catch (error, stack) {
      if (!completed.isCompleted) completed.completeError(error, stack);
    }
  });
  // Attach an error handler before issuing requests, including on the red run.
  final observerResult = completed.future.then<Object?>(
    (_) => null,
    onError: (Object error, StackTrace stack) => error,
  );
  try {
    for (final request in requests) {
      final result = await client.request(
        request['method']! as String,
        request['path']! as String,
        request['body'] as Map<String, Object?>?,
        timeout: const Duration(seconds: 2),
      );
      if (result['ok'] != true) {
        throw StateError('The actual HTTP peer rejected the request.');
      }
    }
    final observerError = await observerResult.timeout(
      const Duration(seconds: 2),
    );
    if (observerError != null) throw observerError;
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'scope':
            'actual Dart host client against a strict loopback HTTP server',
        'status': 'passed',
        'requests': observed,
      }),
    );
  } finally {
    client.close();
    await subscription.cancel();
    await server.close(force: true);
  }
}
