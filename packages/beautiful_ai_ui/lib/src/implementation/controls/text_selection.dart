import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show
        CupertinoTheme,
        CupertinoThemeData,
        cupertinoTextSelectionHandleControls;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show
        TextSelectionTheme,
        TextSelectionThemeData,
        materialTextSelectionHandleControls;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/environment.dart';
import '../../foundation/failure.dart';
import '../../foundation/theme.dart';
import 'action_control.dart';

/// Platform-shaped handles whose placement and dragging stay Flutter-owned.
final class BeautifulTextSelectionControls extends TextSelectionControls
    with TextSelectionHandleControls {
  /// Creates handles in the component's semantic accent color.
  BeautifulTextSelectionControls(this.color);

  /// Color used by the platform handle painter.
  final Color color;

  // Editors rebuild during selection drags. Equivalent controls must compare
  // equal so EditableText retains its active SelectionOverlay and drag state.
  @override
  bool operator ==(Object other) =>
      other is BeautifulTextSelectionControls && other.color == color;

  @override
  int get hashCode => Object.hash(BeautifulTextSelectionControls, color);

  TextSelectionControls get _platformControls =>
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS ||
        TargetPlatform.macOS => cupertinoTextSelectionHandleControls,
        _ => materialTextSelectionHandleControls,
      };

  @override
  Size getHandleSize(double textLineHeight) =>
      _platformControls.getHandleSize(textLineHeight);

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) =>
      _platformControls.getHandleAnchor(type, textLineHeight);

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) => TextSelectionTheme(
    data: TextSelectionThemeData(selectionHandleColor: color),
    child: CupertinoTheme(
      data: CupertinoThemeData(primaryColor: color),
      child: Builder(
        builder: (context) =>
            _platformControls.buildHandle(context, type, textLineHeight, onTap),
      ),
    ),
  );
}

/// Supplies native Flutter text gestures around a raw [EditableText].
///
/// Assign [editableTextKey] to that editor and set its `rendererIgnoresPointer`
/// to true. This wrapper handles touch long press, double-click word selection,
/// mouse dragging, and the platform's context-menu gesture.
/// Keyboard and native accessibility clipboard actions use the same guarded
/// clipboard routine as the toolbar, and are invalidated by [identity] changes.
final class BeautifulTextSelectionGestureDetector extends StatefulWidget {
  /// Creates a gesture layer for one stable editor.
  const BeautifulTextSelectionGestureDetector({
    super.key,
    required this.editableTextKey,
    required this.child,
    this.identity,
  });

  /// The editor whose render object performs hit testing and selection.
  final GlobalKey<EditableTextState> editableTextKey;

  /// Host model identity whose pending clipboard operations must be isolated.
  ///
  /// Examples include a conversation ID or an approval/question ID record.
  /// Changing identity invalidates an operation even when the replacement
  /// editor has exactly the same text and selection as its predecessor.
  final Object? identity;

  /// Editor and optional padding that share its interactive area.
  final Widget child;

  @override
  State<BeautifulTextSelectionGestureDetector> createState() =>
      _BeautifulTextSelectionGestureDetectorState();
}

