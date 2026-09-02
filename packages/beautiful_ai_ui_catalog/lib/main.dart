import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

SemanticsHandle? _semanticsHandle;

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

const _recommendationOptions = <BeautifulRecommendationOption>[
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
  BeautifulRecommendationOption(
    id: 'full-restock',
    body: 'Fall back to a full restock across every SKU.',
    shortLabel: 'Full restock across every SKU',
    signal: 0,
    tone: BeautifulRecommendationTone.neutral,
    confidenceLabel: 'No signal',
    actionLabel: 'Accept full restock',
  ),
];

const _searchItems = <BeautifulSearchItem>[
  BeautifulSearchItem(id: 'forecast', title: 'Forecast summer demand'),
  BeautifulSearchItem(id: 'cones', title: 'Find waffle cone suppliers'),
  BeautifulSearchItem(id: 'seasonal', title: 'Compare seasonal flavors'),
  BeautifulSearchItem(id: 'launch', title: 'Draft flavor launch plan'),
  BeautifulSearchItem(id: 'cold-chain', title: 'Check cold-chain status'),
  BeautifulSearchItem(id: 'sugar', title: 'Audit sugar costs'),
  BeautifulSearchItem(id: 'retire', title: 'Retire low sellers'),
];

const _sampleCode = '''export async function churnBatch() {
  const flavor = await getFlavor("pistachio");
  const base = await dairy.fetch({ flavor });
  await freezer.store(base, { temp: "-16C" });
  return base.gallons;
}''';

const _sampleDiff = <BeautifulDiffLine>[
  BeautifulDiffLine(
    oldLineNumber: 1,
    newLineNumber: 1,
    kind: BeautifulDiffLineKind.context,
    pieces: <BeautifulCodePiece>[
      BeautifulCodePiece(text: 'await freezer.store(base, { temp: '),
    ],
  ),
  BeautifulDiffLine(
    oldLineNumber: 2,
    kind: BeautifulDiffLineKind.removed,
    pieces: <BeautifulCodePiece>[
      BeautifulCodePiece(
        text: '  "-14C"',
        change: BeautifulDiffLineKind.removed,
      ),
    ],
  ),
  BeautifulDiffLine(
    newLineNumber: 2,
    kind: BeautifulDiffLineKind.added,
    pieces: <BeautifulCodePiece>[
      BeautifulCodePiece(text: '  "-16C"', change: BeautifulDiffLineKind.added),
    ],
  ),
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('ENABLE_WEB_SEMANTICS')) {
    _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
    assert(_semanticsHandle != null);
  }
  runApp(const CatalogApp());
}

/// Multi-platform catalog for the Beautiful AI UI package.
final class CatalogApp extends StatefulWidget {
  /// Creates the catalog application.
  const CatalogApp({super.key});

  @override
  State<CatalogApp> createState() => _CatalogAppState();
}

final class _CatalogAppState extends State<CatalogApp> {
  var _themeMode = BeautifulUiThemeMode.system;
  var _motion = BeautifulMotionPolicy.system;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xff0285ff),
      debugShowCheckedModeBanner: false,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyD, meta: true):
            _ToggleThemeIntent(),
      },
      actions: <Type, Action<Intent>>{
        _ToggleThemeIntent: CallbackAction<_ToggleThemeIntent>(
          onInvoke: (_) {
            _cycleTheme();
            return null;
          },
        ),
      },
      builder: (context, child) {
        return BeautifulUiScope(
          themeMode: _themeMode,
          motion: _motion,
          child: _CatalogHome(
            themeMode: _themeMode,
            motion: _motion,
            onThemePressed: _cycleTheme,
            onMotionPressed: _cycleMotion,
          ),
        );
      },
    );
  }

  void _cycleTheme() {
    setState(() {
      _themeMode = switch (_themeMode) {
        BeautifulUiThemeMode.system => BeautifulUiThemeMode.light,
        BeautifulUiThemeMode.light => BeautifulUiThemeMode.dark,
        BeautifulUiThemeMode.dark => BeautifulUiThemeMode.system,
      };
    });
  }

  void _cycleMotion() {
    setState(() {
      _motion = switch (_motion) {
        BeautifulMotionPolicy.system => BeautifulMotionPolicy.reduced,
        BeautifulMotionPolicy.reduced => BeautifulMotionPolicy.none,
        BeautifulMotionPolicy.none => BeautifulMotionPolicy.system,
      };
    });
  }
}

