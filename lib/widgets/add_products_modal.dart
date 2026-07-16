import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/pricing.dart';
import 'market_search_bar.dart';

Future<void> showAddProductsModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => const AddProductsModal(),
  );
}

/// Modal "Agregar productos" — estética 1:1 con search-modal web.
class AddProductsModal extends StatefulWidget {
  const AddProductsModal({super.key});

  @override
  State<AddProductsModal> createState() => _AddProductsModalState();
}

class _AddProductsModalState extends State<AddProductsModal> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  // Misma notación que la web: $3,50
  final _fmt = NumberFormat('#,##0.00', 'es');

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
        label: 'UND (${_qtyLabel(product.cantidadUnidad)})',
        price: product.price!,
      ));
    }
    if (product.priceMayor != null && product.statusMayor) {
      list.add(_PresOption(
        key: 'Mayor',
        label: 'Mayor (${_qtyLabel(product.cantidadMayor)})',
        price: product.priceMayor!,
      ));
    }
    if (product.priceBulto != null && product.statusBulto) {
      list.add(_PresOption(
        key: 'Bulto',
        label: 'Bulto (${_qtyLabel(product.cantidadBulto)})',
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

  String _qtyLabel(num n) {
    if (n == n.roundToDouble()) return n.round().toString();
    return n.toString();
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
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
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
      return parent.isEmpty
          ? subCats.join(' > ')
          : '$parent > ${subCats.join(' > ')}';
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
    final maxW = media.size.width > 680 ? 680.0 : media.size.width - 32;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Agregar productos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                // Search — misma estructura que .search-wrapper web
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: MarketSearchBar(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: (v) {
                      setState(() {});
                      _loadProducts(v);
                    },
                    fillColor: const Color(0xFFF8FAFC),
                    onClear: _searchCtrl.text.isNotEmpty
                        ? () {
                            _searchCtrl.clear();
                            setState(() {});
                            _loadProducts();
                          }
                        : null,
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                // Results
                Expanded(
                  child: _loading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                              color: Color(0xFF6366F1),
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : _products.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'Escribe al menos 2 caracteres o no hay resultados',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 14,
                                  ),
                                ),
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
                                  added:
                                      _addedKey == '${product.id}-$selected',
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
    final sellable =
        firebaseProductHasSellablePresentation(product, product.stock);
    final stockLevel = getStockLevel(product.stock);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image 56×56
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: (product.imgUrl100 ?? product.imgUrl)?.isNotEmpty == true
                    ? CachedNetworkImage(
                        imageUrl: product.imgUrl100 ?? product.imgUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF64748B),
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF64748B),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                        height: 1.3,
                      ),
                    ),
                    if (categoryLine != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        categoryLine!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    if (options.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final pres in options)
                            PresChipTag(
                              label:
                                  '${pres.label} \$${fmt.format(getCasheaAdjustedUnitPrice(pres.price, pres.key, isCashea))}',
                              selected: selectedPres == pres.key,
                              disabled: !pres.stockOk,
                              onTap: () => onSelectPres(pres.key),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '\$${fmt.format(displayPrice)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Action — círculo 36px como la web
              if (added)
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                )
              else if (!sellable)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                )
              else
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onAdd(selectedPres),
                    customBorder: const CircleBorder(),
                    child: Ink(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                      ),
                      child: const Icon(
                        Icons.add_shopping_cart,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Stock dot top-right
          Positioned(
            top: -2,
            right: -2,
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
                    StockLevel.critical => const Color(0xFFEF4444),
                    StockLevel.warning => const Color(0xFFF97316),
                    StockLevel.ok => const Color(0xFF22C55E),
                    StockLevel.unknown => const Color(0xFF94A3B8),
                  },
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
