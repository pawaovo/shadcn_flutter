import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';

void main() => runApp(const HostedConsumerApp());

/// The consumer imports only published package entry points.
final class HostedConsumerApp extends StatelessWidget {
  const HostedConsumerApp({super.key});

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xff0285ff),
    builder: (context, child) => const BeautifulUiScope(
      motion: BeautifulMotionPolicy.none,
      child: Center(
        child: BeautifulLoadingState(label: 'Hosted package connected'),
      ),
    ),
  );
}
