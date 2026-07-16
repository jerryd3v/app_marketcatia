import 'dart:math' as math;

/// Misma lógica que `deliveryCostApi.js` web.
const double deliveryTier1MaxKm = 1;
const double deliveryTier1Cost = 1;
const double deliveryTier2MaxKm = 2.5;
const double deliveryTier2Cost = 2;

class DeliveryCostRates {
  const DeliveryCostRates({
    required this.kilometer,
    required this.amountPremium,
    required this.amountStandard,
  });

  final double kilometer;
  final double amountPremium;
  final double amountStandard;

  static const defaults = DeliveryCostRates(
    kilometer: 1,
    amountPremium: 1,
    amountStandard: 0.5,
  );

  factory DeliveryCostRates.fromApi(Map<String, dynamic> raw) {
    final nested = raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : raw;

    double? numOf(List<String> keys) {
      for (final k in keys) {
        final v = nested[k] ?? raw[k];
        if (v == null || v == '') continue;
        if (v is num) return v.toDouble();
        final p = double.tryParse(v.toString().replaceAll(',', '.'));
        if (p != null) return p;
      }
      return null;
    }

    final km = numOf(['kilometer', 'Kilometer', 'km', 'KM']) ?? 1;
    final premium = numOf([
          'amountPremium',
          'AmountPremium',
          'amount_premium',
        ]) ??
        1;
    final standard = numOf([
          'amountStandard',
          'AmountStandard',
          'amount_standard',
          'amount',
          'Amount',
          'cost',
          'price',
        ]) ??
        0.5;

    return DeliveryCostRates(
      kilometer: km > 0 ? km : 1,
      amountPremium: premium > 0 ? premium : 1,
      amountStandard: standard >= 0 ? standard : 0.5,
    );
  }
}

double calculateDeliveryCost(
  double distanceKm, {
  required double kilometer,
  required double amount,
}) {
  if (!distanceKm.isFinite || distanceKm < 0) return 0;
  if (distanceKm < deliveryTier1MaxKm) return deliveryTier1Cost;
  if (distanceKm <= deliveryTier2MaxKm) return deliveryTier2Cost;
  final kmUnit = kilometer > 0 ? kilometer : 1;
  final raw = (distanceKm / kmUnit) * amount;
  return (raw * 100).round() / 100;
}

/// Distancia en línea recta (fallback si Directions falla).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _rad(double d) => d * math.pi / 180;
