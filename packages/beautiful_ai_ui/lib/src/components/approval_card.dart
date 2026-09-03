import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/failure.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';
import '../implementation/controls/text_selection.dart';

/// Whether a question accepts one option or several options.
enum BeautifulApprovalQuestionType {
  /// Selecting an option replaces the previous option and any custom answer.
  singleChoice,

  /// Selected options may be combined with a custom answer.
  multipleChoice,
}

/// One immutable choice in an approval question.
@immutable
final class BeautifulApprovalOption {
  /// Creates an option with a stable, non-empty [id] and localized [label].
  const BeautifulApprovalOption({required this.id, required this.label})
    : assert(id != ''),
      assert(label != '');

  /// Stable identity within the containing question.
  final String id;

  /// Visible and spoken choice text.
  final String label;
}

/// An immutable question and its selectable options.
@immutable
final class BeautifulApprovalQuestion {
  /// Creates a question, taking a defensive copy of [options].
  ///
  /// IDs must be unique within a question. Empty options are permitted only
  /// when [allowCustomAnswer] is true. [title] and [id] must be non-empty.
  BeautifulApprovalQuestion({
    required this.id,
    required this.title,
    required List<BeautifulApprovalOption> options,
    this.type = BeautifulApprovalQuestionType.singleChoice,
    this.allowCustomAnswer = true,
  }) : assert(id != ''),
       assert(title != ''),
       assert(options.isNotEmpty || allowCustomAnswer),
       assert(_uniqueIds(options.map((option) => option.id))),
       options = List<BeautifulApprovalOption>.unmodifiable(options);

  /// Stable identity used to preserve a draft across reordered questions.
  final String id;

  /// Localized heading of the question.
  final String title;

  /// Immutable selectable options in presentation order.
  final List<BeautifulApprovalOption> options;

  /// Selection behavior for this question.
  final BeautifulApprovalQuestionType type;

  /// Whether a custom answer field is available.
  final bool allowCustomAnswer;
}

/// An immutable answer draft delivered to the host.
@immutable
final class BeautifulApprovalAnswer {
  /// Creates an answer, taking a defensive copy of [optionIds].
  ///
  /// [questionId] is required and option IDs must be unique and non-empty.
  /// [customText] retains the user's text, including surrounding whitespace.
  BeautifulApprovalAnswer({
    required this.questionId,
    List<String> optionIds = const <String>[],
    this.customText = '',
  }) : assert(questionId != ''),
       assert(optionIds.every((id) => id != '')),
       assert(_uniqueIds(optionIds)),
       optionIds = List<String>.unmodifiable(optionIds);

  /// Identity of the question this answer belongs to.
  final String questionId;

  /// Selected option identities in the question's presentation order.
  final List<String> optionIds;

  /// Custom answer text, also included in the submission snapshot.
  final String customText;

  /// Whether this draft contains an option or non-whitespace custom text.
  bool get hasAnswer => optionIds.isNotEmpty || customText.trim().isNotEmpty;
}

