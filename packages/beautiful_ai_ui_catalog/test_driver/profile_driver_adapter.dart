import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The native VM-service operations used by the host. No Flutter test clock.
abstract interface class ProfileDriverTransport {
  Stream<Map<String, dynamic>> get checkpointEvents;
  Future<void> get disconnected;
  Future<void> listenForCheckpoints();
  Future<String> requestData();
  Future<Map<String, dynamic>> checkpoint(String action, int sequence);
  Future<void> stopTimeline();
  Future<void> close();
}

typedef ProfileEvidenceSink = Future<void> Function(String name, String data);

final class ProfileDriverFailure {
  ProfileDriverFailure(this.phase, this.error, this.stack);
  final String phase;
  final Object error;
  final StackTrace stack;

  Map<String, Object?> toJson() => <String, Object?>{
    'phase': phase,
    'error': error.toString(),
    'stack': stack.toString(),
  };
}

final class ProfileDriverCapture {
  String? response;
  Map<String, dynamic>? checkpoint;
  String? checkpointFile;
  final failures = <ProfileDriverFailure>[];
  final timelineStops = <Map<String, Object?>>[];
  bool get failed => failures.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'status': failed ? 'failed' : 'response_received',
    'response_file': response == null ? null : 'integration_response.raw.json',
    'checkpoint_file': checkpointFile,
    'checkpoint_sequence': checkpoint?['sequence'],
    'checkpoint_terminal': checkpoint?['terminal'],
    'timeline_stop_attempts': timelineStops,
    'primary_failure': failures.isEmpty ? null : failures.first.toJson(),
    'secondary_failures': failures
        .skip(1)
        .map((value) => value.toJson())
        .toList(),
  };
}

