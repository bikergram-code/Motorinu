import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Native implementation — record audio to a temp file.
Future<void> startRecording(AudioRecorder recorder, void Function(String) setPath) async {
  try {
    final hasPerm = await recorder.hasPermission();
    debugPrint('[VoiceRec] hasPermission=$hasPerm');
    if (hasPerm) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      debugPrint('[VoiceRec] Recording to: $path');
      setPath(path);
      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      debugPrint('[VoiceRec] recorder.start() OK');
    } else {
      debugPrint('[VoiceRec] Permission denied!');
    }
  } catch (e, st) {
    debugPrint('[VoiceRec] Error: $e\n$st');
  }
}
