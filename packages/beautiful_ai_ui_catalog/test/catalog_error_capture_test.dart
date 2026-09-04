import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/catalog_error_capture.dart';

void main() {
  test('records each error and forwards the identical details once', () {
    final original = FlutterError.onError;
    addTearDown(() => FlutterError.onError = original);
    final errors = <Map<String, Object?>>[];
    final forwarded = <FlutterErrorDetails>[];
    void previous(FlutterErrorDetails details) => forwarded.add(details);
    FlutterError.onError = previous;
    final restore = captureCatalogFlutterErrors(errors);
    final first = FlutterErrorDetails(
      exception: StateError('first error'),
      stack: StackTrace.fromString('first stack'),
      context: ErrorDescription('while editing the prompt'),
      library: 'first library',
    );
    final second = FlutterErrorDetails(
      exception: StateError('second error'),
      stack: StackTrace.fromString('second stack'),
      context: ErrorDescription('while closing the menu'),
      library: 'second library',
    );
    try {
      FlutterError.reportError(first);
      FlutterError.reportError(second);
    } finally {
      restore();
    }

    expect(FlutterError.onError, same(previous));
    expect(forwarded, <Matcher>[same(first), same(second)]);
    expect(errors, <Map<String, Object?>>[
      <String, Object?>{
        'exception': 'Bad state: first error',
        'stack': 'first stack',
        'context': 'while editing the prompt',
        'library': 'first library',
      },
      <String, Object?>{
        'exception': 'Bad state: second error',
        'stack': 'second stack',
        'context': 'while closing the menu',
        'library': 'second library',
      },
    ]);
    FlutterError.reportError(first);
    expect(forwarded, <Matcher>[same(first), same(second), same(first)]);
    expect(errors, hasLength(2));
  });

  test('preserves an exception thrown by the original handler', () {
    final original = FlutterError.onError;
    addTearDown(() => FlutterError.onError = original);
    final errors = <Map<String, Object?>>[];
    final sentinel = StateError('original reporter failure');
    final forwarded = <FlutterErrorDetails>[];
    FlutterError.onError = (details) {
      forwarded.add(details);
      throw sentinel;
    };
    final details = FlutterErrorDetails(
      exception: StateError('reported error'),
    );
    final restore = captureCatalogFlutterErrors(errors);
    Object? thrown;
    try {
      FlutterError.reportError(details);
    } catch (error) {
      thrown = error;
    } finally {
      restore();
      FlutterError.onError = original;
    }

    expect(thrown, same(sentinel));
    expect(forwarded, <Matcher>[same(details)]);
    expect(errors, hasLength(1));
    expect(errors.single['exception'], 'Bad state: reported error');
    expect(errors.single['stack'], isNull);
    expect(errors.single['context'], isNull);
  });
}
