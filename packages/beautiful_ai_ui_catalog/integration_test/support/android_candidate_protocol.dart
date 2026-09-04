import 'dart:async';
import 'dart:collection';

final class AndroidCandidateStageSpec {
  const AndroidCandidateStageSpec._(
    this.id,
    this.text,
    this.candidate,
    this.composingBase,
    this.composingExtent,
    this.selectionOffset,
  );
  final String id;
  final String text;
  final String candidate;
  final int composingBase;
  final int composingExtent;
  final int selectionOffset;

  static const chatSend = AndroidCandidateStageSpec._(
    'chat_send',
    'Check cone inventory',
    'inventory',
    11,
    20,
    20,
  );
  static const promptCommand = AndroidCandidateStageSpec._(
    'prompt_command',
    '/rest',
    'rest',
    1,
    5,
    5,
  );
  static const promptSend = AndroidCandidateStageSpec._(
    'prompt_send',
    'Prepare the seasonal restock',
    'restock',
    21,
    28,
    28,
  );
  static const ordered = <AndroidCandidateStageSpec>[
    chatSend,
    promptCommand,
    promptSend,
  ];
}

/// VM requests are delivered outside the test's WidgetTester async scope.
final class AndroidCandidateRpcQueue {
  AndroidCandidateRpcQueue(this.protocol);

  final AndroidCandidateProtocol protocol;
  Map<String, Object?> Function(Map<String, Object?>)? decorate;
  final Queue<_AndroidCandidateRequest> _pending =
      Queue<_AndroidCandidateRequest>();
  Zone? _testZone;
  bool _live = false;
  bool _frozen = false;
  bool get isFrozen => _frozen;

  /// Call in the owning test zone immediately before installing live getters.
  void beginLiveObservation() {
    if (_testZone != null || _frozen) {
      throw StateError('The live candidate observation can only start once.');
    }
    _testZone = Zone.current;
    _live = true;
  }

  Future<Map<String, Object?>> request(Map<String, String> parameters) {
    final copied = Map<String, String>.of(parameters);
    if (!_live) return Future<Map<String, Object?>>.sync(() => _handle(copied));
    final request = _AndroidCandidateRequest(copied);
    _pending.add(request);
    return request.result.future;
  }

  /// The owner calls this only after its guarded pump completes, or immediately
  /// before the final activation. Handling stays synchronous and FIFO.
  void drain() {
    if (_testZone != null && !identical(Zone.current, _testZone)) {
      throw StateError(
        'Only the owning test zone may drain live candidate RPCs.',
      );
    }
    while (_pending.isNotEmpty) {
      final request = _pending.removeFirst();
      try {
        request.result.complete(_handle(request.parameters));
      } catch (error, stack) {
        request.result.completeError(error, stack);
      }
    }
  }

  /// Install a record-only getter (or enter a terminal protocol state) first.
  /// Pending requests then finish without widget access. Future claims cannot
  /// authorize actions from the frozen record, even if it looks eligible.
  void freeze() {
    _frozen = true;
    _live = false;
    drain();
  }

  Map<String, Object?> _handle(Map<String, String> parameters) {
    if (_frozen && parameters['action'] == 'claim') {
      throw StateError('A frozen candidate observation cannot issue a claim.');
    }
    final result = protocol.handle(parameters);
    return decorate?.call(result) ?? result;
  }
}

final class _AndroidCandidateRequest {
  _AndroidCandidateRequest(this.parameters);

  final Map<String, String> parameters;
  final Completer<Map<String, Object?>> result =
      Completer<Map<String, Object?>>();
}

