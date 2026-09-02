import 'dart:io';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_fonts.dart';
import '../test_harness.dart';

const _thinkingItems = <BeautifulThinkingItem>[
  BeautifulThinkingItem(id: 'briefs', label: 'Reading flavor briefs'),
  BeautifulThinkingItem(id: 'suppliers', label: 'Scanning supplier lists'),
  BeautifulThinkingItem(
    id: 'notes',
    label: 'Comparing tasting notes',
    detail: '6 flavors',
  ),
];

const _contextChunks = <BeautifulContextChunk>[
  BeautifulContextChunk(
    id: 'vendor-rule',
    title: 'Vendor onboarding rule',
    characterCountLabel: '290 characters',
    body:
        'Cold-chain certification must be verified before a new dairy can be '
        'added to the reorder workflow.',
    sourceLabel: 'Dairy Onboarding SOP.pdf',
    sourceBadge: 'PDF',
    tone: BeautifulContextTone.destructive,
  ),
  BeautifulContextChunk(
    id: 'seasonal-demand',
    title: 'Seasonal demand row',
    characterCountLabel: '1,250 characters',
    body:
        'Q4 velocity table: pistachio +18%, vanilla +6%, rocky road -11%; '
        'retire flavors below 40 scoops weekly.',
    sourceLabel: 'Sales Velocity Export.csv',
    sourceBadge: 'CSV',
    tone: BeautifulContextTone.success,
  ),
];

const _recommendations = <BeautifulRecommendationOption>[
  BeautifulRecommendationOption(
    id: 'cone-king',
    body: 'Reorder waffle cones from Cone King with a 7-day lead time.',
    shortLabel: 'Reorder from Cone King · 7-day lead',
    signal: 3,
    tone: BeautifulRecommendationTone.success,
    confidenceLabel: 'High confidence',
    actionLabel: 'Accept',
  ),
  BeautifulRecommendationOption(
    id: 'madagascar',
    body: 'Switch vanilla to Vanilla Madagascar for peak season.',
    shortLabel: 'Switch to Vanilla Madagascar',
    signal: 2,
    tone: BeautifulRecommendationTone.warning,
    confidenceLabel: 'Needs review',
    actionLabel: 'Configure',
  ),
];

const _searchItems = <BeautifulSearchItem>[
  BeautifulSearchItem(id: 'forecast', title: 'Forecast summer demand'),
  BeautifulSearchItem(id: 'cones', title: 'Find waffle cone suppliers'),
  BeautifulSearchItem(id: 'seasonal', title: 'Compare seasonal flavors'),
  BeautifulSearchItem(id: 'launch', title: 'Draft flavor launch plan'),
  BeautifulSearchItem(id: 'cold-chain', title: 'Check cold-chain status'),
];

const _code = '''export async function churnBatch() {
  const flavor = await getFlavor("pistachio");
  const base = await dairy.fetch({ flavor });
  await freezer.store(base, { temp: "-16C" });
  return base.gallons;
}''';

const _diff = <BeautifulDiffLine>[
  BeautifulDiffLine(
    oldLineNumber: 1,
    newLineNumber: 1,
    kind: BeautifulDiffLineKind.context,
    pieces: <BeautifulCodePiece>[
      BeautifulCodePiece(text: 'await freezer.store(base, { temp: value });'),
    ],
  ),
  BeautifulDiffLine(
    oldLineNumber: 2,
    kind: BeautifulDiffLineKind.removed,
    pieces: <BeautifulCodePiece>[
      BeautifulCodePiece(
        text: 'const value = "-14C";',
        change: BeautifulDiffLineKind.removed,
      ),
    ],
  ),
  BeautifulDiffLine(
    newLineNumber: 2,
    kind: BeautifulDiffLineKind.added,
    pieces: <BeautifulCodePiece>[
      BeautifulCodePiece(
        text: 'const value = "-16C";',
        change: BeautifulDiffLineKind.added,
      ),
    ],
  ),
];

void main() {
  setUpAll(loadBeautifulTestFonts);

  for (final brightness in Brightness.values) {
    testWidgets('P1 modules match the ${brightness.name} golden', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1020);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final boundaryKey = Key('p1-${brightness.name}');
      final background = brightness == Brightness.dark
          ? const Color(0xff17181a)
          : const Color(0xfffafafb);

      await tester.pumpWidget(
        beautifulTestApp(
          size: const Size(1200, 1020),
          brightness: brightness,
          disableAnimations: true,
          motion: BeautifulMotionPolicy.none,
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: background,
              child: SizedBox(
                width: 1200,
                height: 1020,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            BeautifulThinking(
                              variant: BeautifulThinkingVariant.steps,
                              status: BeautifulThinkingStatus.complete,
                              workingLabel: 'Thinking',
                              completedLabel: 'Thought for 4 seconds',
                              items: _thinkingItems,
                              initiallyExpanded: true,
                            ),
                            const SizedBox(height: 28),
                            const BeautifulContextCards(
                              chunks: _contextChunks,
                              countLabel: '32',
                            ),
                            const SizedBox(height: 28),
                            BeautifulSearch(
                              items: _searchItems,
                              placeholder: 'Search flavors…',
                              searchLabel: 'Search flavors',
                              onSelected: (_) {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            BeautifulRecommendationCard(
                              title: 'Want me to place this restock order?',
                              options: _recommendations,
                              onAccept: (_) {},
                            ),
                            const SizedBox(height: 28),
                            BeautifulCodeBlock.code(
                              filename: 'churn.ts',
                              code: _code,
                              onCopy: (_) {},
                            ),
                            const SizedBox(height: 28),
                            const BeautifulCodeBlock.diff(
                              filename: 'churn.ts',
                              lines: _diff,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile(
          'goldens/p1_components_${brightness.name}'
          '${Platform.isMacOS ? '_macos' : ''}.png',
        ),
      );
    }, skip: !(Platform.isLinux || Platform.isMacOS));
  }
}
