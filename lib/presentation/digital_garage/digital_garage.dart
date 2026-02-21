import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/add_bike_bottom_sheet.dart';
import './widgets/bike_detail_screen.dart';
import './widgets/empty_garage_widget.dart';
import './widgets/motorcycle_card_widget.dart';

class DigitalGarage extends StatefulWidget {
  const DigitalGarage({super.key});

  @override
  State<DigitalGarage> createState() => _DigitalGarageState();
}

class _DigitalGarageState extends State<DigitalGarage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _primaryBikeId;

  // Mock motorcycle data
  final List<Map<String, dynamic>> _motorcycles = [
    {
      "id": 1,
      "make": "Ducati",
      "model": "Panigale V4",
      "year": 2023,
      "imageUrl":
          "https://images.unsplash.com/photo-1680058945189-3f58daf67d28",
      "semanticLabel":
          "Red Ducati Panigale V4 sportbike parked on asphalt with black background",
      "modificationCount": 8,
      "isPrimary": true,
      "category": "Sport",
      "modifications": [
        {
          "title": "Akrapovic Vollanlage",
          "date": "2024-12-15",
          "cost": "3.200,00 €",
          "description":
              "Komplette Akrapovic Racing Auspuffanlage mit ECU-Mapping",
          "beforeImage":
              "https://img.rocket.new/generatedImages/rocket_gen_img_183e634df-1767639203437.png",
          "beforeSemanticLabel": "Stock Ducati exhaust system",
          "afterImage":
              "https://img.rocket.new/generatedImages/rocket_gen_img_154e592f9-1765464643197.png",
          "afterSemanticLabel": "Akrapovic titanium exhaust system installed",
        },
        {
          "title": "Carbon Verkleidung",
          "date": "2024-11-20",
          "cost": "1.800,00 €",
          "description": "Komplette Carbon-Verkleidung von Carbonin",
          "beforeImage":
              "https://images.unsplash.com/photo-1725434656837-8ca655bd4533",
          "beforeSemanticLabel": "Stock plastic fairings",
          "afterImage":
              "https://img.rocket.new/generatedImages/rocket_gen_img_112353d6c-1767639198261.png",
          "afterSemanticLabel": "Carbon fiber fairings installed",
        },
      ],
      "specifications": {
        "Hubraum": "1.103 ccm",
        "Leistung": "214 PS",
        "Drehmoment": "124 Nm",
        "Gewicht": "195 kg",
        "Baujahr": "2023",
      },
      "wishlist": [
        {
          "part": "Brembo GP4-RX Bremsen",
          "priority": "Hoch",
          "estimatedCost": "2.500,00 €",
        },
        {
          "part": "Öhlins TTX36 Federbein",
          "priority": "Mittel",
          "estimatedCost": "1.800,00 €",
        },
      ],
    },
    {
      "id": 2,
      "make": "BMW",
      "model": "S 1000 RR",
      "year": 2022,
      "imageUrl":
          "https://images.unsplash.com/photo-1648088108877-90fded8b0949",
      "semanticLabel": "Blue and white BMW S1000RR sportbike on race track",
      "modificationCount": 5,
      "isPrimary": false,
      "category": "Sport",
      "modifications": [
        {
          "title": "SC-Project Auspuff",
          "date": "2024-10-05",
          "cost": "1.400,00 €",
          "description": "SC-Project S1 Schalldämpfer mit DB-Killer",
          "beforeImage":
              "https://images.unsplash.com/photo-1632169615079-957f8a692eda",
          "beforeSemanticLabel": "Stock BMW exhaust",
          "afterImage":
              "https://images.unsplash.com/photo-1583971407627-99b68eea9e34",
          "afterSemanticLabel": "SC-Project exhaust installed",
        },
      ],
      "specifications": {
        "Hubraum": "999 ccm",
        "Leistung": "207 PS",
        "Drehmoment": "113 Nm",
        "Gewicht": "197 kg",
        "Baujahr": "2022",
      },
      "wishlist": [
        {
          "part": "Carbon Räder",
          "priority": "Niedrig",
          "estimatedCost": "3.200,00 €",
        },
      ],
    },
    {
      "id": 3,
      "make": "Yamaha",
      "model": "MT-09",
      "year": 2021,
      "imageUrl":
          "https://images.unsplash.com/photo-1629801040055-f590b72993df",
      "semanticLabel": "Dark gray Yamaha MT-09 naked bike on urban street",
      "modificationCount": 12,
      "isPrimary": false,
      "category": "Naked",
      "modifications": [
        {
          "title": "Öhlins Fahrwerk",
          "date": "2024-09-12",
          "cost": "2.100,00 €",
          "description": "Komplettes Öhlins Fahrwerk vorne und hinten",
          "beforeImage":
              "https://img.rocket.new/generatedImages/rocket_gen_img_164dd834e-1765107320919.png",
          "beforeSemanticLabel": "Stock suspension",
          "afterImage":
              "https://img.rocket.new/generatedImages/rocket_gen_img_176e75ab8-1767639198946.png",
          "afterSemanticLabel": "Öhlins suspension installed",
        },
      ],
      "specifications": {
        "Hubraum": "889 ccm",
        "Leistung": "119 PS",
        "Drehmoment": "93 Nm",
        "Gewicht": "189 kg",
        "Baujahr": "2021",
      },
      "wishlist": [
        {
          "part": "Quickshifter Pro",
          "priority": "Hoch",
          "estimatedCost": "450,00 €",
        },
      ],
    },
  ];

  List<Map<String, dynamic>> get _filteredMotorcycles {
    if (_searchQuery.isEmpty) {
      return _motorcycles;
    }
    return _motorcycles.where((bike) {
      final makeModel = '${bike["make"]} ${bike["model"]}'.toLowerCase();
      final category = (bike["category"] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();
      return makeModel.contains(query) || category.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _primaryBikeId = _motorcycles.firstWhere(
      (bike) => bike["isPrimary"] == true,
      orElse: () => _motorcycles.first,
    )["id"];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddBikeBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddBikeBottomSheet(
        onBikeAdded: (bikeData) {
          setState(() {
            _motorcycles.add({
              "id": _motorcycles.length + 1,
              "make": bikeData["make"],
              "model": bikeData["model"],
              "year": bikeData["year"],
              "imageUrl": bikeData["imageUrl"],
              "semanticLabel": bikeData["semanticLabel"],
              "modificationCount": 0,
              "isPrimary": false,
              "category": bikeData["category"],
              "modifications": [],
              "specifications": bikeData["specifications"],
              "wishlist": [],
            });
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${bikeData["make"]} ${bikeData["model"]} zur Garage hinzugefügt',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _navigateToBikeDetail(Map<String, dynamic> bike) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BikeDetailScreen(
          bike: bike,
          onBikeUpdated: (updatedBike) {
            setState(() {
              final index = _motorcycles.indexWhere(
                (b) => b["id"] == updatedBike["id"],
              );
              if (index != -1) {
                _motorcycles[index] = updatedBike;
              }
            });
          },
          onBikeDeleted: (bikeId) {
            setState(() {
              _motorcycles.removeWhere((b) => b["id"] == bikeId);
            });
          },
        ),
      ),
    );
  }

  void _setPrimaryBike(int bikeId) {
    HapticFeedback.lightImpact();
    setState(() {
      for (var bike in _motorcycles) {
        bike["isPrimary"] = bike["id"] == bikeId;
      }
      _primaryBikeId = bikeId;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hauptmotorrad aktualisiert'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _archiveBike(int bikeId) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Motorrad archiviert'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Rückgängig', onPressed: () {}),
      ),
    );
  }

  void _deleteBike(int bikeId) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
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
                setState(() {
                  _motorcycles.removeWhere((bike) => bike["id"] == bikeId);
                });
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

  void _shareBike(Map<String, dynamic> bike) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${bike["make"]} ${bike["model"]} teilen'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _duplicateBike(Map<String, dynamic> bike) {
    HapticFeedback.lightImpact();
    setState(() {
      final newBike = Map<String, dynamic>.from(bike);
      newBike["id"] = _motorcycles.length + 1;
      newBike["isPrimary"] = false;
      newBike["model"] = '${bike["model"]} (Kopie)';
      _motorcycles.add(newBike);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Motorrad dupliziert'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        variant: AppBarVariant.standard,
        title: 'Meine Garage',
        centerTitle: false,
        actions: [
          IconButton(
            icon: CustomIconWidget(
              iconName: 'filter_list',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Filter öffnen'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Filter',
          ),
          IconButton(
            icon: CustomIconWidget(
              iconName: 'more_vert',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showGarageMenu();
            },
            tooltip: 'Mehr',
          ),
        ],
      ),
      body: _motorcycles.isEmpty
          ? EmptyGarageWidget(onAddBike: _showAddBikeBottomSheet)
          : Column(
              children: [
                // Search bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  color: theme.colorScheme.surface,
                  child: Container(
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Marke, Modell oder Kategorie suchen...',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(2.w),
                          child: CustomIconWidget(
                            iconName: 'search',
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: CustomIconWidget(
                                  iconName: 'clear',
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 1.5.h,
                        ),
                      ),
                    ),
                  ),
                ),
                // Motorcycle list
                Expanded(
                  child: _filteredMotorcycles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomIconWidget(
                                iconName: 'search_off',
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 64,
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Keine Motorräder gefunden',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                'Versuche einen anderen Suchbegriff',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          itemCount: _filteredMotorcycles.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 2.h),
                          itemBuilder: (context, index) {
                            final bike = _filteredMotorcycles[index];
                            return MotorcycleCardWidget(
                              bike: bike,
                              isPrimary: bike["id"] == _primaryBikeId,
                              onTap: () => _navigateToBikeDetail(bike),
                              onSetPrimary: () => _setPrimaryBike(bike["id"]),
                              onArchive: () => _archiveBike(bike["id"]),
                              onDelete: () => _deleteBike(bike["id"]),
                              onShare: () => _shareBike(bike),
                              onDuplicate: () => _duplicateBike(bike),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBikeBottomSheet,
        icon: CustomIconWidget(
          iconName: 'add',
          color: theme.colorScheme.onSecondary,
          size: 24,
        ),
        label: Text(
          'Motorrad hinzufügen',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSecondary,
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 1,
        onTap: (index) {
          if (index != 1) {
            BottomBarNavigation.navigateToIndex(context, index);
          }
        },
      ),
    );
  }

  void _showGarageMenu() {
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
                  iconName: 'picture_as_pdf',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text(
                  'Garage als PDF exportieren',
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
                  iconName: 'visibility_off',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text(
                  'Datenschutzeinstellungen',
                  style: theme.textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Datenschutzeinstellungen öffnen'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'help_outline',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text('Hilfe & Tipps', style: theme.textTheme.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hilfe öffnen'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              SizedBox(height: 2.h),
            ],
          ),
        );
      },
    );
  }
}
