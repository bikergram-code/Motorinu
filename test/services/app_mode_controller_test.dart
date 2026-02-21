import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bikergram/services/app_mode_controller.dart';
import 'package:bikergram/services/kalman_filter.dart';

void main() {
  group('AppModeController', () {
    late ProviderContainer container;
    late AppModeController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(appModeProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    AppModeState readState() => container.read(appModeProvider);

    test('initial state is idle with follow camera and good GPS', () {
      expect(readState().mode, AppMode.idle);
      expect(readState().cameraMode, CameraMode.follow);
      expect(readState().locationQuality, LocationQuality.good);
      expect(readState().isIdle, true);
      expect(readState().isTracking, false);
    });

    test('enterDriving: idle → driving', () {
      controller.enterDriving();

      expect(readState().mode, AppMode.driving);
      expect(readState().cameraMode, CameraMode.follow);
      expect(readState().isDriving, true);
      expect(readState().isTracking, true);
    });

    test('enterDriving: ignored if not idle', () {
      controller.enterDriving();
      controller.enterNavigation();

      // Try to enter driving from navigating — should be ignored
      controller.enterDriving();
      expect(readState().mode, AppMode.navigating); // Still navigating
    });

    test('enterNavigation: any → navigating', () {
      controller.enterNavigation();

      expect(readState().mode, AppMode.navigating);
      expect(readState().cameraMode, CameraMode.follow);
      expect(readState().isNavigating, true);
      expect(readState().isTracking, true);
    });

    test('enterRoutePreview: idle → routePreview', () {
      controller.enterRoutePreview();

      expect(readState().mode, AppMode.routePreview);
      expect(readState().cameraMode, CameraMode.browse); // User reviews route freely
      expect(readState().isRoutePreview, true);
    });

    test('enterRoutePreview: ignored from navigating', () {
      controller.enterNavigation();
      controller.enterRoutePreview();

      expect(readState().mode, AppMode.navigating); // Should not change
    });

    test('exitNavigation: navigating → driving', () {
      controller.enterNavigation();
      controller.exitNavigation();

      expect(readState().mode, AppMode.driving);
      expect(readState().cameraMode, CameraMode.follow);
    });

    test('exitNavigation: ignored if not navigating', () {
      controller.enterDriving();
      controller.exitNavigation();

      expect(readState().mode, AppMode.driving); // Unchanged
    });

    test('exitToIdle: any → idle (full reset)', () {
      controller.enterNavigation();
      controller.onUserPan(); // Camera to browse
      controller.onQualityChange(LocationQuality.degraded);

      controller.exitToIdle();

      expect(readState().mode, AppMode.idle);
      expect(readState().cameraMode, CameraMode.follow);
      expect(readState().locationQuality, LocationQuality.good); // Reset to good
    });

    // ── Camera Mode ──

    test('onUserPan: follow → browse (only in tracking mode)', () {
      controller.enterDriving();
      controller.onUserPan();

      expect(readState().cameraMode, CameraMode.browse);
      expect(readState().isBrowsing, true);
      expect(readState().lastBrowseTime, isNotNull);
    });

    test('onUserPan: ignored if idle', () {
      controller.onUserPan();
      expect(readState().cameraMode, CameraMode.follow); // Unchanged
    });

    test('reCenter: browse → follow', () {
      controller.enterDriving();
      controller.onUserPan();
      expect(readState().isBrowsing, true);

      controller.reCenter();
      expect(readState().isFollowing, true);
      expect(readState().lastBrowseTime, isNull);
    });

    test('reCenter: ignored if already following', () {
      controller.enterDriving();
      // Already following, should be no-op
      controller.reCenter();
      expect(readState().isFollowing, true);
    });

    // ── Quality Updates ──

    test('onQualityChange updates quality', () {
      controller.onQualityChange(LocationQuality.degraded);
      expect(readState().locationQuality, LocationQuality.degraded);
      expect(readState().isGpsDegraded, true);

      controller.onQualityChange(LocationQuality.lost);
      expect(readState().locationQuality, LocationQuality.lost);
      expect(readState().isGpsLost, true);

      controller.onQualityChange(LocationQuality.good);
      expect(readState().locationQuality, LocationQuality.good);
      expect(readState().isGpsGood, true);
    });

    test('onQualityChange: no-op if same quality', () {
      controller.onQualityChange(LocationQuality.good);
      // Should not trigger state update (same value)
      expect(readState().locationQuality, LocationQuality.good);
    });

    // ── Full navigation lifecycle ──

    test('complete navigation lifecycle', () {
      // 1. Start idle
      expect(readState().isIdle, true);

      // 2. Enter route preview
      controller.enterRoutePreview();
      expect(readState().isRoutePreview, true);
      expect(readState().isBrowsing, true); // User reviews route

      // 3. Start navigation
      controller.enterNavigation();
      expect(readState().isNavigating, true);
      expect(readState().isFollowing, true); // Auto-follow

      // 4. User pans map
      controller.onUserPan();
      expect(readState().isBrowsing, true);

      // 5. GPS degrades
      controller.onQualityChange(LocationQuality.degraded);
      expect(readState().isGpsDegraded, true);

      // 6. Re-center
      controller.reCenter();
      expect(readState().isFollowing, true);

      // 7. GPS recovers
      controller.onQualityChange(LocationQuality.good);

      // 8. Stop navigation
      controller.exitNavigation();
      expect(readState().isDriving, true); // Falls back to driving

      // 9. Exit completely
      controller.exitToIdle();
      expect(readState().isIdle, true);
    });
  });
}
