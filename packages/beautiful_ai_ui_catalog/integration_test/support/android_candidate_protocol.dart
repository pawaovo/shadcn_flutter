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
    this.deadlineMilliseconds = 90000,
  }) {
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
      'protocol_version': 1,
      'nonce': nonce,
      'source_sha': sourceSha,
      'stage': _stage,
      'elapsed_ms': elapsedMilliseconds(),
      'remaining_ms': _remaining(_deadline),
      'expected_text': expectedText,
      'candidate_text': candidateText,
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
    if (parameters['nonce'] != nonce || parameters['source_sha'] != sourceSha) {
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
        if (!isComposingCandidate(_lastSnapshot!)) {
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
    if (!isComposingCandidate(_lastSnapshot!)) {
      throw StateError('The actual Android composing state has not appeared.');
    }
    _move('awaiting_candidate');
  }

  void beginSend() {
    _requireStage('awaiting_commit');
    _lastSnapshot = readSnapshot();
    if (!_clicked || !_nativeDrained || !isCommittedCandidate(_lastSnapshot!)) {
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
    if (!_nativeDrained || !_clicked || !isCommittedCandidate(snapshot)) {
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
    } else if ((_stage == 'action_claimed' || _stage == 'awaiting_commit') &&
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

  static bool _sameFocusedText(Map<String, Object?> snapshot) {
    final input = snapshot['input'];
    return input is Map &&
        input['text'] == expectedText &&
        input['selectionBase'] == expectedText.length &&
        input['selectionExtent'] == expectedText.length &&
        snapshot['editor_primary_focus'] == true &&
        snapshot['send_count'] == 1 &&
        snapshot['view_insets_bottom_physical'] is num &&
        (snapshot['view_insets_bottom_physical']! as num) > 0 &&
        snapshot['observation_error'] == null;
  }

  static bool isComposingCandidate(Map<String, Object?> snapshot) {
    final input = snapshot['input'];
    return _sameFocusedText(snapshot) &&
        input is Map &&
        input['composingBase'] == 11 &&
        input['composingExtent'] == 20 &&
        snapshot['send_enabled_semantics'] == 'isFalse';
  }

  static bool isCommittedCandidate(Map<String, Object?> snapshot) {
    final input = snapshot['input'];
    return _sameFocusedText(snapshot) &&
        input is Map &&
        input['composingBase'] == -1 &&
        input['composingExtent'] == -1 &&
        snapshot['send_enabled_semantics'] == 'isTrue';
  }
}
