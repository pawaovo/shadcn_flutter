import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/failure.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';
import '../implementation/controls/text_selection.dart';

/// The outer shape of a [BeautifulPromptBar].
enum BeautifulPromptBarVariant {
  /// A softly rounded composer card.
  rounded,

  /// A pill when inline, with generous corners when expanded.
  pill,
}

/// An attachment selected by the host's file picker.
///
/// This package keeps only identity and presentation. File contents, upload
/// progress, authorization, and removal from remote storage belong to the host.
final class BeautifulPromptAttachment {
  /// Creates an attachment with a stable identity and localized filename.
  const BeautifulPromptAttachment({required this.id, required this.label})
    : assert(id != ''),
      assert(label != '');

  /// Stable attachment identity, unique within a draft.
  final String id;

  /// Complete visible and accessible filename or description.
  final String label;
}

/// A source available through the composer's `@` menu.
final class BeautifulPromptSource {
  /// Creates a source. Connection state is supplied by the host.
  const BeautifulPromptSource({
    required this.id,
    required this.label,
    this.description = '',
    this.connected = true,
  }) : assert(id != ''),
       assert(label != '');

  /// Stable source identity, unique within the supplied snapshot.
  final String id;

  /// Display name, inserted as `@label ` when chosen.
  final String label;

  /// Localized supporting explanation.
  final String description;

  /// Whether the host has connected this source. A connection callback alone
  /// never changes this value; the host must provide an updated snapshot.
  final bool connected;
}

/// A command inserted by the composer's `/` menu.
final class BeautifulPromptCommand {
  /// Creates a command. The label may include or omit its leading slash.
  const BeautifulPromptCommand({
    required this.id,
    required this.label,
    this.description = '',
  }) : assert(id != ''),
       assert(label != '');

  /// Stable command identity, unique within the supplied snapshot.
  final String id;

  /// Localized command name, inserted with one leading `/` and a trailing space.
  final String label;

  /// Localized supporting explanation.
  final String description;
}

/// A host-owned model option, without a built-in model service.
final class BeautifulPromptModel {
  /// Creates a model with a localized label and optional descriptive tag.
  const BeautifulPromptModel({
    required this.id,
    required this.label,
    this.description = '',
  }) : assert(id != ''),
       assert(label != '');

  /// Stable model identity, unique within the supplied snapshot.
  final String id;

  /// Complete visible and accessible model name.
  final String label;

  /// Optional localized explanation or tier.
  final String description;
}

/// An immutable draft submitted to the host by [BeautifulPromptBar].
final class BeautifulPromptSubmission {
  /// Creates a submission and copies the attachment list.
  BeautifulPromptSubmission({
    required this.text,
    required List<BeautifulPromptAttachment> attachments,
    this.modelId,
  }) : attachments = List<BeautifulPromptAttachment>.unmodifiable(attachments);

  /// Trimmed prompt text, which may be empty for an attachment-only prompt.
  final String text;

  /// The exact ordered attachments submitted with this prompt.
  final List<BeautifulPromptAttachment> attachments;

  /// The host-selected model at the moment of submission.
  final String? modelId;
}

/// An adaptive prompt composer with attachments, sources, commands, and models.
///
/// The host supplies business snapshots and real file, connection, dictation,
/// and send actions. This widget owns draft text, attachments, selection, focus,
/// menus, and pending feedback. It never opens a microphone or file service,
/// invents an AI response, or starts a demonstration timer.
///
/// [composerId] is the draft ownership boundary. [initialDraft] and
/// [initialAttachments] seed state only when this identity changes. Resizing and
/// equal-content parent updates preserve editing state. [selectedModelId] and
/// source connection values are controlled by the host.
///
/// Enter sends, Shift+Enter inserts a newline, and active IME composition never
/// selects a suggestion or submits. In an open menu, arrow keys select a row,
/// Enter/Tab choose it, and Escape dismisses it. Commands only insert text;
/// they do not execute business actions.
///
/// Successful send clears only the exact unedited draft that was submitted and
/// removes only its attachment entries. Files added later and subsequent edits
/// survive. Duplicate actions are suppressed while pending. Obsolete results
/// from another [composerId] are ignored. Errors go to `BeautifulUiScope.onFailure`;
/// localized visible errors are supplied through [errorText].
final class BeautifulPromptBar extends StatefulWidget {
  /// Creates a composer with optional host-provided integrations.
  const BeautifulPromptBar({
    super.key,
    required this.composerId,
    this.onSend,
    this.initialDraft = '',
    this.initialAttachments = const <BeautifulPromptAttachment>[],
    this.sources = const <BeautifulPromptSource>[],
    this.commands = const <BeautifulPromptCommand>[],
    this.models = const <BeautifulPromptModel>[],
    this.selectedModelId,
    this.onModelChanged,
    this.onAttach,
    this.onDictate,
    this.onStopDictation,
    this.onConnectSource,
    this.variant = BeautifulPromptBarVariant.rounded,
    this.tall = false,
    this.enabled = true,
    this.autofocus = false,
    this.errorText,
    this.placeholder = 'Write a message…',
    this.composerLabel = 'Prompt',
    this.addLabel = 'Add sources and files',
    this.attachLabel = 'Add photos and files',
    this.attachingLabel = 'Adding files…',
    this.removeLabel = 'Remove',
    this.modelsLabel = 'Choose model',
    this.sourcesLabel = 'Sources and files',
    this.commandsLabel = 'Commands',
    this.connectLabel = 'Connect',
    this.connectingLabel = 'Connecting…',
    this.dictateLabel = 'Start dictation',
    this.dictatingLabel = 'Listening…',
    this.stopDictationLabel = 'Stop dictation',
    this.stoppingDictationLabel = 'Stopping dictation…',
    this.sendLabel = 'Send',
    this.sendingLabel = 'Sending…',
    this.noMatchesLabel = 'No matching options',
  }) : assert(composerId != ''),
       assert(composerLabel != ''),
       assert(addLabel != ''),
       assert(attachLabel != ''),
       assert(attachingLabel != ''),
       assert(removeLabel != ''),
       assert(modelsLabel != ''),
       assert(sourcesLabel != ''),
       assert(commandsLabel != ''),
       assert(connectLabel != ''),
       assert(connectingLabel != ''),
       assert(dictateLabel != ''),
       assert(dictatingLabel != ''),
       assert(stopDictationLabel != ''),
       assert(stoppingDictationLabel != ''),
       assert(sendLabel != ''),
       assert(sendingLabel != ''),
       assert(noMatchesLabel != '');

