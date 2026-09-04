import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../test_driver/p3_performance_driver.dart';
import '../test_driver/profile_driver_adapter.dart';

Map<String, dynamic> _reportData() => <String, dynamic>{
  'p3_performance': <String, dynamic>{
    'status': 'measuring',
    'scenarios': <Object?>[
      <String, Object?>{
        'id': 'prompt',
        'status': 'complete',
        'raw_frame_timings': <Object?>[
          <String, int>{'frame_number': 7},
        ],
        'rss_samples': <Object?>[
          <String, int>{'current_rss_bytes': 123},
        ],
      },
    ],
  },
};

Map<String, dynamic> _checkpoint(int sequence, {bool terminal = false}) =>
    <String, dynamic>{
      'schema_version': 1,
      'sequence': sequence,
      'terminal': terminal,
      'report_data': _reportData(),
    };

final class _Transport implements ProfileDriverTransport {
  final events = StreamController<Map<String, dynamic>>(sync: true);
  final gone = Completer<void>();
  final requested = Completer<void>();
  final response = Completer<String>();
  final closed = Completer<void>();
  final calls = <String>[];
  final checkpoints = <int, Map<String, dynamic>>{};
  Future<void> Function()? onClose;
  Future<void> Function()? onStopTimeline;
  Future<void> Function(String, int)? onCheckpoint;

  @override
  Stream<Map<String, dynamic>> get checkpointEvents => events.stream;
  @override
  Future<void> get disconnected => gone.future;
  @override
  Future<void> listenForCheckpoints() async => calls.add('listen');
  @override
  Future<String> requestData() {
    calls.add('request');
    requested.complete();
    return response.future;
  }

  @override
  Future<void> stopTimeline() async {
    calls.add('stop_trace');
    await onStopTimeline?.call();
  }

  @override
  Future<Map<String, dynamic>> checkpoint(String action, int sequence) async {
    calls.add('$action:$sequence');
    await onCheckpoint?.call(action, sequence);
    return action == 'read'
        ? checkpoints[sequence]!
        : <String, dynamic>{'acknowledged': sequence};
  }

  @override
  Future<void> close() async {
    calls.add('close');
    if (!closed.isCompleted) closed.complete();
    await onClose?.call();
  }

  void emit(int sequence, {bool terminal = false}) => events.add(
    <String, dynamic>{'sequence': '$sequence', 'terminal': '$terminal'},
  );
}

final class _DiagnosticStderr implements Stdout {
  final lines = <String>[];

