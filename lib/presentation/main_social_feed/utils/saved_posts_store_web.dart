import 'dart:collection';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// SavedPostsStore (Web)
/// Persists bookmarks in localStorage.
class SavedPostsStore {
  SavedPostsStore._() {
    _load();
  }

  static final SavedPostsStore instance = SavedPostsStore._();

  static const String _key = 'bikergram_saved_posts_v1';

  final ValueNotifier<Set<int>> notifier = ValueNotifier<Set<int>>(<int>{});

  bool isSaved(int postId) => notifier.value.contains(postId);

  bool toggle(int postId) {
    final set = SplayTreeSet<int>.from(notifier.value);
    final nowSaved = !set.contains(postId);
    if (nowSaved) {
      set.add(postId);
    } else {
      set.remove(postId);
    }
    notifier.value = set;
    _persist(set);
    return nowSaved;
  }

  void _load() {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final set = <int>{};
        for (final v in decoded) {
          if (v is int) set.add(v);
          if (v is num) set.add(v.toInt());
          if (v is String) {
            final i = int.tryParse(v);
            if (i != null) set.add(i);
          }
        }
        notifier.value = SplayTreeSet<int>.from(set);
      }
    } catch (_) {
      // ignore corrupt storage
    }
  }

  void _persist(Set<int> set) {
    try {
      html.window.localStorage[_key] = jsonEncode(set.toList(growable: false));
    } catch (_) {
      // ignore
    }
  }
}
