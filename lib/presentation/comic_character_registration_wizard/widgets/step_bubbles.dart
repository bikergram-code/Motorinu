import 'package:flutter/material.dart';
import 'comic_speech_bubble.dart';

String bikergramDisplayName(String raw) {
  final n = raw.trim();
  if (n.isEmpty) return '';
  final first = n.split(RegExp(r'\s+')).first;
  return first;
}

String bikergramGreet(String userName) {
  final n = bikergramDisplayName(userName);
  return n.isEmpty ? 'Hey!' : 'Hey $n!';
}

/// Main bubble + optional red warning bubble (shown only when showError is true).
class StepBubbles extends StatelessWidget {
  final String mainText;
  final bool showError;
  final String errorText;
  final bool tailOnRight;

  const StepBubbles({
    super.key,
    required this.mainText,
    this.showError = false,
    this.errorText = '',
    this.tailOnRight = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComicSpeechBubble(
          text: mainText,
          tailOnRight: tailOnRight,
          enableTypewriter: true,
        ),
        if (showError && errorText.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          ComicSpeechBubble(
            text: errorText,
            tailOnRight: tailOnRight,
            enableTypewriter: true,
            bubbleColor: const Color(0xFFFFE8E8),
            borderColor: const Color(0xFFE53935),
            opacity: 0.98,
          ),
        ],
      ],
    );
  }
}
