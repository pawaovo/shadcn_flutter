import 'dart:js_interop';

@JS('globalThis.__beautifulInputAcceptance')
external set _state(JSAny? value);

@JS('globalThis.__beautifulInputAcknowledgement')
external JSString? get _acknowledgement;

@JS('globalThis.__beautifulInputAcknowledgement')
external set _acknowledgement(JSString? value);

void publishBrowserInputState(Map<String, Object?> state) {
  _state = state.jsify();
}

String? browserInputAcknowledgement() => _acknowledgement?.toDart;

void resetBrowserInputState() {
  _state = null;
  _acknowledgement = null;
}
