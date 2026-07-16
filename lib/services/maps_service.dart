import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../constants/geo_reference.dart';
import '../utils/delivery_cost.dart';

class MapsRouteResult {
  const MapsRouteResult({
    required this.distanceKm,
    this.polylinePoints = const [],
    this.address,
  });

  final double distanceKm;
  final List<LatLng> polylinePoints;
  final String? address;
}

class MapsService {
  Future<MapsRouteResult> routeTo(LatLng destination) async {
    final origin = catiaReferenceLocation;
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': ApiConfig.googleMapsApiKey,
      },
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode >= 400) {
        return _fallback(destination);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        return _fallback(destination, address: await reverseGeocode(destination));
      }
      final routes = data['routes'] as List? ?? [];
      if (routes.isEmpty) {
        return _fallback(destination, address: await reverseGeocode(destination));
      }
      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List? ?? [];
      var meters = 0;
      for (final leg in legs) {
        if (leg is Map) {
          meters += (leg['distance']?['value'] as num?)?.toInt() ?? 0;
        }
      }
      final points = _decodePolyline(
        (route['overview_polyline'] as Map?)?['points']?.toString() ?? '',
      );
      final addr = await reverseGeocode(destination);
      return MapsRouteResult(
        distanceKm: meters / 1000,
        polylinePoints: points,
        address: addr,
      );
    } catch (_) {
      return _fallback(destination);
    }
  }

  Future<String?> reverseGeocode(LatLng pos) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${pos.latitude},${pos.longitude}',
        'key': ApiConfig.googleMapsApiKey,
        'language': 'es',
      },
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode >= 400) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final results = data['results'] as List? ?? [];
      if (results.isEmpty) return null;
      return (results.first as Map)['formatted_address']?.toString();
    } catch (_) {
      return null;
    }
  }

  MapsRouteResult _fallback(LatLng destination, {String? address}) {
    final origin = catiaReferenceLocation;
    final km = haversineKm(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    return MapsRouteResult(
      distanceKm: km,
      address: address ??
          '${destination.latitude.toStringAsFixed(5)}, ${destination.longitude.toStringAsFixed(5)}',
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return const [];
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
