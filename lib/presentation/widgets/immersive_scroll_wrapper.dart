import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../providers/navigation_state.dart';

/// Wraps a scrollable child and toggles bar visibility on scroll direction.
/// Scroll down → hide bars (fullscreen). Scroll up → show bars.
class ImmersiveScrollWrapper extends StatelessWidget {
  const ImmersiveScrollWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
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
        return false;
      },
      child: child,
    );
  }
}
