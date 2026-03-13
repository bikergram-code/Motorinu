import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Upload an avatar image and update the profile with the new URL.
  /// [community] determines which avatar field to update:
  /// - 'bikergram' → avatar_url
  /// - 'cargram'  → avatar_url_cargram
  Future<String> uploadAvatar(
    Uint8List imageBytes,
    String fileName, {
    String community = 'bikergram',
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final ext = fileName.split('.').last.toLowerCase();
    final prefix = community == 'cargram' ? 'avatar_car' : 'avatar';
    final path =
        '$userId/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage.from('posts').uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    final publicUrl = _supabase.storage.from('posts').getPublicUrl(path);

    // Update the correct avatar field based on community
    if (community == 'cargram') {
      await updateProfile(avatarUrlCargram: publicUrl);
    } else {
      await updateProfile(avatarUrl: publicUrl);
    }

    return publicUrl;
  }

  Future<Map<String, dynamic>> getProfile(String userId) async {
    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return data;
  }

  Future<void> updateProfile({
    String? username,
    String? displayName,
    String? bikername,
    String? bio,
    String? postalCode,
    String? country,
    String? avatarUrl,
    String? avatarUrlCargram,
    int? birthYear,
    int? motoStartAge,
    int? carStartAge,
    bool? hasTrackExperience,
    double? homeLat,
    double? homeLng,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (username != null) updates['username'] = username;
    if (displayName != null) updates['display_name'] = displayName;
    if (bikername != null) updates['bikername'] = bikername;
    if (bio != null) updates['bio'] = bio;
    if (postalCode != null) updates['postal_code'] = postalCode;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (avatarUrlCargram != null) {
      updates['avatar_url_cargram'] = avatarUrlCargram;
    }
    if (birthYear != null) updates['birth_year'] = birthYear;
    if (motoStartAge != null) updates['moto_start_age'] = motoStartAge;
    if (carStartAge != null) updates['car_start_age'] = carStartAge;
    if (hasTrackExperience != null) {
      updates['has_track_experience'] = hasTrackExperience;
    }

    await _supabase.from('profiles').update(updates).eq('id', userId);

    // country separat — Spalte existiert evtl. noch nicht
    if (country != null) {
      try {
        await _supabase.from('profiles').update({
          'country': country,
        }).eq('id', userId);
      } catch (e) {
        debugPrint('[Profile] country update failed (migration pending?): $e');
      }
    }

    // home_lat / home_lng separat — Spalten existieren evtl. noch nicht
    if (homeLat != null && homeLng != null) {
      try {
        await _supabase.from('profiles').update({
          'home_lat': homeLat,
          'home_lng': homeLng,
        }).eq('id', userId);
      } catch (e) {
        debugPrint('[Profile] home_lat/home_lng update failed (migration pending?): $e');
      }
    }
  }

  Future<int> getPostCount(String userId) async {
    final data = await _supabase
        .from('posts')
        .select('id')
        .eq('user_id', userId);
    return data.length;
  }

  Future<int> getFollowerCount(String userId) async {
    final data = await _supabase
        .from('follows')
        .select('id')
        .eq('following_id', userId);
    return data.length;
  }

  Future<int> getFollowingCount(String userId) async {
    final data = await _supabase
        .from('follows')
        .select('id')
        .eq('follower_id', userId);
    return data.length;
  }

  /// Get the set of user IDs that the current user is following.
  /// Optionally filtered by community (e.g. 'bikergram', 'cars').
  Future<Set<String>> getFollowingIds({String? community}) async {
    final userId = _currentUserId;
    if (userId == null) return {};

    var query = _supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);

    if (community != null) {
      query = query.or('community.eq.$community,community.is.null');
    }

    final data = await query;
    return data
        .map<String>((row) => row['following_id'] as String)
        .toSet();
  }

  /// Get total likes across all posts by a user.
  Future<int> getTotalLikes(String userId) async {
    try {
      final data = await _supabase
          .from('posts')
          .select('like_count')
          .eq('user_id', userId);
      int total = 0;
      for (final row in data) {
        total += (row['like_count'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> isFollowing(String targetUserId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final data = await _supabase
        .from('follows')
        .select('id')
        .eq('follower_id', userId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    return data != null;
  }

  /// Search users by username, display_name or bikername.
  Future<List<Map<String, dynamic>>> searchUsers(String query, {int limit = 20}) async {
    final data = await _supabase
        .from('profiles')
        .select('id, username, display_name, bikername, bio, avatar_url, avatar_url_cargram, level, is_premium, is_business, community')
        .or('username.ilike.%$query%,display_name.ilike.%$query%,bikername.ilike.%$query%')
        .neq('id', _currentUserId ?? '')
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Get suggested users — smart algorithm (PLZ proximity, community, FoF).
  /// Uses the Supabase RPC `get_suggested_users` for server-side scoring.
  Future<List<Map<String, dynamic>>> getSuggestedUsers({int limit = 15}) async {
    final data = await _supabase
        .rpc('get_suggested_users', params: {'p_limit': limit});
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<bool> toggleFollow(String targetUserId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final existing = await _supabase
        .from('follows')
        .select('id')
        .eq('follower_id', userId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', userId)
          .eq('following_id', targetUserId);
      return false;
    } else {
      await _supabase.from('follows').insert({
        'follower_id': userId,
        'following_id': targetUserId,
      });
      return true;
    }
  }
}
