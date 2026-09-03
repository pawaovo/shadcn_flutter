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
    this.maxLines = 2,
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

  /// Visible label line limit, or null to wrap the full label.
  final int? maxLines;

  @override
  State<BeautifulActionControl> createState() => _BeautifulActionControlState();
}

final class _BeautifulActionControlState extends State<BeautifulActionControl> {
  var _hovered = false;
  var _focused = false;
  var _hasFocus = false;
  var _pressed = false;

  @override
  void didUpdateWidget(BeautifulActionControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) _pressed = false;
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final environment = BeautifulUiEnvironment.of(context);
    final enabled = widget.onPressed != null;
    final platformDisablesMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration =
        platformDisablesMotion ||
            environment.motionPolicy == BeautifulMotionPolicy.none ||
            // A host may mute an entire subtree to stop continuous motion.
            // Finite state changes must still commit their painted colors.
            !TickerMode.valuesOf(context).enabled
        ? Duration.zero
        : theme.motion.quick;

    final (background, foreground, border) = _colors(theme, enabled);
    final selected = widget.selected ?? false;
    final label = Text(
      widget.label,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null
          ? TextOverflow.clip
          : TextOverflow.ellipsis,
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
        if (widget.fullWidth)
          Expanded(child: label)
        else
          Flexible(child: label),
        if (widget.trailing case final trailing?) ...<Widget>[
          SizedBox(width: theme.spacing.xs),
          trailing,
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      focusable: enabled,
      focused: enabled && _hasFocus,
      expanded: widget.expanded,
      selected: widget.selected,
      excludeSemantics: true,
      label: widget.semanticLabel ?? widget.label,
      onTap: widget.onPressed,
      child: SizedBox(
        width: widget.fullWidth ? double.infinity : null,
        child: FocusableActionDetector(
          enabled: enabled,
          onFocusChange: (value) => setState(() => _hasFocus = value),
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
            onTapDown: enabled ? (_) => _setPressed(true) : null,
            onTapUp: enabled ? (_) => _setPressed(false) : null,
            onTapCancel: enabled ? () => _setPressed(false) : null,
            child: AnimatedContainer(
              duration: duration,
              curve: theme.motion.outCurve,
              constraints: BoxConstraints(
                minWidth: widget.minHeight >= 48 ? 48 : 44,
                minHeight: widget.minHeight,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md + 1,
                vertical: theme.spacing.sm + 1,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(theme.radii.control),
              ),
              // Paint state outlines independently of layout so selection and
              // focus cannot reflow labels or change lazy-menu row extents.
              foregroundDecoration: BoxDecoration(
                border: Border.all(
                  color: _focused || _pressed
                      ? theme.colors.foregroundOn(background)
                      : border,
                  width:
                      (_focused ? 3 : (selected ? 2 : 1)) + (_pressed ? 1 : 0),
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
    final colors = theme.colors;
    final selected = widget.selected ?? false;
    if (!enabled) {
      return (
        colors.inset,
        colors.inkSubtle,
        selected ? colors.foregroundOn(colors.inset) : colors.line,
      );
    }
    final (background, foreground, border) = switch (widget.tone) {
      BeautifulActionTone.primary => (
        _hovered ? colors.accentHover : colors.accent,
        colors.accentForeground,
        const Color(0x00000000),
      ),
      BeautifulActionTone.success => (
        colors.success,
        colors.successForeground,
        const Color(0x00000000),
      ),
      BeautifulActionTone.destructive => (
        colors.destructive,
        colors.destructiveForeground,
        const Color(0x00000000),
      ),
      BeautifulActionTone.secondary => (
        _hovered ? colors.hoverStrong : colors.inset,
        colors.ink,
        colors.lineStrong,
      ),
      BeautifulActionTone.quiet => (
        _hovered ? colors.hover : const Color(0x00000000),
        colors.inkMuted,
        const Color(0x00000000),
      ),
    };
    if (!selected) {
      return _pressedColors(theme, background, foreground, border);
    }
    final selectedBackground = switch (widget.tone) {
      BeautifulActionTone.secondary || BeautifulActionTone.quiet =>
        Color.alphaBlend(colors.accentTint, colors.surface),
      _ => background,
    };
    final selectedForeground = switch (widget.tone) {
      BeautifulActionTone.secondary ||
      BeautifulActionTone.quiet => colors.foregroundOn(selectedBackground),
      _ => foreground,
    };
    return _pressedColors(
      theme,
      selectedBackground,
      selectedForeground,
      selectedForeground,
    );
  }

  (Color, Color, Color) _pressedColors(
    BeautifulUiThemeData theme,
    Color background,
    Color foreground,
    Color border,
  ) {
    if (!_pressed) return (background, foreground, border);
    final base = Color.alphaBlend(background, theme.colors.surface);
    final ink = Color.alphaBlend(foreground, base);
    // Move away from the existing ink so the label stays readable throughout
    // the transition. The extra outline also distinguishes neutral fills at
    // the light/dark endpoint, where a color shift alone may be invisible.
    final endpoint = ink.computeLuminance() < base.computeLuminance()
        ? const Color(0xffffffff)
        : const Color(0xff000000);
    return (Color.lerp(base, endpoint, .12)!, foreground, border);
  }
}
