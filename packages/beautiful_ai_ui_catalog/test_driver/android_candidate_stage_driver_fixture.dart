import 'dart:convert';
import 'dart:io';

import '../integration_test/driver/catalog_android_candidate_driver.dart'
    as driver;
import '../integration_test/support/android_candidate_protocol.dart';

/// Production protocol and driver bookkeeping in one Dart process. All native
/// receipts are explicit fixtures; no OS input or application acceptance occurs.
Future<void> main() async {
  final nonce = 'a' * 32;
  final sha = 'b' * 40;
  var elapsed = 100;
  var nextNonce = 0;
  var nextLease = 0;
  final checks = <String>[];
  final sequence = AndroidCandidateSequence(
    nonce: nonce,
    sourceSha: sha,
    elapsedMilliseconds: () => elapsed,
    newStageNonce: () => '${++nextNonce}'.padLeft(32, '0'),
    newLeaseId: () => 'lease-${++nextLease}',
  );
  final stages = driver.AndroidCandidateDriverStages(nonce, sha);
  Map<String, String>? oldIdentity;

  void require(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks.add(label);
  }

  Future<void> rejects(String label, Future<void> Function() action) async {
    var rejected = false;
    try {
      await action();
    } on StateError {
      rejected = true;
    }
    require(rejected, label);
  }

  Map<String, String> request(
    String action,
    Map<String, String> identity, [
    Map<String, String> fields = const <String, String>{},
  ]) => <String, String>{
    'action': action,
    'nonce': nonce,
    'source_sha': sha,
    ...identity,
    ...fields,
  };

  Map<String, Object?> snapshot(
    AndroidCandidateStageSpec spec,
    bool committed,
  ) => <String, Object?>{
    'input': <String, Object?>{
      'text': spec.text,
      'selectionBase': spec.selectionOffset,
      'selectionExtent': spec.selectionOffset,
      'composingBase': committed ? -1 : spec.composingBase,
      'composingExtent': committed ? -1 : spec.composingExtent,
    },
    'editor_primary_focus': true,
    'send_count': 1,
    'send_enabled_semantics': committed ? 'isTrue' : 'isFalse',
    'view_insets_bottom_physical': 900,
    'observation_error': null,
    if (spec.id == 'prompt_command' && committed) ...<String, Object?>{
      'commands_label_count': 1,
      'restock_option_count': 1,
      'restock_option_enabled': 'isTrue',
    },
  };

  await rejects('missing complete journey is rejected', () async {
    stages.requireComplete(sequence.state(), allTestsPassed: true);
  });
  for (final spec in AndroidCandidateStageSpec.ordered) {
    final session = sequence.enterStage(spec.id);
    var editing = snapshot(spec, false);
    session.readSnapshot = () => editing;
    session.protocol.beginCandidateWindow();
    session.protocol.offerCandidate();
    final stage = stages.observe(sequence.state())!;
    stages.requirePredecessorsFinished(stage);
    if (oldIdentity != null) {
      for (final action in <String>[
        'state',
        'claim',
        'result',
        'drained',
        'abort',
      ]) {
        await rejects(
          'late ${oldIdentity['stage_id']} $action rejected by actual protocol',
          () async {
            await sequence.request(
              request(action, oldIdentity!, <String, String>{
                'candidate_id': 'old-ticket',
                'lease_id': 'old-lease',
                'clicked': 'true',
                'native_drained': 'true',
              }),
            );
          },
        );
      }
      await rejects('late native receipt cannot enter ${spec.id}', () async {
        stage.verify(<String, Object?>{...oldIdentity!});
      });
    }
    await rejects('wrong stage nonce rejects ${spec.id} claim', () async {
      await sequence.request(
        request(
          'claim',
          <String, String>{...stage.identity, 'stage_nonce': 'f' * 32},
          <String, String>{'candidate_id': 'ticket'},
        ),
      );
    });
    stage.beginAttempt();
    await rejects('native attempt cannot repeat for ${spec.id}', () async {
      stage.beginAttempt();
    });
    final candidate = 'fixture-ticket-${spec.id}';
    final claim = await sequence.request(
      request('claim', stage.identity, <String, String>{
        'candidate_id': candidate,
      }),
    );
    stage.leaseId = claim['lease_id']! as String;
    await rejects(
      'undrained fixture receipt rejected for ${spec.id}',
      () async {
        stage.acceptClick(<String, Object?>{
          ...stage.identity,
          'clicked': true,
          'native_drained': false,
          'used_candidate_id': candidate,
        }, candidateId: candidate);
      },
    );
    stage.acceptClick(<String, Object?>{
      ...stage.identity,
      'clicked': true,
      'native_drained': true,
      'used_candidate_id': candidate,
      'scope': 'fixture_only',
    }, candidateId: candidate);
    await rejects('duplicate native receipt rejected for ${spec.id}', () async {
      stage.acceptClick(<String, Object?>{
        ...stage.identity,
        'clicked': true,
        'native_drained': true,
        'used_candidate_id': candidate,
      }, candidateId: candidate);
    });
    await sequence.request(
      request('result', stage.identity, <String, String>{
        'candidate_id': candidate,
        'lease_id': stage.leaseId!,
        'clicked': 'true',
        'native_drained': 'true',
      }),
    );
    editing = snapshot(spec, true);
    session.protocol.beginSend();
    session.protocol.guardSendActivation(editing);
    session.rpc.freeze();
    sequence.completeStage(spec.id);
    stages.observe(sequence.state());
    await rejects(
      'stage cannot pass before helper drain for ${spec.id}',
      () async {
        stage.acceptFinish(<String, Object?>{
          ...stage.identity,
          'native_drained': false,
          'helper_stopped': true,
          'cleanup_verified': true,
        });
      },
    );
    stage.acceptFinish(<String, Object?>{
      ...stage.identity,
      'native_drained': true,
      'helper_stopped': true,
      'cleanup_verified': true,
    });
    elapsed += 6000;
    stages.observe(sequence.state()); // Live elapsed fields are not immutable.
    if (spec.id != AndroidCandidateStageSpec.ordered.last.id) {
      await rejects(
        'partial stage sequence is not complete after ${spec.id}',
        () async {
          stages.requireComplete(sequence.state(), allTestsPassed: true);
        },
      );
    }
    oldIdentity = stage.identity;
  }
  await rejects(
    'three stages alone do not replace full journey result',
    () async {
      stages.requireComplete(sequence.state(), allTestsPassed: true);
    },
  );
  sequence.finishJourney(true);
  await rejects('false original full response is rejected', () async {
    stages.requireComplete(sequence.state(), allTestsPassed: false);
  });
  stages.requireComplete(sequence.state(), allTestsPassed: true);
  require(
    stages.clickCount == 3,
    'three ordered fixture receipts and full result verified',
  );
  final valid = sequence.state();
  await rejects('changed source ledger is rejected', () async {
    stages.observe(<String, Object?>{...valid, 'source_sha': 'c' * 40});
  });
  await rejects('completed ledger rollback is rejected', () async {
    stages.observe(<String, Object?>{
      ...valid,
      'completed_stage_ids': <String>[],
      'stage_results': <Object?>[],
    });
  });
  stdout.writeln(
    jsonEncode(<String, Object?>{
      'scope': 'plain Dart production sequence and driver protocol bookkeeping',
      'native_receipts': 'explicit fixtures only',
      'application_acceptance': 'not_exercised',
      'status': 'passed',
      'checks': checks.length,
      'verified': checks,
    }),
  );
}
