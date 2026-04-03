import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/osrm_service.dart';

/// Global navigation state — controls MainShell bar visibility + route mode.
/// When navigation is active, TopBar + BottomNav hide.
/// Tap on map → bars show briefly (5s), then auto-hide again.
class NavigationState extends ChangeNotifier {
  static final instance = NavigationState._();
  NavigationState._();

  bool _isNavigating = false;
  bool _barsVisible = true;
  bool _feedScrolling = false;
  RouteMode _routeMode = RouteMode.biker;

  bool get isNavigating => _isNavigating;
  bool get feedScrolling => _feedScrolling;
  bool get barsVisible => _feedScrolling ? false : (!_isNavigating || _barsVisible);
  RouteMode get routeMode => _routeMode;

  /// Mode color: Biker=Red, Auto=Blue, Pedestrian=Green
  Color get modeColor => _routeMode == RouteMode.biker
      ? const Color(0xFFE53935)
      : _routeMode == RouteMode.pedestrian
          ? const Color(0xFF4CAF50)
          : const Color(0xFF2196F3);

  void setRouteMode(RouteMode mode) {
    if (_routeMode == mode) return;
    _routeMode = mode;
    notifyListeners();
  }

  void startNavigation() {
    _isNavigating = true;
    _barsVisible = false;
    notifyListeners();
  }

  void stopNavigation() {
    _isNavigating = false;
    _barsVisible = true;
    notifyListeners();
  }

  void setFeedScrolling(bool scrolling) {
    if (_feedScrolling == scrolling) return;
    _feedScrolling = scrolling;
    notifyListeners();
  }

  /// Show bars briefly (called on tap during navigation)
  void showBarsBriefly() {
    if (!_isNavigating) return;
    _barsVisible = true;
    notifyListeners();

    Future.delayed(const Duration(seconds: 5), () {
      if (_isNavigating) {
        _barsVisible = false;
        notifyListeners();
      }
    });
  }
}
