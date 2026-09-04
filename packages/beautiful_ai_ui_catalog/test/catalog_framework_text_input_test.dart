import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/interactions.dart';

void main() {
  testWidgets('framework edit synchronizes the IME before numeric submission', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1206, 2622);
    try {
      await tester.pumpWidget(const CatalogApp());
      await tester.pump();
      final card = find.byKey(const Key('catalog-fine-tune'));
      final input = find.descendant(
        of: find.descendant(
          of: card,
          matching: find.byKey(const Key('beautiful-fine-tune-input-width')),
        ),
        matching: find.byType(EditableText),
      );
      double acceptedWidth() => tester
          .widget<BeautifulFineTuneCard>(card)
          .settings
          .fields
          .singleWhere((field) => field.id == 'width')
          .value;

      await tester.ensureVisible(input);
      expect(acceptedWidth(), 324);
      await enterCatalogText(tester, input, '360');
      expect(tester.widget<EditableText>(input).controller.text, '360');
      // Draft entry must not bypass the actual Enter/host-acceptance contract.
      expect(acceptedWidth(), 324);

      final outbound = Map<String, dynamic>.from(
        tester.testTextInput.log
                .lastWhere((call) => call.method == 'TextInput.setEditingState')
                .arguments
            as Map,
      );
      expect(outbound['text'], '360');
      // Explicit protocol echo of what Flutter actually sent to its peer.
      // A legacy tester.enterText call leaves this outbound value at 324.
      tester.testTextInput.updateEditingValue(
        TextEditingValue.fromJSON(outbound),
      );
      await tester.idle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tester.widget<EditableText>(input).controller.text, '360');
      expect(acceptedWidth(), 360);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
