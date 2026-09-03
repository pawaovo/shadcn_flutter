import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/failure.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';
import '../implementation/controls/text_selection.dart';

/// The author of a [BeautifulChatMessage].
enum BeautifulChatRole {
  /// A prompt supplied by the person using the application.
  user,

  /// A response supplied by the host's assistant.
  assistant,

  /// Context or a notice supplied by the host application.
  system,
}

/// The host-owned response state of a [BeautifulChat].
enum BeautifulChatStatus {
  /// No response is currently being generated.
  idle,

  /// The host is generating a response identified by `responseId`.
  responding,
}

/// An immutable message snapshot with stable identity inside a conversation.
///
/// Update [text] under the same [id] as a response arrives. The package does
/// not generate messages or infer completion from text. [title], [subtitle],
/// and [detailLabel] describe optional source/context/timing metadata.
final class BeautifulChatMessage {
  /// Creates one user, assistant, or system message.
  const BeautifulChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.title,
    this.subtitle,
    this.detailLabel,
    this.isResolving = false,
  }) : assert(id != '');

  /// Stable, non-empty identity, unique within the conversation snapshot.
  final String id;

  /// Author role, also used for alignment and accessible attribution.
  final BeautifulChatRole role;

  /// Current plain-text body, including partially received text.
  final String text;

  /// Optional source or section heading.
  final String? title;

  /// Optional secondary context beside the heading.
  final String? subtitle;

  /// Optional host-formatted timing or other detail.
  final String? detailLabel;

  /// Whether this message is still being resolved by the host.
  final bool isResolving;
}

/// A host-owned context tab displayed above a [BeautifulChat].
final class BeautifulChatTab {
  /// Creates a tab with stable identity and a localized label.
  const BeautifulChatTab({required this.id, required this.label})
    : assert(id != ''),
      assert(label != '');

  /// Stable identity, unique in the tab snapshot.
  final String id;

  /// Visible and accessible text.
  final String label;
}

/// A conversation panel with host-owned messages and an editable composer.
///
/// The host owns message transport, response state, context selection, and
/// visible errors. This widget owns draft input, focus, pending action
/// feedback, and scroll position. It never invents replies or runs timers.
///
/// [conversationId] identifies that ownership boundary. Replacing it resets
/// the draft to [initialDraft], follows the new transcript, and ignores old
/// send/stop completions. Ordinary message updates and resizing preserve the
/// draft, focus, and the reader's scroll position. New messages follow the
/// bottom only while the reader is already there; otherwise a latest action
/// remains available.
///
/// Enter sends, Shift+Enter inserts a newline, and active IME composition
/// never submits. The software keyboard uses its multiline action. A send
/// receives trimmed text and is de-duplicated until its callback completes.
/// Successful completion clears only the exact, unedited submitted draft;
/// users can prepare their next draft while a send is pending. Failures are
/// normalized through `BeautifulUiScope.onFailure`; [errorText] remains
/// host-owned localized presentation.
///
/// Example:
/// ```dart
/// BeautifulChat(
///   conversationId: 'summer-planning',
///   messages: messages,
///   onSend: (text) => conversation.send(text),
/// )
/// ```
final class BeautifulChat extends StatefulWidget {
  /// Creates a conversation panel.
  ///
  /// [height] is a preferred height capped by parent constraints and the
  /// available viewport above the software keyboard. Very short viewports
  /// allow the whole panel to scroll so composer controls remain reachable.
  /// [selectedTabId] and [onTabChanged] follow a controlled convention: a tap
  /// reports identity, and selection changes when the host supplies a new ID.
  /// While responding, [responseId] must identify that specific generation.
  const BeautifulChat({
    super.key,
    required this.conversationId,
    required this.messages,
    this.onSend,
    this.status = BeautifulChatStatus.idle,
    this.responseId,
    this.onStop,
    this.errorText,
    this.tabs = const <BeautifulChatTab>[],
    this.selectedTabId,
    this.onTabChanged,
    this.initialDraft = '',
    this.placeholder = 'Write a message…',
    this.composerLabel = 'Chat prompt',
    this.sendLabel = 'Send',
    this.sendingLabel = 'Sending…',
    this.stopLabel = 'Stop response',
    this.stoppingLabel = 'Stopping…',
    this.respondingLabel = 'Responding…',
    this.emptyLabel = 'Start a conversation',
    this.latestLabel = 'Scroll to latest',
    this.userLabel = 'You',
    this.assistantLabel = 'Assistant',
    this.systemLabel = 'System',
    this.resolvingLabel = 'In progress',
    this.height = 420,
    this.autofocus = false,
  }) : assert(conversationId != ''),
       assert(height > 0 && height < double.infinity),
       assert(
         status != BeautifulChatStatus.responding ||
             (responseId != null && responseId != ''),
       ),
       assert(composerLabel != ''),
       assert(sendLabel != ''),
       assert(sendingLabel != ''),
       assert(stopLabel != ''),
       assert(stoppingLabel != ''),
       assert(respondingLabel != ''),
       assert(emptyLabel != ''),
       assert(latestLabel != ''),
       assert(userLabel != ''),
       assert(assistantLabel != ''),
       assert(systemLabel != ''),
       assert(resolvingLabel != '');

