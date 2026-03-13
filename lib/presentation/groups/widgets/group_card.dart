import 'package:flutter/material.dart';


import '../../../domain/models/group.dart';

/// Reusable card widget for displaying a group in lists.
class GroupCard extends StatelessWidget {
  final BikerGroup group;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  const GroupCard({
    super.key,
    required this.group,
    this.onTap,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.10)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            _GroupAvatar(group: group),
            SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Type badge
                      _TypeBadge(type: group.groupType),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          group.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${group.memberCount} Mitglieder',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (group.isRideActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'LIVE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (group.description != null &&
                      group.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      group.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Join button (only for non-members in discover)
            if (onJoin != null) ...[
              SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onJoin,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Beitreten',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (onJoin == null)
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  final BikerGroup group;
  const _GroupAvatar({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (group.avatarUrl != null && group.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(group.avatarUrl!),
      );
    }

    // Default icon based on type
    final color = group.groupType == GroupType.ride
        ? Colors.orange
        : group.groupType == GroupType.club
            ? Colors.blue
            : theme.colorScheme.primary;

    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        GroupType.icon(group.groupType),
        style: const TextStyle(fontSize: 20),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type == GroupType.ride
        ? Colors.orange
        : type == GroupType.club
            ? Colors.blue
            : Colors.teal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        GroupType.label(type),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
