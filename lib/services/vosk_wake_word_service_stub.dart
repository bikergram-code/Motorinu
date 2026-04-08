/// Events emitted by VoskWakeWordService.
enum VoskWakeEvent {
  wakeWordDetected,
  commandRecognized,
  commandTimeout,
}

/// Web stub — voice recognition not available on web.
class VoskWakeWordService {
  VoskWakeWordService._();
  static final instance = VoskWakeWordService._();

  bool directListenMode = false;
  void Function(VoskWakeEvent event, String text)? onEvent;

  bool get isListening => false;
  bool get isInitialized => false;
  bool get isWakeWordTriggered => false;

  Future<bool> init() async => false;
  Future<void> startListening() async {}
  Future<void> stopListening() async {}
  Future<void> setPaused(bool paused) async {}
  void dispose() {}
}
