class LocationCoords {
  const LocationCoords({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

bool isValidCoord(double lat, double lng) {
  if (!lat.isFinite || !lng.isFinite) return false;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
  if (lat == 0 && lng == 0) return false;
  return true;
}

LocationCoords? _pairFromMatch(RegExpMatch? m) {
  if (m == null) return null;
  final lat = double.tryParse(m.group(1)!);
  final lng = double.tryParse(m.group(2)!);
  if (lat == null || lng == null || !isValidCoord(lat, lng)) return null;
  return LocationCoords(lat: lat, lng: lng);
}

final _coordPatterns = <RegExp>[
  RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)', caseSensitive: false),
  RegExp(r'[?&]q=(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)', caseSensitive: false),
  RegExp(r'[?&]ll=(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)', caseSensitive: false),
  RegExp(r'@(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)'),
  RegExp(r'^(-?\d+(?:\.\d+)?)\s*[,;\s]\s*(-?\d+(?:\.\d+)?)$'),
];

LocationCoords? parseCoordsFromLocationInput(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;
  for (final re in _coordPatterns) {
    final coords = _pairFromMatch(re.firstMatch(raw));
    if (coords != null) return coords;
  }
  return null;
}

bool isShortGoogleMapsUrl(String input) {
  try {
    final u = Uri.parse(input.trim());
    final host = u.host.toLowerCase();
    return host == 'maps.app.goo.gl' ||
        host == 'goo.gl' ||
        host == 'g.co' ||
        (host.endsWith('.goo.gl') && u.path.length > 1);
  } catch (_) {
    return false;
  }
}

bool looksLikeMapUrl(String input) {
  final raw = input.trim();
  return RegExp(r'^https?://', caseSensitive: false).hasMatch(raw) &&
      RegExp(r'google\.|goo\.gl|g\.co', caseSensitive: false).hasMatch(raw);
}

bool isGoogleMapsLink(String input) =>
    isShortGoogleMapsUrl(input) || looksLikeMapUrl(input);