/// A one-question-at-a-time approval form with host-owned submission.
///
/// The card owns editable drafts, navigation, dismissal, and pending/success
/// presentation. The host owns the actual operation through [onSubmit]. A
/// successful callback shows [sentLabel]; a failed callback keeps all drafts
/// editable and reports a [BeautifulUiFailure] through the enclosing scope.
/// Supply a localized [errorMessage] to display a host error in the card.
///
/// [initialAnswers] is read on first insertion or when [id] changes. Subsequent
/// rebuilds preserve drafts by question and option ID; removed choices are
/// discarded. Changing the question model invalidates pending completions.
/// A new [id] starts a new approval. No backend, timer, or agent is bundled.
///
/// Single-choice selections automatically move to the next question and submit
/// on the final question when [autoAdvance] is true. Set it to false when every
/// answer must be confirmed explicitly. Multiple-choice and custom answers
/// always wait for Continue or Send. Next/Previous preserve drafts; Skip moves
/// to the next question, or dismisses the final question without submitting.
///
/// Custom editing uses Flutter selection handles and a localized context menu.
/// Provide an [Overlay] and [WidgetsLocalizations], normally through the host
/// application's navigator, so those native editing affordances are available.
///
/// ```dart
/// BeautifulApprovalCard(
///   id: 'launch-review',
///   questions: [
///     BeautifulApprovalQuestion(
///       id: 'market',
///       title: 'Which market should we enter?',
///       options: const [
///         BeautifulApprovalOption(id: 'shops', label: 'Scoop shops'),
///       ],
///     ),
///   ],
///   onSubmit: (answers) async {},
/// );
/// ```
final class BeautifulApprovalCard extends StatefulWidget {
  /// Creates an approval form with immutable question and initial-answer lists.
  ///
  /// [questions] must be non-empty with unique IDs. Initial answers must refer
  /// to existing questions and options and obey each question's selection type.
  /// All action and accessibility labels are localizable and non-empty.
  BeautifulApprovalCard({
    super.key,
    required this.id,
    required List<BeautifulApprovalQuestion> questions,
    required this.onSubmit,
    List<BeautifulApprovalAnswer> initialAnswers =
        const <BeautifulApprovalAnswer>[],
    this.onAnswerChanged,
    this.errorMessage,
    this.enabled = true,
    this.resettable = true,
    this.autoAdvance = true,
    this.skipLabel = 'Skip',
    this.continueLabel = 'Continue',
    this.sendLabel = 'Send',
    this.pendingLabel = 'Sending…',
    this.sentLabel = 'Answers sent',
    this.resetLabel = 'Start over',
    this.dismissLabel = 'Dismiss',
    this.openLabel = 'Open approval',
    this.previousLabel = 'Previous question',
    this.nextLabel = 'Next question',
    this.customPlaceholder = 'Something else…',
    this.customAnswerLabel = 'Custom answer',
  }) : assert(id != ''),
       assert(questions.isNotEmpty),
       assert(_uniqueIds(questions.map((question) => question.id))),
       assert(_validInitialAnswers(questions, initialAnswers)),
       assert(skipLabel != ''),
       assert(continueLabel != ''),
       assert(sendLabel != ''),
       assert(pendingLabel != ''),
       assert(sentLabel != ''),
       assert(resetLabel != ''),
       assert(dismissLabel != ''),
       assert(openLabel != ''),
       assert(previousLabel != ''),
       assert(nextLabel != ''),
       assert(customPlaceholder != ''),
       assert(customAnswerLabel != ''),
       assert(errorMessage == null || errorMessage != ''),
       questions = List<BeautifulApprovalQuestion>.unmodifiable(questions),
       initialAnswers = List<BeautifulApprovalAnswer>.unmodifiable(
         initialAnswers,
       );

  /// Stable approval identity. Changing it starts a new draft workflow.
  final String id;

  /// Immutable questions in presentation order.
  final List<BeautifulApprovalQuestion> questions;

  /// Performs host submission for all questions, including unanswered drafts.
  ///
  /// The list and every answer's option IDs are immutable. Repeated submission
  /// is ignored while pending. Completions from replaced models are ignored.
  final FutureOr<void> Function(List<BeautifulApprovalAnswer> answers) onSubmit;

  /// Draft seeds, read initially and when [id] changes, never on every rebuild.
  final List<BeautifulApprovalAnswer> initialAnswers;

  /// Observes an immutable draft after a choice, custom edit, or reset.
  ///
  /// The card remains the draft owner. Persist drafts here and use
  /// [initialAnswers] to restore them after the card is recreated.
  final ValueChanged<BeautifulApprovalAnswer>? onAnswerChanged;

  /// Host-supplied, localized submission or validation error.
  final String? errorMessage;

  /// Whether editing, navigation, and submission are enabled.
  final bool enabled;

  /// Whether a submitted approval offers the reset action.
  final bool resettable;

  /// Whether a single-choice selection immediately advances or submits.
  final bool autoAdvance;

  /// Localized skip action label.
  final String skipLabel;

  /// Localized continue action label.
  final String continueLabel;

  /// Localized final submission label.
  final String sendLabel;

  /// Localized pending submission label.
  final String pendingLabel;

  /// Localized success message.
  final String sentLabel;

  /// Localized reset action label.
  final String resetLabel;

  /// Localized dismissal label.
  final String dismissLabel;

  /// Localized action label when the card is dismissed.
  final String openLabel;

  /// Localized previous-question accessibility label.
  final String previousLabel;

  /// Localized next-question accessibility label.
  final String nextLabel;

