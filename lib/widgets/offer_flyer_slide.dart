import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/content_policy.dart';
import '../models/campaign_product.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/caracas_date.dart';

const _slotsMobile = 6;

List<T> shuffleWithSeed<T>(List<T> items, int seed) {
  final arr = List<T>.from(items);
  final rand = Random(seed);
  for (var i = arr.length - 1; i > 0; i--) {
    final j = rand.nextInt(i + 1);
    final tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

int _hashSeed(String str) {
  var h = 2166136261;
  for (var i = 0; i < str.length; i++) {
    h ^= str.codeUnitAt(i);
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return h;
}

class OfferFlyerSlide extends StatefulWidget {
  const OfferFlyerSlide({
    super.key,
    required this.banner,
    required this.onTap,
  });

  final Map<String, dynamic> banner;
  final VoidCallback onTap;

  @override
  State<OfferFlyerSlide> createState() => _OfferFlyerSlideState();
}

class _OfferFlyerSlideState extends State<OfferFlyerSlide> {
  List<CampaignProductView> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    try {
      final items = filterCampaignProductsForPlatform(
        await app.promo.resolveCampaignProducts(
          widget.banner,
          modo: app.modo,
          categorias: app.categorias,
          promoSource: 'banner',
        ),
      );
      if (!mounted) return;
      final seed = _hashSeed('${widget.banner['id']}|${caracasDateString()}');
      setState(() {
        _products = shuffleWithSeed(items, seed);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _products.take(_slotsMobile).toList();
    final fmt = NumberFormat('#,##0.00', 'es');

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          boxShadow: AppColors.shadowMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ESTA SEMANA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'OFERTAS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Cargando ofertas…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.28,
                ),
                itemCount: visible.length,
                itemBuilder: (_, i) => _FlyerCard(product: visible[i], fmt: fmt),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlyerCard extends StatelessWidget {
  const _FlyerCard({required this.product, required this.fmt});
  final CampaignProductView product;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.discountPercent > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.featuredBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            offset: const Offset(3, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            height: 60,
            child: product.imgUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.imgUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, _, _) =>
                        const Center(child: Text('📦', style: TextStyle(fontSize: 22))),
                  )
                : const Center(child: Text('📦', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    height: 1.15,
                  ),
                ),
                if (hasDiscount) ...[
                  const SizedBox(height: 2),
                  Text(
                    'ANTES \$${fmt.format(product.basePrice)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textLight,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '\$${fmt.format(product.offerPrice)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.discount,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
