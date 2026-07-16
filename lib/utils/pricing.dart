import '../constants/cart_payment_modality.dart';
import '../models/models.dart';

const double casheaBulkSurchargeRate = 0.05;

double redondear(num value) => (value * 100).round() / 100;

bool presentationIsCasheaBulk(String? presentacion) {
  final p = (presentacion ?? '').trim().toLowerCase();
  return p == 'bulto' || p == 'caja' || p == 'lote';
}

double resolveProductLevelDiscountPercent(List<dynamic> discounts) {
  final arr = discounts;
  final promo = arr.cast<dynamic>().whereType<Map>().cast<Map>().firstWhere(
        (d) =>
            d['name'] == 'Producto' &&
            d['promoCampaignId'] != null &&
            d['percent'] != null,
        orElse: () => {},
      );
  if (promo.isNotEmpty) {
    return (promo['percent'] as num?)?.toDouble() ?? 0;
  }
  final producto = arr.whereType<Map>().cast<Map>().firstWhere(
        (d) => d['name'] == 'Producto' && d['percent'] != null,
        orElse: () => {},
      );
  if (producto.isNotEmpty) {
    return (producto['percent'] as num?)?.toDouble() ?? 0;
  }
  final first = arr.whereType<Map>().cast<Map>().firstWhere(
        (d) => d['percent'] != null,
        orElse: () => {},
      );
  return (first['percent'] as num?)?.toDouble() ?? 0;
}

double getCasheaAdjustedUnitPrice(
  double catalogUnitPrice,
  String? presentationKey,
  bool isCasheaFlow,
) {
  if (!isCasheaFlow || catalogUnitPrice <= 0) return catalogUnitPrice;
  if (!presentationIsCasheaBulk(presentationKey)) return catalogUnitPrice;
  return redondear(catalogUnitPrice * (1 + casheaBulkSurchargeRate));
}

double resolveCartLineCatalogUnitPrice(CartItem item) {
  double fromPresentation = double.nan;
  switch (item.presentacion) {
    case 'Unidad':
      fromPresentation = item.precioUnidad ?? double.nan;
      break;
    case 'Mayor':
      fromPresentation = item.precioMayor ?? double.nan;
      break;
    case 'Bulto':
    case 'Caja':
    case 'Lote':
      fromPresentation = item.precioBulto ?? double.nan;
      break;
  }
  final catalog = item.precioCatalogoPresentacion ??
      item.precioOri;
  if (catalog > 0) return catalog;
  if (fromPresentation.isFinite && fromPresentation > 0) return fromPresentation;
  return item.precio;
}

List<CartItem> applyCasheaBulkSurcharge(List<CartItem> items, bool active) {
  if (!active) return items;
  return items.map((item) {
    if (!presentationIsCasheaBulk(item.presentacion)) return item;
    final catalog = resolveCartLineCatalogUnitPrice(item);
    if (catalog <= 0) return item;
    final newUnit = redondear(catalog * (1 + casheaBulkSurchargeRate));
    return item.copyWith(
      precio: newUnit,
      precioOri: catalog,
      precioCatalogoPresentacion: catalog,
      totalAux: redondear(newUnit * item.cantidad),
      casheaSurchargeApplied: true,
    );
  }).toList();
}

List<CartItem> revertCasheaBulkSurcharge(List<CartItem> items) {
  return items.map((item) {
    if (!presentationIsCasheaBulk(item.presentacion)) return item;
    final catalog = resolveCartLineCatalogUnitPrice(item);
    if (catalog <= 0) {
      return item.copyWith(casheaSurchargeApplied: false);
    }
    final unit = redondear(catalog);
    return item.copyWith(
      precio: unit,
      precioOri: catalog,
      totalAux: redondear(unit * item.cantidad),
      casheaSurchargeApplied: false,
    );
  }).toList();
}

List<CartItem> syncCartLinesWithPaymentModality(
  List<CartItem> items,
  String? paymentModality,
) {
  if (items.isEmpty) return items;
  if (paymentModality == CartPaymentModality.cashea) {
    return applyCasheaBulkSurcharge(items, true);
  }
  return revertCasheaBulkSurcharge(items);
}

bool isStockAllowedForAddToCart(dynamic stock) {
  if (stock == null) return true;
  if (stock is bool) return stock;
  if (stock is num) return stock > 0;
  final s = stock.toString().toLowerCase();
  if (s == 'out' || s == 'agotado' || s == '0' || s == 'false') return false;
  return true;
}

num getPresentationBaseUnits(Product product, String presentacion) {
  switch (presentacion) {
    case 'Mayor':
      return product.cantidadMayor;
    case 'Bulto':
      return product.cantidadBulto;
    default:
      return product.cantidadUnidad;
  }
}

/// Parsea id de temp-order: `uuid&type=CASHEA`
({String id, String? paymentType}) parseTempOrderId(String raw) {
  final parts = raw.split('&');
  final id = parts.first;
  String? type;
  for (final p in parts.skip(1)) {
    final kv = p.split('=');
    if (kv.length == 2 && kv[0] == 'type') {
      final v = kv[1].toUpperCase();
      if (v == 'CASHEA') type = CartPaymentModality.cashea;
      if (v == 'PAGO_MOVIL' || v == 'PAGOMOVIL') {
        type = CartPaymentModality.pagoMovil;
      }
    }
  }
  return (id: id, paymentType: type);
}
