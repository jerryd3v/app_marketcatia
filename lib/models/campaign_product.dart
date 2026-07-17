import '../models/models.dart';

class CampaignProductView {
  CampaignProductView({
    required this.id,
    required this.product,
    required this.nombre,
    required this.imgUrl,
    required this.basePrice,
    required this.discountPercent,
    required this.offerPrice,
    required this.categoryName,
    this.categoryIcon = '📦',
    this.promoSource,
    this.promoCampaignId,
  });

  final String id;
  final Product product;
  final String nombre;
  final String imgUrl;
  final double basePrice;
  final double discountPercent;
  final double offerPrice;
  final String categoryName;
  final String categoryIcon;
  final String? promoSource;
  final String? promoCampaignId;
}

const promoNoticeDailyOffer =
    'Descuento promocional activo solo entre las fechas de la campaña (hora Caracas).';
const promoNoticeBanner =
    'Descuento promocional activo en catálogo y carrito mientras el banner esté activo.';