  /// Stable draft ownership identity. Replacing it invalidates pending work.
  final String composerId;

  /// Real host send action. Null disables sending.
  final FutureOr<void> Function(BeautifulPromptSubmission submission)? onSend;

  /// Draft seed, read only when [composerId] changes or on first mount.
  final String initialDraft;

  /// Attachment seed, using the same lifetime as [initialDraft].
  final List<BeautifulPromptAttachment> initialAttachments;

  /// Immutable source snapshot with unique IDs.
  final List<BeautifulPromptSource> sources;

  /// Immutable command snapshot with unique IDs.
  final List<BeautifulPromptCommand> commands;

  /// Immutable model snapshot with unique IDs.
  final List<BeautifulPromptModel> models;

  /// Controlled model identity, or null when none is selected.
  final String? selectedModelId;

  /// Reports model intent. The label changes after the host updates its ID.
  final ValueChanged<String>? onModelChanged;

  /// Opens the host's picker. Empty results represent cancellation. Existing
  /// attachment IDs are ignored, and late results cannot cross [composerId].
  final FutureOr<List<BeautifulPromptAttachment>> Function()? onAttach;

  /// Requests one host-owned dictation session. Null or empty text represents
  /// cancellation. A result inserts at the original selection only if that
  /// exact editing value remains current, preserving later edits and IME.
  final FutureOr<String?> Function()? onDictate;

  /// Requests stopping the current dictation and immediately invalidates its
  /// pending transcript. Permission and recorder lifetimes remain host-owned.
  final FutureOr<void> Function()? onStopDictation;

  /// Requests connection for a source ID. Completion only releases pending
  /// feedback; the source stays disconnected until the host updates it.
  final FutureOr<void> Function(String sourceId)? onConnectSource;

  /// Rounded card or pill shape.
  final BeautifulPromptBarVariant variant;

  /// Starts with a taller editor and controls on their own row.
  final bool tall;

  /// Disables editing and action controls when false.
  final bool enabled;

  /// Whether the editor initially requests focus.
  final bool autofocus;

  /// Localized host-owned error, announced as a native live region.
  final String? errorText;

  /// Localized empty-editor hint.
  final String placeholder;

  /// Accessible editor label.
  final String composerLabel;

  /// Localized add-menu action label.
  final String addLabel;

  /// Localized file-picker action label.
  final String attachLabel;

  /// Localized pending file-picker label.
  final String attachingLabel;

  /// Prefix for an attachment removal action, followed by its complete label.
  final String removeLabel;

  /// Localized model-picker label.
  final String modelsLabel;

  /// Localized source-menu heading.
  final String sourcesLabel;

  /// Localized command-menu heading.
  final String commandsLabel;

  /// Localized disconnected-source action label.
  final String connectLabel;

  /// Localized pending source-connection label.
  final String connectingLabel;

  /// Localized start-dictation action label.
  final String dictateLabel;

  /// Localized pending dictation status.
  final String dictatingLabel;

  /// Localized stop-dictation action label.
  final String stopDictationLabel;

  /// Localized pending dictation-stop label.
  final String stoppingDictationLabel;

  /// Localized send action label.
  final String sendLabel;

  /// Localized pending send label.
  final String sendingLabel;

  /// Localized empty-menu status.
  final String noMatchesLabel;

  @override
  State<BeautifulPromptBar> createState() => _BeautifulPromptBarState();
}

