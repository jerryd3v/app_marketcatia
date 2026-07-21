import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/campaign_product.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/pricing.dart';

final _offerPriceFmt = NumberFormat('#,##0.00', 'es');

class AdBannerCarousel extends StatefulWidget {
  const AdBannerCarousel({super.key, this.onScrollToOffers});

  final VoidCallback? onScrollToOffers;

  @override
  State<AdBannerCarousel> createState() => _AdBannerCarouselState();
}

class _AdBannerCarouselState extends State<AdBannerCarousel> {
  final _controller = PageController(viewportFraction: 0.94);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _executeBannerAction(
    BuildContext context,
    Map<String, dynamic> banner,
  ) async {
    final app = context.read<AppProvider>();
    final action = (banner['ctaAction'] ?? 'campaign_view').toString();
    switch (action) {
      case 'announcement':
        return;
      case 'scroll_offers':
        widget.onScrollToOffers?.call();
        return;
      case 'category':
        app.resetHomeState();
        context.go('/');
        app.openCategoryById(banner['categoryId']?.toString());
        return;
      case 'subcategory':
        app.resetHomeState();
        context.go('/');
        app.openSubcategoryByIds(
          banner['categoryId']?.toString(),
          banner['subcategoryId']?.toString(),
        );
        return;
      case 'wholesale':
        context.go('/');
        await app.cambiarModo('wholesale');
        return;
      case 'external_url':
        final url = banner['externalUrl']?.toString() ?? '';
        if (url.isEmpty) return;
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return;
      case 'campaign_view':
      default:
        final id = banner['id']?.toString() ?? '';
        if (id.isNotEmpty) context.go('/campana/banner/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final banners = context.watch<AppProvider>().banners;
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final b = banners[i];
              final isAnnouncement = b['ctaAction'] == 'announcement';
              if (isAnnouncement) {
                final img = (b['backgroundImageMobileUrl'] ??
                        b['backgroundImageUrl'] ??
                        '')
                    .toString();
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    child: img.isEmpty
                        ? const ColoredBox(color: AppColors.border)
                        : CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: _PromoBannerSlide(
                  banner: b,
                  onTap: () => _executeBannerAction(context, b),
                ),
              );
            },
          ),
        ),
        if (banners.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              banners.length,
              (i) => Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _index
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PromoBannerSlide extends StatelessWidget {
  const _PromoBannerSlide({required this.banner, required this.onTap});
  final Map<String, dynamic> banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgType = (banner['backgroundType'] ?? '').toString();
    final bgImage = (banner['backgroundImageUrl'] ?? '').toString();
    final title = (banner['titulo'] ?? banner['title'] ?? '').toString();
    final subtitle =
        (banner['subtitulo'] ?? banner['subtitle'] ?? '').toString();
    final cta = (banner['ctaText'] ?? 'Ver más').toString();
    final emoji = (banner['iconEmoji'] ?? '🔥').toString();
    final iconImg = (banner['iconImageUrl'] ?? '').toString();

    Decoration decoration;
    if (bgType == 'image' && bgImage.isNotEmpty) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        image: DecorationImage(
          image: CachedNetworkImageProvider(bgImage),
          fit: BoxFit.cover,
        ),
      );
    } else {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        gradient: AppColors.primaryGradient,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Ink(
          decoration: decoration,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              color: bgType == 'image'
                  ? Colors.black.withValues(alpha: 0.35)
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: banner['iconType'] == 'image' && iconImg.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: iconImg,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 28)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          cta,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DailyOffersSection extends StatefulWidget {
  const DailyOffersSection({super.key});

  @override
  State<DailyOffersSection> createState() => _DailyOffersSectionState();
}

class _DailyOffersSectionState extends State<DailyOffersSection> {
  String _filter = 'todos';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final campaign = app.activeDailyOffer;
    final products = app.dailyOfferProducts;
    if (app.cargandoOfertas || campaign == null || products.isEmpty) {
      return const SizedBox.shrink();
    }

    final filters = app.promo.buildOfferCategoryFilters(products);
    final filtered = _filter == 'todos'
        ? products
        : products.where((p) => p.categoryName == _filter).toList();
    final title = (campaign['nombre'] ?? 'Ofertas del Día').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              const Icon(Icons.local_offer, color: AppColors.discount, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/campana/ofertas'),
                child: const Text('Ver todas'),
              ),
            ],
          ),
        ),
        if (filters.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: 'Todos',
                  selected: _filter == 'todos',
                  onTap: () => setState(() => _filter = 'todos'),
                ),
                for (final f in filters)
                  _FilterChip(
                    label: '${f.icon} ${f.name}',
                    selected: _filter == f.name,
                    onTap: () => setState(() => _filter = f.name),
                  ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            promoNoticeDailyOffer,
            style: TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
        ),
        SizedBox(
          height: 210,
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Sin ofertas en esta categoría',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: filtered.length.clamp(0, 14),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => OfferProductCard(
                    product: filtered[i],
                    onTap: () {
                      context.go('/');
                      app.goToCampaignProduct(filtered[i]);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textMedium,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class OfferProductCard extends StatelessWidget {
  const OfferProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.width = 148,
  });

  final CampaignProductView product;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppColors.radiusMd),
                        ),
                        child: product.imgUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: product.imgUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Center(
                                  child: Text('📦', style: TextStyle(fontSize: 36)),
                                ),
                              )
                            : const Center(
                                child: Text('📦', style: TextStyle(fontSize: 36)),
                              ),
                      ),
                    ),
                    if (product.discountPercent > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.discount,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-${product.discountPercent.round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (product.discountPercent > 0) ...[
                          Text(
                            '\$${_offerPriceFmt.format(product.basePrice)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          '\$${_offerPriceFmt.format(product.offerPrice)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.discount,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({super.key});

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  final _pageController = PageController();
  int _page = 0;
  int _pageCount = 0;
  Timer? _auto;

  @override
  void dispose() {
    _auto?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartAuto(int pageCount) {
    _auto?.cancel();
    _pageCount = pageCount;
    if (pageCount <= 1) return;
    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_page + 1) % pageCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    // Como la web: no mostrar spinner; ocultar hasta tener datos
    if (app.cargandoMasVendidos || app.bestSellers.isEmpty) {
      return const SizedBox.shrink();
    }

    final products = app.bestSellers;
    final wide = MediaQuery.sizeOf(context).width >= 768;
    // Móvil: 2x2 (4 tarjetas visibles). Tablet/desktop: 4x2 (8).
    final cols = wide ? 4 : 2;
    final rows = 2;
    final perPage = cols * rows;
    final aspect = wide ? 0.85 : 0.72;
    const gridPad = 12.0;
    const gridGap = 10.0;

    final pages = <List<Product>>[];
    for (var i = 0; i < products.length; i += perPage) {
      pages.add(
        products.sublist(i, (i + perPage).clamp(0, products.length)),
      );
    }

    if (_pageCount != pages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restartAuto(pages.length);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Icon(Icons.local_fire_department, color: AppColors.featured),
                SizedBox(width: 8),
                Text(
                  'Productos Más Vendidos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.cardBg,
            elevation: 2,
            shadowColor: Colors.black12,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final usable =
                        constraints.maxWidth - gridPad * 2;
                    final cellW =
                        (usable - gridGap * (cols - 1)) / cols;
                    final cellH = cellW / aspect;
                    final pageHeight = gridPad * 2 +
                        rows * cellH +
                        gridGap * (rows - 1);
                    return SizedBox(
                      height: pageHeight,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: pages.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (_, pageIndex) {
                          final slide = pages[pageIndex];
                          return Padding(
                            padding: const EdgeInsets.all(gridPad),
                            child: GridView.builder(
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisSpacing: gridGap,
                                crossAxisSpacing: gridGap,
                                childAspectRatio: aspect,
                              ),
                              itemCount: perPage,
                              itemBuilder: (_, i) {
                                if (i >= slide.length) {
                                  return const _BestSellerPlaceholder();
                                }
                                return _BestSellerTile(
                                  product: slide[i],
                                  onTap: () {
                                    app.openProductInCatalog(slide[i]);
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                if (pages.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            final prev =
                                _page == 0 ? pages.length - 1 : _page - 1;
                            _pageController.animateToPage(
                              prev,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOut,
                            );
                            _restartAuto(pages.length);
                          },
                          icon: const Icon(Icons.chevron_left),
                          color: AppColors.primary,
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              pages.length,
                              (i) => Container(
                                width: 8,
                                height: 8,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _page
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final next = (_page + 1) % pages.length;
                            _pageController.animateToPage(
                              next,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOut,
                            );
                            _restartAuto(pages.length);
                          },
                          icon: const Icon(Icons.chevron_right),
                          color: AppColors.primary,
                        ),
                      ],
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

class _BestSellerTile extends StatelessWidget {
  const _BestSellerTile({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Como la web: priceBulto || price + descuento de producto
    final base = (product.priceBulto ?? product.price ?? 0).toDouble();
    final discount = resolveProductLevelDiscountPercent(product.discounts);
    final price = base * (1 - discount / 100);
    final img = product.displayImage;

    return Material(
      color: AppColors.lightBg,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.featured,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'MÁS VENDIDO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: img.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: img,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Center(
                            child: Text('📦', style: TextStyle(fontSize: 28)),
                          ),
                        )
                      : const Center(
                          child: Text('📦', style: TextStyle(fontSize: 28)),
                        ),
                ),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${_offerPriceFmt.format(price)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                if (discount > 0)
                  Text(
                    '-${discount.round()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.discount,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BestSellerPlaceholder extends StatelessWidget {
  const _BestSellerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.lightBg,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📦', style: TextStyle(fontSize: 28)),
            SizedBox(height: 6),
            Text(
              'Próximamente',
              style: TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}
