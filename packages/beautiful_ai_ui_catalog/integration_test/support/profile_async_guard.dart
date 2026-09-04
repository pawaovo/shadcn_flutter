import 'dart:async';

/// An await whose real deadline expired while its original Future is pending.
/// Future.timeout cannot cancel that Future, so this stops further UI work.
final class ProfileAsyncTimeout extends TimeoutException {
  ProfileAsyncTimeout(this.operation, Duration timeout, this.observation)
    : super('Profile operation "$operation" did not return in time.', timeout);

  final String operation;
  final Map<String, Object?> observation;

  Map<String, Object?> toJson() => <String, Object?>{
    'operation': operation,
    'timeout_us': duration!.inMicroseconds,
    'message': message,
    'observation': observation,
    'future_cancelled': false,
    'deadline_requires_suite_stop': true,
  };
}

/// Real-time guards independent of the widget binding's clock and frame loop.
final class ProfileAsyncGuard {
  ProfileAsyncGuard({
    this.frameTimeout = const Duration(seconds: 8),
    Map<String, Object?> Function()? observation,
    this.onOperation,
  }) : _observation = observation ?? _emptyObservation;

  final Duration frameTimeout;
  final Map<String, Object?> Function() _observation;
  final void Function(Map<String, Object?>)? onOperation;
  ProfileAsyncTimeout? _terminalFailure;
  final _diagnosticErrors = <String>[];

  bool get isTerminal => _terminalFailure != null;
  ProfileAsyncTimeout? get terminalFailure => _terminalFailure;

  static Map<String, Object?> _emptyObservation() => <String, Object?>{};

  Map<String, Object?> _safeObservation() {
    try {
      return <String, Object?>{
        ..._observation(),
        if (_diagnosticErrors.isNotEmpty)
          'diagnostic_errors': List<String>.of(_diagnosticErrors),
      };
    } catch (error) {
      return <String, Object?>{
        'diagnostic_observation_error': error.toString(),
      };
    }
  }

  void _reportOperation(Map<String, Object?> operation) {
    try {
      onOperation?.call(operation);
    } catch (error) {
      _diagnosticErrors.add(error.toString());
    }
  }

  void checkActive() {
    if (_terminalFailure case final failure?) throw failure;
  }

  Future<T> wait<T>(
    String operation,
    Future<T> Function() action, {
    Duration? timeout,
    bool allowAfterTerminal = false,
  }) async {
    if (!allowAfterTerminal) checkActive();
    final limit = timeout ?? frameTimeout;
    final started = DateTime.now().microsecondsSinceEpoch;
    final timer = Stopwatch()..start();
    _reportOperation(<String, Object?>{
      'operation': operation,
      'status': 'waiting',
      'start_epoch_us': started,
      'timeout_us': limit.inMicroseconds,
    });
    try {
      final value = await action().timeout(
        limit,
        onTimeout: () {
          final failure = ProfileAsyncTimeout(
            operation,
            limit,
            <String, Object?>{
              'wait_start_epoch_us': started,
              'observed_at_epoch_us': DateTime.now().microsecondsSinceEpoch,
              'wall_time_us': timer.elapsedMicroseconds,
              ..._safeObservation(),
            },
          );
          _terminalFailure ??= failure;
          throw failure;
        },
      );
      if (timer.elapsed > limit) {
        final failure = ProfileAsyncTimeout(operation, limit, <String, Object?>{
          'wait_start_epoch_us': started,
          'observed_at_epoch_us': DateTime.now().microsecondsSinceEpoch,
          'wall_time_us': timer.elapsedMicroseconds,
          'completion_arrived_after_deadline': true,
          ..._safeObservation(),
        });
        _terminalFailure ??= failure;
        throw failure;
      }
      // Another enclosing deadline may have expired while this Future waited.
      // Do not let that late completion continue an input helper or pump loop.
      if (!allowAfterTerminal) checkActive();
      _reportOperation(<String, Object?>{
        'operation': operation,
        'status': 'completed',
        'start_epoch_us': started,
        'end_epoch_us': DateTime.now().microsecondsSinceEpoch,
        'wall_time_us': timer.elapsedMicroseconds,
      });
      return value;
    } catch (error) {
      _reportOperation(<String, Object?>{
        'operation': operation,
        'status': 'failed',
        'start_epoch_us': started,
        'end_epoch_us': DateTime.now().microsecondsSinceEpoch,
        'wall_time_us': timer.elapsedMicroseconds,
        'error': error.toString(),
      });
      rethrow;
    }
  }

  /// Equivalent settle condition and 16ms cadence, but each pending pump has
  /// the remaining real deadline. A late original pump cannot resume this loop.
  Future<void> settle({
    required Future<void> Function(Duration) pump,
    required bool Function() hasScheduledFrame,
    Duration frameInterval = const Duration(milliseconds: 16),
    Duration? timeout,
  }) async {
    checkActive();
    final limit = timeout ?? frameTimeout;
    final clock = Stopwatch()..start();
    do {
      final remaining = limit - clock.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('pumpAndSettle timed out', limit);
      }
      await wait('settle.pump', () => pump(frameInterval), timeout: remaining);
    } while (hasScheduledFrame());
  }
}

/// The real recorder's failure finalization seam. Raw independent evidence is
/// attached before optional observations or cleanup can fail. Passing no cleanup
/// is intentional when a pending native Future makes further pumps unsafe.
Future<void> finalizeProfileEvidence({
  required ProfileFailureLedger failures,
  required Map<String, Object?> result,
  required void Function() preserveRaw,
  required void Function() runtime,
  required void Function() outcomes,
  Future<void> Function()? cleanup,
}) async {
  failures.attempt('raw_evidence', preserveRaw);
  failures.attempt('runtime_metadata', runtime);
  failures.attempt('outcomes', outcomes);
  if (cleanup != null) await failures.attemptAsync('cleanup', cleanup);
  if (failures.hasFailure) {
    result['status'] = 'failed';
    result['failures'] = failures.records;
    result['failure'] = failures.records.first['error'];
    result['stack'] = failures.records.first['stack'];
  }
}

/// Preserve the original failure when evidence/cleanup also throws.
final class ProfileFailureLedger {
  Object? _first;
  StackTrace? _firstStack;
  final records = <Map<String, Object?>>[];

  bool get hasFailure => _first != null;

  void add(String phase, Object error, StackTrace stack) {
    final primary = _first == null;
    if (primary) {
      _first = error;
      _firstStack = stack;
    }
    records.add(<String, Object?>{
      'phase': phase,
      'primary': primary,
      'error': error.toString(),
      'stack': stack.toString(),
      if (error is ProfileAsyncTimeout) 'timeout': error.toJson(),
    });
  }

  void attempt(String phase, void Function() action) {
    try {
      action();
    } catch (error, stack) {
      add(phase, error, stack);
    }
  }

  Future<void> attemptAsync(
    String phase,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error, stack) {
      add(phase, error, stack);
    }
  }

  void rethrowFirst() {
    if (_first case final error?) {
      Error.throwWithStackTrace(error, _firstStack!);
    }
  }
}