enum _PromptMenu { sources, commands, models }

enum _PromptOptionKind { attach, source, command, model }

final class _PromptToken {
  const _PromptToken(this.menu, this.query, this.start, this.end);
  final _PromptMenu menu;
  final String query;
  final int start;
  final int end;
}

final class _PromptOption {
  const _PromptOption(this.kind, this.id, this.label, this.description);
  final _PromptOptionKind kind;
  final String id;
  final String label;
  final String description;
}

// An entry's identity distinguishes a submitted file from a remove/re-add of
// the same host file while that send is pending.
final class _PromptAttachmentEntry {
  _PromptAttachmentEntry(this.attachment);
  final BeautifulPromptAttachment attachment;
}

final class _BeautifulPromptBarState extends State<BeautifulPromptBar> {
  late final TextEditingController _draft;
  late final FocusNode _editorFocus;
  final GlobalKey<EditableTextState> _editableKey =
      GlobalKey<EditableTextState>();
  final ScrollController _menuScroll = ScrollController();
  final ScrollController _bodyScroll = ScrollController();
  final Object _tapGroup = Object();
  late List<BeautifulPromptSource> _sources;
  late Map<String, BeautifulPromptSource> _sourcesById;
  late List<BeautifulPromptCommand> _commands;
  late List<BeautifulPromptModel> _models;
  late List<_PromptAttachmentEntry> _attachments;
  late String _lastDraft;
  var _generation = 0;
  var _draftRevision = 0;
  var _dictationEpoch = 0;
  var _sending = false;
  var _attaching = false;
  var _dictating = false;
  var _stoppingDictation = false;
  var _dismissed = false;
  var _focused = false;
  var _active = 0;
  _PromptMenu? _explicitMenu;
  final Map<String, Object> _connections = <String, Object>{};
  List<double> _rowExtents = <double>[];
  Object? _optionMeasurementInputs;
  // Retain warm measurements across filtering and menu dismissal, without
  // retaining an unbounded history of caller-edited labels.
  final Map<String, double> _optionMeasurements = <String, double>{};
  static const _optionMeasurementLimit = 4096;

  bool get _isComposing =>
      _draft.value.composing.isValid && !_draft.value.composing.isCollapsed;

  bool get _canSend =>
      widget.enabled &&
      widget.onSend != null &&
      !_sending &&
      !_isComposing &&
      (_draft.text.trim().isNotEmpty || _attachments.isNotEmpty);

  _PromptToken? get _token {
    if (_isComposing || !widget.enabled) return null;
    final value = _draft.value;
    if (!value.selection.isValid || !value.selection.isCollapsed) return null;
    final end = value.selection.extentOffset;
    final match = RegExp(r'(^|\s)([@/])([^\s@/]*)$')
        .firstMatch(value.text.substring(0, end));
    if (match == null) return null;
    return _PromptToken(
      match.group(2) == '@' ? _PromptMenu.sources : _PromptMenu.commands,
      match.group(3)!.toLowerCase(),
      match.start + match.group(1)!.length,
      end,
    );
  }

  _PromptMenu? get _menu => widget.enabled
      ? (_explicitMenu ?? (_focused && !_dismissed ? _token?.menu : null))
      : null;

  @override
  void initState() {
    super.initState();
    _snapshot();
    _seedAttachments();
    _lastDraft = widget.initialDraft;
    _draft = TextEditingController(text: _lastDraft)
      ..selection = TextSelection.collapsed(offset: _lastDraft.length)
      ..addListener(_draftChanged);
    _editorFocus = FocusNode(
      debugLabel: 'BeautifulPromptBar editor',
      onKeyEvent: _handleKey,
    )..addListener(_focusChanged);
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  void _snapshot() {
    _sources = List<BeautifulPromptSource>.unmodifiable(widget.sources);
    _sourcesById = <String, BeautifulPromptSource>{
      for (final source in _sources) source.id: source,
    };
    _commands = List<BeautifulPromptCommand>.unmodifiable(widget.commands);
    _models = List<BeautifulPromptModel>.unmodifiable(widget.models);
    assert(_unique(_sources.map((item) => item.id)), 'Duplicate source IDs.');
    assert(_unique(_commands.map((item) => item.id)), 'Duplicate command IDs.');
    assert(_unique(_models.map((item) => item.id)), 'Duplicate model IDs.');
    assert(
      widget.selectedModelId == null ||
          _models.any((model) => model.id == widget.selectedModelId),
      'selectedModelId must identify an existing model.',
    );
    _connections.removeWhere((id, _) => _sourcesById[id]?.connected ?? true);
  }

  static bool _unique(Iterable<String> ids) {
    final list = ids.toList();
    return list.toSet().length == list.length;
  }

  void _seedAttachments() {
    assert(
      _unique(widget.initialAttachments.map((item) => item.id)),
      'Duplicate initial attachment IDs.',
    );
    _attachments = widget.initialAttachments
        .map(_PromptAttachmentEntry.new)
        .toList();
  }

  @override
  void didUpdateWidget(BeautifulPromptBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _snapshot();
    if (oldWidget.composerId != widget.composerId) {
      _generation++;
      _dictationEpoch++;
      _sending = _attaching = _dictating = _stoppingDictation = false;
      _connections.clear();
      _explicitMenu = null;
      _dismissed = false;
      _active = 0;
      _seedAttachments();
      _setDraft(widget.initialDraft);
    }
    if (!widget.enabled) _explicitMenu = null;
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _draft
      ..removeListener(_draftChanged)
      ..dispose();
    _editorFocus
      ..removeListener(_focusChanged)
      ..dispose();
    _menuScroll.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  void _fontsChanged() {
    // The family name can stay unchanged while FontLoader installs different
    // metrics. Rebuild open menus as well as invalidating future reopenings.
    if (!mounted) return;
    setState(_optionMeasurements.clear);
    if (_menu != null) _revealActive();
  }

  void _draftChanged() {
    if (_lastDraft != _draft.text) {
      _lastDraft = _draft.text;
      _draftRevision++;
      _dismissed = false;
      _explicitMenu = null;
      _active = 0;
    }
    if (mounted) setState(() {});
  }

  void _focusChanged() {
    if (mounted) setState(() => _focused = _editorFocus.hasFocus);
  }

  void _setDraft(String text, {int? caret}) {
    _draft.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret ?? text.length),
    );
  }

