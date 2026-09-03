import 'package:flutter/widgets.dart';

import '../../foundation/theme.dart';
import '../controls/text_selection.dart';

/// A selectable, naturally wrapping snapshot without simulated token timing.
///
/// Only the adjacent status is a live region. Replacing this content therefore
/// does not request a full-answer announcement for every incoming chunk.
final class BeautifulStreamContent extends StatefulWidget {
  /// Creates the internal text rendering module.
  const BeautifulStreamContent({
    super.key,
    required this.span,
    required this.copyLabel,
    required this.onCopy,
  });

  /// Exact text and citation markers supplied by the owning composite.
  final TextSpan span;

  /// Localized text-selection toolbar action.
  final String copyLabel;

  /// Copy action shared with the owning composite's failure handling.
  final ValueChanged<String> onCopy;

  @override
  State<BeautifulStreamContent> createState() => _BeautifulStreamContentState();
}

final class _BeautifulStreamContentState extends State<BeautifulStreamContent> {
  final _focus = FocusNode();
  String _selectedText = '';

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final text = Text.rich(
      widget.span,
      style: theme.typography.body.copyWith(
        color: theme.colors.ink,
        height: 1.7,
      ),
      selectionColor: theme.colors.accentTint,
    );
    // Selection overlays need the app's Overlay (normally WidgetsApp). Plain
    // embedding still displays the exact snapshot, like Code Block does.
    if (Overlay.maybeOf(context) == null) return text;
    final region = SelectableRegion(
      focusNode: _focus,
      selectionControls: BeautifulTextSelectionControls(theme.colors.accent),
      onSelectionChanged: (content) => _selectedText = content?.plainText ?? '',
      contextMenuBuilder: (context, selection) {
        return beautifulTextSelectionToolbar(
          context,
          anchors: selection.contextMenuAnchors,
          buttons: [
            if (_selectedText.isNotEmpty)
              ContextMenuButtonItem(
                type: ContextMenuButtonType.copy,
                label: widget.copyLabel,
                onPressed: () {
                  widget.onCopy(_selectedText);
                  selection.hideToolbar();
                },
              ),
          ],
        );
      },
      child: text,
    );
    // SelectableRegion deliberately makes this action overridable. Route
    // keyboard copying through the same host callback as the touch toolbar.
    return Actions(
      actions: <Type, Action<Intent>>{
        CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
          onInvoke: (_) {
            if (_selectedText.isNotEmpty) widget.onCopy(_selectedText);
            return null;
          },
        ),
      },
      child: region,
    );
  }
}
