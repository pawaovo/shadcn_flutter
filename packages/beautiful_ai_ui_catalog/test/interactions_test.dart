import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/interactions.dart';

void main() {
  testWidgets('waits through obstruction and reflow before one activation', (
    tester,
  ) async {
    var activations = 0;
    var obstructionTaps = 0;
    double? activatedAt;
    final fixture = GlobalKey<_ReflowingTargetState>();
    await tester.pumpWidget(
      _ReflowingTarget(
        key: fixture,
        onTap: (offset) {
          activations++;
          activatedAt = offset;
        },
        onObstructionTap: () => obstructionTaps++,
      ),
    );
    final target = find.text('Delayed citation');
    fixture.currentState!.startReflow();

    // The previous reveal + one pump finds a mounted target whose center is
    // still covered. Sending that pointer reaches the obstruction, not the link.
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pump();
    expect(target, findsOneWidget);
    expect(target.hitTestable(), findsNothing);
    await tester.tapAt(tester.getCenter(target));
    expect(activations, 0);
    expect(obstructionTaps, 1);

    await tapCatalogTarget(tester, target);
    expect(activations, 1);
    expect(obstructionTaps, 1);
    // It becomes hit-testable while still moving; activation must wait until
    // the six reflow frames finish, rather than merely finding an uncovered link.
    expect(activatedAt, 72);
    expect(fixture.currentState!.reflowFrames, 6);
    await tester.pump(const Duration(milliseconds: 80));
    expect(activations, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('persistent obstruction fails without sending a pointer', (
    tester,
  ) async {
    var activations = 0;
    var obstructionTaps = 0;
    await tester.pumpWidget(
      _ReflowingTarget(
        onTap: (_) => activations++,
        onObstructionTap: () => obstructionTaps++,
      ),
    );
    final target = find.text('Delayed citation');
    await expectLater(
      tapCatalogTarget(
        tester,
        target,
        timeout: const Duration(milliseconds: 80),
      ),
      throwsA(
        isA<TestFailure>().having(
          (failure) => failure.message,
          'diagnostic',
          contains('center is not hit-testable'),
        ),
      ),
    );
    expect(target, findsOneWidget);
    expect(activations, 0);
    expect(obstructionTaps, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

final class _ReflowingTarget extends StatefulWidget {
  const _ReflowingTarget({
    super.key,
    required this.onTap,
    required this.onObstructionTap,
  });

  final ValueChanged<double> onTap;
  final VoidCallback onObstructionTap;

  @override
  State<_ReflowingTarget> createState() => _ReflowingTargetState();
}

final class _ReflowingTargetState extends State<_ReflowingTarget> {
  Timer? _timer;
  var reflowFrames = 0;

  void startReflow() {
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() => reflowFrames++);
      if (reflowFrames == 6) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: SingleChildScrollView(
      child: Column(
        children: <Widget>[
          const SizedBox(height: 1000),
          SizedBox(
            height: 100,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: reflowFrames * 12,
                  top: 20,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onTap(reflowFrames * 12),
                    child: const SizedBox(
                      width: 220,
                      height: 48,
                      child: Center(child: Text('Delayed citation')),
                    ),
                  ),
                ),
                if (reflowFrames < 3)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onObstructionTap,
                      child: const ColoredBox(color: Color(0xffffffff)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 1000),
        ],
      ),
    ),
  );
}
