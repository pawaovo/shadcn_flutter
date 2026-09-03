import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/rendering.dart' show ScrollCacheExtent, ViewportOffset;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/failure.dart';
import '../foundation/layout.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';
import '../implementation/controls/text_selection.dart';

/// The supported output types of a record property.
enum BeautifulRecordPropertyType {
  /// Plain text.
  text,

  /// A file reference.
  file,

  /// A collection of values.
  collection,

  /// A single choice.
  singleSelect,

  /// Multiple choices.
  multiSelect,

  /// A URL.
  url,

  /// A reference to another object.
  reference,

  /// Structured JSON displayed as caller-formatted text.
  json,

  /// Output from splitting a file.
  fileSplitter,

  /// A date.
  date,
}

/// The execution state of one caller-owned cell.
enum BeautifulRecordCellStatus {
  /// A value is ready, including an empty value.
  ready,

  /// The host is calculating this value.
  running,

  /// The host reports a failed calculation.
  failed,
}

/// A host-provided model or tool option. No tool is shipped in the package.
@immutable
final class BeautifulRecordTool {
  /// Creates an option with stable identity and localized text.
  const BeautifulRecordTool({required this.id, required this.label});

  /// Stable, non-empty tool identity.
  final String id;

  /// Localized visible name, such as the host's model or web-search tool.
  final String label;
}

/// Immutable accepted settings, or a complete proposed property configuration.
@immutable
final class BeautifulRecordPropertyConfig {
  /// Creates settings and defensively copies input column identities.
  BeautifulRecordPropertyConfig({
    this.type = BeautifulRecordPropertyType.text,
    this.toolId,
    Iterable<String> inputColumnIds = const <String>[],
    this.prompt = '',
    this.grounding = false,
    this.requiredValue = false,
    this.allowEmpty = true,
    this.showConfidence = false,
  }) : inputColumnIds = List<String>.unmodifiable(inputColumnIds) {
    if (this.inputColumnIds.toSet().length != this.inputColumnIds.length ||
        this.inputColumnIds.any((id) => id.isEmpty)) {
      throw ArgumentError('Input column IDs must be unique and non-empty.');
    }
  }

  /// Requested output type; the host interprets its business meaning.
  final BeautifulRecordPropertyType type;

  /// Selected host tool identity, or null for manual input.
  final String? toolId;

  /// Input properties in their chosen order, excluding the output itself.
  final List<String> inputColumnIds;

  /// Exact user-authored calculation instructions, including any mentions.
  final String prompt;

  /// Whether the host should ground generation in connected sources.
  final bool grounding;

  /// Whether the host requires a value.
  final bool requiredValue;

  /// Whether empty results are allowed by the host.
  final bool allowEmpty;

  /// Whether the host should provide confidence information.
  final bool showConfidence;

  /// Returns a complete proposed snapshot, preserving unspecified settings.
  BeautifulRecordPropertyConfig copyWith({
    BeautifulRecordPropertyType? type,
    String? toolId,
    bool clearTool = false,
    Iterable<String>? inputColumnIds,
    String? prompt,
    bool? grounding,
    bool? requiredValue,
    bool? allowEmpty,
    bool? showConfidence,
  }) => BeautifulRecordPropertyConfig(
    type: type ?? this.type,
    toolId: clearTool ? null : toolId ?? this.toolId,
    inputColumnIds: inputColumnIds ?? this.inputColumnIds,
    prompt: prompt ?? this.prompt,
    grounding: grounding ?? this.grounding,
    requiredValue: requiredValue ?? this.requiredValue,
    allowEmpty: allowEmpty ?? this.allowEmpty,
    showConfidence: showConfidence ?? this.showConfidence,
  );

  @override
  bool operator ==(Object other) =>
      other is BeautifulRecordPropertyConfig &&
      type == other.type &&
      toolId == other.toolId &&
      listEquals(inputColumnIds, other.inputColumnIds) &&
      prompt == other.prompt &&
      grounding == other.grounding &&
      requiredValue == other.requiredValue &&
      allowEmpty == other.allowEmpty &&
      showConfidence == other.showConfidence;

  @override
  int get hashCode => Object.hash(
    type,
    toolId,
    Object.hashAll(inputColumnIds),
    prompt,
    grounding,
    requiredValue,
    allowEmpty,
    showConfidence,
  );
}

/// A property column and its accepted host configuration.
@immutable
final class BeautifulRecordColumn {
  /// Creates a column. Width is an initial presentation value, in logical px.
  BeautifulRecordColumn({
    required this.id,
    required this.label,
    BeautifulRecordPropertyConfig? property,
    this.width = 220,
    this.sortable = true,
    this.hideable = false,
    this.summary,
  }) : property = property ?? BeautifulRecordPropertyConfig() {
    if (id.isEmpty || label.isEmpty || !width.isFinite || width < 144) {
      throw ArgumentError('Use non-empty column IDs/labels and width >= 144.');
    }
  }

  /// Stable, unique property identity.
  final String id;

  /// Full localized property name.
  final String label;

  /// Current settings accepted by the host.
  final BeautifulRecordPropertyConfig property;

  /// Initial width; local resizing and view changes do not modify this value.
  final double width;

  /// Whether local sorting is available.
  final bool sortable;

  /// Whether this column may be hidden locally, then restored in Properties.
  final bool hideable;

  /// Optional caller-calculated, localized footer such as `14 links`.
  final String? summary;
}

/// Exact caller-owned cell content and optional typed ordering values.
///
/// Numeric values sort numerically, dates chronologically, and all other
/// values by lowercase display text. When types differ, number precedes date,
/// which precedes text. Empty/missing values sort last in either direction.
@immutable
final class BeautifulRecordCell {
  /// Creates a cell, defensively copying tags. No values are generated locally.
  BeautifulRecordCell({
    required this.text,
    Iterable<String> tags = const <String>[],
    this.number,
    this.date,
    this.uri,
    this.status = BeautifulRecordCellStatus.ready,
    this.error,
  }) : tags = List<String>.unmodifiable(tags) {
    if (number != null && !number!.isFinite) {
      throw ArgumentError.value(number, 'number', 'Must be finite.');
    }
    if (number != null && date != null) {
      throw ArgumentError('A cell may have a number or a date sort value.');
    }
  }

  /// Full visible and assistive text, already localized by the caller.
  final String text;

  /// Optional category chips; detail always exposes the entire list.
  final List<String> tags;

  /// Optional numeric sort key, independent of localized display text.
  final num? number;

  /// Optional chronological sort key, independent of display text.
  final DateTime? date;

  /// Optional link target, passed to the host action without opening a URL.
  final Uri? uri;

  /// Authoritative calculation lifecycle for this cell.
  final BeautifulRecordCellStatus status;

  /// Localized failure detail supplied by the host.
  final String? error;
}

/// An immutable record with stable identity and property-keyed values.
@immutable
final class BeautifulRecordRow {
  /// Creates a row and defensively copies its cell map.
  BeautifulRecordRow({
    required this.id,
    required this.label,
    required Map<String, BeautifulRecordCell> cells,
  }) : cells = Map<String, BeautifulRecordCell>.unmodifiable(cells) {
    if (id.isEmpty || label.isEmpty) {
      throw ArgumentError('Record IDs and labels must be non-empty.');
    }
  }

  /// Stable, unique record identity; selection survives sorting and refresh.
  final String id;

  /// Full human-readable record name.
  final String label;

  /// Exact values keyed by [BeautifulRecordColumn.id]. Missing means empty.
  final Map<String, BeautifulRecordCell> cells;
}

/// A local sort request. Null on the widget preserves caller row order.
@immutable
final class BeautifulRecordSort {
  /// Creates a sort for a configured column.
  const BeautifulRecordSort({required this.columnId, this.descending = false});

  /// Property to order by.
  final String columnId;

  /// Whether non-empty ordering values are descending.
  final bool descending;
}