  /// Localized placeholder for an empty custom answer field.
  final String customPlaceholder;

  /// Localized custom answer field accessibility label.
  final String customAnswerLabel;

  @override
  State<BeautifulApprovalCard> createState() => _BeautifulApprovalCardState();
}

bool _uniqueIds(Iterable<String> ids) => ids.toSet().length == ids.length;

bool _validInitialAnswers(
  List<BeautifulApprovalQuestion> questions,
  List<BeautifulApprovalAnswer> answers,
) {
  if (!_uniqueIds(answers.map((answer) => answer.questionId))) return false;
  for (final answer in answers) {
    final matching = questions.where(
      (question) => question.id == answer.questionId,
    );
    if (matching.isEmpty) return false;
    final question = matching.first;
    final options = question.options.map((option) => option.id).toSet();
    if (!options.containsAll(answer.optionIds)) return false;
    if (!question.allowCustomAnswer && answer.customText.isNotEmpty) {
      return false;
    }
    if (question.type == BeautifulApprovalQuestionType.singleChoice &&
        (answer.optionIds.length > 1 ||
            (answer.optionIds.isNotEmpty && answer.customText.isNotEmpty))) {
      return false;
    }
  }
  return true;
}

bool _sameQuestions(
  List<BeautifulApprovalQuestion> previous,
  List<BeautifulApprovalQuestion> next,
) {
  if (previous.length != next.length) return false;
  for (var index = 0; index < previous.length; index++) {
    final before = previous[index];
    final after = next[index];
    if (before.id != after.id ||
        before.title != after.title ||
        before.type != after.type ||
        before.allowCustomAnswer != after.allowCustomAnswer ||
        before.options.length != after.options.length) {
      return false;
    }
    for (var option = 0; option < before.options.length; option++) {
      if (before.options[option].id != after.options[option].id ||
          before.options[option].label != after.options[option].label) {
        return false;
      }
    }
  }
  return true;
}

final class _BeautifulApprovalCardState extends State<BeautifulApprovalCard> {
  final Map<String, BeautifulApprovalAnswer> _answers = {};
  final TextEditingController _customController = TextEditingController();
  final GlobalKey<EditableTextState> _customFieldKey =
      GlobalKey<EditableTextState>();
  final FocusNode _customFocus = FocusNode(
    debugLabel: 'Approval custom answer',
  );
  final FocusNode _headingFocus = FocusNode(skipTraversal: true);
  final FocusNode _cardFocus = FocusNode(canRequestFocus: false);
  final ScrollController _scrollController = ScrollController();
  late String _questionId;
  var _open = true;
  var _pending = false;
  var _sent = false;
  var _generation = 0;

  int get _index => widget.questions.indexWhere((q) => q.id == _questionId);
  BeautifulApprovalQuestion get _question => widget.questions[_index];
  BeautifulApprovalAnswer get _answer => _answers[_questionId]!;
  bool get _last => _index == widget.questions.length - 1;
  bool get _interactive => widget.enabled && !_pending;
  bool get _hasComposingText =>
      _customController.value.composing.isValid &&
      !_customController.value.composing.isCollapsed;

  @override
  void initState() {
    super.initState();
    _initialize();
    _customFocus.addListener(_focusChanged);
  }

  void _initialize() {
    final seeds = <String, BeautifulApprovalAnswer>{
      for (final answer in widget.initialAnswers) answer.questionId: answer,
    };
    _answers.clear();
    for (final question in widget.questions) {
      final seed = seeds[question.id];
      _answers[question.id] = BeautifulApprovalAnswer(
        questionId: question.id,
        optionIds: question.options
            .where((option) => seed?.optionIds.contains(option.id) ?? false)
            .map((option) => option.id)
            .toList(),
        customText: seed?.customText ?? '',
      );
    }
    _questionId = widget.questions.first.id;
    _open = true;
    _pending = false;
    _sent = false;
    _syncCustom();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  void didUpdateWidget(BeautifulApprovalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _generation++;
      _initialize();
    } else if (!_sameQuestions(oldWidget.questions, widget.questions)) {
      _generation++;
      _pending = false;
      _sent = false;
      final updated = <String, BeautifulApprovalAnswer>{};
      for (final question in widget.questions) {
        final previous = _answers[question.id];
        final validIds = previous?.optionIds.toSet() ?? <String>{};
        var selected = question.options
            .where((option) => validIds.contains(option.id))
            .map((option) => option.id)
            .toList();
        final custom = question.allowCustomAnswer
            ? previous?.customText ?? ''
            : '';
        if (question.type == BeautifulApprovalQuestionType.singleChoice) {
          selected = custom.isNotEmpty ? <String>[] : selected.take(1).toList();
        }
        updated[question.id] = BeautifulApprovalAnswer(
          questionId: question.id,
          optionIds: selected,
          customText: custom,
        );
      }
      _answers
        ..clear()
        ..addAll(updated);
      if (!_answers.containsKey(_questionId)) {
        _questionId = widget.questions.first.id;
      }
      _syncCustom();
    }
  }

