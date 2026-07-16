import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/pricing.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final discount = resolveProductLevelDiscountPercent(product.discounts);
    final basePrice = product.price ?? product.priceMayor ?? product.priceBulto ?? 0;
    final inCart = app.carrito.any((c) => c.id == product.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppColors.radiusMd),
                  ),
                  child: product.displayImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.displayImage,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (_, __) => Container(
                            color: AppColors.lightBg,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.image_not_supported,
                                color: AppColors.textLight),
                          ),
                        )
                      : Container(
                          color: AppColors.lightBg,
                          child: const Center(
                            child: Text('📦', style: TextStyle(fontSize: 32)),
                          ),
                        ),
                ),
                if (discount > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.discount,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-${discount.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
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
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${basePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: inCart
                        ? null
                        : () => app.agregarProductoAlCarritoCompleto(product),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(inCart ? 'En carrito' : 'Agregar'),
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

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products, this.loading = false});

  final List<Product> products;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (products.isEmpty) {
      return const Center(
        child: Text('No hay productos', style: TextStyle(color: AppColors.textLight)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) => ProductCard(product: products[i]),
    );
  }
}

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (app.cargandoCategorias) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (app.categorias.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No se pudieron cargar las categorías.\nVerifica Firebase.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textLight),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: app.categorias.length,
      itemBuilder: (_, i) {
        final cat = app.categorias[i];
        return InkWell(
          onTap: () => app.openCategoria(cat),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.shadowSm,
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (cat.imgUrl != null && cat.imgUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: cat.imgUrl!,
                    height: 48,
                    width: 48,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) =>
                        Text(cat.icon ?? '🛒', style: const TextStyle(fontSize: 28)),
                  )
                else
                  Text(cat.icon ?? '🛒', style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  cat.nombre,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SubcategoryList extends StatelessWidget {
  const SubcategoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final cat = app.categoriaActual;
    final subs = cat?.subCategories ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: app.resetHomeState,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  cat?.nombre ?? 'Subcategorías',
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
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: subs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final sub = subs[i];
              final name =
                  (sub['value'] ?? sub['nombre'] ?? sub['name'] ?? 'Subcategoría')
                      .toString();
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  side: const BorderSide(color: AppColors.border),
                ),
                tileColor: AppColors.cardBg,
                title: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => app.openSubcategoria(sub),
              );
            },
          ),
        ),
      ],
    );
  }
}
