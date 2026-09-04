import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/failure.dart';
import '../foundation/layout.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';

/// The meaning of one proposed record change, independent of color.
enum BeautifulDiffChange {
  /// A new record with no previous value.
  added,

  /// An existing record proposed for removal.
  removed,

  /// An existing record with changed values.
  modified,

  /// Context that is identical before and after the proposal.
  unchanged,
}

/// One caller-defined field displayed in each record comparison.
@immutable
final class BeautifulDiffColumn {
  /// Creates a field with a stable identity and localized heading.
  const BeautifulDiffColumn({required this.id, required this.label})
    : assert(id != '');

  /// Stable, non-empty identity matching keys in the record value maps.
  final String id;

  /// Localized visible and assistive heading.
  final String label;
}

/// An immutable pair of record snapshots for [BeautifulDiffTable].
///
/// A missing [before] means addition; a missing [after] means removal. Both
/// present means modification or unchanged context. Maps are copied on
/// construction; values are exact caller-formatted strings, never parsed.
@immutable
final class BeautifulDiffRow {
  /// Creates a comparison; at least one record snapshot is required.
  BeautifulDiffRow({
    required this.id,
    Map<String, String>? before,
    Map<String, String>? after,
  }) : assert(id != ''),
       assert(before != null || after != null),
       before = before == null
           ? null
           : Map<String, String>.unmodifiable(before),
       after = after == null ? null : Map<String, String>.unmodifiable(after);

  /// Stable, non-empty record identity, unique within the proposal.
  final String id;

  /// Previous values keyed by [BeautifulDiffColumn.id], or null for additions.
  final Map<String, String>? before;

  /// Proposed values keyed by [BeautifulDiffColumn.id], or null for removals.
  final Map<String, String>? after;

  /// The inferred record change, including non-interactive unchanged context.
  BeautifulDiffChange get kind {
    if (before == null) return BeautifulDiffChange.added;
    if (after == null) return BeautifulDiffChange.removed;
    return mapEquals(before, after)
        ? BeautifulDiffChange.unchanged
        : BeautifulDiffChange.modified;
  }
}

/// Localized visible and assistive text for [BeautifulDiffTable].
@immutable
final class BeautifulDiffTableLabels {
  /// Creates comparison, selection, action, and result labels.
  const BeautifulDiffTableLabels({
    this.change = 'Change',
    this.before = 'Before',
    this.after = 'After',
    this.added = 'Added',
    this.removed = 'Removed',
    this.modified = 'Changed',
    this.unchanged = 'Unchanged',
    this.absent = 'No record',
    this.missingValue = 'No value',
    this.include = 'Include change',
    this.included = 'Included',
    this.excluded = 'Excluded',
    this.selected = 'Selected changes',
    this.apply = 'Apply changes',
    this.applying = 'Applying changes',
    this.applied = 'Changes applied',
    this.applyFailed = 'Changes could not be applied. Try again.',
    this.empty = 'No records to compare',
    this.previous = 'Previous page',
    this.next = 'Next page',
    this.page = 'Page',
  });

  /// Heading for the record change and inclusion control.
  final String change;

  /// Heading identifying previous values.
  final String before;

  /// Heading identifying proposed values.
  final String after;

  /// Text identifying additions, independent of tint.
  final String added;

  /// Text identifying removals, independent of tint or strike-through.
  final String removed;

  /// Text identifying modifications.
  final String modified;

  /// Text identifying unchanged context.
  final String unchanged;

  /// Value shown when a before or after record does not exist.
  final String absent;

  /// Value shown when a record lacks a particular column.
  final String missingValue;

  /// Selection control text, followed by record identity in Semantics.
  final String include;

  /// Visible text for a selected change.
  final String included;

  /// Visible text for a change excluded from the submission.
  final String excluded;

  /// Prefix for the count of selected changes across all pages.
  final String selected;

  /// Apply action text, followed by its count.
  final String apply;

  /// Pending action and status text.
  final String applying;

  /// Successful action and status text, followed by its count.
  final String applied;

  /// Localized failure feedback; diagnostic details use the root failure seam.
  final String applyFailed;

  /// Empty proposal message.
  final String empty;

  /// Previous-page action text.
  final String previous;

