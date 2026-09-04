import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const profileTimelineTransport = 'gzip_base64_json_v1';

/// Replaces one completed VM timeline graph with a lossless transport envelope.
///
/// Call only after sampling has ended and raw FrameTiming/RSS arrays have been
/// preserved. This does not recover events already evicted by the VM recorder,
/// and it neither requests garbage collection nor claims an RSS reduction.
Map<String, Object?> compressProfileTimelineReport(
  Map<String, dynamic> reportData,
  String reportKey,
) {
  final startedAt = DateTime.now().microsecondsSinceEpoch;
  final clock = Stopwatch()..start();
  final envelope = encodeProfileTimeline(reportData[reportKey]);
  // The old graph stays available to the driver if encoding throws. Keeping
  // its reference inside this synchronous helper avoids retaining it across
  // later awaits in the workload recorder.
  reportData[reportKey] = envelope;
  clock.stop();
  return <String, Object?>{
    'encoding': profileTimelineTransport,
    'json_bytes': envelope['json_bytes'],
    'gzip_bytes': envelope['gzip_bytes'],
    'base64_characters': (envelope['data']! as String).length,
    'json_sha256': envelope['json_sha256'],
    'trace_event_count': envelope['trace_event_count'],
    'compression_start_epoch_us': startedAt,
    'compression_end_epoch_us': DateTime.now().microsecondsSinceEpoch,
    'compression_wall_time_us': clock.elapsedMicroseconds,
    'scope': 'Lossless encoding after the measured window and timing flush; the driver restores the original timeline object before writing .timeline.json. Counts describe retained VM events only. No garbage collection is forced.',
  };
}

Map<String, Object?> encodeProfileTimeline(Object? value) {
  final timeline = _timeline(value);
  final bytes = JsonUtf8Encoder().convert(timeline);
  final compressed = gzip.encode(bytes);
  return <String, Object?>{
    'profile_timeline_transport': profileTimelineTransport,
    'json_bytes': bytes.length,
    'gzip_bytes': compressed.length,
    'json_sha256': sha256.convert(bytes).toString(),
    'trace_event_count': (timeline['traceEvents']! as List).length,
    'data': base64Encode(compressed),
  };
}

/// Restores every saved event, argument and metadata field without filtering.
/// Legacy raw timeline maps remain supported for old/partial report payloads.
Map<String, dynamic> decodeProfileTimeline(Object? value) {
  if (value is! Map || !value.containsKey('profile_timeline_transport')) {
    return _timeline(value);
  }
  _require(
    value['profile_timeline_transport'] == profileTimelineTransport,
    'Unsupported profile timeline transport.',
  );
  for (final field in <String>[
    'json_bytes',
    'gzip_bytes',
    'trace_event_count',
  ]) {
    _require(
      value[field] is int && (value[field] as int) >= 0,
      'Invalid timeline $field.',
    );
  }
  _require(value['data'] is String, 'Missing encoded timeline data.');
  final digest = value['json_sha256'];
  _require(
    digest is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(digest),
    'Invalid timeline SHA-256.',
  );
  final compressed = base64Decode(value['data'] as String);
  _require(
    compressed.length == value['gzip_bytes'],
    'Encoded timeline size does not match its metadata.',
  );
  final bytes = gzip.decode(compressed);
  _require(
    bytes.length == value['json_bytes'],
    'Restored timeline size does not match its metadata.',
  );
  _require(
    sha256.convert(bytes).toString() == digest,
    'Restored timeline SHA-256 does not match its metadata.',
  );
  final timeline = _timeline(jsonDecode(utf8.decode(bytes)));
  _require(
    (timeline['traceEvents']! as List).length == value['trace_event_count'],
    'Restored timeline event count does not match its metadata.',
  );
  return timeline;
}

Map<String, dynamic> _timeline(Object? value) {
  _require(value is Map, 'Expected a VM timeline object.');
  final timeline = Map<String, dynamic>.from(value! as Map);
  _require(
    timeline['traceEvents'] is List,
    'Expected the VM timeline traceEvents array.',
  );
  return timeline;
}

void _require(bool condition, String message) {
  if (!condition) throw FormatException(message);
}
