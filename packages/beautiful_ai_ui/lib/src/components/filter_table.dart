import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/layout.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';

/// The three task states supported by [BeautifulFilterTable].
enum BeautifulFilterTableStatus {
  /// Work that has not started.
  todo,

  /// Work currently in progress.
  inProgress,

  /// Completed work.
  completed,
}

/// An immutable task snapshot displayed by [BeautifulFilterTable].
///
/// Dates are caller-formatted display text. The component never parses dates,
/// fetches records, or changes task status.
final class BeautifulFilterTableRow {
  /// Creates a row with stable identity and caller-owned business data.
  const BeautifulFilterTableRow({
    required this.id,
    required this.task,
    required this.date,
    required this.status,
    required this.owner,
  }) : assert(id != ''),
       assert(task != '');

  /// Stable, non-empty identity, unique within one table.
  final String id;

  /// The full task name.
  final String task;

  /// A date already formatted for the host application's locale.
  final String date;

  /// Task state used by the local status filter.
  final BeautifulFilterTableStatus status;

  /// The task's owner or advisor.
  final String owner;
}

/// Localized visible and assistive text for [BeautifulFilterTable].
final class BeautifulFilterTableLabels {
  /// Creates labels for the filters, column headings, and result states.
  const BeautifulFilterTableLabels({
    this.all = 'All',
    this.todo = 'To do',
    this.inProgress = 'In progress',
    this.completed = 'Completed',
    this.taskColumn = 'Task name',
    this.dateColumn = 'Date',
    this.statusColumn = 'Status',
    this.ownerColumn = 'Advisor',
    this.table = 'Tasks',
    this.results = 'Matching tasks',
    this.empty = 'No matching tasks',
  });

  /// Label for the filter showing every row.
  final String all;

  /// Label for tasks that have not started.
  final String todo;

  /// Label for tasks in progress.
  final String inProgress;

  /// Label for completed tasks.
  final String completed;

  /// Task heading, also used in row semantics.
  final String taskColumn;

  /// Date heading, also shown in compact cards.
  final String dateColumn;

  /// Status heading, also used in row semantics.
  final String statusColumn;

  /// Owner heading, also shown in compact cards.
  final String ownerColumn;

  /// Assistive label for the task table or compact list.
  final String table;

  /// Label for the matching-count announcement.
  final String results;

  /// Visible and assistive message when the selected filter has no rows.
  final String empty;

  String _status(BeautifulFilterTableStatus? status) => switch (status) {
    null => all,
    BeautifulFilterTableStatus.todo => todo,
    BeautifulFilterTableStatus.inProgress => inProgress,
    BeautifulFilterTableStatus.completed => completed,
  };
}

/// A task table whose status chips filter an immutable row snapshot.
///
/// The table owns its presentation filter. [initialStatus] is read only when
/// its state is created; null means All. [onFilterChanged] is a notification,
/// not a controlled-value mechanism. Resizing, updating rows, and changing
/// labels preserve the selected filter, including when it has no matches.
/// Recreate the widget with a different key to reset it programmatically.
///
/// Counts are derived from [rows], never from demonstration data. Rows are
/// copied defensively when the widget is mounted or updated. Hidden rows leave
/// both the visible and Semantics trees immediately. Compact and medium widths
/// show fully wrapping cards; expanded widths show four aligned columns.
///
/// The component sizes to its contents. The host supplies a scrollable parent
/// for long result sets. Network access, persistence, and row editing remain
/// in the host application.
///
/// ```dart
/// BeautifulFilterTable(
///   rows: const <BeautifulFilterTableRow>[
///     BeautifulFilterTableRow(
///       id: 'inventory',
///       task: 'Review inventory',
///       date: 'Sep 3',
///       status: BeautifulFilterTableStatus.inProgress,
///       owner: 'Operations',
///     ),
///   ],
/// )
/// ```
final class BeautifulFilterTable extends StatefulWidget {
  /// Creates a table with an optional initial presentation filter.
  const BeautifulFilterTable({
    super.key,
    required this.rows,
    this.initialStatus,
    this.onFilterChanged,
    this.labels = const BeautifulFilterTableLabels(),
  });

  /// Caller-owned row snapshot in display order, with unique non-empty IDs.
  final List<BeautifulFilterTableRow> rows;

  /// The filter used when this state is first created; null means All.
  final BeautifulFilterTableStatus? initialStatus;

