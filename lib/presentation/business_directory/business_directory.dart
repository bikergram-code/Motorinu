import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/business_card_widget.dart';
import './widgets/business_detail_modal_widget.dart';
import './widgets/category_filter_chip_widget.dart';
import './widgets/filter_modal_widget.dart';

class BusinessDirectory extends StatefulWidget {
  const BusinessDirectory({super.key});

  @override
  State<BusinessDirectory> createState() => _BusinessDirectoryState();
}

class _BusinessDirectoryState extends State<BusinessDirectory> {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  bool _isMapView = false;
  String _selectedRadius = '10km';
  String? _selectedCategory;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  final Set<Marker> _markers = {};

  // Filter state
  double _minRating = 0.0;
  bool _showOpenOnly = false;
  String? _priceRange;
  List<String> _selectedServices = [];

  final List<Map<String, dynamic>> _mockBusinesses = [
    {
      "id": 1,
      "name": "Motorrad Werkstatt Schmidt",
      "category": "Werkstätten",
      "rating": 4.8,
      "reviewCount": 127,
      "distance": 2.3,
      "address": "Hauptstraße 45, 10115 Berlin",
      "phone": "+49 30 12345678",
      "isOpen": true,
      "isFeatured": true,
      "specializations": ["BMW", "Ducati", "Wartung"],
      "priceRange": "\$\$",
      "image":
          "https://img.rocket.new/generatedImages/rocket_gen_img_1b6668292-1766727726586.png",
      "semanticLabel":
          "Modern motorcycle workshop interior with bikes on lifts and tools on walls",
      "latitude": 52.5200,
      "longitude": 13.4050,
      "description":
          "Spezialisiert auf BMW und Ducati Motorräder. Vollständiger Service und Reparaturen.",
      "services": ["Wartung", "Reparatur", "Tuning", "Inspektion"],
      "openingHours": "Mo-Fr: 08:00-18:00, Sa: 09:00-14:00",
      "hasDeals": true,
      "dealText": "10% Rabatt auf Winterservice",
    },
    {
      "id": 2,
      "name": "Bike Paradise Händler",
      "category": "Händler",
      "rating": 4.6,
      "reviewCount": 89,
      "distance": 5.7,
      "address": "Berliner Allee 123, 10178 Berlin",
      "phone": "+49 30 87654321",
      "isOpen": true,
      "isFeatured": false,
      "specializations": ["Yamaha", "Kawasaki", "Neufahrzeuge"],
      "priceRange": "\$\$\$",
      "image":
          "https://images.unsplash.com/photo-1686869571548-8139ea62803d",
      "semanticLabel":
          "Motorcycle dealership showroom with multiple sport bikes on display",
      "latitude": 52.5300,
      "longitude": 13.4150,
      "description":
          "Offizieller Yamaha und Kawasaki Händler mit großer Auswahl an Neufahrzeugen.",
      "services": ["Verkauf", "Finanzierung", "Inzahlungnahme", "Beratung"],
      "openingHours": "Mo-Fr: 09:00-19:00, Sa: 10:00-16:00",
      "hasDeals": false,
      "dealText": null,
    },
    {
      "id": 3,
      "name": "Biker's Rest Hotel",
      "category": "Hotels",
      "rating": 4.9,
      "reviewCount": 234,
      "distance": 8.2,
      "address": "Landstraße 67, 10179 Berlin",
      "phone": "+49 30 11223344",
      "isOpen": true,
      "isFeatured": true,
      "specializations": ["Motorradfreundlich", "Garage", "Touren"],
      "priceRange": "\$\$",
      "image":
          "https://images.unsplash.com/photo-1643374902579-61fbbb5d2404",
      "semanticLabel":
          "Cozy hotel exterior with motorcycle parking area and mountain backdrop",
      "latitude": 52.5100,
      "longitude": 13.4250,
      "description":
          "Motorradfreundliches Hotel mit sicherer Garage und Tourenberatung.",
      "services": ["Übernachtung", "Garage", "Tourenplanung", "Werkstatt"],
      "openingHours": "24/7 Rezeption",
      "hasDeals": true,
      "dealText": "Kostenlose Garage bei 2+ Nächten",
    },
    {
      "id": 4,
      "name": "Track Day Events Berlin",
      "category": "Events",
      "rating": 4.7,
      "reviewCount": 156,
      "distance": 12.5,
      "address": "Rennstrecke 1, 10180 Berlin",
      "phone": "+49 30 99887766",
      "isOpen": false,
      "isFeatured": false,
      "specializations": ["Trackdays", "Training", "Rennstrecke"],
      "priceRange": "\$\$\$",
      "image":
          "https://images.unsplash.com/photo-1686633663306-de94fccb9f27",
      "semanticLabel":
          "Racing motorcycles lined up on track with riders in full gear",
      "latitude": 52.5400,
      "longitude": 13.4350,
      "description":
          "Organisiert Trackdays und Fahrertraining auf professionellen Rennstrecken.",
      "services": ["Trackdays", "Training", "Zeitnahme", "Coaching"],
      "openingHours": "Event-basiert",
      "hasDeals": false,
      "dealText": null,
    },
    {
      "id": 5,
      "name": "Fahrschule Motorrad Pro",
      "category": "Fahrschulen",
      "rating": 4.5,
      "reviewCount": 78,
      "distance": 3.8,
      "address": "Schulstraße 89, 10115 Berlin",
      "phone": "+49 30 55667788",
      "isOpen": true,
      "isFeatured": false,
      "specializations": ["A-Führerschein", "Auffrischung", "Sicherheit"],
      "priceRange": "\$\$",
      "image":
          "https://img.rocket.new/generatedImages/rocket_gen_img_1c6845ffa-1766775741769.png",
      "semanticLabel":
          "Motorcycle training session with instructor and student on practice bikes",
      "latitude": 52.5250,
      "longitude": 13.4100,
      "description":
          "Professionelle Motorrad-Fahrschule für alle Führerscheinklassen.",
      "services": [
        "A1-Führerschein",
        "A2-Führerschein",
        "A-Führerschein",
        "Auffrischung",
      ],
      "openingHours": "Mo-Sa: 08:00-20:00",
      "hasDeals": true,
      "dealText": "Erste Fahrstunde gratis",
    },
    {
      "id": 6,
      "name": "Custom Bikes Tuning",
      "category": "Werkstätten",
      "rating": 4.9,
      "reviewCount": 201,
      "distance": 6.4,
      "address": "Industrieweg 34, 10178 Berlin",
      "phone": "+49 30 44556677",
      "isOpen": true,
      "isFeatured": true,
      "specializations": ["Custom", "Tuning", "Lackierung"],
      "priceRange": "\$\$\$",
      "image":
          "https://images.unsplash.com/photo-1627472559871-e694c371ac82",
      "semanticLabel":
          "Custom motorcycle workshop with partially assembled chopper and paint booth",
      "latitude": 52.5350,
      "longitude": 13.4200,
      "description":
          "Spezialist für Custom Bikes, Tuning und individuelle Lackierungen.",
      "services": ["Custom Build", "Tuning", "Lackierung", "Umbau"],
      "openingHours": "Mo-Fr: 09:00-18:00",
      "hasDeals": false,
      "dealText": null,
    },
  ];