/// A complete new-property proposal; the host assigns the accepted stable ID.
@immutable
final class BeautifulRecordPropertyDraft {
  /// Creates the proposal submitted by the Add property editor.
  const BeautifulRecordPropertyDraft({
    required this.label,
    required this.property,
  });

  /// User-entered property name.
  final String label;

  /// Proposed configuration.
  final BeautifulRecordPropertyConfig property;
}

/// A calculation request. Only the host executes it and supplies cell results.
@immutable
final class BeautifulRecordRunRequest {
  /// Creates a request and defensively copies the exact visible row IDs.
  BeautifulRecordRunRequest({
    required this.columnId,
    required this.property,
    required Iterable<String> rowIds,
  }) : rowIds = List<String>.unmodifiable(rowIds);

  /// Property being calculated.
  final String columnId;

  /// Exact configuration draft used for this request.
  final BeautifulRecordPropertyConfig property;

  /// Filtered rows in their current sort order; selection does not limit runs.
  final List<String> rowIds;
}

/// Localized text for the records surface, configuration, and feedback.
@immutable
final class BeautifulRecordsTableLabels {
  /// Creates copy; all package-owned type names are independently replaceable.
  const BeautifulRecordsTableLabels({
    this.table = 'Records',
    this.record = 'Record',
    this.search = 'Search records',
    this.results = 'Matching records',
    this.selected = 'Selected',
    this.select = 'Select',
    this.selectAll = 'Select matching records',
    this.clearSelection = 'Clear selection',
    this.empty = 'No matching records',
    this.details = 'Details',
    this.close = 'Close',
    this.properties = 'Properties',
    this.addProperty = 'Add property',
    this.propertyName = 'Property name',
    this.configure = 'Configure',
    this.type = 'Type',
    this.tool = 'Tool',
    this.manual = 'User input',
    this.inputs = 'Inputs',
    this.prompt = 'Calculation prompt',
    this.grounding = 'Grounding',
    this.groundingHelp = 'Verify generated values against connected sources.',
    this.moreSettings = 'More settings',
    this.requiredValue = 'Required value',
    this.allowEmpty = 'Allow empty results',
    this.showConfidence = 'Show confidence',
    this.save = 'Save property',
    this.run = 'Go calculate',
    this.running = 'Calculating',
    this.failed = 'Calculation failed',
    this.pending = 'Working',
    this.actionFailed = 'Action failed. Try again.',
    this.saved = 'Request completed',
    this.invalidName = 'Enter a property name',
    this.noValue = 'No value',
    this.sort = 'Sort',
    this.ascending = 'Ascending',
    this.descending = 'Descending',
    this.pin = 'Pin first',
    this.unpin = 'Unpin',
    this.hide = 'Hide from view',
    this.show = 'Show',
    this.compactColumns = 'Compact columns',
    this.resetWidths = 'Reset column widths',
    this.resize = 'Resize column',
    this.increaseWidth = 'Widen',
    this.decreaseWidth = 'Narrow',
    this.typeLabels = const <BeautifulRecordPropertyType, String>{
      BeautifulRecordPropertyType.text: 'Text',
      BeautifulRecordPropertyType.file: 'File',
      BeautifulRecordPropertyType.collection: 'Collection',
      BeautifulRecordPropertyType.singleSelect: 'Single select',
      BeautifulRecordPropertyType.multiSelect: 'Multi select',
      BeautifulRecordPropertyType.url: 'URL',
      BeautifulRecordPropertyType.reference: 'Reference',
      BeautifulRecordPropertyType.json: 'JSON',
      BeautifulRecordPropertyType.fileSplitter: 'File splitter',
      BeautifulRecordPropertyType.date: 'Date',
    },
  });

  /// Table/list assistive name.
  final String table;

  /// Identity-column heading.
  final String record;

  /// Search input label.
  final String search;

  /// Matching-count prefix.
  final String results;

  /// Selected-count prefix.
  final String selected;

  /// Single record selection prefix.
  final String select;

  /// Select-all matching rows label.
  final String selectAll;

  /// Clear-selection action.
  final String clearSelection;

  /// Empty search result.
  final String empty;

  /// Record-detail action prefix.
  final String details;

  /// Disclosure dismissal action.
  final String close;

  /// Property-list disclosure.
  final String properties;

  /// New property action.
  final String addProperty;

  /// New property name input.
  final String propertyName;

  /// Existing property editor prefix.
  final String configure;

  /// Property type heading.
  final String type;

  /// Host tool heading.
  final String tool;

  /// Manual-input choice.
  final String manual;

  /// Input property choices heading.
  final String inputs;

  /// Prompt input label.
  final String prompt;

  /// Grounding switch.
  final String grounding;

  /// Grounding explanation.
  final String groundingHelp;

  /// Advanced-settings disclosure.
  final String moreSettings;

  /// Required-value switch.
  final String requiredValue;

  /// Empty-result switch.
  final String allowEmpty;

  /// Confidence switch.
  final String showConfidence;

  /// Save configuration action.
  final String save;

  /// Calculate visible rows action.
  final String run;

  /// Host-calculating cell text.
  final String running;

  /// Host-failed cell text.
  final String failed;

  /// Pending external-action text.
  final String pending;

  /// Recoverable action error; exception details are reported separately.
  final String actionFailed;

  /// Completed request text; does not claim data/configuration was accepted.
  final String saved;

  /// Name validation message.
  final String invalidName;

  /// Missing-cell text.
  final String noValue;

  /// Sort action prefix.
  final String sort;

  /// Ascending sort name.
  final String ascending;

  /// Descending sort name.
  final String descending;

  /// Pin to leading column order action.
  final String pin;

  /// Undo leading column order action.
  final String unpin;

  /// Hide a hideable column.
  final String hide;

  /// Restore a hidden column.
  final String show;

  /// Compact all column widths action.
  final String compactColumns;

  /// Restore initial column widths action.
  final String resetWidths;

  /// Pointer/keyboard resizing assistive prefix.
  final String resize;

  /// Accessible width-increase action prefix.
  final String increaseWidth;

  /// Accessible width-decrease action prefix.
  final String decreaseWidth;

  /// Complete localized names for the supported property types.
  final Map<BeautifulRecordPropertyType, String> typeLabels;
}

/// A lazy records grid with selectable rows and host-executed AI properties.
///
/// Business rows, accepted property configurations, tools, and execution remain
/// host-owned. Save/Add/Calculate submit complete proposals and never fabricate
/// accepted columns, results, or progress. Cell actions expose the exact row,
/// column and cell (including URI), leaving navigation to the host.
///
/// Selection, query, sort, widths, hidden/pinned columns and disclosure are
/// local view state. The three `initial` values seed state once per [id]; their
/// callbacks are observational, not controlled values. Selection persists when
/// filtering, select-all toggles matching rows only, and removed IDs are pruned.
/// Runs target all matching rows in sort order, independently of selection.
/// Query and sort changes restart the row viewport at its beginning.
/// Pinning moves properties to leading display order; it does not freeze them.
///
/// Expanded layouts use a horizontally scrollable grid with a fixed header and
/// lazy rows. Compact/medium widths or text above 150% use cards with full row
/// detail. The same vertical controller survives changes in presentation.
/// [height] bounds the lazy viewport; the host supplies scrolling for the
/// surrounding toolbar and inline property/detail disclosures. Sorting/filtering
/// is cached on snapshot/query/sort changes, not row realization. The tested
/// workload is 1,000 records; row widgets are built only near the viewport.
///
/// Drafts survive resize. An accepted property change/removal or new table [id]
/// invalidates obsolete async completions and clipboard work. Changed records
/// invalidate only actions that used those record snapshots. Calculation
/// guards compare row identity and configured input values/schema; ordinary
/// output progress does not unlock a still-pending host calculation. Removed input
/// columns are pruned from proposals without discarding other draft settings.
/// Recreated equal
/// configurations and callback closures do not invalidate pending work.
final class BeautifulRecordsTable extends StatefulWidget {
  /// Creates a records surface using stable row, column and table identities.
  const BeautifulRecordsTable({
    super.key,
    required this.id,
    required this.columns,
    required this.rows,
    this.tools = const <BeautifulRecordTool>[],
    this.initialSelectedIds = const <String>{},
    this.initialSort,
    this.initialQuery = '',
    this.onSelectionChanged,
    this.onSortChanged,
    this.onQueryChanged,
    this.onPropertyChanged,
    this.onPropertyAdded,
    this.onRun,
    this.onCellActivated,
    this.height = 480,
    this.labels = const BeautifulRecordsTableLabels(),
  }) : assert(id != ''),
       assert(height >= 160 && height < double.infinity);

