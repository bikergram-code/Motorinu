import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../domain/models/direct_message.dart';
import '../../providers/core/providers.dart';
import '../../providers/messages/messages_notifier.dart';
import '../../theme/app_theme.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
        ),
        title: Text(
          'Nachrichten',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Suche...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.3), size: 22),
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
    final conversations = state.conversations.where((c) {
      if (_searchQuery.isEmpty) return true;
      final name = (c.otherUsername ?? '').toLowerCase();
      final groupName = (c.groupName ?? '').toLowerCase();
      return name.contains(_searchQuery) || groupName.contains(_searchQuery);
    }).toList();

    if (conversations.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: accentColor,
      onRefresh: () =>
          ref.read(messagesNotifierProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: conversations.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
        itemBuilder: (context, index) =>
            _ConversationTile(
              conversation: conversations[index],
              accentColor: accentColor,
              onTap: () => context.push('/messages/${conversations[index].id}'),
            ),
      ),
    );
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
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.15),
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.accentColor,
    required this.onTap,
  });

  final Conversation conversation;
  final Color accentColor;
  final VoidCallback onTap;

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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
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
                    conversation.lastMessageBody ?? 'Neue Unterhaltung',
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
                          : Colors.white.withValues(alpha: 0.3),
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
          ],
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
