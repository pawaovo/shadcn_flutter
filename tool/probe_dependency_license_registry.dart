// Run from packages/beautiful_ai_ui_catalog:
// flutter test ../../tool/probe_dependency_license_registry.dart --no-pub
//
// This reads Flutter's real generated NOTICES.Z through LicenseRegistry. It
// never registers synthetic licenses or replaces the asset loader.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

String _normalized(String text) => text.split(RegExp(r'\s+')).join(' ').trim();

Directory _repositoryRoot() {
  var directory = Directory.current;
  while (!File('${directory.path}/legal/dependency_assets.json').existsSync()) {
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Run this probe from inside the repository.');
    }
    directory = parent;
  }
  return directory;
}

void main() {
  // TestWidgetsFlutterBinding intentionally suppresses initLicenses. This
  // non-widget probe uses the production binding and the real generated bundle.
  WidgetsFlutterBinding.ensureInitialized();

  test('generated LicenseRegistry contains complete dependency asset notices', () async {
    final root = _repositoryRoot();
    final inventory = jsonDecode(
      File('${root.path}/legal/dependency_assets.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final expected = <String, String>{};
    for (final value in inventory['licenses'] as List<dynamic>) {
      final license = value as Map<String, dynamic>;
      final body = File('${root.path}/${license['file']}').readAsStringSync();
      for (final label in license['notice_labels'] as List<dynamic>) {
        expected[label as String] = _normalized(body);
      }
    }
    for (final value
        in inventory['required_additional_notices'] as List<dynamic>) {
      final item = value as Map<String, dynamic>;
      var body = File('${root.path}/${item['license_file']}')
          .readAsStringSync();
      if (item.containsKey('source_label')) {
        final separator = '\n${'-' * 80}\n';
        body = body.split(separator).singleWhere((block) {
          final names = block.substring(0, block.indexOf('\n\n')).split('\n');
          return names.contains(item['source_label']);
        });
        body = body.substring(body.indexOf('\n\n') + 2);
      }
      expected[item['label'] as String] = _normalized(body);
    }
    final actual = <String, List<String>>{};
    await for (final entry in LicenseRegistry.licenses) {
      final text = _normalized(entry.paragraphs.map((p) => p.text).join('\n'));
      for (final package in entry.packages) {
        actual.putIfAbsent(package, () => <String>[]).add(text);
      }
    }
    for (final entry in expected.entries) {
      expect(
        actual[entry.key],
        contains(entry.value),
        reason: 'Missing complete generated license text for ${entry.key}',
      );
    }
    debugPrint(
      'Verified ${expected.length} complete license labels through Flutter LicenseRegistry.',
    );
  });
}
