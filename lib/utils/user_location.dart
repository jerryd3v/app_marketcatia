/// Ubicación guardada del usuario (paridad con locationsService web).
class UserLocation {
  const UserLocation({
    required this.id,
    required this.title,
    required this.address,
    this.lat,
    this.lng,
    this.distanceKm,
    this.zone,
    this.mapUrl,
    this.isDefault = false,
    this.deliveryLocation,
  });

  final String id;
  final String title;
  final String address;
  final double? lat;
  final double? lng;
  final double? distanceKm;
  final String? zone;
  final String? mapUrl;
  final bool isDefault;
  final Map<String, dynamic>? deliveryLocation;

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'id': id,
      'title': title,
      'alias': title,
      'label': title,
      'address': address,
      'isDefault': isDefault,
    };
    if (lat != null) m['lat'] = lat;
    if (lng != null) m['lng'] = lng;
    if (distanceKm != null) m['distance'] = distanceKm;
    if (zone != null && zone!.isNotEmpty) m['zone'] = zone;
    if (mapUrl != null) m['mapUrl'] = mapUrl;
    if (deliveryLocation != null) m['delivery_location'] = deliveryLocation;
    return m;
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  factory UserLocation.fromMap(Map raw, {int index = 0}) {
    final lat = _num(raw['lat'] ??
        raw['latitude'] ??
        (raw['coords'] is Map ? raw['coords']['lat'] : null) ??
        (raw['coordinates'] is Map ? raw['coordinates']['lat'] : null) ??
        (raw['delivery_location'] is Map
            ? raw['delivery_location']['latitude']
            : null));
    final lng = _num(raw['lng'] ??
        raw['longitude'] ??
        (raw['coords'] is Map ? raw['coords']['lng'] : null) ??
        (raw['coordinates'] is Map ? raw['coordinates']['lng'] : null) ??
        (raw['delivery_location'] is Map
            ? raw['delivery_location']['longitude']
            : null));
    final dist = _num(raw['distance'] ??
        raw['distance_km'] ??
        raw['distancia'] ??
        (raw['delivery_location'] is Map
            ? raw['delivery_location']['distanceKm']
            : null));
    final title = (raw['title'] ??
            raw['name'] ??
            raw['alias'] ??
            raw['label'] ??
            'Ubicación')
        .toString()
        .trim();
    final address = (raw['address'] ?? raw['direccion'] ?? '').toString();
    final id = (raw['id'] ?? raw['uid'] ?? 'location-$index').toString();
    Map<String, dynamic>? delivery;
    if (lat != null && lng != null) {
      delivery = {
        'latitude': lat,
        'longitude': lng,
        'address': address.isEmpty ? null : address,
        'label': title.isEmpty ? null : title,
        'zone': (raw['zone'] ?? raw['zona'])?.toString(),
        'distanceKm': dist,
        'mapUrl': raw['mapUrl'] ??
            raw['url'] ??
            'https://www.google.com/maps?q=$lat,$lng',
      };
    }
    return UserLocation(
      id: id,
      title: title.isEmpty ? 'Ubicación' : title,
      address: address,
      lat: lat,
      lng: lng,
      distanceKm: dist != null && dist >= 0 ? dist : null,
      zone: (raw['zone'] ?? raw['zona'])?.toString(),
      mapUrl: raw['mapUrl']?.toString() ??
          raw['url']?.toString() ??
          (lat != null && lng != null
              ? 'https://www.google.com/maps?q=$lat,$lng'
              : null),
      isDefault: raw['isDefault'] == true,
      deliveryLocation: delivery,
    );
  }
}

List<UserLocation> parseUserLocations(List<dynamic> raw) {
  final out = <UserLocation>[];
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is! Map) continue;
    final loc = UserLocation.fromMap(Map<String, dynamic>.from(item), index: i);
    if (loc.address.trim().isEmpty && (loc.lat == null || loc.lng == null)) {
      continue;
    }
    out.add(loc);
  }
  return out;
}

UserLocation? pickDefaultLocation(List<UserLocation> locations) {
  if (locations.isEmpty) return null;
  for (final loc in locations) {
    if (loc.isDefault) return loc;
  }
  return locations.first;
}

bool _isPlusCodeOrCoords(String part) {
  final s = part.trim();
  if (s.isEmpty) return true;
  if (RegExp(r'\+[A-Z0-9]+$', caseSensitive: false).hasMatch(s) ||
      RegExp(r'^[A-Z0-9]{2,}\+[A-Z0-9]+$', caseSensitive: false).hasMatch(s)) {
    return true;
  }
  if (RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(s)) return true;
  if (RegExp(r'^-?\d+\.\d+$').hasMatch(s)) return true;
  return false;
}

String extractCity(String address) {
  final parts = address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
  for (final part in parts) {
    if (_isPlusCodeOrCoords(part)) continue;
    final city = part.replaceFirst(RegExp(r'\s+\d{3,}$'), '').trim();
    if (city.isNotEmpty) return city;
  }
  return '';
}

/// Texto de la barra: "Enviar a Casa · Caracas".
String shortLocationLabel(UserLocation? loc, {required bool loggedIn}) {
  if (!loggedIn) return 'Elige tu ubicación';
  if (loc == null) return 'Elige tu ubicación';
  var title = loc.title.trim();
  if (_isGenericTitle(title)) title = '';
  final city = extractCity(loc.address);
  if (title.isNotEmpty && city.isNotEmpty) return 'Enviar a $title · $city';
  if (title.isNotEmpty) return 'Enviar a $title';
  if (city.isNotEmpty) return 'Enviar a $city';
  return 'Elige tu ubicación';
}

bool _isGenericTitle(String title) {
  final t = title.toLowerCase();
  return t == 'mi ubicación' ||
      t == 'ubicacion' ||
      t == 'ubicación' ||
      t == 'ubicación sin nombre' ||
      t == 'sin nombre';
}
