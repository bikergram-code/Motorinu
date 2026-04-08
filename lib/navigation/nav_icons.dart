import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Creates a Waze-style navigation arrow icon.
/// Triangle pointing up with a colored fill and white border.
/// [color] is the accent color (cyan for biker, green for pedestrian, blue for auto).
Future<BitmapDescriptor> createNavArrowIcon(Color color) async {
  const double size = 96;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

  // Arrow shape: triangle pointing up
  // Slightly wider base for better visibility
  final arrowPath = Path()
    ..moveTo(size / 2, 10)          // Top point
    ..lineTo(size / 2 + 24, size - 20) // Bottom right
    ..lineTo(size / 2, size - 30)    // Notch (Waze-style tail notch)
    ..lineTo(size / 2 - 24, size - 20) // Bottom left
    ..close();

  // Glow / shadow
  canvas.drawPath(
    arrowPath.shift(const Offset(0, 2)),
    Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );

  // White border (draw slightly larger)
  final borderPath = Path()
    ..moveTo(size / 2, 6)
    ..lineTo(size / 2 + 28, size - 17)
    ..lineTo(size / 2, size - 27)
    ..lineTo(size / 2 - 28, size - 17)
    ..close();
  canvas.drawPath(borderPath, Paint()..color = Colors.white);

  // Colored fill
  canvas.drawPath(arrowPath, Paint()..color = color);

  // Small highlight on left edge
  canvas.drawPath(
    Path()
      ..moveTo(size / 2, 14)
      ..lineTo(size / 2 - 4, 18)
      ..lineTo(size / 2 - 16, size - 28)
      ..lineTo(size / 2, size - 34)
      ..close(),
    Paint()..color = Colors.white.withValues(alpha: 0.25),
  );

  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return BitmapDescriptor.defaultMarker;

  return BitmapDescriptor.bytes(bytes.buffer.asUint8List());
}

/// Creates a small dot icon for non-navigation mode (blue dot like Google Maps).
Future<BitmapDescriptor> createNavDotIcon(Color color) async {
  const double size = 96;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
  const center = Offset(size / 2, size / 2);

  // Soft glow
  canvas.drawCircle(center, 44, Paint()
    ..color = color.withValues(alpha: 0.12)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  // Wide ring (stroke)
  canvas.drawCircle(center, 34, Paint()
    ..color = color.withValues(alpha: 0.25)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6);
  // White border
  canvas.drawCircle(center, 18, Paint()..color = Colors.white);
  // Colored center
  canvas.drawCircle(center, 13, Paint()..color = color);
  // Highlight
  canvas.drawCircle(Offset(size / 2 - 3, size / 2 - 3), 4, Paint()
    ..color = Colors.white.withValues(alpha: 0.4));

  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return BitmapDescriptor.defaultMarker;

  return BitmapDescriptor.bytes(bytes.buffer.asUint8List());
}

/// Get the accent color for a route mode.
Color routeModeColor(String routeMode) {
  switch (routeMode) {
    case 'biker':
      return const Color(0xFF00BCD4); // Cyan
    case 'pedestrian':
      return const Color(0xFF4CAF50); // Green
    default:
      return const Color(0xFF2196F3); // Blue
  }
}
