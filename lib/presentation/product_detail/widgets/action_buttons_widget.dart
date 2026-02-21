import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class ActionButtonsWidget extends StatelessWidget {
  final VoidCallback onSendMessage;
  final VoidCallback onBuyNow;

  const ActionButtonsWidget({
    super.key,
    required this.onSendMessage,
    required this.onBuyNow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: onSendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                  ),
                  child: const Text('Nachricht senden'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: onBuyNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successLight,
                  ),
                  child: const Text('Jetzt kaufen'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
