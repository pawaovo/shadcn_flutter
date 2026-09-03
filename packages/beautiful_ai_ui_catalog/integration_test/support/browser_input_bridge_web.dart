import 'dart:js_interop';

// Use the same page window as WebDriver. Firefox executes driver scripts in a
// separate global scope, so globalThis writes there do not acknowledge here.
@JS('window.__beautifulInputAcceptance')
external set _state(JSAny? value);

@JS('window.__beautifulInputAcknowledgement')
external JSString? get _acknowledgement;

@JS('window.__beautifulInputAcknowledgement')
external set _acknowledgement(JSString? value);

void publishBrowserInputState(Map<String, Object?> state) {
  _state = state.jsify();
}

String? browserInputAcknowledgement() => _acknowledgement?.toDart;

void resetBrowserInputState() {
  _state = null;
  _acknowledgement = null;
}
