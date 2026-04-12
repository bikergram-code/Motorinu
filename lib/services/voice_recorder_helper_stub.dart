import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Web stub — voice recording not available on web.
Future<void> startRecording(AudioRecorder recorder, void Function(String) setPath) async {
  debugPrint('[VoiceRecorder] Not available on web');
}
