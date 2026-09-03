import 'dart:async';
import 'dart:ui' show BoxWidthStyle;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/failure.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';
import '../implementation/controls/text_selection.dart';

/// Whether a selected-text action proposes an edit or only explains content.
enum BeautifulSelectionActionKind {
  /// The returned text can replace the selected range after confirmation.
  replace,

  /// The returned explanation never replaces document content.
  explain,
}

/// One localized operation offered for an actual selected range.
@immutable
final class BeautifulSelectionAction {
  /// Creates a stable action. Secondary actions live behind More actions.
  const BeautifulSelectionAction({
    required this.id,
    required this.label,
    this.kind = BeautifulSelectionActionKind.replace,
    this.secondary = false,
    this.busyLabel,
  });

  /// Non-empty stable action identity.
  final String id;

  /// Visible, localizable action name.
  final String label;

  /// Whether the result is an edit or an explanation.
  final BeautifulSelectionActionKind kind;

  /// Whether the in-flow panel initially hides this action.
  final bool secondary;

  /// Optional localized progress label.
  final String? busyLabel;
}

/// Immutable request crossing from selection presentation to the host.
@immutable
final class BeautifulSelectionRequest {
  /// Creates a request from a precise UTF-16 selection in the source snapshot.
  const BeautifulSelectionRequest({
    required this.documentId,
    required this.baseText,
    required this.selection,
    required this.action,
    this.instruction,
  });

  /// The document whose selection was acted on.
  final String documentId;

  /// Exact source snapshot; the host can include or validate surrounding text.
  final String baseText;

  /// Precise range, including which repeated occurrence the user selected.
  final TextSelection selection;

  /// Stable action and its result kind.
  final BeautifulSelectionAction action;

  /// Optional custom instruction, otherwise null for a preset action.
  final String? instruction;

  /// The literal selected substring, without whitespace normalization.
  String get selectedText => selection.textInside(baseText);
}

/// An explicit proposed edit; applying it remains a host responsibility.
@immutable
final class BeautifulSelectionEdit {
  /// Creates an edit with the original snapshot for conflict checking.
  const BeautifulSelectionEdit({
    required this.request,
    required this.replacement,
  });

  /// Source document, original selection, action and optional instruction.
  final BeautifulSelectionRequest request;

  /// Exact replacement, which can be empty to remove the selection.
  final String replacement;

  /// The result if the host accepts this edit against [request.baseText].
  String get updatedText => request.baseText.replaceRange(
    request.selection.start,
    request.selection.end,
    replacement,
  );
}

/// Labels for the document, instruction editor, preview and action status.
@immutable
final class BeautifulSelectionLabels {
  /// Creates labels with English defaults.
  const BeautifulSelectionLabels({
    this.document = 'Document',
    this.chooseText = 'Select text to see actions',
    this.selectedText = 'Selected text',
    this.instruction = 'Describe edits',
    this.send = 'Send edit instruction',
    this.more = 'More actions',
    this.fewer = 'Fewer actions',
    this.working = 'Working on selection',
    this.ready = 'Suggestion ready',
    this.applying = 'Applying change',
    this.applied = 'Change accepted',
    this.before = 'Original text',
    this.after = 'Suggested text',
    this.explanation = 'Explanation',
    this.keep = 'Keep change',
    this.discard = 'Discard',
    this.retry = 'Try again',
    this.requestFailed = 'Could not prepare a suggestion',
    this.applyFailed = 'Could not apply the change',
  });

  /// Accessible document name.
  final String document;

  /// Hint when the selection is empty.
  final String chooseText;

  /// Heading for the current source range.
  final String selectedText;

  /// Label and placeholder for the instruction input.
  final String instruction;

  /// Custom request action.
  final String send;

  /// Expand secondary actions.
  final String more;

  /// Hide secondary actions.
  final String fewer;

  /// Default request progress.
  final String working;

  /// Completed suggestion progress.
  final String ready;

  /// Host apply progress.
  final String applying;

  /// Successful host apply progress.
  final String applied;

  /// Original range heading.
  final String before;

  /// Replacement heading.
  final String after;

  /// Explanation heading.
  final String explanation;

  /// Apply the replacement.
  final String keep;

  /// Close a result or cancel its local presentation.
  final String discard;

  /// Repeat the last exact request.
  final String retry;

