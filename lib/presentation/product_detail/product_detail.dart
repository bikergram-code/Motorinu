import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_app_bar.dart';
import './widgets/action_buttons_widget.dart';
import './widgets/image_gallery_widget.dart';
import './widgets/product_info_card_widget.dart';
import './widgets/related_products_widget.dart';
import './widgets/reviews_section_widget.dart';
import './widgets/seller_section_widget.dart';

class ProductDetail extends StatefulWidget {
  const ProductDetail({super.key});

  @override
  State<ProductDetail> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetail> {
  bool _isSaved = false;
  bool _isDescriptionExpanded = false;

  // Mock product data
  final Map<String, dynamic> productData = {
    "id": 1,
    "title": "Akrapovic Auspuffanlage Komplett",
    "price": "1.299,00",
    "currency": "€",
    "condition": "Neuwertig",
    "images": [
      {
        "url":
            "https://images.unsplash.com/photo-1583971407627-99b68eea9e34",
        "semanticLabel":
            "Close-up of a chrome motorcycle exhaust system with Akrapovic branding mounted on a black sport bike",
      },
      {
        "url":
            "https://img.rocket.new/generatedImages/rocket_gen_img_103942598-1766601475190.png",
        "semanticLabel":
            "Side view of complete motorcycle exhaust system showing headers and muffler on workshop floor",
      },
      {
        "url":
            "https://images.unsplash.com/photo-1725857603500-73e88030e2dd",
        "semanticLabel":
            "Detail shot of titanium exhaust tip with carbon fiber heat shield and mounting bracket",
      },
      {
        "url":
            "https://img.rocket.new/generatedImages/rocket_gen_img_19e0f722a-1767639198586.png",
        "semanticLabel":
            "Full exhaust system laid out showing all components including headers, mid-pipe, and muffler",
      },
    ],
    "description":
        "Original Akrapovic Racing Auspuffanlage für Sportbikes. Komplettsystem aus Titan mit Carbon-Endkappe. Deutliche Gewichtsreduktion von 4,2 kg gegenüber Serienanlage. Leistungssteigerung von ca. 8 PS im oberen Drehzahlbereich. TÜV-Teilegutachten vorhanden. Nur 2.000 km gelaufen, wie neu. Inklusive aller Montageteile und Dichtungen. Passt perfekt für Yamaha R1 (2015-2019) und MT-10 (2016-2020). Sound ist tief und sportlich, nicht zu laut für den Alltag.",
    "specifications": [
      {"label": "Marke", "value": "Akrapovic"},
      {"label": "Material", "value": "Titan mit Carbon"},
      {"label": "Gewicht", "value": "3,8 kg"},
      {"label": "Kompatibilität", "value": "Yamaha R1 / MT-10"},
      {"label": "Baujahr", "value": "2015-2020"},
      {"label": "Teilenummer", "value": "S-Y10SO14-HAPT"},
      {"label": "Zustand", "value": "Neuwertig (2.000 km)"},
      {"label": "TÜV", "value": "Ja, Gutachten vorhanden"},
    ],
    "seller": {
      "id": 123,
      "name": "Michael Schmidt",
      "avatar":
          "https://img.rocket.new/generatedImages/rocket_gen_img_197db517a-1763293484621.png",
      "semanticLabel":
          "Profile photo of a man with short brown hair and a beard wearing a black leather jacket",
      "rating": 4.8,
      "totalReviews": 47,
      "responseTime": "< 2 Std.",
      "location": "München",
      "distance": "12 km",
      "verified": true,
      "memberSince": "2023",
    },
    "compatibility": {
      "compatible": true,
      "userBikes": ["Yamaha MT-10 (2018)"],
      "warning": null,
    },
    "reviews": [
      {
        "id": 1,
        "userName": "Thomas Weber",
        "userAvatar":
            "https://img.rocket.new/generatedImages/rocket_gen_img_1c8b652f2-1763293994171.png",
        "semanticLabel":
            "Profile photo of a middle-aged man with glasses and gray hair wearing a blue shirt",
        "rating": 5,
        "date": "2025-12-15",
        "comment":
            "Perfekter Zustand, genau wie beschrieben. Schnelle Lieferung und gute Kommunikation. Sehr empfehlenswert!",
        "helpful": 12,
        "images": [],
      },
      {
        "id": 2,
        "userName": "Andreas Müller",
        "userAvatar":
            "https://img.rocket.new/generatedImages/rocket_gen_img_126de2306-1763294599585.png",
        "semanticLabel":
            "Profile photo of a young man with short blonde hair wearing a red motorcycle jacket",
        "rating": 5,
        "date": "2025-11-28",
        "comment":
            "Top Verkäufer! Auspuff war perfekt verpackt und passt 1A. Sound ist der Hammer!",
        "helpful": 8,
        "images": [
          {
            "url":
                "https://img.rocket.new/generatedImages/rocket_gen_img_1b2833bd2-1767639199244.png",
            "semanticLabel":
                "Installed exhaust system on motorcycle showing perfect fitment",
          },
        ],
      },
    ],
    "relatedProducts": [
      {
        "id": 2,
        "title": "Yoshimura R-77 Auspuff",
        "price": "899,00",
        "currency": "€",
        "image":
            "https://img.rocket.new/generatedImages/rocket_gen_img_1c7c11137-1767639201839.png",
        "semanticLabel":
            "Yoshimura R-77 exhaust system with stainless steel construction and carbon fiber tip",
        "condition": "Gebraucht",
      },
      {
        "id": 3,
        "title": "SC-Project Schalldämpfer",
        "price": "1.099,00",
        "currency": "€",
        "image":
            "https://img.rocket.new/generatedImages/rocket_gen_img_187e57d7a-1767639199419.png",
        "semanticLabel":
            "SC-Project titanium muffler with GP-style design and carbon end cap",
        "condition": "Neu",
      },
      {
        "id": 4,
        "title": "Arrow Komplettanlage",
        "price": "1.450,00",
        "currency": "€",
        "image":
            "https://img.rocket.new/generatedImages/rocket_gen_img_18aca5614-1767639200825.png",
        "semanticLabel":
            "Arrow full exhaust system with racing headers and titanium muffler",
        "condition": "Neuwertig",
      },
    ],
  };

  void _toggleSave() {
    setState(() {
      _isSaved = !_isSaved;
    });
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved ? 'Zur Wunschliste hinzugefügt' : 'Von Wunschliste entfernt',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareProduct() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teilen-Funktion wird geöffnet...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sendMessage() {
    HapticFeedback.lightImpact();
    _showMessageBottomSheet();
  }

  void _buyNow() {
    HapticFeedback.lightImpact();
    _showPurchaseBottomSheet();
  }

  void _showMessageBottomSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 70.h,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.secondary,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: CustomImageWidget(
                        imageUrl: productData["seller"]["avatar"],
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        semanticLabel: productData["seller"]["semanticLabel"],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productData["seller"]["name"],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Antwortet normalerweise in ${productData["seller"]["responseTime"]}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: CustomIconWidget(
                      iconName: 'close',
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CustomImageWidget(
                            imageUrl: (productData["images"] as List)[0]["url"],
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            semanticLabel:
                                (productData["images"]
                                    as List)[0]["semanticLabel"],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productData["title"],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${productData["currency"]} ${productData["price"]}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Hallo, ich interessiere mich für Ihre ${productData["title"]}. Ist der Artikel noch verfügbar?',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Ihre Nachricht...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nachricht gesendet!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text('Nachricht senden'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseBottomSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 60.h,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sichere Zahlung',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: CustomIconWidget(
                      iconName: 'close',
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'verified_user',
                          color: theme.colorScheme.secondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Käuferschutz durch Treuhand-Service',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPurchaseInfoRow(
                    theme,
                    'Artikelpreis',
                    '${productData["currency"]} ${productData["price"]}',
                  ),
                  const SizedBox(height: 12),
                  _buildPurchaseInfoRow(
                    theme,
                    'Versandkosten',
                    '${productData["currency"]} 9,90',
                  ),
                  const SizedBox(height: 12),
                  _buildPurchaseInfoRow(
                    theme,
                    'Treuhand-Gebühr',
                    '${productData["currency"]} 19,90',
                  ),
                  Divider(
                    height: 32,
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  _buildPurchaseInfoRow(
                    theme,
                    'Gesamt',
                    '${productData["currency"]} 1.328,80',
                    isTotal: true,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Zahlungsmethode wählen',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(theme, 'PayPal', 'paypal'),
                  const SizedBox(height: 8),
                  _buildPaymentOption(theme, 'Kreditkarte', 'credit_card'),
                  const SizedBox(height: 8),
                  _buildPaymentOption(
                    theme,
                    'SEPA-Lastschrift',
                    'account_balance',
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Zahlung wird verarbeitet...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successLight,
                    ),
                    child: const Text('Jetzt kaufen'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseInfoRow(
    ThemeData theme,
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: isTotal ? 18 : 14,
            color: isTotal ? theme.colorScheme.secondary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(ThemeData theme, String label, String iconName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CustomIconWidget(
            iconName: iconName,
            color: theme.colorScheme.onSurfaceVariant,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          CustomIconWidget(
            iconName: 'chevron_right',
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _reportProduct() {
    HapticFeedback.lightImpact();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Artikel melden'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Warum möchten Sie diesen Artikel melden?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildReportOption(theme, 'Verdächtiger Inhalt'),
            _buildReportOption(theme, 'Falsche Produktinformationen'),
            _buildReportOption(theme, 'Betrug oder Spam'),
            _buildReportOption(theme, 'Unangemessene Bilder'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(ThemeData theme, String label) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meldung wurde gesendet. Vielen Dank!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(label, style: theme.textTheme.bodyMedium),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: CustomAppBar(
        variant: AppBarVariant.standard,
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: CustomIconWidget(
              iconName: _isSaved ? 'favorite' : 'favorite_border',
              color: _isSaved
                  ? AppTheme.errorLight
                  : theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            onPressed: _toggleSave,
            tooltip: 'Zur Wunschliste hinzufügen',
          ),
          IconButton(
            icon: CustomIconWidget(
              iconName: 'share',
              color: theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            onPressed: _shareProduct,
            tooltip: 'Teilen',
          ),
          PopupMenuButton<String>(
            icon: CustomIconWidget(
              iconName: 'more_vert',
              color: theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            onSelected: (value) {
              if (value == 'report') {
                _reportProduct();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Text('Artikel melden'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ImageGalleryWidget(
                  images: productData["images"] as List<Map<String, dynamic>>,
                ),
                const SizedBox(height: 16),
                ProductInfoCardWidget(
                  title: productData["title"],
                  price: productData["price"],
                  currency: productData["currency"],
                  condition: productData["condition"],
                  description: productData["description"],
                  specifications:
                      productData["specifications"]
                          as List<Map<String, dynamic>>,
                  isDescriptionExpanded: _isDescriptionExpanded,
                  onToggleDescription: () {
                    setState(() {
                      _isDescriptionExpanded = !_isDescriptionExpanded;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (productData["compatibility"]["compatible"] == true)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.successLight.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'check_circle',
                          color: AppTheme.successLight,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kompatibel mit Ihrem ${(productData["compatibility"]["userBikes"] as List)[0]}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.successLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                SellerSectionWidget(
                  seller: productData["seller"] as Map<String, dynamic>,
                ),
                const SizedBox(height: 16),
                ReviewsSectionWidget(
                  reviews: productData["reviews"] as List<Map<String, dynamic>>,
                ),
                const SizedBox(height: 16),
                RelatedProductsWidget(
                  products:
                      productData["relatedProducts"]
                          as List<Map<String, dynamic>>,
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ActionButtonsWidget(
              onSendMessage: _sendMessage,
              onBuyNow: _buyNow,
            ),
          ),
        ],
      ),
    );
  }
}
