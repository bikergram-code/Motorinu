import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';
import '../../providers/groups/group_detail_notifier.dart';
import '../../providers/groups/groups_notifier.dart';
import '../../providers/core/providers.dart';
import '../../providers/map/live_location_provider.dart';

/// Full-screen detail page for a group.
class GroupDetailScreen extends ConsumerWidget {
  final int groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final detailState = ref.watch(groupDetailProvider(groupId));
    final group = detailState.group;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(
          group?.name ?? 'Gruppe',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (group != null && group.isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Bearbeiten',
              onPressed: () => _showEditSheet(context, ref, group),
            ),
        ],
      ),
      body: detailState.isLoading && group == null
          ? const Center(child: CircularProgressIndicator())
          : group == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group_off_rounded,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          detailState.error ?? 'Gruppe nicht gefunden',
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => ref
                              .read(groupDetailProvider(groupId).notifier)
                              .refresh(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Erneut versuchen'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Zurück'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(groupDetailProvider(groupId).notifier)
                      .refresh(),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    children: [
                      // Header
                      _GroupHeader(group: group),
                      const SizedBox(height: 16),

                      // Active ride banner
                      if (group.isRideActive && group.isMember)
                        _ActiveRideBanner(
                          group: group,
                          groupId: groupId,
                        ),

                      // Status badges + Ride controls
                      if (group.isMember) ...[
                        _QuickActions(
                          group: group,
                          groupId: groupId,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Join button for non-members
                      if (!group.isMember) ...[
                        _JoinButton(groupId: groupId),
                        const SizedBox(height: 16),
                      ],

                      // Members section
                      _MembersSection(
                        members: detailState.members,
                        group: group,
                        groupId: groupId,
                      ),

                      // Leave button at bottom (for non-admin members)
                      if (group.isMember && !group.isAdmin) ...[
                        const SizedBox(height: 24),
                        _LeaveButton(groupId: groupId),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, BikerGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditGroupSheet(group: group, groupId: groupId),
    );
  }

}

// ═══════════════════════════════════════════════════
//  GROUP HEADER
// ═══════════════════════════════════════════════════

class _GroupHeader extends StatelessWidget {
  final BikerGroup group;
  const _GroupHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1E2E), const Color(0xFF252540)]
              : [Colors.white, const Color(0xFFF5F5FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          // Avatar + Badge
          Stack(
            alignment: Alignment.bottomRight,
            children: [_buildAvatar(theme), _buildTypeBadge()],
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            group.name,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(
                icon: Icons.people_outline,
                label: '${group.memberCount}',
              ),
              if (!group.isPublic) ...[
                const SizedBox(width: 8),
                _StatChip(icon: Icons.lock_outline, label: 'Privat'),
              ],
              if (group.isRideActive) ...[
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.directions_bike,
                  label: 'Fahrt aktiv',
                  color: Colors.green,
                ),
              ],
            ],
          ),
          // Description
          if (group.description != null && group.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              group.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          // Creator
          if (group.creatorName != null) ...[
            const SizedBox(height: 6),
            Text(
              'von ${group.creatorName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    if (group.avatarUrl != null && group.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(group.avatarUrl!),
      );
    }
    final color = group.groupType == GroupType.ride
        ? Colors.orange
        : group.groupType == GroupType.club
            ? Colors.blue
            : theme.colorScheme.primary;
    return CircleAvatar(
      radius: 40,
      backgroundColor: color.withOpacity(0.15),
      child: Text(GroupType.icon(group.groupType),
          style: const TextStyle(fontSize: 36)),
    );
  }

  Widget _buildTypeBadge() {
    final color = group.groupType == GroupType.ride
        ? Colors.orange
        : group.groupType == GroupType.club
            ? Colors.blue
            : Colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        GroupType.label(group.groupType),
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _StatChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  ACTIVE RIDE BANNER
// ═══════════════════════════════════════════════════

class _ActiveRideBanner extends ConsumerWidget {
  final BikerGroup group;
  final int groupId;

  const _ActiveRideBanner({required this.group, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveService = globalLiveLocationService;
    final isInThisRide = liveService.isLive &&
        liveService.activeGroupId == groupId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Main ride banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_bike, color: Colors.orange, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gruppenfahrt aktiv',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        isInThisRide
                            ? 'Du fährst mit — GPS wird geteilt'
                            : 'Tritt bei um deinen Standort zu teilen',
                        style: TextStyle(
                          color: Colors.orange.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isInThisRide)
                  FilledButton.tonal(
                    onPressed: () {
                      final rideColor = group.rideColor;
                      liveService.setActiveGroup(groupId, rideColor, isLeader: group.isAdmin);
                      if (!liveService.isLive) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Gruppe verbunden! Schalte GPS auf der Karte ein um deinen Standort zu teilen.'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Du fährst jetzt mit!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      ref.read(groupDetailProvider(groupId).notifier).refresh();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Beitreten',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                if (isInThisRide)
                  OutlinedButton(
                    onPressed: () {
                      liveService.setActiveGroup(null, null);
                      ref.read(groupDetailProvider(groupId).notifier).refresh();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Verlassen',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
              ],
            ),
          ),

          // "Ride Screen" action button — opens full-screen ride experience
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                // Make sure user is part of this ride
                if (!isInThisRide) {
                  liveService.setActiveGroup(groupId, group.rideColor, isLeader: group.isAdmin);
                }
                context.push('/group-ride/$groupId');
              },
              icon: const Icon(Icons.fullscreen_rounded, size: 20),
              label: const Text(
                'Fahrt-Modus öffnen — Karte · Video · Blitzer',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  QUICK ACTIONS (Chat, Voice, Video, Ride)
// ═══════════════════════════════════════════════════

class _QuickActions extends ConsumerWidget {
  final BikerGroup group;
  final int groupId;

  const _QuickActions({
    required this.group,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Status badges row
          Row(
            children: [
              Expanded(
                child: _StatusBadge(
                  icon: Icons.headset_mic_rounded,
                  label: 'Funk verbunden',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusBadge(
                  icon: !group.isPublic ? Icons.lock_outline : Icons.public,
                  label: !group.isPublic ? 'Privat' : 'Öffentlich',
                  color: !group.isPublic ? Colors.amber.shade700 : Colors.blue,
                ),
              ),
            ],
          ),
          // Ride controls (all group types can start a ride)
          if (group.isMember) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (group.isAdmin)
                  Expanded(
                    child: _ActionTile(
                      icon: group.isRideActive
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_rounded,
                      label: group.isRideActive
                          ? 'Fahrt stoppen'
                          : 'Fahrt starten',
                      color: group.isRideActive ? Colors.red : Colors.orange,
                      onTap: () => _toggleRide(context, ref),
                    ),
                  ),
                if (group.isAdmin) const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.map_rounded,
                    label: 'Karte',
                    color: Colors.teal,
                    onTap: () => context.go('/map'),
                  ),
                ),
              ],
            ),
            // Navigation + Blitzer (only when ride is active)
            if (group.isRideActive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.navigation_rounded,
                      label: group.destinationName != null
                          ? 'Navigieren'
                          : 'Ziel setzen',
                      color: Colors.indigo,
                      onTap: () => _handleNavigation(context, ref),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.speed_rounded,
                      label: 'Blitzer',
                      color: Colors.red,
                      onTap: () => _showBlitzerWarning(context),
                    ),
                  ),
                ],
              ),
              // Current destination info
              if (group.destinationName != null) ...[
                const SizedBox(height: 8),
                _DestinationBanner(
                  group: group,
                  groupId: groupId,
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _toggleRide(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(groupDetailProvider(groupId).notifier);
    try {
      if (group.isRideActive) {
        await notifier.stopRide();
      } else {
        await notifier.startRide();
      }
      ref.read(groupsNotifierProvider.notifier).refresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  /// Handle navigation — if destination exists, open in Google Maps/Waze.
  /// If no destination, show dialog to set one.
  Future<void> _handleNavigation(
      BuildContext context, WidgetRef ref) async {
    if (group.destinationLat != null && group.destinationLng != null) {
      // Open navigation app chooser
      _showNavAppChooser(context, group.destinationLat!,
          group.destinationLng!, group.destinationName ?? 'Ziel');
    } else if (group.isAdmin) {
      // Admin can set destination
      _showSetDestinationDialog(context, ref);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Der Admin hat noch kein Ziel gesetzt')),
      );
    }
  }

  /// Show chooser between Google Maps and Waze
  void _showNavAppChooser(
      BuildContext context, double lat, double lng, String name) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Navigation zu "$name"',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map_rounded, color: Colors.blue),
              title: const Text('Google Maps'),
              subtitle: const Text('Motorradmodus verfügbar'),
              onTap: () {
                Navigator.of(ctx).pop();
                _launchUrl(
                    'google.navigation:q=$lat,$lng&mode=d');
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed_rounded, color: Colors.cyan),
              title: const Text('Waze'),
              subtitle: const Text('Blitzer-Warnungen inklusive'),
              onTap: () {
                Navigator.of(ctx).pop();
                _launchUrl(
                    'https://waze.com/ul?ll=$lat,$lng&navigate=yes');
              },
            ),
            ListTile(
              leading: const Icon(Icons.navigation_rounded,
                  color: Colors.green),
              title: const Text('Standard Navigation'),
              onTap: () {
                Navigator.of(ctx).pop();
                _launchUrl(
                    'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(name)})');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      // Use url_launcher through intent
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }

  /// Dialog for admin to set ride destination
  void _showSetDestinationDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fahrt-Ziel setzen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Zielname',
                hintText: 'z.B. Grossglockner, Stilfser Joch...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Breitengrad',
                      hintText: '47.0732',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: lngCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Längengrad',
                      hintText: '12.6954',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tipp: Koordinaten aus Google Maps kopieren',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.6)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final lat = double.tryParse(latCtrl.text.trim());
              final lng = double.tryParse(lngCtrl.text.trim());
              if (name.isEmpty || lat == null || lng == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Bitte Name und gültige Koordinaten eingeben')),
                );
                return;
              }
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(groupRepositoryProvider);
                await repo.setDestination(groupId,
                    lat: lat, lng: lng, name: name);
                ref
                    .read(groupDetailProvider(groupId).notifier)
                    .refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ziel "$name" gesetzt!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fehler: $e')),
                  );
                }
              }
            },
            child: const Text('Ziel setzen'),
          ),
        ],
      ),
    );
  }

  void _showBlitzerWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.speed_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            const Text('Blitzer-Warnung'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Für Blitzer-Warnungen während der Fahrt empfehlen wir:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.speed_rounded, color: Colors.cyan),
              title: const Text('Waze',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Echtzeit Blitzer-Meldungen von der Community'),
              onTap: () {
                Navigator.of(ctx).pop();
                _launchUrl('https://waze.com/ul');
              },
            ),
            const Divider(),
            const Text(
              'Starte die Navigation über "Navigieren" → Waze, um Blitzer automatisch zu erkennen.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _DestinationBanner extends ConsumerWidget {
  final BikerGroup group;
  final int groupId;

  const _DestinationBanner({required this.group, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: Colors.indigo, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ziel: ${group.destinationName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.indigo,
                  ),
                ),
                if (group.destinationLat != null)
                  Text(
                    '${group.destinationLat!.toStringAsFixed(4)}, ${group.destinationLng!.toStringAsFixed(4)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.indigo.withOpacity(0.7)),
                  ),
              ],
            ),
          ),
          if (group.isAdmin)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.indigo),
              onPressed: () async {
                final repo = ref.read(groupRepositoryProvider);
                await repo.clearDestination(groupId);
                ref.read(groupDetailProvider(groupId).notifier).refresh();
              },
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  JOIN BUTTON
// ═══════════════════════════════════════════════════

