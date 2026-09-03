import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/layout.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';

/// Semantic chart color roles. Markers also distinguish plotted series.
enum BeautifulInsightTone {
  /// Primary accent.
  accent,

  /// Positive outcome.
  positive,

  /// Negative outcome.
  negative,

  /// Neutral comparison.
  neutral,
}

/// An exact host-supplied observation; the library never interpolates values.
@immutable
final class BeautifulInsightPoint {
  /// Creates a point with stable identity and localized display text.
  const BeautifulInsightPoint({
    required this.id,
    required this.label,
    required this.value,
    required this.formattedValue,
  });

  /// Stable identity, unique within a series.
  final String id;

  /// Localized domain-axis label, such as a date.
  final String label;

  /// Finite numeric observation used only for drawing.
  final double value;

  /// Host-formatted value including its unit.
  final String formattedValue;
}

/// An immutable bounded line series with exact accessible observations.
@immutable
final class BeautifulInsightSeries {
  /// Creates a series of 1–512 finite points with unique non-empty IDs.
  BeautifulInsightSeries({
    required this.id,
    required this.label,
    required this.valueLabel,
    required Iterable<BeautifulInsightPoint> points,
    this.detail,
    this.tone = BeautifulInsightTone.accent,
  }) : points = List<BeautifulInsightPoint>.unmodifiable(points) {
    _text(id, 'series.id');
    _text(label, 'series.label');
    _text(valueLabel, 'series.valueLabel');
    _validatePoints(this.points);
  }

  /// Stable series identity.
  final String id;

  /// Localized legend label.
  final String label;

  /// Host-formatted headline value, including any direction or unit.
  final String valueLabel;

  /// Optional supporting value or explanation.
  final String? detail;

  /// Color role, supplemented by ordered marker and line patterns.
  final BeautifulInsightTone tone;

  /// Exact observations in host order, spaced uniformly along the chart.
  final List<BeautifulInsightPoint> points;
}

/// One selectable anomaly metric and its host-supplied threshold.
@immutable
final class BeautifulInsightMetric {
  /// Creates a metric with 1–512 finite observations.
  BeautifulInsightMetric({
    required this.id,
    required this.label,
    required this.valueLabel,
    required Iterable<BeautifulInsightPoint> points,
    this.detail,
    this.thresholdValue,
    this.thresholdLabel,
  }) : points = List<BeautifulInsightPoint>.unmodifiable(points) {
    _text(id, 'metric.id');
    _text(label, 'metric.label');
    _text(valueLabel, 'metric.valueLabel');
    _validatePoints(this.points);
    if ((thresholdValue == null) != (thresholdLabel == null) ||
        (thresholdValue != null && !thresholdValue!.isFinite)) {
      throw ArgumentError(
        'Supply both a finite thresholdValue and thresholdLabel.',
      );
    }
    if (thresholdLabel != null) _text(thresholdLabel!, 'thresholdLabel');
  }

  /// Stable metric identity.
  final String id;

  /// Localized metric selector label.
  final String label;

  /// Host-formatted headline value.
  final String valueLabel;

  /// Optional host-supplied comparison or explanation.
  final String? detail;

  /// Exact observations in host order.
  final List<BeautifulInsightPoint> points;

  /// Optional threshold in the same unit as the observations.
  final double? thresholdValue;

  /// Complete localized threshold description, including the formatted value.
  final String? thresholdLabel;
}

/// A host-supplied allocation segment with an accessible amount and share.
@immutable
final class BeautifulInsightAllocationSegment {
  /// Creates a segment. Its share must be finite and between zero and one.
  const BeautifulInsightAllocationSegment({
    required this.id,
    required this.label,
    required this.share,
    required this.shareLabel,
    required this.valueLabel,
    this.detail,
  });

  /// Stable segment identity.
  final String id;

  /// Full localized segment name.
  final String label;

  /// Fraction used for proportional drawing; shares must total one.
  final double share;

  /// Host-formatted share, such as `72.5%`.
  final String shareLabel;

  /// Host-formatted amount.
  final String valueLabel;

  /// Optional localized explanation for the selected segment.
  final String? detail;
}

/// Typed chart snapshots supported by [BeautifulInsightCards].
@immutable
sealed class BeautifulInsightChart {
  /// Creates a chart with a meaningful title and textual alternative.
  BeautifulInsightChart({required this.title, required this.summary}) {
    _text(title, 'chart.title');
    _text(summary, 'chart.summary');
  }

  /// Visible chart heading.
  final String title;

  /// Explicit host-authored textual alternative to the visual chart.
  final String summary;
}

