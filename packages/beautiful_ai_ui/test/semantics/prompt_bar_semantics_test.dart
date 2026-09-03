import 'dart:async';
import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets('prompt exposes native editing value and send enabled state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final sent = <BeautifulPromptSubmission>[];
    await tester.pumpWidget(
      _app(BeautifulPromptBar(composerId: 'one', onSend: sent.add)),
    );
    var send = tester
        .getSemantics(find.bySemanticsLabel('Send'))
        .getSemanticsData();
    expect(send.flagsCollection.isButton, isTrue);
    expect(send.flagsCollection.isEnabled, ui.Tristate.isFalse);
    await tester.enterText(find.byType(EditableText), 'A precise request');
    await tester.pump();
    final field = tester
        .getSemantics(find.bySemanticsLabel('Prompt'))
        .getSemanticsData();
    expect(field.flagsCollection.isTextField, isTrue);
    expect(field.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(field.value, 'A precise request');
    expect(field.hasAction(SemanticsAction.setText), isTrue);
    send = tester
        .getSemantics(find.bySemanticsLabel('Send'))
        .getSemanticsData();
    expect(send.flagsCollection.isEnabled, ui.Tristate.isTrue);
    tester.semantics.tap(find.semantics.byLabel('Send'));
    await tester.pump();
    expect(sent.single.text, 'A precise request');
    semantics.dispose();
  });

  testWidgets('pending send has disabled button semantics and explicit label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final completion = Completer<void>();
    await tester.pumpWidget(
      _app(
        BeautifulPromptBar(
          composerId: 'one',
          initialDraft: 'Send me',
          onSend: (_) => completion.future,
        ),
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('Send'));
    await tester.pump();
    final send = tester
        .getSemantics(find.bySemanticsLabel('Sending…'))
        .getSemanticsData();
    expect(send.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(send.hasAction(SemanticsAction.tap), isFalse);
    completion.complete();
    await tester.pump();
    semantics.dispose();
  });

  testWidgets(
    'model disclosure exposes controlled selection and full descriptions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final selected = <String>[];
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            models: const [
              BeautifulPromptModel(
                id: 'fast',
                label: 'Fast model',
                description: 'Quick answers',
              ),
              BeautifulPromptModel(
                id: 'deep',
                label: 'Detailed model',
                description: 'Longer reasoning',
              ),
            ],
            selectedModelId: 'fast',
            onModelChanged: selected.add,
          ),
        ),
      );
      final trigger = find.bySemanticsLabel('Choose model: Fast model');
      expect(
        tester
            .getSemantics(trigger)
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        ui.Tristate.isFalse,
      );
      tester.semantics.tap(find.semantics.byLabel('Choose model: Fast model'));
      await tester.pump();
      expect(
        tester
            .getSemantics(trigger)
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        ui.Tristate.isTrue,
      );
      final fast = tester
          .getSemantics(find.bySemanticsLabel('Fast model\nQuick answers'))
          .getSemanticsData();
      final deep = tester
          .getSemantics(
            find.bySemanticsLabel('Detailed model\nLonger reasoning'),
          )
          .getSemanticsData();
      expect(fast.flagsCollection.isSelected, ui.Tristate.isTrue);
      expect(deep.flagsCollection.isSelected, ui.Tristate.isFalse);
      tester.semantics.tap(
        find.semantics.byLabel('Detailed model\nLonger reasoning'),
      );
      await tester.pump();
      expect(selected, ['deep']);
      expect(
        find.bySemanticsLabel('Detailed model\nLonger reasoning'),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Choose model: Fast model'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'source connection is an independent named action with pending state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final connection = Completer<void>();
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            sources: const [
              BeautifulPromptSource(
                id: 'secure',
                label: 'Secure records',
                description: 'Workspace content',
                connected: false,
              ),
            ],
            onConnectSource: (_) => connection.future,
          ),
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('Add sources and files'));
      await tester.pump();
      const readyLabel = 'Secure records\nWorkspace content\nConnect';
      final source = tester
          .getSemantics(find.bySemanticsLabel(readyLabel))
          .getSemanticsData();
      expect(source.flagsCollection.isButton, isTrue);
      expect(source.flagsCollection.isEnabled, ui.Tristate.isTrue);
      tester.semantics.tap(find.semantics.byLabel(readyLabel));
      await tester.pump();
      final pending = tester
          .getSemantics(
            find.bySemanticsLabel(
              'Secure records\nWorkspace content\nConnecting…',
            ),
          )
          .getSemanticsData();
      expect(pending.flagsCollection.isEnabled, ui.Tristate.isFalse);
      connection.complete();
      await tester.pump();
      semantics.dispose();
    },
  );

  testWidgets(
    'dictation and changed errors use native live regions without duplicate children',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final dictation = Completer<String?>();
      var error = 'Microphone unavailable';
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeautifulPromptBar(
                composerId: 'one',
                errorText: error,
                onDictate: () => dictation.future,
                onStopDictation: () {},
              );
            },
          ),
        ),
      );
      final original = tester.getSemantics(find.bySemanticsLabel(error));
      expect(original.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      update(() => error = 'Microphone ready');
      await tester.pump();
      final updated = tester.getSemantics(find.bySemanticsLabel(error));
      expect(updated.id, original.id);
      expect(updated.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(updated.getSemanticsData().role, isNot(SemanticsRole.status));
      tester.semantics.tap(find.semantics.byLabel('Start dictation'));
      await tester.pump();
      final listening = tester
          .getSemantics(find.bySemanticsLabel('Listening…'))
          .getSemanticsData();
      expect(listening.flagsCollection.isLiveRegion, isTrue);
      final stop = tester
          .getSemantics(find.bySemanticsLabel('Stop dictation'))
          .getSemanticsData();
      expect(stop.flagsCollection.isSelected, ui.Tristate.isTrue);
      dictation.complete(null);
      await tester.pump();
      semantics.dispose();
    },
  );

  testWidgets(
    'all primary controls and attachments meet labeled 48dp targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            initialDraft: 'Ready',
            initialAttachments: const [
              BeautifulPromptAttachment(
                id: 'report',
                label: 'Quarterly report.pdf',
              ),
            ],
            sources: const [
              BeautifulPromptSource(id: 'records', label: 'Records'),
            ],
            models: const [BeautifulPromptModel(id: 'model', label: 'Model')],
            onModelChanged: (_) {},
            onSend: (_) {},
            onDictate: () => null,
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      tester.semantics.tap(
        find.semantics.byLabel('Remove Quarterly report.pdf'),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel('Remove Quarterly report.pdf'),
        findsNothing,
      );
      tester.semantics.tap(find.semantics.byLabel('Add sources and files'));
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    },
  );

  testWidgets('disabled prompt exposes a read-only editor and no send action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        BeautifulPromptBar(
          composerId: 'one',
          initialDraft: 'Frozen',
          enabled: false,
          onSend: (_) {},
        ),
      ),
    );
    final field = tester
        .getSemantics(find.bySemanticsLabel('Prompt'))
        .getSemanticsData();
    expect(field.flagsCollection.isTextField, isTrue);
    expect(field.flagsCollection.isReadOnly, isTrue);
    expect(field.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(field.hasAction(SemanticsAction.setText), isFalse);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Send'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets(
    'dictation without a stop callback exposes one live listening status',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final transcript = Completer<String?>();
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            onDictate: () => transcript.future,
          ),
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('Start dictation'));
      await tester.pump();
      expect(find.bySemanticsLabel('Listening…'), findsOneWidget);
      final status = tester
          .getSemantics(find.bySemanticsLabel('Listening…'))
          .getSemanticsData();
      expect(status.flagsCollection.isLiveRegion, isTrue);
      final start = tester
          .getSemantics(find.bySemanticsLabel('Start dictation'))
          .getSemanticsData();
      expect(start.flagsCollection.isEnabled, ui.Tristate.isFalse);
      transcript.complete(null);
      await tester.pump();
      semantics.dispose();
    },
  );
}

Widget _app(Widget child) =>
    beautifulTestApp(disableAnimations: true, child: child);
