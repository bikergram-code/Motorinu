import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/core/providers.dart';

/// WhatsApp-style bottom sheet for creating a group chat.
/// Step 1: Enter group name
/// Step 2: Search & select contacts
/// Step 3: Create group + navigate to chat
class CreateGroupChatSheet extends ConsumerStatefulWidget {
  const CreateGroupChatSheet({super.key});

  @override
  ConsumerState<CreateGroupChatSheet> createState() =>
      _CreateGroupChatSheetState();
}

class _CreateGroupChatSheetState extends ConsumerState<CreateGroupChatSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _searchController = TextEditingController();
  final List<Map<String, dynamic>> _selectedUsers = [];
  List<Map<String, dynamic>> _followingUsers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _isCreating = false;
  bool _isSearching = false;
  int _step = 0; // 0 = name, 1 = members
  Uint8List? _avatarBytes;
  String? _avatarName;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _loadFollowing();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _avatarBytes = bytes;
      _avatarName = picked.name;
    });
  }

  Future<void> _loadFollowing() async {
    setState(() => _isLoading = true);
    try {
      final groupRepo = ref.read(groupRepositoryProvider);
      final users = await groupRepo.getFollowingProfiles();
      if (mounted) {
        setState(() {
          _followingUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[GroupChat] Load following error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final results = await profileRepo.searchUsers(query.trim(), limit: 15);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('[GroupChat] Search error: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _toggleUser(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    setState(() {
      final idx = _selectedUsers.indexWhere((u) => u['id'] == userId);
      if (idx >= 0) {
        _selectedUsers.removeAt(idx);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  bool _isSelected(String userId) {
    return _selectedUsers.any((u) => u['id'] == userId);
  }

  Future<void> _createGroupChat() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedUsers.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final groupRepo = ref.read(groupRepositoryProvider);

      // 1. Create group with type 'chat'
      final desc = _descController.text.trim();
      debugPrint('[GroupChat] Creating group: name=$name, desc=$desc, members=${_selectedUsers.length}');
      final groupId = await groupRepo.createGroup(
        name: name,
        description: desc.isNotEmpty ? desc : null,
        groupType: 'chat',
        isPublic: false,
      );
      debugPrint('[GroupChat] Group created: id=$groupId');

      // 1b. Upload avatar if selected
      if (_avatarBytes != null && _avatarName != null) {
        final ext = _avatarName!.split('.').last.toLowerCase();
        final path = 'groups/$groupId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final sb = Supabase.instance.client;
        await sb.storage.from('posts').uploadBinary(
          path,
          _avatarBytes!,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
        final avatarUrl = sb.storage.from('posts').getPublicUrl(path);
        await groupRepo.updateGroup(groupId, avatarUrl: avatarUrl);
        debugPrint('[GroupChat] Avatar uploaded: $avatarUrl');
      }

      // 2. Add selected members
      final userIds = _selectedUsers.map((u) => u['id'] as String).toList();
      await groupRepo.addMembersToGroup(groupId, userIds);
      debugPrint('[GroupChat] Members added: ${userIds.length} users');

      // 3. Get conversation ID
      final convId = await groupRepo.getGroupConversationId(groupId);
      debugPrint('[GroupChat] Conversation ID: $convId');

      // 4. Send notification to each invited member
      final notifRepo = ref.read(notificationRepositoryProvider);
      for (final userId in userIds) {
        notifRepo.createNotification(
          targetUserId: userId,
          type: 'system',
          title: 'Du wurdest zur Gruppe "$name" eingeladen',
          body: 'Tippe hier um die Gruppe zu öffnen',
          data: {
            'group_id': groupId,
            if (convId != null) 'conversation_id': convId,
          },
          community: 'bikergram',
        );
      }
      debugPrint('[GroupChat] Notifications sent');

      // 5. Send welcome message to trigger realtime update for all members
      if (convId != null) {
        final msgRepo = ref.read(messageRepositoryProvider);
        final memberNames = _selectedUsers
            .map((u) => u['display_name'] as String? ?? u['username'] as String? ?? '?')
            .join(', ');
        await msgRepo.sendMessage(convId, '👋 Gruppe "$name" erstellt mit $memberNames');
        debugPrint('[GroupChat] Welcome message sent to conv $convId');
      }

      debugPrint('[GroupChat] Done! Navigating to /messages/$convId');
      if (mounted) {
        Navigator.of(context).pop(); // Close sheet
        if (convId != null) {
          context.push('/messages/$convId');
        }
      }
    } catch (e) {
      debugPrint('[GroupChat] Create error: $e');
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                if (_step == 1)
                  IconButton(
                    onPressed: () => setState(() => _step = 0),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Text(
                    _step == 0 ? 'Neue Gruppe' : 'Mitglieder hinzufügen',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (_step == 1 && _selectedUsers.isNotEmpty)
                  TextButton(
                    onPressed: _isCreating ? null : _createGroupChat,
                    child: _isCreating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Erstellen',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Content
          Expanded(
            child: _step == 0 ? _buildNameStep(isDark) : _buildMembersStep(isDark),
          ),
        ],
      ),
    );
  }

  // ── Step 0: Group Name ──────────────────────────────────────────────

  Widget _buildNameStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Group avatar (tappable) + name field
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        image: _avatarBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_avatarBytes!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _avatarBytes == null
                          ? Icon(
                              Icons.group_rounded,
                              color: isDark ? Colors.white38 : Colors.grey.shade400,
                              size: 28,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF3A3A5C) : Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Gruppenname eingeben',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) {
                    if (_nameController.text.trim().isNotEmpty) {
                      setState(() => _step = 1);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Description field
          TextField(
            controller: _descController,
            maxLines: 3,
            maxLength: 200,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Beschreibung (optional)',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey.shade400,
                fontSize: 14,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
              ),
              counterStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.grey.shade400,
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nameController.text.trim().isNotEmpty
                  ? () => setState(() => _step = 1)
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Weiter',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Select Members ──────────────────────────────────────────

  Widget _buildMembersStep(bool isDark) {
    final displayList = _searchController.text.trim().isNotEmpty
        ? _searchResults
        : _followingUsers;

    return Column(
      children: [
        // Selected users chips
        if (_selectedUsers.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _selectedUsers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final user = _selectedUsers[index];
                return Chip(
                  avatar: CircleAvatar(
                    radius: 14,
                    backgroundImage: user['avatar_url'] != null
                        ? NetworkImage(user['avatar_url'] as String)
                        : null,
                    child: user['avatar_url'] == null
                        ? Text(
                            (user['display_name'] ?? user['username'] ?? '?')
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                  ),
                  label: Text(
                    user['display_name'] as String? ??
                        user['username'] as String? ??
                        '?',
                    style: const TextStyle(fontSize: 13),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _toggleUser(user),
                );
              },
            ),
          ),

        if (_selectedUsers.isNotEmpty) const SizedBox(height: 8),

        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Kontakte suchen...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _searchUsers,
          ),
        ),

        const SizedBox(height: 8),

        // User list
        Expanded(
          child: _isLoading || _isSearching
              ? const Center(child: CircularProgressIndicator())
              : displayList.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().isNotEmpty
                            ? 'Keine Ergebnisse'
                            : 'Du folgst noch niemandem',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final user = displayList[index];
                        final userId = user['id'] as String;
                        final name = user['display_name'] as String? ??
                            user['username'] as String? ??
                            '?';
                        final avatar = user['avatar_url'] as String?;
                        final selected = _isSelected(userId);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                avatar != null ? NetworkImage(avatar) : null,
                            child: avatar == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  )
                                : null,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: user['username'] != null
                              ? Text(
                                  '@${user['username']}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                )
                              : null,
                          trailing: selected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: Colors.green)
                              : Icon(Icons.circle_outlined,
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey.shade300),
                          onTap: () => _toggleUser(user),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