/// One stage's widget getter and FIFO are never reused for another stage.
final class AndroidCandidateStageSession {
  AndroidCandidateStageSession({
    required this.spec,
    required this.stageNonce,
    required String nonce,
    required String sourceSha,
    required int Function() elapsedMilliseconds,
    required String Function() newLeaseId,
    required int deadlineMilliseconds,
  }) {
    protocol = AndroidCandidateProtocol(
      nonce: nonce,
      sourceSha: sourceSha,
      stageNonce: stageNonce,
      spec: spec,
      readSnapshot: () => readSnapshot(),
      elapsedMilliseconds: elapsedMilliseconds,
      newLeaseId: newLeaseId,
      deadlineMilliseconds: deadlineMilliseconds,
    );
    rpc = AndroidCandidateRpcQueue(protocol);
  }
  final AndroidCandidateStageSpec spec;
  final String stageNonce;
  late final AndroidCandidateProtocol protocol;
  late final AndroidCandidateRpcQueue rpc;
  Map<String, Object?> Function() readSnapshot = () => <String, Object?>{
    'observation_error': 'The original journey has not reached this stage yet.',
  };
  bool entered = false;
  bool originalActionPassed = false;
}

/// A fixed sequence with read-only discovery and stage-bound mutations.
final class AndroidCandidateSequence {
  AndroidCandidateSequence({
    required this.nonce,
    required this.sourceSha,
    required this.elapsedMilliseconds,
    required this.newStageNonce,
    required this.newLeaseId,
    this.deadlineMilliseconds = 600000,
    String? initialStageNonce,
  }) {
    _sessions.add(
      _create(
        AndroidCandidateStageSpec.chatSend,
        stageNonce: initialStageNonce,
      ),
    );
  }
  final String nonce;
  final String sourceSha;
  final int Function() elapsedMilliseconds;
  final String Function() newStageNonce;
  final String Function() newLeaseId;
  final int deadlineMilliseconds;
  final List<AndroidCandidateStageSession> _sessions =
      <AndroidCandidateStageSession>[];
  String journeyStatus = 'running';
  AndroidCandidateStageSession get current => _sessions.last;

  AndroidCandidateStageSession _create(
    AndroidCandidateStageSpec spec, {
    String? stageNonce,
  }) {
    stageNonce ??= newStageNonce();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(stageNonce) ||
        stageNonce == nonce ||
        _sessions.any((session) => session.stageNonce == stageNonce)) {
      throw StateError('Every candidate stage requires a fresh unique nonce.');
    }
    final session = AndroidCandidateStageSession(
      spec: spec,
      stageNonce: stageNonce,
      nonce: nonce,
      sourceSha: sourceSha,
      elapsedMilliseconds: elapsedMilliseconds,
      newLeaseId: newLeaseId,
      deadlineMilliseconds: deadlineMilliseconds,
    );
    session.rpc.decorate = (state) => _decorate(session, state);
    return session;
  }

  AndroidCandidateStageSession enterStage(String id) {
    if (journeyStatus != 'running' || current.protocol.stage == 'failed') {
      throw StateError(
        'A failed or finished journey cannot enter another stage.',
      );
    }
    if (current.spec.id != id) {
      final next = _sessions.length;
      if (!current.originalActionPassed ||
          next >= AndroidCandidateStageSpec.ordered.length ||
          AndroidCandidateStageSpec.ordered[next].id != id) {
        throw StateError(
          'Candidate stages must follow the fixed original action order.',
        );
      }
      _sessions.add(_create(AndroidCandidateStageSpec.ordered[next]));
    }
    if (current.entered) {
      throw StateError('A candidate stage cannot be repeated.');
    }
    current.entered = true;
    return current;
  }

  void completeStage(String id) {
    if (current.spec.id != id ||
        !current.entered ||
        current.originalActionPassed ||
        !current.rpc.isFrozen) {
      throw StateError(
        'Only the completed original action can finish its stage.',
      );
    }
    current.protocol.pass(captureSnapshot: false);
    current.originalActionPassed = true;
  }

  List<Map<String, Object?>> get stageResults => <Map<String, Object?>>[
    for (final session in _sessions)
      if (session.originalActionPassed)
        <String, Object?>{
          ...session.protocol.state(),
          'stage': 'stage_done',
          'original_action_passed': true,
        },
  ];

  Map<String, Object?> _decorate(
    AndroidCandidateStageSession session,
    Map<String, Object?> state,
  ) => <String, Object?>{
    ...state,
    'stage': state['stage'] == 'passed' ? 'stage_done' : state['stage'],
    'stage_index': AndroidCandidateStageSpec.ordered.indexOf(session.spec),
    'original_action_passed': session.originalActionPassed,
    'completed_stage_ids': <String>[
      for (final done in stageResults) done['stage_id']! as String,
    ],
    'stage_results': stageResults,
    'journey_status': journeyStatus,
  };

  Future<Map<String, Object?>> request(Map<String, String> parameters) async {
    if (parameters['nonce'] != nonce || parameters['source_sha'] != sourceSha) {
      throw StateError('Candidate sequence identity mismatch.');
    }
    final session = current;
    final unboundState =
        parameters['action'] == 'state' &&
        !parameters.containsKey('stage_id') &&
        !parameters.containsKey('stage_nonce');
    if (!unboundState &&
        (parameters['stage_id'] != session.spec.id ||
            parameters['stage_nonce'] != session.stageNonce)) {
      throw StateError('The request does not own the current candidate stage.');
    }
    return session.rpc.request(<String, String>{
      ...parameters,
      'stage_id': session.spec.id,
      'stage_nonce': session.stageNonce,
    });
  }

  void finishJourney(bool originalPassed) {
    final allStages =
        _sessions.length == AndroidCandidateStageSpec.ordered.length &&
        _sessions.every((session) => session.originalActionPassed);
    final withinDeadline = elapsedMilliseconds() < deadlineMilliseconds;
    journeyStatus = originalPassed && allStages && withinDeadline
        ? 'passed'
        : 'failed';
    if (journeyStatus == 'failed') {
      current.protocol.fail('The complete original journey did not pass.');
    }
  }

  Map<String, Object?> state() => _decorate(current, current.protocol.state());
}

