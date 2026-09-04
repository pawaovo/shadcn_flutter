import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

const profileCheckpointExtension = 'ext.beautiful.profileCheckpoint';
const profileCheckpointEvent = 'beautiful.profileCheckpoint';

/// Durable host checkpoints are acknowledged before another workload starts.
/// Publication is only called outside measured windows. No polling/serialization
/// occurs during a valid measured interaction.
final class ProfileCheckpointPublisher {
  ProfileCheckpointPublisher({
    required this.reportData,
    this.timeout = const Duration(seconds: 15),
    this.notificationInterval = const Duration(milliseconds: 500),
    void Function(String, Map<String, Object?>)? postEvent,
  }) : _postEvent = postEvent ?? developer.postEvent;

  final Map<String, dynamic> Function() reportData;
  final Duration timeout;
  final Duration notificationInterval;
  final void Function(String, Map<String, Object?>) _postEvent;
  int _sequence = 0;
  int _lastAcknowledged = 0;
  String? _payload;
  Completer<void>? _ack;
  bool _terminal = false;

  void register() {
    developer.registerExtension(profileCheckpointExtension, (
      _,
      parameters,
    ) async {
      try {
        return developer.ServiceExtensionResponse.result(handle(parameters));
      } catch (error) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          error.toString(),
        );
      }
    });
  }

  String handle(Map<String, String> parameters) {
    final sequence = int.tryParse(parameters['sequence'] ?? '');
    if (parameters['action'] == 'ack' &&
        sequence != null &&
        sequence > 0 &&
        sequence <= _lastAcknowledged) {
      return jsonEncode(<String, Object?>{
        'schema_version': 1,
        'sequence': sequence,
        'acknowledged': true,
      });
    }
    if (sequence != _sequence || _payload == null || _ack == null) {
      throw StateError('No pending profile checkpoint for sequence $sequence.');
    }
    switch (parameters['action']) {
      case 'read':
        return _payload!;
      case 'ack':
        _lastAcknowledged = _sequence;
        if (!_ack!.isCompleted) _ack!.complete();
        return jsonEncode(<String, Object?>{
          'schema_version': 1,
          'sequence': _sequence,
          'acknowledged': true,
        });
      default:
        throw ArgumentError('Use read or ack.');
    }
  }

  Future<void> publish({required bool terminal}) async {
    if (_ack != null) {
      throw StateError('A profile checkpoint is still pending.');
    }
    _sequence++;
    _terminal = terminal;
    _payload = jsonEncode(<String, Object?>{
      'schema_version': 1,
      'sequence': _sequence,
      'terminal': terminal,
      'report_data': reportData(),
    });
    _ack = Completer<void>();
    void announce() {
      try {
        _postEvent(profileCheckpointEvent, <String, Object?>{
          'sequence': '$_sequence',
          'terminal': '$_terminal',
        });
      } catch (error, stack) {
        if (!_ack!.isCompleted) _ack!.completeError(error, stack);
      }
    }

    final notifications = Timer.periodic(
      notificationInterval,
      (_) => announce(),
    );
    try {
      final acknowledgement = _ack!.future.timeout(timeout);
      announce();
      await acknowledgement;
    } finally {
      notifications.cancel();
      _ack = null;
      _payload = null;
    }
  }
}
