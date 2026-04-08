import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../domain/models/direct_message.dart';
import '../../providers/core/providers.dart';
import '../../providers/messages/messages_notifier.dart';
import '../../providers/messages/unread_messages_notifier.dart';
import '../../theme/app_theme.dart';
import '../widgets/immersive_scroll_wrapper.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key, this.initialFilter});

  final String? initialFilter;

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  late bool _archivedOnly = widget.initialFilter == 'archived';
  final Set<int> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  Future<void> _markAllAsRead() async {
    HapticFeedback.lightImpact();
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client
          .from('messages')
          .update({'is_read': true})
          .neq('user_id', userId)
          .eq('is_read', false);
      ref.read(messagesNotifierProvider.notifier).refresh();
      ref.read(unreadMessagesProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alle als gelesen markiert')),
        );
      }
    } catch (_) {}
  }

  void _deleteSelected(Color accentColor) {
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text('$count Chats löschen?', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('$count ausgewählte Chats werden unwiderruflich gelöscht.',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Abbrechen', style: GoogleFonts.inter(color: accentColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final ids = _selectedIds.toList();
              _clearSelection();
              ref.read(messagesNotifierProvider.notifier).deleteConversations(ids);
            },
            child: Text('Löschen', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _archiveSelected() {
    final ids = _selectedIds.toList();
    _clearSelection();
    ref.read(messagesNotifierProvider.notifier).archiveConversations(ids);
  }

  void _confirmPermanentDelete(Conversation conv, Color accentColor) {
    final name = conv.isGroupChat
        ? (conv.groupName ?? 'Gruppe')
        : (conv.otherUsername ?? 'Chat');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text('Endgültig löschen?', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('"$name" wird endgültig gelöscht und kann nicht wiederhergestellt werden.',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Abbrechen', style: GoogleFonts.inter(color: accentColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(messagesNotifierProvider.notifier)
                  .permanentlyDeleteConversation(conv.id);
            },
            child: Text('Endgültig löschen', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmEmptyTrash(List<Conversation> trashed, Color accentColor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text('Papierkorb leeren?', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('${trashed.length} Chats werden endgültig gelöscht.',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Abbrechen', style: GoogleFonts.inter(color: accentColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(messagesNotifierProvider.notifier)
                  .permanentlyDeleteConversations(trashed.map((c) => c.id).toList());
            },
            child: Text('Alle löschen', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteConversation(Conversation conv, Color accentColor) {
    final name = conv.isGroupChat
        ? (conv.groupName ?? 'Gruppe')
        : (conv.otherUsername ?? 'Chat');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text('Chat löschen?', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('Der gesamte Chat mit "$name" wird unwiderruflich gelöscht.',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Abbrechen', style: GoogleFonts.inter(color: accentColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(messagesNotifierProvider.notifier)
                  .deleteConversation(conv.id);
            },
            child: Text('Löschen', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final messagesState = ref.watch(messagesNotifierProvider);

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
      appBar: AppBar(
        backgroundColor: _isSelecting
            ? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : accentColor)
            : (community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5))),
        surfaceTintColor: Colors.transparent,
        leading: _isSelecting
            ? IconButton(
                onPressed: _clearSelection,
                icon: Icon(Icons.close_rounded, color: _isSelecting && brightness == Brightness.light ? Colors.white : (community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)))),
              )
            : IconButton(
                onPressed: () => context.pop(),
                icon: Icon(Icons.arrow_back_rounded, color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
              ),
        title: _isSelecting
            ? Text(
                '${_selectedIds.length} ausgewählt',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _isSelecting && brightness == Brightness.light ? Colors.white : (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                ),
              )
            : Text(
                'Nachrichten',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                  letterSpacing: -0.3,
                ),
              ),
        actions: _isSelecting
            ? [
                IconButton(
                  onPressed: _archiveSelected,
                  icon: Icon(Icons.archive_rounded, color: _isSelecting && brightness == Brightness.light ? Colors.white : Colors.orange),
                  tooltip: 'Archivieren',
                ),
                IconButton(
                  onPressed: () => _deleteSelected(accentColor),
                  icon: Icon(Icons.delete_rounded, color: _isSelecting && brightness == Brightness.light ? Colors.white : Colors.red),
                  tooltip: 'Löschen',
                ),
              ]
            : [
                IconButton(
                  onPressed: _markAllAsRead,
                  icon: Icon(Icons.done_all_rounded, color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                  tooltip: 'Alle als gelesen',
                ),
              ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: GoogleFonts.inter(fontSize: 15, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'Suche...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF9E9E9E),
                ),
                prefixIcon: Icon(Icons.search_rounded,
                    color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF9E9E9E), size: 22),
                filled: true,
                fillColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(messagesState, accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(MessagesState state, Color accentColor) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (state.error != null) {
      final brightness = Theme.of(context).brightness;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.white.withValues(alpha: 0.3), size: 48),
            const SizedBox(height: 16),
            Text(
              'Fehler beim Laden',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.read(messagesNotifierProvider.notifier).refresh(),
              child: Text('Erneut versuchen',
                  style: GoogleFonts.inter(
                      color: accentColor, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    // Filter by search (search in username AND group name)
    final allFiltered = state.conversations.where((c) {
      if (_searchQuery.isEmpty) return true;
      final name = (c.otherUsername ?? '').toLowerCase();
      final groupName = (c.groupName ?? '').toLowerCase();
      return name.contains(_searchQuery) || groupName.contains(_searchQuery);
    }).toList();

    final activeConversations = allFiltered.where((c) => c.archivedAt == null && c.deletedAt == null).toList();
    final archivedConversations = allFiltered.where((c) => c.archivedAt != null && c.deletedAt == null).toList();
    final trashedConversations = allFiltered.where((c) => c.deletedAt != null).toList();

    // Archived-only mode: show only archived conversations
    if (_archivedOnly) {
      if (archivedConversations.isEmpty) return _buildEmptyState();
      return _buildArchivedOnlyView(archivedConversations, accentColor);
    }

    if (activeConversations.isEmpty && archivedConversations.isEmpty && trashedConversations.isEmpty) {
      return _buildEmptyState();
    }

    final brightness = Theme.of(context).brightness;

    return ImmersiveScrollWrapper(child: RefreshIndicator(
      color: accentColor,
      onRefresh: () =>
          ref.read(messagesNotifierProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Active conversations
          for (int i = 0; i < activeConversations.length; i++) ...[
            Dismissible(
              key: ValueKey('conv_${activeConversations[i].id}'),
              direction: _isSelecting ? DismissDirection.none : DismissDirection.horizontal,
              // Swipe left → Archive (orange)
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.red, size: 24),
              ),
              // Swipe right → Delete (red)
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.archive_rounded, color: Colors.orange, size: 24),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  // Swipe right → confirm delete
                  _confirmDeleteConversation(activeConversations[i], accentColor);
                  return false; // dialog handles it
                }
                return true; // archive directly
              },
              onDismissed: (_) {
                ref.read(messagesNotifierProvider.notifier)
                    .archiveConversation(activeConversations[i].id);
              },
              child: _SelectableConversationTile(
                conversation: activeConversations[i],
                accentColor: accentColor,
                isSelected: _selectedIds.contains(activeConversations[i].id),
                isSelecting: _isSelecting,
                onTap: () {
                  if (_isSelecting) {
                    _toggleSelection(activeConversations[i].id);
                  } else {
                    context.push('/messages/${activeConversations[i].id}');
                  }
                },
                onLongPress: () => _toggleSelection(activeConversations[i].id),
                onArchive: () {
                  ref.read(messagesNotifierProvider.notifier)
                      .archiveConversation(activeConversations[i].id);
                },
                onDelete: () => _confirmDeleteConversation(
                  activeConversations[i], accentColor),
                onMarkRead: () {
                  ref.read(messagesNotifierProvider.notifier)
                      .markConversationAsRead(activeConversations[i].id);
                },
                onMarkUnread: () {
                  ref.read(messagesNotifierProvider.notifier)
                      .markConversationAsUnread(activeConversations[i].id);
                },
              ),
            ),
            if (i < activeConversations.length - 1)
              Divider(height: 1, color: brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE8EAED)),
          ],

          // Archived section
          if (archivedConversations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ArchivedSection(
              conversations: archivedConversations,
              accentColor: accentColor,
              brightness: brightness,
              onTap: (conv) => context.push('/messages/${conv.id}'),
              onUnarchive: (conv) {
                ref.read(messagesNotifierProvider.notifier)
                    .unarchiveConversation(conv.id);
              },
            ),
          ],

          // Trash / Papierkorb section
          if (trashedConversations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TrashSection(
              conversations: trashedConversations,
              accentColor: accentColor,
              brightness: brightness,
              onRestore: (conv) {
                ref.read(messagesNotifierProvider.notifier)
                    .restoreConversation(conv.id);
              },
              onPermanentDelete: (conv) {
                _confirmPermanentDelete(conv, accentColor);
              },
              onEmptyTrash: () {
                _confirmEmptyTrash(trashedConversations, accentColor);
              },
            ),
          ],
        ],
      ),
    ));
  }

  Widget _buildArchivedOnlyView(List<dynamic> archived, Color accentColor) {
    final brightness = Theme.of(context).brightness;
    return ImmersiveScrollWrapper(child: RefreshIndicator(
      color: accentColor,
      onRefresh: () => ref.read(messagesNotifierProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 56),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.archive_rounded, size: 18, color: Colors.orange.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Text(
                  'Archivierte Chats (${archived.length})',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6C757D)),
                ),
              ],
            ),
          ),
          for (final conv in archived) ...[
            Dismissible(
              key: ValueKey('archived_${conv.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.green.withValues(alpha: 0.15),
                child: const Icon(Icons.unarchive_rounded, color: Colors.green),
              ),
              onDismissed: (_) {
                ref.read(messagesNotifierProvider.notifier).unarchiveConversation(conv.id);
              },
              child: _ConversationTile(
                conversation: conv,
                accentColor: accentColor,
                onTap: () => context.push('/messages/${conv.id}'),
              ),
            ),
            Divider(height: 1, color: brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE8EAED)),
          ],
          const SizedBox(height: 100),
        ],
      ),
    ));
  }

  Widget _buildEmptyState() {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Nachrichten',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Starte eine Unterhaltung!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps _ConversationTile with selection state (checkbox overlay + highlight).
class _SelectableConversationTile extends StatelessWidget {
  const _SelectableConversationTile({
    required this.conversation,
    required this.accentColor,
    required this.isSelected,
    required this.isSelecting,
    required this.onTap,
    required this.onLongPress,
    this.onArchive,
    this.onDelete,
    this.onMarkRead,
    this.onMarkUnread,
  });

  final Conversation conversation;
  final Color accentColor;
  final bool isSelected;
  final bool isSelecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkRead;
  final VoidCallback? onMarkUnread;

  @override
  Widget build(BuildContext context) {
    return _ConversationTile(
      conversation: conversation,
      accentColor: accentColor,
      isSelected: isSelected,
      isSelecting: isSelecting,
      onTap: onTap,
      onLongPress: onLongPress,
      onArchive: isSelecting ? null : onArchive,
      onDelete: isSelecting ? null : onDelete,
      onMarkRead: isSelecting ? null : onMarkRead,
      onMarkUnread: isSelecting ? null : onMarkUnread,
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.accentColor,
    required this.onTap,
    this.onLongPress,
    this.onArchive,
    this.onUnarchive,
    this.onDelete,
    this.onMarkRead,
    this.onMarkUnread,
    this.isSelected = false,
    this.isSelecting = false,
  });

  final Conversation conversation;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkRead;
  final VoidCallback? onMarkUnread;
  final bool isSelected;
  final bool isSelecting;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final hasUnread = conversation.unreadCount > 0;
    final displayName = conversation.isGroupChat
        ? (conversation.groupName ?? 'Gruppe')
        : (conversation.otherUsername ?? 'Unbekannt');
    final avatarUrl = conversation.isGroupChat
        ? conversation.groupAvatarUrl
        : conversation.otherAvatarUrl;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress ?? ((onArchive != null || onUnarchive != null || onDelete != null)
          ? () => _showConversationMenu(context, brightness)
          : null),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: isSelected
            ? BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Row(
          children: [
            // Selection checkbox
            if (isSelecting) ...[
              const SizedBox(width: 4),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? accentColor : (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF9E9E9E)),
                size: 22,
              ),
              const SizedBox(width: 10),
            ],
            // Avatar — group icon or user avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (avatarUrl == null || avatarUrl.isEmpty)
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: conversation.isGroupChat
                            ? [Colors.teal, Colors.teal.withValues(alpha: 0.6)]
                            : [accentColor, accentColor.withValues(alpha: 0.6)],
                      )
                    : null,
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => conversation.isGroupChat
                            ? _buildGroupIcon()
                            : _buildInitial(displayName, accentColor),
                      )
                    : conversation.isGroupChat
                        ? _buildGroupIcon()
                        : _buildInitial(displayName, accentColor),
              ),
            ),

            const SizedBox(width: 14),

            // Name & last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (conversation.isGroupChat) ...[
                        Icon(Icons.groups_rounded,
                            size: 14,
                            color: brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.5)
                                : const Color(0xFF6C757D)),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          displayName,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPreview(conversation.lastMessageBody),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          hasUnread ? FontWeight.w500 : FontWeight.w400,
                      color: hasUnread
                          ? (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1A1A1A))
                          : (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF6C757D)),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Time & unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (conversation.lastMessageAt != null)
                  Text(
                    _formatTime(conversation.lastMessageAt!),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: hasUnread
                          ? accentColor
                          : (brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.3)
                              : const Color(0xFF9E9E9E)),
                    ),
                  ),
                if (hasUnread) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // ⋮ Menu (hide in selection mode)
            if (!isSelecting && (onArchive != null || onUnarchive != null || onDelete != null))
              GestureDetector(
                onTap: () => _showConversationMenu(context, brightness),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.3)
                        : const Color(0xFF9E9E9E),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showConversationMenu(BuildContext context, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final hasUnread = conversation.unreadCount > 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Als gelesen / ungelesen markieren
              if (hasUnread && onMarkRead != null)
                ListTile(
                  leading: Icon(Icons.done_all_rounded, color: accentColor),
                  title: Text('Als gelesen markieren', style: GoogleFonts.inter(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onMarkRead?.call();
                  },
                ),
              if (!hasUnread && onMarkUnread != null)
                ListTile(
                  leading: Icon(Icons.mark_email_unread_rounded, color: accentColor),
                  title: Text('Als ungelesen markieren', style: GoogleFonts.inter(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onMarkUnread?.call();
                  },
                ),
              // Archivieren / Entarchivieren
              if (onArchive != null)
                ListTile(
                  leading: const Icon(Icons.archive_rounded, color: Colors.orange),
                  title: Text('Archivieren', style: GoogleFonts.inter(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onArchive?.call();
                  },
                ),
              if (onUnarchive != null)
                ListTile(
                  leading: Icon(Icons.unarchive_rounded, color: accentColor),
                  title: Text('Entarchivieren', style: GoogleFonts.inter(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onUnarchive?.call();
                  },
                ),
              // Löschen
              if (onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: Colors.red),
                  title: Text('Chat löschen', style: GoogleFonts.inter(fontSize: 15, color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete?.call();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.teal, Colors.teal.withValues(alpha: 0.6)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.groups_rounded, size: 24, color: Colors.white),
      ),
    );
  }

  Widget _buildInitial(String name, Color accent) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.6)],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _formatPreview(String? body) {
    if (body == null || body.isEmpty) return 'Neue Unterhaltung';
    if (!body.startsWith('{')) return body;
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';
      final vehicleName = data['vehicle_name'] as String? ?? '';
      final amount = (data['price'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0;
      return switch (type) {
        'like' => '\u2764\ufe0f $vehicleName gefällt mir',
        'offer' => '\ud83d\udcb0 Angebot: ${amount.toStringAsFixed(0)} \u20ac',
        'counter' => '\ud83d\udd04 Gegenangebot: ${amount.toStringAsFixed(0)} \u20ac',
        'accepted' => '\u2705 Angebot angenommen!',
        'declined' => '\u274c Angebot abgelehnt',
        _ => '\ud83d\udcb0 Angebot',
      };
    } catch (_) {
      return body;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Gestern';
    } else if (diff.inDays < 7) {
      const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
      return days[time.weekday - 1];
    } else {
      return '${time.day}.${time.month}.';
    }
  }
}

/// Expandable archived conversations section.
class _ArchivedSection extends StatefulWidget {
  const _ArchivedSection({
    required this.conversations,
    required this.accentColor,
    required this.brightness,
    required this.onTap,
    required this.onUnarchive,
  });

  final List<Conversation> conversations;
  final Color accentColor;
  final Brightness brightness;
  final void Function(Conversation) onTap;
  final void Function(Conversation) onUnarchive;

  @override
  State<_ArchivedSection> createState() => _ArchivedSectionState();
}

class _ArchivedSectionState extends State<_ArchivedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    return Column(
      children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.archive_rounded,
                    size: 18, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 10),
                Text(
                  'Archivierte Chats (${widget.conversations.length})',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D),
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
        // Expandable list
        if (_expanded) ...[
          const SizedBox(height: 4),
          for (final conv in widget.conversations)
            Dismissible(
              key: ValueKey('archived_${conv.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.unarchive_rounded, color: widget.accentColor, size: 24),
              ),
              onDismissed: (_) => widget.onUnarchive(conv),
              child: _ConversationTile(
                conversation: conv,
                accentColor: widget.accentColor,
                onTap: () => widget.onTap(conv),
                onUnarchive: () => widget.onUnarchive(conv),
              ),
            ),
        ],
      ],
    );
  }
}