  /// Localized request failure.
  final String requestFailed;

  /// Localized apply failure.
  final String applyFailed;
}

const _defaultActions = <BeautifulSelectionAction>[
  BeautifulSelectionAction(
    id: 'explain',
    label: 'Explain',
    kind: BeautifulSelectionActionKind.explain,
  ),
  BeautifulSelectionAction(id: 'improve', label: 'Improve'),
  BeautifulSelectionAction(id: 'shorten', label: 'Shorten', secondary: true),
  BeautifulSelectionAction(id: 'tone', label: 'Change tone', secondary: true),
  BeautifulSelectionAction(
    id: 'grammar',
    label: 'Fix grammar',
    secondary: true,
  ),
];

/// Contextual actions, native text selection and a confirmable edit preview.
///
/// The host supplies [text] and executes [onRequest] / [onApply]. This widget
/// does not fabricate a selected passage or run an AI service. Pointer, touch,
/// keyboard and native selection all produce exact Flutter [TextSelection]
/// ranges. The native anchored toolbar offers the primary actions; an in-flow
/// panel keeps all actions and the result reachable at narrow widths and with
/// a software keyboard. The bounded editor scrolls long documents internally.
///
/// Changing [documentId], [text], or the selected range invalidates old work.
/// Resizing and equivalent snapshots preserve the range, instruction and focus.
/// [initialSelection] is read only on insertion or a different document ID.
/// Applying a replacement invokes the host; it never silently edits [text].
final class BeautifulSelectionActions extends StatefulWidget {
  /// Creates a selected-text editing surface.
  ///
  /// [onRequest] returns exact replacement/explanation text. [onApply] can be
  /// omitted for a preview-only surface; Keep remains disabled in that case.
  /// Invalid IDs, duplicate actions, or out-of-bounds initial ranges throw
  /// [ArgumentError]. Selection offsets are UTF-16 and cannot split a surrogate.
  BeautifulSelectionActions({
    super.key,
    required this.documentId,
    required this.text,
    required this.onRequest,
    this.onApply,
    this.initialSelection,
    Iterable<BeautifulSelectionAction> actions = _defaultActions,
    this.labels = const BeautifulSelectionLabels(),
    this.errorMessage,
    this.documentMaxLines = 8,
    this.enabled = true,
  }) : actions = List.unmodifiable(actions) {
    if (documentId.trim().isEmpty) {
      throw ArgumentError.value(documentId, 'documentId');
    }
    if (documentMaxLines < 1 || documentMaxLines > 40) {
      throw ArgumentError.value(
        documentMaxLines,
        'documentMaxLines',
        'must be between 1 and 40',
      );
    }
    if (initialSelection != null && !_validRange(text, initialSelection!)) {
      throw ArgumentError.value(
        initialSelection,
        'initialSelection',
        'must be a valid UTF-16 range',
      );
    }
    final ids = <String>{};
    for (final action in this.actions) {
      if (action.id.trim().isEmpty ||
          action.label.trim().isEmpty ||
          !ids.add(action.id)) {
        throw ArgumentError('Actions require unique non-empty IDs and labels.');
      }
    }
  }

  /// Stable document identity; use a different ID for a replacement document.
  final String documentId;

  /// Exact host-owned plain text.
  final String text;

  /// Optional initial range, including a reversed selection.
  final TextSelection? initialSelection;

  /// Defensively copied available actions.
  final List<BeautifulSelectionAction> actions;

  /// Host operation returning replacement or explanation text.
  final FutureOr<String> Function(BeautifulSelectionRequest request) onRequest;

  /// Host application of the explicit edit after the user confirms it.
  final FutureOr<void> Function(BeautifulSelectionEdit edit)? onApply;

  /// Localized interface labels.
  final BeautifulSelectionLabels labels;

  /// Optional host-provided localized error.
  final String? errorMessage;

  /// Maximum visible document lines; longer text scrolls within the editor.
  final int documentMaxLines;

  /// Whether AI requests and application controls are available.
  final bool enabled;

  static bool _validRange(String text, TextSelection range) {
    if (!range.isValid || range.start < 0 || range.end > text.length) {
      return false;
    }
    bool boundary(int i) =>
        i == 0 ||
        i == text.length ||
        !(text.codeUnitAt(i - 1) >= 0xd800 &&
            text.codeUnitAt(i - 1) <= 0xdbff &&
            text.codeUnitAt(i) >= 0xdc00 &&
            text.codeUnitAt(i) <= 0xdfff);
    return boundary(range.start) && boundary(range.end);
  }

