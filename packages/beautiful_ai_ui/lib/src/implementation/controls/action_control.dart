import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/environment.dart';
import '../../foundation/motion.dart';
import '../../foundation/theme.dart';

/// Visual roles used by package-private action controls.
enum BeautifulActionTone {
  /// The prominent accent action.
  primary,

  /// A neutral outlined action.
  secondary,

  /// A low-emphasis transparent action.
  quiet,

  /// A completed or positive action.
  success,

  /// A destructive action.
  destructive,
}

/// A package-private action control with one pointer, keyboard, and Semantics
/// contract shared by composite modules.
final class BeautifulActionControl extends StatefulWidget {
  /// Creates an internal action control.
  const BeautifulActionControl({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = BeautifulActionTone.secondary,
    this.semanticLabel,
    this.leading,
    this.trailing,
    this.expanded,
    this.selected,
    this.fullWidth = false,
    this.minHeight = 44,
  });

  /// Visible action text.
  final String label;

  /// Activation callback, or null when disabled.
  final VoidCallback? onPressed;

  /// Semantic visual role.
  final BeautifulActionTone tone;

  /// Optional assistive label overriding [label].
  final String? semanticLabel;

  /// Optional leading visual.
  final Widget? leading;

  /// Optional trailing visual.
  final Widget? trailing;

  /// Optional disclosure state exposed to Semantics.
  final bool? expanded;

  /// Optional selection state exposed to Semantics.
  final bool? selected;

  /// Whether the control fills its bounded horizontal space.
  final bool fullWidth;

  /// Minimum interactive height in logical pixels.
  final double minHeight;

  @override
  State<BeautifulActionControl> createState() => _BeautifulActionControlState();
}

final class _BeautifulActionControlState extends State<BeautifulActionControl> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final environment = BeautifulUiEnvironment.of(context);
    final enabled = widget.onPressed != null;
    final platformDisablesMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration =
        platformDisablesMotion ||
            environment.motionPolicy == BeautifulMotionPolicy.none
        ? Duration.zero
        : theme.motion.quick;

    final (background, foreground, border) = _colors(theme, enabled);
    final label = Text(
      widget.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: theme.typography.label.copyWith(color: foreground, fontSize: 12.5),
    );
    final content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.leading case final leading?) ...<Widget>[
          leading,
          SizedBox(width: theme.spacing.xs),
        ],
        if (widget.fullWidth) Expanded(child: label) else label,
        if (widget.trailing case final trailing?) ...<Widget>[
          SizedBox(width: theme.spacing.xs),
          trailing,
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      expanded: widget.expanded,
      selected: widget.selected,
      excludeSemantics: true,
      label: widget.semanticLabel ?? widget.label,
      onTap: widget.onPressed,
      child: SizedBox(
        width: widget.fullWidth ? double.infinity : null,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: duration,
              curve: theme.motion.outCurve,
              constraints: BoxConstraints(
                minWidth: 44,
                minHeight: widget.minHeight,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md,
                vertical: theme.spacing.sm,
              ),
              decoration: BoxDecoration(
                color: background,
                border: Border.all(
                  color: _focused ? theme.colors.accent : border,
                  width: _focused ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(theme.radii.control),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color, Color) _colors(BeautifulUiThemeData theme, bool enabled) {
    if (!enabled) {
      return (theme.colors.inset, theme.colors.inkSubtle, theme.colors.line);
    }
    return switch (widget.tone) {
      BeautifulActionTone.primary => (
        _hovered ? theme.colors.accentInk : theme.colors.accent,
        theme.colors.tooltipForeground,
        const Color(0x00000000),
      ),
      BeautifulActionTone.success => (
        theme.colors.success,
        theme.colors.tooltipForeground,
        const Color(0x00000000),
      ),
      BeautifulActionTone.destructive => (
        theme.colors.destructive,
        theme.colors.tooltipForeground,
        const Color(0x00000000),
      ),
      BeautifulActionTone.secondary => (
        _hovered ? theme.colors.hoverStrong : theme.colors.inset,
        theme.colors.ink,
        theme.colors.lineStrong,
      ),
      BeautifulActionTone.quiet => (
        _hovered ? theme.colors.hover : const Color(0x00000000),
        theme.colors.inkMuted,
        const Color(0x00000000),
      ),
    };
  }
}
