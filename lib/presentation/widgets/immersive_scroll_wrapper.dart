import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../providers/navigation_state.dart';

/// Wraps a scrollable child and toggles bar visibility on scroll direction.
/// Scroll down → hide bars (fullscreen). Scroll up → show bars.
/// Consumes notifications so parent FeedScreen listener doesn't conflict.
class ImmersiveScrollWrapper extends StatelessWidget {
  const ImmersiveScrollWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Am oberen Rand angekommen → Bars IMMER einblenden
        if (notification.metrics.pixels <= 0) {
          if (NavigationState.instance.feedScrolling) {
            NavigationState.instance.setFeedScrolling(false);
          }
          return true; // consumed
        }

        if (notification is UserScrollNotification) {
          if (notification.direction == ScrollDirection.forward) {
            // Finger moves down → content scrolls up → show bars
            if (NavigationState.instance.feedScrolling) {
              NavigationState.instance.setFeedScrolling(false);
            }
          } else if (notification.direction == ScrollDirection.reverse) {
            // Finger moves up → content scrolls down → hide bars
            if (!NavigationState.instance.feedScrolling) {
              NavigationState.instance.setFeedScrolling(true);
            }
          }
        }

        return true; // consume — don't let FeedScreen's listener interfere
      },
      child: child,
    );
  }
}
