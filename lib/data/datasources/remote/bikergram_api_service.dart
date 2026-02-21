import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api_config.dart';
import '../../../domain/models/auth_tokens.dart';
import '../local/token_storage.dart';

/// Consolidated API service for Bikergram.
///
/// Replaces the 4 separate HTTP clients with a single Dio-based service
/// that supports both the legacy PHP endpoints and the new NestJS endpoints.
class BikergramApiService {
  BikergramApiService({
    required TokenStorage tokenStorage,
    Dio? dio,
    Dio? refreshDio,
  })  : _tokenStorage = tokenStorage,
        _dio = dio ?? _createDio(),
        _refreshDio = refreshDio ?? _createDio() {
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  final TokenStorage _tokenStorage;
  final Dio _dio;
  final Dio _refreshDio; // Separate instance for refresh to avoid deadlock

  /// Feature flags: controls whether to use NestJS (/api/v1/) or PHP (/*.php).
  /// Set to true per feature as the NestJS backend becomes ready.
  static const Map<String, bool> _useNestJs = {
    'auth': false,
    'posts': false,
    'users': false,
    'motorcycles': false,
    'rides': false,
    'marketplace': false,
    'businesses': false,
    'blitzer': false,
    'events': false,
    'xp': false,
    'messages': false,
    'notifications': false,
    'media': false,
    'live_go': false,
    'payments': false,
    'stories': false,
    'follows': false,
  };

  static bool useNestJs(String feature) => _useNestJs[feature] ?? false;

  // ---------------------------------------------------------------------------
  // Auth endpoints
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? username,
  }) async {
    if (useNestJs('auth')) {
      final resp = await _dio.post('/api/v1/auth/register', data: {
        'email': email,
        'password': password,
        if (username != null) 'username': username,
      });
      return resp.data as Map<String, dynamic>;
    }
    final resp = await _dio.post('/register.php', data: {
      'email': email,
      'password': password,
      if (username != null) 'username': username,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (useNestJs('auth')) {
      final resp = await _dio.post('/api/v1/auth/login', data: {
        'email': email,
        'password': password,
      });
      return resp.data as Map<String, dynamic>;
    }
    final resp = await _dio.post('/login.php', data: {
      'email': email,
      'password': password,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async {
    if (useNestJs('auth')) {
      final resp = await _dio.get('/api/v1/auth/me');
      return resp.data as Map<String, dynamic>;
    }
    final resp = await _dio.get('/me.php');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refreshTokens(String refreshToken) async {
    if (useNestJs('auth')) {
      final resp = await _refreshDio.post('/api/v1/auth/refresh', data: {
        'refreshToken': refreshToken,
      });
      return resp.data as Map<String, dynamic>;
    }
    final resp = await _refreshDio.post('/refresh.php', data: {
      'refreshToken': refreshToken,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Feed / Posts
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getFeed({int page = 1, int limit = 20}) async {
    if (useNestJs('posts')) {
      final resp = await _dio.get('/api/v1/posts', queryParameters: {
        'page': page,
        'limit': limit,
      });
      return resp.data as Map<String, dynamic>;
    }
    final resp = await _dio.get('/feed.php', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPost({
    String? caption,
    String? imageUrl,
  }) async {
    if (useNestJs('posts')) {
      final resp = await _dio.post('/api/v1/posts', data: {
        if (caption != null) 'body': caption,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
      return resp.data as Map<String, dynamic>;
    }
    final resp = await _dio.post('/post_create.php', data: {
      if (caption != null) 'caption': caption,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePost(int postId, {
    String? caption,
    String? imageUrl,
  }) async {
    if (useNestJs('posts')) {
      final resp = await _dio.patch('/api/v1/posts/$postId', data: {
        if (caption != null) 'body': caption,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
      return resp.data as Map<String, dynamic>;
    }
    final resp = await _dio.post('/post_update.php', data: {
      'post_id': postId,
      if (caption != null) 'caption': caption,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deletePost(int postId) async {
    if (useNestJs('posts')) {
      await _dio.delete('/api/v1/posts/$postId');
      return;
    }
    await _dio.post('/post_delete.php', data: {'post_id': postId});
  }

  Future<Map<String, dynamic>> toggleLike(int postId) async {
    if (useNestJs('posts')) {
      final resp = await _dio.post('/api/v1/posts/$postId/like');
      return resp.data as Map<String, dynamic>;
    }
    final resp = await _dio.post('/like_toggle.php', data: {'post_id': postId});
    return resp.data as Map<String, dynamic>;
  }

  Future<void> reportPost(int postId, {String? reason, String? details}) async {
    if (useNestJs('posts')) {
      await _dio.post('/api/v1/posts/$postId/report', data: {
        if (reason != null) 'reason': reason,
        if (details != null) 'details': details,
      });
      return;
    }
    await _dio.post('/report_post.php', data: {
      'post_id': postId,
      if (reason != null) 'reason': reason,
      if (details != null) 'details': details,
    });
  }

  // ---------------------------------------------------------------------------
  // Media upload
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> uploadImage(String base64Image) async {
    if (useNestJs('media')) {
      final resp = await _dio.post('/api/v1/media/upload', data: {
        'image': base64Image,
      });
      return resp.data as Map<String, dynamic>;
    }
    final resp = await _dio.post('/upload_image.php', data: {
      'image': base64Image,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Users / Profile
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getUser(int userId) async {
    final resp = await _dio.get('/api/v1/users/$userId');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    if (useNestJs('users')) {
      final resp = await _dio.patch('/api/v1/users/me', data: data);
      return resp.data as Map<String, dynamic>;
    }
    final resp = await _dio.post('/profile_update.php', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> searchUsers(String query) async {
    final resp = await _dio.get('/api/v1/users/search', queryParameters: {'q': query});
    return resp.data as List<dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Follow
  // ---------------------------------------------------------------------------

  Future<void> follow(int userId) async {
    await _dio.post('/api/v1/follows/$userId');
  }

  Future<void> unfollow(int userId) async {
    await _dio.delete('/api/v1/follows/$userId');
  }

  Future<List<dynamic>> getFollowers(int userId, {int page = 1}) async {
    final resp = await _dio.get('/api/v1/users/$userId/followers', queryParameters: {'page': page});
    return resp.data as List<dynamic>;
  }

  Future<List<dynamic>> getFollowing(int userId, {int page = 1}) async {
    final resp = await _dio.get('/api/v1/users/$userId/following', queryParameters: {'page': page});
    return resp.data as List<dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Motorcycles / Garage
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getMyMotorcycles() async {
    final resp = await _dio.get('/api/v1/motorcycles');
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createMotorcycle(Map<String, dynamic> data) async {
    final resp = await _dio.post('/api/v1/motorcycles', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMotorcycle(int id, Map<String, dynamic> data) async {
    final resp = await _dio.patch('/api/v1/motorcycles/$id', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteMotorcycle(int id) async {
    await _dio.delete('/api/v1/motorcycles/$id');
  }

  // ---------------------------------------------------------------------------
  // Rides
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getRideHistory({int page = 1}) async {
    final resp = await _dio.get('/api/v1/rides', queryParameters: {'page': page});
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> saveRide(Map<String, dynamic> data) async {
    final resp = await _dio.post('/api/v1/rides', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<void> uploadRidePoints(int rideId, List<Map<String, dynamic>> points) async {
    await _dio.post('/api/v1/rides/$rideId/points', data: {'points': points});
  }

  // ---------------------------------------------------------------------------
  // Marketplace
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getListings({
    int page = 1,
    int limit = 20,
    String? category,
    String? query,
    String? sort,
  }) async {
    final resp = await _dio.get('/api/v1/marketplace', queryParameters: {
      'page': page,
      'limit': limit,
      if (category != null) 'category': category,
      if (query != null) 'q': query,
      if (sort != null) 'sort': sort,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createListing(Map<String, dynamic> data) async {
    final resp = await _dio.post('/api/v1/marketplace', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateListing(int id, Map<String, dynamic> data) async {
    final resp = await _dio.patch('/api/v1/marketplace/$id', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteListing(int id) async {
    await _dio.delete('/api/v1/marketplace/$id');
  }

  // ---------------------------------------------------------------------------
  // Business Directory
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getBusinesses({
    double? lat,
    double? lng,
    double? radius,
    String? category,
  }) async {
    final resp = await _dio.get('/api/v1/businesses', queryParameters: {
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (radius != null) 'radius': radius,
      if (category != null) 'category': category,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createBusinessReview(int businessId, {
    required int rating,
    String? body,
  }) async {
    final resp = await _dio.post('/api/v1/businesses/$businessId/reviews', data: {
      'rating': rating,
      if (body != null) 'body': body,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Blitzer
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getBlitzers({
    required double lat,
    required double lng,
    double radius = 10,
  }) async {
    final resp = await _dio.get('/api/v1/blitzer', queryParameters: {
      'lat': lat,
      'lng': lng,
      'radius': radius,
    });
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> reportBlitzer(Map<String, dynamic> data) async {
    final resp = await _dio.post('/api/v1/blitzer', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<void> confirmBlitzer(int id) async {
    await _dio.post('/api/v1/blitzer/$id/confirm');
  }

  Future<void> dismissBlitzer(int id) async {
    await _dio.post('/api/v1/blitzer/$id/dismiss');
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getEvents({double? lat, double? lng}) async {
    final resp = await _dio.get('/api/v1/events', queryParameters: {
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data) async {
    final resp = await _dio.post('/api/v1/events', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<void> participateEvent(int eventId, {String status = 'going'}) async {
    await _dio.post('/api/v1/events/$eventId/participate', data: {'status': status});
  }

  Future<void> leaveEvent(int eventId) async {
    await _dio.delete('/api/v1/events/$eventId/participate');
  }

  // ---------------------------------------------------------------------------
  // XP / Gamification
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getXpSummary() async {
    final resp = await _dio.get('/api/v1/xp/summary');
    return resp.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getXpTransactions({int page = 1}) async {
    final resp = await _dio.get('/api/v1/xp/transactions', queryParameters: {'page': page});
    return resp.data as List<dynamic>;
  }

  Future<List<dynamic>> getAchievements() async {
    final resp = await _dio.get('/api/v1/achievements');
    return resp.data as List<dynamic>;
  }

  Future<List<dynamic>> getMyAchievements() async {
    final resp = await _dio.get('/api/v1/achievements/me');
    return resp.data as List<dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getConversations() async {
    final resp = await _dio.get('/api/v1/conversations');
    return resp.data as List<dynamic>;
  }

  Future<List<dynamic>> getMessages(int conversationId, {int page = 1}) async {
    final resp = await _dio.get('/api/v1/conversations/$conversationId/messages',
        queryParameters: {'page': page});
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    required String body,
    String? imageUrl,
  }) async {
    final resp = await _dio.post('/api/v1/messages', data: {
      'conversationId': conversationId,
      'body': body,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startConversation(int userId) async {
    final resp = await _dio.post('/api/v1/conversations/$userId');
    return resp.data as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getNotifications() async {
    final resp = await _dio.get('/api/v1/notifications');
    return resp.data as List<dynamic>;
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.post('/api/v1/notifications/read-all');
  }

  // ---------------------------------------------------------------------------
  // Live-Go
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getActiveRiders() async {
    final resp = await _dio.get('/api/v1/live-go/active');
    return resp.data as List<dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Payments (Stripe)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createCheckoutSession({
    required String priceId,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final resp = await _dio.post('/api/v1/payments/create-checkout-session', data: {
      'priceId': priceId,
      if (successUrl != null) 'successUrl': successUrl,
      if (cancelUrl != null) 'cancelUrl': cancelUrl,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPortalSession() async {
    final resp = await _dio.post('/api/v1/payments/create-portal-session');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final resp = await _dio.get('/api/v1/payments/subscription-status');
    return resp.data as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Stories
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getStories() async {
    final resp = await _dio.get('/api/v1/stories');
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createStory({
    required String mediaUrl,
    String mediaType = 'image',
    String? caption,
  }) async {
    final resp = await _dio.post('/api/v1/stories', data: {
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      if (caption != null) 'caption': caption,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteStory(int id) async {
    await _dio.delete('/api/v1/stories/$id');
  }

  // ---------------------------------------------------------------------------
  // Comments
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getComments(int postId, {int page = 1}) async {
    final resp = await _dio.get('/api/v1/posts/$postId/comments',
        queryParameters: {'page': page});
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createComment(int postId, {
    required String body,
    int? parentId,
  }) async {
    final resp = await _dio.post('/api/v1/posts/$postId/comments', data: {
      'body': body,
      if (parentId != null) 'parentId': parentId,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Internal: Token access for interceptor
  // ---------------------------------------------------------------------------

  Future<String?> getAccessToken() => _tokenStorage.accessToken;
  TokenStorage get tokenStorage => _tokenStorage;

  // ---------------------------------------------------------------------------
  // Dio factory
  // ---------------------------------------------------------------------------

  static Dio _createDio() {
    return Dio(BaseOptions(
      baseUrl: ApiConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
      // IMPORTANT: Use contentType property, NOT headers map.
      // Dio ignores Content-Type in headers for POST requests and
      // auto-sets it based on data type. Only contentType property works.
      contentType: 'application/json; charset=utf-8',
      headers: {
        'Accept': 'application/json',
      },
      // Accept all status codes so we can read error response bodies.
      // Our code handles errors via the {"ok":false,"error":{...}} envelope.
      validateStatus: (status) => status != null && status < 500,
    ))
      ..interceptors.add(LogInterceptor(
        requestBody: kDebugMode,
        responseBody: kDebugMode,
        logPrint: (o) => debugPrint('[API] $o'),
      ));
  }
}

// -----------------------------------------------------------------------------
// Auth interceptor: attaches Bearer token, handles 401 with refresh
// -----------------------------------------------------------------------------

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._service);

  final BikergramApiService _service;
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  static const _noAuthPaths = [
    '/register.php', '/login.php', '/refresh.php',
    '/api/v1/auth/register', '/api/v1/auth/login', '/api/v1/auth/refresh',
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final path = options.path;
    if (_noAuthPaths.any((p) => path.contains(p))) {
      return handler.next(options);
    }

    final token = await _service.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    // Since validateStatus accepts < 500, we get 401 as a response, not error.
    // For auth paths (login, register), 401 means invalid credentials — pass through.
    final path = response.requestOptions.path;
    if (_noAuthPaths.any((p) => path.contains(p))) {
      return handler.next(response);
    }

    // For protected endpoints, 401 means expired token — try refresh.
    if (response.statusCode == 401) {
      try {
        final newToken = await _tryRefresh();
        if (newToken != null) {
          final opts = response.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          final retryResp = await _service._dio.fetch(opts);
          return handler.resolve(retryResp);
        }
      } catch (_) {
        // Refresh failed, return the original 401 response
      }
    }

    handler.next(response);
  }

  Future<String?> _tryRefresh() async {
    if (_isRefreshing) {
      return _refreshCompleter?.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final tokens = await _service.tokenStorage.read();
      if (tokens == null) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final data = await _service.refreshTokens(tokens.refreshToken);
      final newAccess = data['accessToken'] ?? data['access_token'];
      final newRefresh = data['refreshToken'] ?? data['refresh_token'] ?? tokens.refreshToken;

      if (newAccess == null) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final newPair = AuthTokenPair(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      await _service.tokenStorage.write(newPair, reason: 'auto_refresh');

      _refreshCompleter!.complete(newAccess);
      return newAccess;
    } catch (e) {
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _isRefreshing = false;
    }
  }
}
