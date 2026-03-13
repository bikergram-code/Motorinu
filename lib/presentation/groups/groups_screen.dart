import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../domain/models/group.dart';
import '../../providers/core/providers.dart';
import '../../providers/groups/groups_notifier.dart';
import '../../theme/app_theme.dart';
import 'create_group_sheet.dart';
import 'widgets/group_card.dart';

/// Full-screen Gruppen page (accessible from bottom nav or speed dial).
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  String _selectedType = ''; // empty = Alle

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(groupsNotifierProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final groupsState = ref.watch(groupsNotifierProvider);

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ??
          (brightness == Brightness.dark
              ? Colors.black
              : const Color(0xFFF5F5F5)),
      appBar: AppBar(
        backgroundColor: community?.scaffoldFor(brightness) ??
            (brightness == Brightness.dark
                ? Colors.black
                : const Color(0xFFF5F5F5)),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded,
              color: community?.textColor(brightness) ??
                  (brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1A1A1A))),
        ),
        title: Text(
          'Gruppen',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: community?.textColor(brightness) ??
                (brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF1A1A1A)),
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: accentColor),
            tooltip: 'Gruppe erstellen',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const CreateGroupSheet(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildChip('', 'Alle', accentColor),
                const SizedBox(width: 8),
                _buildChip(GroupType.ride, 'Fahrgruppen', accentColor),
                const SizedBox(width: 8),
                _buildChip(GroupType.chat, 'Chat', accentColor),
                const SizedBox(width: 8),
                _buildChip(GroupType.club, 'Clubs', accentColor),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(groupsState, accentColor, brightness),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String type, String label, Color accent) {
    final isSelected =
        (type.isEmpty && _selectedType.isEmpty) || _selectedType == type;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: accent,
      onSelected: (_) {
        setState(() => _selectedType = type);
        ref.read(groupsNotifierProvider.notifier).filterByType(
            type.isEmpty ? null : type);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
    );
  }

  Widget _buildContent(
      GroupsState state, Color accentColor, Brightness brightness) {
    if (state.isLoading &&
        state.myGroups.isEmpty &&
        state.discoverGroups.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (state.myGroups.isEmpty && state.discoverGroups.isEmpty) {
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
              child: Icon(Icons.groups_rounded,
                  size: 36, color: Colors.white.withValues(alpha: 0.15)),
            ),
            const SizedBox(height: 20),
            Text(
              'Noch keine Gruppen',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.5)
                    : const Color(0xFF6C757D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Erstelle eine Gruppe oder tritt einer bei!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.3)
                    : const Color(0xFF6C757D),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: accentColor,
      onRefresh: () => ref.read(groupsNotifierProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (state.myGroups.isNotEmpty) ...[
            _sectionHeader('Meine Gruppen', state.myGroups.length, brightness),
            const SizedBox(height: 8),
            for (final group in state.myGroups) ...[
              GroupCard(
                group: group,
                onTap: () => context.push('/group/${group.id}'),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
          ],
          if (state.discoverGroups.isNotEmpty) ...[
            _sectionHeader(
                'Entdecken', state.discoverGroups.length, brightness),
            const SizedBox(height: 8),
            for (final group in state.discoverGroups) ...[
              GroupCard(
                group: group,
                onTap: () => context.push('/group/${group.id}'),
                onJoin: () => _joinGroup(group),
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count, Brightness brightness) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _joinGroup(BikerGroup group) async {
    try {
      await ref.read(groupsNotifierProvider.notifier).joinGroup(group.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Du bist "${group.name}" beigetreten!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
