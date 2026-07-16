import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../constants/geo_reference.dart';
import '../services/maps_service.dart';
import '../theme/app_colors.dart';
import '../utils/delivery_cost.dart';

/// Sección Delivery con mapa — paridad con ShoppingCar web.
class DeliveryMapSection extends StatefulWidget {
  const DeliveryMapSection({
    super.key,
    required this.rates,
    required this.onCostChanged,
    this.shippingSubtype = 'standard',
  });

  final DeliveryCostRates rates;
  final void Function({
    required double cost,
    required double? distanceKm,
    LatLng? destination,
    String? address,
    String? locationName,
  }) onCostChanged;
  final String shippingSubtype;

  @override
  State<DeliveryMapSection> createState() => _DeliveryMapSectionState();
}

class _DeliveryMapSectionState extends State<DeliveryMapSection> {
  final _maps = MapsService();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  GoogleMapController? _controller;
  LatLng? _destination;
  Set<Polyline> _polylines = {};
  double? _distanceKm;
  double _cost = 0;
  bool _routing = false;
  String? _routeError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _controller?.dispose();
    super.dispose();
  }

  double get _rateAmount => widget.shippingSubtype == 'alta'
      ? widget.rates.amountPremium
      : widget.rates.amountStandard;

  Future<void> _setDestination(LatLng pos) async {
    setState(() {
      _destination = pos;
      _routing = true;
      _routeError = null;
    });

    final result = await _maps.routeTo(pos);
    if (!mounted) return;

    final cost = calculateDeliveryCost(
      result.distanceKm,
      kilometer: widget.rates.kilometer,
      amount: _rateAmount,
    );

    setState(() {
      _distanceKm = result.distanceKm;
      _cost = cost;
      _routing = false;
      _addressCtrl.text = result.address ??
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      _polylines = result.polylinePoints.length >= 2
          ? {
              Polyline(
                polylineId: const PolylineId('route'),
                points: result.polylinePoints,
                color: AppColors.primary,
                width: 4,
              ),
            }
          : {};
    });

    widget.onCostChanged(
      cost: cost,
      distanceKm: result.distanceKm,
      destination: pos,
      address: _addressCtrl.text,
      locationName: _nameCtrl.text.trim(),
    );

    if (result.polylinePoints.length >= 2) {
      await _fitBounds([catiaReferenceLocation, pos, ...result.polylinePoints]);
    } else {
      await _controller?.animateCamera(CameraUpdate.newLatLng(pos));
    }
  }

  Future<void> _fitBounds(List<LatLng> points) async {
    if (_controller == null || points.isEmpty) return;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
    }
    await _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        48,
      ),
    );
  }

  Future<void> _useGps() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => _routeError = 'Activa el GPS del dispositivo.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _routeError = 'Permiso de ubicación denegado.');
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _setDestination(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      if (mounted) {
        setState(() => _routeError = 'No se pudo obtener la ubicación GPS.');
      }
    }
  }

  Set<Marker> get _markers {
    final markers = <Marker>{
      const Marker(
        markerId: MarkerId('store'),
        position: catiaReferenceLocation,
        infoWindow: InfoWindow(title: 'Punto de partida (tienda)'),
      ),
    };
    if (_destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dest'),
          position: _destination!,
          draggable: true,
          infoWindow: const InfoWindow(title: 'Punto de destino'),
          onDragEnd: _setDestination,
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Toca el mapa para marcar tu dirección de entrega',
          style: TextStyle(fontSize: 13, color: AppColors.textLight),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 364, // ponytail: 280 * 1.3
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: catiaReferenceLocation,
                    zoom: 13,
                  ),
                  onMapCreated: (c) => _controller = c,
                  onTap: _setDestination,
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                ),
                if (_routing)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55FFFFFF),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_routeError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.discountBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _routeError!,
              style: const TextStyle(color: AppColors.discount, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre de la ubicación',
            hintText: 'Ej: Casa, Oficina, Depósito',
          ),
          onChanged: (_) => widget.onCostChanged(
            cost: _cost,
            distanceKm: _distanceKm,
            destination: _destination,
            address: _addressCtrl.text,
            locationName: _nameCtrl.text.trim(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _addressCtrl,
          readOnly: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Dirección',
            hintText: 'Selecciona un punto en el mapa',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _routing ? null : _useGps,
          icon: const Icon(Icons.my_location),
          label: const Text('Usar GPS'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
        if (_distanceKm != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Distancia',
                        style: TextStyle(color: AppColors.textMedium)),
                    Text(
                      '${_distanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Costo de envío',
                        style: TextStyle(color: AppColors.textMedium)),
                    Text(
                      _fmt.format(_cost),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
