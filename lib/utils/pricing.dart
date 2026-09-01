import '../constants/cart_payment_modality.dart';
import '../models/models.dart';
import 'caracas_date.dart';

const double casheaBulkSurchargeRate = 0.05;

double redondear(num value) => (value * 100).round() / 100;

bool presentationIsCasheaBulk(String? presentacion) {
  final p = (presentacion ?? '').trim().toLowerCase();
  return p == 'bulto' || p == 'caja' || p == 'lote';
}

bool _isDiscountLive(Map d, [String? dateStr]) {
  final start = d['promoStartDate']?.toString().trim() ?? '';
  final end = d['promoEndDate']?.toString().trim() ?? '';
  if (start.isNotEmpty && end.isNotEmpty) {
    return isDateInCaracasRange(start, end, dateStr ?? caracasDateString());
  }
  return true;
}

double resolveProductLevelDiscountPercent(
  List<dynamic> discounts, [
  String? dateStr,
]) {
  final arr = discounts
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  final today = dateStr ?? caracasDateString();
  for (final d in arr) {
    if (d['name'] == 'Producto' &&
        d['promoCampaignId'] != null &&
        d['percent'] != null &&
        _isDiscountLive(d, today)) {
      return (d['percent'] as num?)?.toDouble() ?? 0;
    }
  }
  for (final d in arr) {
    if (d['name'] == 'Producto' &&
        d['promoCampaignId'] == null &&
        d['percent'] != null) {
      return (d['percent'] as num?)?.toDouble() ?? 0;
    }
  }
  for (final d in arr) {
    if (d['percent'] != null && d['promoCampaignId'] == null) {
      return (d['percent'] as num?)?.toDouble() ?? 0;
    }
  }
  return 0;
}

Map<String, dynamic>? findPresentationDiscount(
  List<dynamic> discounts,
  String name, [
  String? dateStr,
]) {
  final arr = discounts
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  final today = dateStr ?? caracasDateString();
  final named =
      arr.where((d) => d['name'] == name && d['percent'] != null).toList();
  for (final d in named) {
    if (d['promoCampaignId'] != null && _isDiscountLive(d, today)) return d;
  }
  for (final d in named) {
    if (d['promoCampaignId'] == null) return d;
  }
  return null;
}

String presentationDiscountName(String presentacion) {
  final p = presentacion.trim().toLowerCase();
  if (p == 'mayor') return 'Mayor';
  if (p == 'bulto' || p == 'caja' || p == 'lote') return 'Bulto';
  return 'Unidad';
}