  @override
  State<BeautifulSelectionActions> createState() =>
      _BeautifulSelectionActionsState();
}

final class _BeautifulSelectionActionsState
    extends State<BeautifulSelectionActions> {
  late final TextEditingController _document;
  final _instruction = TextEditingController();
  final _documentFocus = FocusNode();
  final _instructionFocus = FocusNode();
  final _documentKey = GlobalKey<EditableTextState>();
  final _instructionKey = GlobalKey<EditableTextState>();
  final _scroll = ScrollController();
  late TextSelection _selection;
  var _generation = 0;
  var _requesting = false;
  var _applying = false;
  var _more = false;
  var _syncing = false;
  String? _result;
  String? _status;
  BeautifulSelectionRequest? _request;

  bool get _active =>
      BeautifulSelectionActions._validRange(widget.text, _selection) &&
      !_selection.isCollapsed;
  bool get _busy => _requesting || _applying;

  @override
  void initState() {
    super.initState();
    _selection =
        widget.initialSelection ?? const TextSelection.collapsed(offset: 0);
    _document = TextEditingController.fromValue(
      TextEditingValue(text: widget.text, selection: _selection),
    );
    _instruction.addListener(_instructionChanged);
    _documentFocus.addListener(_focusChanged);
    _instructionFocus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  void _instructionChanged() {
    if (!_syncing && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(BeautifulSelectionActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId ||
        oldWidget.text != widget.text) {
      _invalidate();
      _selection = oldWidget.documentId != widget.documentId
          ? widget.initialSelection ?? const TextSelection.collapsed(offset: 0)
          : const TextSelection.collapsed(offset: 0);
      _syncing = true;
      _document.value = TextEditingValue(
        text: widget.text,
        selection: _selection,
      );
      _instruction.clear();
      _syncing = false;
      _more = false;
    } else if (oldWidget.enabled && !widget.enabled) {
      _invalidate();
    }
  }

  void _invalidate() {
    _generation++;
    _requesting = false;
    _applying = false;
    _result = null;
    _request = null;
    _status = null;
  }

  void _selectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    if (_syncing ||
        selection == _selection ||
        !BeautifulSelectionActions._validRange(widget.text, selection)) {
      return;
    }
    setState(() {
      _invalidate();
      _selection = selection;
    });
  }

  Future<void> _run(
    BeautifulSelectionAction action, {
    String? instruction,
  }) async {
    if (!_active || _busy || !widget.enabled) return;
    final request = BeautifulSelectionRequest(
      documentId: widget.documentId,
      baseText: widget.text,
      selection: _selection,
      action: action,
      instruction: instruction,
    );
    final generation = ++_generation;
    final environment = BeautifulUiEnvironment.of(context);
    final callback = widget.onRequest;
    // The instruction/preset controls may disappear when a result arrives.
    // Keep keyboard ownership on the persistent document during the request.
    _documentFocus.requestFocus();
    setState(() {
      _request = request;
      _result = null;
      _requesting = true;
      _status = action.busyLabel ?? widget.labels.working;
    });
    try {
      final result = await callback(request);
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = result;
        _status = widget.labels.ready;
      });
    } catch (error, stack) {
      if (!mounted || generation != _generation) return;
      setState(() => _status = widget.labels.requestFailed);
      environment.reportFailure(
        BeautifulUiFailure(
          operation: BeautifulUiOperation.selection,
          message: 'Selected-text request failed.',
          cause: error,
          stackTrace: stack,
        ),
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _requesting = false);
      }
    }
  }

  void _runInstruction() {
    if (_instruction.value.composing.isValid &&
        !_instruction.value.composing.isCollapsed) {
      return;
    }
    final text = _instruction.text.trim();
    if (text.isEmpty) return;
    unawaited(
      _run(
        BeautifulSelectionAction(id: 'custom', label: widget.labels.send),
        instruction: text,
      ),
    );
  }

  Future<void> _apply() async {
    final result = _result;
    final request = _request;
    final callback = widget.onApply;
    if (!widget.enabled ||
        _busy ||
        result == null ||
        request == null ||
        callback == null ||
        request.action.kind != BeautifulSelectionActionKind.replace) {
      return;
    }
    final generation = _generation;
    final environment = BeautifulUiEnvironment.of(context);
    _documentFocus.requestFocus();
    setState(() {
      _applying = true;
      _status = widget.labels.applying;
    });
    try {
      await callback(
        BeautifulSelectionEdit(request: request, replacement: result),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = null;
        _request = null;
        _status = widget.labels.applied;
      });
    } catch (error, stack) {
      if (!mounted || generation != _generation) return;
      setState(() => _status = widget.labels.applyFailed);
      environment.reportFailure(
        BeautifulUiFailure(
          operation: BeautifulUiOperation.selection,
          message: 'Applying selected-text edit failed.',
          cause: error,
          stackTrace: stack,
        ),
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _applying = false);
      }
    }
  }

  void _discard() {
    setState(_invalidate);
    _documentFocus.requestFocus();
  }

  @override
  void dispose() {
    _instruction.removeListener(_instructionChanged);
    _documentFocus.removeListener(_focusChanged);
    _instructionFocus.removeListener(_focusChanged);
    _document.dispose();
    _instruction.dispose();
    _documentFocus.dispose();
    _instructionFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final hasOverlay = Overlay.maybeOf(context) != null;
    final labels = widget.labels;
    return Focus(
      includeSemantics: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            (_request != null || _more)) {
          _discard();
          setState(() => _more = false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Semantics(
              label: labels.document,
              textField: true,
              readOnly: true,
              enabled: true,
              child: BeautifulTextSelectionGestureDetector(
                editableTextKey: _documentKey,
                identity: (widget.documentId, widget.text),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: EdgeInsets.all(theme.spacing.md),
                  decoration: BoxDecoration(
                    color: theme.colors.surface,
                    border: Border.all(color: theme.colors.line),
                    borderRadius: BorderRadius.circular(theme.radii.card),
                  ),
                  child: EditableText(
                    key: _documentKey,
                    controller: _document,
                    focusNode: _documentFocus,
                    readOnly: true,
                    showCursor: false,
                    rendererIgnoresPointer: true,
                    scrollController: _scroll,
                    minLines: 1,
                    maxLines: widget.documentMaxLines,
                    style: theme.typography.body.copyWith(
                      color: theme.colors.ink,
                      height: 1.7,
                    ),
                    cursorColor: theme.colors.accent,
                    backgroundCursorColor: theme.colors.inkMuted,
                    selectionColor: theme.colors.accentTint,
                    // Native max-width boxes can cover unselected RTL text.
                    // Editing actions must show the exact source range.
                    selectionWidthStyle: BoxWidthStyle.tight,
                    selectionControls: hasOverlay
                        ? BeautifulTextSelectionControls(theme.colors.accent)
                        : null,
                    showSelectionHandles: hasOverlay,
                    onSelectionChanged: _selectionChanged,
                    contextMenuBuilder: !hasOverlay
                        ? null
                        : (_, editor) {
                            final generation = _generation;
                            return beautifulEditableTextContextMenu(
                              context,
                              editor,
                              isCurrent: () =>
                                  mounted && generation == _generation,
                              additionalButtons: [
                                if (widget.enabled && !_busy && _active)
                                  for (final action in widget.actions.where(
                                    (a) => !a.secondary,
                                  ))
                                    ContextMenuButtonItem(
                                      label: action.label,
                                      onPressed: () {
                                        editor.hideToolbar();
                                        unawaited(_run(action));
                                      },
                                    ),
                              ],
                            );
                          },
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(
              _status ?? (_active ? labels.selectedText : labels.chooseText),
              style: theme.typography.caption.copyWith(
                color: theme.colors.inkMuted,
              ),
            ),
          ),
          if (widget.errorMessage case final message?)
            Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                message,
                style: theme.typography.body.copyWith(
                  color: theme.colors.destructive,
                ),
              ),
            ),
          if (_active) ...[
            SizedBox(height: theme.spacing.sm),
            if (_result != null && _request != null) ...[
              if (_request!.action.kind ==
                  BeautifulSelectionActionKind.replace) ...[
                _preview(labels.before, _request!.selectedText, theme),
                SizedBox(height: theme.spacing.sm),
              ],
              _preview(
                _request!.action.kind == BeautifulSelectionActionKind.explain
                    ? labels.explanation
                    : labels.after,
                _result!,
                theme,
              ),
              SizedBox(height: theme.spacing.sm),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: [
                  if (_request!.action.kind ==
                      BeautifulSelectionActionKind.replace)
                    _button(
                      labels.keep,
                      !_busy && widget.enabled && widget.onApply != null
                          ? _apply
                          : null,
                      primary: true,
                    ),
                  _button(labels.discard, _discard),
                  _button(
                    labels.retry,
                    !_busy && widget.enabled
                        ? () => _run(
                            _request!.action,
                            instruction: _request!.instruction,
                          )
                        : null,
                  ),
                ],
              ),
            ] else ...[
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: [
                  for (final action in widget.actions)
                    if (!action.secondary || _more)
                      _button(
                        action.label,
                        widget.enabled && !_busy ? () => _run(action) : null,
                      ),
                  if (widget.actions.any((a) => a.secondary))
                    BeautifulActionControl(
                      label: _more ? labels.fewer : labels.more,
                      expanded: _more,
                      minHeight: 48,
                      maxLines: null,
                      onPressed: () => setState(() => _more = !_more),
                    ),
                  if (_request != null && !_busy)
                    _button(
                      labels.retry,
                      widget.enabled
                          ? () => _run(
                              _request!.action,
                              instruction: _request!.instruction,
                            )
                          : null,
                    ),
                  if (_request != null) _button(labels.discard, _discard),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              MergeSemantics(
                child: Semantics(
                  label: labels.instruction,
                  enabled: widget.enabled,
                  textField: true,
                  child: BeautifulTextSelectionGestureDetector(
                    editableTextKey: _instructionKey,
                    identity: (
                      widget.documentId,
                      _selection.start,
                      _selection.end,
                    ),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: EdgeInsets.all(theme.spacing.md),
                      decoration: BoxDecoration(
                        color: theme.colors.field,
                        border: Border.all(color: theme.colors.lineStrong),
                        borderRadius: BorderRadius.circular(
                          theme.radii.control,
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (_instruction.text.isEmpty)
                            ExcludeSemantics(
                              child: Text(
                                labels.instruction,
                                style: theme.typography.body.copyWith(
                                  color: theme.colors.inkSubtle,
                                ),
                              ),
                            ),
                          EditableText(
                            key: _instructionKey,
                            controller: _instruction,
                            focusNode: _instructionFocus,
                            readOnly: !widget.enabled,
                            rendererIgnoresPointer: true,
                            minLines: 1,
                            maxLines: 3,
                            style: theme.typography.body.copyWith(
                              color: theme.colors.ink,
                            ),
                            cursorColor: theme.colors.accent,
                            backgroundCursorColor: theme.colors.inkMuted,
                            selectionColor: theme.colors.accentTint,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.done,
                            onEditingComplete: () {},
                            onSubmitted: (_) => _runInstruction(),
                            selectionControls: hasOverlay
                                ? BeautifulTextSelectionControls(
                                    theme.colors.accent,
                                  )
                                : null,
                            showSelectionHandles: hasOverlay,
                            contextMenuBuilder: !hasOverlay
                                ? null
                                : (_, editor) {
                                    final generation = _generation;
                                    return beautifulEditableTextContextMenu(
                                      context,
                                      editor,
                                      isCurrent: () =>
                                          mounted && generation == _generation,
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              _button(
                labels.send,
                widget.enabled && !_busy && _instruction.text.trim().isNotEmpty
                    ? _runInstruction
                    : null,
                primary: true,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback? action, {bool primary = false}) =>
      BeautifulActionControl(
        label: label,
        onPressed: action,
        minHeight: 48,
        maxLines: null,
        tone: primary ? BeautifulActionTone.primary : BeautifulActionTone.quiet,
      );

  Widget _preview(String label, String text, BeautifulUiThemeData theme) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.inset,
          border: Border.all(color: theme.colors.line),
          borderRadius: BorderRadius.circular(theme.radii.card),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: theme.typography.label.copyWith(
                  color: theme.colors.inkMuted,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                text,
                style: theme.typography.body.copyWith(color: theme.colors.ink),
              ),
            ],
          ),
        ),
      );
}