/// Compares 1–4 aligned series without generating synthetic observations.
final class BeautifulInsightComparison extends BeautifulInsightChart {
  /// Creates a comparison. All series must share point IDs and labels in order.
  BeautifulInsightComparison({
    required super.title,
    required super.summary,
    required Iterable<BeautifulInsightSeries> series,
  }) : series = List<BeautifulInsightSeries>.unmodifiable(series) {
    _ids(this.series.map((s) => s.id), 'series', 4);
    final reference = this.series.first.points;
    for (final item in this.series.skip(1)) {
      if (item.points.length != reference.length ||
          !listEquals(
            item.points.map((p) => p.id).toList(),
            reference.map((p) => p.id).toList(),
          ) ||
          !listEquals(
            item.points.map((p) => p.label).toList(),
            reference.map((p) => p.label).toList(),
          )) {
        throw ArgumentError(
          'Comparison series must share point IDs and labels in order.',
        );
      }
    }
  }

  /// Plotted series in legend and marker order.
  final List<BeautifulInsightSeries> series;
}

/// A chart with 1–8 host-controlled selectable metrics.
final class BeautifulInsightAnomaly extends BeautifulInsightChart {
  /// Creates metrics and validates the currently selected metric.
  BeautifulInsightAnomaly({
    required super.title,
    required super.summary,
    required Iterable<BeautifulInsightMetric> metrics,
    required this.selectedMetricId,
  }) : metrics = List<BeautifulInsightMetric>.unmodifiable(metrics) {
    _ids(this.metrics.map((m) => m.id), 'metrics', 8);
    if (!this.metrics.any((m) => m.id == selectedMetricId)) {
      throw ArgumentError.value(selectedMetricId, 'selectedMetricId');
    }
  }

  /// Selectable host-supplied metrics.
  final List<BeautifulInsightMetric> metrics;

  /// Accepted metric selection. Callbacks propose changes to the host.
  final String selectedMetricId;
}

/// A proportional allocation chart with 1–12 selectable segments.
final class BeautifulInsightAllocation extends BeautifulInsightChart {
  /// Creates an allocation whose finite shares total one (tolerance 0.000001).
  BeautifulInsightAllocation({
    required super.title,
    required super.summary,
    required Iterable<BeautifulInsightAllocationSegment> segments,
    required this.selectedSegmentId,
  }) : segments = List<BeautifulInsightAllocationSegment>.unmodifiable(
         segments,
       ) {
    _ids(this.segments.map((s) => s.id), 'segments', 12);
    var total = 0.0;
    for (final segment in this.segments) {
      _text(segment.label, 'segment.label');
      _text(segment.shareLabel, 'segment.shareLabel');
      _text(segment.valueLabel, 'segment.valueLabel');
      if (!segment.share.isFinite || segment.share < 0 || segment.share > 1) {
        throw ArgumentError.value(segment.share, 'share');
      }
      total += segment.share;
    }
    if ((total - 1).abs() > 0.000001) {
      throw ArgumentError('Allocation shares must total one.');
    }
    if (!this.segments.any((s) => s.id == selectedSegmentId)) {
      throw ArgumentError.value(selectedSegmentId, 'selectedSegmentId');
    }
  }

  /// Segments in bar, legend, and reading order.
  final List<BeautifulInsightAllocationSegment> segments;

  /// Accepted segment selection. Callbacks propose changes to the host.
  final String selectedSegmentId;
}

/// A carousel page with host-authored prose, chart data, and optional action.
@immutable
final class BeautifulInsightPage {
  /// Creates a page with stable identity and a concrete typed chart snapshot.
  const BeautifulInsightPage({
    required this.id,
    required this.title,
    required this.prose,
    required this.chart,
    this.followUpLabel,
  });

  /// Stable identity used to retain inspection and data disclosure on reorder.
  final String id;

  /// Localized page heading.
  final String title;

  /// Host-authored insight explanation.
  final String prose;

  /// The accepted chart snapshot.
  final BeautifulInsightChart chart;

  /// Optional follow-up action text; no action is fabricated by the package.
  final String? followUpLabel;
}

/// Localizable controls and status text for [BeautifulInsightCards].
@immutable
final class BeautifulInsightLabels {
  /// Creates labels. Numbered data values remain host formatted.
  const BeautifulInsightLabels({
    this.title = 'Insights',
    this.previous = 'Previous insight',
    this.next = 'Next insight',
    this.showData = 'View chart data',
    this.hideData = 'Hide chart data',
    this.previousPoint = 'Previous observation',
    this.nextPoint = 'Next observation',
    this.inspectHint = 'Use arrow keys to inspect observations. Home and End select the first and last.',
    this.empty = 'No insights',
  });

  /// Carousel heading.
  final String title;

  /// Previous page action.
  final String previous;

  /// Next page action.
  final String next;

