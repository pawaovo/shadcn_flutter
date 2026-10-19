import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/failure.dart';
import '../foundation/layout.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';
import '../implementation/streaming/stream_content.dart';

/// Caller-owned lifecycle of a streamed answer.
enum BeautifulStreamingStatus {
  /// More content may arrive; completion actions remain unavailable.
  streaming,

  /// The answer is complete and follow-up actions are available.
  complete,

  /// Generation failed; any received content remains readable.
  failed,
}

/// Caller-owned feedback on a completed answer.
enum BeautifulStreamingFeedback {
  /// The answer was helpful.
  positive,

  /// The answer was not helpful.
  negative,
}

/// Exact text or an inline citation to a source with a stable identity.
///
/// Text is never split on spaces or rewritten: CJK, emoji, punctuation and
/// chunk boundaries remain under host control. Citation markers refer to the
/// source list by ID, rather than always linking the first source.
@immutable
final class BeautifulStreamingPart {
  /// A literal piece of the received answer, including its whitespace.
  const BeautifulStreamingPart.text(this.text) : sourceId = null;

  /// An inline marker for a source present in the same snapshot.
  const BeautifulStreamingPart.citation(String id) : sourceId = id, text = '';

  /// Literal answer text, empty for a citation.
  final String text;

  /// Stable source identity, or null for text.
  final String? sourceId;

  @override
  bool operator ==(Object other) =>
      other is BeautifulStreamingPart &&
      other.text == text &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(text, sourceId);
}

/// A cited source; navigation is delegated to the host by stable [id].
@immutable
final class BeautifulStreamingSource {
  /// Creates a source without requiring network URLs or remote artwork.
  const BeautifulStreamingSource({
    required this.id,
    required this.title,
    this.detail = '',
  });

  /// Non-empty stable identity unique within the answer.
  final String id;

  /// Human-readable source name.
  final String title;

  /// Optional domain, filename or other source description.
  final String detail;
}

/// An immutable follow-up suggestion passed back to the host when chosen.
@immutable
final class BeautifulStreamingFollowUp {
  /// Creates a follow-up with stable identity and localized text.
  const BeautifulStreamingFollowUp({required this.id, required this.label});

  /// Non-empty stable identity unique within the answer.
  final String id;

  /// User-facing suggestion.
  final String label;
}

/// Localizable labels for streamed answer state and actions.
@immutable
final class BeautifulStreamingLabels {
  /// Creates labels; defaults are English.
  const BeautifulStreamingLabels({
    this.streaming = 'Generating answer',
    this.complete = 'Answer complete',
    this.failed = 'Answer interrupted',
    this.copy = 'Copy answer',
    this.copying = 'Copying answer',
    this.copied = 'Answer copied',
    this.copyFailed = 'Could not copy answer',
    this.retry = 'Retry answer',
    this.retrying = 'Retrying answer',
    this.sources = 'Sources',
    this.followUps = 'Follow-ups',
    this.positiveFeedback = 'Helpful answer',
    this.negativeFeedback = 'Unhelpful answer',
  });

  /// State while the host is generating content.
  final String streaming;

  /// Completed-answer state.
  final String complete;

  /// Failed-generation state.
  final String failed;

  /// Copy action.
  final String copy;

  /// Pending clipboard state.
  final String copying;

  /// Successful clipboard state.
  final String copied;

  /// Clipboard failure state.
  final String copyFailed;

  /// Host retry action.
  final String retry;

  /// Pending host retry state.
  final String retrying;

  /// Source-list disclosure label; the source count is appended.
  final String sources;

  /// Follow-up section heading.
  final String followUps;

  /// Positive feedback action.
  final String positiveFeedback;

  /// Negative feedback action.
  final String negativeFeedback;
}