final class _BeautifulTextSelectionGestureDetectorState
    extends State<BeautifulTextSelectionGestureDetector>
    implements TextSelectionGestureDetectorBuilderDelegate {
  late final TextSelectionGestureDetectorBuilder _gestures =
      TextSelectionGestureDetectorBuilder(delegate: this);
  TextEditingController? _observedController;
  FocusNode? _observedFocus;
  var _identityGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scheduleObserveEditor();
  }

  @override
  void didUpdateWidget(BeautifulTextSelectionGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.editableTextKey != widget.editableTextKey) {
      _identityGeneration++;
    }
    _scheduleObserveEditor();
  }

  void _scheduleObserveEditor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final editor = editableTextKey.currentState;
      final controller = editor?.widget.controller;
      final focus = editor?.widget.focusNode;
      if (controller == _observedController && focus == _observedFocus) return;
      _observedController?.removeListener(_editorChanged);
      _observedFocus?.removeListener(_editorChanged);
      _observedController = controller;
      _observedFocus = focus;
      controller?.addListener(_editorChanged);
      focus?.addListener(_editorChanged);
      setState(() {});
    });
  }

  void _editorChanged() {
    if (mounted) setState(() {});
  }

  void _runClipboard(
    ContextMenuButtonType type, {
    SelectionChangedCause cause = SelectionChangedCause.toolbar,
  }) {
    final editor = editableTextKey.currentState;
    if (editor == null || !editor.widget.selectionEnabled) return;
    final generation = _identityGeneration;
    unawaited(
      _clipboardAction(
        BeautifulUiEnvironment.of(context),
        editor,
        type,
        () => mounted && generation == _identityGeneration,
        cause: cause,
      ),
    );
  }

  @override
  void dispose() {
    _observedController?.removeListener(_editorChanged);
    _observedFocus?.removeListener(_editorChanged);
    super.dispose();
  }

  @override
  GlobalKey<EditableTextState> get editableTextKey => widget.editableTextKey;

  @override
  bool get forcePressEnabled => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get selectionEnabled =>
      editableTextKey.currentState?.widget.selectionEnabled ?? true;

  @override
  Widget build(BuildContext context) {
    final editor = editableTextKey.currentState;
    final focused = editor?.widget.focusNode.hasFocus ?? false;
    final canCopy =
        focused && selectionEnabled && (editor?.copyEnabled ?? false);
    final canCut = focused && selectionEnabled && (editor?.cutEnabled ?? false);
    final canPaste =
        focused && selectionEnabled && (editor?.pasteEnabled ?? false);
    return Actions(
      actions: <Type, Action<Intent>>{
        CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
          onInvoke: (intent) {
            _runClipboard(
              intent.collapseSelection
                  ? ContextMenuButtonType.cut
                  : ContextMenuButtonType.copy,
              cause: intent.cause,
            );
            return null;
          },
        ),
        PasteTextIntent: CallbackAction<PasteTextIntent>(
          onInvoke: (intent) {
            _runClipboard(ContextMenuButtonType.paste, cause: intent.cause);
            return null;
          },
        ),
      },
      // The outer action handlers win when native editor descendants are
      // merged into this node. Keep the editor's value, selection movement,
      // focus, and text-editing semantics intact.
      child: MergeSemantics(
        child: Semantics(
          onCopy: canCopy
              ? () => _runClipboard(ContextMenuButtonType.copy)
              : null,
          onCut: canCut ? () => _runClipboard(ContextMenuButtonType.cut) : null,
          onPaste: canPaste
              ? () => _runClipboard(ContextMenuButtonType.paste)
              : null,
          child: _gestures.buildGestureDetector(
            behavior: HitTestBehavior.translucent,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Builds a localized editor menu with guarded clipboard reads and writes.
///
/// Successful cut/paste applies through [EditableTextState.userUpdateTextEditingValue],
/// preserving input formatters and edit callbacks. A delayed operation cannot
/// replace subsequent edits. [isCurrent] additionally guards a host model or
/// conversation that can be replaced while retaining the same editor state.
Widget beautifulEditableTextContextMenu(
  BuildContext context,
  EditableTextState editable, {
  String? copyLabel,
  String? cutLabel,
  String? pasteLabel,
  String? selectAllLabel,
  bool Function()? isCurrent,
  Iterable<ContextMenuButtonItem> additionalButtons = const [],
}) {
  final labels = WidgetsLocalizations.of(context);
  final environment = BeautifulUiEnvironment.of(context);
  final buttons = <ContextMenuButtonItem>[];
  for (final item in editable.contextMenuButtonItems) {
    final label = switch (item.type) {
      ContextMenuButtonType.copy => copyLabel ?? labels.copyButtonLabel,
      ContextMenuButtonType.cut => cutLabel ?? labels.cutButtonLabel,
      ContextMenuButtonType.paste => pasteLabel ?? labels.pasteButtonLabel,
      ContextMenuButtonType.selectAll =>
        selectAllLabel ?? labels.selectAllButtonLabel,
      _ => null,
    };
    if (label == null) continue;
    buttons.add(
      ContextMenuButtonItem(
        type: item.type,
        label: label,
        onPressed: item.type == ContextMenuButtonType.selectAll
            ? () {
                if (editable.mounted && (isCurrent?.call() ?? true)) {
                  editable.selectAll(SelectionChangedCause.toolbar);
                }
              }
            : () => unawaited(
                _clipboardAction(environment, editable, item.type, isCurrent),
              ),
      ),
    );
  }
  buttons.addAll(additionalButtons);
  return beautifulTextSelectionToolbar(
    context,
    anchors: editable.contextMenuAnchors,
    buttons: buttons,
  );
}

Future<void> _clipboardAction(
  BeautifulUiEnvironment environment,
  EditableTextState editable,
  ContextMenuButtonType type,
  bool Function()? isCurrent, {
  SelectionChangedCause cause = SelectionChangedCause.toolbar,
}) async {
  if (!editable.mounted || !(isCurrent?.call() ?? true)) return;
  if (!editable.widget.selectionEnabled ||
      (editable.widget.readOnly && type != ContextMenuButtonType.copy)) {
    return;
  }
  final before = editable.textEditingValue;
  if (!before.selection.isValid) return;
  bool stillCurrent() =>
      editable.mounted &&
      (isCurrent?.call() ?? true) &&
      editable.textEditingValue == before;
  try {
    String? replacement;
    if (type == ContextMenuButtonType.paste) {
      replacement = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (replacement == null) return;
    } else {
      if (before.selection.isCollapsed || editable.widget.obscureText) return;
      await Clipboard.setData(
        ClipboardData(text: before.selection.textInside(before.text)),
      );
      if (type == ContextMenuButtonType.cut) replacement = '';
    }
    if (!stillCurrent()) return;
    if (replacement != null && !editable.widget.readOnly) {
      editable.userUpdateTextEditingValue(
        before.copyWith(
          text:
              before.selection.textBefore(before.text) +
              replacement +
              before.selection.textAfter(before.text),
          selection: TextSelection.collapsed(
            offset: before.selection.start + replacement.length,
          ),
          composing: TextRange.empty,
        ),
        cause,
      );
    }
    editable.hideToolbar();
    editable.clipboardStatus.update();
  } catch (error, stackTrace) {
    if (!stillCurrent()) return;
    environment.reportFailure(
      BeautifulUiFailure(
        operation: BeautifulUiOperation.clipboard,
        message: 'Text selection ${type.name} failed.',
        cause: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

/// Places accessible 48dp menu actions at native text-selection anchors.
///
/// Captures package theme/environment because context-menu overlays may be
/// mounted above the component's [BeautifulUiScope]. Owners of selectable
/// content supply the exact selected substring and their own action callback.
Widget beautifulTextSelectionToolbar(
  BuildContext context, {
  required TextSelectionToolbarAnchors anchors,
  required List<ContextMenuButtonItem> buttons,
}) {
  final theme = BeautifulUiTheme.of(context);
  final environment = BeautifulUiEnvironment.of(context);
  return BeautifulUiEnvironment(
    breakpoints: environment.breakpoints,
    motionPolicy: environment.motionPolicy,
    failureHandler: environment.failureHandler,
    child: BeautifulUiTheme(
      data: theme,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: CustomSingleChildLayout(
          delegate: TextSelectionToolbarLayoutDelegate(
            anchorAbove: anchors.primaryAnchor,
            anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.max(0, MediaQuery.sizeOf(context).width - 16),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.surface,
                borderRadius: BorderRadius.circular(theme.radii.control),
                border: Border.all(color: theme.colors.lineStrong),
                boxShadow: theme.shadows.raised,
              ),
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.xs),
                child: Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    for (final button in buttons)
                      BeautifulActionControl(
                        label: button.label ?? button.type.name,
                        minHeight: 48,
                        maxLines: null,
                        tone: BeautifulActionTone.quiet,
                        onPressed: button.onPressed,
                      ),
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