  final List<Map<String, dynamic>> _categories = [
    {"name": "Werkstätten", "icon": "build", "count": 45},
    {"name": "Händler", "icon": "store", "count": 23},
    {"name": "Hotels", "icon": "hotel", "count": 18},
    {"name": "Events", "icon": "event", "count": 12},
    {"name": "Fahrschulen", "icon": "school", "count": 8},
  ];

  final List<String> _radiusOptions = ['5km', '10km', '25km', '50km'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
      _updateMarkers();
    } catch (e) {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _updateMarkers() {
    _markers.clear();
    for (var business in _getFilteredBusinesses()) {
      _markers.add(
        Marker(
          markerId: MarkerId(business["id"].toString()),
          position: LatLng(
            business["latitude"] as double,
            business["longitude"] as double,
          ),
          infoWindow: InfoWindow(
            title: business["name"] as String,
            snippet: "${business["rating"]} ⭐ • ${business["distance"]}km",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            business["isFeatured"] == true
                ? BitmapDescriptor.hueOrange
                : BitmapDescriptor.hueRed,
          ),
          onTap: () => _showBusinessDetail(business),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredBusinesses() {
    var filtered = _mockBusinesses.where((business) {
      // Category filter
      if (_selectedCategory != null &&
          business["category"] != _selectedCategory) {
        return false;
      }

      // Search filter
      if (_searchController.text.isNotEmpty) {
        final searchLower = _searchController.text.toLowerCase();
        final nameLower = (business["name"] as String).toLowerCase();
        final specializationsLower = (business["specializations"] as List)
            .map((s) => s.toString().toLowerCase())
            .join(" ");
        if (!nameLower.contains(searchLower) &&
            !specializationsLower.contains(searchLower)) {
          return false;
        }
      }

      // Rating filter
      if ((business["rating"] as double) < _minRating) {
        return false;
      }

      // Open only filter
      if (_showOpenOnly && business["isOpen"] != true) {
        return false;
      }

      // Price range filter
      if (_priceRange != null && business["priceRange"] != _priceRange) {
        return false;
      }

      // Services filter
      if (_selectedServices.isNotEmpty) {
        final businessServices = business["services"] as List;
        if (!_selectedServices.any(
          (service) => businessServices.contains(service),
        )) {
          return false;
        }
      }

      // Radius filter
      final radiusKm = double.parse(_selectedRadius.replaceAll('km', ''));
      if ((business["distance"] as double) > radiusKm) {
        return false;
      }

      return true;
    }).toList();

    // Sort: Featured first, then by distance
    filtered.sort((a, b) {
      if (a["isFeatured"] == true && b["isFeatured"] != true) return -1;
      if (a["isFeatured"] != true && b["isFeatured"] == true) return 1;
      return (a["distance"] as double).compareTo(b["distance"] as double);
    });

    return filtered;
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterModalWidget(
        minRating: _minRating,
        showOpenOnly: _showOpenOnly,
        priceRange: _priceRange,
        selectedServices: _selectedServices,
        onApply: (rating, openOnly, priceRange, services) {
          setState(() {
            _minRating = rating;
            _showOpenOnly = openOnly;
            _priceRange = priceRange;
            _selectedServices = services;
          });
          if (_isMapView) _updateMarkers();
        },
      ),
    );
  }

  void _showBusinessDetail(Map<String, dynamic> business) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BusinessDetailModalWidget(business: business),
    );
  }

  void _makePhoneCall(String phone) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Anrufen: $phone'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openNavigation(Map<String, dynamic> business) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation zu ${business["name"]}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveBusiness(Map<String, dynamic> business) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${business["name"]} gespeichert'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareBusiness(Map<String, dynamic> business) {
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        variant: AppBarVariant.search,
        searchHint: 'Suche nach Werkstätten, Händlern...',
        onSearchChanged: (value) {
          setState(() {});
          if (_isMapView) _updateMarkers();
        },
        actions: [
          IconButton(
            icon: CustomIconWidget(
              iconName: _isMapView ? 'list' : 'map',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isMapView = !_isMapView;
                if (_isMapView) _updateMarkers();
              });
            },
            tooltip: _isMapView ? 'Listenansicht' : 'Kartenansicht',
          ),
          IconButton(
            icon: CustomIconWidget(
              iconName: 'tune',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: _showFilterModal,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLocationHeader(theme),
          _buildCategoryFilters(theme),
          Expanded(
            child: _isMapView ? _buildMapView(theme) : _buildListView(theme),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 3,
        onTap: (index) {
          if (index != 3) {
            BottomBarNavigation.navigateToIndex(context, index);
          }
        },
      ),
    );
  }

  Widget _buildLocationHeader(ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          CustomIconWidget(
            iconName: 'location_on',
            color: theme.colorScheme.secondary,
            size: 20,
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoadingLocation
                      ? 'Standort wird geladen...'
                      : 'Berlin, Deutschland',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Umkreis: $_selectedRadius',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: CustomIconWidget(
              iconName: 'expand_more',
              color: theme.colorScheme.onSurface,
              size: 20,
            ),
            onSelected: (value) {
              setState(() {
                _selectedRadius = value;
              });
              if (_isMapView) _updateMarkers();
            },
            itemBuilder: (context) => _radiusOptions.map((radius) {
              return PopupMenuItem<String>(
                value: radius,
                child: Row(
                  children: [
                    if (radius == _selectedRadius)
                      CustomIconWidget(
                        iconName: 'check',
                        color: theme.colorScheme.secondary,
                        size: 20,
                      ),
                    if (radius == _selectedRadius) SizedBox(width: 2.w),
                    Text(radius),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(ThemeData theme) {
    return Container(
      height: 8.h,
      padding: EdgeInsets.symmetric(vertical: 1.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        itemCount: _categories.length,
        separatorBuilder: (context, index) => SizedBox(width: 2.w),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return CategoryFilterChipWidget(
            category: category,
            isSelected: _selectedCategory == category["name"],
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedCategory = _selectedCategory == category["name"]
                    ? null
                    : category["name"] as String;
              });
              if (_isMapView) _updateMarkers();
            },
          );
        },
      ),
    );
  }

  Widget _buildListView(ThemeData theme) {
    final filteredBusinesses = _getFilteredBusinesses();

    if (filteredBusinesses.isEmpty) {
      return Center(
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
              'Keine Ergebnisse gefunden',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Versuche andere Filter oder Suchbegriffe',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      itemCount: filteredBusinesses.length,
      separatorBuilder: (context, index) => SizedBox(height: 1.h),
      itemBuilder: (context, index) {
        final business = filteredBusinesses[index];
        return Slidable(
          key: ValueKey(business["id"]),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (context) =>
                    _makePhoneCall(business["phone"] as String),
                backgroundColor: theme.colorScheme.tertiary,
                foregroundColor: theme.colorScheme.onTertiary,
                icon: Icons.phone,
                label: 'Anrufen',
              ),
              SlidableAction(
                onPressed: (context) => _openNavigation(business),
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                icon: Icons.navigation,
                label: 'Route',
              ),
              SlidableAction(
                onPressed: (context) => _saveBusiness(business),
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                icon: Icons.bookmark,
                label: 'Speichern',
              ),
              SlidableAction(
                onPressed: (context) => _shareBusiness(business),
                backgroundColor: theme.colorScheme.tertiaryContainer,
                foregroundColor: theme.colorScheme.onTertiaryContainer,
                icon: Icons.share,
                label: 'Teilen',
              ),
            ],
          ),
          child: BusinessCardWidget(
            business: business,
            onTap: () => _showBusinessDetail(business),
          ),
        );
      },
    );
  }

  Widget _buildMapView(ThemeData theme) {
    if (_currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.secondary),
            SizedBox(height: 2.h),
            Text(
              'Karte wird geladen...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 12,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _mapController = controller;
      },
    );
  }
}
