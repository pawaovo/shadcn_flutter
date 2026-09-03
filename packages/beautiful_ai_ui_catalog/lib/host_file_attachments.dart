import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';

/// Opt-in real host I/O. The default Catalog journey keeps its sample callback.
const catalogRealFiles = bool.fromEnvironment('CATALOG_REAL_FILES');

/// Receipt for bytes actually read by the Catalog host after file selection.
final class CatalogFileReceipt {
  const CatalogFileReceipt({
    required this.attachment,
    required this.byteCount,
    required this.sha256,
  });

  final BeautifulPromptAttachment attachment;
  final int byteCount;
  final String sha256;

  String get summary =>
      '${attachment.label} · $byteCount bytes · SHA-256 $sha256';
}

/// Maps user-selected files to the existing presentation-only attachment API.
///
/// Bytes are streamed locally to a digest, never uploaded or persisted here.
/// All files must be readable before any attachment from that pick is accepted.
final class CatalogFileAttachments {
  CatalogFileAttachments({Future<List<XFile>> Function()? pickFiles})
    : _pickFiles = pickFiles ?? openFiles;

  final Future<List<XFile>> Function() _pickFiles;
  final Map<String, CatalogFileReceipt> _receipts = {};
  var _nextId = 0;

  Future<List<BeautifulPromptAttachment>> pick() async {
    final files = await _pickFiles();
    final selected = <CatalogFileReceipt>[];
    for (final file in files) {
      var byteCount = 0;
      final digest = await sha256
          .bind(
            file.openRead().map((chunk) {
              byteCount += chunk.length;
              return chunk;
            }),
          )
          .first;
      final name = file.name;
      if (name.isEmpty) {
        throw const FormatException('The selected file has no filename.');
      }
      selected.add(
        CatalogFileReceipt(
          attachment: BeautifulPromptAttachment(
            id: 'local-file-${++_nextId}',
            label: name,
          ),
          byteCount: byteCount,
          sha256: digest.toString(),
        ),
      );
    }
    for (final receipt in selected) {
      _receipts[receipt.attachment.id] = receipt;
    }
    return List<BeautifulPromptAttachment>.unmodifiable(
      selected.map((receipt) => receipt.attachment),
    );
  }

  List<CatalogFileReceipt> receiptsFor(
    List<BeautifulPromptAttachment> attachments,
  ) => List<CatalogFileReceipt>.unmodifiable(
    attachments.map((attachment) {
      final receipt = _receipts[attachment.id];
      if (receipt == null) {
        throw StateError('Attachment was not read by this Catalog host.');
      }
      return receipt;
    }),
  );
}