Future<void> Function(Object tester, Object root, String stageId)?
androidCandidateBeforeStageAction;
void Function(Object tester, Object root, String stageId)?
androidCandidateGuardStageAction;
void Function(String stageId)? androidCandidateAfterStageAction;
void Function(String stageId)? androidCandidateStageCompleted;

Future<void> awaitAndroidCandidateStage(
  Object tester,
  Object root,
  String stageId,
) {
  final callback = androidCandidateBeforeStageAction;
  if (callback == null) {
    throw StateError('The candidate stage target is not installed.');
  }
  return callback(tester, root, stageId);
}

void guardAndroidCandidateStage(Object tester, Object root, String stageId) {
  final callback = androidCandidateGuardStageAction;
  if (callback == null) {
    throw StateError('The candidate stage activation guard is not installed.');
  }
  callback(tester, root, stageId);
}

void completeAndroidCandidateStage(String stageId) {
  final callback = androidCandidateStageCompleted;
  if (callback == null) {
    throw StateError('The candidate stage completion target is not installed.');
  }
  callback(stageId);
}

typedef AndroidCandidateBeforeSend = Future<void> Function(
  Object tester,
  Object chat,
  String expectedText,
);

/// Only the explicit Android target installs this test callback. Importing the
/// protocol does not register an extension, start a timer, or change widgets.
AndroidCandidateBeforeSend? androidCandidateBeforeSend;

/// This callback must synchronously read the live editor at the final tap site.
void Function(Object tester, Object chat, String expectedText)?
androidCandidateBeforeActivation;

/// Installed by the diagnostic wrapper; its observer catches and records its
/// own failures so cleanup cannot replace the original tap/assertion failure.
void Function()? androidCandidateAfterTap;

void guardAndroidCandidateBeforeActivation(
  Object tester,
  Object chat,
  String expectedText,
) {
  final callback = androidCandidateBeforeActivation;
  if (callback == null) {
    throw StateError(
      'The Android candidate activation guard is not installed.',
    );
  }
  callback(tester, chat, expectedText);
}

