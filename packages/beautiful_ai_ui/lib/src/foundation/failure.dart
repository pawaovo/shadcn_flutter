import 'package:flutter/foundation.dart';

/// Identifies the user-facing operation that produced a recoverable failure.
enum BeautifulUiOperation {
  /// A recommendation action failed.
  recommendation,

  /// A clipboard write failed.
  clipboard,
}

/// A recoverable failure reported by a Beautiful AI UI module.
///
/// ```dart
/// final failure = BeautifulUiFailure(
///   operation: BeautifulUiOperation.clipboard,
///   message: 'Clipboard write failed.',
///   cause: StateError('unavailable'),
///   stackTrace: StackTrace.current,
/// );
/// ```
@immutable
final class BeautifulUiFailure implements Exception {
  /// Creates a normalized module failure.
  const BeautifulUiFailure({
    required this.operation,
    required this.message,
    required this.cause,
    required this.stackTrace,
  });

  /// The operation that failed.
  final BeautifulUiOperation operation;

  /// A stable diagnostic message intended for logs, not localized UI copy.
  final String message;

  /// The original error without platform-specific assumptions.
  final Object cause;

  /// The original stack trace.
  final StackTrace stackTrace;

  @override
  String toString() => 'BeautifulUiFailure(${operation.name}): $message';
}

/// Handles recoverable failures at the package root seam.
typedef BeautifulUiFailureHandler = void Function(BeautifulUiFailure failure);
