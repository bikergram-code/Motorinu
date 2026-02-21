import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/app_export.dart';
import '../../../widgets/custom_app_bar.dart';

class BikeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> bike;
  final Function(Map<String, dynamic>) onBikeUpdated;
  final Function(int) onBikeDeleted;

  const BikeDetailScreen({
    super.key,
    required this.bike,
    required this.onBikeUpdated,
    required this.onBikeDeleted,
  });

  @override
  State<BikeDetailScreen> createState() => _BikeDetailScreenState();
}

class _BikeDetailScreenState extends State<BikeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        variant: AppBarVariant.standard,
        title: '${widget.bike["make"]} ${widget.bike["model"]}',
        centerTitle: false,
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
                const SnackBar(
                  content: Text('Motorrad teilen'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Teilen',
          ),
          IconButton(
            icon: CustomIconWidget(
              iconName: 'more_vert',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showOptionsMenu();
            },
            tooltip: 'Mehr',
          ),
        ],
      ),
      body: Column(
        children: [
          // Photo gallery
          SizedBox(
            height: 30.h,
            child: Stack(
              children: [
                PageView(
                  onPageChanged: (index) {
                    setState(() {
                      _currentPhotoIndex = index;
                    });
                  },
                  children: [
                    CustomImageWidget(
                      imageUrl: widget.bike["imageUrl"],
                      width: double.infinity,
                      height: 30.h,
                      fit: BoxFit.cover,
                      semanticLabel: widget.bike["semanticLabel"],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 2.h,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      1,
                      (index) => Container(
                        width: 2.w,
                        height: 2.w,
                        margin: EdgeInsets.symmetric(horizontal: 1.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPhotoIndex == index
                              ? theme.colorScheme.secondary
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tabs
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Übersicht'),
                Tab(text: 'Modifikationen'),
                Tab(text: 'Wunschliste'),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildModificationsTab(),
                _buildWishlistTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final theme = Theme.of(context);
    final specifications =
        widget.bike["specifications"] as Map<String, dynamic>;

    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic info card
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.bike["make"]} ${widget.bike["model"]}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 0.8.h,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.bike["category"],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'calendar_today',
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      'Baujahr ${widget.bike["year"]}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          // Specifications
          Text(
            'Technische Daten',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: specifications.entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 1.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        entry.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 3.h),
          // Quick actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/build-log-editor');
                  },
                  icon: CustomIconWidget(
                    iconName: 'edit_note',
                    color: theme.colorScheme.onSecondary,
                    size: 20,
                  ),
                  label: const Text('Build-Log'),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/marketplace-browse');
                  },
                  icon: CustomIconWidget(
                    iconName: 'shopping_cart',
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  label: const Text('Teile kaufen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModificationsTab() {
    final theme = Theme.of(context);
    final modifications = widget.bike["modifications"] as List;

    return modifications.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomIconWidget(
                  iconName: 'build',
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 64,
                ),
                SizedBox(height: 2.h),
                Text(
                  'Noch keine Modifikationen',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Füge deine ersten Umbauten hinzu',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 3.h),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/build-log-editor');
                  },
                  icon: CustomIconWidget(
                    iconName: 'add',
                    color: theme.colorScheme.onSecondary,
                    size: 20,
                  ),
                  label: const Text('Modifikation hinzufügen'),
                ),
              ],
            ),
          )
        : ListView.separated(
            padding: EdgeInsets.all(4.w),
            itemCount: modifications.length,
            separatorBuilder: (context, index) => SizedBox(height: 2.h),
            itemBuilder: (context, index) {
              final mod = modifications[index];
              return Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            mod["title"],
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          mod["cost"],
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.h),
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'calendar_today',
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 14,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          mod["date"],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(mod["description"], style: theme.textTheme.bodyMedium),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vorher',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(height: 0.5.h),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CustomImageWidget(
                                  imageUrl: mod["beforeImage"],
                                  width: double.infinity,
                                  height: 15.h,
                                  fit: BoxFit.cover,
                                  semanticLabel: mod["beforeSemanticLabel"],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nachher',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(height: 0.5.h),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CustomImageWidget(
                                  imageUrl: mod["afterImage"],
                                  width: double.infinity,
                                  height: 15.h,
                                  fit: BoxFit.cover,
                                  semanticLabel: mod["afterSemanticLabel"],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
  }

  Widget _buildWishlistTab() {
    final theme = Theme.of(context);
    final wishlist = widget.bike["wishlist"] as List;

    return wishlist.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomIconWidget(
                  iconName: 'favorite_border',
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 64,
                ),
                SizedBox(height: 2.h),
                Text(
                  'Wunschliste ist leer',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Füge Teile hinzu, die du kaufen möchtest',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        : ListView.separated(
            padding: EdgeInsets.all(4.w),
            itemCount: wishlist.length,
            separatorBuilder: (context, index) => SizedBox(height: 2.h),
            itemBuilder: (context, index) {
              final item = wishlist[index];
              return Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item["part"],
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 2.w,
                                  vertical: 0.5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: item["priority"] == "Hoch"
                                      ? theme.colorScheme.errorContainer
                                      : item["priority"] == "Mittel"
                                      ? theme.colorScheme.tertiaryContainer
                                      : theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item["priority"],
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: item["priority"] == "Hoch"
                                        ? theme.colorScheme.onErrorContainer
                                        : item["priority"] == "Mittel"
                                        ? theme.colorScheme.onTertiaryContainer
                                        : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                item["estimatedCost"],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: CustomIconWidget(
                        iconName: 'shopping_cart',
                        color: theme.colorScheme.secondary,
                        size: 24,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pushNamed(context, '/marketplace-browse');
                      },
                    ),
                  ],
                ),
              );
            },
          );
  }

  void _showOptionsMenu() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10.w,
                height: 0.5.h,
                margin: EdgeInsets.symmetric(vertical: 1.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'edit',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text('Bearbeiten', style: theme.textTheme.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bearbeiten öffnen'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'picture_as_pdf',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text(
                  'Als PDF exportieren',
                  style: theme.textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PDF wird erstellt...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'delete',
                  color: theme.colorScheme.error,
                  size: 24,
                ),
                title: Text(
                  'Löschen',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.mediumImpact();
                  _confirmDelete();
                },
              ),
              SizedBox(height: 2.h),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Motorrad löschen?', style: theme.textTheme.titleLarge),
          content: Text(
            'Möchtest du dieses Motorrad wirklich aus deiner Garage entfernen? Diese Aktion kann nicht rückgängig gemacht werden.',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                widget.onBikeDeleted(widget.bike["id"]);
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Motorrad gelöscht'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text(
                'Löschen',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }
}
