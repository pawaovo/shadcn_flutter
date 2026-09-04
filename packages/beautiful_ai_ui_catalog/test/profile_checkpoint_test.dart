import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/profile_checkpoint.dart';

void main() {
  test(
    'checkpoint is frozen, reannounced, and only acknowledgement releases it',
    () async {
      final data = <String, dynamic>{
        'p3_performance': <String, dynamic>{'status': 'measuring'},
      };
      final events = <Map<String, Object?>>[];
      final publisher = ProfileCheckpointPublisher(
        reportData: () => data,
        timeout: const Duration(seconds: 1),
        notificationInterval: const Duration(milliseconds: 5),
        postEvent: (kind, event) {
          expect(kind, profileCheckpointEvent);
          events.add(event);
        },
      );
      var completed = false;
      final publication = publisher
          .publish(terminal: false)
          .then((_) => completed = true);
      data['p3_performance']['status'] = 'changed after publication';
      await Future<void>.delayed(const Duration(milliseconds: 16));
      expect(completed, isFalse);
      expect(events.length, greaterThan(1));
      expect(events.every((event) => event['sequence'] == '1'), isTrue);
      final snapshot = jsonDecode(
        publisher.handle({'action': 'read', 'sequence': '1'}),
      ) as Map;
      expect(snapshot['report_data']['p3_performance']['status'], 'measuring');
      publisher.handle({'action': 'ack', 'sequence': '1'});
      await publication;
      final count = events.length;
      await Future<void>.delayed(const Duration(milliseconds: 12));
      expect(
        events.length,
        count,
        reason: 'No checkpoint timer may remain active.',
      );
      expect(
        jsonDecode(
          publisher.handle({'action': 'ack', 'sequence': '1'}),
        )['acknowledged'],
        isTrue,
      );
      expect(
        () => publisher.handle({'action': 'read', 'sequence': '1'}),
        throwsStateError,
      );
    },
  );

  test(
    'duplicate old ack cannot release a later terminal checkpoint',
    () async {
      final publisher = ProfileCheckpointPublisher(
        reportData: () => {},
        postEvent: (_, _) {},
      );
      final first = publisher.publish(terminal: false);
      publisher.handle({'action': 'ack', 'sequence': '1'});
      await first;
      var completed = false;
      final second = publisher
          .publish(terminal: true)
          .then((_) => completed = true);
      publisher.handle({'action': 'ack', 'sequence': '1'});
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(
        jsonDecode(
          publisher.handle({'action': 'read', 'sequence': '2'}),
        )['terminal'],
        isTrue,
      );
      publisher.handle({'action': 'ack', 'sequence': '2'});
      await second;
    },
  );

  test(
    'missing host acknowledgement times out and cancels notification timers',
    () async {
      var events = 0;
      final publisher = ProfileCheckpointPublisher(
        reportData: () => {},
        timeout: const Duration(milliseconds: 25),
        notificationInterval: const Duration(milliseconds: 5),
        postEvent: (_, _) => events++,
      );
      await expectLater(
        publisher.publish(terminal: true),
        throwsA(isA<TimeoutException>()),
      );
      final count = events;
      await Future<void>.delayed(const Duration(milliseconds: 12));
      expect(events, count);
      expect(
        () => publisher.handle({'action': 'read', 'sequence': '1'}),
        throwsStateError,
      );
    },
  );

  test(
    'a repeated notification error fails publication and cancels its timer',
    () async {
      var notifications = 0;
      final original = StateError('notification transport failed');
      final publisher = ProfileCheckpointPublisher(
        reportData: () => {},
        notificationInterval: const Duration(milliseconds: 5),
        postEvent: (_, _) {
          if (++notifications > 1) throw original;
        },
      );
      await expectLater(
        publisher.publish(terminal: true),
        throwsA(same(original)),
      );
      final count = notifications;
      await Future<void>.delayed(const Duration(milliseconds: 12));
      expect(notifications, count);
      expect(
        () => publisher.handle({'action': 'read', 'sequence': '1'}),
        throwsStateError,
      );
    },
  );
}
