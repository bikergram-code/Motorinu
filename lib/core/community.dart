import 'package:flutter/material.dart';

/// Defines the two communities supported by the app.
/// Each community has its own branding, backend namespace, and feature set.
enum Community {
  bikergram,
  cargram;

  String get displayName => switch (this) {
        Community.bikergram => 'Biker',
        Community.cargram => 'Cars',
      };

  String get tagline => switch (this) {
        Community.bikergram => 'Die Community f\u00fcr Biker',
        Community.cargram => 'Die Community f\u00fcr Autofans',
      };

  String get vehicleLabel => switch (this) {
        Community.bikergram => 'Bike',
        Community.cargram => 'Auto',
      };

  String get vehicleLabelPlural => switch (this) {
        Community.bikergram => 'Bikes',
        Community.cargram => 'Autos',
      };

  String get garageLabel => switch (this) {
        Community.bikergram => 'Meine Garage',
        Community.cargram => 'Meine Garage',
      };

  /// API namespace prefix — backend uses this to separate communities.
  /// e.g. /api/v1/bikergram/posts vs /api/v1/cargram/posts
  String get apiNamespace => name;

  /// Icon data for the community
  String get iconAsset => switch (this) {
        Community.bikergram => 'assets/images/biker_icon.png',
        Community.cargram => 'assets/images/cars_icon.png',
      };

  // ── Community Colors ──────────────────────────────────────────────────

  /// Primary accent color for the community.
  Color get accentColor => switch (this) {
        Community.bikergram => const Color(0xFFFF6B35), // Warm orange
        Community.cargram => const Color(0xFF4A90D9),   // Cool blue
      };

  /// Subtle glow / tint for borders, shadows, overlays.
  Color get accentGlow => switch (this) {
        Community.bikergram => const Color(0x40FF6B35), // Orange 25%
        Community.cargram => const Color(0x404A90D9),   // Blue 25%
      };

  // ── Dark-mode colors (existing, kept as defaults) ──

  /// Scaffold / main background — subtly tinted black.
  Color get scaffoldColor => switch (this) {
        Community.bikergram => const Color(0xFF080604), // warm near-black
        Community.cargram => const Color(0xFF040810),   // cool near-black
      };

  /// Card / container background — slightly lighter tinted surface.
  Color get cardColor => switch (this) {
        Community.bikergram => const Color(0xFF1E1814), // warm dark brown
        Community.cargram => const Color(0xFF141C26),   // cool dark blue
      };

  /// Bottom navigation bar background.
  Color get navBarColor => switch (this) {
        Community.bikergram => const Color(0xFF110E0A), // warm BottomBar
        Community.cargram => const Color(0xFF0A0E16),   // cool BottomBar
      };

  /// Subtle border color for cards, dividers.
  Color get borderColor => switch (this) {
        Community.bikergram => const Color(0x18FF6B35), // orange 9%
        Community.cargram => const Color(0x184A90D9),   // blue 9%
      };

  // ── Brightness-aware color resolvers ──────────────────────────────────

  /// Scaffold background for the given [brightness].
  Color scaffoldFor(Brightness b) => switch ((this, b)) {
        (Community.bikergram, Brightness.dark)  => const Color(0xFF080604),
        (Community.bikergram, Brightness.light) => const Color(0xFFF8F5F0),
        (Community.cargram,   Brightness.dark)  => const Color(0xFF040810),
        (Community.cargram,   Brightness.light) => const Color(0xFFF0F4FA),
      };

  /// Card / container background for the given [brightness].
  Color cardFor(Brightness b) => switch ((this, b)) {
        (Community.bikergram, Brightness.dark)  => const Color(0xFF1E1814),
        (Community.bikergram, Brightness.light) => const Color(0xFFFFFFFF),
        (Community.cargram,   Brightness.dark)  => const Color(0xFF141C26),
        (Community.cargram,   Brightness.light) => const Color(0xFFFFFFFF),
      };

  /// Bottom navigation bar background for the given [brightness].
  Color navBarFor(Brightness b) => switch ((this, b)) {
        (Community.bikergram, Brightness.dark)  => const Color(0xFF110E0A),
        (Community.bikergram, Brightness.light) => const Color(0xFFFAF6F2),
        (Community.cargram,   Brightness.dark)  => const Color(0xFF0A0E16),
        (Community.cargram,   Brightness.light) => const Color(0xFFF2F6FC),
      };

  /// Subtle border color for the given [brightness].
  Color borderFor(Brightness b) => switch ((this, b)) {
        (Community.bikergram, Brightness.dark)  => const Color(0x18FF6B35),
        (Community.bikergram, Brightness.light) => const Color(0x30FF6B35),
        (Community.cargram,   Brightness.dark)  => const Color(0x184A90D9),
        (Community.cargram,   Brightness.light) => const Color(0x304A90D9),
      };

  /// Primary text color for the given [brightness].
  Color textColor(Brightness b) =>
      b == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A);

  /// Secondary / muted text color for the given [brightness].
  Color textMutedColor(Brightness b) =>
      b == Brightness.dark
          ? Colors.white.withValues(alpha: 0.5)
          : const Color(0xFF6C757D);

  /// Faint overlay color (for dividers, subtle backgrounds).
  Color faintColor(Brightness b) =>
      b == Brightness.dark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06);
}
