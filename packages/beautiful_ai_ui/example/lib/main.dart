import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(const _ExampleApp());
}

final class _ExampleApp extends StatelessWidget {
  const _ExampleApp();

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xff0285ff),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return const BeautifulUiScope(child: _ExampleHome());
      },
    );
  }
}

final class _ExampleHome extends StatefulWidget {
  const _ExampleHome();

  @override
  State<_ExampleHome> createState() => _ExampleHomeState();
}

final class _ExampleHomeState extends State<_ExampleHome> {
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
      color: theme.colors.page,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.xl),
            child: BeautifulLoadingState(
              label: 'Preparing workspace',
              elapsed: _stopwatch.elapsed,
            ),
          ),
        ),
      ),
    );
  }
}