/// A real host deadline, unlike FlutterDriver's warning-only timeout parameter.
/// Checkpoints are requested only in response to native boundary events. The
/// native publisher may repeat an event until its durable checkpoint is acked.
Future<ProfileDriverCapture> captureNativeProfile({
  required Future<ProfileDriverTransport> Function() connect,
  required ProfileEvidenceSink persist,
  void Function(String response)? inspectResponse,
  Duration timeout = const Duration(minutes: 25),
  Duration cleanupTimeout = const Duration(seconds: 5),
}) async {
  final result = ProfileDriverCapture();
  final deadline = _HostDeadline(timeout);
  final abort = Completer<void>();
  ProfileDriverTransport? transport;
  StreamSubscription<Map<String, dynamic>>? subscription;
  var closing = false;
  var finished = false;
  var phase = 'connect';
  var terminalReceived = false;
  var checkpointQueue = Future<void>.value();
  final seenSequences = <int, bool>{};

  void fail(String at, Object error, StackTrace stack) {
    result.failures.add(ProfileDriverFailure(at, error, stack));
    if (!abort.isCompleted) abort.complete();
  }

  void requireActive() {
    if (closing || finished || result.failed) {
      throw const _ProfileTransportStopped();
    }
  }

  Future<void> stopTimeline(String boundary, {int? sequence}) async {
    final attempt = <String, Object?>{
      'boundary': boundary,
      'checkpoint_sequence': ?sequence,
      'status': 'started',
      'start_epoch_us': DateTime.now().microsecondsSinceEpoch,
    };
    result.timelineStops.add(attempt);
    try {
      await deadline.run(
        () => transport!.stopTimeline(),
        'trace_stop.$boundary',
        cap: cleanupTimeout,
      );
      attempt['status'] = 'acknowledged';
    } catch (error, stack) {
      attempt['status'] = 'failed';
      attempt['error'] = error.toString();
      attempt['stack'] = stack.toString();
      rethrow;
    } finally {
      attempt['end_epoch_us'] = DateTime.now().microsecondsSinceEpoch;
    }
  }

  Future<void> receiveCheckpoint(Map<String, dynamic> event) async {
    final sequence = int.tryParse(event['sequence'].toString());
    final terminalValue = event['terminal'];
    if (sequence == null ||
        sequence < 1 ||
        (terminalValue != 'true' && terminalValue != 'false')) {
      throw const FormatException('Invalid native checkpoint event.');
    }
    final terminal = terminalValue == 'true';
    if (seenSequences.containsKey(sequence)) {
      if (seenSequences[sequence] != terminal) {
        throw const FormatException(
          'Checkpoint terminal flag changed for the same sequence.',
        );
      }
      return;
    }
    seenSequences[sequence] = terminal;
    terminalReceived |= terminal;
    requireActive();
    final checkpoint = await deadline.run(
      () => transport!.checkpoint('read', sequence),
      'checkpoint_read',
    );
    requireActive();
    if (checkpoint['schema_version'] != 1 ||
        checkpoint['sequence'] != sequence ||
        checkpoint['terminal'] != terminal ||
        checkpoint['report_data'] is! Map ||
        (checkpoint['report_data'] as Map)['p3_performance'] is! Map) {
      throw const FormatException(
        'Native checkpoint does not match its event.',
      );
    }
    final previous = result.checkpoint?['sequence'] as int?;
    if (previous != null && sequence <= previous) {
      throw const FormatException(
        'Native checkpoint sequence moved backwards.',
      );
    }
    final serialized = jsonEncode(checkpoint);
    final filename =
        'checkpoints/checkpoint-${sequence.toString().padLeft(6, '0')}.json';
    await deadline.run(() => persist(filename, serialized), 'checkpoint_save');
    if (finished) return;
    // Only a completed atomic write counts as the recoverable checkpoint.
    result.checkpoint = Map<String, dynamic>.from(
      jsonDecode(serialized) as Map,
    );
    result.checkpointFile = filename;
    requireActive();
    if (terminal) {
      // Preserve the native fatal failure even if acknowledgement/close fails.
      result.failures.add(
        ProfileDriverFailure(
          'terminal_checkpoint',
          StateError(
            'The native recorder stopped after a fatal frame wait; '
            'checkpoint $sequence was durably saved.',
          ),
          StackTrace.current,
        ),
      );
    }
    try {
      // The publisher still holds the next workload behind its ACK boundary.
      // Use the public VM service API; binding.enableTimeline rejects [].
      await stopTimeline('checkpoint', sequence: sequence);
      if (closing || finished || (!terminal && result.failed)) {
        throw const _ProfileTransportStopped();
      }
      await deadline.run(
        () => transport!.checkpoint('ack', sequence),
        'checkpoint_ack',
      );
    } finally {
      if (terminal && !abort.isCompleted) abort.complete();
    }
  }

  try {
    final pendingConnection = connect().then((value) {
      if (closing || finished) {
        // Future.timeout cannot cancel connect. Dispose a late connection,
        // without reviving the completed run or accepting any late response.
        unawaited(
          Future<void>.sync(value.close)
              .timeout(cleanupTimeout)
              .catchError((Object _) {}),
        );
      } else {
        // A completed connection can still fail the elapsed deadline check.
        // Hold it now so that the failure's finally can stop tracing and close.
        transport = value;
      }
      return value;
    });
    final connected = await deadline.run(() => pendingConnection, phase);
    transport = connected;
    phase = 'checkpoint_subscription';
    subscription = connected.checkpointEvents.listen(
      (event) {
        if (closing || finished || result.failed) return;
        terminalReceived |= event['terminal'] == 'true';
        checkpointQueue = checkpointQueue
            .then((_) => receiveCheckpoint(event))
            .catchError((Object error, StackTrace stack) {
              if (!finished && error is! _ProfileTransportStopped) {
                fail('checkpoint', error, stack);
              }
            });
      },
      onError: (Object error, StackTrace stack) {
        if (!closing && !finished) fail('checkpoint_stream', error, stack);
      },
    );
    unawaited(
      connected.disconnected.then(
        (_) {
          if (!closing && !finished) {
            fail(
              'transport_disconnect',
              StateError('VM service disconnected.'),
              StackTrace.current,
            );
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!closing && !finished) fail('transport_disconnect', error, stack);
        },
      ),
    );
    await Future.any<void>(<Future<void>>[
      deadline.run(connected.listenForCheckpoints, phase),
      abort.future,
    ]);
    if (result.failed) return result;
    phase = 'request_data';
    final request = deadline
        .run(connected.requestData, phase)
        .then((value) => value);
    // An abort is a value, not an unobserved error Future. The losing request
    // stays observed; its late completion can never write a success report.
    final response = await Future.any<String?>(<Future<String?>>[
      request,
      abort.future.then((_) => null),
    ]);
    if (response != null && !result.failed) {
      phase = 'checkpoint_drain';
      await deadline.run(() => checkpointQueue, phase);
      if (!result.failed && !terminalReceived) {
        phase = 'response_save';
        await deadline.run(
          () => persist('integration_response.raw.json', response),
          phase,
        );
        result.response = response;
        // A terminal event may arrive while the response is being flushed.
        // Drain every observed checkpoint before closing or accepting success.
        phase = 'checkpoint_drain_after_response';
        await deadline.run(() => checkpointQueue, phase);
        if (!result.failed && !terminalReceived) {
          phase = 'response_validation';
          inspectResponse?.call(response);
        }
      }
    }
  } catch (error, stack) {
    fail(phase, error, stack);
  } finally {
    closing = true;
    try {
      await deadline.run(
        () => checkpointQueue,
        'checkpoint_cleanup',
        cap: cleanupTimeout,
      );
    } catch (error, stack) {
      fail('checkpoint_cleanup', error, stack);
    }
    if (subscription != null) {
      try {
        await deadline.run(
          subscription.cancel,
          'subscription_cleanup',
          cap: cleanupTimeout,
        );
      } catch (error, stack) {
        fail('subscription_cleanup', error, stack);
      }
    }
    final closingTransport = transport;
    if (closingTransport != null) {
      try {
        await stopTimeline('final_close');
      } catch (error, stack) {
        fail('trace_stop.final_close', error, stack);
      }
      try {
        await deadline.run(
          closingTransport.close,
          'close',
          cap: cleanupTimeout,
        );
      } catch (error, stack) {
        fail('close', error, stack);
      }
    }
    finished = true;
  }
  return result;
}

