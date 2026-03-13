import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';

/// Repository for biker groups (Fahrgruppen, Chat-Gruppen, Clubs).
class GroupRepository {
  GroupRepository();

  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ═══════════════════════════════════════════════════
  //  BROWSE / DISCOVERY
  // ═══════════════════════════════════════════════════

  /// Get all groups the current user is a member of.
  Future<List<BikerGroup>> getMyGroups({String? community}) async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('[GroupRepo] getMyGroups: no userId, returning []');
      return [];
    }

    final communityFilter = community ?? 'bikergram';
    debugPrint('[GroupRepo] getMyGroups: userId=$userId community=$communityFilter');

    try {
      // Use RPC to bypass RLS issues with self-referencing policies
      final data = await _supabase.rpc('get_my_groups', params: {
        'p_community': communityFilter,
      });

      debugPrint('[GroupRepo] getMyGroups RPC returned ${(data as List).length} groups');

      if (data.isEmpty) return [];

      // Build role map from the returned data
      final roleMap = <int, String>{};
      for (final g in data) {
        final gid = (g['id'] as num).toInt();
        roleMap[gid] = g['user_role'] as String? ?? 'member';
      }

      // Fetch creator profiles separately
      final enriched = await _enrichWithCreatorProfiles(data);
      return _enrichGroups(enriched, roleMap: roleMap);
    } catch (e) {
      debugPrint('[GroupRepo] getMyGroups RPC error: $e');
      // Fallback to direct queries
      return _getMyGroupsFallback(userId, communityFilter);
    }
  }

  /// Fallback if RPC not available.
  Future<List<BikerGroup>> _getMyGroupsFallback(
      String userId, String communityFilter) async {
    try {
      debugPrint('[GroupRepo] _getMyGroupsFallback starting...');
      final memberships = await _supabase
          .from('group_members')
          .select('group_id, role')
          .eq('user_id', userId);

      debugPrint('[GroupRepo] memberships: ${memberships.length}');
      if (memberships.isEmpty) return [];

      final groupIds =
          memberships.map((m) => (m['group_id'] as num).toInt()).toList();
      final roleMap = <int, String>{};
      for (final m in memberships) {
        roleMap[(m['group_id'] as num).toInt()] = m['role'] as String;
      }

      debugPrint('[GroupRepo] groupIds: $groupIds');

      final data = await _supabase
          .from('groups')
          .select()
          .inFilter('id', groupIds)
          .eq('community', communityFilter)
          .order('updated_at', ascending: false);

      debugPrint('[GroupRepo] groups query returned: ${data.length}');

      final enriched = await _enrichWithCreatorProfiles(data);
      return _enrichGroups(enriched, roleMap: roleMap);
    } catch (e) {
      debugPrint('[GroupRepo] _getMyGroupsFallback error: $e');
      return [];
    }
  }

  /// Discover public groups (not yet a member).
  Future<List<BikerGroup>> discoverGroups({
    String? community,
    String? groupType,
    int limit = 50,
  }) async {
    final communityFilter = community ?? 'bikergram';
    debugPrint('[GroupRepo] discoverGroups: community=$communityFilter type=$groupType');

    try {
      // Use RPC to bypass RLS
      final data = await _supabase.rpc('discover_public_groups', params: {
        'p_community': communityFilter,
        'p_group_type': groupType,
        'p_limit': limit,
      });

      debugPrint('[GroupRepo] discoverGroups RPC returned ${(data as List).length}');

      final enriched = await _enrichWithCreatorProfiles(data);
      return _enrichGroups(enriched);
    } catch (e) {
      debugPrint('[GroupRepo] discoverGroups RPC error: $e');
      // Fallback to direct queries
      return _discoverGroupsFallback(communityFilter, groupType, limit);
    }
  }

  /// Fallback if RPC not available.
  Future<List<BikerGroup>> _discoverGroupsFallback(
      String communityFilter, String? groupType, int limit) async {
    final userId = _currentUserId;
    try {
      var query = _supabase
          .from('groups')
          .select()
          .eq('community', communityFilter)
          .eq('is_public', true);

      if (groupType != null) {
        query = query.eq('group_type', groupType);
      }

      final data =
          await query.order('member_count', ascending: false).limit(limit);

      final enriched = await _enrichWithCreatorProfiles(data);

      if (userId != null) {
        final memberships = await _supabase
            .from('group_members')
            .select('group_id')
            .eq('user_id', userId);

        final myGroupIds = memberships
            .map((m) => (m['group_id'] as num).toInt())
            .toSet();

        final filtered = enriched
            .where((d) => !myGroupIds.contains((d['id'] as num).toInt()))
            .toList();

        return _enrichGroups(filtered);
      }

      return _enrichGroups(enriched);
    } catch (e) {
      debugPrint('[GroupRepo] _discoverGroupsFallback error: $e');
      return [];
    }
  }

  /// Get a single group by ID with enrichment.
  Future<BikerGroup?> getGroupById(int groupId) async {
    // Try RPC first (bypasses RLS for reliable loading)
    try {
      final data = await _supabase.rpc('get_group_by_id', params: {
        'p_group_id': groupId,
      });
      if (data != null) {
        final map = Map<String, dynamic>.from(data as Map<String, dynamic>);
        // Build profiles sub-map from flat fields
        map['profiles'] = {
          'username': map.remove('creator_username'),
          'display_name': map.remove('creator_display_name'),
          'avatar_url': map.remove('creator_avatar_url'),
        };
        final role = map.remove('user_role') as String?;
        final convId = (map.remove('conversation_id') as num?)?.toInt();
        debugPrint('[GroupRepo] getGroupById RPC OK: id=$groupId role=$role convId=$convId');
        return BikerGroup.fromSupabase(
          map,
          currentUserId: _currentUserId,
          isMember: role != null,
          isAdmin: role == 'admin',
          conversationId: convId,
        );
      }
    } catch (e) {
      debugPrint('[GroupRepo] getGroupById RPC error: $e');
    }

    // Fallback: direct queries
    return _getGroupByIdFallback(groupId);
  }

  /// Fallback for getGroupById when RPC is not available.
  Future<BikerGroup?> _getGroupByIdFallback(int groupId) async {
    try {
      final data = await _supabase
          .from('groups')
          .select()
          .eq('id', groupId)
          .maybeSingle();

      debugPrint('[GroupRepo] getGroupById fallback: groups query → ${data != null ? 'found' : 'null'}');
      if (data == null) return null;

      // Enrich with creator profile
      final creatorId = data['creator_id'] as String?;
      Map<String, dynamic> enrichedData = Map<String, dynamic>.from(data);
      if (creatorId != null) {
        try {
          final profile = await _supabase
              .from('profiles')
              .select('username, display_name, avatar_url')
              .eq('id', creatorId)
              .maybeSingle();
          if (profile != null) {
            enrichedData['profiles'] = profile;
          }
        } catch (e) {
          debugPrint('[GroupRepo] getGroupById fallback: profiles query error: $e');
        }
      }

      final userId = _currentUserId;
      String? role;
      if (userId != null) {
        try {
          final membership = await _supabase
              .from('group_members')
              .select('role')
              .eq('group_id', groupId)
              .eq('user_id', userId)
              .maybeSingle();
          role = membership?['role'] as String?;
        } catch (e) {
          debugPrint('[GroupRepo] getGroupById fallback: membership query error: $e');
        }
      }

      // Get conversation ID
      int? convId;
      try {
        final conv = await _supabase
            .from('conversations')
            .select('id')
            .eq('group_id', groupId)
            .maybeSingle();
        convId = conv?['id'] as int?;
      } catch (e) {
        debugPrint('[GroupRepo] getGroupById fallback: conversations query error: $e');
      }

      return BikerGroup.fromSupabase(
        enrichedData,
        currentUserId: userId,
        isMember: role != null,
        isAdmin: role == 'admin',
        conversationId: convId,
      );
    } catch (e) {
      debugPrint('[GroupRepo] getGroupById fallback error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════
  //  CREATE / UPDATE / DELETE
  // ═══════════════════════════════════════════════════

  /// Create a new group (via RPC — creates group + conversation + auto-join).
  Future<int> createGroup({
    required String name,
    String? description,
    String groupType = 'chat',
    String community = 'bikergram',
    bool isPublic = true,
    String rideColor = '#4CAF50',
    int? maxMembers,
  }) async {
    debugPrint('[GroupRepo] createGroup: name=$name type=$groupType community=$community');
    final result = await _supabase.rpc('create_group', params: {
      'p_name': name,
      'p_description': description,
      'p_group_type': groupType,
      'p_community': community,
      'p_is_public': isPublic,
      'p_ride_color': rideColor,
      'p_max_members': maxMembers,
    });
    final groupId = result is int ? result : int.parse(result.toString());
    debugPrint('[GroupRepo] createGroup SUCCESS: groupId=$groupId');
    return groupId;
  }

  /// Update group details (admin only) — via RPC (bypasses RLS).
  Future<void> updateGroup(
    int groupId, {
    String? name,
    String? description,
    String? avatarUrl,
    bool? isPublic,
    String? rideColor,
    int? maxMembers,
  }) async {
    try {
      await _supabase.rpc('update_group', params: {
        'p_group_id': groupId,
        'p_name': name,
        'p_description': description,
        'p_avatar_url': avatarUrl,
        'p_is_public': isPublic,
        'p_ride_color': rideColor,
        'p_max_members': maxMembers,
      });
      debugPrint('[GroupRepo] updateGroup RPC OK: groupId=$groupId');
    } catch (e) {
      debugPrint('[GroupRepo] updateGroup RPC error: $e — trying direct update');
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (isPublic != null) updates['is_public'] = isPublic;
      if (rideColor != null) updates['ride_color'] = rideColor;
      if (maxMembers != null) updates['max_members'] = maxMembers;
      await _supabase.from('groups').update(updates).eq('id', groupId);
    }
  }

  /// Delete group (only creator) — via RPC (bypasses RLS).
  Future<void> deleteGroup(int groupId) async {
    try {
      await _supabase.rpc('delete_group', params: {'p_group_id': groupId});
      debugPrint('[GroupRepo] deleteGroup RPC OK: groupId=$groupId');
    } catch (e) {
      debugPrint('[GroupRepo] deleteGroup RPC error: $e — trying direct delete');
      await _supabase.from('groups').delete().eq('id', groupId);
    }
  }

  // ═══════════════════════════════════════════════════
  //  MEMBERSHIP
  // ═══════════════════════════════════════════════════

  /// Join group (via RPC — adds to group_members + conversation_participants).
  Future<void> joinGroup(int groupId) async {
    await _supabase.rpc('join_group', params: {'p_group_id': groupId});
  }

  /// Leave group (via RPC).
  Future<void> leaveGroup(int groupId) async {
    await _supabase.rpc('leave_group', params: {'p_group_id': groupId});
  }

  /// Get members of a group with profile data.
  /// Uses RPC (SECURITY DEFINER) to bypass RLS, with direct-query fallback.
  Future<List<GroupMember>> getGroupMembers(int groupId) async {
    // Try RPC first (bypasses RLS)
    try {
      final rpcResult = await _supabase.rpc('get_group_members', params: {
        'p_group_id': groupId,
      });
      if (rpcResult != null) {
        final list = rpcResult as List;
        return list.map((d) {
          final m = Map<String, dynamic>.from(d as Map);
          // Build 'profiles' sub-map for GroupMember.fromSupabase()
          m['profiles'] = {
            'username': m.remove('username'),
            'display_name': m.remove('display_name'),
            'avatar_url': m.remove('avatar_url'),
          };
          return GroupMember.fromSupabase(m);
        }).toList();
      }
    } catch (e) {
      debugPrint('[GroupRepo] getGroupMembers RPC error: $e');
    }

    // Fallback: direct query (may fail due to RLS)
    try {
      final data = await _supabase
          .from('group_members')
          .select('*, profiles(username, display_name, avatar_url)')
          .eq('group_id', groupId)
          .order('role', ascending: true) // admins first
          .order('joined_at', ascending: true);

      return (data as List).map((d) => GroupMember.fromSupabase(d)).toList();
    } catch (e) {
      debugPrint('[GroupRepo] getGroupMembers fallback error: $e');
      return [];
    }
  }

  /// Add members to a group (admin action — uses RPC).
  Future<void> addMembersToGroup(int groupId, List<String> userIds) async {
    if (userIds.isEmpty) return;
    await _supabase.rpc('add_members_to_group', params: {
      'p_group_id': groupId,
      'p_user_ids': userIds,
    });
  }

  /// Get profiles of users the current user follows (for friend picker).
  Future<List<Map<String, dynamic>>> getFollowingProfiles() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final data = await _supabase
          .from('follows')
          .select('following_id, profiles:following_id(id, username, display_name, avatar_url)')
          .eq('follower_id', userId);

      return (data as List).map((d) {
        final profile = d['profiles'] as Map<String, dynamic>? ?? {};
        return {
          'id': profile['id'] ?? d['following_id'],
          'username': profile['username'],
          'display_name': profile['display_name'],
          'avatar_url': profile['avatar_url'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[GroupRepo] getFollowingProfiles error: $e');
      return [];
    }
  }

  /// Get the conversation ID for a group's chat.
  Future<int?> getGroupConversationId(int groupId) async {
    final conv = await _supabase
        .from('conversations')
        .select('id')
        .eq('group_id', groupId)
        .maybeSingle();
    return conv?['id'] as int?;
  }

  // ═══════════════════════════════════════════════════
  //  RIDE MANAGEMENT
  // ═══════════════════════════════════════════════════

  /// Start a group ride (admin only) — via RPC (bypasses RLS).
  Future<void> startRide(int groupId) async {
    try {
      await _supabase.rpc('start_ride', params: {'p_group_id': groupId});
      debugPrint('[GroupRepo] startRide RPC OK: groupId=$groupId');
    } catch (e) {
      debugPrint('[GroupRepo] startRide RPC error: $e — trying direct update');
      // Fallback: direct update (needs RLS permission)
      await _supabase
          .from('groups')
          .update({'is_ride_active': true, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', groupId);
    }
  }

  /// Stop a group ride — via RPC (bypasses RLS).
  Future<void> stopRide(int groupId) async {
    try {
      await _supabase.rpc('stop_ride', params: {'p_group_id': groupId});
      debugPrint('[GroupRepo] stopRide RPC OK: groupId=$groupId');
    } catch (e) {
      debugPrint('[GroupRepo] stopRide RPC error: $e — trying direct update');
      await _supabase
          .from('groups')
          .update({
            'is_ride_active': false,
            'destination_lat': null,
            'destination_lng': null,
            'destination_name': null,
          })
          .eq('id', groupId);
    }
  }

  /// Set navigation destination for a group ride (admin only).
  Future<void> setDestination(
    int groupId, {
    required double lat,
    required double lng,
    required String name,
  }) async {
    await _supabase.from('groups').update({
      'destination_lat': lat,
      'destination_lng': lng,
      'destination_name': name,
    }).eq('id', groupId);
  }

  /// Clear navigation destination.
  Future<void> clearDestination(int groupId) async {
    await _supabase.from('groups').update({
      'destination_lat': null,
      'destination_lng': null,
      'destination_name': null,
    }).eq('id', groupId);
  }

  // ═══════════════════════════════════════════════════
  //  ADMIN: MEMBER MANAGEMENT
  // ═══════════════════════════════════════════════════

  /// Promote a member to admin (admin only).
  Future<void> promoteMember(int groupId, String userId) async {
    await _supabase
        .from('group_members')
        .update({'role': 'admin'})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Demote an admin back to member (admin only).
  Future<void> demoteMember(int groupId, String userId) async {
    await _supabase
        .from('group_members')
        .update({'role': 'member'})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Kick a member from the group (admin only, via RPC).
  Future<void> kickMember(int groupId, String userId) async {
    try {
      await _supabase.rpc('kick_member', params: {
        'p_group_id': groupId,
        'p_user_id': userId,
      });
    } catch (e) {
      debugPrint('[GroupRepo] kickMember RPC error: $e, trying direct');
      // Fallback: direct delete
      await _supabase
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
      // Update member count
      await _supabase.from('groups').update({
        'member_count': await _supabase
            .from('group_members')
            .select()
            .eq('group_id', groupId)
            .count(CountOption.exact)
            .then((r) => r.count),
      }).eq('id', groupId);
    }
  }

  // ═══════════════════════════════════════════════════
  //  IMAGE UPLOAD
  // ═══════════════════════════════════════════════════

  /// Upload group avatar. Returns public URL.
  Future<String> uploadGroupAvatar(Uint8List bytes, int groupId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'groups/$groupId/$timestamp.jpg';

    await _supabase.storage.from('posts').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return _supabase.storage.from('posts').getPublicUrl(path);
  }

  // ═══════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ═══════════════════════════════════════════════════

  /// Fetch creator profiles separately and merge into group data.
  Future<List<Map<String, dynamic>>> _enrichWithCreatorProfiles(
      List<dynamic> groups) async {
    if (groups.isEmpty) return [];

    // Collect unique creator IDs
    final creatorIds = <String>{};
    for (final g in groups) {
      final cid = (g as Map<String, dynamic>)['creator_id'] as String?;
      if (cid != null) creatorIds.add(cid);
    }

    if (creatorIds.isEmpty) {
      return groups.cast<Map<String, dynamic>>();
    }

    // Batch fetch profiles
    Map<String, Map<String, dynamic>> profileMap = {};
    try {
      final profiles = await _supabase
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .inFilter('id', creatorIds.toList());

      for (final p in profiles) {
        profileMap[p['id'] as String] = p;
      }
    } catch (e) {
      debugPrint('[GroupRepo] _enrichWithCreatorProfiles error: $e');
    }

    // Merge profiles into group data
    return groups.map((g) {
      final data = Map<String, dynamic>.from(g as Map<String, dynamic>);
      final cid = data['creator_id'] as String?;
      if (cid != null && profileMap.containsKey(cid)) {
        data['profiles'] = profileMap[cid];
      }
      return data;
    }).toList();
  }

  List<BikerGroup> _enrichGroups(
    List<dynamic> rawGroups, {
    Map<int, String>? roleMap,
  }) {
    final userId = _currentUserId;
    return rawGroups.map((raw) {
      final data = raw as Map<String, dynamic>;
      final groupId = (data['id'] as num).toInt();
      final role = roleMap?[groupId];

      return BikerGroup.fromSupabase(
        data,
        currentUserId: userId,
        isMember: role != null,
        isAdmin: role == 'admin',
      );
    }).toList();
  }
}
