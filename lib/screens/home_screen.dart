import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/home_sections.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
          const AdBannerCarousel(),
          const DailyOffersSection(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Categorías',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const CategoryGrid(),
          const FeaturedCarousel(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
