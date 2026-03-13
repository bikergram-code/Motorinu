import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Singleton service that caches videos to local storage for instant replay.
///
/// First view: streams from URL (unchanged behavior) + caches in background.
/// Second view: loads from local file (instant!).
///
/// Uses [flutter_cache_manager] which is already a transitive dependency
/// via cached_network_image — no new packages needed.
class VideoCacheService {
  VideoCacheService._();
  static final VideoCacheService instance = VideoCacheService._();

  final _cacheManager = CacheManager(
    Config(
      'bikergram_video_cache',
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 50,
    ),
  );

  /// URLs currently being prefetched (avoids duplicate concurrent downloads).
  final Set<String> _activePrefetches = {};

  /// Returns local file path if the video is already cached,
  /// otherwise returns the original URL (for network streaming).
  ///
  /// This is a fast local-only check (no network), <1ms overhead.
  Future<String> getVideoPath(String url) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);
      if (fileInfo != null) {
        debugPrint('[VideoCache] HIT: ${url.split('/').last}');
        return fileInfo.file.path;
      }
    } catch (e) {
      debugPrint('[VideoCache] Cache lookup error: $e');
    }
    return url; // Not cached → stream from network
  }

  /// Download a video to cache in the background.
  /// Non-blocking, silent on error. Safe to call fire-and-forget.
  Future<void> prefetch(String url) async {
    if (url.isEmpty || _activePrefetches.contains(url)) return;
    _activePrefetches.add(url);
    try {
      // Check if already cached — skip download if so
      final existing = await _cacheManager.getFileFromCache(url);
      if (existing != null) {
        _activePrefetches.remove(url);
        return;
      }

      debugPrint('[VideoCache] Prefetching: ${url.split('/').last}');
      await _cacheManager.downloadFile(url);
      debugPrint('[VideoCache] Cached: ${url.split('/').last}');
    } catch (e) {
      debugPrint('[VideoCache] Prefetch error: $e');
    } finally {
      _activePrefetches.remove(url);
    }
  }

  /// Prefetch multiple videos sequentially (one at a time to avoid
  /// bandwidth contention with the currently playing video).
  Future<void> prefetchList(List<String> urls) async {
    for (final url in urls) {
      await prefetch(url);
    }
  }
}
