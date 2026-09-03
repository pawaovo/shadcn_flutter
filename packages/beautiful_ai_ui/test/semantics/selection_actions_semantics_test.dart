import 'dart:async';
import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _text = 'Select the actual second passage: second';
const _selection = TextSelection(baseOffset: 34, extentOffset: 40);

void main() {
  testWidgets(
    'read-only document exposes value and selection but no text mutation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      final editor = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      editor.focusNode.requestFocus();
      await tester.pumpAndSettle();
      final document = tester
          .getSemantics(find.bySemanticsLabel('Document'))
          .getSemanticsData();
      expect(document.flagsCollection.isTextField, isTrue);
      expect(document.flagsCollection.isReadOnly, isTrue);
      expect(document.flagsCollection.isEnabled, ui.Tristate.isTrue);
      expect(document.value, _text);
      expect(document.textSelection, _selection);
      expect(document.hasAction(SemanticsAction.setSelection), isTrue);
      expect(document.hasAction(SemanticsAction.copy), isTrue);
      expect(document.hasAction(SemanticsAction.setText), isFalse);
      expect(document.hasAction(SemanticsAction.cut), isFalse);
      expect(document.hasAction(SemanticsAction.paste), isFalse);
      semantics.dispose();
    },
  );

  testWidgets(
    'semantic selection sends the exact repeated range through the same action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final requests = <BeautifulSelectionRequest>[];
      await tester.pumpWidget(
        _app(
          selection: null,
          onRequest: (request) {
            requests.add(request);
            return 'new wording';
          },
        ),
      );
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .requestFocus();
      await tester.pumpAndSettle();
      tester.semantics.setSelection(
        find.semantics.byLabel('Document'),
        base: _selection.baseOffset,
        extent: _selection.extentOffset,
      );
      await tester.pump();
      tester.semantics.tap(find.semantics.byLabel('Improve'));
      await tester.pump();
      expect(requests.single.selectedText, 'second');
      expect(requests.single.selection, _selection);
      expect(requests.single.baseText, _text);
      semantics.dispose();
    },
  );

  testWidgets(
    'more actions has explicit expansion and hidden options leave semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final requests = <BeautifulSelectionRequest>[];
      await tester.pumpWidget(
        _app(
          onRequest: (request) {
            requests.add(request);
            return 'short';
          },
        ),
      );
      expect(find.bySemanticsLabel('Shorten'), findsNothing);
      final more = tester
          .getSemantics(find.bySemanticsLabel('More actions'))
          .getSemanticsData();
      expect(more.flagsCollection.isButton, isTrue);
      expect(more.flagsCollection.isExpanded, ui.Tristate.isFalse);
      tester.semantics.tap(find.semantics.byLabel('More actions'));
      await tester.pump();
      final fewer = tester
          .getSemantics(find.bySemanticsLabel('Fewer actions'))
          .getSemanticsData();
      expect(fewer.flagsCollection.isExpanded, ui.Tristate.isTrue);
      tester.semantics.tap(find.semantics.byLabel('Shorten'));
      await tester.pump();
      expect(requests.single.action.id, 'shorten');
      expect(find.bySemanticsLabel('More actions'), findsNothing);
      expect(find.bySemanticsLabel('Shorten'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'localized pending and result announce while controls expose disabled state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final completion = Completer<String>();
      const labels = BeautifulSelectionLabels(
        selectedText: '已选文字',
        working: '正在处理所选文字',
        ready: '建议已就绪',
        before: '原始文字',
        after: '建议文字',
        keep: '保留修改',
      );
      await tester.pumpWidget(
        _app(onRequest: (_) => completion.future, labels: labels),
      );
      tester.semantics.tap(find.semantics.byLabel('Improve'));
      await tester.pump();
      final pending = tester
          .getSemantics(find.bySemanticsLabel('正在处理所选文字'))
          .getSemanticsData();
      expect(pending.flagsCollection.isLiveRegion, isTrue);
      final improve = tester
          .getSemantics(find.bySemanticsLabel('Improve'))
          .getSemanticsData();
      expect(improve.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(improve.hasAction(SemanticsAction.tap), isFalse);
      completion.complete('更清楚的内容');
      await tester.pump();
      final ready = tester
          .getSemantics(find.bySemanticsLabel('建议已就绪'))
          .getSemanticsData();
      expect(ready.flagsCollection.isLiveRegion, isTrue);
      final keep = tester
          .getSemantics(find.bySemanticsLabel('保留修改'))
          .getSemanticsData();
      expect(keep.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(keep.hasAction(SemanticsAction.tap), isFalse);
      final nodes = _data(tester);
      expect(
        nodes
            .where((data) => data.flagsCollection.isLiveRegion)
            .map((data) => data.label),
        ['建议已就绪'],
      );
      expect(nodes.any((data) => data.label.contains('原始文字')), isTrue);
      expect(nodes.any((data) => data.label.contains('建议文字')), isTrue);
      semantics.dispose();
    },
  );

  testWidgets(
    'semantic keep reports host acceptance and live apply errors remain retryable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final edits = <BeautifulSelectionEdit>[];
      final failures = <BeautifulUiFailure>[];
      await tester.pumpWidget(
        _app(
          onRequest: (_) => 'improved',
          onFailure: failures.add,
          onApply: (edit) {
            edits.add(edit);
            if (edits.length == 1) throw StateError('cannot persist yet');
          },
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('Improve'));
      await tester.pump();
      final keep = tester
          .getSemantics(find.bySemanticsLabel('Keep change'))
          .getSemanticsData();
      expect(keep.flagsCollection.isEnabled, ui.Tristate.isTrue);
      tester.semantics.tap(find.semantics.byLabel('Keep change'));
      await tester.pump();
      final failed = tester
          .getSemantics(find.bySemanticsLabel('Could not apply the change'))
          .getSemanticsData();
      expect(failed.flagsCollection.isLiveRegion, isTrue);
      expect(failures.single.operation, BeautifulUiOperation.selection);
      tester.semantics.tap(find.semantics.byLabel('Keep change'));
      await tester.pump();
      expect(edits, hasLength(2));
      expect(edits.last.replacement, 'improved');
      expect(edits.last.request.selection, _selection);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Change accepted'))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      expect(find.bySemanticsLabel('Keep change'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'instruction editor exports value and disabled actions cannot mutate requests',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final requests = <BeautifulSelectionRequest>[];
      await tester.pumpWidget(
        _app(
          onRequest: (request) {
            requests.add(request);
            return 'result';
          },
        ),
      );
      final emptySend = tester
          .getSemantics(find.bySemanticsLabel('Send edit instruction'))
          .getSemanticsData();
      expect(emptySend.flagsCollection.isEnabled, ui.Tristate.isFalse);
      await tester.enterText(
        find.byType(EditableText).at(1),
        'Make it concise',
      );
      await tester.pump();
      final input = tester
          .getSemantics(find.bySemanticsLabel('Describe edits'))
          .getSemanticsData();
      expect(input.value, 'Make it concise');
      expect(input.hasAction(SemanticsAction.setText), isTrue);
      tester.semantics.tap(find.semantics.byLabel('Send edit instruction'));
      await tester.pump();
      expect(requests.single.instruction, 'Make it concise');
      await tester.pumpWidget(_app(enabled: false));
      final doc = tester
          .getSemantics(find.bySemanticsLabel('Document'))
          .getSemanticsData();
      expect(doc.flagsCollection.isReadOnly, isTrue);
      expect(doc.flagsCollection.isEnabled, ui.Tristate.isTrue);
      final disabled = tester
          .getSemantics(find.bySemanticsLabel('Improve'))
          .getSemanticsData();
      expect(disabled.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(disabled.hasAction(SemanticsAction.tap), isFalse);
      semantics.dispose();
    },
  );

  testWidgets('panel actions satisfy Android iOS and labeled targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.enterText(find.byType(EditableText).at(1), 'Ready');
    await tester.pump();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}

List<SemanticsData> _data(WidgetTester tester) {
  final result = <SemanticsData>[];
  void visit(SemanticsNode node) {
    result.add(node.getSemanticsData());
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return result;
}

Widget _app({
  TextSelection? selection = _selection,
  FutureOr<String> Function(BeautifulSelectionRequest)? onRequest,
  FutureOr<void> Function(BeautifulSelectionEdit)? onApply,
  BeautifulUiFailureHandler? onFailure,
  BeautifulSelectionLabels labels = const BeautifulSelectionLabels(),
  bool enabled = true,
}) => beautifulTestApp(
  disableAnimations: true,
  child: BeautifulUiScope(
    onFailure: onFailure,
    child: SingleChildScrollView(
      child: BeautifulSelectionActions(
        documentId: 'semantics',
        text: _text,
        initialSelection: selection,
        labels: labels,
        enabled: enabled,
        onRequest: onRequest ?? (_) => 'result',
        onApply: onApply,
      ),
    ),
  ),
);