/// A selectable streamed answer with citations, sources and completion actions.
///
/// The host replaces [content] and [status] as data arrives. No network client,
/// looping demo timer or artificial text delay lives here. [id] identifies one
/// generation: replace it for a new answer, even in the same conversation.
/// Sources and suggestions are defensively copied. Local source disclosure
/// survives content updates and resizing; a new [id] resets it.
///
/// Inline markers are descriptive. The expanded source list supplies full-size
/// touch/keyboard actions instead of embedding tiny links within text. Only the
/// status is a live region, avoiding repeated full-text announcements.
///
/// ```dart
/// BeautifulStreamingText(
///   id: 'answer-1',
///   status: BeautifulStreamingStatus.streaming,
///   content: const [BeautifulStreamingPart.text('Here is the answer…')],
/// );
/// ```
final class BeautifulStreamingText extends StatefulWidget {
  /// Creates a caller-controlled answer snapshot.
  ///
  /// Throws [ArgumentError] for blank/duplicate identities, unknown citation
  /// references, blank source titles or blank follow-up labels.
  BeautifulStreamingText({
    super.key,
    required this.id,
    required Iterable<BeautifulStreamingPart> content,
    required this.status,
    Iterable<BeautifulStreamingSource> sources = const [],
    Iterable<BeautifulStreamingFollowUp> followUps = const [],
    this.labels = const BeautifulStreamingLabels(),
    this.errorMessage,
    this.feedback,
    this.onSourcePressed,
    this.onFollowUp,
    this.onFeedback,
    this.onCopy,
    this.onRetry,
    this.quiet = false,
    this.density = BeautifulUiDensity.comfortable,
  }) : content = List.unmodifiable(content),
       sources = List.unmodifiable(sources),
       followUps = List.unmodifiable(followUps) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be blank');
    }
    final ids = <String>{};
    for (final source in this.sources) {
      if (source.id.trim().isEmpty ||
          !ids.add(source.id) ||
          source.title.trim().isEmpty) {
        throw ArgumentError('Sources need unique non-empty IDs and titles.');
      }
    }
    for (final part in this.content) {
      if (part.sourceId != null && !ids.contains(part.sourceId)) {
        throw ArgumentError.value(
          part.sourceId,
          'content',
          'unknown source ID',
        );
      }
    }
    ids.clear();
    for (final followUp in this.followUps) {
      if (followUp.id.trim().isEmpty ||
          !ids.add(followUp.id) ||
          followUp.label.trim().isEmpty) {
        throw ArgumentError('Follow-ups need unique non-empty IDs and labels.');
      }
    }
  }

  /// Stable generation identity; a different value clears local feedback.
  final String id;

  /// Immutable received content. Text includes all intended whitespace.
  final List<BeautifulStreamingPart> content;

  /// Host-owned generation lifecycle.
  final BeautifulStreamingStatus status;

  /// Transcript presentation: completed status remains available to assistive
  /// technology while its visible label is omitted. Actions reveal on pointer
  /// hover or keyboard focus; touch-sized viewports keep them visible.
  final bool quiet;

  /// Optional compact completion actions, without changing selection or copy.
  final BeautifulUiDensity density;

  /// Immutable source metadata indexed by citations.
  final List<BeautifulStreamingSource> sources;

  /// Immutable suggestions revealed on completion.
  final List<BeautifulStreamingFollowUp> followUps;

  /// Localized labels.
  final BeautifulStreamingLabels labels;

  /// Optional localized explanation shown only in the failed state.
  final String? errorMessage;

  /// Host-owned feedback selection.
  final BeautifulStreamingFeedback? feedback;

  /// Host source action; null leaves the source list descriptive.
  final ValueChanged<BeautifulStreamingSource>? onSourcePressed;

  /// Host suggestion action; null leaves suggestions descriptive.
  final ValueChanged<BeautifulStreamingFollowUp>? onFollowUp;

  /// Host feedback action; null omits the feedback controls.
  final ValueChanged<BeautifulStreamingFeedback>? onFeedback;

  /// Optional clipboard replacement; otherwise uses Flutter Clipboard.
  final FutureOr<void> Function(String text)? onCopy;

  /// Optional host retry. The host must supply a new [id] for the new attempt.
  final FutureOr<void> Function()? onRetry;

  @override
  State<BeautifulStreamingText> createState() => _BeautifulStreamingTextState();
}

enum _CopyState { idle, pending, copied, failed }

final class _BeautifulStreamingTextState extends State<BeautifulStreamingText> {
  var _sourcesOpen = false;
  var _copyState = _CopyState.idle;
  var _retryPending = false;
  var _generation = 0;
  var _hovered = false;
  var _actionsFocused = false;