final class _ProfileTransportStopped implements Exception {
  const _ProfileTransportStopped();
}

final class _HostDeadline {
  _HostDeadline(this.timeout);
  final Duration timeout;
  final Stopwatch clock = Stopwatch()..start();

  Future<T> run<T>(
    Future<T> Function() action,
    String phase, {
    Duration? cap,
  }) async {
    var remaining = timeout - clock.elapsed;
    if (cap != null && cap < remaining) remaining = cap;
    if (remaining.isNegative) remaining = Duration.zero;
    final operationClock = Stopwatch()..start();
    final value = await Future<T>.sync(action).timeout(
      remaining,
      onTimeout: () {
        throw TimeoutException(
          'Native profile host deadline at $phase.',
          timeout,
        );
      },
    );
    // Synchronous work may exhaust the deadline before its timeout Timer gets
    // a turn. Check both the original total and this operation's remaining cap.
    if (clock.elapsed > timeout || operationClock.elapsed > remaining) {
      throw TimeoutException(
        'Native profile host deadline at $phase; completion arrived after deadline.',
        timeout,
      );
    }
    return value;
  }
}

/// A checkpoint is acknowledged only after flush and same-directory rename.
Future<void> writeProfileArtifactAtomically(
  Directory directory,
  String name,
  String data,
) async {
  final file = File('${directory.path}/$name');
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString(data, flush: true);
  await temporary.rename(file.path);
}
