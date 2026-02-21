import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ProductCardWidget extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback onSaveToWishlist;
  final VoidCallback onShare;
  final VoidCallback onShowSimilar;
  final VoidCallback onLongPress;

  const ProductCardWidget({
    super.key,
    required this.product,
    required this.onTap,
    required this.onSaveToWishlist,
    required this.onShare,
    required this.onShowSimilar,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              HapticFeedback.lightImpact();
              onSaveToWishlist();
            },
            backgroundColor: colorScheme.tertiaryContainer,
            foregroundColor: colorScheme.onTertiaryContainer,
            icon: Icons.bookmark_border,
            label: 'Merken',
          ),
          SlidableAction(
            onPressed: (context) {
              HapticFeedback.lightImpact();
              onShare();
            },
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            icon: Icons.share,
            label: 'Teilen',
          ),
          SlidableAction(
            onPressed: (context) {
              HapticFeedback.lightImpact();
              onShowSimilar();
            },
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            icon: Icons.search,
            label: 'Ähnlich',
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress();
        },
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductImage(context, theme, colorScheme),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(2.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductTitle(theme, colorScheme),
                      SizedBox(height: 0.5.h),
                      _buildProductPrice(theme, colorScheme),
                      SizedBox(height: 1.h),
                      _buildSellerInfo(theme, colorScheme),
                      const Spacer(),
                      _buildDistanceInfo(theme, colorScheme),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Stack(
      children: [
        Hero(
          tag: 'product-${product['id']}',
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: CustomImageWidget(
              imageUrl: product['image'] as String,
              width: double.infinity,
              height: 20.h,
              fit: BoxFit.cover,
              semanticLabel: product['semanticLabel'] as String,
            ),
          ),
        ),
        (product['isTrustedSeller'] as bool)
            ? Positioned(
                top: 1.h,
                right: 2.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.w,
                    vertical: 0.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: 'verified',
                        color: colorScheme.onSecondary,
                        size: 12,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        'Verifiziert',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
        Positioned(
          top: 1.h,
          left: 2.w,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              product['condition'] as String,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductTitle(ThemeData theme, ColorScheme colorScheme) {
    return Text(
      product['title'] as String,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildProductPrice(ThemeData theme, ColorScheme colorScheme) {
    return Text(
      '${product['currency']} ${product['price']}',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.secondary,
      ),
    );
  }

  Widget _buildSellerInfo(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        CustomIconWidget(iconName: 'star', color: Colors.amber, size: 14),
        SizedBox(width: 1.w),
        Text(
          product['sellerRating'].toString(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(width: 1.w),
        Text(
          '(${product['reviewCount']})',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDistanceInfo(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        CustomIconWidget(
          iconName: 'location_on',
          color: colorScheme.onSurfaceVariant,
          size: 14,
        ),
        SizedBox(width: 1.w),
        Text(
          product['distance'] as String,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
