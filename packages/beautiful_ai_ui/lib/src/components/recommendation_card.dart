import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/failure.dart';
import '../foundation/layout.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';

/// Semantic color treatments for a recommendation confidence signal.
enum BeautifulRecommendationTone {
  /// A positive, high-confidence recommendation.
  success,

  /// A recommendation that deserves additional review.
  warning,

  /// A recommendation without a positive or warning signal.
  neutral,
}

/// Immutable content and action data for one recommendation choice.
///
/// ```dart
/// const option = BeautifulRecommendationOption(
///   id: 'primary',
///   body: 'Use the verified supplier.',
///   shortLabel: 'Verified supplier',
///   signal: 3,
///   tone: BeautifulRecommendationTone.success,
///   confidenceLabel: 'High confidence',
///   actionLabel: 'Accept',
/// );
/// ```
@immutable
final class BeautifulRecommendationOption {
  /// Creates a recommendation option.
  ///
  /// Parameters:
  /// - [id] (`String`, required): Stable, non-empty identity.
  /// - [body] (`String`, required): Non-empty, localizable primary content.
  /// - [shortLabel] (`String`, required): Plain-text alternative-row summary.
  /// - [signal] (`int`, required): Filled confidence bars from zero through
  ///   three.
  /// - [tone] (`BeautifulRecommendationTone`, required): Semantic signal tone.
  /// - [confidenceLabel] (`String`, required): Visible, localizable confidence
  ///   text so color is never the only cue.
  /// - [actionLabel] (`String`, required): Localizable primary action text.
  ///
  /// Assertions: text fields are non-empty and [signal] is in `0..3`.
  const BeautifulRecommendationOption({
    required this.id,
    required this.body,
    required this.shortLabel,
    required this.signal,
    required this.tone,
    required this.confidenceLabel,
    required this.actionLabel,
  }) : assert(id != ''),
       assert(body != ''),
       assert(shortLabel != ''),
       assert(signal >= 0 && signal <= 3),
       assert(confidenceLabel != ''),
       assert(actionLabel != '');

  /// Stable identity used to preserve selection when [options] reorder.
  final String id;

  /// Localizable primary content for the selected recommendation.
  ///
  /// The module owns its wrapping, text scaling, directionality, and Semantics.
  /// Structured inline entities can be added later without freezing an
  /// arbitrary widget slot into the public interface.
  final String body;

  /// Plain-text summary shown when this option is an alternative.
  final String shortLabel;

  /// Number of filled confidence bars, from zero through three.
  final int signal;

  /// Semantic color treatment for the confidence meter.
  final BeautifulRecommendationTone tone;

  /// Visible, localizable confidence description.
  final String confidenceLabel;

  /// Visible, localizable primary action label.
  final String actionLabel;
}

/// Displays an agent recommendation, alternatives, confidence, and acceptance.
///
/// The module owns selected-option state, disclosure state, responsive layout,
/// focus order, Semantics, reduced-motion behavior, and the transient
/// pending/accepted lifecycle. The host owns the actual operation through
/// [onAccept]; no networking, persistence, or agent orchestration happens here.
///
/// [onAccept] receives the currently selected stable option. Synchronous and
/// asynchronous callbacks are supported. While it is pending, repeat activation
/// and option changes are ignored. A successful completion changes the action to
/// [acceptedLabel]. A failure leaves selection, disclosure, and prior acceptance
/// intact and is normalized through [BeautifulUiEnvironment.reportFailure].
///
/// ```dart
/// final card = BeautifulRecommendationCard(
///   title: 'Use the verified supplier?',
///   options: const <BeautifulRecommendationOption>[
///     BeautifulRecommendationOption(
///       id: 'primary',
///       body: 'Use the verified supplier.',
///       shortLabel: 'Verified supplier',
///       signal: 3,
///       tone: BeautifulRecommendationTone.success,
///       confidenceLabel: 'High confidence',
///       actionLabel: 'Accept',
///     ),
///   ],
///   onAccept: (option) async {},
/// );
/// ```
final class BeautifulRecommendationCard extends StatefulWidget {
  /// Creates a recommendation card.
  ///
  /// Parameters:
  /// - [title] (`String`, required): Non-empty recommendation prompt.
  /// - [options] (`List<BeautifulRecommendationOption>`, required): Non-empty
  ///   immutable snapshot with stable, unique IDs.
  /// - [initialOptionId] (`String?`, optional): Initially promoted option;
  ///   defaults to the first option.
  /// - [onAccept] (`FutureOr<void> Function(BeautifulRecommendationOption)`,
  ///   required): Host-owned operation for the promoted option.
  /// - [alternativesLabel] (`String`, default: `Alternatives`): Disclosure
  ///   action text.
  /// - [otherOptionsLabel] (`String`, default: `Other options`): Alternatives
  ///   section heading.
  /// - [pendingLabel] (`String`, default: `Accepting…`): Disabled action text
  ///   while [onAccept] is incomplete.
  /// - [acceptedLabel] (`String`, default: `Accepted`): Successful action text.
  ///
  /// Assertions: [options] is non-empty, option IDs are unique,
  /// [initialOptionId] identifies an option when supplied, and labels are
  /// non-empty.
  BeautifulRecommendationCard({
    super.key,
    required this.title,
    required List<BeautifulRecommendationOption> options,
    this.initialOptionId,
    required this.onAccept,
    this.alternativesLabel = 'Alternatives',
    this.otherOptionsLabel = 'Other options',
    this.pendingLabel = 'Accepting…',
    this.acceptedLabel = 'Accepted',
  }) : assert(title != ''),
       assert(options.isNotEmpty, 'options must not be empty'),
       assert(
         _hasUniqueOptionIds(options),
         'options must have stable, unique ids',
       ),
       assert(
         initialOptionId == null ||
             options.any((option) => option.id == initialOptionId),
         'initialOptionId must identify an option',
       ),
       assert(alternativesLabel != ''),
       assert(otherOptionsLabel != ''),
       assert(pendingLabel != ''),
       assert(acceptedLabel != ''),
       options = List<BeautifulRecommendationOption>.unmodifiable(options);