Future<void> awaitAndroidCandidateBeforeSend(
  Object tester,
  Object chat,
  String expectedText,
) {
  final callback = androidCandidateBeforeSend;
  if (callback == null) {
    throw StateError(
      'The explicit Android candidate target was not installed.',
    );
  }
  return callback(tester, chat, expectedText);
}

/// A test-only, one-action handshake. It observes editing state; it cannot edit
/// a controller, focus a widget, commit an IME, or generate a pointer event.
final class AndroidCandidateProtocol {
  AndroidCandidateProtocol({
    required this.nonce,
    required this.sourceSha,
    required this.readSnapshot,
    required this.elapsedMilliseconds,
    required this.newLeaseId,
    this.spec = AndroidCandidateStageSpec.chatSend,
    String? stageNonce,
    this.deadlineMilliseconds = 90000,
  }) : stageNonce = stageNonce ?? nonce {
    if (!RegExp(r'^[a-f0-9]{32,64}$').hasMatch(nonce) ||
        !RegExp(r'^[a-f0-9]{40}$').hasMatch(sourceSha)) {
      throw ArgumentError(
        'An exact source SHA and fresh hex nonce are required.',
      );
    }
  }

  static const extensionName = 'ext.beautiful.androidCandidate';
  static const expectedText = 'Check cone inventory';
  static const candidateText = 'inventory';
  static const actionLeaseMilliseconds = 5000;
  static const minimumClaimRemainingMilliseconds = 10000;

  final String nonce;
  final String sourceSha;
  final AndroidCandidateStageSpec spec;
  final String stageNonce;
  final Map<String, Object?> Function() readSnapshot;
  final int Function() elapsedMilliseconds;
  final String Function() newLeaseId;
  final int deadlineMilliseconds;
  final List<Map<String, Object?>> events = <Map<String, Object?>>[];

  String _stage = 'preparing';
  String? _failure;
  String? _candidateId;
  String? _leaseId;
  int? _claimedAt;
  int? _leaseExpiresAt;
  int? _candidateDeadline;
  bool _clicked = false;
  bool _nativeDrained = true;
  bool _activationChecked = false;
  Map<String, Object?>? _lastSnapshot;

  String get stage {
    _expire();
    return _stage;
  }

  bool get isTerminal => stage == 'passed' || stage == 'failed';

  /// This is only an authorization deadline. Its expiry does not prove that a
  /// public UiAutomation call has returned or that OS input delivery stopped.
  int get leaseRemainingMilliseconds => _remaining(_leaseExpiresAt ?? 0);

  /// An issued claim requires an actual native return/stop acknowledgment.
  /// The target must stay mounted while this is true, even after a deadline.
  bool get nativeCallPending => _leaseId != null && !_nativeDrained;

  Map<String, Object?> state() {
    _expire();
    if (!isTerminal) _lastSnapshot = readSnapshot();
    return <String, Object?>{
      'protocol_version': 2,
      'nonce': nonce,
      'run_nonce': nonce,
      'source_sha': sourceSha,
      'stage_id': spec.id,
      'stage_nonce': stageNonce,
      'stage': _stage,
      'elapsed_ms': elapsedMilliseconds(),
      'remaining_ms': _remaining(_deadline),
      'expected_text': spec.text,
      'candidate_text': spec.candidate,
      'composing_base': spec.composingBase,
      'composing_extent': spec.composingExtent,
      'selection_offset': spec.selectionOffset,
      'snapshot': _lastSnapshot,
      'candidate_id': _candidateId,
      'lease_id': _leaseId,
      'claimed_elapsed_ms': _claimedAt,
      'lease_remaining_ms': leaseRemainingMilliseconds,
      'can_click': _stage == 'action_claimed' && !_clicked,
      'native_click_acknowledged': _clicked,
      'native_drained': _nativeDrained,
      'native_call_pending': nativeCallPending,
      'send_activation_checked': _activationChecked,
      'failure': _failure,
    };
  }

