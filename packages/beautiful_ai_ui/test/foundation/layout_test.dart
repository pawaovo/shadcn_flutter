import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeautifulUiBreakpoints', () {
    const breakpoints = BeautifulUiBreakpoints();

    test('resolves compact around the lower threshold', () {
      expect(breakpoints.resolve(0), BeautifulLayoutMode.compact);
      expect(breakpoints.resolve(599), BeautifulLayoutMode.compact);
      expect(breakpoints.resolve(599.999), BeautifulLayoutMode.compact);
    });

    test('resolves medium at 600 through 1023 logical pixels', () {
      expect(breakpoints.resolve(600), BeautifulLayoutMode.medium);
      expect(breakpoints.resolve(1023), BeautifulLayoutMode.medium);
      expect(breakpoints.resolve(1023.999), BeautifulLayoutMode.medium);
    });

    test('resolves expanded at 1024 logical pixels', () {
      expect(breakpoints.resolve(1024), BeautifulLayoutMode.expanded);
      expect(breakpoints.resolve(1440), BeautifulLayoutMode.expanded);
    });
  });
}