  /// Next-page action text.
  final String next;

  /// Page counter prefix.
  final String page;

  String _kind(BeautifulDiffChange kind) => switch (kind) {
    BeautifulDiffChange.added => added,
    BeautifulDiffChange.removed => removed,
    BeautifulDiffChange.modified => modified,
    BeautifulDiffChange.unchanged => unchanged,
  };
}

/// A paginated before/after review with individually selectable changes.
///
/// The host owns record snapshots and [onApply], which performs the real
/// external action. The widget owns inclusion drafts, page, and pending or
/// successful presentation. [initialIncludedRowIds] seeds inclusion once per
/// [id]; null selects every changed row, and unchanged context is never sent.
/// Changing [id] starts a fresh proposal. Meaningful column or record changes
/// invalidate pending results; equal snapshots and callback rebuilds do not.
/// Same-proposal updates preserve choices for surviving changed rows and
/// include new changed rows by default. Successful application locks inclusion
/// until the proposal changes, and is shown only after [onApply] completes.
///
/// Compact and medium widths present one wrapping change card per record;
/// expanded widths align Change, Before, and After columns. Labels identify
/// meaning independently of color. The host supplies vertical scrolling.
/// At most [pageSize] records are built, bounding rendering for large inputs.
/// The supported verification workload is 500 records with three fields each,
/// at the default 20 records per page. Text is displayed, not editable.
///
/// ```dart
/// BeautifulDiffTable(
///   id: 'proposal-1',
///   title: 'Proposed inventory change',
///   columns: const [BeautifulDiffColumn(id: 'name', label: 'Name')],
///   rows: [BeautifulDiffRow(id: 'new', after: {'name': 'New item'})],
///   onApply: (includedIds) async { /* apply exactly these record changes */ },
/// )
/// ```
final class BeautifulDiffTable extends StatefulWidget {
  /// Creates a proposal review with optional asynchronous application.
  const BeautifulDiffTable({
    super.key,
    required this.id,
    required this.title,
    required this.columns,
    required this.rows,
    this.initialIncludedRowIds,
    this.onApply,
    this.errorMessage,
    this.labels = const BeautifulDiffTableLabels(),
    this.pageSize = 20,
  }) : assert(id != ''),
       assert(pageSize > 0 && pageSize <= 100);

  /// Stable identity of this proposal; change it to reset presentation state.
  final String id;

  /// Caller-owned, fully wrapping proposal title.
  final String title;

  /// Ordered field definitions with unique, non-empty IDs.
  final List<BeautifulDiffColumn> columns;

  /// Caller-owned record snapshot in display order, with unique IDs.
  final List<BeautifulDiffRow> rows;

  /// Initial selected change IDs, read once per proposal identity.
  final Set<String>? initialIncludedRowIds;

  /// Applies an immutable set of selected record IDs across all pages.
  ///
  /// Null leaves the proposal reviewable but disables application. Concurrent
  /// activations are de-duplicated. Failure preserves choices and permits retry.
  final Future<void> Function(Set<String> includedRowIds)? onApply;

  /// Optional caller-owned error, shown verbatim without changing the proposal.
  final String? errorMessage;

  /// Localized text for package-owned controls and states.
  final BeautifulDiffTableLabels labels;

  /// Maximum rendered records per page, from 1 to 100; defaults to 20.
  final int pageSize;

  @override
  State<BeautifulDiffTable> createState() => _BeautifulDiffTableState();
}

