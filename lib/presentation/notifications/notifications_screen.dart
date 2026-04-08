import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/community.dart';
import '../../providers/core/providers.dart';
import '../../providers/notifications/notification_notifier.dart';
import '../../theme/app_theme.dart';
import '../widgets/immersive_scroll_wrapper.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final notifState = ref.watch(notificationNotifierProvider);
    final hasUnread = notifState.notifications.any((n) => !n.isRead);

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
          'Benachrichtigungen',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref
                    .read(notificationNotifierProvider.notifier)
                    .markAllAsRead();
              },
              child: Text(
                'Alle lesen',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(context, ref, notifState, accentColor),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationsState state,
    Color accentColor,
  ) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (state.error != null && state.notifications.isEmpty) {
      final brightness = Theme.of(context).brightness;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF9E9E9E), size: 48),
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
              onPressed: () => ref
                  .read(notificationNotifierProvider.notifier)
                  .refresh(),
              child: Text(
                'Erneut versuchen',
                style: GoogleFonts.inter(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return _buildEmptyState();
    }

    return ImmersiveScrollWrapper(child: RefreshIndicator(
      color: accentColor,
      onRefresh: () =>
          ref.read(notificationNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: state.notifications.length,
        itemBuilder: (context, index) {
          final notif = state.notifications[index];
          return _NotificationTile(
            notification: notif,
            accentColor: accentColor,
            onTap: () {
              // Mark as read on tap
              if (!notif.isRead) {
                ref
                    .read(notificationNotifierProvider.notifier)
                    .markAsRead(notif.id);
              }
              // Navigate based on type
              _handleNotificationTap(context, notif);
            },
          );
        },
      ),
    ));
  }

  Widget _buildEmptyState() {
    return Builder(builder: (context) {
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
              Icons.notifications_none_rounded,
              size: 36,
              color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Keine Benachrichtigungen',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hier siehst du Likes, Kommentare\nund neue Follower',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
    });
  }

  void _handleNotificationTap(BuildContext context, AppNotification notif) {
    final data = notif.data;

    switch (notif.type) {
      case 'like':
      case 'comment':
      case 'mention':
        // ── Dating notifications (like with type=dating_like or match) ──
        final subType = data['type'] as String?;
        if (subType == 'match') {
          // ⚠️ Nicht direkt zu /messages navigieren — conversation_id kann falsch sein!
          // Stattdessen zum Profil mit showDating=true → dort wird korrekte Konversation aufgelöst.
          final matchActorId = data['actor_id'] as String?;
          if (matchActorId != null && matchActorId.isNotEmpty) {
            context.push('/profile/$matchActorId?showDating=true');
            return;
          }
          context.go('/feed');
          return;
        }
        if (subType == 'dating_like') {
          // Navigate to the liker's profile with dating card auto-open
          final likerId = data['actor_id'] as String?;
          if (likerId != null && likerId.isNotEmpty) {
            context.push('/profile/$likerId?showDating=true');
            return;
          }
          context.go('/feed');
          return;
        }

        // Navigate to the post (where like/comment happened)
        final postId = data['post_id'];
        if (postId != null) {
          final id = postId is int ? postId : int.tryParse('$postId');
          if (id != null) {
            context.push('/post/$id');
            return;
          }
        }
        // Fallback: navigate to actor's profile
        final actorId = data['actor_id'] as String?;
        if (actorId != null && actorId.isNotEmpty) {
          context.push('/profile/$actorId');
        }
        break;
      case 'follow':
        final followerId = data['follower_id'] as String?;
        if (followerId != null && followerId.isNotEmpty) {
          context.push('/profile/$followerId');
        }
        break;
      case 'vehicle_offer':
        final convId = data['conversation_id'];
        if (convId != null) {
          final id = convId is int ? convId : int.tryParse('$convId');
          if (id != null) {
            context.push('/messages/$id');
            return;
          }
        }
        // Fallback: navigate to sender profile
        final senderId = data['sender_id'] as String?;
        if (senderId != null && senderId.isNotEmpty) {
          context.push('/profile/$senderId');
        }
        break;
      case 'xp':
        break;
      case 'system':
        final groupId = data['group_id'];
        if (groupId != null) {
          final id = groupId is int ? groupId : int.tryParse('$groupId');
          if (id != null) {
            context.push('/group/$id');
            return;
          }
        }
        break;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.accentColor,
    required this.onTap,
  });

  final AppNotification notification;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final community =
        ProviderScope.containerOf(context).read(communityProvider);
    final cardBg = community?.cardFor(brightness) ??
        (brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : Colors.white);

    final offerType = notification.data['offer_type']?.toString() ?? '';

    final (IconData icon, Color color) = switch (notification.type) {
      'like' => (Icons.favorite_rounded, Colors.red),
      'comment' => (Icons.chat_bubble_rounded, accentColor),
      'follow' => (Icons.person_add_rounded, Colors.green),
      'mention' => (Icons.alternate_email_rounded, Colors.blue),
      'xp' => (Icons.bolt_rounded, Colors.amber),
      'system' => (Icons.info_outline_rounded, Colors.blueGrey),
      'vehicle_offer' => switch (offerType) {
        'like' => (Icons.favorite_rounded, Colors.red),
        'offer' => (Icons.local_offer_rounded, Colors.orange),
        'counter' => (Icons.swap_horiz_rounded, Colors.blue),
        'accepted' => (Icons.check_circle_rounded, Colors.green),
        'declined' => (Icons.cancel_rounded, Colors.red.shade300),
        _ => (Icons.local_offer_rounded, Colors.orange),
      },
      _ => (Icons.notifications_rounded, Colors.grey),
    };

    final bool isUnread = !notification.isRead;
    final hasBody = notification.body != null && notification.body!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.88,
          ),
          child: Material(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            elevation: brightness == Brightness.dark ? 0 : 1,
            shadowColor: Colors.black.withValues(alpha: 0.06),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnread
                        ? accentColor.withValues(alpha: 0.25)
                        : (brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06)),
                    width: isUnread ? 1.2 : 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Icon ──
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.18),
                            color.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),

                    const SizedBox(width: 10),

                    // ── Content ──
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            notification.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w600,
                              color: brightness == Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                              height: 1.3,
                            ),
                          ),

                          // Body (if present) — compact bubble
                          if (hasBody) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                              ),
                              child: Text(
                                notification.body!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: brightness == Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.55)
                                      : const Color(0xFF6C757D),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],

                          // ── "Zur Nachricht" hint for vehicle_offer ──
                          if (notification.type == 'vehicle_offer' &&
                              notification.data['conversation_id'] != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    size: 12, color: accentColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Zur Nachricht',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 5),

                          // Time + unread badge
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 11,
                                color: brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : const Color(0xFFADB5BD),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatTime(notification.createdAt),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: brightness == Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : const Color(0xFFADB5BD),
                                ),
                              ),
                              if (isUnread) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color:
                                        accentColor.withValues(alpha: 0.15),
                                  ),
                                  child: Text(
                                    'Neu',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: accentColor,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';

    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
    if (diff.inHours < 24) {
      return diff.inHours == 1 ? 'vor 1 Std' : 'vor ${diff.inHours} Std';
    }
    if (diff.inDays == 1) return 'Gestern';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
    return '${time.day}.${time.month}.${time.year}';
  }
}

