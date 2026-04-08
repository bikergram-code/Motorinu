import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Shared service for generating custom map marker icons.
///
/// Singleton — shared by CommunityMapScreen and GroupRideScreen.
/// Generates circular profile picture markers with colored borders.
class MarkerIconService {
  MarkerIconService._();
  static final instance = MarkerIconService._();

  static const _maxCacheSize = 50;
  final Map<String, BitmapDescriptor> _liveUserCache = {};
  final Map<String, BitmapDescriptor> _leaderCache = {};
  final Map<String, BitmapDescriptor> _sosCache = {};
  final Map<String, BitmapDescriptor> _navVehicleCache = {};

  /// Evict oldest entries when cache exceeds max size.
  void _evictIfNeeded(Map<String, BitmapDescriptor> cache) {
    if (cache.length > _maxCacheSize) {
      final keysToRemove = cache.keys.take(cache.length - _maxCacheSize).toList();
      for (final k in keysToRemove) { cache.remove(k); }
    }
  }

  // ═══════════════════════════════════════════════════
  //  LIVE USER MARKER (green/group-color border)
  // ═══════════════════════════════════════════════════

  /// Circular profile picture marker with colored border.
  /// [groupColorHex] overrides the default green with a group ride color.
  Future<BitmapDescriptor> getLiveUserMarker({
    required String? avatarUrl,
    required String displayName,
    String? groupColorHex,
  }) async {
    final cacheKey = 'live_${groupColorHex ?? 'default'}_${avatarUrl ?? displayName}';
    if (_liveUserCache.containsKey(cacheKey)) return _liveUserCache[cacheKey]!;

    const double size = 128;
    final borderColor = groupColorHex != null
        ? Color(int.parse('FF${groupColorHex.replaceFirst('#', '')}', radix: 16))
        : const Color(0xFF00C853); // Leuchtgrün für "Online"

    final descriptor = await _buildProfileCircle(
      size: size,
      borderColor: borderColor,
      avatarUrl: avatarUrl,
      displayName: displayName,
      displaySize: 46,
    );

    _liveUserCache[cacheKey] = descriptor;
    _evictIfNeeded(_liveUserCache);
    return descriptor;
  }

  // ═══════════════════════════════════════════════════
  //  LEADER MARKER (red border + gold star badge)
  // ═══════════════════════════════════════════════════

  /// Leader marker: red border with gold star badge at top.
  Future<BitmapDescriptor> getLeaderMarker({
    required String? avatarUrl,
    required String displayName,
  }) async {
    final cacheKey = 'leader_${avatarUrl ?? displayName}';
    if (_leaderCache.containsKey(cacheKey)) return _leaderCache[cacheKey]!;

    const double size = 128; // same size as regular members
    const borderColor = Color(0xFFD32F2F); // Red

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    const center = Offset(size / 2, size / 2 + 5); // offset down for badge

    // Load profile image
    final profileImage = await _loadAvatar(avatarUrl, size.toInt());

    // Red outer glow
    canvas.drawCircle(center, 50,
      Paint()
        ..color = borderColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // Red border
    canvas.drawCircle(center, 46, Paint()..color = borderColor);

    // Profile image or letter fallback
    if (profileImage != null) {
      canvas.save();
      final clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: 38));
      canvas.clipPath(clipPath);
      final srcRect = Rect.fromLTWH(0, 0,
          profileImage.width.toDouble(), profileImage.height.toDouble());
      final dstRect = Rect.fromCircle(center: center, radius: 38);
      canvas.drawImageRect(profileImage, srcRect, dstRect, Paint());
      canvas.restore();
    } else {
      canvas.drawCircle(center, 38, Paint()..color = Colors.white);
      final letter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
      final tp = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: letter,
          style: const TextStyle(
            fontSize: 36, fontWeight: FontWeight.bold, color: borderColor),
        )
        ..layout();
      tp.paint(canvas, Offset(
          center.dx - tp.width / 2, center.dy - tp.height / 2));
    }

    // White inner ring
    canvas.drawCircle(center, 40,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);

    // Red outer ring
    canvas.drawCircle(center, 44,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);

    // ── Gold star badge at top ──
    const badgeCenter = Offset(size / 2, 14);
    // White outline
    canvas.drawCircle(badgeCenter, 15,
      Paint()..color = Colors.white);
    // Gold circle
    canvas.drawCircle(badgeCenter, 12,
      Paint()..color = const Color(0xFFFFD700));
    // Star symbol
    final starTp = TextPainter(textDirection: TextDirection.ltr)
      ..text = const TextSpan(
        text: '★',
        style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w900),
      )
      ..layout();
    starTp.paint(canvas, Offset(
        badgeCenter.dx - starTp.width / 2,
        badgeCenter.dy - starTp.height / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes, width: 46, height: 46);
    _leaderCache[cacheKey] = descriptor;
    _evictIfNeeded(_leaderCache);
    return descriptor;
  }