  Map<String, Object?> handle(Map<String, String> parameters) {
    if (parameters['nonce'] != nonce ||
        parameters['source_sha'] != sourceSha ||
        parameters['stage_id'] != spec.id ||
        parameters['stage_nonce'] != stageNonce) {
      throw StateError('Candidate protocol identity mismatch.');
    }
    _expire();
    switch (parameters['action']) {
      case 'state':
        return state();
      case 'claim':
        _requireStage('awaiting_candidate');
        if (_remaining(_deadline) < minimumClaimRemainingMilliseconds) {
          fail('Insufficient time to issue an action lease.');
          throw StateError(_failure!);
        }
        final candidateId = parameters['candidate_id'];
        if (candidateId == null ||
            !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(candidateId)) {
          throw StateError('A native candidate inspection ID is required.');
        }
        _lastSnapshot = readSnapshot();
        if (!matchesComposing(_lastSnapshot!)) {
          fail('Input changed before the native candidate claim.');
          throw StateError(_failure!);
        }
        _candidateId = candidateId;
        _leaseId = newLeaseId();
        _claimedAt = elapsedMilliseconds();
        _leaseExpiresAt = _claimedAt! + actionLeaseMilliseconds;
        _nativeDrained = false;
        _move('action_claimed');
        return state();
      case 'result':
        _requireStage('action_claimed');
        if (parameters['lease_id'] != _leaseId ||
            parameters['candidate_id'] != _candidateId) {
          throw StateError('Candidate result does not own the action lease.');
        }
        if (parameters['clicked'] != 'true' ||
            parameters['native_drained'] != 'true') {
          fail('Native candidate click failed: ${parameters['error']}.');
          return state();
        }
        _nativeDrained = true;
        _clicked = true;
        _move('awaiting_commit');
        return state();
      case 'drained':
        if (_stage != 'failed' ||
            _leaseId == null ||
            parameters['lease_id'] != _leaseId) {
          throw StateError(
            'Native drain does not match the issued action lease.',
          );
        }
        // Cleanup can release a failed target, but never revive its outcome.
        _nativeDrained = true;
        _move(_stage);
        return state();
      case 'abort':
        fail('Native driver aborted: ${parameters['error'] ?? 'unspecified'}.');
        return state();
      default:
        throw StateError('Unknown candidate protocol action.');
    }
  }

  void offerCandidate() {
    _requireStage('preparing');
    _lastSnapshot = readSnapshot();
    if (!matchesComposing(_lastSnapshot!)) {
      throw StateError('The actual Android composing state has not appeared.');
    }
    _move('awaiting_candidate');
  }

  void beginSend() {
    _requireStage('awaiting_commit');
    _lastSnapshot = readSnapshot();
    if (!_clicked || !_nativeDrained || !matchesCommitted(_lastSnapshot!)) {
      throw StateError('An unchanged, committed native candidate is required.');
    }
    _move('sending');
  }

  /// Rechecks the real editor synchronously after all asynchronous reveal work.
  /// [snapshot] must come from the live widget, not a preserved VM observation.
  void guardSendActivation(Map<String, Object?> snapshot) {
    _requireStage('sending');
    if (_activationChecked) {
      throw StateError('The original Send activation was already checked.');
    }
    _lastSnapshot = snapshot;
    if (!_nativeDrained || !_clicked || !matchesCommitted(snapshot)) {
      fail('The live Chat input changed before the original Send activation.');
      throw StateError(_failure!);
    }
    _activationChecked = true;
    _move('sending');
  }

  /// The original full journey may take time before Chat. Start the shorter
  /// candidate deadline only when its pre-Send hook is actually reached.
  void beginCandidateWindow({int milliseconds = 120000}) {
    _requireStage('preparing');
    if (_candidateDeadline != null || milliseconds <= 0) {
      throw StateError('The candidate window can only start once.');
    }
    _candidateDeadline = elapsedMilliseconds() + milliseconds;
  }