  void _closeMenus() {
    setState(() {
      _explicitMenu = null;
      _dismissed = true;
    });
  }

  List<_PromptOption> _options() {
    final menu = _menu;
    final query = _explicitMenu != null ? '' : (_token?.query ?? '');
    return switch (menu) {
      _PromptMenu.sources => <_PromptOption>[
        if (widget.onAttach != null &&
            widget.attachLabel.toLowerCase().contains(query))
          _PromptOption(
            _PromptOptionKind.attach,
            'attach',
            widget.attachLabel,
            '',
          ),
        for (final source in _sources)
          if (source.label.toLowerCase().contains(query))
            _PromptOption(
              _PromptOptionKind.source,
              source.id,
              source.label,
              source.description,
            ),
      ],
      _PromptMenu.commands => <_PromptOption>[
        for (final command in _commands)
          if (_commandText(command.label)
              .substring(1)
              .toLowerCase()
              .startsWith(query))
            _PromptOption(
              _PromptOptionKind.command,
              command.id,
              _commandText(command.label),
              command.description,
            ),
      ],
      _PromptMenu.models => <_PromptOption>[
        for (final model in _models)
          _PromptOption(
            _PromptOptionKind.model,
            model.id,
            model.label,
            model.description,
          ),
      ],
      null => const <_PromptOption>[],
    };
  }

