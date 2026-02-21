import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../domain/xp_calculator.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/achievement_timeline_widget.dart';
import './widgets/active_challenges_widget.dart';
import './widgets/level_progress_header_widget.dart';
import './widgets/trophy_detail_modal_widget.dart';
import './widgets/trophy_grid_widget.dart';

/// Trophy Achievement Center Screen
/// Displays gamification progress, trophies, challenges, and achievement timeline
class TrophyAchievementCenter extends ConsumerStatefulWidget {
  const TrophyAchievementCenter({super.key});

  @override
  ConsumerState<TrophyAchievementCenter> createState() =>
      _TrophyAchievementCenterState();
}

class _TrophyAchievementCenterState extends ConsumerState<TrophyAchievementCenter>
    with TickerProviderStateMixin {
  late TabController _categoryTabController;
  int _currentBottomNavIndex = 4; // Profile tab
  String _selectedCategory = 'Alle';

  // Mock trophy categories
  final List<String> _trophyCategories = [
    'Alle',
    'Distanz',
    'Sozial',
    'Track',
    'DIY',
    'Saisonal',
  ];

  // Mock trophy data
  final List<Map<String, dynamic>> _trophyData = [
    {
      "id": "trophy_1",
      "title": "Erste 1000 km",
      "category": "Distanz",
      "description": "Fahre deine ersten 1000 Kilometer auf BikerGram",
      "icon": "emoji_events",
      "isUnlocked": true,
      "unlockDate": "15.08.2025",
      "progress": 1.0,
      "metalColor":
          0xFFFFD700, // Gold "imageUrl": "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400",
      "semanticLabel":
          "Golden trophy with motorcycle wheel design on dark background",
    },
    {
      "id": "trophy_2",
      "title": "Social Butterfly",
      "category": "Sozial",
      "description": "Erreiche 100 Follower auf BikerGram",
      "icon": "people",
      "isUnlocked": true,
      "unlockDate": "22.09.2025",
      "progress": 1.0,
      "metalColor":
          0xFFC0C0C0, // Silver "imageUrl": "https://images.unsplash.com/photo-1552820728-8b83bb6b773f?w=400",
      "semanticLabel":
          "Silver trophy with social network icon on marble surface",
    },
    {
      "id": "trophy_3",
      "title": "Track Rookie",
      "category": "Track",
      "description": "Absolviere deinen ersten Track Day",
      "icon": "sports_motorsports",
      "isUnlocked": false,
      "progress": 0.0,
      "metalColor":
          0xFF8B4513, // Bronze "imageUrl": "https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=400",
      "semanticLabel":
          "Bronze trophy with racing helmet silhouette on black background",
    },
    {
      "id": "trophy_4",
      "title": "DIY Master",
      "category": "DIY",
      "description": "Dokumentiere 3 erfolgreiche Modifikationen",
      "icon": "build",
      "isUnlocked": false,
      "progress": 0.67,
      "currentCount": 2,
      "targetCount": 3,
      "metalColor":
          0xFFCD7F32, // Bronze "imageUrl": "https://images.unsplash.com/photo-1581092160562-40aa08e78837?w=400",
      "semanticLabel":
          "Bronze trophy with wrench and gear tools on workshop table",
    },
    {
      "id": "trophy_5",
      "title": "5000 km Meilenstein",
      "category": "Distanz",
      "description": "Erreiche 5000 gefahrene Kilometer",
      "icon": "route",
      "isUnlocked": false,
      "progress": 0.69,
      "currentCount": 3450,
      "targetCount": 5000,
      "metalColor":
          0xFFFFD700, // Gold "imageUrl": "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400",
      "semanticLabel": "Golden trophy with road map design on dark surface",
    },
    {
      "id": "trophy_6",
      "title": "Saisonale Challenge",
      "category": "Saisonal",
      "description": "Gewinne die Winter 2025 Challenge",
      "icon": "ac_unit",
      "isUnlocked": false,
      "progress": 0.45,
      "metalColor":
          0xFFC0C0C0, // Silver "imageUrl": "https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5?w=400",
      "semanticLabel": "Silver trophy with snowflake pattern on icy background",
    },
  ];

  // Mock active challenges
  final List<Map<String, dynamic>> _activeChallenges = [
    {
      "id": "challenge_1",
      "title": "Winter Warrior 2025",
      "description": "Fahre 500 km im Januar",
      "category": "Saisonal",
      "progress": 0.68,
      "currentValue": 340,
      "targetValue": 500,
      "unit": "km",
      "timeRemaining": "12 Tage",
      "participants": 1247,
      "userRank": 89,
      "imageUrl":
          "https://images.unsplash.com/photo-1721184750561-1a580017598c",
      "semanticLabel":
          "Motorcycle riding through snowy mountain road with winter landscape",
    },
    {
      "id": "challenge_2",
      "title": "Social Streak",
      "description": "Poste 7 Tage hintereinander",
      "category": "Sozial",
      "progress": 0.57,
      "currentValue": 4,
      "targetValue": 7,
      "unit": "Tage",
      "timeRemaining": "3 Tage",
      "participants": 892,
      "userRank": 156,
      "imageUrl":
          "https://images.unsplash.com/photo-1540122867794-3c8b7e3a22c0",
      "semanticLabel":
          "Smartphone showing social media feed with motorcycle photos",
    },
    {
      "id": "challenge_3",
      "title": "DIY Januar",
      "description": "Schließe 2 Modifikationen ab",
      "category": "DIY",
      "progress": 0.50,
      "currentValue": 1,
      "targetValue": 2,
      "unit": "Mods",
      "timeRemaining": "18 Tage",
      "participants": 534,
      "userRank": 67,
      "imageUrl":
          "https://images.unsplash.com/photo-1661267705991-375336d19aaf",
      "semanticLabel": "Motorcycle workshop with tools and parts on workbench",
    },
  ];

  // Mock achievement timeline
  final List<Map<String, dynamic>> _achievementTimeline = [
    {
      "id": "timeline_1",
      "trophyTitle": "Social Butterfly",
      "unlockDate": "22.09.2025",
      "timestamp": "vor 3 Monaten",
      "category": "Sozial",
      "icon": "people",
      "metalColor": 0xFFC0C0C0,
    },
    {
      "id": "timeline_2",
      "trophyTitle": "Erste 1000 km",
      "unlockDate": "15.08.2025",
      "timestamp": "vor 4 Monaten",
      "category": "Distanz",
      "icon": "emoji_events",
      "metalColor": 0xFFFFD700,
    },
    {
      "id": "timeline_3",
      "trophyTitle": "Erste Modifikation",
      "unlockDate": "03.07.2025",
      "timestamp": "vor 6 Monaten",
      "category": "DIY",
      "icon": "build",
      "metalColor": 0xFFCD7F32,
    },
  ];

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(
      length: _trophyCategories.length,
      vsync: this,
    );
    _categoryTabController.addListener(_handleCategoryChange);
  }

  @override
  void dispose() {
    _categoryTabController.removeListener(_handleCategoryChange);
    _categoryTabController.dispose();
    super.dispose();
  }

  void _handleCategoryChange() {
    if (_categoryTabController.indexIsChanging) {
      setState(() {
        _selectedCategory = _trophyCategories[_categoryTabController.index];
      });
      HapticFeedback.lightImpact();
    }
  }

  List<Map<String, dynamic>> _getFilteredTrophies() {
    if (_selectedCategory == 'Alle') {
      return _trophyData;
    }
    return _trophyData
        .where((trophy) => trophy['category'] == _selectedCategory)
        .toList();
  }

  void _showTrophyDetail(Map<String, dynamic> trophy) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TrophyDetailModalWidget(trophy: trophy),
    );
  }

  void _handleBottomNavTap(int index) {
    setState(() {
      _currentBottomNavIndex = index;
    });
    BottomBarNavigation.navigateToIndex(context, index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        variant: AppBarVariant.standard,
        title: 'Trophäen & Erfolge',
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: CustomIconWidget(
              iconName: 'share',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Teile deine Erfolge mit der Community!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Erfolge teilen',
          ),
          SizedBox(width: 2.w),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Level Progress Header — echte XP-Daten vom User
            SliverToBoxAdapter(
              child: Builder(builder: (_) {
                final authState = ref.watch(authNotifierProvider);
                final user = authState is Authenticated ? (authState as Authenticated).user : null;
                final xp = user?.xpTotal ?? 0;
                final level = XpCalculator.levelFromXp(xp);
                final currentLevelName = XpCalculator.levelName(level);
                final nextLevelName = XpCalculator.levelName(level + 1);
                final progress = XpCalculator.levelProgress(xp);
                return LevelProgressHeaderWidget(userLevelData: {
                  'currentLevel': currentLevelName,
                  'currentXP': xp,
                  'nextLevelXP': level * 100, // XP-Schwelle für nächstes Level
                  'levelProgress': progress,
                  'nextLevel': nextLevelName,
                });
              }),
            ),

            // Category Tabs
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: TabBar(
                  controller: _categoryTabController,
                  isScrollable: true,
                  labelColor: theme.colorScheme.secondary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorColor: theme.colorScheme.secondary,
                  indicatorWeight: 3,
                  labelStyle: theme.textTheme.labelLarge,
                  unselectedLabelStyle: theme.textTheme.labelMedium,
                  tabs: _trophyCategories.map((category) {
                    return Tab(text: category);
                  }).toList(),
                ),
              ),
            ),

            // Trophy Grid
            SliverToBoxAdapter(
              child: TrophyGridWidget(
                trophies: _getFilteredTrophies(),
                onTrophyTap: _showTrophyDetail,
              ),
            ),

            // Active Challenges Section
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                child: Text(
                  'Aktive Challenges',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: ActiveChallengesWidget(challenges: _activeChallenges),
            ),

            // Achievement Timeline Section
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                child: Text(
                  'Erfolgs-Timeline',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: AchievementTimelineWidget(
                achievements: _achievementTimeline,
              ),
            ),

            // Bottom spacing
            SliverToBoxAdapter(child: SizedBox(height: 10.h)),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: _currentBottomNavIndex,
        onTap: _handleBottomNavTap,
        showBadges: false,
      ),
    );
  }
}
