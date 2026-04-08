import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/group.dart';
import '../../providers/groups/groups_notifier.dart';
import '../../providers/core/providers.dart';

/// Bottom sheet for creating a new group.
class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _groupType = GroupType.chat;
  bool _isPublic = true;
  String _rideColor = '#4CAF50';
  bool _busy = false;
  String? _error;

  // Friend picker state
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _selectedFriendIds = {};
  bool _loadingFriends = true;

  static const _colorOptions = [
    ('#4CAF50', 'Grün', Colors.green),
    ('#2196F3', 'Blau', Colors.blue),
    ('#FF9800', 'Orange', Colors.orange),
    ('#E91E63', 'Pink', Colors.pink),
    ('#9C27B0', 'Lila', Colors.purple),
    ('#F44336', 'Rot', Colors.red),
    ('#00BCD4', 'Cyan', Colors.cyan),
    ('#FFEB3B', 'Gelb', Colors.yellow),
  ];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final repo = ref.read(groupRepositoryProvider);
      final friends = await repo.getFollowingProfiles();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _loadingFriends = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFriends = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mq = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mq.size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      'Neue Gruppe',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Group type selector
                Text(
                  'Typ',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: GroupType.all.map((type) {
                    final selected = _groupType == type;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          selected: selected,
                          label: Text(
                            GroupType.label(type),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          avatar: Text(
                            GroupType.icon(type),
                            style: const TextStyle(fontSize: 14),
                          ),
                          onSelected: (_) =>
                              setState(() => _groupType = type),
                          selectedColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : null,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide.none,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 12),

                // Name
                TextField(
                  controller: _nameCtrl,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Gruppenname *',
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                SizedBox(height: 10),

                // Description
                TextField(
                  controller: _descCtrl,
                  enabled: !_busy,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Beschreibung (optional)',
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                SizedBox(height: 10),

                // Public/Private toggle
                SwitchListTile(
                  value: _isPublic,
                  onChanged:
                      _busy ? null : (v) => setState(() => _isPublic = v),
                  title: Text(
                    _isPublic ? 'Öffentlich' : 'Privat',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _isPublic
                        ? 'Jeder kann beitreten'
                        : 'Nur mit Einladung',
                    style: theme.textTheme.bodySmall,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),

                // Color picker (only for ride groups)
                if (_groupType == GroupType.ride) ...[
                  SizedBox(height: 4),
                  Text(
                    'Marker-Farbe auf der Karte',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colorOptions.map((opt) {
                      final (hex, _, color) = opt;
                      final selected = _rideColor == hex;
                      return GestureDetector(
                        onTap: () => setState(() => _rideColor = hex),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 8,
                                    )
                                  ]
                                : [],
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  size: 18, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 8),
                ],

                SizedBox(height: 8),

                // Friend picker
                Text(
                  'Freunde einladen',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                _buildFriendPicker(theme, isDark),

                // Error
                if (_error != null) ...[
                  SizedBox(height: 4),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.redAccent.withOpacity(0.95),
                    ),
                  ),
                ],

                SizedBox(height: 16),

                // Create button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _create,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _busy
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Text(
                            'Gruppe erstellen',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendPicker(ThemeData theme, bool isDark) {
    if (_loadingFriends) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_friends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Du folgst noch niemandem.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: 160),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final id = friend['id'] as String;
          final name = friend['display_name'] as String? ??
              friend['username'] as String? ??
              'User';
          final avatar = friend['avatar_url'] as String?;
          final selected = _selectedFriendIds.contains(id);

          return InkWell(
            onTap: _busy
                ? null
                : () {
                    setState(() {
                      if (selected) {
                        _selectedFriendIds.remove(id);
                      } else {
                        _selectedFriendIds.add(id);
                      }
                    });
                  },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // Checkbox
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: selected,
                      onChanged: _busy
                          ? null
                          : (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedFriendIds.add(id);
                                } else {
                                  _selectedFriendIds.remove(id);
                                }
                              });
                            },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundImage:
                        avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  // Name
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Bitte einen Gruppennamen eingeben.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final groupId =
          await ref.read(groupsNotifierProvider.notifier).createGroup(
                name: name,
                description: _descCtrl.text.trim().isEmpty
                    ? null
                    : _descCtrl.text.trim(),
                groupType: _groupType,
                isPublic: _isPublic,
                rideColor: _rideColor,
              );

      // Add selected friends + send notifications
      if (_selectedFriendIds.isNotEmpty) {
        try {
          final repo = ref.read(groupRepositoryProvider);
          await repo.addMembersToGroup(
              groupId, _selectedFriendIds.toList());
          // Notify each invited user
          final notifRepo = ref.read(notificationRepositoryProvider);
          for (final userId in _selectedFriendIds) {
            notifRepo.createNotification(
              targetUserId: userId,
              type: 'system',
              title: 'Du wurdest zur Gruppe "$name" eingeladen',
              body: 'Tippe hier um die Gruppe zu öffnen',
              data: {'group_id': groupId},
              community: ref.read(communityProvider)?.name ?? 'bikergram',
            );
          }
        } catch (e) {
          debugPrint('[CreateGroup] Add members error: $e');
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // close create sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$name" erstellt!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }
}
