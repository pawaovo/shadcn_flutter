import 'package:flutter/foundation.dart';

/// Records errors before the test binding can replace them with an aggregate.
///
/// Install inside the test body and register the returned callback with
/// addTearDown, so uncaught assertions remain observable after the body unwinds.
VoidCallback captureCatalogFlutterErrors(List<Map<String, Object?>> errors) {
  final previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      errors.add(<String, Object?>{
        'exception': details.exceptionAsString(),
        'stack': details.stack?.toString(),
        'context': details.context?.toDescription(),
        'library': details.library,
      });
    } finally {
      // Forward the original details exactly once, even if recording fails.
      // The binding still owns reporting, aggregation, and failing the test.
      previous?.call(details);
    }
  };
  return () => FlutterError.onError = previous;
}