final class _ToggleThemeIntent extends Intent {
  const _ToggleThemeIntent();
}

final class _CatalogHome extends StatefulWidget {
  const _CatalogHome({
    required this.themeMode,
    required this.motion,
    required this.onThemePressed,
    required this.onMotionPressed,
  });

  final BeautifulUiThemeMode themeMode;
  final BeautifulMotionPolicy motion;
  final VoidCallback onThemePressed;
  final VoidCallback onMotionPressed;

  @override
  State<_CatalogHome> createState() => _CatalogHomeState();
}

final class _CatalogHomeState extends State<_CatalogHome> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String? _openedContextSource;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return ColoredBox(
      color: theme.colors.canvas,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: <Widget>[
                _CatalogHeader(
                  themeMode: widget.themeMode,
                  motion: widget.motion,
                  onThemePressed: widget.onThemePressed,
                  onMotionPressed: widget.onMotionPressed,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(theme.spacing.xl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: _CatalogGrid(children: _cards()),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _cards() {
    return <Widget>[
      _CatalogCard(
        title: 'Loading · Drive',
        caption: 'Square-cell chevron wavefront',
        child: BeautifulLoadingState(
          label: 'Preparing workspace',
          elapsed: _stopwatch.elapsed,
        ),
      ),
      _CatalogCard(
        title: 'Loading · Dots',
        caption: 'Circular-cell chevron wavefront',
        child: BeautifulLoadingState(
          label: 'Indexing sources',
          variant: BeautifulLoadingVariant.dots,
          elapsed: _stopwatch.elapsed,
        ),
      ),
      _CatalogCard(
        title: 'Loading · Orbit',
        caption: 'A pixel comet follows the perimeter',
        child: BeautifulLoadingState(
          label: 'Checking dependencies',
          variant: BeautifulLoadingVariant.orbit,
          elapsed: _stopwatch.elapsed,
        ),
      ),
      _CatalogCard(
        title: 'Loading · Surfer',
        caption: 'License-safe, zero-network media fallback',
        child: BeautifulLoadingState(
          label: 'Running a long task',
          variant: BeautifulLoadingVariant.surfer,
          elapsed: _stopwatch.elapsed,
          surferFallbackLabel: 'Provide licensed media from the host app',
        ),
      ),
      for (final variant in BeautifulThinkingVariant.values)
        _CatalogCard(
          title: 'Thinking · ${variant.name}',
          caption: 'Caller-owned trace with persistent disclosure state',
          child: BeautifulThinking(
            key: ValueKey<String>('catalog-thinking-${variant.name}'),
            variant: variant,
            status: variant == BeautifulThinkingVariant.steps
                ? BeautifulThinkingStatus.working
                : BeautifulThinkingStatus.complete,
            workingLabel: variant == BeautifulThinkingVariant.search
                ? 'Searching the web'
                : variant == BeautifulThinkingVariant.coding
                ? 'Running tools'
                : 'Thinking',
            completedLabel: variant == BeautifulThinkingVariant.search
                ? 'Searched the web'
                : variant == BeautifulThinkingVariant.coding
                ? 'Ran 3 tools'
                : 'Thought for 4 seconds',
            query: variant == BeautifulThinkingVariant.search
                ? 'best waffle cone supplier'
                : null,
            items: _thinkingItems,
            initiallyExpanded: true,
            expandLabel: 'Show ${variant.name} thinking details',
            collapseLabel: 'Hide ${variant.name} thinking details',
            onItemPressed: (_) {},
          ),
        ),
      _CatalogCard(
        title: 'Context Cards',
        caption: _openedContextSource == null
            ? 'Retrieved chunks with compact disclosure and source action'
            : 'Opened source: $_openedContextSource',
        child: BeautifulContextCards(
          key: const Key('catalog-context-cards'),
          chunks: _contextChunks,
          countLabel: '32',
          onSourcePressed: (chunk) {
            setState(() => _openedContextSource = chunk.id);
          },
        ),
      ),
      _CatalogCard(
        title: 'Recommendation Card',
        caption: 'Alternatives, confidence, and asynchronous acceptance',
        child: BeautifulRecommendationCard(
          key: const Key('catalog-recommendation-card'),
          title: 'Want me to place this restock order?',
          options: _recommendationOptions,
          onAccept: (_) {},
        ),
      ),
      _CatalogCard(
        title: 'Search',
        caption: 'Live filtering with pointer, keyboard, and Semantics paths',
        child: BeautifulSearch(
          key: const Key('catalog-search'),
          items: _searchItems,
          placeholder: 'Search flavors…',
          searchLabel: 'Search flavors',
          onSelected: (_) {},
        ),
      ),
      _CatalogCard(
        title: 'Code Block · Code',
        caption: 'Line numbers, lightweight syntax color, and copy feedback',
        child: BeautifulCodeBlock.code(
          key: const Key('catalog-code-block'),
          filename: 'churn.ts',
          code: _sampleCode,
          onCopy: (_) {},
        ),
      ),
      const _CatalogCard(
        title: 'Code Block · Diff',
        caption: 'Typed unified diff with non-color change semantics',
        child: BeautifulCodeBlock.diff(
          filename: 'churn.ts',
          lines: _sampleDiff,
        ),
      ),
    ];
  }
}

final class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1160
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final totalGaps = theme.spacing.lg * (columns - 1);
        final cardWidth = (constraints.maxWidth - totalGaps) / columns;
        return Wrap(
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.lg,
          children: <Widget>[
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}

final class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.themeMode,
    required this.motion,
    required this.onThemePressed,
    required this.onMotionPressed,
  });

  final BeautifulUiThemeMode themeMode;
  final BeautifulMotionPolicy motion;
  final VoidCallback onThemePressed;
  final VoidCallback onMotionPressed;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return ColoredBox(
      color: theme.colors.page,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colors.line)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final title = Text(
              'Beautiful AI UI · P1 Catalog',
              style: theme.typography.label.copyWith(
                color: theme.colors.ink,
                fontSize: 15,
              ),
            );
            final controls = Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                _CatalogButton(
                  label: 'Theme: ${themeMode.name}',
                  onPressed: onThemePressed,
                ),
                _CatalogButton(
                  label: 'Motion: ${motion.name}',
                  onPressed: onMotionPressed,
                ),
              ],
            );
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xl,
                vertical: theme.spacing.md,
              ),
              child: constraints.maxWidth < 700
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        title,
                        SizedBox(height: theme.spacing.sm),
                        controls,
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(child: title),
                        controls,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

final class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.title,
    required this.caption,
    required this.child,
  });

  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.lg),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.line),
        borderRadius: BorderRadius.circular(theme.radii.card),
        boxShadow: theme.shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.typography.label.copyWith(color: theme.colors.ink),
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            caption,
            style: theme.typography.caption.copyWith(
              color: theme.colors.inkMuted,
            ),
          ),
          SizedBox(height: theme.spacing.xl),
          child,
        ],
      ),
    );
  }
}

final class _CatalogButton extends StatefulWidget {
  const _CatalogButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_CatalogButton> createState() => _CatalogButtonState();
}

final class _CatalogButtonState extends State<_CatalogButton> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: widget.label,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _hovered ? theme.colors.hover : theme.colors.surface,
              border: Border.all(
                color: _focused ? theme.colors.accent : theme.colors.lineStrong,
                width: _focused ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(theme.radii.control),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.md,
                  vertical: theme.spacing.sm,
                ),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
