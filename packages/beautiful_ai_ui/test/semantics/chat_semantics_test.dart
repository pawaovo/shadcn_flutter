import 'dart:async';
import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets(
    'composer exposes its value and send exposes disabled then enabled state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final sent = <String>[];
      await tester.pumpWidget(_app(onSend: sent.add));
      var send = tester
          .getSemantics(find.bySemanticsLabel('Send'))
          .getSemanticsData();
      expect(send.flagsCollection.isButton, isTrue);
      expect(send.flagsCollection.isEnabled, ui.Tristate.isFalse);
      final emptyField = tester
          .getSemantics(find.bySemanticsLabel('Chat prompt'))
          .getSemanticsData();
      // A non-none Tristate exports hasEnabledState to the native bridges.
      expect(emptyField.flagsCollection.isEnabled, isNot(ui.Tristate.none));
      expect(emptyField.flagsCollection.isEnabled, ui.Tristate.isTrue);
      await tester.enterText(find.byType(EditableText), 'A useful question');
      await tester.pump();
      final field = tester
          .getSemantics(find.bySemanticsLabel('Chat prompt'))
          .getSemanticsData();
      expect(field.flagsCollection.isTextField, isTrue);
      expect(field.flagsCollection.isEnabled, ui.Tristate.isTrue);
      expect(field.value, 'A useful question');
      expect(field.hasAction(SemanticsAction.setText), isTrue);
      send = tester
          .getSemantics(find.bySemanticsLabel('Send'))
          .getSemanticsData();
      expect(send.flagsCollection.isEnabled, ui.Tristate.isTrue);
      tester.semantics.tap(find.semantics.byLabel('Send'));
      await tester.pump();
      expect(sent, ['A useful question']);
      semantics.dispose();
    },
  );

  testWidgets('pending send is disabled with explicit progress wording', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final completion = Completer<void>();
    await tester.pumpWidget(_app(onSend: (_) => completion.future));
    await tester.enterText(find.byType(EditableText), 'Question');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    final pending = tester
        .getSemantics(find.bySemanticsLabel('Sending…'))
        .getSemanticsData();
    expect(pending.flagsCollection.isButton, isTrue);
    expect(pending.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(pending.hasAction(SemanticsAction.tap), isFalse);
    completion.complete();
    await tester.pump();
    semantics.dispose();
  });

  testWidgets(
    'messages retain author attribution and avoid token live regions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          messages: const [
            BeautifulChatMessage(
              id: 'user',
              role: BeautifulChatRole.user,
              text: 'My question',
            ),
            BeautifulChatMessage(
              id: 'assistant',
              role: BeautifulChatRole.assistant,
              title: 'Sales',
              text: 'Partial answer',
              isResolving: true,
            ),
          ],
        ),
      );
      final user = tester
          .getSemantics(
            find.bySemanticsLabel(RegExp('You.*My question', dotAll: true)),
          )
          .getSemanticsData();
      final assistant = tester
          .getSemantics(
            find.bySemanticsLabel(
              RegExp('Assistant.*Partial answer', dotAll: true),
            ),
          )
          .getSemanticsData();
      expect(user.label, contains('My question'));
      expect(assistant.label, contains('Sales'));
      expect(assistant.label, contains('In progress'));
      expect(assistant.flagsCollection.isLiveRegion, isFalse);
      semantics.dispose();
    },
  );

  testWidgets(
    'controlled tabs expose selected state and support semantic activation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final selected = <String>[];
      await tester.pumpWidget(_app(onTabChanged: selected.add));
      final flavors = tester
          .getSemantics(find.bySemanticsLabel('Flavors'))
          .getSemanticsData();
      final suppliers = tester
          .getSemantics(find.bySemanticsLabel('Suppliers'))
          .getSemanticsData();
      expect(flavors.flagsCollection.isSelected, ui.Tristate.isTrue);
      expect(suppliers.flagsCollection.isSelected, ui.Tristate.isFalse);
      tester.semantics.tap(find.semantics.byLabel('Suppliers'));
      await tester.pump();
      expect(selected, ['suppliers']);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Flavors'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'response status and localized error announce once without duplicating text',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          status: BeautifulChatStatus.responding,
          responseId: 'reply-1',
          errorText: 'Connection interrupted',
        ),
      );
      for (final label in ['Responding…', 'Connection interrupted']) {
        final finder = find.bySemanticsLabel(label);
        expect(finder, findsOneWidget);
        final data = tester.getSemantics(finder).getSemanticsData();
        expect(data.role, isNot(SemanticsRole.status));
        expect(data.flagsCollection.isLiveRegion, isTrue);
      }
      final stop = tester
          .getSemantics(find.bySemanticsLabel('Stop response'))
          .getSemanticsData();
      expect(stop.flagsCollection.isButton, isTrue);
      semantics.dispose();
    },
  );

  testWidgets('composer and context actions satisfy Android and iOS targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.enterText(find.byType(EditableText), 'Ready');
    await tester.pump();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('changed host status updates the native live-region label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    late StateSetter updateHost;
    var errorText = 'Connection interrupted';
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return BeautifulChat(
              conversationId: 'status-update',
              messages: const [],
              errorText: errorText,
            );
          },
        ),
      ),
    );
    final previous = tester.getSemantics(find.bySemanticsLabel(errorText));
    expect(previous.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    updateHost(() => errorText = 'Connection restored; retry your message');
    await tester.pump();
    final next = tester.getSemantics(find.bySemanticsLabel(errorText));
    expect(next.id, previous.id);
    expect(next.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    expect(next.getSemanticsData().role, isNot(SemanticsRole.status));
    semantics.dispose();
  });
}

Widget _app({
  FutureOr<void> Function(String)? onSend,
  ValueChanged<String>? onTabChanged,
  List<BeautifulChatMessage> messages = const [],
  BeautifulChatStatus status = BeautifulChatStatus.idle,
  String? responseId,
  String? errorText,
}) => beautifulTestApp(
  disableAnimations: true,
  child: BeautifulChat(
    conversationId: 'semantics',
    messages: messages,
    onSend: onSend ?? (_) {},
    tabs: const [
      BeautifulChatTab(id: 'flavors', label: 'Flavors'),
      BeautifulChatTab(id: 'suppliers', label: 'Suppliers'),
    ],
    selectedTabId: 'flavors',
    onTabChanged: onTabChanged ?? (_) {},
    status: status,
    responseId: responseId,
    onStop: (_) {},
    errorText: errorText,
  ),
);