  void pass({bool captureSnapshot = true}) {
    _requireStage('sending');
    if (!_activationChecked) {
      throw StateError('The original Send activation guard did not run.');
    }
    if (captureSnapshot) _lastSnapshot = readSnapshot();
    _move('passed');
  }

  void fail(String reason) {
    if (_stage == 'passed' || _stage == 'failed') return;
    _failure = reason;
    _move('failed');
  }

  void _requireStage(String expected) {
    _expire();
    if (_stage != expected) {
      throw StateError('Expected $expected; candidate stage is $_stage.');
    }
  }

  void _expire() {
    if (_stage == 'passed' || _stage == 'failed') return;
    if (_remaining(_deadline) == 0) {
      fail('Candidate target exceeded its overall deadline.');
    } else if ((_stage == 'action_claimed' ||
            _stage == 'awaiting_commit' ||
            (_stage == 'sending' && !_activationChecked)) &&
        leaseRemainingMilliseconds == 0) {
      fail('Native candidate action lease expired.');
    }
  }

  int get _deadline {
    final candidate = _stage == 'sending' ? null : _candidateDeadline;
    return candidate == null || candidate > deadlineMilliseconds
        ? deadlineMilliseconds
        : candidate;
  }

  int _remaining(int deadline) {
    final remaining = deadline - elapsedMilliseconds();
    return remaining < 0 ? 0 : remaining;
  }

  void _move(String stage) {
    _stage = stage;
    events.add(<String, Object?>{
      'stage': stage,
      'elapsed_ms': elapsedMilliseconds(),
      'snapshot': _lastSnapshot,
      'native_drained': _nativeDrained,
      if (_failure != null) 'failure': _failure,
      if (_leaseId != null) 'lease_id': _leaseId,
    });
  }

  bool matchesComposing(Map<String, Object?> snapshot) =>
      isComposingCandidate(snapshot, spec: spec);
  bool matchesCommitted(Map<String, Object?> snapshot) =>
      isCommittedCandidate(snapshot, spec: spec);

  static bool _sameFocusedText(
    Map<String, Object?> snapshot,
    AndroidCandidateStageSpec spec,
  ) {
    final input = snapshot['input'];
    return input is Map &&
        input['text'] == spec.text &&
        input['selectionBase'] == spec.selectionOffset &&
        input['selectionExtent'] == spec.selectionOffset &&
        snapshot['editor_primary_focus'] == true &&
        snapshot['send_count'] == 1 &&
        snapshot['view_insets_bottom_physical'] is num &&
        (snapshot['view_insets_bottom_physical']! as num) > 0 &&
        snapshot['observation_error'] == null;
  }

  static bool isComposingCandidate(
    Map<String, Object?> snapshot, {
    AndroidCandidateStageSpec spec = AndroidCandidateStageSpec.chatSend,
  }) {
    final input = snapshot['input'];
    return _sameFocusedText(snapshot, spec) &&
        input is Map &&
        input['composingBase'] == spec.composingBase &&
        input['composingExtent'] == spec.composingExtent &&
        snapshot['send_enabled_semantics'] == 'isFalse';
  }

  static bool isCommittedCandidate(
    Map<String, Object?> snapshot, {
    AndroidCandidateStageSpec spec = AndroidCandidateStageSpec.chatSend,
  }) {
    final input = snapshot['input'];
    return _sameFocusedText(snapshot, spec) &&
        input is Map &&
        input['composingBase'] == -1 &&
        input['composingExtent'] == -1 &&
        snapshot['send_enabled_semantics'] == 'isTrue' &&
        (spec != AndroidCandidateStageSpec.promptCommand ||
            (snapshot['commands_label_count'] == 1 &&
                snapshot['restock_option_count'] == 1 &&
                snapshot['restock_option_enabled'] == 'isTrue'));
  }
}
