// ponytail: dart run tool/order_money_selfcheck.dart
import '../lib/utils/order_money.dart';

void main() {
  final lines = [
    {'totalAux': 6.67},
    {'totalAux': 2.2},
    {'totalAux': 5.76},
    {'totalAux': 1.77},
    {'totalAux': 2.98},
    {'totalAux': 1.03},
    {'totalAux': 4.58},
    {'totalAux': 1.2},
    {'totalAux': 3.48},
    {'totalAux': 2.88},
    {'totalAux': 1.96},
    {'totalAux': 0.76},
    {'totalAux': 3.3},
    {'totalAux': 6.24},
  ];
  final sum = sumProductLinesTotalAux(lines);
  if (sum != 44.81) {
    throw StateError('sum expected 44.81 got $sum');
  }

  final fixed = reconcileOrderMoneyFields({
    'productos': lines,
    'delivery_type': 'delivery',
    'shipping_cost': 1.82,
    'costoTotal': 87.31,
    'products_total': 85.49,
    'payment': {'total_paid': 0, 'total_rest': 87.31},
    'payment_type': 'cashea',
    'desglose_montos': {'monto_cashea': 85.49, 'monto_delivery': 1.82},
  });

  if (fixed['products_total'] != 44.81) {
    throw StateError('products_total ${fixed['products_total']}');
  }
  if (fixed['costoTotal'] != 46.63) {
    throw StateError('costoTotal ${fixed['costoTotal']}');
  }
  if ((fixed['payment'] as Map)['total_rest'] != 46.63) {
    throw StateError('total_rest');
  }
  // ignore: avoid_print
  print('order_money_selfcheck ok');
}
