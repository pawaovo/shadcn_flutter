import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

String _normalized(String text) => text.split(RegExp(r'\s+')).join(' ').trim();

void main() {
  // Production binding reads the real generated bundle. The widget-test
  // binding suppresses initLicenses and cannot verify this distribution path.
  WidgetsFlutterBinding.ensureInitialized();

  test(
    'isolated consumer registers the complete generated package notices',
    () async {
      final expected = (jsonDecode(
        File('expected_notices.json').readAsStringSync(),
      ) as Map<String, dynamic>).cast<String, String>();
      final actual = <String, List<String>>{};
      await for (final entry in LicenseRegistry.licenses) {
        final text = _normalized(
          entry.paragraphs.map((p) => p.text).join('\n'),
        );
        for (final label in entry.packages) {
          actual.putIfAbsent(label, () => <String>[]).add(text);
        }
      }
      final missing = <String>[
        for (final entry in expected.entries)
          if (!(actual[entry.key]?.contains(_normalized(entry.value)) ?? false))
            entry.key,
      ]..sort();
      final labels = expected.keys.toList()..sort();
      File('license_probe_result.json').writeAsStringSync(
        jsonEncode(<String, Object>{
          'passed': missing.isEmpty,
          'expected_complete_labels': labels,
          'missing_complete_labels': missing,
          'generated_registry_label_count': actual.length,
          'production_binding': true,
          'synthetic_license_entries': false,
        }),
      );
      expect(
        missing,
        isEmpty,
        reason: 'Missing complete generated license text',
      );
    },
  );
}