  String get _plainText {
    final indexes = {
      for (var i = 0; i < widget.sources.length; i++)
        widget.sources[i].id: i + 1,
    };
    return widget.content
        .map(
          (part) =>
              part.sourceId == null ? part.text : '[${indexes[part.sourceId]}]',
        )
        .join();
  }

  @override
  void didUpdateWidget(BeautifulStreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _generation++;
      _sourcesOpen = false;
      _copyState = _CopyState.idle;
      _retryPending = false;
    } else if (oldWidget.status != widget.status ||
        !listEquals(oldWidget.content, widget.content) ||
        !listEquals(
          oldWidget.sources.map((source) => source.id).toList(),
          widget.sources.map((source) => source.id).toList(),
        )) {
      // Ignore a pending copy of an older snapshot, including partial answers.
      _copyGeneration++;
      _copyState = _CopyState.idle;
    }
  }

  var _copyGeneration = 0;

  Future<void> _copy(String text) async {
    if (_copyState == _CopyState.pending || text.isEmpty) return;
    final generation = _generation;
    final copyGeneration = ++_copyGeneration;
    final environment = BeautifulUiEnvironment.of(context);
    final copy = widget.onCopy;
    setState(() => _copyState = _CopyState.pending);
    try {
      if (copy == null) {
        await Clipboard.setData(ClipboardData(text: text));
      } else {
        await copy(text);
      }
      if (mounted &&
          generation == _generation &&
          copyGeneration == _copyGeneration) {
        setState(() => _copyState = _CopyState.copied);
      }
    } catch (error, stack) {
      if (!mounted ||
          generation != _generation ||
          copyGeneration != _copyGeneration) {
        return;
      }
      setState(() => _copyState = _CopyState.failed);
      environment.reportFailure(
        BeautifulUiFailure(
          operation: BeautifulUiOperation.clipboard,
          message: 'Could not copy streamed answer.',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }

  Future<void> _retry() async {
    if (_retryPending || widget.onRetry == null) return;
    final generation = _generation;
    final environment = BeautifulUiEnvironment.of(context);
    setState(() => _retryPending = true);
    try {
      await widget.onRetry!();
    } catch (error, stack) {
      if (mounted && generation == _generation) {
        environment.reportFailure(
          BeautifulUiFailure(
            operation: BeautifulUiOperation.streaming,
            message: 'Could not retry streamed answer.',
            cause: error,
            stackTrace: stack,
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _retryPending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final labels = widget.labels;
    final done = widget.status == BeautifulStreamingStatus.complete;
    final settled = widget.status != BeautifulStreamingStatus.streaming;
    final sourceIndexes = {
      for (var i = 0; i < widget.sources.length; i++) widget.sources[i].id: i,
    };
    final statusLabel = switch (widget.status) {
      BeautifulStreamingStatus.streaming => labels.streaming,
      BeautifulStreamingStatus.complete => labels.complete,
      BeautifulStreamingStatus.failed => labels.failed,
    };
    final copyLabel = switch (_copyState) {
      _CopyState.idle => labels.copy,
      _CopyState.pending => labels.copying,
      _CopyState.copied => labels.copied,
      _CopyState.failed => labels.copyFailed,
    };
    final compact =
        widget.quiet || widget.density == BeautifulUiDensity.compact;
    final hideStatus = widget.quiet && done;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          excludeSemantics: true,
          label: _copyState == _CopyState.idle
              ? statusLabel
              : '$statusLabel. $copyLabel',
          child: hideStatus
              ? const SizedBox.shrink()
              : Text(
                  statusLabel,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.inkMuted,
                  ),
                ),
        ),
        if (!hideStatus) SizedBox(height: theme.spacing.sm),
        BeautifulStreamContent(
          key: ValueKey(widget.id),
          copyLabel: labels.copy,
          onCopy: _copy,
          span: TextSpan(
            children: [
              for (final part in widget.content)
                if (part.sourceId case final sourceId?)
                  TextSpan(
                    text: '[${sourceIndexes[sourceId]! + 1}]',
                    semanticsLabel:
                        '[${widget.sources[sourceIndexes[sourceId]!].title}]',
                    style: theme.typography.mono.copyWith(
                      color: theme.colors.accentInk,
                      backgroundColor: theme.colors.accentTint,
                    ),
                  )
                else
                  TextSpan(text: part.text),
            ],
          ),
        ),
        if (widget.status == BeautifulStreamingStatus.failed &&
            widget.errorMessage != null) ...[
          SizedBox(height: theme.spacing.sm),
          Text(
            widget.errorMessage!,
            style: theme.typography.body.copyWith(
              color: theme.colors.destructive,
            ),
          ),
        ],
        if (settled) ...[
          SizedBox(height: theme.spacing.sm),
          _actionBar(
            context,
            theme,
            Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: [
                if (_plainText.isNotEmpty)
                  _action(
                    label: copyLabel,
                    glyph: _copyState == _CopyState.copied
                        ? _StreamingGlyph.check
                        : _copyState == _CopyState.failed
                        ? _StreamingGlyph.error
                        : _StreamingGlyph.copy,
                    compact: compact,
                    onPressed: _copyState == _CopyState.pending
                        ? null
                        : () => _copy(_plainText),
                  ),
                if (widget.onRetry != null)
                  _action(
                    label: _retryPending ? labels.retrying : labels.retry,
                    glyph: _StreamingGlyph.retry,
                    compact: compact,
                    onPressed: _retryPending ? null : _retry,
                  ),
                if (done && widget.onFeedback != null)
                  for (final feedback in BeautifulStreamingFeedback.values)
                    _action(
                      label: feedback == BeautifulStreamingFeedback.positive
                          ? labels.positiveFeedback
                          : labels.negativeFeedback,
                      glyph: feedback == BeautifulStreamingFeedback.positive
                          ? _StreamingGlyph.positive
                          : _StreamingGlyph.negative,
                      compact: compact,
                      selected: widget.feedback == feedback,
                      onPressed: () => widget.onFeedback!(feedback),
                    ),
                if (widget.sources.isNotEmpty)
                  _action(
                    label: '${labels.sources} (${widget.sources.length})',
                    glyph: _StreamingGlyph.sources,
                    compact: compact,
                    expanded: _sourcesOpen,
                    onPressed: () =>
                        setState(() => _sourcesOpen = !_sourcesOpen),
                  ),
              ],
            ),
          ),
          if (_sourcesOpen) ...[
            SizedBox(height: theme.spacing.sm),
            for (var i = 0; i < widget.sources.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: theme.spacing.xs),
                child: _source(widget.sources[i], i + 1, theme),
              ),
          ],
        ],
        if (done && widget.followUps.isNotEmpty) ...[
          SizedBox(height: theme.spacing.md),
          Text(
            labels.followUps,
            style: theme.typography.label.copyWith(
              color: theme.colors.inkMuted,
            ),
          ),
          for (final followUp in widget.followUps)
            Padding(
              padding: EdgeInsets.only(top: theme.spacing.xs),
              child: widget.onFollowUp == null
                  ? Text(
                      followUp.label,
                      style: theme.typography.body.copyWith(
                        color: theme.colors.ink,
                      ),
                    )
                  : BeautifulActionControl(
                      label: followUp.label,
                      minHeight: 48,
                      fullWidth: true,
                      maxLines: null,
                      tone: BeautifulActionTone.quiet,
                      onPressed: () => widget.onFollowUp!(followUp),
                    ),
            ),
        ],
      ],
    );
    if (!widget.quiet) return content;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: content,
    );
  }

  Widget _action({
    required String label,
    required _StreamingGlyph glyph,
    required bool compact,
    required VoidCallback? onPressed,
    bool? selected,
    bool? expanded,
  }) => BeautifulActionControl(
    label: label,
    semanticLabel: label,
    minHeight: compact ? 32 : 48,
    density: compact ? BeautifulUiDensity.compact : widget.density,
    iconOnly: compact,
    tone: compact ? BeautifulActionTone.quiet : BeautifulActionTone.secondary,
    leading: compact
        ? CustomPaint(
            size: const Size.square(16),
            painter: _StreamingActionPainter(
              glyph,
              BeautifulUiTheme.of(context).colors.inkMuted,
            ),
          )
        : null,
    selected: selected,
    expanded: expanded,
    onPressed: onPressed,
  );

  Widget _actionBar(
    BuildContext context,
    BeautifulUiThemeData theme,
    Widget child,
  ) {
    if (!widget.quiet) return child;
    final size = MediaQuery.maybeSizeOf(context);
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        (size != null && size.shortestSide < 600);
    final visible =
        mobile ||
        _hovered ||
        _actionsFocused ||
        _sourcesOpen ||
        _copyState != _CopyState.idle ||
        _retryPending;
    final environment = BeautifulUiEnvironment.of(context);
    final reduced =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        environment.motionPolicy == BeautifulMotionPolicy.none ||
        environment.motionPolicy == BeautifulMotionPolicy.reduced;
    return Focus(
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (value) => setState(() => _actionsFocused = value),
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: reduced ? Duration.zero : theme.motion.quick,
        child: child,
      ),
    );
  }

  Widget _source(
    BeautifulStreamingSource source,
    int index,
    BeautifulUiThemeData theme,
  ) {
    final label =
        '[$index] ${source.title}${source.detail.isEmpty ? '' : ' · ${source.detail}'}';
    if (widget.onSourcePressed == null) {
      return Text(
        label,
        style: theme.typography.body.copyWith(color: theme.colors.ink),
      );
    }
    return BeautifulActionControl(
      label: label,
      minHeight: 48,
      fullWidth: true,
      maxLines: null,
      tone: BeautifulActionTone.quiet,
      onPressed: () => widget.onSourcePressed!(source),
    );
  }
}

