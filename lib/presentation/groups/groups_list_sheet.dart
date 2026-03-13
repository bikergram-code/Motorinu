import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../domain/models/group.dart';
import '../../providers/groups/groups_notifier.dart';
import 'create_group_sheet.dart';
import 'widgets/group_card.dart';

/// Bottom sheet showing the user's groups + discover section.
class GroupsListSheet extends ConsumerStatefulWidget {
  const GroupsListSheet({super.key});

  @override
  ConsumerState<GroupsListSheet> createState() => _GroupsListSheetState();
}

class _GroupsListSheetState extends ConsumerState<GroupsListSheet> {
  @override
  void initState() {
    super.initState();
    // Trigger load if not loaded yet
    Future.microtask(
        () => ref.read(groupsNotifierProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final groupsState = ref.watch(groupsNotifierProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4.0),
                child: Row(
                  children: [
                    Text(
                      'Gruppen',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _openCreateSheet,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Erstellen'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Filter chips
              _FilterChips(
                selectedType: groupsState.selectedType,
                onSelected: (type) {
                  ref.read(groupsNotifierProvider.notifier).filterByType(type);
                },
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: groupsState.isLoading &&
                        groupsState.myGroups.isEmpty &&
                        groupsState.discoverGroups.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(groupsNotifierProvider.notifier).refresh(),
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8.0,
                          ),
                          children: [
                            // My Groups
                            if (groupsState.myGroups.isNotEmpty) ...[
                              _SectionHeader(
                                title: 'Meine Gruppen',
                                count: groupsState.myGroups.length,
                              ),
                              SizedBox(height: 6.0),
                              for (final group in groupsState.myGroups) ...[
                                GroupCard(
                                  group: group,
                                  onTap: () => _openGroup(group),
                                ),
                                SizedBox(height: 6.0),
                              ],
                              SizedBox(height: 12.0),
                            ],
                            // Discover
                            if (groupsState.discoverGroups.isNotEmpty) ...[
                              _SectionHeader(
                                title: 'Entdecken',
                                count: groupsState.discoverGroups.length,
                              ),
                              SizedBox(height: 6.0),
                              for (final group
                                  in groupsState.discoverGroups) ...[
                                GroupCard(
                                  group: group,
                                  onTap: () => _openGroup(group),
                                  onJoin: () => _joinGroup(group),
                                ),
                                SizedBox(height: 6.0),
                              ],
                            ],
                            // Empty state
                            if (groupsState.myGroups.isEmpty &&
                                groupsState.discoverGroups.isEmpty &&
                                !groupsState.isLoading) ...[
                              SizedBox(height: 48.0),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.groups_rounded,
                                      size: 48,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withOpacity(0.3),
                                    ),
                                    SizedBox(height: 8.0),
                                    Text(
                                      'Noch keine Gruppen',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    SizedBox(height: 4.0),
                                    Text(
                                      'Erstelle eine Gruppe oder tritt einer bei!',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(height: 16.0),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateGroupSheet(),
    );
  }

  void _openGroup(BikerGroup group) {
    Navigator.of(context).pop(); // close this sheet
    context.push('/group/${group.id}');
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

class _FilterChips extends StatelessWidget {
  final String? selectedType;
  final ValueChanged<String?> onSelected;

  const _FilterChips({
    required this.selectedType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4.0),
      child: Row(
        children: [
          _chip(context, null, 'Alle'),
          const SizedBox(width: 6),
          _chip(context, GroupType.ride, 'Fahrgruppen'),
          const SizedBox(width: 6),
          _chip(context, GroupType.chat, 'Chat'),
          const SizedBox(width: 6),
          _chip(context, GroupType.club, 'Clubs'),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String? type, String label) {
    final theme = Theme.of(context);
    final isSelected =
        (type == null && selectedType == null) || selectedType == type;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
      ),
      backgroundColor: theme.colorScheme.surface,
      selectedColor: theme.colorScheme.primary,
      onSelected: (_) => onSelected(type),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