  /// Domain identity; changing it resets all local view state.
  final String id;

  /// Accepted properties, with stable unique IDs.
  final List<BeautifulRecordColumn> columns;

  /// Immutable caller data, copied defensively on widget updates.
  final List<BeautifulRecordRow> rows;

  /// Available host tools/models with stable unique IDs.
  final List<BeautifulRecordTool> tools;

  /// Initially selected row IDs, read once per [id].
  final Set<String> initialSelectedIds;

  /// Initial local ordering; null preserves caller order.
  final BeautifulRecordSort? initialSort;

  /// Initial local case-insensitive substring query.
  final String initialQuery;

  /// Receives an immutable selection snapshot after each user change.
  final ValueChanged<Set<String>>? onSelectionChanged;

  /// Receives the user's next local sort order.
  final ValueChanged<BeautifulRecordSort>? onSortChanged;

  /// Receives query edits. Filtering is local across names and all cell text.
  final ValueChanged<String>? onQueryChanged;

  /// Submits a property ID and complete proposed settings to the host.
  final FutureOr<void> Function(String, BeautifulRecordPropertyConfig)?
  onPropertyChanged;

  /// Submits a new-property proposal; host acceptance supplies a new column.
  final FutureOr<void> Function(BeautifulRecordPropertyDraft)? onPropertyAdded;

  /// Executes a proposed calculation; only host snapshots change cell values.
  final FutureOr<void> Function(BeautifulRecordRunRequest)? onRun;

  /// Handles an actionable cell, such as opening its [BeautifulRecordCell.uri].
  final FutureOr<void> Function(
    BeautifulRecordRow,
    BeautifulRecordColumn,
    BeautifulRecordCell,
  )?
  onCellActivated;

  /// Finite height of the scrollable row viewport and fixed grid header.
  final double height;

  /// All package-owned visible and assistive text.
  final BeautifulRecordsTableLabels labels;

  @override
  State<BeautifulRecordsTable> createState() => _BeautifulRecordsTableState();
}

