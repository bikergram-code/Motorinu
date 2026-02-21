import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/community.dart';
import '../../../providers/core/providers.dart';

/// A topic from the database.
class Topic {
  const Topic({
    required this.id,
    required this.slug,
    required this.labelEn,
    this.iconUrl,
    this.community = 'global',
  });

  final int id;
  final String slug;
  final String labelEn;
  final String? iconUrl;
  final String community;

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as int,
      slug: json['slug'] as String,
      labelEn: json['label_en'] as String,
      iconUrl: json['icon_url'] as String?,
      community: json['community'] as String? ?? 'global',
    );
  }

  /// Icon for the topic based on slug.
  IconData get icon => switch (slug) {
        'builds' => Icons.build_rounded,
        'trackdays' => Icons.speed_rounded,
        'touring' => Icons.route_rounded,
        'garage' => Icons.garage_rounded,
        'racing' => Icons.emoji_events_rounded,
        'lifestyle' => Icons.local_cafe_rounded,
        'events' => Icons.event_rounded,
        'reviews' => Icons.rate_review_rounded,
        'diy' => Icons.handyman_rounded,
        'offroad' => Icons.terrain_rounded,
        _ => Icons.tag_rounded,
      };
}

/// Provider that fetches available topics from the database.
final topicsProvider = FutureProvider.family<List<Topic>, String?>((ref, communityName) async {
  final data = await Supabase.instance.client
      .from('topics')
      .select()
      .eq('is_active', true)
      .or('community.eq.global,community.eq.${communityName ?? 'bikergram'}')
      .order('sort_order');

  return (data as List).map((j) => Topic.fromJson(j as Map<String, dynamic>)).toList();
});

/// Horizontal scrollable chip picker for selecting up to 3 topics.
class TopicPicker extends ConsumerWidget {
  const TopicPicker({
    super.key,
    required this.selectedTopicIds,
    required this.onChanged,
    this.maxTopics = 3,
  });

  final List<int> selectedTopicIds;
  final ValueChanged<List<int>> onChanged;
  final int maxTopics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? const Color(0xFFFF6B35);
    final brightness = Theme.of(context).brightness;
    final textColor = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    final mutedColor = community?.textMutedColor(brightness) ??
        (brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.4)
            : const Color(0xFF9E9E9E));

    final topicsAsync = ref.watch(topicsProvider(community?.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Icon(Icons.label_outline_rounded, color: mutedColor, size: 16),
              const SizedBox(width: 6),
              Text(
                'Topics (max. $maxTopics)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: mutedColor,
                ),
              ),
              if (selectedTopicIds.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${selectedTopicIds.length}/$maxTopics',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Topic chips
        topicsAsync.when(
          loading: () => const SizedBox(
            height: 36,
            child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
          error: (_, __) => Text(
            'Topics konnten nicht geladen werden',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade300),
          ),
          data: (topics) {
            if (topics.isEmpty) return const SizedBox.shrink();

            return SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: topics.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  final isSelected = selectedTopicIds.contains(topic.id);
                  final canSelect = isSelected || selectedTopicIds.length < maxTopics;

                  return GestureDetector(
                    onTap: () {
                      if (isSelected) {
                        onChanged(selectedTopicIds.where((id) => id != topic.id).toList());
                      } else if (canSelect) {
                        onChanged([...selectedTopicIds, topic.id]);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.15)
                            : (brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            topic.icon,
                            size: 14,
                            color: isSelected ? accentColor : mutedColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            topic.labelEn,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? accentColor : textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
