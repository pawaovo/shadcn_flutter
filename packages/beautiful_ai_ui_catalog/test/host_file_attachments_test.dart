import 'dart:io';
import 'dart:typed_data';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:beautiful_ai_ui_catalog/host_file_attachments.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'multiple files preserve names, order and actual byte receipts',
    () async {
      final host = CatalogFileAttachments(
        pickFiles: () async => <XFile>[
          _memoryFile(' report.txt ', [97, 98, 99]),
          _memoryFile('空文件.csv', []),
        ],
      );

      final attachments = await host.pick();
      expect(attachments.map((file) => file.label), [
        ' report.txt ',
        '空文件.csv',
      ]);
      expect(attachments.map((file) => file.id).toSet(), hasLength(2));
      final receipts = host.receiptsFor(attachments);
      expect(receipts.map((file) => file.byteCount), [3, 0]);
      expect(receipts.map((file) => file.sha256), [
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      ]);
    },
  );

  test('cancelling a later picker retains existing draft receipts', () async {
    var invocation = 0;
    final host = CatalogFileAttachments(
      pickFiles: () async => invocation++ == 0
          ? [
              _memoryFile('retained.bin', [1]),
            ]
          : [],
    );
    final previous = await host.pick();

    expect(await host.pick(), isEmpty);
    expect(host.receiptsFor(previous).single.byteCount, 1);
  });

  test(
    'same filenames from separate picks retain independent identity',
    () async {
      final host = CatalogFileAttachments(
        pickFiles: () async => [_memoryFile('same.txt', [])],
      );
      final first = await host.pick();
      final second = await host.pick();

      expect(first.single.id, isNot(second.single.id));
      expect(host.receiptsFor([...first, ...second]), hasLength(2));
    },
  );

  test('native picker errors propagate without creating attachments', () async {
    final error = StateError('native picker unavailable');
    final host = CatalogFileAttachments(pickFiles: () async => throw error);

    await expectLater(host.pick(), throwsA(same(error)));
    expect(host.receiptsFor([]), isEmpty);
  });

  test(
    'one unreadable file rejects the entire new batch and allows retry',
    () async {
      final directory = await Directory.systemTemp.createTemp('catalog-files-');
      addTearDown(() => directory.delete(recursive: true));
      final existing = File('${directory.path}/真实文件.txt');
      await existing.writeAsBytes([97, 98, 99]);
      var invocation = 0;
      final host = CatalogFileAttachments(
        pickFiles: () async => invocation++ == 0
            ? [XFile(existing.path), XFile('${directory.path}/missing.txt')]
            : [XFile(existing.path)],
      );

      await expectLater(host.pick(), throwsA(isA<FileSystemException>()));
      expect(
        () => host.receiptsFor([
          const BeautifulPromptAttachment(
            id: 'local-file-1',
            label: '真实文件.txt',
          ),
        ]),
        throwsStateError,
      );
      final retry = await host.pick();
      expect(host.receiptsFor(retry).single.byteCount, 3);
      expect(host.receiptsFor(retry).single.attachment.label, '真实文件.txt');
    },
  );

  test('submission cannot claim a file the host did not read', () {
    final host = CatalogFileAttachments(pickFiles: () async => []);

    expect(
      () => host.receiptsFor([
        const BeautifulPromptAttachment(
          id: 'sample-only',
          label: 'inventory.csv',
        ),
      ]),
      throwsStateError,
    );
  });
}

XFile _memoryFile(String name, List<int> bytes) =>
    XFile.fromData(Uint8List.fromList(bytes), path: name, name: name);
