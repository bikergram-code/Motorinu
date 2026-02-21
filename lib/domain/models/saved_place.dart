import 'dart:convert';

/// Ein gespeicherter Ort (Zuhause, Arbeit, oder benutzerdefiniert).
class SavedPlace {
  final String id; // 'home', 'work', oder UUID
  final String name; // 'Zuhause', 'Arbeit', oder Custom-Name
  final String? address;
  final double lat;
  final double lng;
  final String icon; // 'home', 'work', 'star'

  const SavedPlace({
    required this.id,
    required this.name,
    this.address,
    required this.lat,
    required this.lng,
    this.icon = 'star',
  });

  SavedPlace copyWith({
    String? name,
    String? address,
    double? lat,
    double? lng,
    String? icon,
  }) {
    return SavedPlace(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'lat': lat,
    'lng': lng,
    'icon': icon,
  };

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String?,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    icon: json['icon'] as String? ?? 'star',
  );

  String encode() => jsonEncode(toJson());
  static SavedPlace decode(String source) =>
      SavedPlace.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