  /// Stable identity; change it when replacing the conversation.
  final String conversationId;

  /// Immutable, ordered message snapshot with unique IDs.
  final List<BeautifulChatMessage> messages;

  /// Host action for trimmed non-empty draft text; null disables sending.
  final FutureOr<void> Function(String text)? onSend;

  /// Host-owned response progress.
  final BeautifulChatStatus status;

  /// Identity of the active generation, required while responding.
  final String? responseId;

  /// Optional host action to stop the supplied response identity.
  final FutureOr<void> Function(String responseId)? onStop;

  /// Optional localized host-owned error, announced as a live status.
  final String? errorText;

  /// Optional context tabs with stable, unique IDs.
  final List<BeautifulChatTab> tabs;

  /// Selected context identity; null means none selected.
  final String? selectedTabId;

  /// Reports tab intent without changing host-owned selection.
  final ValueChanged<String>? onTabChanged;

  /// Draft read on initial creation and when [conversationId] changes.
  final String initialDraft;

  /// Localized empty-composer hint.
  final String placeholder;

  /// Localized accessible composer label.
  final String composerLabel;

  /// Localized send action.
  final String sendLabel;

  /// Localized pending-send action.
  final String sendingLabel;

  /// Localized stop action.
  final String stopLabel;

  /// Localized pending-stop action.
  final String stoppingLabel;

  /// Localized host response status.
  final String respondingLabel;

  /// Localized empty-conversation guidance.
  final String emptyLabel;

  /// Localized action to reveal the most recent messages.
  final String latestLabel;

  /// Localized accessible attribution for user messages.
  final String userLabel;

  /// Localized accessible attribution for assistant messages.
  final String assistantLabel;

  /// Localized accessible attribution for system messages.
  final String systemLabel;

  /// Localized visible and accessible incomplete-message status.
  final String resolvingLabel;

  /// Preferred panel height, before viewport and parent constraint caps.
  final double height;

  /// Whether the composer initially requests focus.
  final bool autofocus;

  @override
  State<BeautifulChat> createState() => _BeautifulChatState();
}

final class _BeautifulChatState extends State<BeautifulChat> {
  late final TextEditingController _draft;
  late final FocusNode _composerFocus;
  final FocusNode _selectionFocus = FocusNode(
    debugLabel: 'BeautifulChat transcript',
  );
  final ScrollController _scroll = ScrollController();
  final GlobalKey<EditableTextState> _editableKey =
      GlobalKey<EditableTextState>();
  String _selectedTranscript = '';
  late List<BeautifulChatMessage> _messages;
  late List<BeautifulChatTab> _tabs;
  late String _lastDraft;
  var _draftRevision = 0;
  var _conversationGeneration = 0;
  var _responseGeneration = 0;
  var _sending = false;
  var _stopping = false;
  var _focused = false;
  var _followingLatest = true;
  var _followScheduled = false;
  var _adjustingScroll = false;

