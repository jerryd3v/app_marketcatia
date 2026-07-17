import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/home_sections.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _offersKey = GlobalKey();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToOffers() {
    final ctx = _offersKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    if (app.busqueda.trim().length >= 2) {
      return Column(
        children: [
          if (app.buscando)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ProductGrid(
              products: app.resultadosBusqueda,
              loading: app.buscando && app.resultadosBusqueda.isEmpty,
            ),
          ),
        ],
      );
    }

    if (app.vistaActual == 'subcategories') {
      return const SubcategoryList();
    }

    if (app.vistaActual == 'products') {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: app.backToSubcategories,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    (app.subcategoriaActual?['value'] ??
                            app.subcategoriaActual?['nombre'] ??
                            'Productos')
                        .toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ProductGrid(
              products: app.productosSubcategoria,
              loading: app.cargandoProductos,
            ),
          ),
        ],
      );
    }

    // Home: banner → categorías → ofertas → más vendidos (como web)
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          app.loadCategorias(),
          app.loadBestSellers(),
          app.loadBanners(),
          app.loadDailyOffers(),
          app.loadSedes(),
        ]);
      },
      child: ListView(
        controller: _scrollController,
        children: [
          if (!app.firebaseReady)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.featuredBg,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: AppColors.featured),
              ),
              child: const Text(
                'Firebase no inicializado. Puedes buscar productos por API; categorías y sedes requieren Firebase.',
                style: TextStyle(fontSize: 12, color: AppColors.textMedium),
              ),
            ),
          AdBannerCarousel(onScrollToOffers: _scrollToOffers),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Categorías',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const CategoryGrid(),
          KeyedSubtree(
            key: _offersKey,
            child: const DailyOffersSection(),
          ),
          const FeaturedCarousel(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
