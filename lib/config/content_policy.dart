import 'package:flutter/foundation.dart';

import '../models/campaign_product.dart';
import '../models/models.dart';

/// App Store 1.4.3: no facilitar venta/promoción de tabaco en iOS.
bool get hideTobaccoOnThisPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

bool looksLikeTobaccoText(String? value) {
  if (value == null || value.trim().isEmpty) return false;
  final t = value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
  const keys = <String>[
    'tabaco',
    'tobacco',
    'nicotina',
    'nicotine',
    'vape',
    'vaping',
    'vapear',
    'vaporizador',
    'cigarro',
    'cigarrillo',
    'cigarette',
    'cigar',
    'hookah',
    'narguil',
    'e-cig',
    'ecig',
  ];
  return keys.any(t.contains);
}

bool isTobaccoCategory(CategoryItem cat) =>
    looksLikeTobaccoText(cat.nombre) ||
    looksLikeTobaccoText(cat.key) ||
    looksLikeTobaccoText(cat.id);

bool isTobaccoProduct(Product product) {
  if (looksLikeTobaccoText(product.name)) return true;
  final raw = product.raw;
  for (final key in [
    'category',
    'categoria',
    'categoryName',
    'nombreCategoria',
    'categoriaNombre',
  ]) {
    final v = raw[key];
    if (v is String && looksLikeTobaccoText(v)) return true;
    if (v is Map) {
      if (looksLikeTobaccoText(
            (v['value'] ?? v['name'] ?? v['nombre'] ?? v['key'])?.toString(),
          )) {
        return true;
      }
    }
  }
  final subs = raw['sub_categories'] ?? raw['subCategories'];
  if (subs is List) {
    for (final s in subs) {
      if (s is! Map) continue;
      if (looksLikeTobaccoText(
            (s['name'] ?? s['nombre'] ?? s['value'] ?? s['key'])?.toString(),
          )) {
        return true;
      }
    }
  }
  return false;
}

bool isTobaccoCampaignProduct(CampaignProductView view) =>
    looksLikeTobaccoText(view.categoryName) ||
    looksLikeTobaccoText(view.nombre) ||
    isTobaccoProduct(view.product);

bool isTobaccoCartItem(CartItem item) =>
    looksLikeTobaccoText(item.nombre) ||
    looksLikeTobaccoText(item.codigo);

List<CategoryItem> filterCategoriesForPlatform(List<CategoryItem> list) {
  if (!hideTobaccoOnThisPlatform) return list;
  return list.where((c) => !isTobaccoCategory(c)).toList();
}

List<Product> filterProductsForPlatform(List<Product> list) {
  if (!hideTobaccoOnThisPlatform) return list;
  return list.where((p) => !isTobaccoProduct(p)).toList();
}

List<CampaignProductView> filterCampaignProductsForPlatform(
  List<CampaignProductView> list,
) {
  if (!hideTobaccoOnThisPlatform) return list;
  return list.where((p) => !isTobaccoCampaignProduct(p)).toList();
}

List<CartItem> filterCartForPlatform(List<CartItem> list) {
  if (!hideTobaccoOnThisPlatform) return list;
  return list.where((c) => !isTobaccoCartItem(c)).toList();
}
