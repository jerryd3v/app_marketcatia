import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/pricing.dart';

final _priceFmt = NumberFormat('#,##0.00', 'es');

class ProductCard extends StatefulWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  String _selectedPres = 'Unidad';

  Product get product => widget.product;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppProvider>();
    final opts = _options(app.isWholesale);
    if (opts.isNotEmpty && !opts.any((o) => o.key == _selectedPres)) {
      _selectedPres = opts.first.key;
    }
  }

  List<_CardPres> _options(bool isWholesale) {
    if (!isWholesale) {
      if (product.price == null) return const [];
      return [
        _CardPres(
          key: 'Unidad',
          label: 'Unidad',
          qtyLabel: '${_qty(product.cantidadUnidad)} und',
          price: product.price!,
          stockOk: isPresentationAllowedByStock(
            product.stock,
            getPresentationBaseUnits(product, 'Unidad'),
          ),
        ),
      ];
    }
    final list = <_CardPres>[];
    if (product.price != null && product.statusUnidad) {
      list.add(_CardPres(
        key: 'Unidad',
        label: 'Unidad',
        qtyLabel: '${_qty(product.cantidadUnidad)} und',
        price: product.price!,
        stockOk: isPresentationAllowedByStock(
          product.stock,
          getPresentationBaseUnits(product, 'Unidad'),
        ),
      ));
    }
    if (product.priceMayor != null && product.statusMayor) {
      list.add(_CardPres(
        key: 'Mayor',
        label: 'Mayor',
        qtyLabel: '${_qty(product.cantidadMayor)} und',
        price: product.priceMayor!,
        stockOk: isPresentationAllowedByStock(
          product.stock,
          getPresentationBaseUnits(product, 'Mayor'),
        ),
      ));
    }
    if (product.priceBulto != null && product.statusBulto) {
      list.add(_CardPres(
        key: 'Bulto',
        label: 'Bulto',
        qtyLabel: '${_qty(product.cantidadBulto)} und',
        price: product.priceBulto!,
        stockOk: isPresentationAllowedByStock(
          product.stock,
          getPresentationBaseUnits(product, 'Bulto'),
        ),
      ));
    }
    return list;
  }

  String _qty(num n) =>
      n == n.roundToDouble() ? '${n.round()}' : n.toString();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isWholesale = app.isWholesale;
    final discount = resolveProductLevelDiscountPercent(product.discounts);
    final options = _options(isWholesale);
    if (options.isNotEmpty && !options.any((o) => o.key == _selectedPres)) {
      _selectedPres = options.first.key;
    }

    final selected = options.where((o) => o.key == _selectedPres).toList();
    final selectedOpt = selected.isNotEmpty
        ? selected.first
        : (options.isNotEmpty ? options.first : null);

    var unit = selectedOpt?.price ?? product.price ?? 0;
    final catalog = unit;
    if (discount > 0) {
      unit = redondear(unit * (1 - discount / 100));
    }
    final display = getCasheaAdjustedUnitPrice(
      unit,
      isWholesale ? _selectedPres : 'Unidad',
      app.isCashea && isWholesale,
    );
    final strike = discount > 0
        ? getCasheaAdjustedUnitPrice(
            catalog,
            isWholesale ? _selectedPres : 'Unidad',
            app.isCashea && isWholesale,
          )
        : null;

    final inCart = app.carrito.any((c) => c.id == product.id);
    final canAdd =
        selectedOpt?.stockOk ?? isStockAllowedForAddToCart(product.stock);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .product-image web ≈ 120px en móvil
          SizedBox(
            height: 110,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: product.displayImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.displayImage,
                          fit: BoxFit.contain,
                          placeholder: (_, _) => const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, _, _) => const Center(
                            child: Text('📦', style: TextStyle(fontSize: 32)),
                          ),
                        )
                      : const Center(
                          child: Text('📦', style: TextStyle(fontSize: 32)),
                        ),
                ),
                if (discount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.discount,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'OFERTA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14, // 0.875rem web
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (isWholesale && options.isNotEmpty)
                    _PresentationSelector(
                      options: options,
                      selected: _selectedPres,
                      onSelect: (k) => setState(() => _selectedPres = k),
                      isCashea: app.isCashea,
                    )
                  else
                    Text(
                      'Precio unitario',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.retail,
                      ),
                    ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: discount > 0 && strike != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '\$${_priceFmt.format(strike)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textLight,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  Text(
                                    '\$${_priceFmt.format(display)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.discount,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '\$${_priceFmt.format(display)}',
                                style: const TextStyle(
                                  fontSize: 16, // 1rem web
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                      _AddBtn(
                        inCart: inCart,
                        canAdd: canAdd,
                        onAdd: () => app.agregarProductoAlCarritoCompleto(
                          product,
                          presentacion:
                              isWholesale ? _selectedPres : 'Unidad',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPres {
  const _CardPres({
    required this.key,
    required this.label,
    required this.qtyLabel,
    required this.price,
    required this.stockOk,
  });

  final String key;
  final String label;
  final String qtyLabel;
  final double price;
  final bool stockOk;
}

class _PresentationSelector extends StatelessWidget {
  const _PresentationSelector({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.isCashea,
  });

  final List<_CardPres> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool isCashea;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: o.stockOk ? () => onSelect(o.key) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  decoration: BoxDecoration(
                    color: !o.stockOk
                        ? const Color(0xFFE2E8F0)
                        : selected == o.key
                            ? Colors.white
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: !o.stockOk
                          ? Colors.transparent
                          : selected == o.key
                              ? AppColors.primary
                              : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: selected == o.key && o.stockOk
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Opacity(
                    opacity: o.stockOk ? 1 : 0.45,
                    child: Column(
                      children: [
                        Text(
                          o.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12, // 0.75rem web
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          o.qtyLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10, // 0.625rem web
                            color: AppColors.textLight,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${_priceFmt.format(getCasheaAdjustedUnitPrice(o.price, o.key, isCashea))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12, // 0.75rem web
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddBtn extends StatelessWidget {
  const _AddBtn({
    required this.inCart,
    required this.canAdd,
    required this.onAdd,
  });

  final bool inCart;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (inCart) {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 18),
      );
    }
    if (!canAdd) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF1F5F9),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
        ),
        child: const Icon(
          Icons.inventory_2_outlined,
          size: 16,
          color: Color(0xFF64748B),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAdd,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 20),
        ),
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
        child: Text(
          'No hay productos',
          style: TextStyle(color: AppColors.textLight),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Proporción web: tarjeta más alta, tipografía legible
        childAspectRatio: 0.58,
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
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'No se pudieron cargar las categorías.\nDesliza hacia abajo o reintenta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Future.wait([
                  app.loadCategorias(),
                  app.loadSedes(),
                  app.loadBestSellers(),
                  app.loadBanners(),
                  app.loadDailyOffers(),
                ]);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
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
                    errorWidget: (_, _, _) => Text(
                      cat.icon ?? '🛒',
                      style: const TextStyle(fontSize: 28),
                    ),
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
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final sub = subs[i];
              final name = (sub['value'] ??
                      sub['nombre'] ??
                      sub['name'] ??
                      'Subcategoría')
                  .toString();
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  side: const BorderSide(color: AppColors.border),
                ),
                tileColor: AppColors.cardBg,
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
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