  /// Receives each user filter change exactly once; null means All.
  final ValueChanged<BeautifulFilterTableStatus?>? onFilterChanged;

  /// Localized labels for all package-owned text.
  final BeautifulFilterTableLabels labels;

  @override
  State<BeautifulFilterTable> createState() => _BeautifulFilterTableState();
}

final class _BeautifulFilterTableState extends State<BeautifulFilterTable> {
  late List<BeautifulFilterTableRow> _rows;
  BeautifulFilterTableStatus? _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _takeSnapshot();
  }

  @override
  void didUpdateWidget(BeautifulFilterTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _takeSnapshot();
  }

  void _takeSnapshot() {
    _rows = List<BeautifulFilterTableRow>.unmodifiable(widget.rows);
    assert(() {
      final ids = <String>{};
      for (final row in _rows) {
        if (row.id.isEmpty || !ids.add(row.id)) {
          throw FlutterError(
            'BeautifulFilterTable requires unique, non-empty row ids; '
            '`${row.id}` is invalid or duplicated.',
          );
        }
      }
      return true;
    }());
  }

  void _select(BeautifulFilterTableStatus? status) {
    if (_status == status) return;
    setState(() => _status = status);
    widget.onFilterChanged?.call(status);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final visibleRows = _rows
        .where((row) => _status == null || row.status == _status)
        .toList(growable: false);
    final resultCount = '${visibleRows.length} / ${_rows.length}';
    // Isolate the numeric ratio without changing the localized prefix's bidi
    // direction. Otherwise an RTL paragraph paints "1 / 12" as "12 / 1".
    final visibleCount = Directionality.of(context) == TextDirection.rtl
        ? '\u2066$resultCount\u2069'
        : resultCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded =
            BeautifulUiEnvironment.of(context).modeFor(context, constraints) ==
            BeautifulLayoutMode.expanded;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FocusTraversalGroup(
                child: Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    for (final status in <BeautifulFilterTableStatus?>[
                      null,
                      ...BeautifulFilterTableStatus.values,
                    ])
                      _filter(theme, status, width),
                  ],
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              Semantics(
                container: true,
                liveRegion: true,
                label:
                    '${widget.labels.results}: '
                    '${visibleRows.length} / ${_rows.length}',
                excludeSemantics: true,
                child: Text(
                  '${widget.labels.results}: $visibleCount',
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.inkMuted,
                  ),
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              if (visibleRows.isEmpty)
                _surface(
                  theme,
                  Padding(
                    padding: EdgeInsets.all(theme.spacing.lg),
                    child: Text(
                      widget.labels.empty,
                      style: theme.typography.body.copyWith(
                        color: theme.colors.inkMuted,
                      ),
                    ),
                  ),
                )
              else if (expanded)
                _table(theme, visibleRows)
              else
                _cards(theme, visibleRows),
            ],
          ),
        );
      },
    );
  }

  Widget _filter(
    BeautifulUiThemeData theme,
    BeautifulFilterTableStatus? status,
    double maxWidth,
  ) {
    final count = status == null
        ? _rows.length
        : _rows.where((row) => row.status == status).length;
    final selected = _status == status;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: IntrinsicWidth(
        child: BeautifulActionControl(
          key: ValueKey<String>('filter-table-filter-${status?.name ?? 'all'}'),
          label: '${widget.labels._status(status)} ($count)',
          semanticLabel: '${widget.labels._status(status)}, $count',
          selected: selected,
          tone: selected
              ? BeautifulActionTone.secondary
              : BeautifulActionTone.quiet,
          minHeight: 48,
          fullWidth: true,
          maxLines: null,
          leading: selected
              ? CustomPaint(
                  size: const Size.square(12),
                  painter: _FilterCheckPainter(theme.colors.ink),
                )
              : status == null
              ? null
              : _dot(theme, status),
          onPressed: () => _select(status),
        ),
      ),
    );
  }

  Widget _surface(BeautifulUiThemeData theme, Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      color: theme.colors.surface,
      border: Border.all(color: theme.colors.lineStrong),
      borderRadius: BorderRadius.circular(theme.radii.card),
      boxShadow: theme.shadows.card,
    ),
    child: child,
  );

  Widget _cards(
    BeautifulUiThemeData theme,
    List<BeautifulFilterTableRow> rows,
  ) => Semantics(
    key: const ValueKey<String>('filter-table-list'),
    container: true,
    explicitChildNodes: true,
    role: SemanticsRole.list,
    label: widget.labels.table,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < rows.length; index++) ...<Widget>[
          if (index > 0) SizedBox(height: theme.spacing.sm),
          Semantics(
            key: ValueKey<String>('filter-table-row-${rows[index].id}'),
            container: true,
            role: SemanticsRole.listItem,
            excludeSemantics: true,
            label:
                '${widget.labels.taskColumn}: ${rows[index].task}. '
                '${widget.labels.dateColumn}: ${rows[index].date}. '
                '${widget.labels.statusColumn}: '
                '${widget.labels._status(rows[index].status)}. '
                '${widget.labels.ownerColumn}: ${rows[index].owner}',
            child: _surface(
              theme,
              Padding(
                padding: EdgeInsets.all(theme.spacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      rows[index].task,
                      style: theme.typography.label.copyWith(
                        color: theme.colors.ink,
                      ),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    _statusPill(theme, rows[index].status),
                    SizedBox(height: theme.spacing.sm),
                    Text(
                      '${widget.labels.dateColumn}: ${rows[index].date}',
                      style: theme.typography.body.copyWith(
                        color: theme.colors.inkMuted,
                      ),
                    ),
                    Text(
                      '${widget.labels.ownerColumn}: ${rows[index].owner}',
                      style: theme.typography.body.copyWith(
                        color: theme.colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _table(
    BeautifulUiThemeData theme,
    List<BeautifulFilterTableRow> rows,
  ) => Semantics(
    key: const ValueKey<String>('filter-table-expanded'),
    container: true,
    explicitChildNodes: true,
    role: SemanticsRole.table,
    label: widget.labels.table,
    child: _surface(
      theme,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _tableRow(
            theme,
            header: true,
            children: <Widget>[
              Text(widget.labels.taskColumn),
              Text(widget.labels.dateColumn),
              Text(widget.labels.statusColumn),
              Text(widget.labels.ownerColumn),
            ],
          ),
          for (final row in rows)
            _tableRow(
              theme,
              key: ValueKey<String>('filter-table-row-${row.id}'),
              children: <Widget>[
                Text(row.task),
                Text(row.date),
                _statusPill(theme, row.status),
                Text(row.owner),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _tableRow(
    BeautifulUiThemeData theme, {
    Key? key,
    bool header = false,
    required List<Widget> children,
  }) => Semantics(
    key: key,
    container: true,
    explicitChildNodes: true,
    role: SemanticsRole.row,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colors.line)),
      ),
      child: DefaultTextStyle(
        style: (header ? theme.typography.label : theme.typography.body)
            .copyWith(color: header ? theme.colors.inkMuted : theme.colors.ink),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var index = 0; index < children.length; index++)
              Expanded(
                flex: const <int>[13, 6, 10, 10][index],
                child: Semantics(
                  container: true,
                  role: header
                      ? SemanticsRole.columnHeader
                      : SemanticsRole.cell,
                  child: Padding(
                    padding: EdgeInsets.all(theme.spacing.md),
                    child: children[index],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _statusPill(
    BeautifulUiThemeData theme,
    BeautifulFilterTableStatus status,
  ) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: theme.spacing.sm,
      vertical: theme.spacing.xs,
    ),
    decoration: BoxDecoration(
      color: switch (status) {
        BeautifulFilterTableStatus.todo => theme.colors.warningTint,
        BeautifulFilterTableStatus.inProgress => theme.colors.accentTint,
        BeautifulFilterTableStatus.completed => theme.colors.successTint,
      },
      border: Border.all(color: theme.colors.lineStrong),
      borderRadius: BorderRadius.circular(theme.radii.chip),
    ),
    child: Text(
      widget.labels._status(status),
      style: theme.typography.label.copyWith(color: theme.colors.ink),
    ),
  );

  Widget _dot(BeautifulUiThemeData theme, BeautifulFilterTableStatus status) =>
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: switch (status) {
            BeautifulFilterTableStatus.todo => theme.colors.warning,
            BeautifulFilterTableStatus.inProgress => theme.colors.accent,
            BeautifulFilterTableStatus.completed => theme.colors.success,
          },
        ),
      );
}

final class _FilterCheckPainter extends CustomPainter {
  const _FilterCheckPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .15, size.height * .5)
      ..lineTo(size.width * .4, size.height * .75)
      ..lineTo(size.width * .85, size.height * .25);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_FilterCheckPainter oldDelegate) =>
      oldDelegate.color != color;
}