final class _BeautifulDiffTableState extends State<BeautifulDiffTable> {
  List<BeautifulDiffColumn> _columns = const [];
  List<BeautifulDiffRow> _rows = const [];
  Set<String> _included = <String>{};
  Map<BeautifulDiffChange, int>? _includedCounts;
  var _page = 0;
  var _generation = 0;
  var _pending = false;
  var _applied = false;
  var _failed = false;
  int _debugSummaryComputations = 0;
  int _debugSummaryRowVisits = 0;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    assert(() {
      properties
        ..add(IntProperty('summaryComputations', _debugSummaryComputations))
        ..add(IntProperty('summaryRowVisits', _debugSummaryRowVisits));
      return true;
    }());
  }

  int get _pages => math.max(1, (_rows.length / widget.pageSize).ceil());

  @override
  void initState() {
    super.initState();
    _snapshot(reset: true);
  }

  @override
  void didUpdateWidget(BeautifulDiffTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _snapshot(reset: oldWidget.id != widget.id);
    _page = math.min(_page, _pages - 1);
  }

  void _snapshot({required bool reset}) {
    final columns = List<BeautifulDiffColumn>.unmodifiable(widget.columns);
    final rows = List<BeautifulDiffRow>.unmodifiable(widget.rows);
    assert(() {
      final columnIds = <String>{};
      final rowIds = <String>{};
      if (columns.isEmpty ||
          columns.any(
            (column) => column.id.isEmpty || !columnIds.add(column.id),
          )) {
        throw FlutterError(
          'BeautifulDiffTable requires at least one column and unique, '
          'non-empty column ids.',
        );
      }
      if (rows.any((row) => row.id.isEmpty || !rowIds.add(row.id))) {
        throw FlutterError(
          'BeautifulDiffTable requires unique, non-empty row ids.',
        );
      }
      return true;
    }());
    final changed =
        reset || !_sameColumns(columns, _columns) || !_sameRows(rows, _rows);
    final changedIds = <String>{
      for (final row in rows)
        if (row.kind != BeautifulDiffChange.unchanged) row.id,
    };
    if (reset) {
      _included = widget.initialIncludedRowIds == null
          ? changedIds
          : changedIds.intersection(widget.initialIncludedRowIds!);
      _page = 0;
    } else if (changed) {
      final oldIds = <String>{
        for (final row in _rows)
          if (row.kind != BeautifulDiffChange.unchanged) row.id,
      };
      _included = _included.intersection(changedIds)
        ..addAll(changedIds.difference(oldIds));
    }
    if (changed) {
      _includedCounts = null;
      _generation++;
      _pending = false;
      _applied = false;
      _failed = false;
    }
    _columns = columns;
    _rows = rows;
  }

  void _toggle(String id) {
    if (_pending || _applied) return;
    setState(() {
      if (!_included.add(id)) _included.remove(id);
      _includedCounts = null;
      _failed = false;
    });
  }

  Future<void> _apply() async {
    final callback = widget.onApply;
    if (_pending || _applied || _included.isEmpty || callback == null) return;
    final generation = ++_generation;
    final ids = Set<String>.unmodifiable(_included);
    setState(() {
      _pending = true;
      _failed = false;
    });
    try {
      await callback(ids);
    } catch (error, stackTrace) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _pending = false;
        _failed = true;
      });
      BeautifulUiEnvironment.of(context).reportFailure(
        BeautifulUiFailure(
          operation: BeautifulUiOperation.diff,
          message: 'Diff application failed for proposal "${widget.id}".',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
      return;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _pending = false;
      _applied = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded =
            BeautifulUiEnvironment.of(context).modeFor(context, constraints) ==
            BeautifulLayoutMode.expanded;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final start = _page * widget.pageSize;
        final visible = _rows.skip(start).take(widget.pageSize);
        final labels = widget.labels;
        final summary = _summary();
        final error =
            widget.errorMessage ?? (_failed ? labels.applyFailed : null);
        return SizedBox(
          width: width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border.all(color: theme.colors.lineStrong),
              borderRadius: BorderRadius.circular(theme.radii.card),
              boxShadow: theme.shadows.card,
            ),
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(theme.spacing.md),
                    child: Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        style: theme.typography.label.copyWith(
                          color: theme.colors.ink,
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    key: const ValueKey<String>('diff-table-records'),
                    container: true,
                    explicitChildNodes: true,
                    role: _rows.isEmpty
                        ? null
                        : expanded
                        ? SemanticsRole.table
                        : SemanticsRole.list,
                    label: widget.title,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (expanded && _rows.isNotEmpty) _headings(theme),
                        if (_rows.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(theme.spacing.md),
                            child: Text(
                              labels.empty,
                              style: theme.typography.body.copyWith(
                                color: theme.colors.inkMuted,
                              ),
                            ),
                          ),
                        for (final row in visible)
                          _DiffRecord(
                            key: ValueKey<String>('diff-table-row-${row.id}'),
                            row: row,
                            columns: _columns,
                            labels: labels,
                            expanded: expanded,
                            included: _included.contains(row.id),
                            onToggle: _pending || _applied
                                ? null
                                : () => _toggle(row.id),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(theme.spacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Semantics(
                          container: true,
                          liveRegion: true,
                          excludeSemantics: true,
                          label: summary,
                          child: Text(
                            summary,
                            style: theme.typography.caption.copyWith(
                              color: theme.colors.inkMuted,
                            ),
                          ),
                        ),
                        if (error != null) ...<Widget>[
                          SizedBox(height: theme.spacing.sm),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              style: theme.typography.body.copyWith(
                                color: theme.colors.destructive,
                              ),
                            ),
                          ),
                        ],
                        if (_pages > 1) ...<Widget>[
                          SizedBox(height: theme.spacing.sm),
                          Text(
                            '${labels.page} ${_page + 1} / $_pages',
                            style: theme.typography.caption.copyWith(
                              color: theme.colors.inkMuted,
                            ),
                          ),
                          SizedBox(height: theme.spacing.sm),
                          Wrap(
                            spacing: theme.spacing.sm,
                            runSpacing: theme.spacing.sm,
                            children: <Widget>[
                              BeautifulActionControl(
                                key: const ValueKey('diff-table-previous'),
                                label: labels.previous,
                                minHeight: 48,
                                maxLines: null,
                                onPressed: _page == 0
                                    ? null
                                    : () => setState(() => _page--),
                              ),
                              BeautifulActionControl(
                                key: const ValueKey('diff-table-next'),
                                label: labels.next,
                                minHeight: 48,
                                maxLines: null,
                                onPressed: _page >= _pages - 1
                                    ? null
                                    : () => setState(() => _page++),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: theme.spacing.sm),
                        BeautifulActionControl(
                          key: const ValueKey('diff-table-apply'),
                          label: _pending
                              ? labels.applying
                              : _applied
                              ? '${labels.applied}: ${_included.length}'
                              : '${labels.apply} (${_included.length})',
                          minHeight: 48,
                          maxLines: null,
                          fullWidth: !expanded,
                          tone: _applied
                              ? BeautifulActionTone.success
                              : BeautifulActionTone.primary,
                          onPressed:
                              _pending ||
                                  _applied ||
                                  _included.isEmpty ||
                                  widget.onApply == null
                              ? null
                              : () => unawaited(_apply()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _summary() {
    final labels = widget.labels;
    if (_pending) return labels.applying;
    if (_applied) return '${labels.applied}: ${_included.length}';
    // Pagination and inherited/label changes do not alter these quantities.
    // Format using current labels and status instead of caching visible text.
    final counts = _includedCounts ??= _countIncludedChanges();
    return '${labels.selected}: ${_included.length}. '
        '${labels.removed}: ${counts[BeautifulDiffChange.removed] ?? 0}, '
        '${labels.added}: ${counts[BeautifulDiffChange.added] ?? 0}, '
        '${labels.modified}: ${counts[BeautifulDiffChange.modified] ?? 0}';
  }

  Map<BeautifulDiffChange, int> _countIncludedChanges() {
    assert(() {
      _debugSummaryComputations++;
      return true;
    }());
    final counts = <BeautifulDiffChange, int>{};
    for (final row in _rows) {
      assert(() {
        _debugSummaryRowVisits++;
        return true;
      }());
      if (_included.contains(row.id)) {
        counts.update(row.kind, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return Map<BeautifulDiffChange, int>.unmodifiable(counts);
  }

  Widget _headings(BeautifulUiThemeData theme) => Semantics(
    role: SemanticsRole.row,
    child: Row(
      children: <Widget>[
        for (final (index, label) in <String>[
          widget.labels.change,
          widget.labels.before,
          widget.labels.after,
        ].indexed)
          Expanded(
            flex: index == 0 ? 3 : 5,
            child: Semantics(
              role: SemanticsRole.columnHeader,
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.md),
                child: Text(
                  label,
                  style: theme.typography.label.copyWith(
                    color: theme.colors.inkMuted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

final class _DiffRecord extends StatelessWidget {
  const _DiffRecord({
    super.key,
    required this.row,
    required this.columns,
    required this.labels,
    required this.expanded,
    required this.included,
    required this.onToggle,
  });

  final BeautifulDiffRow row;
  final List<BeautifulDiffColumn> columns;
  final BeautifulDiffTableLabels labels;
  final bool expanded;
  final bool included;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final changed = row.kind != BeautifulDiffChange.unchanged;
    final tint = !included
        ? theme.colors.surface
        : switch (row.kind) {
            BeautifulDiffChange.added => theme.colors.successTint,
            BeautifulDiffChange.removed => theme.colors.destructiveTint,
            BeautifulDiffChange.modified => theme.colors.accentTint,
            BeautifulDiffChange.unchanged => theme.colors.surface,
          };
    final rowName =
        row.after?[columns.first.id] ?? row.before?[columns.first.id] ?? row.id;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: expanded ? SemanticsRole.row : SemanticsRole.listItem,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tint,
          border: Border(top: BorderSide(color: theme.colors.lineStrong)),
        ),
        child: Flex(
          direction: expanded ? Axis.horizontal : Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: expanded
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var index = 0; index < 3; index++)
              Flexible(
                flex: expanded ? (index == 0 ? 3 : 5) : 0,
                fit: expanded ? FlexFit.tight : FlexFit.loose,
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  role: expanded ? SemanticsRole.cell : SemanticsRole.none,
                  child: Padding(
                    padding: EdgeInsets.all(theme.spacing.md),
                    child: index == 0
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                labels._kind(row.kind),
                                style: theme.typography.label.copyWith(
                                  color: theme.colors.ink,
                                ),
                              ),
                              if (changed) ...<Widget>[
                                SizedBox(height: theme.spacing.sm),
                                BeautifulActionControl(
                                  key: ValueKey('diff-table-include-${row.id}'),
                                  label: included
                                      ? labels.included
                                      : labels.excluded,
                                  semanticLabel:
                                      '${labels.include}: $rowName, '
                                      '${labels._kind(row.kind)}',
                                  selected: included,
                                  fullWidth: true,
                                  maxLines: null,
                                  minHeight: 48,
                                  tone: BeautifulActionTone.secondary,
                                  leading: CustomPaint(
                                    size: const Size.square(14),
                                    painter: _DiffMarkPainter(
                                      theme.colors.ink,
                                      included: included,
                                    ),
                                  ),
                                  onPressed: onToggle,
                                ),
                              ],
                            ],
                          )
                        : _values(theme, before: index == 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _values(BeautifulUiThemeData theme, {required bool before}) {
    final values = before ? row.before : row.after;
    final heading = before ? labels.before : labels.after;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          heading,
          style: theme.typography.caption.copyWith(
            color: theme.colors.inkMuted,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        if (values == null)
          Text(
            labels.absent,
            style: theme.typography.body.copyWith(color: theme.colors.inkMuted),
          )
        else
          for (final column in columns)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.xs),
              child: Text(
                '${column.label}: '
                '${values[column.id] ?? labels.missingValue}',
                style: theme.typography.body.copyWith(
                  color: theme.colors.ink,
                  decoration:
                      before &&
                          included &&
                          row.kind == BeautifulDiffChange.removed
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
      ],
    );
  }
}

bool _sameColumns(
  List<BeautifulDiffColumn> left,
  List<BeautifulDiffColumn> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index].id != right[index].id ||
        left[index].label != right[index].label) {
      return false;
    }
  }
  return true;
}

bool _sameRows(List<BeautifulDiffRow> left, List<BeautifulDiffRow> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index].id != right[index].id ||
        !mapEquals(left[index].before, right[index].before) ||
        !mapEquals(left[index].after, right[index].after)) {
      return false;
    }
  }
  return true;
}

final class _DiffMarkPainter extends CustomPainter {
  const _DiffMarkPainter(this.color, {required this.included});

  final Color color;
  final bool included;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (included) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * .12, size.height * .5)
          ..lineTo(size.width * .4, size.height * .78)
          ..lineTo(size.width * .88, size.height * .2),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(size.width * .2, size.height * .5),
        Offset(size.width * .8, size.height * .5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DiffMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.included != included;
}
