import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routes/app_router.dart';

/// Top-level handler for background messages (must be top-level function).
/// For data-only FCM messages, we show a local notification here so the
/// user sees it while the app is in the background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[Push] Background message: ${message.messageId}');
  final title = message.data['title'] as String?;
  final body = message.data['body'] as String?;
  if (title == null || title.isEmpty) return;
  try {
    final localNotif = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotif.initialize(const InitializationSettings(android: androidSettings));
    await localNotif.show(
      message.messageId.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'motorinu_default',
          'Motorinu Benachrichtigungen',
          channelDescription: 'Nachrichten, Follower, Gruppen-Einladungen',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  } catch (e) {
    debugPrint('[Push] Background notification error: $e');
  }
}

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  // Lazy — must not be evaluated on Web, where Firebase isn't initialized.
  late final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the push notification system.
  /// Call once after Firebase.initializeApp() and user login.
  Future<void> init() async {
    if (kIsWeb) return; // Push notifications not supported on Web
    if (_initialized) return;
    _initialized = true;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission — wrapped in try-catch for cold-start safety
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
      );
      debugPrint('[Push] Permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('[Push] Permission request failed (cold start?): $e');
      // Retry after short delay — context may not be ready yet
      await Future.delayed(const Duration(seconds: 2));
      try {
        await _messaging.requestPermission(alert: true, badge: true, sound: true);
        debugPrint('[Push] Permission: OK (retry)');
      } catch (e2) {
        debugPrint('[Push] Permission retry also failed: $e2');
      }
    }

    // Setup local notifications (for foreground display)
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        const InitializationSettings(android: androidSettings),
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create notification channels
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'motorinu_default',
            'Motorinu Benachrichtigungen',
            description: 'Nachrichten, Follower, Gruppen-Einladungen',
            importance: Importance.high,
            showBadge: true,
          ),
        );
        // badge_v2: Importance.low statt min — min wird von manchen Launchern ignoriert
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'badge_v2',
            'Badge',
            description: 'App badge count',
            importance: Importance.low,
            showBadge: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Push] Local notification setup error: $e');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Handle notification tap (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Check if app was opened from a notification (cold start)
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        debugPrint('[Push] Cold start — initial message data: ${initial.data}');
        // Store for later — MainShell will call processPendingNavigation()
        // after GoRouter is fully ready
        _pendingNavData = initial.data;
        debugPrint('[Push] Stored pending nav data for later processing');
      }
    } catch (e) {
      debugPrint('[Push] getInitialMessage error: $e');
    }

    // Save FCM token (may fail if user not yet restored from session)
    await saveFcmToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) => saveFcmToken(token: token));

    // ── Re-save token on auth state changes (login / register / re-register) ──
    // Critical: after account delete + re-register, the user_devices row was
    // deleted. Without this listener, the new user has no FCM token in DB
    // and receives no push notifications.
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      // initialSession = App-Start mit gespeicherter Session (KRITISCH!)
      // signedIn = frischer Login
      // tokenRefreshed = JWT-Refresh
      // userUpdated = Profile-Update
      if (event == AuthChangeEvent.signedIn) {
        debugPrint('[Push] Auth event $event → re-saving FCM token + badge');
        saveFcmToken();
        updateBadge();
      }
    });
  }

  bool _savingToken = false;
  String? _lastSavedToken;

  /// Save FCM token to Supabase for this device.
  /// Debounced — skips if already saving or token unchanged.
  Future<void> saveFcmToken({String? token}) async {
    if (kIsWeb) return; // No FCM on Web
    if (_savingToken) return; // Prevent race condition
    _savingToken = true;
    try {
      final fcmToken = token ?? await _messaging.getToken();
      if (fcmToken == null) {
        debugPrint('[Push] No FCM token available');
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('[Push] No user logged in, skipping token save');
        return;
      }

      // Skip if same token already saved this session
      if (_lastSavedToken == fcmToken) {
        debugPrint('[Push] FCM token already saved, skipping');
        return;
      }

      final sb = Supabase.instance.client;

      // Delete ALL rows for this token (prevent duplicates)
      await sb.from('user_devices').delete().eq('fcm_token', fcmToken);

      await sb.from('user_devices').insert({
        'user_id': user.id,
        'fcm_token': fcmToken,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'updated_at': DateTime.now().toIso8601String(),
      });

      _lastSavedToken = fcmToken;
      debugPrint('[Push] FCM token saved OK: ${fcmToken.substring(0, 20)}...');
    } catch (e, st) {
      debugPrint('[Push] Error saving FCM token: $e\n$st');
    } finally {
      _savingToken = false;
    }
  }

  /// Handle foreground message — data-only, no system notification shown.
  /// Just update badge + refresh messages list.
  void _showForegroundNotification(RemoteMessage message) {
    final title = message.data['title'] ?? message.notification?.title;
    debugPrint('[Push] Foreground message: $title (data-only, no banner)');
    updateBadge();
  }

  /// Handle notification tap.
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateFromData(data);
    } catch (_) {}
  }

  /// Handle when app is opened from notification.
  void _onMessageOpenedApp(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  /// Pending navigation data — used when context isn't ready yet.
  static Map<String, dynamic>? _pendingNavData;

  /// Call from main app after router is fully ready to process pending navigation.
  static void processPendingNavigation() {
    if (_pendingNavData != null) {
      debugPrint('[Push] Processing pending navigation: $_pendingNavData');
      final data = _pendingNavData!;
      _pendingNavData = null;
      instance._navigateFromData(data);
    }
  }

  /// Navigate to the right screen based on notification data.
  void _navigateFromData(Map<String, dynamic> data) {
    debugPrint('[Push] Navigate from data: $data');
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('[Push] No navigator context — saving for later');
      _pendingNavData = data;
      return;
    }

    // Check if GoRouter is actually usable
    GoRouter router;
    try {
      router = GoRouter.of(context);
    } catch (e) {
      debugPrint('[Push] GoRouter not ready — saving for later: $e');
      _pendingNavData = data;
      return;
    }

    final type = data['type']?.toString();

    switch (type) {
      case 'like' || 'comment' || 'mention':
        final postId = data['post_id']?.toString();
        if (postId != null) {
          router.push('/post/$postId');
          return;
        }
        final actorId = data['actor_id']?.toString();
        if (actorId != null) router.push('/profile/$actorId');
      case 'follow':
        final followerId = data['follower_id']?.toString();
        if (followerId != null) router.push('/profile/$followerId');
      case 'message':
        final convId = data['conversation_id']?.toString();
        if (convId != null) router.push('/messages/$convId');
      case 'vehicle_offer':
        final convId = data['conversation_id']?.toString();
        if (convId != null) {
          router.push('/messages/$convId');
          return;
        }
        final senderId = data['sender_id']?.toString();
        if (senderId != null) router.push('/profile/$senderId');
      case 'dating_like':
        final actorId = data['actor_id']?.toString();
        if (actorId != null) {
          router.push('/profile/$actorId?showDating=true');
          return;
        }
        router.push('/notifications');
      case 'match':
        // ⚠️ conversation_id vom Server kann falsche Teilnehmer haben!
        // Immer zum Profil navigieren — dort wird die richtige Konversation aufgelöst.
        final actorId = data['actor_id']?.toString();
        if (actorId != null) {
          router.push('/profile/$actorId?showDating=true');
          return;
        }
        router.push('/notifications');
      case 'system':
        final groupId = data['group_id']?.toString();
        if (groupId != null) {
          router.push('/group/$groupId');
          return;
        }
        router.push('/notifications');
      default:
        router.push('/notifications');
    }
  }

  /// Update badge count on app icon.
  Future<void> updateBadge() async {
    if (kIsWeb) return; // No native badge on Web
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Count unread messages (same logic as getTotalUnreadCount)
      final participations = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);
      int msgCount = 0;
      if (participations.isNotEmpty) {
        final convIds = (participations as List)
            .map<int>((p) => p['conversation_id'] as int)
            .toList();
        final unread = await supabase
            .from('messages')
            .select('id')
            .inFilter('conversation_id', convIds)
            .neq('user_id', userId)
            .eq('is_read', false);
        msgCount = (unread as List).length;
      }

      // Count unread notifications
      final notifResult = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      final notifCount = (notifResult as List).length;

      final total = msgCount + notifCount;
      debugPrint('[Push] Badge updated: $total ($msgCount msgs + $notifCount notifs)');

      // Set badge via silent notification, then immediately cancel it.
      // The badge count persists on most launchers even after cancellation.
      // Without cancellation, Vivo/FuntouchOS shows it in the notification drawer.
      await _localNotifications.show(
        99999,
        null,
        null,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'badge_v2',
            'Badge',
            channelDescription: 'App badge count',
            importance: Importance.min,
            priority: Priority.min,
            number: total,
            showWhen: false,
            ongoing: false,
            silent: true,
            playSound: false,
            enableVibration: false,
            onlyAlertOnce: true,
          ),
          iOS: DarwinNotificationDetails(
            badgeNumber: total,
            presentAlert: false,
            presentSound: false,
            presentBadge: true,
          ),
        ),
      );
      // Cancel immediately — badge count stays, notification disappears
      await Future.delayed(const Duration(milliseconds: 200));
      await _localNotifications.cancel(99999);
    } catch (e) {
      debugPrint('[Push] Badge update failed: $e');
    }
  }

  /// Clear badge when user opens the app.
  Future<void> clearBadge() async {
    if (kIsWeb) return;
    // iOS: badge auf 0 setzen, dann Notification entfernen
    await _localNotifications.show(
      99999, null, null,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'badge_v2', 'Badge',
          channelDescription: 'App badge count',
          importance: Importance.min,
          priority: Priority.min,
          number: 0,
          silent: true,
          playSound: false,
          enableVibration: false,
        ),
        iOS: DarwinNotificationDetails(
          badgeNumber: 0,
          presentAlert: false,
          presentSound: false,
          presentBadge: true,
        ),
      ),
    );
    await _localNotifications.cancel(99999);
  }

  /// Remove FCM token on logout.
  Future<void> removeToken() async {
    if (kIsWeb) return;
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) return;

      await Supabase.instance.client
          .from('user_devices')
          .delete()
          .eq('fcm_token', fcmToken);

      debugPrint('[Push] FCM token removed');
    } catch (e) {
      debugPrint('[Push] Error removing token: $e');
    }
  }
}
