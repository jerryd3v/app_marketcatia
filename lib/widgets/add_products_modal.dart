import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/pricing.dart';

Future<void> showAddProductsModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => const AddProductsModal(),
  );
}

/// Modal "Agregar productos" — paridad con `ShoppingCar.jsx` search-modal.
class AddProductsModal extends StatefulWidget {
  const AddProductsModal({super.key});

  @override
  State<AddProductsModal> createState() => _AddProductsModalState();
}

class _AddProductsModalState extends State<AddProductsModal> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _fmt = NumberFormat('#,##0.00');

  List<Product> _products = [];
  bool _loading = false;
  String? _addedKey;
  final Map<String, String> _selectedPres = {};
  int _requestGen = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadProducts([String? name]) async {
    final gen = ++_requestGen;
    setState(() {
      _loading = true;
      _products = [];
    });
    try {
      final list = await _api.reportProducts(
        name: (name == null || name.isEmpty) ? null : name,
      );
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _products = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _requestGen) return;
      setState(() => _loading = false);
    }
  }

  List<_PresOption> _presOptions(Product product) {
    final list = <_PresOption>[];
    if (product.price != null && product.statusUnidad) {
      list.add(_PresOption(
        key: 'Unidad',
        label: 'UND (${product.cantidadUnidad})',
        price: product.price!,
      ));
    }
    if (product.priceMayor != null && product.statusMayor) {
      list.add(_PresOption(
        key: 'Mayor',
        label: 'Mayor (${product.cantidadMayor})',
        price: product.priceMayor!,
      ));
    }
    if (product.priceBulto != null && product.statusBulto) {
      list.add(_PresOption(
        key: 'Bulto',
        label: 'Bulto (${product.cantidadBulto})',
        price: product.priceBulto!,
      ));
    }
    return list
        .map(
          (p) => p.copyWith(
            stockOk: isPresentationAllowedByStock(
              product.stock,
              getPresentationBaseUnits(product, p.key),
            ),
          ),
        )
        .toList();
  }

  String _resolveSelected(Product product, List<_PresOption> options) {
    final firstSellable = options.where((p) => p.stockOk).map((p) => p.key);
    final firstOk = firstSellable.isEmpty ? null : firstSellable.first;
    final raw = _selectedPres[product.id] ??
        firstOk ??
        (options.isNotEmpty ? options.first.key : 'Unidad');
    final rawEntry = options.where((p) => p.key == raw).toList();
    if (rawEntry.isNotEmpty &&
        rawEntry.first.stockOk == false &&
        firstOk != null) {
      return firstOk;
    }
    return raw;
  }

  String? _categoryLine(Product product) {
    final parent = (product.raw['categoria'] ?? product.raw['category'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    String cap(String s) => s
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) =>
            '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');

    final rawSubs = product.raw['sub_categories'];
    final subCats = <String>[];
    if (rawSubs is List) {
      for (final sc in rawSubs) {
        if (sc is Map && sc['name'] != null) {
          subCats.add(cap(sc['name'].toString()));
        } else if (sc != null && sc.toString().isNotEmpty) {
          subCats.add(cap(sc.toString()));
        }
      }
    }
    if (subCats.isNotEmpty) {
      final line = parent.isEmpty
          ? subCats.join(' > ')
          : '$parent > ${subCats.join(' > ')}';
      return line;
    }
    return parent.isEmpty ? null : parent;
  }

  Future<void> _add(Product product, String presentacion) async {
    final app = context.read<AppProvider>();
    final err = await app.agregarProductoDesdeModalCarrito(
      product,
      presentacion,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.discount,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _addedKey = '${product.id}-$presentacion');
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted && _addedKey == '${product.id}-$presentacion') {
      setState(() => _addedKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCashea = context.watch<AppProvider>().isCashea;
    final media = MediaQuery.of(context);
    final maxH = media.size.height * 0.85;
    final maxW = media.size.width.clamp(0, 680).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          elevation: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Agregar productos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textMedium),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: (v) => _loadProducts(v),
                  decoration: InputDecoration(
                    hintText: 'Buscar productos...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textLight,
                    ),
                    filled: true,
                    fillColor: AppColors.lightBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : _products.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Escribe al menos 2 caracteres o no hay resultados',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textLight),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              final options = _presOptions(product);
                              final selected =
                                  _resolveSelected(product, options);
                              return _ProductResultCard(
                                product: product,
                                options: options,
                                selectedPres: selected,
                                categoryLine: _categoryLine(product),
                                isCashea: isCashea,
                                added: _addedKey == '${product.id}-$selected',
                                fmt: _fmt,
                                onSelectPres: (key) {
                                  setState(
                                    () => _selectedPres[product.id] = key,
                                  );
                                },
                                onAdd: (pres) => _add(product, pres),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresOption {
  const _PresOption({
    required this.key,
    required this.label,
    required this.price,
    this.stockOk = true,
  });

  final String key;
  final String label;
  final double price;
  final bool stockOk;

  _PresOption copyWith({bool? stockOk}) => _PresOption(
        key: key,
        label: label,
        price: price,
        stockOk: stockOk ?? this.stockOk,
      );
}

class _ProductResultCard extends StatelessWidget {
  const _ProductResultCard({
    required this.product,
    required this.options,
    required this.selectedPres,
    required this.categoryLine,
    required this.isCashea,
    required this.added,
    required this.fmt,
    required this.onSelectPres,
    required this.onAdd,
  });

  final Product product;
  final List<_PresOption> options;
  final String selectedPres;
  final String? categoryLine;
  final bool isCashea;
  final bool added;
  final NumberFormat fmt;
  final ValueChanged<String> onSelectPres;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((p) => p.key == selectedPres);
    final catalogPrice =
        selected.isNotEmpty ? selected.first.price : (product.price ?? 0);
    final displayPrice =
        getCasheaAdjustedUnitPrice(catalogPrice, selectedPres, isCashea);
    final sellable = firebaseProductHasSellablePresentation(product, product.stock);
    final stockLevel = getStockLevel(product.stock);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowSm,
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.lightBg,
                ),
                clipBehavior: Clip.antiAlias,
                child: (product.imgUrl100 ?? product.imgUrl)?.isNotEmpty == true
                    ? CachedNetworkImage(
                        imageUrl: product.imgUrl100 ?? product.imgUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.textLight,
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.textLight,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (categoryLine != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        categoryLine!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                    if (options.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final pres in options)
                            GestureDetector(
                              onTap: pres.stockOk
                                  ? () => onSelectPres(pres.key)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: !pres.stockOk
                                      ? const Color(0xFFF1F5F9)
                                      : selectedPres == pres.key
                                          ? AppColors.primary
                                              .withValues(alpha: 0.12)
                                          : AppColors.lightBg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: !pres.stockOk
                                        ? AppColors.border
                                        : selectedPres == pres.key
                                            ? AppColors.primary
                                            : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  '${pres.label} \$${fmt.format(getCasheaAdjustedUnitPrice(pres.price, pres.key, isCashea))}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: !pres.stockOk
                                        ? const Color(0xFF94A3B8)
                                        : selectedPres == pres.key
                                            ? AppColors.primary
                                            : AppColors.textMedium,
                                    decoration: !pres.stockOk
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '\$${fmt.format(displayPrice)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (added)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check, color: AppColors.success),
                )
              else if (!sellable)
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.discountBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.remove_shopping_cart_outlined,
                    size: 20,
                    color: AppColors.discount,
                  ),
                )
              else
                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => onAdd(selectedPres),
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.add_shopping_cart,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: switch (stockLevel) {
                StockLevel.critical => 'Sin stock para venta',
                StockLevel.warning => 'Quedan pocas unidades',
                StockLevel.ok => 'Stock alto',
                StockLevel.unknown => 'Stock no indicado',
              },
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (stockLevel) {
                    StockLevel.critical => AppColors.discount,
                    StockLevel.warning => const Color(0xFFF97316),
                    StockLevel.ok => const Color(0xFF22C55E),
                    StockLevel.unknown => const Color(0xFF94A3B8),
                  },
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
