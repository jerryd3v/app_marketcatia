import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/campaign_product.dart';
import '../models/models.dart';
import '../utils/caracas_date.dart';

/// Lógica alineada con `marketcatia/src/services/promoService.js`.
class PromoService {
  PromoService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<List<Map<String, dynamic>>> fetchActivePromoBanners() async {
    try {
      final snap = await _db
          .collection('promo_banners')
          .where('activo', isEqualTo: true)
          .get();
      final list = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      list.sort(
        (a, b) =>
            (a['orden'] as num? ?? 0).compareTo(b['orden'] as num? ?? 0),
      );
      return list.where((b) {
        if (b['ctaAction'] != 'announcement') return true;
        return (b['backgroundImageUrl']?.toString().isNotEmpty ?? false) &&
            (b['backgroundImageMobileUrl']?.toString().isNotEmpty ?? false);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchPromoBannerById(String id) async {
    final snap = await _db.collection('promo_banners').doc(id).get();
    if (!snap.exists) return null;
    return {...snap.data()!, 'id': snap.id};
  }

  Future<Map<String, dynamic>?> fetchActiveDailyOfferForToday() async {
    try {
      final today = caracasDateString();
      final snap = await _db
          .collection('daily_offers')
          .where('activo', isEqualTo: true)
          .get();
      for (final d in snap.docs) {
        final data = d.data();
        if (isDateInCaracasRange(data['startDate'], data['endDate'], today)) {
          return {...data, 'id': d.id};
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<Product>> fetchProductsByIds(List<String> productIds) async {
    final unique = productIds.where((e) => e.trim().isNotEmpty).toSet();
    final out = <Product>[];
    await Future.wait(unique.map((id) async {
      try {
        final snap = await _db.collection('products').doc(id).get();
        if (!snap.exists) return;
        final data = snap.data()!;
        if (data['show'] == false) return;
        out.add(Product.fromMap({...data, 'id': snap.id}));
      } catch (_) {}
    }));
    return out;
  }

  double resolveCampaignDiscount(Map? entry, dynamic globalDiscountPercent) {
    final per = entry?['discountPercent'];
    if (per != null && '$per'.trim().isNotEmpty) {
      return (per is num) ? per.toDouble() : double.tryParse('$per') ?? 0;
    }
    if (globalDiscountPercent is num) return globalDiscountPercent.toDouble();
    return double.tryParse('$globalDiscountPercent') ?? 0;
  }

  double getProductBasePrice(Product product, String modo) {
    if (modo == 'wholesale') {
      return (product.priceBulto ?? product.priceMayor ?? product.price ?? 0)
          .toDouble();
    }
    return (product.price ?? 0).toDouble();
  }

  ({String name, String icon}) resolveProductCategory(
    Product product,
    List<CategoryItem> categorias,
  ) {
    final raw = product.raw;
    final catField = raw['category'] ?? raw['categoria'];
    String name = '';
    if (catField is String && catField.trim().isNotEmpty) {
      name = catField.trim();
    } else if (catField is Map) {
      name = (catField['value'] ?? catField['name'] ?? catField['nombre'] ?? '')
          .toString();
    }
    if (name.isNotEmpty) {
      final matched = categorias.cast<CategoryItem?>().firstWhere(
            (c) =>
                c!.nombre == name ||
                c.key == name ||
                c.id == name ||
                (c.raw['value']?.toString() == name),
            orElse: () => null,
          );
      return (name: name, icon: matched?.icon ?? '🛒');
    }

    final catKey = raw['categoriaID'] ??
        raw['idCategory'] ??
        raw['idCategoria'] ??
        (catField is Map
            ? (catField['id'] ?? catField['key'] ?? catField['idCategory'])
            : null);
    if (catKey != null) {
      final key = catKey.toString();
      final matched = categorias.cast<CategoryItem?>().firstWhere(
            (c) => c!.id == key || c.key == key,
            orElse: () => null,
          );
      if (matched != null) {
        return (name: matched.nombre, icon: matched.icon ?? '🛒');
      }
    }

    final subId = raw['sub_category'] ??
        raw['subCategory'] ??
        raw['subcategoriaId'] ??
        (raw['sub_categories'] is List && (raw['sub_categories'] as List).isNotEmpty
            ? ((raw['sub_categories'] as List).first is Map
                ? (raw['sub_categories'] as List).first['id']
                : null)
            : null);
    if (subId != null) {
      final sid = subId.toString();
      for (final cat in categorias) {
        if (cat.subCategories.any(
          (s) =>
              (s['id'] ?? s['idSubCategory'] ?? '').toString() == sid,
        )) {
          return (name: cat.nombre, icon: cat.icon ?? '🛒');
        }
      }
    }
    return (name: 'Otros', icon: '📦');
  }

  CampaignProductView buildCampaignProductView({
    required Product product,
    required Map entry,
    required dynamic globalDiscountPercent,
    required String modo,
    required List<CategoryItem> categorias,
    String? promoSource,
    String? promoCampaignId,
  }) {
    final discount = resolveCampaignDiscount(entry, globalDiscountPercent);
    final base = getProductBasePrice(product, modo);
    final offer = base * (1 - discount / 100);
    final cat = resolveProductCategory(product, categorias);
    return CampaignProductView(
      id: product.id,
      product: product,
      nombre: product.name,
      imgUrl: product.displayImage,
      basePrice: base,
      discountPercent: discount,
      offerPrice: offer,
      categoryName: cat.name,
      categoryIcon: cat.icon,
      promoSource: promoSource,
      promoCampaignId: promoCampaignId,
    );
  }

  Future<List<CampaignProductView>> resolveCampaignProducts(
    Map<String, dynamic>? campaign, {
    required String modo,
    required List<CategoryItem> categorias,
    String? promoSource,
  }) async {
    final productsRaw = campaign?['products'];
    if (productsRaw is! List || productsRaw.isEmpty) return [];
    final entries = productsRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final ids = entries
        .map((e) => (e['productId'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final fetched = await fetchProductsByIds(ids);
    final byId = {for (final p in fetched) p.id: p};
    final out = <CampaignProductView>[];
    for (final entry in entries) {
      final product = byId[entry['productId']?.toString()];
      if (product == null) continue;
      out.add(
        buildCampaignProductView(
          product: product,
          entry: entry,
          globalDiscountPercent: campaign?['globalDiscountPercent'],
          modo: modo,
          categorias: categorias,
          promoSource: promoSource,
          promoCampaignId: campaign?['id']?.toString(),
        ),
      );
    }
    return out;
  }

  List<({String name, String icon, int count})> buildOfferCategoryFilters(
    List<CampaignProductView> products,
  ) {
    final map = <String, ({String name, String icon, int count})>{};
    for (final p in products) {
      final key = p.categoryName;
      final existing = map[key];
      if (existing != null) {
        map[key] = (name: key, icon: existing.icon, count: existing.count + 1);
      } else {
        map[key] = (name: key, icon: p.categoryIcon, count: 1);
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}
