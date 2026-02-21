import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SavedPostsStore (Non-Web)
/// Persists bookmarks via SharedPreferences.
///
/// Use:
///   final saved = SavedPostsStore.instance.isSaved(id);
///   final nowSaved = SavedPostsStore.instance.toggle(id);
class SavedPostsStore {
  SavedPostsStore._() {
    _load(); // fire & forget
  }

  static final SavedPostsStore instance = SavedPostsStore._();

  static const String _key = 'bikergram_saved_posts_v1';

  final ValueNotifier<Set<int>> notifier = ValueNotifier<Set<int>>(<int>{});

  SharedPreferences? _prefs;
  bool _loaded = false;
  bool _loading = false;

  bool isSaved(int postId) {
    if (!_loaded && !_loading) {
      _load(); // fire & forget
    }
    return notifier.value.contains(postId);
  }

  /// returns new saved state (optimistic, persists async)
  bool toggle(int postId) {
    final set = SplayTreeSet<int>.from(notifier.value);
    final nowSaved = !set.contains(postId);
    if (nowSaved) {
      set.add(postId);
    } else {
      set.remove(postId);
    }
    notifier.value = set;
    _persist(); // fire & forget
    return nowSaved;
  }

  Future<void> _load() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      _prefs = await SharedPreferences.getInstance();

      // Support migration from older keys if they exist.
      final raw = _prefs!.getString(_key) ?? _prefs!.getString('bikergram_saved_posts') ?? '';

      if (raw.trim().isEmpty) {
        _loaded = true;
        return;
      }

      final decoded = jsonDecode(raw);
      final ids = <int>{};

      if (decoded is List) {
        for (final v in decoded) {
          final i = v is int ? v : int.tryParse(v.toString());
          if (i != null) ids.add(i);
        }
      } else if (decoded is Map) {
        // allow legacy map shape {"ids":[...]}
        final list = decoded['ids'];
        if (list is List) {
          for (final v in list) {
            final i = v is int ? v : int.tryParse(v.toString());
            if (i != null) ids.add(i);
          }
        }
      }

      notifier.value = SplayTreeSet<int>.from(ids);
      _loaded = true;
    } catch (_) {
      // ignore
      _loaded = true;
    } finally {
      _loading = false;
    }
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final list = notifier.value.toList(growable: false);
      await _prefs!.setString(_key, jsonEncode(list));
    } catch (_) {
      // ignore
    }
  }
}
