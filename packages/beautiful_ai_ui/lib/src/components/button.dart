import 'package:flutter/widgets.dart';

import '../foundation/layout.dart';
import '../implementation/controls/action_control.dart';

/// Semantic emphasis shared by text and icon actions.
enum BeautifulButtonTone {
  /// The primary action in the surrounding context.
  primary,

  /// A neutral action with a visible surface and outline.
  secondary,

  /// A low-emphasis action that reveals its surface on hover.
  quiet,

  /// A positive or completed action.
  success,

  /// An action that removes or discards something.
  destructive,
}

/// A themed action with shared pointer, keyboard, and accessible behavior.
///
/// Compact density changes the painted control without reducing touch targets
/// on mobile platforms or viewports with a short side below 600 pixels.
final class BeautifulButton extends StatelessWidget {
  /// Creates a text action. A null [onPressed] displays its disabled state.
  const BeautifulButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = BeautifulButtonTone.secondary,
    this.leading,
    this.trailing,
    this.density = BeautifulUiDensity.comfortable,
    this.alignment = TextAlign.center,
    this.fullWidth = false,
    this.selected,
  }) : assert(label != '');

  /// Complete visible and accessible label.
  final String label;

  /// Host action, or null when unavailable.
  final VoidCallback? onPressed;

  /// Semantic visual emphasis.
  final BeautifulButtonTone tone;

  /// Optional visual before the label.
  final Widget? leading;

  /// Optional visual after the label.
  final Widget? trailing;

  /// Spacing and visual size of the control.
  final BeautifulUiDensity density;

  /// Text alignment when the control has extra horizontal space.
  final TextAlign alignment;

  /// Whether the action fills its parent's available width.
  final bool fullWidth;

  /// Optional host-owned selection state, also exposed to assistive tools.
  final bool? selected;

  @override
  Widget build(BuildContext context) => BeautifulActionControl(
    label: label,
    onPressed: onPressed,
    tone: _tone(tone),
    leading: leading,
    trailing: trailing,
    density: density,
    labelAlignment: alignment,
    fullWidth: fullWidth,
    selected: selected,
  );
}

/// An icon action with a complete accessible name and hover/long-press tooltip.
final class BeautifulIconButton extends StatelessWidget {
  /// Creates an icon action without reserving space for a visible text label.
  const BeautifulIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = BeautifulButtonTone.quiet,
    this.density = BeautifulUiDensity.comfortable,
    this.selected,
  }) : assert(label != '');

  /// Accessible name and tooltip describing the action.
  final String label;

  /// Icon shown in the control.
  final IconData icon;

  /// Host action, or null when unavailable.
  final VoidCallback? onPressed;

  /// Semantic visual emphasis.
  final BeautifulButtonTone tone;

  /// Spacing and visual size of the control.
  final BeautifulUiDensity density;

  /// Optional host-owned selection state.
  final bool? selected;

  @override
  Widget build(BuildContext context) => BeautifulActionControl(
    label: label,
    onPressed: onPressed,
    tone: _tone(tone),
    leading: Icon(icon),
    iconOnly: true,
    density: density,
    selected: selected,
  );
}

BeautifulActionTone _tone(BeautifulButtonTone tone) => switch (tone) {
  BeautifulButtonTone.primary => BeautifulActionTone.primary,
  BeautifulButtonTone.secondary => BeautifulActionTone.secondary,
  BeautifulButtonTone.quiet => BeautifulActionTone.quiet,
  BeautifulButtonTone.success => BeautifulActionTone.success,
  BeautifulButtonTone.destructive => BeautifulActionTone.destructive,
};