  @override
  void writeln([Object? object = '']) => lines.add('$object');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('profile-host-adapter-');
  });
  tearDown(() async => directory.delete(recursive: true));
  Future<void> persist(String name, String value) =>
      writeProfileArtifactAtomically(directory, name, value);

  test(
    'diagnostic file write failure cannot replace the original frame error',
    () async {
      await Directory('${directory.path}/driver_transport.json').create();
      final original = StateError('original native frame error');
      final originalStack = StackTrace.fromString(
        'original native frame stack',
      );
      final capture = ProfileDriverCapture()
        ..response = jsonEncode(<String, Object?>{
          'result': 'true',
          'data': _reportData(),
        });
      capture.failures.add(
        ProfileDriverFailure('frame', original, originalStack),
      );
      final output = _DiagnosticStderr();
      final status = await IOOverrides.runZoned(
        () => writeCapturedProfileEvidence(
          capture,
          directory,
          writeEvidence: (data, target) => writeProfilePerformanceEvidence(
            data,
            target,
            launcherMetadata: (_) async => <String, Object?>{},
            sourceMetadata: () async => <String, Object?>{},
          ),
        ),
        stderr: () => output,
      );
      expect(status, 1);
      expect(capture.failures.first.error, same(original));
      expect(capture.failures.first.stack, same(originalStack));
      expect(capture.failures.last.phase, 'diagnostic_write');
      expect(capture.failures.last.error, isA<FileSystemException>());
      expect(output.lines.join('\n'), contains('original native frame error'));
      expect(output.lines.join('\n'), contains('original native frame stack'));
      expect(output.lines.join('\n'), contains('diagnostic_write'));
      expect(
        File('${directory.path}/p3_frame_samples.json').existsSync(),
        isTrue,
      );
    },
  );

  test(
    'synchronous late completion is rejected for overall connect and close cap',
    () async {
      void block() {
        final clock = Stopwatch()..start();
        while (clock.elapsed < const Duration(milliseconds: 15)) {}
      }

      for (final phase in <String>['connect', 'close']) {
        final transport = _Transport()..response.complete('{"result":"true"}');
        if (phase == 'close') {
          transport.onClose = () {
            block();
            return Future<void>.value();
          };
        }
        final result = await captureNativeProfile(
          connect: () {
            if (phase == 'connect') block();
            return Future<ProfileDriverTransport>.value(transport);
          },
          persist: (_, _) async {},
          timeout: phase == 'connect'
              ? const Duration(milliseconds: 5)
              : const Duration(seconds: 1),
          cleanupTimeout: const Duration(milliseconds: 5),
        );
        expect(result.failed, isTrue, reason: phase);
        expect(result.failures.first.phase, phase);
        expect(result.failures.first.error, isA<TimeoutException>());
        expect(
          transport.calls,
          contains('close'),
          reason: 'A completed late connection must still be disposed.',
        );
      }
    },
  );

  test(
    'request deadline is real even when transport Future never completes',
    () async {
      final transport = _Transport();
      final clock = Stopwatch()..start();
      final result = await captureNativeProfile(
        connect: () async => transport,
        persist: persist,
        timeout: const Duration(milliseconds: 80),
      );
      expect(result.failed, isTrue);
      expect(result.failures.first.phase, 'request_data');
      expect(result.failures.first.error, isA<TimeoutException>());
      expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
      expect(transport.calls, contains('close'));
      expect(result.response, isNull);
    },
  );

  test(
    'connect deadline returns and closes a subsequently connected transport',
    () async {
      final connection = Completer<ProfileDriverTransport>();
      final result = await captureNativeProfile(
        connect: () => connection.future,
        persist: persist,
        timeout: const Duration(milliseconds: 30),
      );
      expect(result.failures.first.phase, 'connect');
      final late = _Transport();
      connection.complete(late);
      await late.closed.future.timeout(const Duration(seconds: 1));
      expect(late.calls, <String>['close']);
    },
  );

  test('checkpoint is atomic and durable before ack; repeated events do not read again', () async {
    final transport = _Transport();
    final value = _checkpoint(1);
    transport.checkpoints[1] = value;
    final acked = Completer<void>();
    transport.onCheckpoint = (action, sequence) async {
      if (action == 'ack') {
        expect(
          transport.calls,
          containsAllInOrder(<String>['read:1', 'stop_trace', 'ack:1']),
        );
        final file = File(
          '${directory.path}/checkpoints/checkpoint-000001.json',
        );
        expect(jsonDecode(await file.readAsString()), value);
        expect(File('${file.path}.tmp').existsSync(), isFalse);
        acked.complete();
      }
    };
    final pending = captureNativeProfile(
      connect: () async => transport,
      persist: persist,
    );
    await transport.requested.future;
    // No measurement polling is performed before a boundary event arrives.
    expect(transport.calls, <String>['listen', 'request']);
    transport.emit(1);
    transport.emit(1);
    await acked.future;
    transport.emit(1);
    transport.response.complete('{"result":"true","data":{}}');
    final result = await pending;
    expect(result.failed, isFalse);
    expect(result.checkpoint, value);
    expect(result.timelineStops.map((attempt) => attempt['boundary']), <String>[
      'checkpoint',
      'final_close',
    ]);
    expect(
      result.timelineStops.every(
        (attempt) => attempt['status'] == 'acknowledged',
      ),
      isTrue,
    );
    expect(transport.calls.where((call) => call.startsWith('read')), <String>[
      'read:1',
    ]);
    expect(transport.calls.where((call) => call.startsWith('ack')), <String>[
      'ack:1',
    ]);
    expect(
      await File('${directory.path}/integration_response.raw.json')
          .readAsString(),
      result.response,
    );
  });

  test(
    'checkpoint write failure never acknowledges or invents recoverable data',
    () async {
      final transport = _Transport()..checkpoints[1] = _checkpoint(1);
      final diskError = FileSystemException('disk full');
      final pending = captureNativeProfile(
        connect: () async => transport,
        persist: (name, value) async => throw diskError,
      );
      await transport.requested.future;
      transport.emit(1);
      final result = await pending;
      expect(result.failures.first.error, same(diskError));
      expect(result.checkpoint, isNull);
      expect(transport.calls, isNot(contains('ack:1')));
    },
  );

  test(
    'checkpoint trace stop failure preserves the checkpoint and withholds ACK',
    () async {
      final transport = _Transport()..checkpoints[1] = _checkpoint(1);
      final original = StateError('VM trace stop rejected');
      var stops = 0;
      transport.onStopTimeline = () async {
        if (stops++ == 0) throw original;
      };
      final pending = captureNativeProfile(
        connect: () async => transport,
        persist: persist,
      );
      await transport.requested.future;
      transport.emit(1);
      final result = await pending;
      expect(result.failures.first.error, same(original));
      expect(result.checkpoint?['sequence'], 1);
      expect(transport.calls, isNot(contains('ack:1')));
      expect(result.timelineStops.map((attempt) => attempt['status']), <String>[
        'failed',
        'acknowledged',
      ]);
      expect(transport.calls.last, 'close');
    },
  );

  test(
    'disconnect while stopping a checkpoint cannot acknowledge a next workload',
    () async {
      final transport = _Transport()..checkpoints[1] = _checkpoint(1);
      transport.onStopTimeline = () async {
        if (!transport.gone.isCompleted) transport.gone.complete();
      };
      final pending = captureNativeProfile(
        connect: () async => transport,
        persist: persist,
      );
      await transport.requested.future;
      transport.emit(1);
      final result = await pending;
      expect(result.failures.first.phase, 'transport_disconnect');
      expect(result.checkpoint?['sequence'], 1);
      expect(transport.calls, isNot(contains('ack:1')));
    },
  );

  test('terminal remains primary when checkpoint trace stop fails', () async {
    final transport = _Transport()
      ..checkpoints[1] = _checkpoint(1, terminal: true);
    transport.onStopTimeline = () async =>
        throw StateError('trace stop failed');
    final pending = captureNativeProfile(
      connect: () async => transport,
      persist: persist,
    );
    await transport.requested.future;
    transport.emit(1, terminal: true);
    final result = await pending;
    expect(result.failures.first.phase, 'terminal_checkpoint');
    expect(
      result.failures.skip(1).map((failure) => failure.error.toString()),
      contains(contains('trace stop failed')),
    );
    expect(result.checkpoint?['terminal'], isTrue);
    expect(transport.calls, isNot(contains('ack:1')));
    expect(
      result.timelineStops.every((attempt) => attempt['status'] == 'failed'),
      isTrue,
    );
  });

  test(
    'final trace stop has a real deadline and cannot overwrite request failure',
    () async {
      final transport = _Transport();
      transport.onStopTimeline = () => Completer<void>().future;
      final original = StateError('original request failure');
      final pending = captureNativeProfile(
        connect: () async => transport,
        persist: persist,
        cleanupTimeout: const Duration(milliseconds: 20),
      );
      await transport.requested.future;
      transport.response.completeError(original);
      final result = await pending;
      expect(result.failures.first.error, same(original));
      expect(result.failures.last.phase, 'trace_stop.final_close');
      expect(result.failures.last.error, isA<TimeoutException>());
      expect(result.timelineStops.single['status'], 'failed');
      expect(transport.calls.last, 'close');
    },
  );

  test(
    'terminal checkpoint saves then acks and stops pending normal response',
    () async {
      final transport = _Transport()
        ..checkpoints[1] = _checkpoint(1, terminal: true);
      final pending = captureNativeProfile(
        connect: () async => transport,
        persist: persist,
      );
      await transport.requested.future;
      transport.emit(1, terminal: true);
      final result = await pending;
      expect(result.failures.first.phase, 'terminal_checkpoint');
      expect(result.checkpoint?['terminal'], isTrue);
      expect(
        transport.calls,
        containsAllInOrder(<String>['read:1', 'ack:1', 'close']),
      );
      transport.response.complete(
        jsonEncode(<String, Object?>{
          'result': 'true',
          'data': <String, Object?>{
            'p3_performance': <String, Object?>{
              'status': 'workloads_complete',
              'scenarios': <Object?>[],
            },
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(result.response, isNull);
      expect(
        File('${directory.path}/integration_response.raw.json').existsSync(),
        isFalse,
      );
    },
  );

  test(
    'terminal observed during response persistence wins over SDK success',
    () async {
      final transport = _Transport()
        ..checkpoints[1] = _checkpoint(1, terminal: true);
      final savingResponse = Completer<void>();
      final resumeSave = Completer<void>();
      final pending = captureNativeProfile(
        connect: () async => transport,
        persist: (name, value) async {
          if (name == 'integration_response.raw.json') {
            savingResponse.complete();
            await resumeSave.future;
          }
          await persist(name, value);
        },
      );
      await transport.requested.future;
      transport.response.complete(
        jsonEncode(<String, Object?>{
          'result': 'true',
          'data': <String, Object?>{
            'p3_performance': <String, Object?>{
              'status': 'workloads_complete',
              'scenarios': <Object?>[],
            },
          },
        }),
      );
      await savingResponse.future;
      transport.emit(1, terminal: true);
      resumeSave.complete();
      final result = await pending;
      expect(result.failed, isTrue);
      expect(result.failures.first.phase, 'terminal_checkpoint');
      expect(result.checkpoint?['terminal'], isTrue);
      expect(transport.calls, contains('ack:1'));
      expect(
        await writeCapturedProfileEvidence(
          result,
          directory,
          writeEvidence: (data, target) => writeProfilePerformanceEvidence(
            data,
            target,
            launcherMetadata: (_) async => <String, Object?>{},
            sourceMetadata: () async => <String, Object?>{},
          ),
        ),
        1,
      );
      final report = jsonDecode(
        await File('${directory.path}/p3_performance.json').readAsString(),
      ) as Map;
      expect(report['status'], 'failed_partial_transport');
      expect((report['scenarios'] as List).single['id'], 'prompt');
    },
  );

  test(
    'terminal failure remains primary when ack and close also fail',
    () async {
      final transport = _Transport()
        ..checkpoints[1] = _checkpoint(1, terminal: true);
      transport.onCheckpoint = (action, sequence) async {
        if (action == 'ack') throw StateError('ack rejected');
      };
      transport.onClose = () async => throw StateError('close failed');
      final pending = captureNativeProfile(
        connect: () async => transport,
        persist: persist,
      );
      await transport.requested.future;
      transport.emit(1, terminal: true);
      final result = await pending;
      expect(result.failures.first.phase, 'terminal_checkpoint');
      expect(
        result.failures.map((failure) => failure.error.toString()),
        containsAllInOrder(<Matcher>[
          contains('ack rejected'),
          contains('close failed'),
        ]),
      );
      expect(result.checkpoint, isNotNull);
    },
  );

  test('disconnect retains only a checkpoint whose save completed', () async {
    final transport = _Transport()..checkpoints[1] = _checkpoint(1);
    transport.onCheckpoint = (action, sequence) async {
      if (action == 'ack') transport.gone.complete();
    };
    final pending = captureNativeProfile(
      connect: () async => transport,
      persist: persist,
    );
    await transport.requested.future;
    transport.emit(1);
    final result = await pending;
    expect(result.failures.first.phase, 'transport_disconnect');
    expect(result.checkpoint?['sequence'], 1);
    expect(result.response, isNull);
  });

  test('request failure stays primary when close never completes', () async {
    final transport = _Transport();
    transport.onClose = () => Completer<void>().future;
    final original = StateError('original request failure');
    final pending = captureNativeProfile(
      connect: () async => transport,
      persist: persist,
      cleanupTimeout: const Duration(milliseconds: 20),
    );
    await transport.requested.future;
    transport.response.completeError(original);
    final result = await pending;
    expect(result.failures.first.error, same(original));
    expect(result.failures.last.phase, 'close');
    expect(result.failures.last.error, isA<TimeoutException>());
  });

  test(
    'checkpoint error arriving during cleanup remains a secondary failure',
    () async {
      final transport = _Transport()..checkpoints[1] = _checkpoint(1);
      final reading = Completer<void>();
      final release = Completer<void>();
      transport.onCheckpoint = (action, sequence) async {
        if (action == 'read') {
          reading.complete();
          await release.future;
          throw StateError('checkpoint read failed during cleanup');
        }
      };
      final pending = captureNativeProfile(
        connect: () async => transport,
        persist: persist,
      );
      await transport.requested.future;
      transport.emit(1);
      await reading.future;
      transport.response.completeError(StateError('primary request failure'));
      await Future<void>.delayed(Duration.zero);
      release.complete();
      final result = await pending;
      expect(
        result.failures.first.error.toString(),
        contains('primary request failure'),
      );
      expect(
        result.failures.map((failure) => failure.error.toString()),
        contains(contains('checkpoint read failed during cleanup')),
      );
    },
  );

  test('connect and request share one deadline rather than receiving separate budgets', () async {
    final transport = _Transport();
    final pending = captureNativeProfile(
      connect: () async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        return transport;
      },
      persist: persist,
      timeout: const Duration(milliseconds: 100),
    );
    await transport.requested.future;
    final lateResponse = Timer(const Duration(milliseconds: 70), () {
      transport.response.complete('{"result":"true"}');
    });
    final result = await pending;
    lateResponse.cancel();
    expect(result.failures.first.phase, 'request_data');
    expect(result.response, isNull);
  });

  test('native response validation failure is recorded before secondary close failure', () async {
    final transport = _Transport();
    transport.onClose = () async => throw StateError('secondary close');
    final original = StateError('native test failed');
    final pending = captureNativeProfile(
      connect: () async => transport,
      persist: persist,
      inspectResponse: (_) => throw original,
    );
    await transport.requested.future;
    transport.response.complete('{"result":"false"}');
    final result = await pending;
    expect(result.failures.first.error, same(original));
    expect(result.failures.last.phase, 'close');
    expect(result.response, '{"result":"false"}');
    expect(
      File('${directory.path}/integration_response.raw.json').existsSync(),
      isTrue,
    );
  });

  test('checkpoint recovery writes partial failed evidence without changing the checkpoint', () async {
    final checkpoint = _checkpoint(1);
    final before = jsonEncode(checkpoint);
    final capture = ProfileDriverCapture()
      ..checkpoint = checkpoint
      ..checkpointFile = 'checkpoints/checkpoint-000001.json';
    capture.failures.add(
      ProfileDriverFailure(
        'transport_disconnect',
        StateError('gone'),
        StackTrace.current,
      ),
    );
    await persist(capture.checkpointFile!, before);
    final status = await writeCapturedProfileEvidence(
      capture,
      directory,
      writeEvidence: (data, target) => writeProfilePerformanceEvidence(
        data,
        target,
        launcherMetadata: (_) async => <String, Object?>{},
        sourceMetadata: () async => <String, Object?>{},
      ),
    );
    expect(status, 1);
    final report = jsonDecode(
      await File('${directory.path}/p3_performance.json').readAsString(),
    ) as Map;
    expect(report['status'], 'failed_partial_transport');
    expect(report['workload_status_before_transport_failure'], 'measuring');
    expect((report['transport_evidence_origin'] as Map)['partial'], isTrue);
    expect(jsonEncode(checkpoint), before);
    expect(
      await File('${directory.path}/${capture.checkpointFile}').readAsString(),
      before,
    );
    expect(
      (jsonDecode(
        await File('${directory.path}/driver_transport.json').readAsString(),
      ) as Map)['status'],
      'failed',
    );
    expect(
      File('${directory.path}/p3_frame_samples.json').existsSync(),
      isTrue,
    );
  });

  test(
    'mismatching checkpoint is rejected before persistence and ack',
    () async {
      final transport = _Transport()..checkpoints[1] = _checkpoint(2);
      final pending = captureNativeProfile(
        connect: () async => transport,
        persist: persist,
      );
      await transport.requested.future;
      transport.emit(1);
      final result = await pending;
      expect(result.failures.first.error, isA<FormatException>());
      expect(result.checkpoint, isNull);
      expect(transport.calls, isNot(contains('ack:1')));
    },
  );

  test('raw response frames and RSS precede metadata; secondary errors remain visible', () async {
    final data = _reportData();
    await expectLater(
      writeProfilePerformanceEvidence(
        data,
        directory,
        launcherMetadata: (target) async {
          expect(
            File('${target.path}/p3_response_data.raw.json').existsSync(),
            isTrue,
          );
          expect(
            jsonDecode(
              await File('${target.path}/p3_frame_samples.json').readAsString(),
            ),
            <String, Object?>{
              'prompt': <Object?>[
                <String, int>{'frame_number': 7},
              ],
            },
          );
          expect(
            File('${target.path}/p3_memory_samples.json').existsSync(),
            isTrue,
          );
          throw StateError('first metadata error');
        },
        sourceMetadata: () async => throw StateError('second metadata error'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('first metadata error'),
        ),
      ),
    );
    final report = jsonDecode(
      await File('${directory.path}/p3_performance.json').readAsString(),
    ) as Map;
    expect(report['status'], 'failed_evidence_write');
    final failures = (report['driver'] as Map)['evidence_failures'] as List;
    expect(failures.length, 2);
    expect(failures.first['error'], contains('first metadata error'));
    expect(failures.last['error'], contains('second metadata error'));
    expect(data, _reportData());
  });
}