  @override
  void dispose() {
    _customFocus
      ..removeListener(_focusChanged)
      ..dispose();
    _headingFocus.dispose();
    _cardFocus.dispose();
    _customController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  void _syncCustom() {
    final text = _answer.customText;
    if (_customController.text == text) return;
    _customController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _notifyAnswer(BeautifulApprovalAnswer answer) {
    try {
      widget.onAnswerChanged?.call(answer);
    } catch (error, stackTrace) {
      _reportFailure(error, stackTrace, 'Approval draft callback failed.');
    }
  }

  void _toggle(BeautifulApprovalOption option) {
    if (!_interactive) return;
    final single = _question.type == BeautifulApprovalQuestionType.singleChoice;
    final selected = _answer.optionIds.toSet();
    if (single) {
      selected
        ..clear()
        ..add(option.id);
    } else if (!selected.add(option.id)) {
      selected.remove(option.id);
    }
    final answer = BeautifulApprovalAnswer(
      questionId: _questionId,
      optionIds: _question.options
          .where((option) => selected.contains(option.id))
          .map((option) => option.id)
          .toList(),
      customText: single ? '' : _answer.customText,
    );
    setState(() {
      _answers[_questionId] = answer;
      _syncCustom();
    });
    _notifyAnswer(answer);
    if (single && widget.autoAdvance) _advance();
  }

  void _editCustom(String text) {
    if (!_interactive) return;
    final answer = BeautifulApprovalAnswer(
      questionId: _questionId,
      optionIds: _question.type == BeautifulApprovalQuestionType.singleChoice
          ? const <String>[]
          : _answer.optionIds,
      customText: text,
    );
    setState(() => _answers[_questionId] = answer);
    _notifyAnswer(answer);
  }

  void _goTo(int index) {
    if (!_interactive || index < 0 || index >= widget.questions.length) return;
    final restoreFocus = _cardFocus.hasFocus;
    setState(() {
      _questionId = widget.questions[index].id;
      _syncCustom();
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    if (restoreFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open && !_sent) _headingFocus.requestFocus();
      });
    }
  }

  void _advance() {
    if (!_interactive || !_answer.hasAnswer) return;
    if (_last) {
      unawaited(_submit());
    } else {
      _goTo(_index + 1);
    }
  }

  Future<void> _submit() async {
    if (!_interactive || !_answer.hasAnswer) return;
    final generation = ++_generation;
    final answers = List<BeautifulApprovalAnswer>.unmodifiable(
      widget.questions.map((question) => _answers[question.id]!),
    );
    setState(() => _pending = true);
    try {
      await widget.onSubmit(answers);
    } catch (error, stackTrace) {
      if (!mounted || generation != _generation) return;
      setState(() => _pending = false);
      _reportFailure(error, stackTrace, 'Approval submission failed.');
      return;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _pending = false;
      _sent = true;
    });
  }

  void _reportFailure(Object error, StackTrace stackTrace, String message) {
    BeautifulUiEnvironment.of(context).reportFailure(
      BeautifulUiFailure(
        operation: BeautifulUiOperation.approval,
        message: message,
        cause: error,
        stackTrace: stackTrace,
      ),
    );
  }

  void _dismiss() {
    if (!_interactive) return;
    setState(() => _open = false);
  }

