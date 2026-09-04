import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../integration_test/support/profile_timeline_codec.dart';

/// Replays transport against existing driver artifacts without changing them.
void main(List<String> arguments) {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/verify_profile_timeline_codec.dart <driver.timeline.json> [...]',
    );
    exitCode = 64;
    return;
  }
  final results = <Map<String, Object?>>[];
  for (final path in arguments) {
    final originalBytes = File(path).readAsBytesSync();
    final original = jsonDecode(utf8.decode(originalBytes));
    final encoded = encodeProfileTimeline(original);
    final restored = decodeProfileTimeline(encoded);
    final restoredBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(restored),
    );
    final originalDigest = sha256.convert(originalBytes).toString();
    final restoredDigest = sha256.convert(restoredBytes).toString();
    final sameContent = jsonEncode(original) == jsonEncode(restored);
    final sameDriverBytes = originalDigest == restoredDigest;
    results.add(<String, Object?>{
      'file': File(path).absolute.path,
      'original_driver_json_bytes': originalBytes.length,
      'transport_envelope_json_bytes': JsonUtf8Encoder()
          .convert(encoded)
          .length,
      'compact_json_bytes': encoded['json_bytes'],
      'gzip_bytes': encoded['gzip_bytes'],
      'trace_event_count': encoded['trace_event_count'],
      'original_file_sha256': originalDigest,
      'restored_file_sha256': restoredDigest,
      'json_content_unchanged': sameContent,
      'exact_driver_output_bytes_unchanged': sameDriverBytes,
    });
    if (!sameContent || !sameDriverBytes) exitCode = 1;
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
}
