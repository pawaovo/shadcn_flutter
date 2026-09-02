import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

SemanticsHandle? _semanticsHandle;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('ENABLE_WEB_SEMANTICS')) {
    _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
    assert(_semanticsHandle != null);
  }
  runApp(const CatalogApp());
}

/// Multi-platform catalog for the Beautiful AI UI package.
final class CatalogApp extends StatefulWidget {
  /// Creates the catalog application.
  const CatalogApp({super.key});

  @override
  State<CatalogApp> createState() => _CatalogAppState();
}

final class _CatalogAppState extends State<CatalogApp> {
  var _themeMode = BeautifulUiThemeMode.system;
  var _motion = BeautifulMotionPolicy.system;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xff0285ff),
      debugShowCheckedModeBanner: false,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyD, meta: true):
            _ToggleThemeIntent(),
      },
      actions: <Type, Action<Intent>>{
        _ToggleThemeIntent: CallbackAction<_ToggleThemeIntent>(
          onInvoke: (_) {
            _cycleTheme();
            return null;
          },
        ),
      },
      builder: (context, child) {
        return BeautifulUiScope(
          themeMode: _themeMode,
          motion: _motion,
          child: _CatalogHome(
            themeMode: _themeMode,
            motion: _motion,
            onThemePressed: _cycleTheme,
            onMotionPressed: _cycleMotion,
          ),
        );
      },
    );
  }

  void _cycleTheme() {
    setState(() {
      _themeMode = switch (_themeMode) {
        BeautifulUiThemeMode.system => BeautifulUiThemeMode.light,
        BeautifulUiThemeMode.light => BeautifulUiThemeMode.dark,
        BeautifulUiThemeMode.dark => BeautifulUiThemeMode.system,
      };
    });
  }

  void _cycleMotion() {
    setState(() {
      _motion = switch (_motion) {
        BeautifulMotionPolicy.system => BeautifulMotionPolicy.reduced,
        BeautifulMotionPolicy.reduced => BeautifulMotionPolicy.none,
        BeautifulMotionPolicy.none => BeautifulMotionPolicy.system,
      };
    });
  }
}

final class _ToggleThemeIntent extends Intent {
  const _ToggleThemeIntent();
}

final class _CatalogHome extends StatefulWidget {
  const _CatalogHome({
    required this.themeMode,
    required this.motion,
    required this.onThemePressed,
    required this.onMotionPressed,
  });

  final BeautifulUiThemeMode themeMode;
  final BeautifulMotionPolicy motion;
  final VoidCallback onThemePressed;
  final VoidCallback onMotionPressed;

  @override
  State<_CatalogHome> createState() => _CatalogHomeState();
}

final class _CatalogHomeState extends State<_CatalogHome> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return ColoredBox(
      color: theme.colors.canvas,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 900;
            return Column(
              children: <Widget>[
                _CatalogHeader(
                  themeMode: widget.themeMode,
                  motion: widget.motion,
                  onThemePressed: widget.onThemePressed,
                  onMotionPressed: widget.onMotionPressed,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(theme.spacing.xl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: horizontal
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(child: _firstColumn(theme)),
                                SizedBox(width: theme.spacing.lg),
                                Expanded(child: _secondColumn(theme)),
                              ],
                            )
                          : Column(
                              children: <Widget>[
                                _firstColumn(theme),
                                SizedBox(height: theme.spacing.lg),
                                _secondColumn(theme),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _firstColumn(BeautifulUiThemeData theme) {
    return Column(
      children: <Widget>[
        _CatalogCard(
          title: 'Drive',
          caption: 'Square-cell chevron wavefront',
          child: BeautifulLoadingState(
            label: 'Preparing workspace',
            elapsed: _stopwatch.elapsed,
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        _CatalogCard(
          title: 'Dots',
          caption: 'Circular-cell chevron wavefront',
          child: BeautifulLoadingState(
            label: 'Indexing sources',
            variant: BeautifulLoadingVariant.dots,
            elapsed: _stopwatch.elapsed,
          ),
        ),
      ],
    );
  }

  Widget _secondColumn(BeautifulUiThemeData theme) {
    return Column(
      children: <Widget>[
        _CatalogCard(
          title: 'Orbit',
          caption: 'A pixel comet follows the perimeter',
          child: BeautifulLoadingState(
            label: 'Checking dependencies',
            variant: BeautifulLoadingVariant.orbit,
            elapsed: _stopwatch.elapsed,
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        _CatalogCard(
          title: 'Surfer',
          caption: 'License-safe, zero-network media fallback',
          child: BeautifulLoadingState(
            label: 'Running a long task',
            variant: BeautifulLoadingVariant.surfer,
            elapsed: _stopwatch.elapsed,
            surferFallbackLabel: 'Provide licensed media from the host app',
          ),
        ),
      ],
    );
  }
}

final class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.themeMode,
    required this.motion,
    required this.onThemePressed,
    required this.onMotionPressed,
  });

  final BeautifulUiThemeMode themeMode;
  final BeautifulMotionPolicy motion;
  final VoidCallback onThemePressed;
  final VoidCallback onMotionPressed;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return ColoredBox(
      color: theme.colors.page,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colors.line)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final title = Text(
              'Beautiful AI UI · Loading State',
              style: theme.typography.label.copyWith(
                color: theme.colors.ink,
                fontSize: 15,
              ),
            );
            final controls = Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                _CatalogButton(
                  label: 'Theme: ${themeMode.name}',
                  onPressed: onThemePressed,
                ),
                _CatalogButton(
                  label: 'Motion: ${motion.name}',
                  onPressed: onMotionPressed,
                ),
              ],
            );
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xl,
                vertical: theme.spacing.md,
              ),
              child: constraints.maxWidth < 700
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        title,
                        SizedBox(height: theme.spacing.sm),
                        controls,
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(child: title),
                        controls,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

final class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.title,
    required this.caption,
    required this.child,
  });

  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.lg),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.line),
        borderRadius: BorderRadius.circular(theme.radii.card),
        boxShadow: theme.shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.typography.label.copyWith(color: theme.colors.ink),
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            caption,
            style: theme.typography.caption.copyWith(
              color: theme.colors.inkMuted,
            ),
          ),
          SizedBox(height: theme.spacing.xl),
          child,
        ],
      ),
    );
  }
}

final class _CatalogButton extends StatefulWidget {
  const _CatalogButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_CatalogButton> createState() => _CatalogButtonState();
}

final class _CatalogButtonState extends State<_CatalogButton> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: widget.label,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _hovered ? theme.colors.hover : theme.colors.surface,
              border: Border.all(
                color: _focused ? theme.colors.accent : theme.colors.lineStrong,
                width: _focused ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(theme.radii.control),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.md,
                  vertical: theme.spacing.sm,
                ),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
