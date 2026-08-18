import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/home_sections.dart';
import '../widgets/spin_y_icons.dart';
import '../widgets/store_comments.dart';

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

    // Home: marcas → banner → categorías → ofertas → más vendidos
    // Marcas arriba del banner para no dejar hueco blanco bajo el buscador.
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          app.loadCategorias(),
          app.loadBestSellers(),
          app.loadBanners(),
          app.loadDailyOffers(),
          app.loadSedes(),
          app.loadProductBrands(),
        ]);
      },
      child: ListView(
        controller: _scrollController,
        // Evita el padding top del safe area (el header ya lo aplica):
        // si no, queda un hueco blanco bajo el buscador.
        padding: EdgeInsets.zero,
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
          const BrandsSlider(),
          AdBannerCarousel(onScrollToOffers: _scrollToOffers),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  'Categorías',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 6),
                SpinYIcons(icon: Icons.star, count: 5, size: 16),
              ],
            ),
          ),
          const CategoryGrid(),
          KeyedSubtree(
            key: _offersKey,
            child: const DailyOffersSection(),
          ),
          const StoreCommentsEntry(),
          const FeaturedCarousel(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
