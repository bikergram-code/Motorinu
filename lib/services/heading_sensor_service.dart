import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Fuses gyroscope, GPS heading, and magnetometer+accelerometer for Waze-level
/// smooth camera rotation during navigation.
///
/// - Gyroscope: instant rotation rate at ~50Hz (Z-axis = yaw)
/// - GPS heading: drift-free but slow (~1Hz), used for correction
/// - Magnetometer+Accelerometer: tilt-compensated compass heading (fallback < 3 km/h)
///
/// The magnetometer heading uses the full rotation matrix approach
/// (equivalent to Android's SensorManager.getRotationMatrix + getOrientation)
/// so it works correctly regardless of how the phone is tilted or mounted.
///
/// Algorithm: Complementary filter
///   fusedHeading = α * (prev + gyroRate × dt) + (1-α) * reference
///   α = 0.98 while moving (trust gyro), α = 0.80-0.85 while stationary (trust compass)
class HeadingSensorService {
  HeadingSensorService._();
  static final instance = HeadingSensorService._();

  // ── Output ──
  final _controller = StreamController<double>.broadcast();
  Stream<double> get headingStream => _controller.stream;
  double get currentHeading => _fusedHeading;
  bool get isGyroAvailable => _gyroAvailable;

  // ── Fused state ──
  double _fusedHeading = 0;
  bool _initialized = false; // Wait for first GPS heading before fusing

  // ── Gyroscope ──
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  DateTime _lastGyroTime = DateTime.now();
  bool _gyroAvailable = false;
  double _gyroZBias = 0; // Estimated Z-axis bias (drift per second)

  // ── Gyro bias calibration (when stationary) ──
  double _biasAccumulator = 0;
  int _biasSampleCount = 0;
  static const _biasCalibrationSamples = 50; // ~1 second at 50Hz

  // ── GPS ──
  double _gpsHeading = 0;
  double _gpsSpeed = 0; // km/h

  // ── Magnetometer (tilt-compensated via accelerometer) ──
  StreamSubscription<MagnetometerEvent>? _magnetSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double? _magnetHeading;
  double _magnetSmoothed = 0;
  bool _magnetInitialized = false;

  // Latest accelerometer values for tilt compensation
  double _accelX = 0, _accelY = 0, _accelZ = 9.81;
  // Latest magnetometer raw values
  double _magX = 0, _magY = 0, _magZ = 0;
  bool _hasMagData = false;

  // ── Lifecycle (reference-counted for multi-screen use) ──
  bool _running = false;
  int _refCount = 0;

  /// Start listening to gyroscope, magnetometer, and accelerometer.
  /// Reference-counted: multiple callers can call start()/stop() safely.
  void start() {
    _refCount++;
    if (_running) return;
    if (kIsWeb) return; // Sensors not available on web
    _running = true;

    // Gyroscope stream (~50Hz = gameInterval)
    try {
      _gyroSub = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        _onGyroEvent,
        onError: (e) {
          debugPrint('[HeadingSensor] Gyro not available: $e');
          _gyroAvailable = false;
        },
      );
      _gyroAvailable = true;
      _lastGyroTime = DateTime.now();
      debugPrint('[HeadingSensor] Gyroscope started');
    } catch (e) {
      debugPrint('[HeadingSensor] Gyro init error: $e');
      _gyroAvailable = false;
    }