enum _StreamingGlyph { copy, retry, positive, negative, sources, check, error }

final class _StreamingActionPainter extends CustomPainter {
  const _StreamingActionPainter(this.glyph, this.color);
  final _StreamingGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 16, size.height / 16);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (glyph) {
      case _StreamingGlyph.copy:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 5, 8, 9),
            const Radius.circular(1.5),
          ),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(3, 10)
            ..lineTo(2, 10)
            ..lineTo(2, 2)
            ..lineTo(10, 2)
            ..lineTo(10, 3),
          paint,
        );
      case _StreamingGlyph.retry:
        canvas.drawArc(
          const Rect.fromLTWH(3, 3, 10, 10),
          0.4,
          5.1,
          false,
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 2)
            ..lineTo(12, 6)
            ..lineTo(8, 6),
          paint,
        );
      case _StreamingGlyph.positive:
      case _StreamingGlyph.negative:
        if (glyph == _StreamingGlyph.negative) {
          canvas.translate(0, 16);
          canvas.scale(1, -1);
        }
        canvas.drawPath(
          Path()
            ..moveTo(5, 7)
            ..lineTo(8, 2)
            ..quadraticBezierTo(11, 2, 9, 7)
            ..lineTo(13, 7)
            ..quadraticBezierTo(14, 7, 13, 10)
            ..lineTo(12, 13)
            ..lineTo(5, 13)
            ..close(),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 7, 3, 6),
            const Radius.circular(0.8),
          ),
          paint,
        );
      case _StreamingGlyph.sources:
        canvas.drawPath(
          Path()
            ..moveTo(2, 3)
            ..lineTo(7, 4)
            ..lineTo(8, 5)
            ..lineTo(9, 4)
            ..lineTo(14, 3)
            ..lineTo(14, 12)
            ..lineTo(9, 13)
            ..lineTo(8, 14)
            ..lineTo(7, 13)
            ..lineTo(2, 12)
            ..close()
            ..moveTo(8, 5)
            ..lineTo(8, 14),
          paint,
        );
      case _StreamingGlyph.check:
        canvas.drawPath(
          Path()
            ..moveTo(3, 8)
            ..lineTo(6.5, 11.5)
            ..lineTo(13, 4.5),
          paint,
        );
      case _StreamingGlyph.error:
        canvas.drawCircle(const Offset(8, 8), 6, paint);
        canvas.drawLine(const Offset(8, 4.5), const Offset(8, 8.5), paint);
        canvas.drawCircle(
          const Offset(8, 11),
          0.6,
          paint..style = PaintingStyle.fill,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StreamingActionPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