  /// Recommendation prompt displayed as the card heading.
  final String title;

  /// Immutable recommendation choices.
  final List<BeautifulRecommendationOption> options;

  /// Stable ID selected on first insertion into the tree.
  ///
  /// Later rebuilds preserve the module-owned selection while that ID remains
  /// present. If a refreshed snapshot removes the selected option, this ID is
  /// used as a fallback before the first option.
  final String? initialOptionId;

  /// Performs the host-owned operation for the selected option.
  final FutureOr<void> Function(BeautifulRecommendationOption option) onAccept;

  /// Localizable label for the alternatives disclosure action.
  final String alternativesLabel;

  /// Localizable alternatives section heading.
  final String otherOptionsLabel;

  /// Localizable primary action label while [onAccept] is incomplete.
  final String pendingLabel;

  /// Localizable primary action label after [onAccept] succeeds.
  final String acceptedLabel;

  @override
  State<BeautifulRecommendationCard> createState() =>
      _BeautifulRecommendationCardState();
}

bool _hasUniqueOptionIds(List<BeautifulRecommendationOption> options) {
  final ids = <String>{};
  for (final option in options) {
    if (!ids.add(option.id)) {
      return false;
    }
  }
  return true;
}

bool _sameRecommendationModel(
  BeautifulRecommendationCard previous,
  BeautifulRecommendationCard next,
) {
  if (previous.title != next.title ||
      previous.initialOptionId != next.initialOptionId ||
      previous.options.length != next.options.length) {
    return false;
  }
  for (var index = 0; index < previous.options.length; index++) {
    final previousOption = previous.options[index];
    final nextOption = next.options[index];
    if (previousOption.id != nextOption.id ||
        previousOption.body != nextOption.body ||
        previousOption.shortLabel != nextOption.shortLabel ||
        previousOption.signal != nextOption.signal ||
        previousOption.tone != nextOption.tone ||
        previousOption.confidenceLabel != nextOption.confidenceLabel ||
        previousOption.actionLabel != nextOption.actionLabel) {
      return false;
    }
  }
  return true;
}