    // Accelerometer stream (~15Hz for tilt compensation)
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen(
        (event) {
          _accelX = event.x;
          _accelY = event.y;
          _accelZ = event.z;
        },
        onError: (e) {
          debugPrint('[HeadingSensor] Accelerometer not available: $e');
        },
      );
      debugPrint('[HeadingSensor] Accelerometer started');
    } catch (e) {
      debugPrint('[HeadingSensor] Accelerometer init error: $e');
    }

    // Magnetometer stream (~15Hz = uiInterval)
    try {
      _magnetSub = magnetometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen(
        _onMagnetEvent,
        onError: (e) {
          debugPrint('[HeadingSensor] Magnetometer not available: $e');
        },
      );
      debugPrint('[HeadingSensor] Magnetometer started');
    } catch (e) {
      debugPrint('[HeadingSensor] Magnetometer init error: $e');
    }
  }

  /// Stop sensor subscriptions (reference-counted).
  /// Only actually stops when all callers have called stop().
  void stop() {
    _refCount--;
    if (_refCount > 0) {
      debugPrint('[HeadingSensor] stop() called but $_refCount refs remain — keeping alive');
      return;
    }
    _refCount = 0; // Clamp to 0
    _gyroSub?.cancel();
    _gyroSub = null;
    _magnetSub?.cancel();
    _magnetSub = null;
    _accelSub?.cancel();
    _accelSub = null;
    _running = false;
    debugPrint('[HeadingSensor] Stopped (all refs released)');
  }

  /// Dispose permanently (ignores ref count).
  void dispose() {
    _refCount = 0;
    _running = false;
    _gyroSub?.cancel();
    _gyroSub = null;
    _magnetSub?.cancel();
    _magnetSub = null;
    _accelSub?.cancel();
    _accelSub = null;
    _controller.close();
  }

  /// Feed GPS heading and speed from the GPS listener.
  /// Call this on every GPS fix.
  void updateFromGps({required double gpsHeading, required double speedKmh}) {
    _gpsSpeed = speedKmh;

    if (gpsHeading < 0) return; // Invalid heading

    _gpsHeading = gpsHeading;

    // Initialize fused heading from first valid GPS fix
    if (!_initialized) {
      _fusedHeading = gpsHeading;
      _initialized = true;
      _controller.add(_fusedHeading);
      debugPrint('[HeadingSensor] Initialized from GPS: ${gpsHeading.toStringAsFixed(1)}°');
      return;
    }

    // If gyro is not available, just pass through GPS heading
    if (!_gyroAvailable) {
      _fusedHeading = gpsHeading;
      _controller.add(_fusedHeading);
      return;
    }

    // Drift correction burst: if divergence > 15° while moving, snap closer
    if (speedKmh > 3) {
      double diff = _angleDiff(_fusedHeading, gpsHeading);
      if (diff.abs() > 15) {
        _fusedHeading = _complementaryFilter(_fusedHeading, gpsHeading, alpha: 0.5);
        debugPrint('[HeadingSensor] Drift correction: ${diff.toStringAsFixed(1)}° → snapped to ${_fusedHeading.toStringAsFixed(1)}°');
      }
    }
  }

  // ── Gyroscope callback ──
  void _onGyroEvent(GyroscopeEvent event) {
    final now = DateTime.now();
    final dt = now.difference(_lastGyroTime).inMicroseconds / 1e6;
    _lastGyroTime = now;

    // Ignore unreasonable dt (first event, app resume, etc.)
    if (dt <= 0 || dt > 0.5) return;

    // Initialize from magnetometer if GPS hasn't provided a fix yet
    if (!_initialized) {
      if (_magnetHeading != null) {
        _fusedHeading = _magnetHeading!;
        _initialized = true;
        _controller.add(_fusedHeading);
        debugPrint('[HeadingSensor] Initialized from magnetometer: ${_magnetHeading!.toStringAsFixed(1)}°');
      }
      return;
    }

    // Z-axis = yaw rotation. Negative because turning right = positive heading.
    // Phone in portrait, screen facing user: Z points up.
    final yawRate = -(event.z - _gyroZBias); // rad/s, bias-corrected
    final yawDeg = yawRate * dt * (180 / pi); // Convert to degrees

    if (_gpsSpeed >= 3.0) {
      // Moving: fuse gyro with GPS heading
      final gyroHeading = _fusedHeading + yawDeg;
      _fusedHeading = _complementaryFilter(gyroHeading, _gpsHeading, alpha: 0.98);
    } else {
      // Stationary/walking: fuse gyro with magnetometer if available
      if (_magnetHeading != null) {
        final gyroHeading = _fusedHeading + yawDeg;
        // Lower speed → trust magnetometer more (walking: 0.75, standstill: 0.65)
        final alpha = _gpsSpeed < 1 ? 0.65 : 0.75;
        _fusedHeading = _complementaryFilter(gyroHeading, _magnetHeading!, alpha: alpha);
      } else {
        // No magnetometer: just integrate gyro (will drift, but short-term OK)
        _fusedHeading = _fusedHeading + yawDeg;
      }

      // Calibrate gyro bias when nearly stationary
      if (_gpsSpeed < 1) {
        _updateGyroBias(event.z);
      }
    }

    // Normalize to [0, 360)
    _fusedHeading = _fusedHeading % 360;
    if (_fusedHeading < 0) _fusedHeading += 360;

    _controller.add(_fusedHeading);
  }

  // ── Magnetometer callback (tilt-compensated via accelerometer) ──
  void _onMagnetEvent(MagnetometerEvent event) {
    _magX = event.x;
    _magY = event.y;
    _magZ = event.z;
    _hasMagData = true;

    // ── Tilt-compensated heading using rotation matrix ──
    // This is equivalent to Android's SensorManager.getRotationMatrix()
    // + SensorManager.getOrientation(). Works regardless of device tilt/mount.
    //
    // Algorithm:
    // 1. gravity = accelerometer vector (includes gravity)
    // 2. East = magnetometer × gravity  (cross product)
    // 3. North = gravity × East         (cross product)
    // 4. heading = atan2(dot(East, forward), dot(North, forward))
    //    where forward = device Y-axis = [0, 1, 0] (top of phone)

    final ax = _accelX, ay = _accelY, az = _accelZ;

    // Cross product: East = mag × gravity
    final ex = _magY * az - _magZ * ay;
    final ey = _magZ * ax - _magX * az;
    final ez = _magX * ay - _magY * ax;

    // Normalize East vector
    final eNorm = sqrt(ex * ex + ey * ey + ez * ez);
    if (eNorm < 0.1) return; // Degenerate case (free fall, etc.)
    final enx = ex / eNorm;
    final eny = ey / eNorm;
    final enz = ez / eNorm;

    // Cross product: North = gravity × East_unit
    final nx = ay * enz - az * eny;
    final ny = az * enx - ax * enz;
    final nz = ax * eny - ay * enx;

    // Normalize North vector (magnitude ≈ |gravity|, must match East_unit scale)
    final nNorm = sqrt(nx * nx + ny * ny + nz * nz);
    if (nNorm < 0.1) return;
    final nnx = nx / nNorm;
    final nny = ny / nNorm;
    final nnz = nz / nNorm;

    // Heading: angle of device Y-axis projected on horizontal plane
    var heading = atan2(eny, nny) * (180 / pi);
    if (heading < 0) heading += 360;

    // EMA smoothing (alpha=0.5) to reduce magnetic noise while staying responsive
    if (!_magnetInitialized) {
      _magnetSmoothed = heading;
      _magnetInitialized = true;
    } else {
      // Circular EMA
      final diff = _angleDiff(_magnetSmoothed, heading);
      _magnetSmoothed = (_magnetSmoothed + 0.50 * diff) % 360;
      if (_magnetSmoothed < 0) _magnetSmoothed += 360;
    }
    _magnetHeading = _magnetSmoothed;
  }

  // ── Gyro bias calibration ──
  void _updateGyroBias(double rawZ) {
    _biasAccumulator += rawZ;
    _biasSampleCount++;
    if (_biasSampleCount >= _biasCalibrationSamples) {
      final newBias = _biasAccumulator / _biasSampleCount;
      _gyroZBias = newBias;
      _biasAccumulator = 0;
      _biasSampleCount = 0;
    }
  }

  // ── Math helpers ──

  /// Complementary filter with circular angle handling.
  double _complementaryFilter(double gyroHeading, double refHeading, {required double alpha}) {
    final diff = _angleDiff(gyroHeading, refHeading);
    var result = (gyroHeading + (1 - alpha) * diff) % 360;
    if (result < 0) result += 360;
    return result;
  }

  /// Signed angle difference (ref - current), normalized to [-180, 180].
  double _angleDiff(double current, double target) {
    double diff = target - current;
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    return diff;
  }
}
