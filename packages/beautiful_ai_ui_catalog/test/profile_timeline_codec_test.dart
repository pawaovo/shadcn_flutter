import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/profile_timeline_codec.dart';
import '../test_driver/p3_performance_driver.dart';

Map<String, dynamic> _timeline({int eventCount = 2}) => <String, dynamic>{
  'type': 'Timeline',
  'timeOriginMicros': 1788477760087752,
  'timeExtentMicros': 12918513,
  'traceEvents': List<Object?>.generate(
    eventCount,
    (index) => <String, Object?>{
      'name': 'frame $index · 中文 🧪',
      'ph': index.isEven ? 'B' : 'E',
      'ts': 1788477760087752 + index,
      'args': <String, Object?>{
        'frame_number': 9000000000000000 + index,
        'nested': <Object?>[
          null,
          true,
          false,
          2.5,
          -0.0,
          'quoted "value"\n\t\\',
        ],
      },
    },
  ),
  'extra_metadata': <String, Object?>{
    'keep': 'all fields, even unknown fields',
  },
};

Object? _read(Directory directory, String filename) =>
    jsonDecode(File('${directory.path}/$filename').readAsStringSync());

void main() {
  test(
    'timeline transport preserves complete JSON bytes and event ordering',
    () {
      final original = _timeline();
      final before = jsonEncode(original);
      final encoded = encodeProfileTimeline(original);
      final restored = decodeProfileTimeline(encoded);
      expect(restored, original);
      expect(jsonEncode(restored), before);
      expect(jsonEncode(original), before);
      expect(encoded['trace_event_count'], 2);
      expect(encoded['json_bytes'], utf8.encode(before).length);
    },
  );

  test(
    'empty and partial timelines retain their exact events and metadata',
    () {
      for (final count in <int>[0, 1]) {
        final original = _timeline(eventCount: count);
        expect(
          decodeProfileTimeline(encodeProfileTimeline(original)),
          original,
        );
      }
    },
  );

  test('repeated event data uses a smaller envelope without filtering', () {
    final original = _timeline(eventCount: 1000);
    final encoded = encodeProfileTimeline(original);
    expect(
      (encoded['data']! as String).length,
      lessThan((encoded['json_bytes']! as int) ~/ 3),
    );
    expect(decodeProfileTimeline(encoded), original);
    expect(encoded['trace_event_count'], 1000);
  });

  test(
    'only the completed report trace is replaced, with no raw graph copy',
    () {
      final original = _timeline();
      final samples = <String, Object?>{
        'raw_frame_timings': <int>[1, 2, 3],
      };
      final report = <String, dynamic>{
        'p3_trace_one': original,
        'p3_trace_other': _timeline(eventCount: 1),
        'p3_performance': samples,
      };
      final other = report['p3_trace_other'];
      final metadata = compressProfileTimelineReport(report, 'p3_trace_one');
      expect(report['p3_trace_one'], isNot(same(original)));
      expect(
        (report['p3_trace_one'] as Map).containsKey('traceEvents'),
        isFalse,
      );
      expect(decodeProfileTimeline(report['p3_trace_one']), original);
      expect(report['p3_trace_other'], same(other));
      expect(report['p3_performance'], same(samples));
      expect(metadata.containsKey('data'), isFalse);
      expect(metadata.containsKey('traceEvents'), isFalse);
      expect(metadata['trace_event_count'], 2);
    },
  );

  test(
    'encoding failure leaves the raw graph and independent samples intact',
    () {
      final original = <String, Object?>{
        'traceEvents': <Object?>[],
        'not_json': Object(),
      };
      final samples = <String, Object?>{
        'raw_frame_timings': <int>[1, 2, 3],
      };
      final report = <String, dynamic>{
        'p3_trace_one': original,
        'p3_performance': samples,
      };
      expect(
        () => compressProfileTimelineReport(report, 'p3_trace_one'),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(report['p3_trace_one'], same(original));
      expect(report['p3_performance'], same(samples));
    },
  );

  test('unknown, corrupt and contradictory envelopes are rejected', () {
    final original = encodeProfileTimeline(_timeline());
    for (final modification in <Map<String, Object?>>[
      <String, Object?>{'profile_timeline_transport': 'unknown_v2'},
      <String, Object?>{'data': '%not-base64'},
      <String, Object?>{'gzip_bytes': (original['gzip_bytes']! as int) + 1},
      <String, Object?>{'json_bytes': (original['json_bytes']! as int) + 1},
      <String, Object?>{'json_sha256': '0' * 64},
      <String, Object?>{'trace_event_count': 3},
    ]) {
      expect(
        () => decodeProfileTimeline(<String, Object?>{
          ...original,
          ...modification,
        }),
        throwsFormatException,
      );
    }
    final compressed = base64Decode(original['data']! as String);
    final truncated = compressed.sublist(0, compressed.length - 1);
    expect(
      () => decodeProfileTimeline(<String, Object?>{
        ...original,
        'data': base64Encode(truncated),
      }),
      throwsFormatException,
    );
  });

  test(
    'driver preserves other traces, all samples and bad payload before failing',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'profile-transport-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final original = _timeline();
      final bad = <String, Object?>{
        ...encodeProfileTimeline(original),
        'json_sha256': '0' * 64,
      };
      final data = <String, dynamic>{
        'p3_trace_raw': original,
        'p3_trace_encoded': encodeProfileTimeline(original),
        'p3_trace_bad': bad,
        'p3_performance': <String, Object?>{
          'status': 'workloads_complete',
          'scenarios': <Object?>[
            for (final id in <String>['raw', 'encoded', 'bad'])
              <String, Object?>{
                'id': id,
                'status': 'complete',
                'trace_report_key': 'p3_trace_$id',
                'raw_frame_timings': <Object?>[
                  <String, Object?>{'frame_number': 1, 'build_us': 123},
                ],
                'rss_samples': <Object?>[
                  <String, Object?>{'current_rss_bytes': 456},
                ],
              },
          ],
        },
      };
      await expectLater(
        writeProfilePerformanceEvidence(data, directory),
        throwsStateError,
      );
      expect(_read(directory, 'p3_trace_raw.timeline.json'), original);
      expect(_read(directory, 'p3_trace_encoded.timeline.json'), original);
      expect(_read(directory, 'p3_trace_bad.transport_failure.json'), bad);
      expect(
        File('${directory.path}/p3_trace_bad.timeline.json').existsSync(),
        isFalse,
      );
      final frames = _read(directory, 'p3_frame_samples.json')! as Map;
      final memory = _read(directory, 'p3_memory_samples.json')! as Map;
      expect(frames.keys, <String>['raw', 'encoded', 'bad']);
      expect(memory.keys, <String>['raw', 'encoded', 'bad']);
      expect((frames['bad'] as List).single, <String, int>{
        'frame_number': 1,
        'build_us': 123,
      });
      expect((memory['bad'] as List).single, <String, int>{
        'current_rss_bytes': 456,
      });
      final report = _read(directory, 'p3_performance.json')! as Map;
      expect(report['status'], 'failed_timeline_decode');
      expect(
        report['workload_status_before_timeline_decode_failure'],
        'workloads_complete',
      );
      expect(
        (report['driver'] as Map)['timeline_decode_failures'],
        contains('p3_trace_bad'),
      );
    },
  );
}