/// Expandable trash / Papierkorb section.
class _TrashSection extends StatefulWidget {
  const _TrashSection({
    required this.conversations,
    required this.accentColor,
    required this.brightness,
    required this.onRestore,
    required this.onPermanentDelete,
    required this.onEmptyTrash,
  });

  final List<Conversation> conversations;
  final Color accentColor;
  final Brightness brightness;
  final void Function(Conversation) onRestore;
  final void Function(Conversation) onPermanentDelete;
  final VoidCallback onEmptyTrash;

  @override
  State<_TrashSection> createState() => _TrashSectionState();
}

class _TrashSectionState extends State<_TrashSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    return Column(
      children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.red.withValues(alpha: 0.06) : Colors.red.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded,
                    size: 18, color: Colors.red.withValues(alpha: 0.5)),
                const SizedBox(width: 10),
                Text(
                  'Papierkorb (${widget.conversations.length})',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.red.withValues(alpha: 0.6) : Colors.red.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                if (_expanded)
                  GestureDetector(
                    onTap: widget.onEmptyTrash,
                    child: Text(
                      'Leeren',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20,
                  color: Colors.red.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
        // Expandable list
        if (_expanded) ...[
          const SizedBox(height: 4),
          for (final conv in widget.conversations)
            Dismissible(
              key: ValueKey('trash_${conv.id}'),
              direction: DismissDirection.horizontal,
              // Swipe right → restore
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.restore_rounded, color: widget.accentColor, size: 24),
              ),
              // Swipe left → permanent delete
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.endToStart) {
                  widget.onPermanentDelete(conv);
                  return false;
                }
                return true; // restore directly
              },
              onDismissed: (_) => widget.onRestore(conv),
              child: _ConversationTile(
                conversation: conv,
                accentColor: widget.accentColor,
                onTap: () {},
              ),
            ),
        ],
      ],
    );
  }
}
