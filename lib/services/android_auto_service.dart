import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/message_repository.dart';
import '../providers/blitzer/navigation_provider.dart';
import '../providers/core/providers.dart';
import '../providers/messages/incoming_message_provider.dart';
import '../providers/messages/unread_messages_notifier.dart';
import '../services/osrm_service.dart';

SupabaseClient get _supabase => Supabase.instance.client;

/// Riverpod provider for the Android Auto bridge service.
final androidAutoServiceProvider = Provider<AndroidAutoService>((ref) {
  final service = AndroidAutoService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Dart-side bridge to Android Auto via MethodChannel.
///
/// Handles:
/// - Incoming actions from car display (search, stop nav, route mode toggle)
/// - Outgoing navigation state pushes to car display
///
/// Two-phase initialization:
/// 1. [initChannel] — static, called in main() BEFORE Riverpod.
///    Registers the MethodChannel handler for POI data (fetchPoiData).
///    Only needs Supabase (global singleton), no Riverpod.
/// 2. [init] — instance, called in MainShell.initState() WITH Riverpod.
///    Upgrades the handler to support navigation, messaging, search.
class AndroidAutoService {
  static const _channel = MethodChannel('com.bikergram.app/android_auto');

  /// Singleton instance — set when the Riverpod provider creates the service.
  static AndroidAutoService? _instance;

  /// Whether the static channel handler is registered.
  static bool _channelReady = false;

  final Ref _ref;
  bool _initialized = false;

  /// Set by the map screen so we know the user's current GPS position.
  LatLng Function()? getCurrentPosition;

  AndroidAutoService(this._ref) {
    _instance = this;
  }

  // ─── Phase 1: Static channel init (no Riverpod) ──────────────────────────

  /// Register the MethodChannel handler for Android Auto.
  /// Call in main() after Supabase.initialize().
  /// Handles fetchPoiData directly via Supabase singleton.
  /// Other calls are forwarded to the instance (if available).
  static void initChannel() {
    if (_channelReady) return;
    _channelReady = true;

    _channel.setMethodCallHandler((call) async {
      debugPrint('[AndroidAuto] Received from Kotlin: ${call.method}');

      // POI data — can be handled without Riverpod
      if (call.method == 'fetchPoiData') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final category = args['category'] as String;
        final lat = (args['lat'] as num?)?.toDouble();
        final lng = (args['lng'] as num?)?.toDouble();
        return await _staticFetchPoiData(category, lat, lng);
      }

      // All other calls need Riverpod — delegate to instance
      if (_instance != null && _instance!._initialized) {
        return _instance!._handleMethodCall(call);
      }

      debugPrint('[AndroidAuto] Instance not ready for: ${call.method}');
      return null;
    });

    debugPrint('[AndroidAuto] Static channel handler registered');
  }

  // ─── Phase 2: Instance init (with Riverpod) ──────────────────────────────

  /// Initialize the Riverpod-dependent features (navigation, messaging).
  /// Call once in MainShell.initState().
  void init() {
    if (_initialized) return;
    _initialized = true;
    _instance = this;

    // Channel handler is already set by initChannel() — no need to set again.
    // The static handler delegates non-POI calls to this instance.
    debugPrint('[AndroidAuto] Dart service initialized (Riverpod ready)');
  }

  // ─── Incoming from Kotlin ──────────────────────────────────────────────────

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('[AndroidAuto] Received from Kotlin: ${call.method}');

    switch (call.method) {
      case 'onSearchQuery':
        final query = call.arguments as String;
        await _handleSearch(query);
        return null;

      case 'onSearchSelected':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        await _handleSearchSelected(
          lat: (args['lat'] as num).toDouble(),
          lng: (args['lng'] as num).toDouble(),
          name: args['name'] as String,
        );
        return null;

      case 'onStopNavigation':
        debugPrint('[AndroidAuto] Stop navigation from car');
        _ref.read(navigationProvider.notifier).stopNavigation();
        return null;

      case 'onRouteMode':
        final mode = call.arguments as String;
        debugPrint('[AndroidAuto] Route mode from car: $mode');
        final routeMode = mode == 'biker' ? RouteMode.biker : RouteMode.auto;
        _ref.read(navigationProvider.notifier).setRouteMode(routeMode);

        // If already navigating with a destination, recalculate
        final navState = _ref.read(navigationProvider);
        if (navState.destination != null) {
          final origin = getCurrentPosition?.call();
          if (origin != null) {
            await _ref.read(navigationProvider.notifier).calculateRoute(
              origin,
              navState.destination!,
              name: navState.destinationName,
              mode: routeMode,
            );
          }
        }
        return null;

      // ── Messaging: voice reply from Android Auto ──
      case 'onVoiceReply':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final conversationId = (args['conversationId'] as num).toInt();
        final text = args['text'] as String;
        await _handleVoiceReply(conversationId, text);
        return null;

      // ── Messaging: mark-as-read from Android Auto ──
      case 'onMarkRead':
        final conversationId = (call.arguments as num).toInt();
        await _handleMarkRead(conversationId);
        return null;

      // ── POI data: Android Auto requests events/blitzer from Supabase ──
      case 'fetchPoiData':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final category = args['category'] as String;
        final lat = (args['lat'] as num?)?.toDouble();
        final lng = (args['lng'] as num?)?.toDouble();
        return await _fetchPoiData(category, lat, lng);

      default:
        debugPrint('[AndroidAuto] Unknown method: ${call.method}');
        return null;
    }
  }

  Future<void> _handleSearch(String query) async {
    debugPrint('[AndroidAuto] Search: $query');
    final near = getCurrentPosition?.call();
    await _ref.read(navigationProvider.notifier).searchPlaces(query, near: near);

    // Read results and send back to Kotlin
    final state = _ref.read(navigationProvider);
    final results = state.searchResults.map((r) => <String, dynamic>{
      'name': r.shortName,
      'address': r.displayName,
      'lat': r.location.latitude,
      'lng': r.location.longitude,
    }).toList();

    debugPrint('[AndroidAuto] Sending ${results.length} search results to car');
    try {
      await _channel.invokeMethod('updateSearchResults', results);
    } catch (e) {
      debugPrint('[AndroidAuto] Failed to send search results: $e');
    }
  }

  Future<void> _handleSearchSelected({
    required double lat,
    required double lng,
    required String name,
  }) async {
    debugPrint('[AndroidAuto] Selected destination: $name ($lat, $lng)');
    final origin = getCurrentPosition?.call();
    if (origin == null) {
      debugPrint('[AndroidAuto] No current position — cannot calculate route');
      return;
    }

    final destination = LatLng(lat, lng);
    await _ref.read(navigationProvider.notifier).calculateRoute(
      origin, destination, name: name,
    );
    _ref.read(navigationProvider.notifier).startNavigation();

    // Tell Kotlin navigation started
    sendNavigationStarted();
  }

  // ─── Messaging handlers ──────────────────────────────────────────────────

  /// Handle voice reply from Android Auto.
  /// Sends the message directly to Supabase on behalf of the user.
  Future<void> _handleVoiceReply(int conversationId, String text) async {
    debugPrint('[AndroidAuto] Voice reply: conv=$conversationId, text="$text"');
    try {
      final repo = _ref.read(messageRepositoryProvider);
      await repo.sendMessage(conversationId, text);
      debugPrint('[AndroidAuto] Voice reply sent to Supabase');
    } catch (e) {
      debugPrint('[AndroidAuto] Voice reply error: $e');
    }
  }

  /// Handle mark-as-read from Android Auto.
  Future<void> _handleMarkRead(int conversationId) async {
    debugPrint('[AndroidAuto] Mark read: conv=$conversationId');
    try {
      final repo = _ref.read(messageRepositoryProvider);
      await repo.markAsRead(conversationId);
      // Cancel the in-app notification too
      IncomingMessageBus.instance.cancelNotification(conversationId);
      // Refresh the unread badge
      _ref.read(unreadMessagesProvider.notifier).refresh();
      debugPrint('[AndroidAuto] Marked as read');
    } catch (e) {
      debugPrint('[AndroidAuto] Mark read error: $e');
    }
  }

  // ─── POI data for Android Auto ───────────────────────────────────────────

  /// Fetch POI data from Supabase for the given category.
  /// Returns a List<Map> directly (MethodChannel serializes it automatically).
  Future<List<Map<String, dynamic>>> _fetchPoiData(
    String category,
    double? lat,
    double? lng,
  ) async {
    debugPrint('[AndroidAuto] fetchPoiData: category=$category, lat=$lat, lng=$lng');
    try {
      switch (category) {
        case 'events':
          return await _fetchEvents();
        case 'blitzer':
          return await _fetchBlitzer(lat, lng);
        case 'spots':
          return await _fetchSpots();
        default:
          debugPrint('[AndroidAuto] Unknown POI category: $category');
          return [];
      }
    } catch (e) {
      debugPrint('[AndroidAuto] fetchPoiData error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchEvents() async {
    final now = DateTime.now().toIso8601String();
    final data = await _supabase
        .from('events')
        .select('id, title, description, location, latitude, longitude, starts_at, participant_count')
        .gte('starts_at', now)
        .eq('is_active', true)
        .order('starts_at')
        .limit(8);

    return data.map<Map<String, dynamic>>((e) {
      final startsAt = DateTime.tryParse(e['starts_at'] as String? ?? '');
      final dateStr = startsAt != null
          ? '${startsAt.day}.${startsAt.month}.${startsAt.year} · ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')} Uhr'
          : '';
      final participants = e['participant_count'] as int? ?? 0;
      return {
        'id': '${e['id']}',
        'title': e['title'] as String? ?? 'Event',
        'subtitle': dateStr.isNotEmpty
            ? '$dateStr · $participants Teilnehmer'
            : '$participants Teilnehmer',
        'description': e['description'] as String? ?? e['location'] as String? ?? '',
        'lat': (e['latitude'] as num?)?.toDouble() ?? 0.0,
        'lng': (e['longitude'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchBlitzer(double? lat, double? lng) async {
    // Build filter-first query (filters must come before order/limit)
    var filterQuery = _supabase
        .from('blitzer_reports')
        .select('id, type, latitude, longitude, description, confirmations, expires_at')
        .eq('is_active', true);

    if (lat != null && lng != null) {
      const range = 0.45; // ~50km in degrees
      filterQuery = filterQuery
          .gte('latitude', lat - range)
          .lte('latitude', lat + range)
          .gte('longitude', lng - range)
          .lte('longitude', lng + range);
    }

    final data = await filterQuery
        .order('created_at', ascending: false)
        .limit(12);

    final typeLabels = {
      'fixed': 'Fester Blitzer',
      'mobile': 'Mobiler Blitzer',
      'police': 'Polizeikontrolle',
      'construction': 'Baustelle',
      'accident': 'Unfall',
      'biker_meetup': 'Biker-Treff',
      'scenic_route': 'Schöne Strecke',
      'gas_station': 'Tankstelle',
    };

    // Filter expired
    final now = DateTime.now();
    return data.where((e) {
      final exp = e['expires_at'] as String?;
      if (exp == null) return true;
      final expDate = DateTime.tryParse(exp);
      return expDate == null || now.isBefore(expDate);
    }).map<Map<String, dynamic>>((e) {
      final type = e['type'] as String? ?? 'fixed';
      final label = typeLabels[type] ?? type;
      final conf = e['confirmations'] as int? ?? 0;
      final desc = e['description'] as String?;
      return {
        'id': '${e['id']}',
        'title': label,
        'subtitle': desc?.isNotEmpty == true ? desc! : '$conf Bestätigungen',
        'description': desc ?? '$conf Bestätigungen · $label',
        'lat': (e['latitude'] as num?)?.toDouble() ?? 0.0,
        'lng': (e['longitude'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchSpots() async {
    // Spots = biker_meetup + scenic_route type reports (permanent, high-trust)
    final data = await _supabase
        .from('blitzer_reports')
        .select('id, type, latitude, longitude, description, confirmations')
        .eq('is_active', true)
        .inFilter('type', ['biker_meetup', 'scenic_route', 'gas_station', 'workshop'])
        .order('confirmations', ascending: false)
        .limit(8);

    final typeLabels = {
      'biker_meetup': 'Biker-Treff',
      'scenic_route': 'Schöne Strecke',
      'gas_station': 'Tankstelle',
      'workshop': 'Werkstatt',
    };

    return data.map<Map<String, dynamic>>((e) {
      final type = e['type'] as String? ?? 'biker_meetup';
      final label = typeLabels[type] ?? type;
      final desc = e['description'] as String?;
      final conf = e['confirmations'] as int? ?? 0;
      return {
        'id': '${e['id']}',
        'title': desc?.isNotEmpty == true ? desc! : label,
        'subtitle': '$label · $conf Bestätigungen',
        'description': desc ?? label,
        'lat': (e['latitude'] as num?)?.toDouble() ?? 0.0,
        'lng': (e['longitude'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }

  // ─── Outgoing to Kotlin ───────────────────────────────────────────────────

  /// Push current navigation state to the car display.
  /// Called by BlitzerMapScreen via ref.listen on navigationProvider.
  void pushNavigationState(NavigationState state) {
    if (!_initialized) return;

    final currentStep = state.currentStep;
    // Don't push if not navigating and no step
    if (!state.isNavigating && currentStep == null) return;

    final data = <String, dynamic>{
      'isNavigating': state.isNavigating,
      'stepInstruction': currentStep?.instruction ?? '',
      'roadName': currentStep?.roadName ?? '',
      'maneuver': currentStep?.maneuver ?? 'straight',
      'stepDistanceMeters': state.distanceToNextStep,
      'remainingKm': state.remainingKm,
      'remainingSeconds': state.remainingSeconds,
      'speedKmh': state.currentSpeed,
      'routeMode': state.routeMode == RouteMode.biker ? 'biker' : 'auto',
      'isOffRoute': state.isOffRoute,
      'destinationName': state.destinationName ?? '',
    };

    try {
      _channel.invokeMethod('updateNavigation', data);
    } catch (e) {
      // Don't spam logs — car might not be connected
    }
  }

  /// Tell the car display that navigation has started.
  void sendNavigationStarted() {
    if (!_initialized) return;
    try {
      _channel.invokeMethod('navigationStarted', null);
      debugPrint('[AndroidAuto] Sent navigationStarted to car');
    } catch (e) {
      debugPrint('[AndroidAuto] Failed: $e');
    }
  }

  /// Tell the car display that navigation has ended.
  void sendNavigationEnded() {
    if (!_initialized) return;
    try {
      _channel.invokeMethod('navigationEnded', null);
      debugPrint('[AndroidAuto] Sent navigationEnded to car');
    } catch (e) {
      debugPrint('[AndroidAuto] Failed: $e');
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _initialized = false;
    if (_instance == this) _instance = null;
    debugPrint('[AndroidAuto] Dart service disposed');
  }

  // ─── Static POI fetchers (no Riverpod needed) ─────────────────────────────

  static Future<List<Map<String, dynamic>>> _staticFetchPoiData(
    String category,
    double? lat,
    double? lng,
  ) async {
    debugPrint('[AndroidAuto] staticFetchPoiData: category=$category, lat=$lat, lng=$lng');
    final supabase = Supabase.instance.client;
    try {
      switch (category) {
        case 'events':
          return await _staticFetchEvents(supabase);
        case 'blitzer':
          return await _staticFetchBlitzer(supabase, lat, lng);
        case 'spots':
          return await _staticFetchSpots(supabase);
        default:
          debugPrint('[AndroidAuto] Unknown POI category: $category');
          return [];
      }
    } catch (e) {
      debugPrint('[AndroidAuto] staticFetchPoiData error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _staticFetchEvents(
    SupabaseClient supabase,
  ) async {
    final now = DateTime.now().toIso8601String();
    final data = await supabase
        .from('events')
        .select('id, title, description, location, latitude, longitude, starts_at, participant_count')
        .gte('starts_at', now)
        .eq('is_active', true)
        .order('starts_at')
        .limit(8);

    return data.map<Map<String, dynamic>>((e) {
      final startsAt = DateTime.tryParse(e['starts_at'] as String? ?? '');
      final dateStr = startsAt != null
          ? '${startsAt.day}.${startsAt.month}.${startsAt.year} · ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')} Uhr'
          : '';
      final participants = e['participant_count'] as int? ?? 0;
      return {
        'id': '${e['id']}',
        'title': e['title'] as String? ?? 'Event',
        'subtitle': dateStr.isNotEmpty
            ? '$dateStr · $participants Teilnehmer'
            : '$participants Teilnehmer',
        'description': e['description'] as String? ?? e['location'] as String? ?? '',
        'lat': (e['latitude'] as num?)?.toDouble() ?? 0.0,
        'lng': (e['longitude'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> _staticFetchBlitzer(
    SupabaseClient supabase,
    double? lat,
    double? lng,
  ) async {
    var filterQuery = supabase
        .from('blitzer_reports')
        .select('id, type, latitude, longitude, description, confirmations, expires_at')
        .eq('is_active', true);

    if (lat != null && lng != null) {
      const range = 0.45; // ~50km in degrees
      filterQuery = filterQuery
          .gte('latitude', lat - range)
          .lte('latitude', lat + range)
          .gte('longitude', lng - range)
          .lte('longitude', lng + range);
    }

    final data = await filterQuery
        .order('created_at', ascending: false)
        .limit(12);

    final typeLabels = {
      'fixed': 'Fester Blitzer',
      'mobile': 'Mobiler Blitzer',
      'police': 'Polizeikontrolle',
      'construction': 'Baustelle',
      'accident': 'Unfall',
      'biker_meetup': 'Biker-Treff',
      'scenic_route': 'Schöne Strecke',
      'gas_station': 'Tankstelle',
    };

    final now = DateTime.now();
    return data.where((e) {
      final exp = e['expires_at'] as String?;
      if (exp == null) return true;
      final expDate = DateTime.tryParse(exp);
      return expDate == null || now.isBefore(expDate);
    }).map<Map<String, dynamic>>((e) {
      final type = e['type'] as String? ?? 'fixed';
      final label = typeLabels[type] ?? type;
      final conf = e['confirmations'] as int? ?? 0;
      final desc = e['description'] as String?;
      return {
        'id': '${e['id']}',
        'title': label,
        'subtitle': desc?.isNotEmpty == true ? desc! : '$conf Bestätigungen',
        'description': desc ?? '$conf Bestätigungen · $label',
        'lat': (e['latitude'] as num?)?.toDouble() ?? 0.0,
        'lng': (e['longitude'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> _staticFetchSpots(
    SupabaseClient supabase,
  ) async {
    final data = await supabase
        .from('blitzer_reports')
        .select('id, type, latitude, longitude, description, confirmations')
        .eq('is_active', true)
        .inFilter('type', ['biker_meetup', 'scenic_route', 'gas_station', 'workshop'])
        .order('confirmations', ascending: false)
        .limit(8);

    final typeLabels = {
      'biker_meetup': 'Biker-Treff',
      'scenic_route': 'Schöne Strecke',
      'gas_station': 'Tankstelle',
      'workshop': 'Werkstatt',
    };

    return data.map<Map<String, dynamic>>((e) {
      final type = e['type'] as String? ?? 'biker_meetup';
      final label = typeLabels[type] ?? type;
      final desc = e['description'] as String?;
      final conf = e['confirmations'] as int? ?? 0;
      return {
        'id': '${e['id']}',
        'title': desc?.isNotEmpty == true ? desc! : label,
        'subtitle': '$label · $conf Bestätigungen',
        'description': desc ?? label,
        'lat': (e['latitude'] as num?)?.toDouble() ?? 0.0,
        'lng': (e['longitude'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }
}