  bool get _isComposing =>
      _draft.value.composing.isValid && !_draft.value.composing.isCollapsed;

  bool get _canSend =>
      widget.onSend != null &&
      widget.status == BeautifulChatStatus.idle &&
      !_sending &&
      !_isComposing &&
      _draft.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _snapshot();
    _lastDraft = widget.initialDraft;
    _draft = TextEditingController(text: _lastDraft)
      ..selection = TextSelection.collapsed(offset: _lastDraft.length)
      ..addListener(_draftChanged);
    _composerFocus = FocusNode(
      debugLabel: 'BeautifulChat composer',
      onKeyEvent: _handleKey,
    )..addListener(_focusChanged);
    _scroll.addListener(_scrollChanged);
  }

  void _snapshot() {
    _messages = List<BeautifulChatMessage>.unmodifiable(widget.messages);
    _tabs = List<BeautifulChatTab>.unmodifiable(widget.tabs);
    assert(
      _messages.map((message) => message.id).toSet().length == _messages.length,
      'BeautifulChat messages must have unique IDs.',
    );
    assert(
      _tabs.map((tab) => tab.id).toSet().length == _tabs.length,
      'BeautifulChat tabs must have unique IDs.',
    );
    assert(
      widget.selectedTabId == null ||
          _tabs.any((tab) => tab.id == widget.selectedTabId),
      'BeautifulChat selectedTabId must identify an existing tab.',
    );
  }

  @override
  void didUpdateWidget(BeautifulChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    _snapshot();
    if (oldWidget.conversationId != widget.conversationId) {
      _conversationGeneration++;
      _sending = false;
      _followingLatest = true;
      _draft.value = TextEditingValue(
        text: widget.initialDraft,
        selection: TextSelection.collapsed(offset: widget.initialDraft.length),
      );
    }
    if (oldWidget.conversationId != widget.conversationId ||
        oldWidget.responseId != widget.responseId ||
        oldWidget.status != widget.status) {
      _responseGeneration++;
      _stopping = false;
    }
  }

  @override
  void dispose() {
    _draft
      ..removeListener(_draftChanged)
      ..dispose();
    _composerFocus
      ..removeListener(_focusChanged)
      ..dispose();
    _selectionFocus.dispose();
    _scroll
      ..removeListener(_scrollChanged)
      ..dispose();
    super.dispose();
  }

  void _draftChanged() {
    if (_lastDraft != _draft.text) {
      _lastDraft = _draft.text;
      _draftRevision++;
    }
    if (mounted) setState(() {});
  }

  void _focusChanged() {
    if (mounted) setState(() => _focused = _composerFocus.hasFocus);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter ||
        HardwareKeyboard.instance.isShiftPressed ||
        _isComposing) {
      return KeyEventResult.ignored;
    }
    unawaited(_send());
    return KeyEventResult.handled;
  }

  void _setDraft(String text) {
    _draft.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final callback = widget.onSend!;
    final generation = _conversationGeneration;
    final revision = _draftRevision;
    final draftText = _draft.text;
    setState(() => _sending = true);
    try {
      await callback(draftText.trim());
    } catch (error, stackTrace) {
      if (!mounted || generation != _conversationGeneration) return;
      setState(() => _sending = false);
      _reportFailure('Chat send failed.', error, stackTrace);
      return;
    }
    if (!mounted || generation != _conversationGeneration) return;
    setState(() => _sending = false);
    if (revision == _draftRevision && _draft.text == draftText) {
      _setDraft('');
    }
  }

  Future<void> _stop() async {
    if (_stopping ||
        widget.status != BeautifulChatStatus.responding ||
        widget.onStop == null) {
      return;
    }
    final generation = _responseGeneration;
    final responseId = widget.responseId!;
    setState(() => _stopping = true);
    try {
      await widget.onStop!(responseId);
    } catch (error, stackTrace) {
      if (!mounted || generation != _responseGeneration) return;
      setState(() => _stopping = false);
      _reportFailure(
        'Chat stop failed for response "$responseId".',
        error,
        stackTrace,
      );
      return;
    }
    if (!mounted || generation != _responseGeneration) return;
    setState(() => _stopping = false);
  }

  void _reportFailure(String message, Object error, StackTrace stackTrace) {
    BeautifulUiEnvironment.of(context).reportFailure(
      BeautifulUiFailure(
        operation: BeautifulUiOperation.chat,
        message: message,
        cause: error,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<void> _copyTranscript(String text) async {
    if (text.isEmpty) return;
    final generation = _conversationGeneration;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (error, stackTrace) {
      if (!mounted || generation != _conversationGeneration) return;
      BeautifulUiEnvironment.of(context).reportFailure(
        BeautifulUiFailure(
          operation: BeautifulUiOperation.clipboard,
          message: 'Chat transcript selection copy failed.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void _scrollChanged() {
    if (_adjustingScroll || !_scroll.hasClients || !mounted) return;
    final follow = _scroll.position.extentAfter <= 32;
    if (follow != _followingLatest) {
      setState(() => _followingLatest = follow);
    }
  }

  void _scheduleFollow() {
    if (!_followingLatest || _followScheduled) return;
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      if (!mounted || !_followingLatest || !_scroll.hasClients) return;
      _adjustingScroll = true;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      _adjustingScroll = false;
    });
  }

  void _latest() {
    setState(() => _followingLatest = true);
    _scheduleFollow();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    _scheduleFollow();
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final viewportHeight = math.max(
          0.0,
          media.size.height - media.viewInsets.bottom,
        );
        final availableHeight = math.min(
          widget.height,
          math.min(constraints.maxHeight, viewportHeight),
        );
        final width = math.min(
          540.0,
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : media.size.width,
        );
        return SizedBox(
          key: const ValueKey<String>('beautiful-chat-surface'),
          width: width,
          height: availableHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border.all(color: theme.colors.line),
              borderRadius: BorderRadius.circular(theme.radii.card),
              boxShadow: theme.shadows.card,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.radii.card),
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final contentHeight = math.max(
                      innerConstraints.maxHeight,
                      210 + media.textScaler.scale(52),
                    );
                    return FocusTraversalGroup(
                      // Keep this path stable when the keyboard or text scale
                      // changes. Reparenting the composer would lose its focus
                      // and the transcript's attached scroll position.
                      child: SingleChildScrollView(
                        key: const ValueKey<String>('beautiful-chat-viewport'),
                        reverse: true,
                        child: SizedBox(
                          height: contentHeight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (_tabs.isNotEmpty) _header(theme),
                              Expanded(child: _transcript(theme)),
                              _composer(theme),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BeautifulUiThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colors.line)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.xs),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final tab in _tabs)
                Padding(
                  padding: EdgeInsetsDirectional.only(end: theme.spacing.xs),
                  child: BeautifulActionControl(
                    key: ValueKey<String>('beautiful-chat-tab-${tab.id}'),
                    label: tab.label,
                    selected: widget.selectedTabId == tab.id,
                    minHeight: 48,
                    tone: widget.selectedTabId == tab.id
                        ? BeautifulActionTone.secondary
                        : BeautifulActionTone.quiet,
                    onPressed: widget.onTabChanged == null
                        ? null
                        : () => widget.onTabChanged!(tab.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transcript(BeautifulUiThemeData theme) {
    final messages = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_messages.isEmpty)
          Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Text(
              widget.emptyLabel,
              style: theme.typography.body.copyWith(
                color: theme.colors.inkMuted,
              ),
            ),
          ),
        for (final message in _messages) _message(message, theme),
        if (widget.status == BeautifulChatStatus.responding)
          _status(widget.respondingLabel, theme),
        if (widget.errorText case final error?)
          _status(error, theme, isError: true),
      ],
    );
    final selectable = Overlay.maybeOf(context) == null
        ? messages
        : SelectableRegion(
            focusNode: _selectionFocus,
            selectionControls: BeautifulTextSelectionControls(
              theme.colors.accent,
            ),
            onSelectionChanged: (content) =>
                _selectedTranscript = content?.plainText ?? '',
            contextMenuBuilder: (context, selection) =>
                beautifulTextSelectionToolbar(
                  selection.context,
                  anchors: selection.contextMenuAnchors,
                  buttons: <ContextMenuButtonItem>[
                    ContextMenuButtonItem(
                      type: ContextMenuButtonType.copy,
                      label: WidgetsLocalizations.of(selection.context)
                          .copyButtonLabel,
                      onPressed: _selectedTranscript.isEmpty
                          ? null
                          : () {
                              unawaited(_copyTranscript(_selectedTranscript));
                              selection.hideToolbar();
                            },
                    ),
                  ],
                ),
            child: messages,
          );
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _scheduleFollow();
              return false;
            },
            child: RawScrollbar(
              controller: _scroll,
              thumbVisibility: true,
              thumbColor: theme.colors.lineStrong,
              radius: const Radius.circular(3),
              child: SingleChildScrollView(
                key: const ValueKey<String>('beautiful-chat-transcript'),
                controller: _scroll,
                padding: EdgeInsets.all(theme.spacing.md),
                child: selectable,
              ),
            ),
          ),
        ),
        if (!_followingLatest)
          PositionedDirectional(
            end: theme.spacing.md,
            bottom: theme.spacing.xs,
            child: BeautifulActionControl(
              key: const ValueKey<String>('beautiful-chat-latest'),
              label: widget.latestLabel,
              minHeight: 48,
              onPressed: _latest,
            ),
          ),
      ],
    );
  }

  Widget _message(BeautifulChatMessage message, BeautifulUiThemeData theme) {
    final isUser = message.role == BeautifulChatRole.user;
    final role = switch (message.role) {
      BeautifulChatRole.user => widget.userLabel,
      BeautifulChatRole.assistant => widget.assistantLabel,
      BeautifulChatRole.system => widget.systemLabel,
    };
    return Padding(
      key: ValueKey<String>('beautiful-chat-message-${message.id}'),
      padding: EdgeInsetsDirectional.only(
        start: isUser ? theme.spacing.xl : 0,
        bottom: theme.spacing.md,
      ),
      child: Align(
        alignment: isUser
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Semantics(
          container: true,
          label: role,
          child: Container(
            padding: isUser
                ? EdgeInsets.all(theme.spacing.md)
                : EdgeInsets.zero,
            decoration: isUser
                ? BoxDecoration(
                    color: theme.colors.field,
                    borderRadius: BorderRadius.circular(theme.radii.control),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (message.title != null ||
                    message.subtitle != null ||
                    message.detailLabel != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: theme.spacing.xs),
                    child: Wrap(
                      spacing: theme.spacing.xs,
                      runSpacing: theme.spacing.xs,
                      children: <Widget>[
                        if (message.title case final title?)
                          Text(title, style: theme.typography.label),
                        if (message.subtitle case final subtitle?)
                          Text(
                            subtitle,
                            style: theme.typography.caption.copyWith(
                              color: theme.colors.inkMuted,
                            ),
                          ),
                        if (message.detailLabel case final detail?)
                          Text(detail, style: theme.typography.caption),
                      ],
                    ),
                  ),
                Text(message.text, style: theme.typography.body),
                if (message.isResolving)
                  Padding(
                    padding: EdgeInsets.only(top: theme.spacing.xs),
                    child: Text(
                      widget.resolvingLabel,
                      style: theme.typography.caption.copyWith(
                        color: theme.colors.inkMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(
    String label,
    BeautifulUiThemeData theme, {
    bool isError = false,
  }) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: theme.spacing.sm),
        child: Text(
          label,
          style: theme.typography.caption.copyWith(
            color: isError ? theme.colors.destructive : theme.colors.inkMuted,
          ),
        ),
      ),
    );
  }

  Widget _composer(BeautifulUiThemeData theme) {
    final responding = widget.status == BeautifulChatStatus.responding;
    return Padding(
      padding: EdgeInsets.all(theme.spacing.sm),
      child: Container(
        padding: EdgeInsets.all(theme.spacing.sm),
        decoration: BoxDecoration(
          color: theme.colors.field,
          border: Border.all(
            color: _focused ? theme.colors.accent : theme.colors.lineStrong,
            width: _focused ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(theme.radii.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MergeSemantics(
              child: Semantics(
                label: widget.composerLabel,
                value: _draft.text,
                textField: true,
                enabled: true,
                readOnly: false,
                focusable: true,
                focused: _focused,
                onTap: _composerFocus.requestFocus,
                onFocus: _composerFocus.requestFocus,
                onSetText: _setDraft,
                child: BeautifulTextSelectionGestureDetector(
                  editableTextKey: _editableKey,
                  identity: widget.conversationId,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Stack(
                        alignment: AlignmentDirectional.topStart,
                        children: <Widget>[
                          if (_draft.text.isEmpty)
                            ExcludeSemantics(
                              child: Text(
                                widget.placeholder,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.body.copyWith(
                                  color: theme.colors.inkMuted,
                                ),
                              ),
                            ),
                          KeyedSubtree(
                            key: const ValueKey<String>(
                              'beautiful-chat-composer',
                            ),
                            child: EditableText(
                              key: _editableKey,
                              controller: _draft,
                              focusNode: _composerFocus,
                              style: theme.typography.body.copyWith(
                                color: theme.colors.ink,
                              ),
                              cursorColor: theme.colors.accent,
                              backgroundCursorColor: theme.colors.inkSubtle,
                              selectionColor: theme.colors.accentTint,
                              minLines: 1,
                              maxLines: 3,
                              autofocus: widget.autofocus,
                              textDirection: Directionality.of(context),
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              onSubmitted: (_) => unawaited(_send()),
                              rendererIgnoresPointer: true,
                              showSelectionHandles:
                                  Overlay.maybeOf(context) != null,
                              selectionControls:
                                  Overlay.maybeOf(context) == null
                                  ? null
                                  : BeautifulTextSelectionControls(
                                      theme.colors.accent,
                                    ),
                              contextMenuBuilder:
                                  Overlay.maybeOf(context) == null
                                  ? null
                                  : (context, editable) {
                                      final generation =
                                          _conversationGeneration;
                                      return beautifulEditableTextContextMenu(
                                        editable.context,
                                        editable,
                                        isCurrent: () =>
                                            mounted &&
                                            generation ==
                                                _conversationGeneration,
                                      );
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: BeautifulActionControl(
                key: ValueKey<String>(
                  responding ? 'beautiful-chat-stop' : 'beautiful-chat-send',
                ),
                label: responding
                    ? (_stopping ? widget.stoppingLabel : widget.stopLabel)
                    : (_sending ? widget.sendingLabel : widget.sendLabel),
                minHeight: 48,
                fullWidth: true,
                tone: responding
                    ? BeautifulActionTone.secondary
                    : BeautifulActionTone.primary,
                onPressed: responding
                    ? (!_stopping && widget.onStop != null
                          ? () => unawaited(_stop())
                          : null)
                    : (_canSend ? () => unawaited(_send()) : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