  /// Expand the complete textual observations.
  final String showData;

  /// Collapse the textual observations.
  final String hideData;

  /// Inspect the preceding observation.
  final String previousPoint;

  /// Inspect the following observation.
  final String nextPoint;

  /// Keyboard guidance for the chart inspection surface.
  final String inspectHint;

  /// Empty carousel description.
  final String empty;
}

/// Adaptive insight cards with exact data, native charts, and accessible tables.
///
/// Page, metric, and segment selection are fully controlled: the host accepts
/// callbacks by supplying a new snapshot. Omit callbacks to expose read-only
/// selection. Hover/keyboard inspection and chart-data disclosure are local,
/// retained by page and observation identity across resize and reorder.
///
/// Work is bounded to 32 pages, four series of 512 observations, eight metrics,
/// and twelve allocation segments. Only the selected chart is painted; its full
/// textual data is created only when requested. More than 24 textual rows use a
/// bounded, lazy scroll viewport with complete values and keyboard navigation.
/// No timers, networking, numeric formatting, forecasting, or model execution
/// are performed.
final class BeautifulInsightCards extends StatefulWidget {
  /// Creates a carousel and validates stable page identities in release builds.
  BeautifulInsightCards({
    super.key,
    required Iterable<BeautifulInsightPage> pages,
    required this.selectedPageId,
    this.onPageChanged,
    this.onMetricChanged,
    this.onSegmentChanged,
    this.onFollowUp,
    this.labels = const BeautifulInsightLabels(),
    this.pagePositionLabel,
  }) : pages = List<BeautifulInsightPage>.unmodifiable(pages) {
    _ids(this.pages.map((p) => p.id), 'pages', 32, allowEmpty: true);
    for (final page in this.pages) {
      _text(page.title, 'page.title');
      _text(page.prose, 'page.prose');
      if (page.followUpLabel != null) {
        _text(page.followUpLabel!, 'followUpLabel');
      }
    }
    if (this.pages.isEmpty
        ? selectedPageId != null
        : !this.pages.any((p) => p.id == selectedPageId)) {
      throw ArgumentError.value(selectedPageId, 'selectedPageId');
    }
  }

  /// Immutable pages; an empty carousel requires a null [selectedPageId].
  final List<BeautifulInsightPage> pages;

  /// Accepted page ID, or null for an empty carousel.
  final String? selectedPageId;

  /// Proposes a page ID, wrapping around the current ordered pages.
  final ValueChanged<String>? onPageChanged;

  /// Proposes a metric ID for the identified page.
  final void Function(String pageId, String metricId)? onMetricChanged;

  /// Proposes an allocation segment ID for the identified page.
  final void Function(String pageId, String segmentId)? onSegmentChanged;

  /// Performs the follow-up action for the identified page.
  final ValueChanged<String>? onFollowUp;

  /// Localized UI labels.
  final BeautifulInsightLabels labels;

  /// Optional host-formatted page position; defaults to `current / total`.
  final String? pagePositionLabel;

  @override
  State<BeautifulInsightCards> createState() => _BeautifulInsightCardsState();
}

final class _Inspection {
  String? pointId;
  bool showData = false;
}

final class _BeautifulInsightCardsState extends State<BeautifulInsightCards> {
  final _inspections = <(String, String), _Inspection>{};

