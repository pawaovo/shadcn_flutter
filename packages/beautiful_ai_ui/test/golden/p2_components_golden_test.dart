import 'dart:io';
import 'dart:typed_data';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_fonts.dart';
import '../test_harness.dart';

const _fixtureSize = Size(1440, 1400);
const _fixtureContentKey = Key('p2-fixture-content');

void main() {
  GoldenFileComparator? previousComparator;
  setUpAll(() async {
    await loadBeautifulTestFonts();
    if (Platform.isLinux) {
      final comparator = goldenFileComparator;
      if (comparator is! LocalFileComparator) {
        throw StateError('P2 Linux goldens require a local file comparator.');
      }
      previousComparator = comparator;
      goldenFileComparator = _P2LinuxCandidateComparator(
        comparator.basedir.resolve('p2_components_golden_test.dart'),
      );
    }
  });
  tearDownAll(() {
    final comparator = previousComparator;
    if (Platform.isLinux && comparator != null) {
      goldenFileComparator = comparator;
    }
  });

  test(
    'missing Linux baseline emits a review candidate and still fails',
    () async {
      final scratch = await Directory.systemTemp.createTemp(
        'p2-golden-candidate-',
      );
      addTearDown(() => scratch.delete(recursive: true));
      final comparator = _P2LinuxCandidateComparator(
        scratch.uri.resolve('p2_components_golden_test.dart'),
      );
      final golden = Uri.parse('goldens/p2_components_light.png');
      final imageBytes = Uint8List.fromList(<int>[1, 2, 3]);

      await expectLater(
        comparator.compare(imageBytes, golden),
        throwsA(isA<TestFailure>()),
      );

      final candidate = File.fromUri(
        scratch.uri.resolve('failures/p2_components_light_testImage.png'),
      );
      expect(await candidate.readAsBytes(), orderedEquals(imageBytes));
      expect(
        await File.fromUri(scratch.uri.resolveUri(golden)).exists(),
        isFalse,
      );
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('P2 modules match the ${brightness.name} golden', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _fixtureSize;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final boundaryKey = Key('p2-${brightness.name}');
      final background = brightness == Brightness.dark
          ? const Color(0xff17181a)
          : const Color(0xfffafafb);

      await tester.pumpWidget(
        beautifulTestApp(
          size: _fixtureSize,
          brightness: brightness,
          disableAnimations: true,
          motion: BeautifulMotionPolicy.none,
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: background,
              child: SizedBox.fromSize(
                size: _fixtureSize,
                child: const Padding(
                  padding: EdgeInsets.all(32),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _P2Fixture(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exercise the public disclosure controls so the baseline includes
      // citation details, tool output, and a task's expanded step list.
      await tester.tap(find.text('Sources (1)'));
      await tester.tap(
        find.byKey(const ValueKey('beautiful-tool-step-control-read')),
      );
      await tester.tap(
        find.byKey(const ValueKey('task-toggle-capsules-index')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BeautifulStreamingText), findsOneWidget);
      expect(find.byType(BeautifulApprovalCard), findsOneWidget);
      expect(find.byType(BeautifulToolChips), findsOneWidget);
      expect(find.byType(BeautifulTaskRows), findsNWidgets(2));
      expect(find.byType(BeautifulChat), findsOneWidget);
      expect(find.byType(BeautifulFilterTable), findsOneWidget);
      expect(find.byType(BeautifulFineTuneCard), findsOneWidget);

      final bounds = tester.getRect(find.byKey(boundaryKey));
      final content = tester.getRect(find.byKey(_fixtureContentKey));
      expect(content.left, greaterThanOrEqualTo(bounds.left));
      expect(content.right, lessThanOrEqualTo(bounds.right));
      expect(content.bottom, lessThanOrEqualTo(bounds.bottom - 32));
      expect(
        tester.getRect(find.text('Schedule supplier follow-up')).bottom,
        lessThanOrEqualTo(bounds.bottom - 32),
      );

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile(
          'goldens/p2_components_${brightness.name}'
          '${Platform.isMacOS ? '_macos' : ''}.png',
        ),
      );
    }, skip: !(Platform.isLinux || Platform.isMacOS));
  }
}

/// Keeps first-run Linux candidates reviewable without accepting a baseline.
final class _P2LinuxCandidateComparator extends LocalFileComparator {
  _P2LinuxCandidateComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final canonical = File.fromUri(basedir.resolveUri(golden));
    if (!await canonical.exists()) {
      final candidate = getFailureFile('testImage', golden, basedir);
      await candidate.parent.create(recursive: true);
      await candidate.writeAsBytes(imageBytes, flush: true);
    }
    // The normal comparator still fails when the canonical image is absent.
    // Existing baselines also retain Flutter's ordinary strict comparison.
    return super.compare(imageBytes, golden);
  }
}

final class _P2Fixture extends StatelessWidget {
  const _P2Fixture();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: _fixtureContentKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _FixtureSection(
                    label: 'Streaming Text',
                    child: BeautifulStreamingText(
                      id: 'restock-answer',
                      status: BeautifulStreamingStatus.complete,
                      content: const <BeautifulStreamingPart>[
                        BeautifulStreamingPart.text(
                          'Stock is ready for the weekend. Waffle cones need '
                          'a seven-day lead; place the reorder today. ',
                        ),
                        BeautifulStreamingPart.citation('inventory'),
                      ],
                      sources: const <BeautifulStreamingSource>[
                        BeautifulStreamingSource(
                          id: 'inventory',
                          title: 'Inventory.csv',
                          detail: 'Daily export',
                        ),
                      ],
                      followUps: const <BeautifulStreamingFollowUp>[
                        BeautifulStreamingFollowUp(
                          id: 'draft',
                          label: 'Prepare a supplier email',
                        ),
                      ],
                      feedback: BeautifulStreamingFeedback.positive,
                      onCopy: (_) {},
                      onSourcePressed: (_) {},
                      onFollowUp: (_) {},
                      onFeedback: (_) {},
                    ),
                  ),
                  const SizedBox(height: 32),
                  _FixtureSection(
                    label: 'Approval Card',
                    child: BeautifulApprovalCard(
                      id: 'restock-approval',
                      autoAdvance: false,
                      questions: <BeautifulApprovalQuestion>[
                        BeautifulApprovalQuestion(
                          id: 'delivery',
                          title: 'How should I prepare the restock?',
                          options: const <BeautifulApprovalOption>[
                            BeautifulApprovalOption(
                              id: 'review',
                              label: 'Draft for review',
                            ),
                            BeautifulApprovalOption(
                              id: 'send',
                              label: 'Send to the supplier',
                            ),
                          ],
                        ),
                        BeautifulApprovalQuestion(
                          id: 'notes',
                          title: 'Include supplier lead times?',
                          allowCustomAnswer: false,
                          options: const <BeautifulApprovalOption>[
                            BeautifulApprovalOption(
                              id: 'include',
                              label: 'Include lead-time notes',
                            ),
                          ],
                        ),
                      ],
                      initialAnswers: <BeautifulApprovalAnswer>[
                        BeautifulApprovalAnswer(
                          questionId: 'delivery',
                          optionIds: const <String>['review'],
                        ),
                      ],
                      onSubmit: (_) {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _FixtureSection(
                    label: 'Chat',
                    child: BeautifulChat(
                      conversationId: 'stock-review',
                      height: 390,
                      tabs: const <BeautifulChatTab>[
                        BeautifulChatTab(id: 'inventory', label: 'Inventory'),
                        BeautifulChatTab(id: 'suppliers', label: 'Suppliers'),
                      ],
                      selectedTabId: 'inventory',
                      onTabChanged: (_) {},
                      onSend: (_) {},
                      messages: const <BeautifulChatMessage>[
                        BeautifulChatMessage(
                          id: 'question',
                          role: BeautifulChatRole.user,
                          text: 'What needs restocking this week?',
                        ),
                        BeautifulChatMessage(
                          id: 'answer',
                          role: BeautifulChatRole.assistant,
                          title: 'Inventory review',
                          subtitle: 'Supplier records',
                          detailLabel: '4 seconds',
                          text:
                              'Reorder waffle cones and pistachio base. '
                              'The remaining stock covers the weekend.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _FixtureSection(
                    label: 'Fine-tune Card',
                    child: BeautifulFineTuneCard(
                      labels: const BeautifulFineTuneLabels(
                        title: 'Flavor card',
                      ),
                      settings: BeautifulFineTuneSettings(
                        typeId: 'seasonal',
                        fields: const <BeautifulFineTuneField>[
                          BeautifulFineTuneField(
                            id: 'width',
                            label: 'W',
                            value: 324,
                            min: 40,
                            max: 999,
                          ),
                          BeautifulFineTuneField(
                            id: 'height',
                            label: 'H',
                            value: 96,
                            min: 24,
                            max: 999,
                          ),
                          BeautifulFineTuneField(
                            id: 'radius',
                            label: 'Radius',
                            value: 28,
                            min: 0,
                            max: 64,
                          ),
                          BeautifulFineTuneField(
                            id: 'opacity',
                            label: 'Opacity',
                            value: 100,
                            min: 0,
                            max: 100,
                            suffix: '%',
                          ),
                        ],
                      ),
                      options: const <BeautifulFineTuneOption>[
                        BeautifulFineTuneOption(
                          id: 'seasonal',
                          label: 'Seasonal',
                        ),
                        BeautifulFineTuneOption(
                          id: 'classic',
                          label: 'Classic',
                        ),
                        BeautifulFineTuneOption(
                          id: 'limited',
                          label: 'Limited',
                        ),
                      ],
                      onChanged: (_) {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _FixtureSection(
                    label: 'Tool Chips',
                    child: BeautifulToolChips(
                      headerLabel: '2 tool calls',
                      steps: <BeautifulToolStep>[
                        BeautifulToolStep(
                          id: 'read',
                          label: 'Read inventory',
                          chip: 'inventory.csv',
                          kind: BeautifulToolKind.read,
                          details: const <BeautifulToolDetailLine>[
                            BeautifulToolDetailLine(
                              text: '12 vendor records matched.',
                            ),
                          ],
                        ),
                        BeautifulToolStep(
                          id: 'write',
                          label: 'Update restock plan',
                          chip: 'restock.md',
                          kind: BeautifulToolKind.write,
                        ),
                      ],
                      diffs: <BeautifulToolDiff>[
                        BeautifulToolDiff(
                          id: 'restock',
                          file: 'restock.md',
                          additions: 4,
                          deletions: 1,
                          lines: const <BeautifulToolDetailLine>[
                            BeautifulToolDetailLine(
                              text: 'Order waffle cones today.',
                              tone: BeautifulToolLineTone.addition,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _FixtureSection(
                    label: 'Task Rows · Capsules',
                    child: BeautifulTaskRows(
                      rows: <BeautifulTaskRow>[
                        BeautifulTaskRow(
                          id: 'capsules-verify',
                          label: 'Verified vendor records',
                          amountLabel: '12 suppliers',
                          status: BeautifulTaskStatus.completed,
                        ),
                        BeautifulTaskRow(
                          id: 'capsules-index',
                          label: 'Build reorder task list',
                          amountLabel: '7 SKUs',
                          status: BeautifulTaskStatus.running,
                          step: 2,
                          progress: 0.68,
                          details: const <BeautifulTaskDetail>[
                            BeautifulTaskDetail(
                              id: 'read',
                              label: 'Reading POS export',
                              meta: '3 files',
                            ),
                            BeautifulTaskDetail(
                              id: 'score',
                              label: 'Scoring stockout risk',
                              meta: '68%',
                            ),
                          ],
                        ),
                        BeautifulTaskRow(
                          id: 'capsules-draft',
                          label: 'Draft supplier emails',
                          amountLabel: '2 messages',
                          status: BeautifulTaskStatus.failed,
                        ),
                      ],
                      onRetry: (_) {},
                    ),
                  ),
                  const SizedBox(height: 32),
                  _FixtureSection(
                    label: 'Task Rows · List',
                    child: BeautifulTaskRows(
                      variant: BeautifulTaskRowsVariant.list,
                      rows: <BeautifulTaskRow>[
                        BeautifulTaskRow(
                          id: 'list-verify',
                          label: 'Verify contact details',
                          amountLabel: '12 suppliers',
                          status: BeautifulTaskStatus.completed,
                        ),
                        BeautifulTaskRow(
                          id: 'list-follow-up',
                          label: 'Prepare follow-up notes',
                          amountLabel: '2 messages',
                          status: BeautifulTaskStatus.pending,
                          step: 3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const _FixtureSection(
          label: 'Filter Table',
          child: BeautifulFilterTable(
            rows: <BeautifulFilterTableRow>[
              BeautifulFilterTableRow(
                id: 'verify',
                task: 'Verify vendor records',
                date: 'Sep 03',
                status: BeautifulFilterTableStatus.completed,
                owner: 'Operations',
              ),
              BeautifulFilterTableRow(
                id: 'restock',
                task: 'Prepare the restock plan',
                date: 'Sep 04',
                status: BeautifulFilterTableStatus.inProgress,
                owner: 'Inventory',
              ),
              BeautifulFilterTableRow(
                id: 'follow-up',
                task: 'Schedule supplier follow-up',
                date: 'Sep 05',
                status: BeautifulFilterTableStatus.todo,
                owner: 'Purchasing',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _FixtureSection extends StatelessWidget {
  const _FixtureSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: theme.typography.caption.copyWith(
            color: theme.colors.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
