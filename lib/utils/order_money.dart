/// Totales de orden desde líneas (`totalAux`) + envío.
/// Evita desfase si el payload trae `costoTotal`/`products_total` inflados.
double redondearOrderMoney(num value) => (value * 100).round() / 100;

double sumProductLinesTotalAux(Iterable<dynamic> lines) {
  var sum = 0.0;
  for (final raw in lines) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    if (m['return'] == true) continue;
    final ta = m['totalAux'];
    if (ta is num) sum += ta.toDouble();
  }
  return redondearOrderMoney(sum);
}

/// Reescribe products_total / shipping_cost / costoTotal desde las líneas.
Map<String, dynamic> reconcileOrderMoneyFields(Map<String, dynamic> payload) {
  final out = Map<String, dynamic>.from(payload);
  final lines = (out['productos'] as List?) ?? (out['items'] as List?) ?? const [];
  final productsTotal = sumProductLinesTotalAux(lines);

  final deliveryType =
      (out['delivery_type'] ?? out['deliveryType'] ?? '').toString().toLowerCase().trim();
  final isDelivery = deliveryType == 'delivery';
  final shippingRaw = (out['shipping_cost'] as num?)?.toDouble() ??
      (out['deliveryCost'] as num?)?.toDouble() ??
      0.0;
  final shipping = isDelivery && shippingRaw > 0 ? redondearOrderMoney(shippingRaw) : 0.0;
  final total = redondearOrderMoney(productsTotal + shipping);

  out['products_total'] = productsTotal;
  out['shipping_cost'] = shipping;
  out['costoTotal'] = total;
  out['subtotal'] = productsTotal;
  out['total'] = total;
  out['deliveryCost'] = shipping;

  final paymentRaw = out['payment'];
  if (paymentRaw is Map) {
    final payment = Map<String, dynamic>.from(paymentRaw);
    final paid = (payment['total_paid'] as num?)?.toDouble() ?? 0.0;
    payment['total_rest'] = redondearOrderMoney(total - paid);
    out['payment'] = payment;
  }

  final desgloseRaw = out['desglose_montos'];
  if (desgloseRaw is Map) {
    final desglose = Map<String, dynamic>.from(desgloseRaw);
    final paymentType =
        (out['payment_type'] ?? out['paymentModality'] ?? '').toString().toLowerCase();
    if (paymentType == 'cashea') {
      desglose['monto_cashea'] = productsTotal;
    }
    if (shipping > 0) {
      desglose['monto_delivery'] = shipping;
    } else {
      desglose.remove('monto_delivery');
    }
    out['desglose_montos'] = desglose;
  }

  return out;
}
