import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/app_export.dart';

class BusinessDetailModalWidget extends StatelessWidget {
  final Map<String, dynamic> business;

  const BusinessDetailModalWidget({super.key, required this.business});

  void _makePhoneCall(BuildContext context, String phone) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Anrufen: $phone'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openNavigation(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation zu ${business["name"]}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveBusiness(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${business["name"]} gespeichert'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareBusiness(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${business["name"]} teilen'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 90.h,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: CustomIconWidget(
                    iconName: 'close',
                    color: theme.colorScheme.onSurface,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      CustomImageWidget(
                        imageUrl: business["image"] as String,
                        width: double.infinity,
                        height: 30.h,
                        fit: BoxFit.cover,
                        semanticLabel: business["semanticLabel"] as String,
                      ),
                      if (business["isFeatured"] == true)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 3.w,
                              vertical: 1.h,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CustomIconWidget(
                                  iconName: 'star',
                                  color: theme.colorScheme.onSecondary,
                                  size: 16,
                                ),
                                SizedBox(width: 1.w),
                                Text(
                                  'Featured',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.all(4.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                business["name"] as String,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2.w,
                                vertical: 0.5.h,
                              ),
                              decoration: BoxDecoration(
                                color: business["isOpen"] == true
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                business["isOpen"] == true
                                    ? 'Geöffnet'
                                    : 'Geschlossen',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: business["isOpen"] == true
                                      ? Colors.green
                                      : Colors.red,
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
                              iconName: 'star',
                              color: Colors.amber,
                              size: 20,
                            ),
                            SizedBox(width: 1.w),
                            Text(
                              '${business["rating"]}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 1.w),
                            Text(
                              '(${business["reviewCount"]} Bewertungen)',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          business["description"] as String,
                          style: theme.textTheme.bodyLarge,
                        ),
                        SizedBox(height: 2.h),
                        if (business["hasDeals"] == true) ...[
                          Container(
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CustomIconWidget(
                                  iconName: 'local_offer',
                                  color: Colors.red,
                                  size: 24,
                                ),
                                SizedBox(width: 3.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Aktuelles Angebot',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        business["dealText"] as String,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 2.h),
                        ],
                        _buildInfoSection(theme, 'Kontakt', [
                          _buildInfoRow(
                            theme,
                            'location_on',
                            business["address"] as String,
                          ),
                          _buildInfoRow(
                            theme,
                            'phone',
                            business["phone"] as String,
                          ),
                          _buildInfoRow(
                            theme,
                            'schedule',
                            business["openingHours"] as String,
                          ),
                        ]),
                        SizedBox(height: 2.h),
                        _buildInfoSection(theme, 'Spezialisierungen', [
                          Wrap(
                            spacing: 2.w,
                            runSpacing: 1.h,
                            children: (business["specializations"] as List).map(
                              (spec) {
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 3.w,
                                    vertical: 1.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    spec.toString(),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ).toList(),
                          ),
                        ]),
                        SizedBox(height: 2.h),
                        _buildInfoSection(theme, 'Services', [
                          Wrap(
                            spacing: 2.w,
                            runSpacing: 1.h,
                            children: (business["services"] as List).map((
                              service,
                            ) {
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 3.w,
                                  vertical: 1.h,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CustomIconWidget(
                                      iconName: 'check_circle',
                                      color:
                                          theme.colorScheme.onTertiaryContainer,
                                      size: 16,
                                    ),
                                    SizedBox(width: 1.w),
                                    Text(
                                      service.toString(),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onTertiaryContainer,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ]),
                        SizedBox(height: 2.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _makePhoneCall(context, business["phone"] as String),
                      icon: CustomIconWidget(
                        iconName: 'phone',
                        color: theme.colorScheme.onSecondary,
                        size: 20,
                      ),
                      label: Text('Anrufen'),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openNavigation(context),
                      icon: CustomIconWidget(
                        iconName: 'navigation',
                        color: theme.colorScheme.onSecondary,
                        size: 20,
                      ),
                      label: Text('Route'),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  IconButton(
                    onPressed: () => _saveBusiness(context),
                    icon: CustomIconWidget(
                      iconName: 'bookmark_border',
                      color: theme.colorScheme.onSurface,
                      size: 24,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface.withValues(
                        alpha: 0.5,
                      ),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  IconButton(
                    onPressed: () => _shareBusiness(context),
                    icon: CustomIconWidget(
                      iconName: 'share',
                      color: theme.colorScheme.onSurface,
                      size: 24,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface.withValues(
                        alpha: 0.5,
                      ),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    ThemeData theme,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, String iconName, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomIconWidget(
            iconName: iconName,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          SizedBox(width: 3.w),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
