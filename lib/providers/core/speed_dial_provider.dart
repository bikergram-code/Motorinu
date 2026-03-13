import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Speed-Dial Providers ────────────────────────────────────────────────────
//
// Global Speed-Dial system used by MainShell and individual tab screens.
// Each tab registers its own items in initState, MainShell renders them.

/// Speed-Dial open/close state (global, used by MainShell).
final blitzerSpeedDialProvider =
    NotifierProvider<SpeedDialNotifier, bool>(SpeedDialNotifier.new);

/// Simple notifier for Speed-Dial toggle.
class SpeedDialNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void open() => state = true;
  void close() => state = false;
}

// ─── Speed-Dial action items (registered per-tab) ───────────────────────────

/// A single Speed-Dial action item.
class SpeedDialItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const SpeedDialItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// Holds the current list of Speed-Dial items for the active tab.
/// Each tab screen registers its items in initState and clears in dispose.
final speedDialItemsProvider =
    NotifierProvider<SpeedDialItemsNotifier, List<SpeedDialItem>>(
        SpeedDialItemsNotifier.new);

class SpeedDialItemsNotifier extends Notifier<List<SpeedDialItem>> {
  @override
  List<SpeedDialItem> build() => [];

  void register(List<SpeedDialItem> items) => state = items;
  void clear() => state = [];
}