  void _reset() {
    if (!_interactive) return;
    setState(() {
      _generation++;
      _answers.clear();
      for (final question in widget.questions) {
        _answers[question.id] = BeautifulApprovalAnswer(
          questionId: question.id,
        );
      }
      _questionId = widget.questions.first.id;
      _sent = false;
      _syncCustom();
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    for (final answer in _answers.values.toList()) {
      _notifyAnswer(answer);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        !_hasComposingText &&
        _open &&
        !_sent &&
        _interactive) {
      _dismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final environment = BeautifulUiEnvironment.of(context);
    final noMotion =
        MediaQuery.disableAnimationsOf(context) ||
        environment.motionPolicy == BeautifulMotionPolicy.none;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          380.0,
          constraints.maxWidth.isFinite ? constraints.maxWidth : 380.0,
        );
        final media = MediaQuery.of(context);
        final viewport = math.max(
          48.0,
          media.size.height - media.viewInsets.bottom - media.padding.vertical,
        );
        final maxHeight = constraints.maxHeight.isFinite
            ? math.min(constraints.maxHeight, viewport)
            : viewport;
        return SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Focus(
              focusNode: _cardFocus,
              onKeyEvent: _handleKey,
              child: FocusTraversalGroup(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    child: !_open
                        ? _action(
                            label: widget.openLabel,
                            onPressed: widget.enabled
                                ? () => setState(() => _open = true)
                                : null,
                          )
                        : _sent
                        ? _buildSuccess(theme)
                        : _buildCard(theme, noMotion),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccess(BeautifulUiThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          child: Container(
            padding: EdgeInsets.all(theme.spacing.md),
            decoration: BoxDecoration(
              color: theme.colors.successTint,
              borderRadius: BorderRadius.circular(theme.radii.card),
            ),
            child: Text(
              '✓ ${widget.sentLabel}',
              style: theme.typography.label.copyWith(
                color: theme.colors.success,
              ),
            ),
          ),
        ),
        if (widget.resettable) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          _action(
            label: widget.resetLabel,
            onPressed: _interactive ? _reset : null,
          ),
        ],
      ],
    );
  }

  Widget _buildCard(BeautifulUiThemeData theme, bool noMotion) {
    final questionContent = Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        key: ValueKey<String>(_questionId),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Focus(
                  focusNode: _headingFocus,
                  child: Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      _question.title,
                      style: theme.typography.label.copyWith(
                        color: theme.colors.ink,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: _action(
                  label: '×',
                  semanticLabel: widget.dismissLabel,
                  onPressed: _interactive ? _dismiss : null,
                ),
              ),
            ],
          ),
          for (final option in _question.options) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            Semantics(
              checked: _answer.optionIds.contains(option.id),
              inMutuallyExclusiveGroup:
                  _question.type == BeautifulApprovalQuestionType.singleChoice,
              enabled: _interactive,
              label: option.label,
              excludeSemantics: true,
              onTap: _interactive ? () => _toggle(option) : null,
              child: _action(
                label: option.label,
                selected: _answer.optionIds.contains(option.id),
                leading: _ChoiceMark(
                  selected: _answer.optionIds.contains(option.id),
                  single:
                      _question.type ==
                      BeautifulApprovalQuestionType.singleChoice,
                ),
                onPressed: _interactive ? () => _toggle(option) : null,
              ),
            ),
          ],
          if (_question.allowCustomAnswer) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            _buildCustomField(theme),
          ],
          if (widget.errorMessage case final message?) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: theme.typography.body.copyWith(
                  color: theme.colors.destructive,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.line),
        borderRadius: BorderRadius.circular(theme.radii.card),
        boxShadow: theme.shadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (noMotion)
            questionContent
          else
            AnimatedSize(
              alignment: AlignmentDirectional.topStart,
              duration: theme.motion.standard,
              curve: theme.motion.outCurve,
              child: questionContent,
            ),
          _buildFooter(theme),
        ],
      ),
    );
  }

  Widget _buildCustomField(BeautifulUiThemeData theme) {
    final generation = _generation;
    final questionId = _questionId;
    return MergeSemantics(
      child: Semantics(
        label: widget.customAnswerLabel,
        enabled: _interactive,
        textField: true,
        onTap: _interactive ? _customFocus.requestFocus : null,
        child: BeautifulTextSelectionGestureDetector(
          editableTextKey: _customFieldKey,
          identity: (widget.id, _questionId, _generation),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.all(theme.spacing.md),
            decoration: BoxDecoration(
              color: theme.colors.field,
              borderRadius: BorderRadius.circular(theme.radii.control),
              border: Border.all(
                color: _customFocus.hasFocus
                    ? theme.colors.accent
                    : theme.colors.line,
                width: _customFocus.hasFocus ? 2 : 1,
              ),
            ),
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: <Widget>[
                if (_customController.text.isEmpty)
                  ExcludeSemantics(
                    child: Text(
                      widget.customPlaceholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(
                        color: theme.colors.inkMuted,
                      ),
                    ),
                  ),
                EditableText(
                  key: _customFieldKey,
                  controller: _customController,
                  focusNode: _customFocus,
                  rendererIgnoresPointer: true,
                  showSelectionHandles: true,
                  selectionControls: BeautifulTextSelectionControls(
                    theme.colors.accent,
                  ),
                  contextMenuBuilder: (context, state) {
                    final localizations = WidgetsLocalizations.of(context);
                    return beautifulEditableTextContextMenu(
                      state.context,
                      state,
                      copyLabel: localizations.copyButtonLabel,
                      cutLabel: localizations.cutButtonLabel,
                      pasteLabel: localizations.pasteButtonLabel,
                      selectAllLabel: localizations.selectAllButtonLabel,
                      isCurrent: () =>
                          mounted &&
                          _interactive &&
                          generation == _generation &&
                          questionId == _questionId,
                    );
                  },
                  readOnly: !_interactive,
                  style: theme.typography.body.copyWith(
                    color: theme.colors.ink,
                  ),
                  cursorColor: theme.colors.accent,
                  backgroundCursorColor: theme.colors.inkSubtle,
                  selectionColor: theme.colors.accentTint,
                  textDirection: Directionality.of(context),
                  keyboardType: TextInputType.text,
                  textInputAction: _last
                      ? TextInputAction.send
                      : TextInputAction.next,
                  onChanged: _editCustom,
                  // Preserve the composing range until onSubmitted can reject
                  // an IME action for an answer that is still being composed.
                  onEditingComplete: () {},
                  onSubmitted: (_) {
                    if (!_hasComposingText) {
                      _advance();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BeautifulUiThemeData theme) {
    return Container(
      padding: EdgeInsets.all(theme.spacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 48,
                child: _action(
                  label: '↑',
                  semanticLabel: widget.previousLabel,
                  onPressed: _interactive && _index > 0
                      ? () => _goTo(_index - 1)
                      : null,
                ),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '${_index + 1} / ${widget.questions.length}',
                    textAlign: TextAlign.center,
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.inkMuted,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: _action(
                  label: '↓',
                  semanticLabel: widget.nextLabel,
                  onPressed: _interactive && !_last
                      ? () => _goTo(_index + 1)
                      : null,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Semantics(
            liveRegion: _pending,
            child: _action(
              label: _pending
                  ? widget.pendingLabel
                  : _last
                  ? widget.sendLabel
                  : widget.continueLabel,
              tone: BeautifulActionTone.primary,
              onPressed: _interactive && _answer.hasAnswer ? _advance : null,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          _action(
            label: widget.skipLabel,
            onPressed: _interactive
                ? () => _last ? _dismiss() : _goTo(_index + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _action({
    required String label,
    required VoidCallback? onPressed,
    String? semanticLabel,
    Widget? leading,
    bool? selected,
    BeautifulActionTone tone = BeautifulActionTone.quiet,
  }) {
    return BeautifulActionControl(
      label: label,
      semanticLabel: semanticLabel,
      leading: leading,
      selected: selected,
      tone: selected == true ? BeautifulActionTone.secondary : tone,
      fullWidth: true,
      maxLines: null,
      minHeight: 48,
      onPressed: onPressed,
    );
  }
}

final class _ChoiceMark extends StatelessWidget {
  const _ChoiceMark({required this.selected, required this.single});

  final bool selected;
  final bool single;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: selected ? theme.colors.ink : const Color(0x00000000),
        border: Border.all(
          color: selected ? theme.colors.ink : theme.colors.inkMuted,
        ),
        borderRadius: BorderRadius.circular(single ? 9 : 4),
      ),
      alignment: Alignment.center,
      child: selected
          ? single
                ? Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.colors.surface,
                      shape: BoxShape.circle,
                    ),
                  )
                : Text(
                    '✓',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(color: theme.colors.surface, fontSize: 12),
                  )
          : null,
    );
  }
}
