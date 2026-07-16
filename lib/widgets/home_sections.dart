import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import 'catalog_widgets.dart';

class AdBannerCarousel extends StatelessWidget {
  const AdBannerCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final banners = context.watch<AppProvider>().banners;
    if (banners.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: PageView.builder(
        itemCount: banners.length,
        controller: PageController(viewportFraction: 0.92),
        itemBuilder: (_, i) {
          final b = banners[i];
          final img = (b['imageUrl'] ?? b['imgUrl'] ?? b['image'] ?? '').toString();
          final id = (b['id'] ?? '').toString();
          return GestureDetector(
            onTap: () {
              if (id.isNotEmpty) context.go('/campana/banner/$id');
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                gradient: AppColors.primaryGradient,
              ),
              clipBehavior: Clip.antiAlias,
              child: img.isNotEmpty
                  ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        (b['title'] ?? b['nombre'] ?? 'Promoción').toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class DailyOffersSection extends StatelessWidget {
  const DailyOffersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final offers = context.watch<AppProvider>().dailyOffers;
    if (offers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Ofertas del día',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/campana/ofertas'),
                child: const Text('Ver todas'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: offers.length.clamp(0, 10),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final o = offers[i];
              final name = (o['name'] ?? o['nombre'] ?? 'Oferta').toString();
              return Container(
                width: 200,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.campaignStart, AppColors.campaignEnd],
                  ),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.local_offer, color: Colors.white),
                    const Spacer(),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FeaturedCarousel extends StatelessWidget {
  const FeaturedCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (app.cargandoMasVendidos) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (app.bestSellers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Más vendidos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 260,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: app.bestSellers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(
              width: 160,
              child: ProductCard(product: app.bestSellers[i]),
            ),
          ),
        ),
      ],
    );
  }
}