  // ═══════════════════════════════════════════════════
  //  SOS MARKER (red border + SOS badge)
  // ═══════════════════════════════════════════════════

  /// SOS marker: red border with "SOS" pill badge at bottom.
  Future<BitmapDescriptor> getSosMarker({
    required String? avatarUrl,
    required String displayName,
  }) async {
    final cacheKey = 'sos_${avatarUrl ?? displayName}';
    if (_sosCache.containsKey(cacheKey)) return _sosCache[cacheKey]!;

    const double size = 128;
    const borderColor = Color(0xFFD32F2F);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    const center = Offset(size / 2, size / 2);

    final profileImage = await _loadAvatar(avatarUrl, size.toInt());

    // Red glow
    canvas.drawCircle(center, size / 2,
      Paint()..color = borderColor.withValues(alpha: 0.4));

    // Red border
    canvas.drawCircle(center, size / 2 - 4, Paint()..color = borderColor);

    // Profile or letter
    if (profileImage != null) {
      canvas.save();
      final clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: size / 2 - 8));
      canvas.clipPath(clipPath);
      final srcRect = Rect.fromLTWH(0, 0,
          profileImage.width.toDouble(), profileImage.height.toDouble());
      final dstRect = Rect.fromCircle(center: center, radius: size / 2 - 8);
      canvas.drawImageRect(profileImage, srcRect, dstRect, Paint());
      canvas.restore();
    } else {
      canvas.drawCircle(center, size / 2 - 8, Paint()..color = Colors.white);
      final letter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
      final tp = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: letter,
          style: const TextStyle(
            fontSize: 48, fontWeight: FontWeight.bold, color: borderColor),
        )
        ..layout();
      tp.paint(canvas, Offset(
          (size - tp.width) / 2, (size - tp.height) / 2));
    }

    // White inner ring
    canvas.drawCircle(center, size / 2 - 6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);

    // SOS badge at bottom
    final badgeRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(size / 2 - 28, size - 30, 56, 24),
      const Radius.circular(12),
    );
    canvas.drawRRect(badgeRect.inflate(2), Paint()..color = Colors.white);
    canvas.drawRRect(badgeRect, Paint()..color = borderColor);
    final sosTp = TextPainter(textDirection: TextDirection.ltr)
      ..text = const TextSpan(
        text: 'SOS',
        style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w900,
          color: Colors.white, letterSpacing: 1.5),
      )
      ..layout();
    sosTp.paint(canvas, Offset(size / 2 - sosTp.width / 2, size - 28));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes, width: 48, height: 48);
    _sosCache[cacheKey] = descriptor;
    _evictIfNeeded(_sosCache);
    return descriptor;
  }

  // ═══════════════════════════════════════════════════
  //  NAVIGATION VEHICLE MARKER (profile pic + mode badge)
  // ═══════════════════════════════════════════════════

  /// Navigation marker with profile picture and vehicle mode badge.
  /// [isBikerMode] true = motorcycle badge, false = car badge.
  /// Profile picture in blue circle, vehicle icon badge at bottom.
  Future<BitmapDescriptor> getNavigationVehicleMarker({
    required String? avatarUrl,
    required String displayName,
    bool isBikerMode = false,
    String? routeModeKey,
  }) async {
    final modeKey = routeModeKey ?? (isBikerMode ? 'bike' : 'car');
    final cacheKey = 'nav_${modeKey}_${avatarUrl ?? displayName}';
    if (_navVehicleCache.containsKey(cacheKey)) return _navVehicleCache[cacheKey]!;

    const double circleArea = 160;
    const double size = circleArea; // No arrow — map rotates instead
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, circleArea, size));
    const center = Offset(circleArea / 2, circleArea / 2);

    final profileImage = await _loadAvatar(avatarUrl, size.toInt());

    // Mode color: cyan for biker, green for pedestrian, blue for auto
    final modeColor = modeKey == 'bike'
        ? const Color(0xFF00BCD4)
        : modeKey == 'pedestrian'
            ? const Color(0xFF4CAF50)
            : const Color(0xFF2196F3);

    // Outer glow
    canvas.drawCircle(center, 52,
      Paint()
        ..color = modeColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // Colored border circle
    canvas.drawCircle(center, 46, Paint()..color = modeColor);

    // Profile image or letter fallback
    if (profileImage != null) {
      canvas.save();
      final clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: 38));
      canvas.clipPath(clipPath);
      final srcRect = Rect.fromLTWH(0, 0,
          profileImage.width.toDouble(), profileImage.height.toDouble());
      final dstRect = Rect.fromCircle(center: center, radius: 38);
      canvas.drawImageRect(profileImage, srcRect, dstRect, Paint());
      canvas.restore();
    } else {
      canvas.drawCircle(center, 38, Paint()..color = const Color(0xFF1A1E2E));
      final letter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
      final tp = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: letter,
          style: TextStyle(
            fontSize: 38, fontWeight: FontWeight.bold, color: modeColor),
        )
        ..layout();
      tp.paint(canvas, Offset(
          center.dx - tp.width / 2, center.dy - tp.height / 2));
    }

    // White inner ring
    canvas.drawCircle(center, 40,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);

    // Colored outer ring
    canvas.drawCircle(center, 45,
      Paint()
        ..color = modeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4);

    // ── Vehicle mode badge at bottom ──
    final badgeCenter = Offset(circleArea / 2, circleArea - 18);
    // White outline circle
    canvas.drawCircle(badgeCenter, 20, Paint()..color = Colors.white);
    // Colored circle
    canvas.drawCircle(badgeCenter, 17, Paint()..color = modeColor);

    // Vehicle icon (motorcycle, car, or pedestrian)
    final vehicleText = modeKey == 'bike' ? '🏍' : modeKey == 'pedestrian' ? '🚶' : '🚗';
    final vehicleTp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: vehicleText,
        style: const TextStyle(fontSize: 18),
      )
      ..layout();
    vehicleTp.paint(canvas, Offset(
        badgeCenter.dx - vehicleTp.width / 2,
        badgeCenter.dy - vehicleTp.height / 2));

    // No direction arrow — map rotates with heading instead

    final picture = recorder.endRecording();
    final image = await picture.toImage(circleArea.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes, width: 56, height: (56 * size / circleArea).round().toDouble());
    _navVehicleCache[cacheKey] = descriptor;
    _evictIfNeeded(_navVehicleCache);
    return descriptor;
  }

  // ═══════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════

  /// Build a standard circular profile marker with border.
  Future<BitmapDescriptor> _buildProfileCircle({
    required double size,
    required Color borderColor,
    required String? avatarUrl,
    required String displayName,
    required double displaySize,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    final center = Offset(size / 2, size / 2);

    final profileImage = await _loadAvatar(avatarUrl, size.toInt());

    // Outer glow
    canvas.drawCircle(center, size / 2,
      Paint()
        ..color = borderColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Colored border
    canvas.drawCircle(center, size / 2 - 4, Paint()..color = borderColor);

    if (profileImage != null) {
      canvas.save();
      final clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: size / 2 - 10));
      canvas.clipPath(clipPath);
      final srcRect = Rect.fromLTWH(0, 0,
          profileImage.width.toDouble(), profileImage.height.toDouble());
      final dstRect = Rect.fromCircle(center: center, radius: size / 2 - 10);
      canvas.drawImageRect(profileImage, srcRect, dstRect, Paint());
      canvas.restore();
    } else {
      canvas.drawCircle(center, size / 2 - 10, Paint()..color = Colors.white);
      final letter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
      final tp = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: letter,
          style: TextStyle(
            fontSize: 48, fontWeight: FontWeight.bold, color: borderColor),
        )
        ..layout();
      tp.paint(canvas, Offset(
          (size - tp.width) / 2, (size - tp.height) / 2));
    }

    // White inner ring
    canvas.drawCircle(center, size / 2 - 8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);

    // Colored outer ring
    canvas.drawCircle(center, size / 2 - 3,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(bytes,
        width: displaySize, height: displaySize);
  }

  /// Load an avatar image from URL.
  Future<ui.Image?> _loadAvatar(String? avatarUrl, int targetSize) async {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(avatarUrl));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(
          response.bodyBytes,
          targetWidth: targetSize,
          targetHeight: targetSize,
        );
        final frame = await codec.getNextFrame();
        return frame.image;
      }
    } catch (e) {
      debugPrint('[MarkerIcon] Failed to load avatar: $e');
    }
    return null;
  }

  /// Clear all caches (e.g., when user changes avatar).
  void clearCache() {
    _liveUserCache.clear();
    _leaderCache.clear();
    _sosCache.clear();
    _navVehicleCache.clear();
  }
}