  static String _commandText(String label) =>
      label.startsWith('/') ? label : '/$label';

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _isComposing || !widget.enabled) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && _menu != null) {
      _closeMenus();
      _editorFocus.requestFocus();
      return KeyEventResult.handled;
    }
    final options = _options();
    if (_menu != null && options.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _active =
              (_active + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
              options.length;
        });
        _revealActive();
        return KeyEventResult.handled;
      }
      if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.tab) &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _pick(options[_active.clamp(0, options.length - 1)]);
        return KeyEventResult.handled;
      }
    }
    if (node == _editorFocus &&
        key == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      unawaited(_send());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _revealActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_menuScroll.hasClients ||
          _active >= _rowExtents.length) {
        return;
      }
      final top = _rowExtents.take(_active).fold<double>(0, (a, b) => a + b);
      final bottom = top + _rowExtents[_active];
      final position = _menuScroll.position;
      final target = top < position.pixels
          ? top
          : bottom > position.pixels + position.viewportDimension
          ? bottom - position.viewportDimension
          : position.pixels;
      // Lazy slivers estimate maxScrollExtent from realized rows. A wrapped
      // label near the end can be taller than those initial rows, so use the
      // complete measured extent when revealing an arbitrary keyboard target.
      final total = _rowExtents.fold<double>(0, (a, b) => a + b);
      _menuScroll.jumpTo(
        target.clamp(0, math.max(0, total - position.viewportDimension)),
      );
    });
  }

  void _pick(_PromptOption option) {
    if (!widget.enabled || _isComposing) return;
    switch (option.kind) {
      case _PromptOptionKind.attach:
        unawaited(_attach());
        return;
      case _PromptOptionKind.model:
        if (widget.onModelChanged == null) return;
        try {
          widget.onModelChanged!(option.id);
        } catch (error, stack) {
          _reportFailure('Prompt model selection failed.', error, stack);
        }
        _closeMenus();
        _editorFocus.requestFocus();
        return;
      case _PromptOptionKind.source:
        final source = _sources
            .where((source) => source.id == option.id)
            .firstOrNull;
        if (source == null) return;
        if (!source.connected) {
          unawaited(_connect(source.id));
          return;
        }
      case _PromptOptionKind.command:
        break;
    }
    final token = _token;
    final value = _draft.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final start = token?.start ?? selection.start;
    final end = token?.end ?? selection.end;
    final insert =
        '${option.kind == _PromptOptionKind.source ? '@' : ''}${option.label} ';
    _setDraft(
      value.text.replaceRange(start, end, insert),
      caret: start + insert.length,
    );
    _closeMenus();
    _editorFocus.requestFocus();
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final generation = _generation;
    final revision = _draftRevision;
    final draft = _draft.text;
    final submitted = _attachments.toList();
    final request = BeautifulPromptSubmission(
      text: draft.trim(),
      attachments: submitted.map((entry) => entry.attachment).toList(),
      modelId: widget.selectedModelId,
    );
    setState(() => _sending = true);
    try {
      await widget.onSend!(request);
    } catch (error, stack) {
      if (!_current(generation)) return;
      setState(() => _sending = false);
      _reportFailure('Prompt send failed.', error, stack);
      return;
    }
    if (!_current(generation)) return;
    setState(() {
      _sending = false;
      _attachments.removeWhere(submitted.contains);
      if (revision == _draftRevision && _draft.text == draft && !_isComposing) {
        _setDraft('');
        _explicitMenu = null;
      }
    });
  }

  Future<void> _attach() async {
    if (!widget.enabled || _attaching || widget.onAttach == null) return;
    final generation = _generation;
    final before = _draft.value;
    final token = _token;
    setState(() => _attaching = true);
    try {
      final picked = await widget.onAttach!();
      if (!_current(generation)) return;
      setState(() {
        _attaching = false;
        final knownIds = _attachments
            .map((entry) => entry.attachment.id)
            .toSet();
        for (final attachment in picked) {
          if (knownIds.add(attachment.id)) {
            _attachments.add(_PromptAttachmentEntry(attachment));
          }
        }
        if (picked.isNotEmpty && token != null && _draft.value == before) {
          _setDraft(
            before.text.replaceRange(token.start, token.end, ''),
            caret: token.start,
          );
        }
        _explicitMenu = null;
        _dismissed = true;
      });
      _editorFocus.requestFocus();
    } catch (error, stack) {
      if (!_current(generation)) return;
      setState(() => _attaching = false);
      _reportFailure('Prompt attachment selection failed.', error, stack);
    }
  }

  Future<void> _dictate() async {
    if (!widget.enabled ||
        _dictating ||
        _stoppingDictation ||
        _isComposing ||
        widget.onDictate == null) {
      return;
    }
    final generation = _generation;
    final epoch = ++_dictationEpoch;
    final before = _draft.value;
    final revision = _draftRevision;
    setState(() => _dictating = true);
    try {
      final transcript = await widget.onDictate!();
      if (!_current(generation) || epoch != _dictationEpoch) return;
      setState(() => _dictating = false);
      if (transcript == null ||
          transcript.isEmpty ||
          revision != _draftRevision ||
          _draft.value != before ||
          _isComposing) {
        return;
      }
      final selection = before.selection.isValid
          ? before.selection
          : TextSelection.collapsed(offset: before.text.length);
      final prefix = before.text.substring(0, selection.start);
      final spacer = prefix.isNotEmpty && !RegExp(r'\s$').hasMatch(prefix)
          ? ' '
          : '';
      final insertion = '$spacer$transcript';
      _setDraft(
        before.text.replaceRange(selection.start, selection.end, insertion),
        caret: selection.start + insertion.length,
      );
      _editorFocus.requestFocus();
    } catch (error, stack) {
      if (!_current(generation) || epoch != _dictationEpoch) return;
      setState(() => _dictating = false);
      _reportFailure('Prompt dictation failed.', error, stack);
    }
  }

  Future<void> _stopDictation() async {
    if (!widget.enabled ||
        !_dictating ||
        _stoppingDictation ||
        widget.onStopDictation == null) {
      return;
    }
    final generation = _generation;
    setState(() {
      _dictationEpoch++;
      _stoppingDictation = true;
    });
    try {
      await widget.onStopDictation!();
      if (!_current(generation)) return;
      setState(() {
        _dictating = false;
        _stoppingDictation = false;
      });
    } catch (error, stack) {
      if (!_current(generation)) return;
      setState(() => _stoppingDictation = false);
      _reportFailure('Prompt dictation stop failed.', error, stack);
    }
  }

  Future<void> _connect(String id) async {
    if (!widget.enabled ||
        _connections.containsKey(id) ||
        widget.onConnectSource == null) {
      return;
    }
    final generation = _generation;
    final ticket = Object();
    setState(() => _connections[id] = ticket);
    try {
      await widget.onConnectSource!(id);
      if (!_current(generation) || _connections[id] != ticket) return;
      setState(() => _connections.remove(id));
    } catch (error, stack) {
      if (!_current(generation) || _connections[id] != ticket) return;
      setState(() => _connections.remove(id));
      _reportFailure('Prompt source connection failed.', error, stack);
    }
  }

  bool _current(int generation) => mounted && generation == _generation;

  void _reportFailure(String message, Object error, StackTrace stack) {
    BeautifulUiEnvironment.of(context).reportFailure(
      BeautifulUiFailure(
        operation: BeautifulUiOperation.prompt,
        message: message,
        cause: error,
        stackTrace: stack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : media.size.width;
        final viewport = math.max(
          48.0,
          media.size.height -
              media.viewInsets.vertical -
              media.padding.vertical,
        );
        final height = constraints.maxHeight.isFinite
            ? math.min(constraints.maxHeight, viewport)
            : viewport;
        final model = _models
            .where((model) => model.id == widget.selectedModelId)
            .firstOrNull;
        final modelLabel = model?.label ?? widget.modelsLabel;
        final labels = <String>[
          if (widget.onAttach != null || _sources.isNotEmpty) widget.addLabel,
          if (_models.isNotEmpty) modelLabel,
          if (widget.onDictate != null) _dictationLabel,
          _sending ? widget.sendingLabel : widget.sendLabel,
        ];
        final controlsWidth = labels.fold<double>(0, (sum, label) {
          final painter = TextPainter(
            text: TextSpan(
              text: label,
              style: theme.typography.label.copyWith(fontSize: 12.5),
            ),
            textDirection: Directionality.of(context),
            textScaler: media.textScaler,
          )..layout();
          final measured = math.max(
            48.0,
            painter.width + theme.spacing.md * 2 + 2,
          );
          painter.dispose();
          return sum + measured + theme.spacing.xs;
        });
        final draftPainter = TextPainter(
          text: TextSpan(
            text: _draft.text.isEmpty ? widget.placeholder : _draft.text,
            style: theme.typography.body,
          ),
          textDirection: Directionality.of(context),
          textScaler: media.textScaler,
          maxLines: 1,
        )..layout();
        final expanded =
            widget.tall ||
            width < 600 ||
            _draft.text.contains('\n') ||
            draftPainter.width + controlsWidth + 64 > width;
        draftPainter.dispose();
        final menu = _menu;
        final body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (menu != null) ...<Widget>[
              _buildMenu(theme, menu, math.min(240, viewport * .4)),
              SizedBox(height: theme.spacing.sm),
            ],
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.surface,
                border: Border.all(
                  color: _focused
                      ? theme.colors.accent
                      : theme.colors.lineStrong,
                ),
                borderRadius: BorderRadius.circular(
                  widget.variant == BeautifulPromptBarVariant.pill
                      ? (expanded || _attachments.isNotEmpty ? 24 : 999)
                      : theme.radii.card,
                ),
                boxShadow: theme.shadows.card,
              ),
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_attachments.isNotEmpty) ...<Widget>[
                      Wrap(
                        spacing: theme.spacing.xs,
                        runSpacing: theme.spacing.xs,
                        children: <Widget>[
                          for (final entry in _attachments)
                            BeautifulActionControl(
                              key: ObjectKey(entry),
                              label:
                                  '${widget.removeLabel} ${entry.attachment.label}',
                              minHeight: 48,
                              maxLines: null,
                              onPressed: widget.enabled
                                  ? () => setState(
                                      () => _attachments.remove(entry),
                                    )
                                  : null,
                            ),
                        ],
                      ),
                      SizedBox(height: theme.spacing.sm),
                    ],
                    Flex(
                      direction: expanded ? Axis.vertical : Axis.horizontal,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: expanded
                          ? CrossAxisAlignment.stretch
                          : CrossAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          flex: expanded ? 0 : 1,
                          child: _buildEditor(theme),
                        ),
                        SizedBox(
                          width: theme.spacing.sm,
                          height: theme.spacing.sm,
                        ),
                        Flexible(
                          flex: 0,
                          child: _buildControls(theme, modelLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_dictating) _status(theme, widget.dictatingLabel),
            if (widget.errorText case final error?)
              _status(theme, error, error: true),
          ],
        );
        return SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height),
            child: SafeArea(
              top: false,
              child: Focus(
                onKeyEvent: _handleKey,
                child: TapRegion(
                  groupId: _tapGroup,
                  onTapOutside: (_) {
                    if (_menu != null) _closeMenus();
                  },
                  child: SingleChildScrollView(
                    controller: _bodyScroll,
                    child: body,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String get _dictationLabel => _stoppingDictation
      ? widget.stoppingDictationLabel
      : _dictating
      ? (widget.onStopDictation != null
            ? widget.stopDictationLabel
            : widget.dictateLabel)
      : widget.dictateLabel;

  Widget _buildControls(BeautifulUiThemeData theme, String modelLabel) => Wrap(
    spacing: theme.spacing.xs,
    runSpacing: theme.spacing.xs,
    alignment: WrapAlignment.end,
    children: <Widget>[
      if (widget.onAttach != null || _sources.isNotEmpty)
        BeautifulActionControl(
          key: const ValueKey<String>('beautiful-prompt-add'),
          label: widget.addLabel,
          minHeight: 48,
          maxLines: null,
          expanded: _menu == _PromptMenu.sources,
          tone: BeautifulActionTone.quiet,
          onPressed: widget.enabled
              ? () {
                  setState(() {
                    _explicitMenu = _menu == _PromptMenu.sources
                        ? null
                        : _PromptMenu.sources;
                    _dismissed = true;
                    _active = 0;
                  });
                  _editorFocus.requestFocus();
                }
              : null,
        ),
      if (_models.isNotEmpty)
        BeautifulActionControl(
          key: const ValueKey<String>('beautiful-prompt-model'),
          label: modelLabel,
          semanticLabel: '${widget.modelsLabel}: $modelLabel',
          minHeight: 48,
          maxLines: null,
          expanded: _menu == _PromptMenu.models,
          tone: BeautifulActionTone.quiet,
          onPressed: widget.enabled && widget.onModelChanged != null
              ? () {
                  setState(() {
                    _explicitMenu = _menu == _PromptMenu.models
                        ? null
                        : _PromptMenu.models;
                    _dismissed = true;
                    _active = math.max(
                      0,
                      _models.indexWhere(
                        (model) => model.id == widget.selectedModelId,
                      ),
                    );
                  });
                  _revealActive();
                }
              : null,
        ),
      if (widget.onDictate != null)
        BeautifulActionControl(
          key: const ValueKey<String>('beautiful-prompt-dictate'),
          label: _dictationLabel,
          minHeight: 48,
          maxLines: null,
          selected: _dictating,
          tone: BeautifulActionTone.quiet,
          onPressed: !widget.enabled || _stoppingDictation || _isComposing
              ? null
              : _dictating
              ? (widget.onStopDictation == null
                    ? null
                    : () => unawaited(_stopDictation()))
              : () => unawaited(_dictate()),
        ),
      BeautifulActionControl(
        key: const ValueKey<String>('beautiful-prompt-send'),
        label: _sending ? widget.sendingLabel : widget.sendLabel,
        minHeight: 48,
        maxLines: null,
        tone: BeautifulActionTone.primary,
        onPressed: _canSend ? () => unawaited(_send()) : null,
      ),
    ],
  );

  Widget _buildEditor(BeautifulUiThemeData theme) => MergeSemantics(
    child: Semantics(
      label: widget.composerLabel,
      value: _draft.text,
      textField: true,
      enabled: widget.enabled,
      readOnly: !widget.enabled,
      focusable: widget.enabled,
      focused: _focused,
      onTap: widget.enabled ? _editorFocus.requestFocus : null,
      onFocus: widget.enabled ? _editorFocus.requestFocus : null,
      onSetText: widget.enabled ? _setDraft : null,
      child: BeautifulTextSelectionGestureDetector(
        editableTextKey: _editableKey,
        identity: widget.composerId,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.tall ? 88 : 48),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.sm,
            ),
            child: Stack(
              alignment: AlignmentDirectional.topStart,
              children: <Widget>[
                if (_draft.text.isEmpty)
                  ExcludeSemantics(
                    child: Text(
                      widget.placeholder,
                      style: theme.typography.body.copyWith(
                        color: theme.colors.inkMuted,
                      ),
                    ),
                  ),
                EditableText(
                  key: _editableKey,
                  groupId: _tapGroup,
                  controller: _draft,
                  focusNode: _editorFocus,
                  style: theme.typography.body.copyWith(
                    color: theme.colors.ink,
                  ),
                  cursorColor: theme.colors.accent,
                  backgroundCursorColor: theme.colors.inkSubtle,
                  selectionColor: theme.colors.accentTint,
                  minLines: widget.tall ? 2 : 1,
                  maxLines: 4,
                  readOnly: !widget.enabled,
                  autofocus: widget.autofocus,
                  textDirection: Directionality.of(context),
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => unawaited(_send()),
                  rendererIgnoresPointer: true,
                  showSelectionHandles: Overlay.maybeOf(context) != null,
                  selectionControls: Overlay.maybeOf(context) == null
                      ? null
                      : BeautifulTextSelectionControls(theme.colors.accent),
                  contextMenuBuilder: Overlay.maybeOf(context) == null
                      ? null
                      : (context, editable) {
                          final generation = _generation;
                          return beautifulEditableTextContextMenu(
                            editable.context,
                            editable,
                            isCurrent: () => _current(generation),
                          );
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildMenu(
    BeautifulUiThemeData theme,
    _PromptMenu menu,
    double height,
  ) {
    final options = _options();
    _active = options.isEmpty ? 0 : _active.clamp(0, options.length - 1);
    final heading = switch (menu) {
      _PromptMenu.sources => widget.sourcesLabel,
      _PromptMenu.commands => widget.commandsLabel,
      _PromptMenu.models => widget.modelsLabel,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.lineStrong),
        borderRadius: BorderRadius.circular(theme.radii.card),
        boxShadow: theme.shadows.raised,
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: Text(
                heading,
                style: theme.typography.label.copyWith(
                  color: theme.colors.inkMuted,
                ),
              ),
            ),
            if (options.isEmpty)
              Padding(
                padding: EdgeInsets.all(theme.spacing.md),
                child: Text(
                  widget.noMatchesLabel,
                  style: theme.typography.body.copyWith(
                    color: theme.colors.inkMuted,
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final labels = options.map(_optionLabel).toList();
                  _rowExtents = _measureOptions(
                    context,
                    theme,
                    labels,
                    constraints.maxWidth,
                  );
                  final total = _rowExtents.fold<double>(0, (a, b) => a + b);
                  return SizedBox(
                    height: math.min(height, total),
                    child: ListView.builder(
                      key: ValueKey<_PromptMenu>(menu),
                      controller: _menuScroll,
                      primary: false,
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemExtentBuilder: (index, _) => _rowExtents[index],
                      itemBuilder: (context, index) {
                        final option = options[index];
                        return BeautifulActionControl(
                          key: ValueKey<String>(
                            'beautiful-prompt-option-${option.kind.name}-${option.id}',
                          ),
                          label: labels[index],
                          minHeight: 48,
                          maxLines: null,
                          fullWidth: true,
                          selected: menu == _PromptMenu.models
                              ? widget.selectedModelId == option.id
                              : _active == index,
                          tone: _active == index
                              ? BeautifulActionTone.secondary
                              : BeautifulActionTone.quiet,
                          onPressed: _optionEnabled(option)
                              ? () => _pick(option)
                              : null,
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  List<double> _measureOptions(
    BuildContext context,
    BeautifulUiThemeData theme,
    List<String> labels,
    double width,
  ) {
    final defaults = DefaultTextStyle.of(context);
    var style = theme.typography.label.copyWith(fontSize: 12.5);
    if (style.inherit) style = defaults.style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    style = style.merge(
      TextStyle(
        height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
        letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
        wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
      ),
    );
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final maxWidth = defaults.softWrap
        ? math.max(1.0, width - theme.spacing.md * 2 - 2)
        : double.infinity;
    final padding = theme.spacing.sm * 2 + 2;
    final heightBehavior =
        defaults.textHeightBehavior ??
        DefaultTextHeightBehavior.maybeOf(context);
    final inputs = (
      style,
      direction,
      scaler,
      locale,
      maxWidth,
      padding,
      defaults.maxLines,
      defaults.textWidthBasis,
      heightBehavior,
    );
    if (_optionMeasurementInputs != inputs) {
      _optionMeasurementInputs = inputs;
      _optionMeasurements.clear();
    }
    TextPainter? painter;
    final extents = <double>[];
    for (final label in labels) {
      var extent = _optionMeasurements[label];
      if (extent == null) {
        painter ??= TextPainter(
          textDirection: direction,
          textScaler: scaler,
          locale: locale,
          textAlign: TextAlign.center,
          maxLines: defaults.maxLines,
          textWidthBasis: defaults.textWidthBasis,
          textHeightBehavior: heightBehavior,
        );
        painter
          ..text = TextSpan(text: label, style: style)
          ..layout(maxWidth: maxWidth);
        extent = math.max(48.0, painter.height + padding);
        if (_optionMeasurements.length >= _optionMeasurementLimit) {
          _optionMeasurements.remove(_optionMeasurements.keys.first);
        }
        _optionMeasurements[label] = extent;
      }
      extents.add(extent);
    }
    painter?.dispose();
    return extents;
  }

  String _optionLabel(_PromptOption option) {
    final lines = <String>[
      option.kind == _PromptOptionKind.attach && _attaching
          ? widget.attachingLabel
          : option.label,
      if (option.description.isNotEmpty) option.description,
    ];
    if (option.kind == _PromptOptionKind.source) {
      final source = _sourcesById[option.id]!;
      if (!source.connected) {
        lines.add(
          _connections.containsKey(source.id)
              ? widget.connectingLabel
              : widget.connectLabel,
        );
      }
    }
    return lines.join('\n');
  }

  bool _optionEnabled(_PromptOption option) {
    if (!widget.enabled || _isComposing) return false;
    return switch (option.kind) {
      _PromptOptionKind.attach => !_attaching && widget.onAttach != null,
      _PromptOptionKind.model => widget.onModelChanged != null,
      _PromptOptionKind.command => true,
      _PromptOptionKind.source =>
        !_connections.containsKey(option.id) &&
            (_sourcesById[option.id]!.connected ||
                widget.onConnectSource != null),
    };
  }

  Widget _status(
    BeautifulUiThemeData theme,
    String label, {
    bool error = false,
  }) => Padding(
    key: ValueKey<String>(
      error ? 'beautiful-prompt-error' : 'beautiful-prompt-dictation-status',
    ),
    padding: EdgeInsets.all(theme.spacing.sm),
    child: Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Text(
          label,
          style: theme.typography.body.copyWith(
            color: error ? theme.colors.destructive : theme.colors.inkMuted,
          ),
        ),
      ),
    ),
  );
}
