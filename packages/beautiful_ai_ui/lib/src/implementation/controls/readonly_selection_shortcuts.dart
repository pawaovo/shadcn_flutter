import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Uses the editor's SDK actions for horizontal read-only selection on Web.
///
/// The document host applies this adapter only on Web. Keeping it independent
/// of platform detection lets tests exercise the exact adapter against the
/// browser-default shortcut policy without changing the host's native behavior.
final class BeautifulReadonlySelectionShortcuts extends StatelessWidget {
  /// Creates a shortcut scope around one read-only document editor.
  const BeautifulReadonlySelectionShortcuts({super.key, required this.child});

  /// The document whose existing EditableText Actions perform selection.
  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(
        LogicalKeyboardKey.arrowLeft,
      ): ExtendSelectionByCharacterIntent(
        forward: false,
        collapseSelection: true,
      ),
      SingleActivator(
        LogicalKeyboardKey.arrowRight,
      ): ExtendSelectionByCharacterIntent(
        forward: true,
        collapseSelection: true,
      ),
      SingleActivator(
        LogicalKeyboardKey.arrowLeft,
        shift: true,
      ): ExtendSelectionByCharacterIntent(
        forward: false,
        collapseSelection: false,
      ),
      SingleActivator(
        LogicalKeyboardKey.arrowRight,
        shift: true,
      ): ExtendSelectionByCharacterIntent(
        forward: true,
        collapseSelection: false,
      ),
    },
    child: child,
  );
}