double resolvePresentationDiscountPercent(
  List<dynamic> discounts,
  String presentacion, [
  String? dateStr,
]) {
  final fallback = resolveProductLevelDiscountPercent(discounts, dateStr);
  final named = findPresentationDiscount(
    discounts,
    presentationDiscountName(presentacion),
    dateStr,
  );
  if (named != null) return (named['percent'] as num?)?.toDouble() ?? 0;
  return fallback;
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

double catalogPriceForPresentation(Product product, String presentacion) {
  switch (presentacion) {
    case 'Mayor':
      return product.priceMayor ?? product.price ?? 0;
    case 'Bulto':
    case 'Caja':
    case 'Lote':
      return product.priceBulto ?? product.price ?? 0;
    default:
      return product.price ?? 0;
  }
}

typedef CartLineDiscountResolver = double Function(
  List<dynamic> discounts,
  String presentacion,
);

CartItem refreshCartLineFromProduct(
  CartItem item,
  Product product, {
  required bool isCasheaFlow,
  required CartLineDiscountResolver resolveDiscount,
}) {
  final pres = item.presentacion;
  final qty = item.cantidad < 1 ? 1 : item.cantidad;
  var unitPrice = catalogPriceForPresentation(product, pres);
  final discountPct = resolveDiscount(product.discounts, pres);
  if (discountPct > 0) {
    unitPrice = redondear(unitPrice * (1 - discountPct / 100));
  }
  var precioFinal = unitPrice;
  final catalogPrice = unitPrice;
  if (isCasheaFlow) {
    precioFinal = getCasheaAdjustedUnitPrice(unitPrice, pres, true);
  }

  return CartItem(
    id: item.id,
    nombre: product.name,
    codigo: product.codigo ?? item.codigo,
    precio: precioFinal,
    precioOri: catalogPrice,
    presentacion: pres,
    cantidad: qty,
    totalAux: redondear(precioFinal * qty),
    precioUnidad: product.price,
    precioMayor: product.priceMayor,
    precioBulto: product.priceBulto,
    cantidadBulto: item.cantidadBulto,
    cantidadUnidadOri: product.cantidadUnidad,
    cantidadMayorOri: product.cantidadMayor,
    cantidadBultoOri: product.cantidadBulto,
    imgUrl100: product.imgUrl100 ?? product.imgUrl ?? item.imgUrl100,
    discounts: product.discounts,
    taxable: product.taxable,
    ivaRate: product.ivaRate,
    peso: product.peso,
    casheaSurchargeApplied: isCasheaFlow && presentationIsCasheaBulk(pres),
    precioCatalogoPresentacion: catalogPrice,
    presentaciones: item.presentaciones,
  );
}

({List<CartItem> lines, bool changed}) applyCatalogPricesToCartLines(
  List<CartItem> items,
  Map<String, Product> productsById, {
  required bool isCasheaFlow,
  required CartLineDiscountResolver resolveDiscount,
}) {
  if (items.isEmpty) return (lines: items, changed: false);
  var changed = false;
  final lines = items.map((item) {
    final product = productsById[item.id];
    if (product == null) return item;
    final refreshed = refreshCartLineFromProduct(
      item,
      product,
      isCasheaFlow: isCasheaFlow,
      resolveDiscount: resolveDiscount,
    );
    if (refreshed.precio != item.precio ||
        refreshed.totalAux != item.totalAux ||
        refreshed.precioOri != item.precioOri) {
      changed = true;
    }
    return refreshed;
  }).toList();
  return (lines: lines, changed: changed);
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

/// Reserva mínima (unidades físicas) — misma regla que `stockLevel.js` web.
const int minStockForAddToCart = 3;

double? getStockNumeric(dynamic stock) {
  if (stock == null) return null;
  if (stock is bool) return stock ? null : 0;
  if (stock is num) {
    if (!stock.isFinite || stock < 0) return null;
    return stock.toDouble();
  }
  final s = stock.toString().toLowerCase().trim();
  if (s == 'out' || s == 'agotado' || s == 'false') return 0;
  final n = double.tryParse(s);
  if (n == null || !n.isFinite || n < 0) return null;
  return n;
}

double? getSellableBaseUnits(dynamic stock) {
  final n = getStockNumeric(stock);
  if (n == null) return null;
  return (n - minStockForAddToCart).clamp(0, double.infinity);
}

num getPresentationBaseUnits(Product product, String presentacion) {
  final lower = presentacion.trim().toLowerCase();
  if (lower == 'unidad' || lower == 'und') {
    return product.cantidadUnidad < 1 ? 1 : product.cantidadUnidad;
  }
  if (lower == 'mayor') {
    return product.cantidadMayor < 1 ? 1 : product.cantidadMayor;
  }
  if (lower == 'bulto' || lower == 'lote' || lower == 'caja') {
    return product.cantidadBulto < 1 ? 1 : product.cantidadBulto;
  }
  return 1;
}

bool isPresentationAllowedByStock(dynamic stock, num baseUnitsNeeded) {
  final sellable = getSellableBaseUnits(stock);
  if (sellable == null) return true;
  final need = baseUnitsNeeded < 1 ? 1 : baseUnitsNeeded;
  return sellable >= need;
}

bool isStockAllowedForAddToCart(dynamic stock) {
  final sellable = getSellableBaseUnits(stock);
  if (sellable == null) return true;
  return sellable >= 1;
}

bool firebaseProductHasSellablePresentation(Product product, dynamic stock) {
  final checks = <bool>[];
  if (product.price != null && product.statusUnidad) {
    checks.add(isPresentationAllowedByStock(
      stock,
      getPresentationBaseUnits(product, 'Unidad'),
    ));
  }
  if (product.priceMayor != null && product.statusMayor) {
    checks.add(isPresentationAllowedByStock(
      stock,
      getPresentationBaseUnits(product, 'Mayor'),
    ));
  }
  if (product.priceBulto != null && product.statusBulto) {
    checks.add(isPresentationAllowedByStock(
      stock,
      getPresentationBaseUnits(product, 'Bulto'),
    ));
  }
  if (checks.isEmpty) return isStockAllowedForAddToCart(stock);
  return checks.any((ok) => ok);
}

enum StockLevel { unknown, critical, warning, ok }

StockLevel getStockLevel(dynamic stock) {
  final n = getStockNumeric(stock);
  if (n == null) return StockLevel.unknown;
  if (n <= minStockForAddToCart) return StockLevel.critical;
  if (n <= 100) return StockLevel.warning;
  return StockLevel.ok;
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
