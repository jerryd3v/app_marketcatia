import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/content_policy.dart';
import '../models/campaign_product.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/caracas_date.dart';

const _slotsMobile = 6;
const _cardHeight = 88.0;
const _rowTopSpace = 10.0;
const _rowHeight = _rowTopSpace + _cardHeight;
const _rowGap = 13.6;
const _colGap = 8.8;
const _gridTopPad = 18.0;

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

double offerFlyerCarouselHeight(double viewportWidth) {
  const rows = _slotsMobile ~/ 2;
  const header = 13.8 + 4.0 + 19.4 + 10.0;
  const slidePad = 14.0 + 12.0;
  const pagePad = 16.0;
  const buffer = 6.0;
  final grid = _gridTopPad + rows * _rowHeight + (rows - 1) * _rowGap;
  return header + grid + slidePad + pagePad + buffer;
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

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          boxShadow: AppColors.shadowMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ESTA SEMANA',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                height: 1.2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'OFERTAS',
              style: TextStyle(
                fontSize: 17.6,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                height: 1.1,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Expanded(
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (visible.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Cargando ofertas…',
                    style: TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: _gridTopPad),
                  child: _FlyerGrid(products: visible),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlyerGrid extends StatelessWidget {
  const _FlyerGrid({required this.products});
  final List<CampaignProductView> products;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < products.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: _rowGap));
      rows.add(
        SizedBox(
          height: _rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _FlyerCard(product: products[i])),
              const SizedBox(width: _colGap),
              Expanded(
                child: i + 1 < products.length
                    ? _FlyerCard(product: products[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _FlyerCard extends StatelessWidget {
  const _FlyerCard({required this.product});
  final CampaignProductView product;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.discountPercent > 0;
    final antes = product.basePrice.toStringAsFixed(2);

    return SizedBox(
      height: _cardHeight,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 9, 9, 8),
        decoration: BoxDecoration(
          color: AppColors.featuredBg,
          borderRadius: BorderRadius.circular(16),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Transform.translate(
              offset: const Offset(-4, -18),
              child: _FlyerProductImage(imgUrl: product.imgUrl),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      height: 1.2,
                    ),
                  ),
                  if (hasDiscount) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Text(
                          'ANTES',
                          style: TextStyle(
                            fontSize: 8.8,
                            fontWeight: FontWeight.w800,
                            color: AppColors.discount,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '\$$antes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.3,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMedium,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.discount,
                              decorationThickness: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  _FlyerPrice(value: product.offerPrice),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlyerProductImage extends StatelessWidget {
  const _FlyerProductImage({required this.imgUrl});
  final String imgUrl;

  static const _w = 58.0;
  static const _h = 68.0;

  @override
  Widget build(BuildContext context) {
    if (imgUrl.isEmpty) {
      return const SizedBox(
        width: _w,
        height: _h,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Text('📦', style: TextStyle(fontSize: 26)),
        ),
      );
    }

    return SizedBox(
      width: _w,
      height: _h,
      child: CachedNetworkImage(
        imageUrl: imgUrl,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorWidget: (_, _, _) => const Align(
          alignment: Alignment.bottomCenter,
          child: Text('📦', style: TextStyle(fontSize: 26)),
        ),
        imageBuilder: (context, imageProvider) =>
            _DropShadowImage(imageProvider: imageProvider),
      ),
    );
  }
}

/// ponytail: duplica el raster para simular CSS `drop-shadow`; sin paquete extra.
class _DropShadowImage extends StatelessWidget {
  const _DropShadowImage({required this.imageProvider});
  final ImageProvider imageProvider;

  Widget _image() => Image(
        image: imageProvider,
        fit: BoxFit.contain,
        width: _FlyerProductImage._w,
        height: _FlyerProductImage._h,
        alignment: Alignment.bottomCenter,
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Transform.translate(
          offset: const Offset(0, 3),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x330F172A),
                BlendMode.srcIn,
              ),
              child: _image(),
            ),
          ),
        ),
        _image(),
      ],
    );
  }
}

class _FlyerPrice extends StatelessWidget {
  const _FlyerPrice({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final parts = value.toStringAsFixed(2).split('.');
    const style = TextStyle(
      fontWeight: FontWeight.w900,
      color: AppColors.primary,
      letterSpacing: -0.3,
      height: 1,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('\$', style: style.copyWith(fontSize: 11.5, height: 1.35)),
        Text(parts[0], style: style.copyWith(fontSize: 21.6)),
        Padding(
          padding: const EdgeInsets.only(left: 1, top: 1),
          child: Text(parts[1], style: style.copyWith(fontSize: 11)),
        ),
      ],
    );
  }
}