  @override
  void didUpdateWidget(BeautifulInsightCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    final keys = <(String, String)>{};
    for (final page in widget.pages) {
      switch (page.chart) {
        case BeautifulInsightComparison():
          keys.add((page.id, 'comparison'));
        case BeautifulInsightAnomaly(:final metrics):
          keys.addAll(metrics.map((metric) => (page.id, metric.id)));
        case BeautifulInsightAllocation():
          keys.add((page.id, 'allocation'));
      }
    }
    _inspections.removeWhere((key, _) => !keys.contains(key));
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    if (widget.pages.isEmpty) {
      return Text(
        widget.labels.empty,
        style: theme.typography.body.copyWith(color: theme.colors.inkMuted),
      );
    }
    final index = widget.pages.indexWhere((p) => p.id == widget.selectedPageId);
    final page = widget.pages[index];
    final navigable = widget.pages.length > 1 && widget.onPageChanged != null;
    void move(int delta) => widget.onPageChanged?.call(
      widget.pages[(index + delta) % widget.pages.length].id,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final environment = BeautifulUiEnvironment.of(context);
        final mode = environment.modeFor(context, constraints);
        final expanded =
            mode == BeautifulLayoutMode.expanded &&
            MediaQuery.textScalerOf(context).scale(14) < 24;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                page.title,
                style: theme.typography.label.copyWith(
                  color: theme.colors.ink,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              page.prose,
              style: theme.typography.body.copyWith(
                color: theme.colors.inkMuted,
              ),
            ),
          ],
        );
        final action = page.followUpLabel == null
            ? null
            : Padding(
                padding: EdgeInsets.only(top: theme.spacing.md),
                child: BeautifulActionControl(
                  key: ValueKey<String>(
                    'beautiful-insight-followup-${page.id}',
                  ),
                  label: page.followUpLabel!,
                  onPressed: widget.onFollowUp == null
                      ? null
                      : () => widget.onFollowUp!(page.id),
                  minHeight: 48,
                  maxLines: null,
                  fullWidth: !expanded,
                ),
              );
        final chart = _chart(context, page);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${widget.labels.title} ${widget.pagePositionLabel ?? '${index + 1} / ${widget.pages.length}'}',
                    style: theme.typography.label.copyWith(
                      color: theme.colors.ink,
                    ),
                  ),
                ),
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    BeautifulActionControl(
                      key: const Key('beautiful-insight-previous'),
                      label: widget.labels.previous,
                      onPressed: navigable ? () => move(-1) : null,
                      minHeight: 48,
                      maxLines: null,
                    ),
                    BeautifulActionControl(
                      key: const Key('beautiful-insight-next'),
                      label: widget.labels.next,
                      onPressed: navigable ? () => move(1) : null,
                      minHeight: 48,
                      maxLines: null,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            // Keep the chart under the same elements when its layout changes,
            // so its focus and keyboard inspection survive responsive resize.
            Flex(
              direction: expanded ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: expanded
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  flex: expanded ? 1 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[text, if (expanded) ?action],
                  ),
                ),
                SizedBox(
                  width: expanded ? theme.spacing.lg : 0,
                  height: expanded ? 0 : theme.spacing.md,
                ),
                Flexible(flex: expanded ? 2 : 0, child: chart),
              ],
            ),
            if (!expanded) ?action,
          ],
        );
      },
    );
  }

  Widget _chart(BuildContext context, BeautifulInsightPage page) {
    final theme = BeautifulUiTheme.of(context);
    final chart = page.chart;
    final Widget body = switch (chart) {
      BeautifulInsightComparison(:final series) => _lineChart(
        context,
        page,
        'comparison',
        series,
      ),
      BeautifulInsightAnomaly() => _anomaly(context, page, chart),
      BeautifulInsightAllocation() => _allocation(context, page, chart),
    };
    return Container(
      key: ValueKey<String>('beautiful-insight-card-${page.id}'),
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.lineStrong),
        borderRadius: BorderRadius.circular(theme.radii.card),
        boxShadow: theme.shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              chart.title,
              style: theme.typography.label.copyWith(color: theme.colors.ink),
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            chart.summary,
            style: theme.typography.caption.copyWith(
              color: theme.colors.inkMuted,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          body,
        ],
      ),
    );
  }

  Widget _anomaly(
    BuildContext context,
    BeautifulInsightPage page,
    BeautifulInsightAnomaly chart,
  ) {
    final metric = chart.metrics.firstWhere(
      (m) => m.id == chart.selectedMetricId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chart.metrics
              .map(
                (m) => BeautifulActionControl(
                  key: ValueKey<String>(
                    'beautiful-insight-metric-${page.id}-${m.id}',
                  ),
                  label: m.label,
                  selected: m.id == chart.selectedMetricId,
                  onPressed: widget.onMetricChanged == null
                      ? null
                      : () => widget.onMetricChanged!(page.id, m.id),
                  minHeight: 48,
                  maxLines: null,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        _lineChart(
          context,
          page,
          metric.id,
          <BeautifulInsightSeries>[
            BeautifulInsightSeries(
              id: metric.id,
              label: metric.label,
              valueLabel: metric.valueLabel,
              detail: metric.detail,
              points: metric.points,
              tone: BeautifulInsightTone.negative,
            ),
          ],
          thresholdValue: metric.thresholdValue,
          thresholdLabel: metric.thresholdLabel,
        ),
      ],
    );
  }

  Widget _lineChart(
    BuildContext context,
    BeautifulInsightPage page,
    String chartId,
    List<BeautifulInsightSeries> series, {
    double? thresholdValue,
    String? thresholdLabel,
  }) {
    final theme = BeautifulUiTheme.of(context);
    final inspection = _inspections.putIfAbsent((
      page.id,
      chartId,
    ), _Inspection.new);
    final points = series.first.points;
    var selected = points.indexWhere((p) => p.id == inspection.pointId);
    if (selected < 0) selected = points.length - 1;
    final selectedIndex = selected;
    void inspect(int next) {
      final id = points[next.clamp(0, points.length - 1)].id;
      if (inspection.pointId != id) setState(() => inspection.pointId = id);
    }

    String describe(int index) => <String>[
      points[index].label,
      ...series.map((s) => '${s.label}: ${s.points[index].formattedValue}'),
    ].join('. ');
    final observation = describe(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: <Widget>[
            for (var i = 0; i < series.length; i++)
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ExcludeSemantics(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CustomPaint(
                              painter: _MarkerPainter(
                                index: i,
                                color: _tone(theme, series[i].tone),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            series[i].label,
                            style: theme.typography.label.copyWith(
                              color: theme.colors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      series[i].valueLabel,
                      style: theme.typography.label.copyWith(
                        color: theme.colors.ink,
                        fontSize: 18,
                      ),
                    ),
                    if (series[i].detail case final detail?)
                      Text(
                        detail,
                        style: theme.typography.caption.copyWith(
                          color: theme.colors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        if (thresholdLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              thresholdLabel,
              style: theme.typography.caption.copyWith(
                color: theme.colors.inkMuted,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _ChartInspection(
          key: ValueKey<(String, String)>((page.id, chartId)),
          label: '${page.chart.title}. ${page.chart.summary}',
          hint: widget.labels.inspectHint,
          observation: observation,
          previousObservation: selected > 0 ? describe(selected - 1) : null,
          nextObservation: selected < points.length - 1
              ? describe(selected + 1)
              : null,
          selected: selected,
          count: points.length,
          onChanged: inspect,
          child: RepaintBoundary(
            child: CustomPaint(
              key: ValueKey<String>('beautiful-insight-plot-${page.id}'),
              size: const Size(double.infinity, 180),
              painter: _LinePainter(
                series: series,
                colors: series.map((s) => _tone(theme, s.tone)).toList(),
                ink: theme.colors.ink,
                grid: theme.colors.lineStrong,
                selected: selected,
                threshold: thresholdValue,
                rtl: Directionality.of(context) == TextDirection.rtl,
                highContrast: MediaQuery.highContrastOf(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            observation,
            key: ValueKey<String>('beautiful-insight-observation-${page.id}'),
            style: theme.typography.caption.copyWith(color: theme.colors.ink),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            BeautifulActionControl(
              key: ValueKey<String>(
                'beautiful-insight-previous-point-${page.id}',
              ),
              label: widget.labels.previousPoint,
              onPressed: selected > 0 ? () => inspect(selectedIndex - 1) : null,
              minHeight: 48,
              maxLines: null,
            ),
            BeautifulActionControl(
              key: ValueKey<String>('beautiful-insight-next-point-${page.id}'),
              label: widget.labels.nextPoint,
              onPressed: selected < points.length - 1
                  ? () => inspect(selectedIndex + 1)
                  : null,
              minHeight: 48,
              maxLines: null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        BeautifulActionControl(
          key: ValueKey<String>('beautiful-insight-data-${page.id}'),
          label: inspection.showData
              ? widget.labels.hideData
              : widget.labels.showData,
          expanded: inspection.showData,
          onPressed: () =>
              setState(() => inspection.showData = !inspection.showData),
          minHeight: 48,
          maxLines: null,
        ),
        if (inspection.showData)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _InsightTextData(
              key: ValueKey<(String, String)>((page.id, chartId)),
              pageId: page.id,
              label: widget.labels.showData,
              series: series,
            ),
          ),
      ],
    );
  }

  Widget _allocation(
    BuildContext context,
    BeautifulInsightPage page,
    BeautifulInsightAllocation chart,
  ) {
    final theme = BeautifulUiTheme.of(context);
    final active = chart.segments.firstWhere(
      (s) => s.id == chart.selectedSegmentId,
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final colors = <Color>[
      theme.colors.accentInk,
      theme.colors.inkMuted,
      theme.colors.success,
      theme.colors.warning,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${active.label}: ${active.valueLabel}',
          key: ValueKey<String>(
            'beautiful-insight-allocation-value-${page.id}',
          ),
          style: theme.typography.label.copyWith(
            color: theme.colors.ink,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        // Narrow proportional segments have equivalent full-size legend actions.
        ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.onSegmentChanged == null
                  ? null
                  : (event) {
                      final fraction =
                          (event.localPosition.dx / constraints.maxWidth).clamp(
                            0.0,
                            1.0,
                          );
                      final position = rtl ? 1 - fraction : fraction;
                      var end = 0.0;
                      for (final segment in chart.segments) {
                        end += segment.share;
                        if (segment.share > 0 && position <= end) {
                          widget.onSegmentChanged!(page.id, segment.id);
                          return;
                        }
                      }
                    },
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: CustomPaint(
                  key: ValueKey<String>(
                    'beautiful-insight-allocation-bar-${page.id}',
                  ),
                  painter: _AllocationPainter(
                    segments: chart.segments,
                    selectedId: active.id,
                    colors: colors,
                    ink: theme.colors.ink,
                    rtl: rtl,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (var i = 0; i < chart.segments.length; i++)
              BeautifulActionControl(
                key: ValueKey<String>(
                  'beautiful-insight-segment-${page.id}-${chart.segments[i].id}',
                ),
                label:
                    '${chart.segments[i].label}: ${chart.segments[i].shareLabel}, ${chart.segments[i].valueLabel}',
                selected: chart.segments[i].id == active.id,
                leading: ExcludeSemantics(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CustomPaint(
                      painter: _MarkerPainter(
                        index: i,
                        color: colors[i % colors.length],
                      ),
                    ),
                  ),
                ),
                onPressed: widget.onSegmentChanged == null
                    ? null
                    : () => widget.onSegmentChanged!(
                        page.id,
                        chart.segments[i].id,
                      ),
                minHeight: 48,
                maxLines: null,
              ),
          ],
        ),
        if (active.detail case final detail?)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              detail,
              style: theme.typography.caption.copyWith(
                color: theme.colors.inkMuted,
              ),
            ),
          ),
      ],
    );
  }
}

final class _InsightTextData extends StatefulWidget {
  const _InsightTextData({
    super.key,
    required this.pageId,
    required this.label,
    required this.series,
  });

  final String pageId;
  final String label;
  final List<BeautifulInsightSeries> series;

  @override
  State<_InsightTextData> createState() => _InsightTextDataState();
}

final class _InsightTextDataState extends State<_InsightTextData> {
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _focused = false;
  bool _seekingEnd = false;

  @override
  void didUpdateWidget(_InsightTextData oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.series, widget.series)) _seekingEnd = false;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _jumpToEnd() {
    if (!mounted || !_seekingEnd || !_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
    // Variable-height translated rows refine the estimated end after layout.
    // Keep following that end until the actual final row is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_seekingEnd || !_scroll.hasClients) return;
      if ((_scroll.offset - _scroll.position.maxScrollExtent).abs() > 0.5) {
        _jumpToEnd();
      } else {
        _seekingEnd = false;
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        !_scroll.hasClients) {
      return KeyEventResult.ignored;
    }
    final position = _scroll.position;
    if (event.logicalKey == LogicalKeyboardKey.end) {
      _seekingEnd = true;
      _jumpToEnd();
      return KeyEventResult.handled;
    }
    final target = switch (event.logicalKey) {
      LogicalKeyboardKey.home => 0.0,
      LogicalKeyboardKey.arrowUp => position.pixels - 64,
      LogicalKeyboardKey.arrowDown => position.pixels + 64,
      LogicalKeyboardKey.pageUp =>
        position.pixels - position.viewportDimension * 0.85,
      LogicalKeyboardKey.pageDown =>
        position.pixels + position.viewportDimension * 0.85,
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    _seekingEnd = false;
    _scroll.jumpTo(target.clamp(0, position.maxScrollExtent));
    return KeyEventResult.handled;
  }

  Widget _row(int index, BeautifulUiThemeData theme) {
    final point = widget.series.first.points[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        '${point.label}. ${widget.series.map((s) => '${s.label}: ${s.points[index].formattedValue}').join('. ')}',
        key: ValueKey<String>(
          'beautiful-insight-datum-${widget.pageId}-${point.id}',
        ),
        style: theme.typography.caption.copyWith(color: theme.colors.ink),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final count = widget.series.first.points.length;
    if (count <= 24) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var index = 0; index < count; index++) _row(index, theme),
        ],
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.label,
      child: Focus(
        focusNode: _focus,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: _onKey,
        child: Listener(
          onPointerDown: (_) {
            _seekingEnd = false;
            _focus.requestFocus();
          },
          onPointerSignal: (_) => _seekingEnd = false,
          child: SizedBox(
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focused
                      ? theme.colors.accentInk
                      : theme.colors.lineStrong,
                  width: _focused ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(theme.radii.control),
              ),
              child: RawScrollbar(
                controller: _scroll,
                thumbVisibility: true,
                thumbColor: theme.colors.inkMuted,
                radius: Radius.circular(theme.radii.control),
                child: ListView.builder(
                  key: ValueKey<String>(
                    'beautiful-insight-data-scroll-${widget.pageId}',
                  ),
                  controller: _scroll,
                  primary: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: count,
                  itemBuilder: (context, index) => _row(index, theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ChartInspection extends StatefulWidget {
  const _ChartInspection({
    super.key,
    required this.label,
    required this.hint,
    required this.observation,
    required this.previousObservation,
    required this.nextObservation,
    required this.selected,
    required this.count,
    required this.onChanged,
    required this.child,
  });
  final String label;
  final String hint;
  final String observation;
  final String? previousObservation;
  final String? nextObservation;
  final int selected;
  final int count;
  final ValueChanged<int> onChanged;
  final Widget child;

  @override
  State<_ChartInspection> createState() => _ChartInspectionState();
}

final class _ChartInspectionState extends State<_ChartInspection> {
  final _focus = FocusNode();
  var _highlight = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final theme = BeautifulUiTheme.of(context);
    void change(int delta) =>
        widget.onChanged((widget.selected + delta).clamp(0, widget.count - 1));
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: widget.label,
      value: widget.observation,
      hint: widget.hint,
      focusable: true,
      focused: _focus.hasFocus,
      slider: widget.count > 1,
      enabled: true,
      onTap: _focus.requestFocus,
      onIncrease: widget.selected < widget.count - 1 ? () => change(1) : null,
      onDecrease: widget.selected > 0 ? () => change(-1) : null,
      increasedValue: widget.nextObservation,
      decreasedValue: widget.previousObservation,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowLeft:
              change(rtl ? 1 : -1);
            case LogicalKeyboardKey.arrowRight:
              change(rtl ? -1 : 1);
            case LogicalKeyboardKey.arrowUp:
              change(1);
            case LogicalKeyboardKey.arrowDown:
              change(-1);
            case LogicalKeyboardKey.home:
              widget.onChanged(0);
            case LogicalKeyboardKey.end:
              widget.onChanged(widget.count - 1);
            default:
              return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: FocusableActionDetector(
          focusNode: _focus,
          onFocusChange: (_) => setState(() {}),
          onShowFocusHighlight: (value) => setState(() => _highlight = value),
          child: LayoutBuilder(
            builder: (context, constraints) {
              void inspect(Offset position) {
                final fraction =
                    ((position.dx - 12) /
                            math.max(1, constraints.maxWidth - 24))
                        .clamp(0.0, 1.0);
                widget.onChanged(
                  ((rtl ? 1 - fraction : fraction) * (widget.count - 1))
                      .round(),
                );
              }

              return MouseRegion(
                onHover: (event) => inspect(event.localPosition),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (event) {
                    _focus.requestFocus();
                    inspect(event.localPosition);
                  },
                  onHorizontalDragUpdate: (event) =>
                      inspect(event.localPosition),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colors.inset,
                      border: Border.all(
                        color: _highlight
                            ? theme.colors.accentInk
                            : theme.colors.lineStrong,
                        width: _highlight ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(theme.radii.control),
                    ),
                    child: ExcludeSemantics(child: widget.child),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Color _tone(BeautifulUiThemeData theme, BeautifulInsightTone tone) =>
    switch (tone) {
      BeautifulInsightTone.accent => theme.colors.accentInk,
      BeautifulInsightTone.positive => theme.colors.success,
      BeautifulInsightTone.negative => theme.colors.destructive,
      BeautifulInsightTone.neutral => theme.colors.inkMuted,
    };

final class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({required this.index, required this.color});
  final int index;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => _marker(
    canvas,
    size.center(Offset.zero),
    4,
    index,
    Paint()..color = color,
  );
  @override
  bool shouldRepaint(_MarkerPainter old) =>
      old.index != index || old.color != color;
}

void _marker(
  Canvas canvas,
  Offset center,
  double radius,
  int index,
  Paint paint,
) {
  switch (index % 4) {
    case 0:
      canvas.drawCircle(center, radius, paint);
    case 1:
      canvas.drawRect(
        Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
        paint,
      );
    case 2:
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius, center.dy + radius)
          ..lineTo(center.dx - radius, center.dy + radius)
          ..close(),
        paint,
      );
    case 3:
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius, center.dy)
          ..lineTo(center.dx, center.dy + radius)
          ..lineTo(center.dx - radius, center.dy)
          ..close(),
        paint,
      );
  }
}

final class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.series,
    required this.colors,
    required this.ink,
    required this.grid,
    required this.selected,
    required this.threshold,
    required this.rtl,
    required this.highContrast,
  });
  final List<BeautifulInsightSeries> series;
  final List<Color> colors;
  final Color ink;
  final Color grid;
  final int selected;
  final double? threshold;
  final bool rtl;
  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(12);
    if (rect.isEmpty) return;
    final values = <double>[
      for (final item in series) ...item.points.map((p) => p.value),
      ?threshold,
    ];
    final scale = values.fold<double>(
      1,
      (value, next) => math.max(value, next.abs()),
    );
    final min = values.map((v) => v / scale).reduce(math.min);
    final max = values.map((v) => v / scale).reduce(math.max);
    final span = max - min;
    double y(double value) => span == 0
        ? rect.center.dy
        : rect.bottom - ((value / scale - min) / span) * rect.height;
    double x(int index) {
      final fraction = series.first.points.length == 1
          ? 0.5
          : index / (series.first.points.length - 1);
      return rect.left + (rtl ? 1 - fraction : fraction) * rect.width;
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = 0; i < 4; i++) {
      final dy = rect.top + rect.height * i / 3;
      canvas.drawLine(
        Offset(rect.left, dy),
        Offset(rect.right, dy),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
    }
    if (threshold case final threshold?) {
      for (double dx = rect.left; dx < rect.right; dx += 10) {
        canvas.drawLine(
          Offset(dx, y(threshold)),
          Offset(math.min(dx + 5, rect.right), y(threshold)),
          Paint()
            ..color = ink
            ..strokeWidth = 1.5,
        );
      }
    }
    for (var s = 0; s < series.length; s++) {
      final item = series[s];
      final paint = Paint()
        ..color = colors[s]
        ..strokeWidth = highContrast ? 3 : 2.25
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < item.points.length; i++) {
        final position = Offset(x(i), y(item.points[i].value));
        if (i == 0) {
          path.moveTo(position.dx, position.dy);
        } else {
          path.lineTo(position.dx, position.dy);
        }
      }
      if (s.isEven) {
        canvas.drawPath(path, paint);
      } else {
        for (final metric in path.computeMetrics()) {
          for (double offset = 0; offset < metric.length; offset += 10) {
            canvas.drawPath(
              metric.extractPath(offset, math.min(offset + 6, metric.length)),
              paint,
            );
          }
        }
      }
      final markerPaint = Paint()..color = colors[s];
      final stride = math.max(1, (item.points.length / 12).ceil());
      for (var i = 0; i < item.points.length; i += stride) {
        _marker(
          canvas,
          Offset(x(i), y(item.points[i].value)),
          3,
          s,
          markerPaint,
        );
      }
      _marker(
        canvas,
        Offset(x(selected), y(item.points[selected].value)),
        5,
        s,
        markerPaint,
      );
    }
    canvas.drawLine(
      Offset(x(selected), rect.top),
      Offset(x(selected), rect.bottom),
      Paint()
        ..color = ink
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      !identical(old.series, series) ||
      !listEquals(old.colors, colors) ||
      old.ink != ink ||
      old.grid != grid ||
      old.selected != selected ||
      old.threshold != threshold ||
      old.rtl != rtl ||
      old.highContrast != highContrast;
}

final class _AllocationPainter extends CustomPainter {
  const _AllocationPainter({
    required this.segments,
    required this.selectedId,
    required this.colors,
    required this.ink,
    required this.rtl,
  });
  final List<BeautifulInsightAllocationSegment> segments;
  final String selectedId;
  final List<Color> colors;
  final Color ink;
  final bool rtl;
  @override
  void paint(Canvas canvas, Size size) {
    var progress = 0.0;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final width = segment.share * size.width;
      if (width > 0) {
        final left = rtl ? size.width - progress - width : progress;
        final rect = Rect.fromLTWH(
          left + 1,
          4,
          math.max(0, width - 2),
          size.height - 8,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          Paint()..color = colors[i % colors.length],
        );
        if (segment.id == selectedId) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(3)),
            Paint()
              ..color = ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        }
        if (width > 16) {
          _marker(canvas, rect.center, 4, i, Paint()..color = ink);
        }
      }
      progress += width;
    }
  }

  @override
  bool shouldRepaint(_AllocationPainter old) =>
      !identical(old.segments, segments) ||
      old.selectedId != selectedId ||
      !listEquals(old.colors, colors) ||
      old.ink != ink ||
      old.rtl != rtl;
}

void _text(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
}

void _ids(
  Iterable<String> values,
  String name,
  int maximum, {
  bool allowEmpty = false,
}) {
  final ids = values.toList(growable: false);
  if ((!allowEmpty && ids.isEmpty) || ids.length > maximum) {
    throw ArgumentError(
      '$name must contain ${allowEmpty ? 0 : 1}–$maximum items.',
    );
  }
  final unique = <String>{};
  for (final id in ids) {
    _text(id, '$name.id');
    if (!unique.add(id)) {
      throw ArgumentError.value(id, name, 'IDs must be unique.');
    }
  }
}

void _validatePoints(List<BeautifulInsightPoint> points) {
  _ids(points.map((p) => p.id), 'points', 512);
  for (final point in points) {
    _text(point.label, 'point.label');
    _text(point.formattedValue, 'point.formattedValue');
    if (!point.value.isFinite) {
      throw ArgumentError.value(point.value, 'point.value', 'Must be finite.');
    }
  }
}