final class _BeautifulRecordsTableState extends State<BeautifulRecordsTable> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final _searchController = TextEditingController();
  final _promptController = TextEditingController();
  final _nameController = TextEditingController();
  final _panelFocus = FocusNode();
  final _searchFocus = FocusNode();
  FocusNode? _returnFocus;
  late List<BeautifulRecordRow> _rows;
  late List<BeautifulRecordColumn> _columns;
  late List<BeautifulRecordTool> _tools;
  List<BeautifulRecordRow> _visible = <BeautifulRecordRow>[];
  final _selected = <String>{};
  final _hidden = <String>{};
  final _pinned = <String>{};
  final _widths = <String, double>{};
  final _rowIdentityKeys = <String, GlobalKey>{};
  final _cellActionKeys = <(String, String, bool), GlobalKey>{};
  BeautifulRecordSort? _sort;
  String? _detailId;
  String? _editingId;
  BeautifulRecordPropertyConfig? _draft;
  var _adding = false;
  var _propertiesOpen = false;
  var _moreOpen = false;
  var _generation = 0;
  String? _pending;
  final _inFlight = <String, _RecordsPendingAction>{};
  String? _feedback;
  var _expanded = false;
  var _wideOffset = 0.0;
  var _editorRevision = 0;

  @override
  void initState() {
    super.initState();
    _horizontal.addListener(() {
      if (_expanded && _horizontal.hasClients) _wideOffset = _horizontal.offset;
    });
    _reset();
  }

  @override
  void didUpdateWidget(BeautifulRecordsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_vertical.hasClients) _vertical.jumpTo(0);
        if (_horizontal.hasClients) _horizontal.jumpTo(0);
      });
      return;
    }
    final previous = _column(_editingId);
    _snapshot();
    final accepted = _column(_editingId);
    if (_editingId != null &&
        (accepted == null || previous?.property != accepted.property)) {
      _generation++;
      _pending = null;
      _feedback = null;
      if (accepted == null) {
        _closeEditor();
      } else {
        _draft = accepted.property;
        _promptController.text = accepted.property.prompt;
        _editorRevision++;
      }
    }
    if (_draft != null) {
      _draft = _draft!.copyWith(
        inputColumnIds: _draft!.inputColumnIds.where(
          (id) => id != _editingId && _columns.any((column) => column.id == id),
        ),
        clearTool:
            _draft!.toolId != null &&
            !_tools.any((tool) => tool.id == _draft!.toolId),
      );
    }
    _inFlight.removeWhere((key, action) {
      final obsolete = !_requestMatches(action);
      if (obsolete && _pending == key) {
        _pending = null;
        _feedback = null;
      }
      return obsolete;
    });
    _recompute();
  }

  void _snapshot() {
    _rows = List<BeautifulRecordRow>.unmodifiable(widget.rows);
    _columns = List<BeautifulRecordColumn>.unmodifiable(widget.columns);
    _tools = List<BeautifulRecordTool>.unmodifiable(widget.tools);
    void unique(Iterable<String> ids, String subject) {
      final values = ids.toList();
      if (values.any((value) => value.isEmpty) ||
          values.toSet().length != values.length) {
        throw ArgumentError(
          'Records Table requires unique, non-empty $subject IDs.',
        );
      }
    }

    unique(_rows.map((row) => row.id), 'row');
    unique(_columns.map((column) => column.id), 'column');
    unique(_tools.map((tool) => tool.id), 'tool');
    final columnIds = _columns.map((column) => column.id).toSet();
    for (final column in _columns) {
      if (column.property.inputColumnIds.any((id) => id == column.id)) {
        throw ArgumentError('A property cannot use itself as an input.');
      }
      _widths.putIfAbsent(column.id, () => column.width);
    }
    final rowIds = _rows.map((row) => row.id).toSet();
    _selected.retainAll(rowIds);
    _rowIdentityKeys.removeWhere((id, _) => !rowIds.contains(id));
    _cellActionKeys.removeWhere(
      (key, _) => !rowIds.contains(key.$1) || !columnIds.contains(key.$2),
    );
    _pinned.retainAll(columnIds);
    _hidden.retainAll(
      _columns.where((column) => column.hideable).map((column) => column.id),
    );
    _widths.removeWhere((id, _) => !columnIds.contains(id));
    if (_sort != null &&
        !_columns.any(
          (column) => column.id == _sort!.columnId && column.sortable,
        )) {
      _sort = null;
    }
  }

  void _reset() {
    _generation++;
    _pending = null;
    _inFlight.clear();
    _feedback = null;
    _detailId = null;
    _editingId = null;
    _adding = false;
    _propertiesOpen = false;
    _moreOpen = false;
    _draft = null;
    _selected
      ..clear()
      ..addAll(widget.initialSelectedIds);
    _hidden.clear();
    _pinned.clear();
    _widths.clear();
    _rowIdentityKeys.clear();
    _cellActionKeys.clear();
    _sort = widget.initialSort;
    _searchController.text = widget.initialQuery;
    _wideOffset = 0;
    _editorRevision++;
    _snapshot();
    _recompute();
  }

  BeautifulRecordColumn? _column(String? id) {
    for (final column in _columns) {
      if (column.id == id) return column;
    }
    return null;
  }

  void _recompute() {
    final query = _searchController.text.trim().toLowerCase();
    _visible = _rows
        .where(
          (row) =>
              query.isEmpty ||
              row.label.toLowerCase().contains(query) ||
              row.cells.values.any(
                (cell) =>
                    cell.text.toLowerCase().contains(query) ||
                    cell.tags.any((tag) => tag.toLowerCase().contains(query)),
              ),
        )
        .toList();
    if (_sort case final sort?) {
      final originalIndex = <String, int>{
        for (var i = 0; i < _rows.length; i++) _rows[i].id: i,
      };
      _visible.sort((a, b) {
        final left = a.cells[sort.columnId];
        final right = b.cells[sort.columnId];
        bool empty(BeautifulRecordCell? cell) =>
            cell == null ||
            (cell.text.isEmpty &&
                cell.tags.isEmpty &&
                cell.number == null &&
                cell.date == null);
        if (empty(left) != empty(right)) return empty(left) ? 1 : -1;
        var order = 0;
        if (left != null && right != null) {
          int kind(BeautifulRecordCell cell) => cell.number != null
              ? 0
              : cell.date != null
              ? 1
              : 2;
          order = kind(left).compareTo(kind(right));
          if (order == 0) {
            order = switch (kind(left)) {
              0 => left.number!.compareTo(right.number!),
              1 => left.date!.compareTo(right.date!),
              _ => left.text.toLowerCase().compareTo(right.text.toLowerCase()),
            };
          }
        }
        if (order != 0) return sort.descending ? -order : order;
        return originalIndex[a.id]!.compareTo(originalIndex[b.id]!);
      });
    }
    if (!_visible.any((row) => row.id == _detailId)) _detailId = null;
  }

  void _select(String id) {
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
    widget.onSelectionChanged?.call(Set<String>.unmodifiable(_selected));
  }

  void _selectAll() {
    final all =
        _visible.isNotEmpty &&
        _visible.every((row) => _selected.contains(row.id));
    setState(() {
      for (final row in _visible) {
        all ? _selected.remove(row.id) : _selected.add(row.id);
      }
    });
    widget.onSelectionChanged?.call(Set<String>.unmodifiable(_selected));
  }

  void _setSort(BeautifulRecordColumn column) {
    final next = BeautifulRecordSort(
      columnId: column.id,
      descending: _sort?.columnId == column.id && !_sort!.descending,
    );
    setState(() {
      _sort = next;
      _recompute();
    });
    if (_vertical.hasClients) _vertical.jumpTo(0);
    widget.onSortChanged?.call(next);
  }

  void _openEditor(BeautifulRecordColumn? column) {
    _returnFocus = FocusManager.instance.primaryFocus;
    setState(() {
      _generation++;
      _pending = null;
      _feedback = null;
      _editingId = column?.id;
      _adding = column == null;
      _draft = column?.property ?? BeautifulRecordPropertyConfig();
      _promptController.text = _draft!.prompt;
      _nameController.text = column?.label ?? '';
      for (final entry in _inFlight.entries) {
        if (entry.value.columnId == column?.id) {
          _pending = entry.key;
          break;
        }
      }
      _moreOpen = false;
      _editorRevision++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _draft == null) return;
      _panelFocus.requestFocus();
      final panelContext = _panelFocus.context;
      if (panelContext != null) Scrollable.ensureVisible(panelContext);
    });
  }

  void _closeEditor() {
    _generation++;
    _pending = null;
    _editingId = null;
    _adding = false;
    _draft = null;
    _feedback = null;
    _editorRevision++;
    if (_returnFocus?.context != null && _returnFocus!.canRequestFocus) {
      _returnFocus!.requestFocus();
    }
  }

  bool _requestMatches(_RecordsPendingAction action) {
    if (action.tableId != widget.id) return false;
    if (action.columnId != null &&
        _column(action.columnId)?.property != action.acceptedProperty) {
      return false;
    }
    final currentRows = <String, BeautifulRecordRow>{
      for (final row in _rows) row.id: row,
    };
    if (action.inputColumns case final inputColumns?) {
      if (inputColumns.any(
        (column) => _column(column.id)?.property != column.property,
      )) {
        return false;
      }
      return action.rows.every((before) {
        final after = currentRows[before.id];
        return after != null &&
            before.label == after.label &&
            inputColumns.every(
              (column) => _sameRecordCell(
                before.cells[column.id],
                after.cells[column.id],
              ),
            );
      });
    }
    return action.rows.every(
      (before) => _sameRecord(before, currentRows[before.id]),
    );
  }

  Future<void> _action(
    String operation,
    FutureOr<void> Function() callback, {
    List<BeautifulRecordRow> rows = const <BeautifulRecordRow>[],
    String? columnId,
    List<String>? inputColumnIds,
  }) async {
    final targetColumn = columnId ?? _editingId;
    final key = '$operation:${targetColumn ?? 'new'}';
    if (_inFlight.containsKey(key) || _pending != null) return;
    final generation = _generation;
    final action = _RecordsPendingAction(
      widget.id,
      targetColumn,
      _column(targetColumn)?.property,
      rows,
      inputColumnIds == null
          ? null
          : _columns
                .where((column) => inputColumnIds.contains(column.id))
                .toList(growable: false),
    );
    final environment = BeautifulUiEnvironment.of(context);
    setState(() {
      _inFlight[key] = action;
      _pending = key;
      _feedback = null;
    });
    bool current() =>
        mounted && identical(_inFlight[key], action) && _requestMatches(action);
    try {
      await callback();
      if (!current()) return;
      if (generation == _generation || _pending == key) {
        setState(() {
          _pending = null;
          _feedback = widget.labels.saved;
        });
      }
    } catch (error, stackTrace) {
      if (!current()) return;
      if (generation == _generation || _pending == key) {
        setState(() {
          _pending = null;
          _feedback = widget.labels.actionFailed;
        });
        environment.reportFailure(
          BeautifulUiFailure(
            operation: BeautifulUiOperation.records,
            message: 'Records Table $operation failed.',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }
    } finally {
      if (mounted && identical(_inFlight[key], action)) {
        setState(() {
          _inFlight.remove(key);
          if (_pending == key) _pending = null;
        });
      }
    }
  }

  BeautifulRecordPropertyConfig _proposal() => _draft!.copyWith(
    prompt: _promptController.text,
    inputColumnIds: _draft!.inputColumnIds.where(
      (id) => id != _editingId && _columns.any((column) => column.id == id),
    ),
  );

  void _save() {
    if (_draft == null) return;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _feedback = widget.labels.invalidName);
      return;
    }
    if (_adding) {
      final draft = BeautifulRecordPropertyDraft(
        label: _nameController.text.trim(),
        property: _proposal(),
      );
      if (widget.onPropertyAdded case final callback?) {
        unawaited(_action('add', () => callback(draft)));
      }
    } else if (_editingId case final id?) {
      final proposal = _proposal();
      if (widget.onPropertyChanged case final callback?) {
        unawaited(_action('save', () => callback(id, proposal)));
      }
    }
  }

  void _run() {
    if (_editingId == null || _draft == null || widget.onRun == null) return;
    final request = BeautifulRecordRunRequest(
      columnId: _editingId!,
      property: _proposal(),
      rowIds: _visible.map((row) => row.id),
    );
    unawaited(
      _action(
        'run',
        () => widget.onRun!(request),
        rows: List<BeautifulRecordRow>.of(_visible),
        inputColumnIds: request.property.inputColumnIds,
      ),
    );
  }

  @override
  void dispose() {
    _generation++;
    _vertical.dispose();
    _horizontal.dispose();
    _searchController.dispose();
    _promptController.dispose();
    _nameController.dispose();
    _panelFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final expanded =
            BeautifulUiEnvironment.of(context).modeFor(context, constraints) ==
                BeautifulLayoutMode.expanded &&
            MediaQuery.textScalerOf(context).scale(14) <= 21;
        if (expanded != _expanded) {
          _expanded = expanded;
          if (expanded) {
            final offset = _wideOffset;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _expanded && _horizontal.hasClients) {
                _horizontal.jumpTo(
                  offset.clamp(0, _horizontal.position.maxScrollExtent),
                );
              }
            });
          }
        }
        return SizedBox(
          width: width,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape &&
                  _draft != null) {
                setState(_closeEditor);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _RecordsTextEntry(
                  key: ValueKey<Object>((widget.id, 'search')),
                  identity: (widget.id, 'search'),
                  label: widget.labels.search,
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: (value) {
                    setState(_recompute);
                    widget.onQueryChanged?.call(value);
                  },
                ),
                SizedBox(height: theme.spacing.sm),
                _toolbar(theme, width),
                SizedBox(height: theme.spacing.sm),
                Semantics(
                  container: true,
                  liveRegion: true,
                  label:
                      '${widget.labels.results}: ${_visible.length} / ${_rows.length}. ${widget.labels.selected}: ${_selected.length}',
                  excludeSemantics: true,
                  child: Text(
                    '${widget.labels.results}: ${_visible.length} / ${_rows.length}  ·  ${widget.labels.selected}: ${_selected.length}',
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.inkMuted,
                    ),
                  ),
                ),
                if (_propertiesOpen) ...<Widget>[
                  SizedBox(height: theme.spacing.sm),
                  _properties(theme, width),
                ],
                SizedBox(height: theme.spacing.sm),
                _viewport(theme, width, expanded),
                if (_detailId != null) ...<Widget>[
                  SizedBox(height: theme.spacing.sm),
                  _detail(theme),
                ],
                if (_draft != null) ...<Widget>[
                  SizedBox(height: theme.spacing.md),
                  _editor(theme, width),
                ],
                if (_feedback != null && _draft == null) _status(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _button(
    String label,
    VoidCallback? onPressed, {
    String? key,
    String? semanticLabel,
    bool? selected,
    bool? expanded,
    bool fullWidth = false,
    int? maxLines,
  }) => BeautifulActionControl(
    key: key == null ? null : ValueKey<String>(key),
    label: label,
    semanticLabel: semanticLabel,
    minHeight: 48,
    maxLines: maxLines,
    fullWidth: fullWidth,
    selected: selected,
    expanded: expanded,
    onPressed: onPressed,
    tone: selected == true
        ? BeautifulActionTone.secondary
        : BeautifulActionTone.quiet,
  );

  Widget _toolbar(BeautifulUiThemeData theme, double width) => Wrap(
    spacing: theme.spacing.xs,
    runSpacing: theme.spacing.xs,
    children: <Widget>[
      _bounded(
        width,
        _RecordsCheck(
          label: widget.labels.selectAll,
          checked:
              _visible.isNotEmpty &&
              _visible.every((row) => _selected.contains(row.id)),
          mixed:
              _visible.any((row) => _selected.contains(row.id)) &&
              !_visible.every((row) => _selected.contains(row.id)),
          onChanged: _visible.isEmpty ? null : _selectAll,
        ),
      ),
      _bounded(
        width,
        _button(
          widget.labels.clearSelection,
          _selected.isEmpty
              ? null
              : () {
                  setState(_selected.clear);
                  widget.onSelectionChanged?.call(const <String>{});
                },
          key: 'records-clear-selection',
        ),
      ),
      _bounded(
        width,
        _button(
          widget.labels.properties,
          () => setState(() => _propertiesOpen = !_propertiesOpen),
          key: 'records-properties',
          expanded: _propertiesOpen,
        ),
      ),
      if (widget.onPropertyAdded != null)
        _bounded(
          width,
          _button(
            widget.labels.addProperty,
            () => _openEditor(null),
            key: 'records-add',
          ),
        ),
    ],
  );

  Widget _bounded(double width, Widget child) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width),
    child: child,
  );

  Widget _surface(BeautifulUiThemeData theme, Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      color: theme.colors.surface,
      border: Border.all(color: theme.colors.lineStrong),
      borderRadius: BorderRadius.circular(theme.radii.card),
    ),
    child: child,
  );

  Widget _properties(BeautifulUiThemeData theme, double width) => _surface(
    theme,
    Padding(
      padding: EdgeInsets.all(theme.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final column in _columns)
            Wrap(
              spacing: theme.spacing.xs,
              children: <Widget>[
                _bounded(
                  width - theme.spacing.sm * 2,
                  _button(
                    '${widget.labels.configure}: ${column.label}',
                    () => _openEditor(column),
                    key: 'records-config-${column.id}',
                  ),
                ),
                if (column.sortable)
                  _bounded(width - theme.spacing.sm * 2, _sortButton(column)),
                if (_hidden.contains(column.id))
                  _bounded(
                    width - theme.spacing.sm * 2,
                    _button(
                      '${widget.labels.show}: ${column.label}',
                      () => setState(() => _hidden.remove(column.id)),
                      key: 'records-show-${column.id}',
                    ),
                  ),
              ],
            ),
          Wrap(
            spacing: theme.spacing.xs,
            children: <Widget>[
              _bounded(
                width - theme.spacing.sm * 2,
                _button(
                  widget.labels.compactColumns,
                  () => setState(() {
                    for (final column in _columns) {
                      _widths[column.id] = 160;
                    }
                  }),
                  key: 'records-compact-columns',
                ),
              ),
              _bounded(
                width - theme.spacing.sm * 2,
                _button(
                  widget.labels.resetWidths,
                  () => setState(() {
                    for (final column in _columns) {
                      _widths[column.id] = column.width;
                    }
                  }),
                  key: 'records-reset-widths',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  List<BeautifulRecordColumn> get _displayColumns => <BeautifulRecordColumn>[
    ..._columns.where(
      (column) => _pinned.contains(column.id) && !_hidden.contains(column.id),
    ),
    ..._columns.where(
      (column) => !_pinned.contains(column.id) && !_hidden.contains(column.id),
    ),
  ];

  Widget _sortButton(BeautifulRecordColumn column) {
    final selected = _sort?.columnId == column.id;
    final direction = selected && _sort!.descending
        ? widget.labels.descending
        : widget.labels.ascending;
    return _button(
      widget.labels.sort,
      () => _setSort(column),
      key: 'records-sort-${column.id}',
      selected: selected,
      semanticLabel: '${widget.labels.sort}: ${column.label}. $direction',
    );
  }

  Widget _viewport(BeautifulUiThemeData theme, double width, bool expanded) {
    final columns = _displayColumns;
    final gridWidth = expanded
        ? math.max(
            width,
            272 +
                columns.fold<double>(
                  0,
                  (sum, column) => sum + _widths[column.id]!,
                ),
          )
        : width;
    final positions = <String, int>{
      for (var i = 0; i < _visible.length; i++)
        'records-row-${_visible[i].id}': i,
    };
    return KeyedSubtree(
      key: const ValueKey<String>('records-viewport-state'),
      child: _surface(
        theme,
        SizedBox(
          key: const ValueKey<String>('records-viewport'),
          height: widget.height,
          child: RawScrollbar(
            controller: _horizontal,
            thumbVisibility: expanded,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: gridWidth,
                height: widget.height,
                child: RawScrollbar(
                  controller: _vertical,
                  thumbVisibility: true,
                  child: _RecordsScrollView(
                    key: const ValueKey<String>('records-list'),
                    controller: _vertical,
                    table: expanded,
                    label: widget.labels.table,
                    slivers: <Widget>[
                      if (expanded)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _RecordsHeaderDelegate(
                            _header(theme, columns),
                            104,
                          ),
                        ),
                      if (_visible.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(theme.spacing.md),
                            child: expanded
                                ? Semantics(
                                    role: SemanticsRole.row,
                                    child: Semantics(
                                      role: SemanticsRole.cell,
                                      child: Text(
                                        widget.labels.empty,
                                        style: theme.typography.body,
                                      ),
                                    ),
                                  )
                                : Semantics(
                                    role: SemanticsRole.listItem,
                                    child: Text(
                                      widget.labels.empty,
                                      style: theme.typography.body,
                                    ),
                                  ),
                          ),
                        ),
                      SliverList(
                        key: ValueKey<Object>((
                          'records-sliver',
                          _sort?.columnId,
                          _sort?.descending,
                          _searchController.text,
                        )),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final row = _visible[index];
                            return Semantics(
                              key: ValueKey<String>('records-row-${row.id}'),
                              container: false,
                              explicitChildNodes: true,
                              role: expanded
                                  ? SemanticsRole.row
                                  : SemanticsRole.listItem,
                              selected: _selected.contains(row.id),
                              label: row.label,
                              child: expanded
                                  ? _gridRow(theme, row, columns)
                                  : _cardRow(theme, row, columns),
                            );
                          },
                          childCount: _visible.length,
                          findChildIndexCallback: (key) =>
                              key is ValueKey<String>
                              ? positions[key.value]
                              : null,
                        ),
                      ),
                      if (expanded &&
                          columns.any((column) => column.summary != null))
                        SliverToBoxAdapter(child: _footer(theme, columns)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(
    BeautifulUiThemeData theme,
    List<BeautifulRecordColumn> columns,
  ) => Semantics(
    container: true,
    explicitChildNodes: true,
    role: SemanticsRole.row,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.inset,
        border: Border(bottom: BorderSide(color: theme.colors.lineStrong)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 272,
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.md),
              child: Semantics(
                role: SemanticsRole.columnHeader,
                child: Text(
                  widget.labels.record,
                  style: theme.typography.label,
                ),
              ),
            ),
          ),
          for (final column in columns)
            SizedBox(
              width: _widths[column.id],
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                role: SemanticsRole.columnHeader,
                label: column.label,
                child: Column(
                  children: <Widget>[
                    _button(
                      column.label,
                      () => _openEditor(column),
                      key: 'records-header-${column.id}',
                      maxLines: 1,
                      semanticLabel:
                          '${widget.labels.configure}: ${column.label}',
                      fullWidth: true,
                    ),
                    Row(
                      children: <Widget>[
                        if (column.sortable)
                          Expanded(child: _sortButton(column))
                        else
                          const Spacer(),
                        _RecordsResize(
                          label: '${widget.labels.resize}: ${column.label}',
                          value: _widths[column.id]!,
                          onChanged: (value) => setState(
                            () => _widths[column.id] = value.clamp(144, 800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _identity(BeautifulUiThemeData theme, BeautifulRecordRow row) =>
      KeyedSubtree(
        key: _rowIdentityKeys.putIfAbsent(row.id, GlobalKey.new),
        child: Row(
          children: <Widget>[
            _RecordsCheck(
              label: '${widget.labels.select}: ${row.label}',
              checked: _selected.contains(row.id),
              compact: true,
              onChanged: () => _select(row.id),
            ),
            Expanded(
              child: _button(
                row.label,
                () => setState(
                  () => _detailId = _detailId == row.id ? null : row.id,
                ),
                key: 'records-detail-${row.id}',
                semanticLabel: '${widget.labels.details}: ${row.label}',
                expanded: _detailId == row.id,
                fullWidth: true,
              ),
            ),
          ],
        ),
      );

  Widget _gridRow(
    BeautifulUiThemeData theme,
    BeautifulRecordRow row,
    List<BeautifulRecordColumn> columns,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      color: _selected.contains(row.id) ? theme.colors.accentTint : null,
      border: Border(bottom: BorderSide(color: theme.colors.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 272,
          child: Semantics(
            container: true,
            role: SemanticsRole.cell,
            child: _identity(theme, row),
          ),
        ),
        for (final column in columns)
          SizedBox(
            width: _widths[column.id],
            child: _cell(theme, row, column, detail: false),
          ),
      ],
    ),
  );

  Widget _cardRow(
    BeautifulUiThemeData theme,
    BeautifulRecordRow row,
    List<BeautifulRecordColumn> columns,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      color: _selected.contains(row.id) ? theme.colors.accentTint : null,
      border: Border(bottom: BorderSide(color: theme.colors.line)),
    ),
    child: Padding(
      padding: EdgeInsets.all(theme.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _identity(theme, row),
          for (final column in columns.take(2))
            _cell(theme, row, column, detail: false, showLabel: true),
        ],
      ),
    ),
  );

  String _cellText(BeautifulRecordCell? cell) {
    if (cell == null) return widget.labels.noValue;
    if (cell.status == BeautifulRecordCellStatus.running) {
      return widget.labels.running;
    }
    if (cell.status == BeautifulRecordCellStatus.failed) {
      return '${widget.labels.failed}${cell.error == null ? '' : ': ${cell.error}'}';
    }
    final text = cell.tags.isEmpty ? cell.text : cell.tags.join(', ');
    return text.isEmpty ? widget.labels.noValue : text;
  }

  Widget _cell(
    BeautifulUiThemeData theme,
    BeautifulRecordRow row,
    BeautifulRecordColumn column, {
    required bool detail,
    bool showLabel = false,
  }) {
    final cell = row.cells[column.id];
    final text = _cellText(cell);
    final label = '${column.label}: $text';
    final content = cell?.uri != null && widget.onCellActivated != null
        ? _button(
            text,
            _pending == null
                ? () => unawaited(
                    _action(
                      'cell',
                      () => widget.onCellActivated!(row, column, cell!),
                      rows: <BeautifulRecordRow>[row],
                      columnId: column.id,
                    ),
                  )
                : null,
            semanticLabel: label,
            key: 'records-cell-action-${row.id}-${column.id}',
            fullWidth: true,
          )
        : Semantics(
            container: true,
            role: _expanded && !detail
                ? SemanticsRole.cell
                : SemanticsRole.none,
            label: label,
            excludeSemantics: true,
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child:
                  cell != null &&
                      cell.tags.isNotEmpty &&
                      cell.status == BeautifulRecordCellStatus.ready
                  ? _tags(
                      theme,
                      column,
                      cell,
                      detail: detail,
                      showLabel: showLabel,
                    )
                  : Text(
                      showLabel ? label : text,
                      maxLines: detail ? null : 2,
                      overflow: detail
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(
                        color: cell?.status == BeautifulRecordCellStatus.failed
                            ? theme.colors.destructive
                            : theme.colors.ink,
                      ),
                    ),
            ),
          );
    final stableContent = cell?.uri != null && widget.onCellActivated != null
        ? KeyedSubtree(
            key: _cellActionKeys.putIfAbsent((
              row.id,
              column.id,
              detail,
            ), GlobalKey.new),
            child: content,
          )
        : content;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child:
          cell?.uri != null &&
              widget.onCellActivated != null &&
              _expanded &&
              !detail
          ? Semantics(
              container: true,
              role: SemanticsRole.cell,
              child: stableContent,
            )
          : stableContent,
    );
  }

  Widget _tags(
    BeautifulUiThemeData theme,
    BeautifulRecordColumn column,
    BeautifulRecordCell cell, {
    required bool detail,
    required bool showLabel,
  }) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showLabel)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.xs),
            child: Text(
              column.label,
              style: theme.typography.caption.copyWith(
                color: theme.colors.inkMuted,
              ),
            ),
          ),
        Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            for (final tag in detail ? cell.tags : cell.tags.take(2))
              Container(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.sm,
                  vertical: theme.spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: theme.colors.accentTint,
                  border: Border.all(color: theme.colors.lineStrong),
                  borderRadius: BorderRadius.circular(theme.radii.chip),
                ),
                child: Text(
                  tag,
                  maxLines: detail ? null : 2,
                  overflow: detail ? TextOverflow.clip : TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.ink,
                  ),
                ),
              ),
            if (!detail && cell.tags.length > 2)
              Text(
                '+${cell.tags.length - 2}',
                style: theme.typography.caption.copyWith(
                  color: theme.colors.inkMuted,
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _footer(
    BeautifulUiThemeData theme,
    List<BeautifulRecordColumn> columns,
  ) => Semantics(
    container: true,
    explicitChildNodes: true,
    role: SemanticsRole.row,
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 272,
          child: Semantics(
            container: true,
            role: SemanticsRole.cell,
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: Text(
                '${widget.labels.record}: ${_rows.length}',
                style: theme.typography.caption,
              ),
            ),
          ),
        ),
        for (final column in columns)
          SizedBox(
            width: _widths[column.id],
            child: Semantics(
              container: true,
              role: SemanticsRole.cell,
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.sm),
                child: Text(
                  column.summary ?? '',
                  style: theme.typography.caption,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _detail(BeautifulUiThemeData theme) {
    final row = _visible.firstWhere((row) => row.id == _detailId);
    return _surface(
      theme,
      Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                '${widget.labels.details}: ${row.label}',
                style: theme.typography.label,
              ),
            ),
            for (final column in _displayColumns)
              _cell(theme, row, column, detail: true, showLabel: true),
            _button(
              widget.labels.close,
              () => setState(() => _detailId = null),
              key: 'records-close-detail',
            ),
          ],
        ),
      ),
    );
  }

  Widget _status(BeautifulUiThemeData theme) => Semantics(
    container: true,
    liveRegion: true,
    label: _pending == null ? _feedback : widget.labels.pending,
    excludeSemantics: true,
    child: Padding(
      padding: EdgeInsets.all(theme.spacing.sm),
      child: Text(
        _pending == null ? _feedback ?? '' : widget.labels.pending,
        style: theme.typography.body,
      ),
    ),
  );

  Widget _editor(BeautifulUiThemeData theme, double width) {
    final column = _column(_editingId);
    final labels = widget.labels;
    final contentWidth = math.max(0.0, width - theme.spacing.md * 2);
    final editable =
        _pending == null &&
        (_adding
            ? widget.onPropertyAdded != null
            : widget.onPropertyChanged != null || widget.onRun != null);
    Widget choice(
      String label,
      bool selected,
      VoidCallback update, {
      String? key,
    }) => _bounded(
      contentWidth,
      _button(label, editable ? update : null, key: key, selected: selected),
    );
    Widget toggle(
      String label,
      bool value,
      ValueChanged<bool> change,
      String key,
    ) => _RecordsCheck(
      key: ValueKey<String>(key),
      label: label,
      checked: value,
      onChanged: editable ? () => setState(() => change(!value)) : null,
    );
    return _surface(
      theme,
      Focus(
        focusNode: _panelFocus,
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  _adding
                      ? labels.addProperty
                      : '${labels.configure}: ${column?.label ?? ''}',
                  style: theme.typography.label,
                ),
              ),
              if (_adding) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                _RecordsTextEntry(
                  identity: (widget.id, _editorRevision, 'name'),
                  label: labels.propertyName,
                  controller: _nameController,
                  enabled: editable,
                ),
              ],
              SizedBox(height: theme.spacing.sm),
              Text(labels.type, style: theme.typography.label),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  for (final type in BeautifulRecordPropertyType.values)
                    choice(
                      labels.typeLabels[type] ?? type.name,
                      _draft!.type == type,
                      () =>
                          setState(() => _draft = _draft!.copyWith(type: type)),
                      key: 'records-type-${type.name}',
                    ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              Text(labels.tool, style: theme.typography.label),
              Wrap(
                spacing: theme.spacing.xs,
                children: <Widget>[
                  choice(
                    labels.manual,
                    _draft!.toolId == null,
                    () => setState(
                      () => _draft = _draft!.copyWith(clearTool: true),
                    ),
                    key: 'records-tool-manual',
                  ),
                  for (final tool in _tools)
                    choice(
                      tool.label,
                      _draft!.toolId == tool.id,
                      () => setState(
                        () => _draft = _draft!.copyWith(toolId: tool.id),
                      ),
                      key: 'records-tool-${tool.id}',
                    ),
                ],
              ),
              toggle(
                labels.grounding,
                _draft!.grounding,
                (value) => _draft = _draft!.copyWith(grounding: value),
                'records-grounding',
              ),
              Text(
                labels.groundingHelp,
                style: theme.typography.caption.copyWith(
                  color: theme.colors.inkMuted,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              Text(labels.inputs, style: theme.typography.label),
              for (final input in _columns.where(
                (input) => input.id != _editingId,
              ))
                toggle(input.label, _draft!.inputColumnIds.contains(input.id), (
                  value,
                ) {
                  final ids = <String>[..._draft!.inputColumnIds];
                  value ? ids.add(input.id) : ids.remove(input.id);
                  _draft = _draft!.copyWith(inputColumnIds: ids);
                }, 'records-input-${input.id}'),
              SizedBox(height: theme.spacing.sm),
              _RecordsTextEntry(
                identity: (widget.id, _editorRevision, 'prompt'),
                label: labels.prompt,
                controller: _promptController,
                multiline: true,
                enabled: editable,
              ),
              SizedBox(height: theme.spacing.sm),
              _button(
                labels.moreSettings,
                () => setState(() => _moreOpen = !_moreOpen),
                key: 'records-more-settings',
                expanded: _moreOpen,
              ),
              if (_moreOpen) ...<Widget>[
                toggle(
                  labels.requiredValue,
                  _draft!.requiredValue,
                  (value) => _draft = _draft!.copyWith(requiredValue: value),
                  'records-required',
                ),
                toggle(
                  labels.allowEmpty,
                  _draft!.allowEmpty,
                  (value) => _draft = _draft!.copyWith(allowEmpty: value),
                  'records-allow-empty',
                ),
                toggle(
                  labels.showConfidence,
                  _draft!.showConfidence,
                  (value) => _draft = _draft!.copyWith(showConfidence: value),
                  'records-confidence',
                ),
              ],
              if (column != null)
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    _bounded(
                      contentWidth,
                      _button(
                        _pinned.contains(column.id) ? labels.unpin : labels.pin,
                        () => setState(() {
                          _pinned.contains(column.id)
                              ? _pinned.remove(column.id)
                              : _pinned.add(column.id);
                        }),
                        key: 'records-pin',
                      ),
                    ),
                    if (column.hideable)
                      _bounded(
                        contentWidth,
                        _button(
                          _hidden.contains(column.id)
                              ? labels.show
                              : labels.hide,
                          () => setState(() {
                            _hidden.contains(column.id)
                                ? _hidden.remove(column.id)
                                : _hidden.add(column.id);
                          }),
                          key: 'records-hide',
                        ),
                      ),
                    _bounded(
                      contentWidth,
                      _button(
                        '${labels.decreaseWidth}: ${column.label}',
                        () => setState(
                          () => _widths[column.id] = math.max(
                            144,
                            _widths[column.id]! - 24,
                          ),
                        ),
                        key: 'records-narrow',
                      ),
                    ),
                    _bounded(
                      contentWidth,
                      _button(
                        '${labels.increaseWidth}: ${column.label}',
                        () => setState(
                          () => _widths[column.id] = math.min(
                            800,
                            _widths[column.id]! + 24,
                          ),
                        ),
                        key: 'records-widen',
                      ),
                    ),
                  ],
                ),
              if (_feedback != null || _pending != null) _status(theme),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  _bounded(
                    contentWidth,
                    _button(
                      _adding ? labels.addProperty : labels.save,
                      _pending != null ||
                              (_adding
                                  ? widget.onPropertyAdded == null
                                  : widget.onPropertyChanged == null)
                          ? null
                          : _save,
                      key: 'records-save',
                    ),
                  ),
                  if (!_adding)
                    _bounded(
                      contentWidth,
                      _button(
                        labels.run,
                        _pending != null ||
                                widget.onRun == null ||
                                _visible.isEmpty ||
                                _rows.any(
                                  (row) =>
                                      row.cells[_editingId]?.status ==
                                      BeautifulRecordCellStatus.running,
                                )
                            ? null
                            : _run,
                        key: 'records-run',
                      ),
                    ),
                  _bounded(
                    contentWidth,
                    _button(
                      labels.close,
                      () => setState(_closeEditor),
                      key: 'records-close-editor',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _RecordsTextEntry extends StatefulWidget {
  const _RecordsTextEntry({
    super.key,
    required this.identity,
    required this.label,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.multiline = false,
    this.enabled = true,
  });
  final Object identity;
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool multiline;
  final bool enabled;
  @override
  State<_RecordsTextEntry> createState() => _RecordsTextEntryState();
}

final class _RecordsTextEntryState extends State<_RecordsTextEntry> {
  final _key = GlobalKey<EditableTextState>();
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final identity = widget.identity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.label,
          style: theme.typography.caption.copyWith(
            color: theme.colors.inkMuted,
          ),
        ),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.inset,
            border: Border.all(color: theme.colors.lineStrong),
            borderRadius: BorderRadius.circular(theme.radii.control),
          ),
          child: BeautifulTextSelectionGestureDetector(
            editableTextKey: _key,
            identity: identity,
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: Semantics(
                label: widget.label,
                enabled: widget.enabled,
                readOnly: !widget.enabled,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: EditableText(
                    key: _key,
                    controller: widget.controller,
                    focusNode: widget.focusNode ?? _focus,
                    style: theme.typography.body.copyWith(
                      color: theme.colors.ink,
                    ),
                    cursorColor: theme.colors.accent,
                    backgroundCursorColor: theme.colors.inkMuted,
                    maxLines: widget.multiline ? null : 1,
                    minLines: widget.multiline ? 3 : 1,
                    readOnly: !widget.enabled,
                    rendererIgnoresPointer: true,
                    selectionControls: Overlay.maybeOf(context) == null
                        ? null
                        : BeautifulTextSelectionControls(theme.colors.accent),
                    selectionColor: theme.colors.accentTint,
                    onChanged: widget.onChanged,
                    contextMenuBuilder: (_, editable) =>
                        beautifulEditableTextContextMenu(
                          context,
                          editable,
                          isCurrent: () =>
                              mounted && widget.identity == identity,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _RecordsCheck extends StatefulWidget {
  const _RecordsCheck({
    super.key,
    required this.label,
    required this.checked,
    this.mixed = false,
    this.compact = false,
    this.onChanged,
  });
  final String label;
  final bool checked;
  final bool mixed;
  final bool compact;
  final VoidCallback? onChanged;
  @override
  State<_RecordsCheck> createState() => _RecordsCheckState();
}

final class _RecordsCheckState extends State<_RecordsCheck> {
  var _focused = false;
  final _focusNode = FocusNode();
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Semantics(
      label: widget.label,
      checked: widget.mixed ? null : widget.checked,
      mixed: widget.mixed,
      enabled: widget.onChanged != null,
      excludeSemantics: true,
      onTap: widget.onChanged,
      child: FocusableActionDetector(
        focusNode: _focusNode,
        enabled: widget.onChanged != null,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onChanged?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onChanged == null
              ? null
              : () {
                  _focusNode.requestFocus();
                  widget.onChanged!();
                },
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: _focused ? theme.colors.accent : const Color(0x00000000),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(theme.radii.control),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CustomPaint(
                  size: const Size.square(20),
                  painter: _RecordsCheckPainter(
                    theme.colors.ink,
                    widget.checked,
                    widget.mixed,
                  ),
                ),
                if (!widget.compact) ...<Widget>[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.label,
                      style: theme.typography.label.copyWith(
                        color: theme.colors.ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _RecordsCheckPainter extends CustomPainter {
  const _RecordsCheckPainter(this.color, this.checked, this.mixed);
  final Color color;
  final bool checked;
  final bool mixed;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
      paint,
    );
    if (mixed) {
      canvas.drawLine(const Offset(5, 10), const Offset(15, 10), paint);
    } else if (checked) {
      canvas.drawPath(
        Path()
          ..moveTo(4, 10)
          ..lineTo(8, 14)
          ..lineTo(16, 5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RecordsCheckPainter oldDelegate) =>
      color != oldDelegate.color ||
      checked != oldDelegate.checked ||
      mixed != oldDelegate.mixed;
}

final class _RecordsResize extends StatefulWidget {
  const _RecordsResize({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  @override
  State<_RecordsResize> createState() => _RecordsResizeState();
}

final class _RecordsResizeState extends State<_RecordsResize> {
  var _focused = false;
  var _dragWidth = 0.0;
  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return Semantics(
      slider: true,
      enabled: true,
      label: widget.label,
      value: widget.value.round().toString(),
      increasedValue: math.min(800, widget.value + 24).round().toString(),
      decreasedValue: math.max(144, widget.value - 24).round().toString(),
      onIncrease: () => widget.onChanged(widget.value + 24),
      onDecrease: () => widget.onChanged(widget.value - 24),
      child: Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              widget.onChanged(
                widget.value +
                    (event.logicalKey == LogicalKeyboardKey.arrowRight
                            ? 24
                            : -24) *
                        direction,
              );
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (_) => _dragWidth = widget.value,
            onHorizontalDragUpdate: (details) {
              _dragWidth = (_dragWidth + details.delta.dx * direction).clamp(
                144,
                800,
              );
              widget.onChanged(_dragWidth);
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focused
                      ? theme.colors.accent
                      : const Color(0x00000000),
                ),
              ),
              child: Center(
                child: Container(
                  width: 3,
                  height: 18,
                  color: theme.colors.lineStrong,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Put role metadata inside Scrollable's own semantics boundary so Flutter's
// strict native table/list parent relationships remain valid with lazy rows.
final class _RecordsScrollView extends CustomScrollView {
  const _RecordsScrollView({
    super.key,
    required super.controller,
    required super.slivers,
    required this.table,
    required this.label,
  }) : super(scrollCacheExtent: const ScrollCacheExtent.pixels(100));
  final bool table;
  final String label;
  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) => Semantics(
    container: true,
    explicitChildNodes: true,
    role: table ? SemanticsRole.table : SemanticsRole.list,
    label: label,
    child: super.buildViewport(context, offset, axisDirection, slivers),
  );
}

final class _RecordsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _RecordsHeaderDelegate(this.child, this.height);
  final Widget child;
  final double height;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(_RecordsHeaderDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}

final class _RecordsPendingAction {
  const _RecordsPendingAction(
    this.tableId,
    this.columnId,
    this.acceptedProperty,
    this.rows,
    this.inputColumns,
  );
  final String tableId;
  final String? columnId;
  final BeautifulRecordPropertyConfig? acceptedProperty;
  final List<BeautifulRecordRow> rows;
  final List<BeautifulRecordColumn>? inputColumns;
}

bool _sameRecord(BeautifulRecordRow before, BeautifulRecordRow? after) {
  if (after == null ||
      before.id != after.id ||
      before.label != after.label ||
      before.cells.length != after.cells.length) {
    return false;
  }
  for (final entry in before.cells.entries) {
    final a = entry.value;
    final b = after.cells[entry.key];
    if (b == null ||
        a.text != b.text ||
        !listEquals(a.tags, b.tags) ||
        a.number != b.number ||
        a.date != b.date ||
        a.uri != b.uri ||
        a.status != b.status ||
        a.error != b.error) {
      return false;
    }
  }
  return true;
}

bool _sameRecordCell(BeautifulRecordCell? a, BeautifulRecordCell? b) {
  if (a == null || b == null) return a == b;
  return a.text == b.text &&
      listEquals(a.tags, b.tags) &&
      a.number == b.number &&
      a.date == b.date &&
      a.uri == b.uri &&
      a.status == b.status &&
      a.error == b.error;
}
