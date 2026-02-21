import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/repositories/blitzer_repository.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/ride_repository.dart';
import '../../data/repositories/story_repository.dart';
import '../../data/repositories/live_repository.dart';
import '../../data/repositories/moderation_repository.dart';

// ---------------------------------------------------------------------------
// Theme mode (persisted to SharedPreferences)
// ---------------------------------------------------------------------------

const _themeKey = 'theme_mode';

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Load persisted value on first build
    _loadSaved();
    return ThemeMode.dark; // default
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);
    if (saved == 'light') {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _persist();
  }

  void setMode(ThemeMode mode) {
    state = mode;
    _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _themeKey, state == ThemeMode.light ? 'light' : 'dark');
  }
}

// ---------------------------------------------------------------------------
// Community selection (persisted to Supabase profile)
// ---------------------------------------------------------------------------

/// The currently selected community. Null until the user picks one.
final communityProvider =
    NotifierProvider<CommunityNotifier, Community?>(CommunityNotifier.new);

class CommunityNotifier extends Notifier<Community?> {
  @override
  Community? build() => null;

  void select(Community? community) {
    state = community;
    // Persist to Supabase profile
    if (community != null) {
      _saveToProfile(community.name);
    }
  }

  Future<void> _saveToProfile(String communityName) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'community': communityName})
          .eq('id', userId);
    } catch (_) {
      // Silently ignore — community is still set in memory
    }
  }
}

// ---------------------------------------------------------------------------
// Repositories — Supabase-based
// ---------------------------------------------------------------------------

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository();
});

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository();
});

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository();
});

final blitzerRepositoryProvider = Provider<BlitzerRepository>((ref) {
  return BlitzerRepository();
});

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository();
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository();
});

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepository();
});

final liveRepositoryProvider = Provider<LiveRepository>((ref) {
  return LiveRepository();
});

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository();
});
