import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/campaign_product.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/home_sections.dart';

class CampaignScreen extends StatefulWidget {
  const CampaignScreen({
    super.key,
    this.bannerId,
    this.isDailyOffers = false,
  });

  final String? bannerId;
  final bool isDailyOffers;

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  bool _loading = true;
  Map<String, dynamic>? _hero;
  List<CampaignProductView> _products = [];
  String _filter = 'todos';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic>? campaign;
      Map<String, dynamic> hero;

      if (widget.isDailyOffers) {
        campaign = await app.promo.fetchActiveDailyOfferForToday();
        if (campaign == null) {
          throw Exception('No hay ofertas activas hoy');
        }
        hero = {
          'title': campaign['nombre'] ?? 'Ofertas del Día',
          'subtitle':
              'Promoción válida del ${campaign['startDate']} al ${campaign['endDate']}',
          'backgroundType': 'gradient',
          'iconEmoji': '🏷️',
          'notice': promoNoticeDailyOffer,
        };
      } else {
        final id = widget.bannerId ?? '';
        campaign = await app.promo.fetchPromoBannerById(id);
        if (campaign == null) throw Exception('Campaña no encontrada');
        hero = {
          'title': campaign['titulo'] ?? campaign['title'] ?? 'Campaña',
          'subtitle': campaign['subtitulo'] ?? campaign['subtitle'] ?? '',
          'backgroundType': campaign['backgroundType'],
          'backgroundGradient': campaign['backgroundGradient'],
          'backgroundImageUrl': campaign['backgroundImageUrl'],
          'iconType': campaign['iconType'],
          'iconEmoji': campaign['iconEmoji'] ?? '🔥',
          'iconImageUrl': campaign['iconImageUrl'],
          'notice': promoNoticeBanner,
        };
      }

      final products = await app.promo.resolveCampaignProducts(
        campaign,
        modo: app.modo,
        categorias: app.categorias,
        promoSource: widget.isDailyOffers ? 'daily_offer' : 'banner',
      );

      if (!mounted) return;
      setState(() {
        _hero = hero;
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _hero = null;
        _products = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _hero == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Campaña no encontrada',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMedium),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go('/'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      );
    }

    final app = context.watch<AppProvider>();
    final filters = app.promo.buildOfferCategoryFilters(_products);
    final filtered = _filter == 'todos'
        ? _products
        : _products.where((p) => p.categoryName == _filter).toList();
    final title = (_hero!['title'] ?? '').toString();
    final subtitle = (_hero!['subtitle'] ?? '').toString();
    final notice = (_hero!['notice'] ?? '').toString();
    final bgImage = (_hero!['backgroundImageUrl'] ?? '').toString();
    final isImage = _hero!['backgroundType'] == 'image' && bgImage.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: isImage
                    ? null
                    : (widget.isDailyOffers
                        ? const LinearGradient(
                            colors: [
                              AppColors.campaignStart,
                              AppColors.campaignEnd,
                            ],
                          )
                        : AppColors.primaryGradient),
                image: isImage
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(bgImage),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                color: isImage ? Colors.black38 : null,
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      (_hero!['iconEmoji'] ?? '').toString(),
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (notice.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  notice,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ),
          if (filters.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: const Text('Todos'),
                        selected: _filter == 'todos',
                        onSelected: (_) => setState(() => _filter = 'todos'),
                      ),
                    ),
                    for (final f in filters)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('${f.icon} ${f.name}'),
                          selected: _filter == f.name,
                          onSelected: (_) =>
                              setState(() => _filter = f.name),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (filtered.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Sin productos en esta categoría',
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final p = filtered[i];
                    return OfferProductCard(
                      product: p,
                      width: null,
                      onTap: () {
                        context.go('/');
                        app.goToCampaignProduct(p);
                      },
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
