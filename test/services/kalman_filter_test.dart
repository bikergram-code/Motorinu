import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:bikergram/services/kalman_filter.dart';

/// Helper to create a Position with given values.
Position _pos({
  required double lat,
  required double lng,
  double speed = 0,
  double heading = 0,
  double accuracy = 10,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: heading,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0,
  );
}

void main() {
  group('KalmanFilter', () {
    late KalmanFilter filter;

    setUp(() {
      filter = KalmanFilter();
    });

    test('first update returns raw position', () {
      final pos = _pos(lat: 52.52, lng: 13.405);
      final result = filter.update(pos);

      expect(result.smoothedLat, 52.52);
      expect(result.smoothedLng, 13.405);
      expect(result.quality, LocationQuality.good);
    });

    test('reduces noise from jittery GPS at standstill', () {
      // Simulate standing still with noisy GPS
      const baseLat = 52.520;
      const baseLng = 13.405;

      // Feed 20 noisy positions around base point
      final offsets = [
        0.00003, -0.00002, 0.00004, -0.00001, 0.00002,
        -0.00003, 0.00001, -0.00004, 0.00003, -0.00002,
        0.00002, -0.00001, 0.00003, -0.00003, 0.00001,
        -0.00002, 0.00004, -0.00001, 0.00002, -0.00003,
      ];

      SmoothedPosition? lastResult;
      for (int i = 0; i < offsets.length; i++) {
        final pos = _pos(
          lat: baseLat + offsets[i],
          lng: baseLng + offsets[offsets.length - 1 - i],
          speed: 0,
          accuracy: 10,
        );
        lastResult = filter.update(pos);
      }

      // Smoothed position should be closer to base than average noise
      final latDiff = (lastResult!.smoothedLat - baseLat).abs();
      final lngDiff = (lastResult.smoothedLng - baseLng).abs();

      expect(latDiff, lessThan(0.00005)); // Should converge to center
      expect(lngDiff, lessThan(0.00005));
    });

    test('speed is smoothed (EMA) and near-zero clamped to 0', () {
      // First update at standstill
      filter.update(_pos(lat: 52.52, lng: 13.405, speed: 0));

      // Small noise readings at standstill
      var result = filter.update(_pos(lat: 52.52, lng: 13.405, speed: 0.5)); // 1.8 km/h
      expect(result.smoothedSpeed, lessThan(2.0)); // Should be clamped to 0

      result = filter.update(_pos(lat: 52.52, lng: 13.405, speed: 0.3)); // 1.08 km/h
      expect(result.smoothedSpeed, 0); // Near-zero clamp
    });

    test('speed reflects actual movement', () {
      // Start
      filter.update(_pos(lat: 52.520, lng: 13.405, speed: 0));

      // Moving at 50 km/h = ~13.9 m/s
      for (int i = 0; i < 10; i++) {
        filter.update(_pos(
          lat: 52.520 + i * 0.0001,
          lng: 13.405,
          speed: 13.9,
          accuracy: 5,
        ));
      }

      final result = filter.update(_pos(
        lat: 52.521,
        lng: 13.405,
        speed: 13.9,
        accuracy: 5,
      ));

      // Should show meaningful speed (close to 50 km/h)
      expect(result.smoothedSpeed, greaterThan(20));
    });

    test('handles GPS jump (>500m) by resetting', () {
      // Initial position
      filter.update(_pos(lat: 52.520, lng: 13.405));

      // Normal nearby position
      final normal = filter.update(_pos(lat: 52.5201, lng: 13.4051));
      expect(normal.smoothedLat, closeTo(52.5201, 0.001));

      // Huge jump (Berlin → Munich, >500km)
      final jumped = filter.update(_pos(lat: 48.137, lng: 11.576));

      // Should have reset — position should be close to the new location
      expect(jumped.smoothedLat, closeTo(48.137, 0.01));
      expect(jumped.smoothedLng, closeTo(11.576, 0.01));
    });

    test('LocationQuality: good when accuracy <= 15m', () {
      final result = filter.update(_pos(lat: 52.52, lng: 13.405, accuracy: 10));
      expect(result.quality, LocationQuality.good);
    });

    test('LocationQuality: degraded when accuracy 15-50m', () {
      final result = filter.update(_pos(lat: 52.52, lng: 13.405, accuracy: 30));
      expect(result.quality, LocationQuality.degraded);
    });

    test('LocationQuality: lost when accuracy > 50m', () {
      final result = filter.update(_pos(lat: 52.52, lng: 13.405, accuracy: 100));
      expect(result.quality, LocationQuality.lost);
    });

    test('heading smoothing handles 360/0 wrap-around', () {
      // Start heading north (0°)
      filter.update(_pos(lat: 52.52, lng: 13.405, heading: 350));

      // Turn slightly past north to 10°
      final result = filter.update(_pos(lat: 52.52, lng: 13.405, heading: 10));

      // Smoothed heading should be near 0° (not 180° average!)
      // With alpha=0.4: result should be between 350 and 10
      expect(result.smoothedHeading, anyOf(
        greaterThan(340), // Near 360 wrapping
        lessThan(20),     // Near 0
      ));
    });

    test('reset clears state and next update acts as first', () {
      filter.update(_pos(lat: 52.52, lng: 13.405));
      filter.update(_pos(lat: 52.521, lng: 13.406));

      filter.reset();

      // After reset, next position should be returned as-is
      final result = filter.update(_pos(lat: 48.0, lng: 11.0));
      expect(result.smoothedLat, 48.0);
      expect(result.smoothedLng, 11.0);
    });

    test('higher accuracy GPS gets more weight', () {
      // Initialize
      filter.update(_pos(lat: 52.520, lng: 13.405, accuracy: 10));

      // Update with high accuracy (5m) — should be strongly weighted
      final highAcc = filter.update(_pos(
        lat: 52.521, lng: 13.406, accuracy: 5,
      ));

      // Reset and try with low accuracy
      filter.reset();
      filter.update(_pos(lat: 52.520, lng: 13.405, accuracy: 10));
      final lowAcc = filter.update(_pos(
        lat: 52.521, lng: 13.406, accuracy: 100,
      ));

      // High accuracy should move closer to new position than low accuracy
      final highDist = (highAcc.smoothedLat - 52.521).abs();
      final lowDist = (lowAcc.smoothedLat - 52.521).abs();

      expect(highDist, lessThan(lowDist));
    });
  });
}