class _JoinButton extends ConsumerWidget {
  final int groupId;
  const _JoinButton({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () async {
          await ref.read(groupDetailProvider(groupId).notifier).join();
          ref.read(groupsNotifierProvider.notifier).refresh();
        },
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Beitreten',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  LEAVE BUTTON
// ═══════════════════════════════════════════════════

class _LeaveButton extends ConsumerWidget {
  final int groupId;
  const _LeaveButton({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Gruppe verlassen?'),
              content: const Text(
                  'Möchtest du diese Gruppe wirklich verlassen?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Verlassen',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await ref
                .read(groupDetailProvider(groupId).notifier)
                .leave();
            ref.read(groupsNotifierProvider.notifier).refresh();
            if (context.mounted) context.pop();
          }
        },
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Gruppe verlassen'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  MEMBERS SECTION
// ═══════════════════════════════════════════════════

class _MembersSection extends ConsumerWidget {
  final List<GroupMember> members;
  final BikerGroup group;
  final int groupId;

  const _MembersSection({
    required this.members,
    required this.group,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Mitglieder',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${members.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const Spacer(),
            // Add members button (admin only)
            if (group.isAdmin)
              IconButton(
                icon: const Icon(Icons.person_add_outlined, size: 20),
                tooltip: 'Mitglieder einladen',
                onPressed: () => _showInviteDialog(context, ref),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final member in members) ...[
          _MemberTile(
            member: member,
            isAdmin: group.isAdmin,
            isCreator: group.creatorId == member.userId,
            isMe: member.userId == currentUserId,
            groupId: groupId,
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(groupRepositoryProvider);
    final notifRepo = ref.read(notificationRepositoryProvider);
    final existingIds = members.map((m) => m.userId).toSet();

    // Load users the current user follows
    List<Map<String, dynamic>> friends;
    try {
      friends = await repo.getFollowingProfiles();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
      return;
    }

    // Filter out users already in the group
    friends = friends
        .where((f) => !existingIds.contains(f['id'] as String?))
        .toList();

    if (!context.mounted) return;

    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Keine weiteren Follower zum Einladen vorhanden')),
      );
      return;
    }

    final selected = <String>{};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final theme = Theme.of(ctx);
          final isDark = theme.brightness == Brightness.dark;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.65,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Mitglieder einladen',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: friends.length,
                    itemBuilder: (_, i) {
                      final f = friends[i];
                      final fId = f['id'] as String;
                      final name = f['display_name'] as String? ??
                          f['username'] as String? ??
                          'User';
                      final avatar = f['avatar_url'] as String?;
                      final isSel = selected.contains(fId);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundImage:
                              avatar != null ? NetworkImage(avatar) : null,
                          child: avatar == null
                              ? Text(name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?')
                              : null,
                        ),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Checkbox(
                          value: isSel,
                          onChanged: (_) {
                            setLocal(() {
                              if (isSel) {
                                selected.remove(fId);
                              } else {
                                selected.add(fId);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          setLocal(() {
                            if (isSel) {
                              selected.remove(fId);
                            } else {
                              selected.add(fId);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () => Navigator.of(ctx).pop(),
                      child: Text(
                        selected.isEmpty
                            ? 'Auswählen'
                            : '${selected.length} einladen',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (selected.isEmpty || !context.mounted) return;

    // Add members to group
    try {
      await repo.addMembersToGroup(groupId, selected.toList());

      // Send notification to each invited user
      final groupName = group.name;
      for (final userId in selected) {
        notifRepo.createNotification(
          targetUserId: userId,
          type: 'system',
          title: 'Du wurdest zur Gruppe "$groupName" eingeladen',
          body: 'Tippe hier um die Gruppe zu öffnen',
          data: {'group_id': groupId},
          community: 'bikergram',
        );
      }

      ref.read(groupDetailProvider(groupId).notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.length} Mitglied(er) eingeladen'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }
}

class _MemberTile extends ConsumerWidget {
  final GroupMember member;
  final bool isAdmin;
  final bool isCreator;
  final bool isMe;
  final int groupId;

  const _MemberTile({
    required this.member,
    required this.isAdmin,
    required this.isCreator,
    required this.isMe,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = member.displayName ?? member.username ?? 'User';

    return InkWell(
      onTap: () => context.push('/profile/${member.userId}'),
      onLongPress: (isAdmin && !isMe && !isCreator)
          ? () => _showMemberActions(context, ref)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundImage: member.avatarUrl != null
                  ? NetworkImage(member.avatarUrl!)
                  : null,
              child: member.avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Name + role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '$name (Du)' : name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (isCreator)
                    Text(
                      'Ersteller',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
            // Role badge
            if (member.role == 'admin')
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.amber.shade700,
                  ),
                ),
              ),
            // Admin actions (kebab menu)
            if (isAdmin && !isMe && !isCreator)
              IconButton(
                icon: Icon(Icons.more_vert, size: 18,
                    color: theme.colorScheme.onSurfaceVariant),
                onPressed: () => _showMemberActions(context, ref),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  void _showMemberActions(BuildContext context, WidgetRef ref) {
    final name = member.displayName ?? member.username ?? 'User';

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            // Promote / Demote
            ListTile(
              leading: Icon(
                member.role == 'admin'
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: Colors.amber.shade700,
              ),
              title: Text(member.role == 'admin'
                  ? 'Zum Mitglied machen'
                  : 'Zum Admin machen'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final repo = ref.read(groupRepositoryProvider);
                try {
                  if (member.role == 'admin') {
                    await repo.demoteMember(groupId, member.userId);
                  } else {
                    await repo.promoteMember(groupId, member.userId);
                  }
                  ref
                      .read(groupDetailProvider(groupId).notifier)
                      .refresh();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fehler: $e')),
                    );
                  }
                }
              },
            ),
            // Kick
            ListTile(
              leading: const Icon(Icons.person_remove_rounded,
                  color: Colors.red),
              title: const Text('Aus Gruppe entfernen',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dlg) => AlertDialog(
                    title: Text('$name entfernen?'),
                    content: Text(
                        '$name wird aus der Gruppe und dem Chat entfernt.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dlg).pop(false),
                        child: const Text('Abbrechen'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dlg).pop(true),
                        child: const Text('Entfernen',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    final repo = ref.read(groupRepositoryProvider);
                    await repo.kickMember(groupId, member.userId);
                    ref
                        .read(groupDetailProvider(groupId).notifier)
                        .refresh();
                    ref.read(groupsNotifierProvider.notifier).refresh();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler: $e')),
                      );
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  EDIT GROUP SHEET
// ═══════════════════════════════════════════════════

class _EditGroupSheet extends ConsumerStatefulWidget {
  final BikerGroup group;
  final int groupId;

  const _EditGroupSheet({required this.group, required this.groupId});

  @override
  ConsumerState<_EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends ConsumerState<_EditGroupSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.group.name);
    _descCtrl =
        TextEditingController(text: widget.group.description ?? '');
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
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Gruppe bearbeiten',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Gruppenname',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Beschreibung',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Text('Speichern',
                          style:
                              TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Gruppe löschen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(
                        color: Colors.red.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(groupRepositoryProvider);
      await repo.updateGroup(
        widget.groupId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
      ref
          .read(groupDetailProvider(widget.groupId).notifier)
          .refresh();
      ref.read(groupsNotifierProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gruppe löschen?'),
        content: const Text(
            'Diese Aktion kann nicht rückgängig gemacht werden. '
            'Alle Nachrichten und Mitgliedschaften werden gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(groupsNotifierProvider.notifier)
          .deleteGroup(widget.groupId);
      if (mounted) {
        Navigator.of(context).pop(); // close sheet
        context.pop(); // go back from detail
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
        setState(() => _busy = false);
      }
    }
  }
}
