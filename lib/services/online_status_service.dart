import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight service that keeps the current user's `is_online` / `last_seen`
/// columns in the `profiles` table up-to-date via a periodic heartbeat.
///
/// Usage:
///   globalOnlineStatusService.start();  // on login / app resume
///   globalOnlineStatusService.stop();   // on logout / app detach
class OnlineStatusService {
  OnlineStatusService._();
  static final instance = OnlineStatusService._();

  Timer? _heartbeatTimer;
  bool _isRunning = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get isRunning => _isRunning;

  /// Mark user online, start 2-minute heartbeat.
  /// Idempotent — safe to call multiple times.
  Future<void> start() async {
    if (_isRunning) {
      // Already running — just trigger an immediate heartbeat
      _heartbeat();
      return;
    }
    _isRunning = true;
    await _setOnline(true);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) => _heartbeat());
    debugPrint('[OnlineStatus] Started (heartbeat every 2 min)');
  }

  /// Mark user offline, stop heartbeat.
  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isRunning = false;
    await _setOnline(false);
    debugPrint('[OnlineStatus] Stopped');
  }

  /// Heartbeat — just update `last_seen`.
  Future<void> _heartbeat() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('profiles').update({
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('[OnlineStatus] Heartbeat failed: $e');
    }
  }

  /// Set `is_online` + `last_seen`.
  Future<void> _setOnline(bool online) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('profiles').update({
        'is_online': online,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('[OnlineStatus] Set online=$online failed: $e');
    }
  }
}

/// Global singleton — same pattern as live location service.
final globalOnlineStatusService = OnlineStatusService.instance;