final class _BeautifulRecommendationCardState
    extends State<BeautifulRecommendationCard> {
  static const _maximumWidth = 380.0;
  static const _interactiveHeight = 48.0;

  late String _selectedId;
  String? _acceptedOptionId;
  var _alternativesExpanded = false;
  var _pending = false;
  var _acceptGeneration = 0;

  BeautifulRecommendationOption get _selectedOption {
    for (final option in widget.options) {
      if (option.id == _selectedId) {
        return option;
      }
    }
    return widget.options.first;
  }

  List<BeautifulRecommendationOption> get _otherOptions => widget.options
      .where((option) => option.id != _selectedId)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialOptionId ?? widget.options.first.id;
  }

  @override
  void didUpdateWidget(BeautifulRecommendationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameRecommendationModel(oldWidget, widget)) {
      // A completion belongs to the exact model that initiated it. Re-enable
      // the refreshed card immediately and prevent the old result from
      // committing success or failure into its replacement.
      _acceptGeneration += 1;
      _pending = false;
      _acceptedOptionId = null;
    }
    final selectionStillExists = widget.options.any(
      (option) => option.id == _selectedId,
    );
    if (!selectionStillExists) {
      _selectedId = widget.initialOptionId ?? widget.options.first.id;
    }
    if (_acceptedOptionId != null &&
        !widget.options.any((option) => option.id == _acceptedOptionId)) {
      _acceptedOptionId = null;
    }
    if (widget.options.length == 1) {
      _alternativesExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final environment = BeautifulUiEnvironment.of(context);
        final theme = BeautifulUiTheme.of(context);
        final mode = environment.modeFor(context, constraints);
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackActions =
            mode == BeautifulLayoutMode.compact || textScale >= 1.5;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _maximumWidth;
        final width = math.min(_maximumWidth, availableWidth);
        final transitionDuration = _transitionDuration(
          context,
          environment,
          theme.motion.standard,
        );

        return SizedBox(
          key: const ValueKey<String>('recommendation-card-surface'),
          width: width,
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.escape):
                    _collapseAlternatives,
              },
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: theme.colors.surface,
                    border: Border.all(color: theme.colors.line),
                    borderRadius: BorderRadius.circular(theme.radii.card),
                    boxShadow: theme.shadows.card,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildPrimaryContent(theme, transitionDuration),
                      _buildAlternatives(theme, transitionDuration),
                      _buildFooter(theme, stackActions),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrimaryContent(
    BeautifulUiThemeData theme,
    Duration transitionDuration,
  ) {
    final selected = _selectedOption;
    return Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            container: true,
            header: true,
            child: Text(
              widget.title,
              style: theme.typography.label.copyWith(
                color: theme.colors.ink,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: DefaultTextStyle.merge(
              style: theme.typography.body.copyWith(
                color: theme.colors.inkMuted,
                fontSize: 13,
                height: 1.625,
              ),
              child: transitionDuration == Duration.zero
                  ? Text(key: ValueKey<String>(selected.id), selected.body)
                  : AnimatedSwitcher(
                      duration: transitionDuration,
                      switchInCurve: theme.motion.outCurve,
                      switchOutCurve: theme.motion.outCurve.flipped,
                      child: Text(
                        key: ValueKey<String>(selected.id),
                        selected.body,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternatives(
    BeautifulUiThemeData theme,
    Duration transitionDuration,
  ) {
    final alternatives = _otherOptions;
    final visible = _alternativesExpanded && alternatives.isNotEmpty;
    final content = visible
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border(top: BorderSide(color: theme.colors.line)),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Semantics(
                    container: true,
                    header: true,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: 6,
                        end: 6,
                        bottom: theme.spacing.xs,
                      ),
                      child: Text(
                        widget.otherOptionsLabel,
                        style: theme.typography.caption.copyWith(
                          color: theme.colors.inkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  for (var index = 0; index < alternatives.length; index++)
                    Padding(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : theme.spacing.xs,
                      ),
                      child: FocusTraversalOrder(
                        order: NumericFocusOrder(index + 2),
                        child: _buildAlternativeControl(
                          theme,
                          alternatives[index],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
        : const SizedBox(width: double.infinity);
    if (transitionDuration == Duration.zero) {
      return content;
    }
    return ClipRect(
      child: AnimatedSize(
        alignment: Alignment.topCenter,
        duration: transitionDuration,
        curve: theme.motion.outCurve,
        child: content,
      ),
    );
  }

  Widget _buildAlternativeControl(
    BeautifulUiThemeData theme,
    BeautifulRecommendationOption option,
  ) {
    return BeautifulActionControl(
      key: ValueKey<String>('recommendation-option-${option.id}'),
      label: option.shortLabel,
      semanticLabel: '${option.shortLabel}, ${option.confidenceLabel}',
      tone: BeautifulActionTone.quiet,
      selected: false,
      fullWidth: true,
      minHeight: _interactiveHeight,
      leading: _ConfidenceMeter(option: option),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 112),
        child: Text(
          option.confidenceLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: theme.typography.caption.copyWith(
            color: theme.colors.inkMuted,
            fontSize: 11,
          ),
        ),
      ),
      onPressed: _pending ? null : () => _selectOption(option),
    );
  }

  Widget _buildFooter(BeautifulUiThemeData theme, bool stackActions) {
    final selected = _selectedOption;
    final alternatives = _otherOptions;
    final accepted = _acceptedOptionId == selected.id;
    final confidence = _ConfidenceSummary(option: selected);
    final disclosure = alternatives.isEmpty
        ? null
        : FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: BeautifulActionControl(
              key: const ValueKey<String>('recommendation-alternatives'),
              label: widget.alternativesLabel,
              tone: BeautifulActionTone.secondary,
              expanded: _alternativesExpanded,
              fullWidth: stackActions,
              minHeight: _interactiveHeight,
              onPressed: _toggleAlternatives,
            ),
          );
    final action = FocusTraversalOrder(
      order: NumericFocusOrder(widget.options.length + 2),
      child: BeautifulActionControl(
        key: const ValueKey<String>('recommendation-accept'),
        label: _pending
            ? widget.pendingLabel
            : accepted
            ? widget.acceptedLabel
            : selected.actionLabel,
        tone: accepted
            ? BeautifulActionTone.success
            : BeautifulActionTone.primary,
        fullWidth: stackActions,
        minHeight: _interactiveHeight,
        onPressed: _pending ? null : _startAccept,
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(10),
      child: stackActions
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                confidence,
                if (disclosure != null) ...<Widget>[
                  SizedBox(height: theme.spacing.sm),
                  disclosure,
                ],
                SizedBox(height: theme.spacing.sm),
                action,
              ],
            )
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: theme.spacing.md,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                confidence,
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.sm,
                  children: <Widget>[?disclosure, action],
                ),
              ],
            ),
    );
  }

  void _toggleAlternatives() {
    setState(() {
      _alternativesExpanded = !_alternativesExpanded;
    });
  }

  void _collapseAlternatives() {
    if (!_alternativesExpanded) {
      return;
    }
    setState(() {
      _alternativesExpanded = false;
    });
  }

  void _selectOption(BeautifulRecommendationOption option) {
    if (_pending || option.id == _selectedId) {
      return;
    }
    setState(() {
      _selectedId = option.id;
      _acceptedOptionId = null;
    });
  }

  void _startAccept() {
    unawaited(_accept());
  }

  Future<void> _accept() async {
    if (_pending) {
      return;
    }
    final generation = ++_acceptGeneration;
    final option = _selectedOption;
    setState(() {
      _pending = true;
    });

    try {
      await widget.onAccept(option);
    } catch (error, stackTrace) {
      if (!mounted || generation != _acceptGeneration) {
        return;
      }
      setState(() {
        _pending = false;
      });
      BeautifulUiEnvironment.of(context).reportFailure(
        BeautifulUiFailure(
          operation: BeautifulUiOperation.recommendation,
          message: 'Recommendation action failed for option "${option.id}".',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
      return;
    }

    if (!mounted || generation != _acceptGeneration) {
      return;
    }
    setState(() {
      _pending = false;
      _acceptedOptionId = option.id;
    });
  }
}

Duration _transitionDuration(
  BuildContext context,
  BeautifulUiEnvironment environment,
  Duration requested,
) {
  final platformDisabled =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  if (platformDisabled ||
      environment.motionPolicy == BeautifulMotionPolicy.none) {
    return Duration.zero;
  }
  return requested;
}

final class _ConfidenceSummary extends StatelessWidget {
  const _ConfidenceSummary({required this.option});

  final BeautifulRecommendationOption option;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Semantics(
      container: true,
      label: option.confidenceLabel,
      value: '${option.signal}/3',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ConfidenceMeter(option: option),
            SizedBox(width: theme.spacing.sm),
            Flexible(
              child: Text(
                option.confidenceLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.label.copyWith(
                  color: theme.colors.inkMuted,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ConfidenceMeter extends StatelessWidget {
  const _ConfidenceMeter({required this.option});

  final BeautifulRecommendationOption option;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final activeColor = switch (option.tone) {
      BeautifulRecommendationTone.success => theme.colors.success,
      BeautifulRecommendationTone.warning => theme.colors.warning,
      BeautifulRecommendationTone.neutral => theme.colors.inkSubtle,
    };
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var bar = 0; bar < 3; bar++) ...<Widget>[
            if (bar > 0) const SizedBox(width: 2),
            Container(
              width: 4,
              height: 10,
              decoration: BoxDecoration(
                color: bar < option.signal
                    ? activeColor
                    : theme.colors.lineStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
