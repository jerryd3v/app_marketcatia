import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/cart_payment_modality.dart';
import '../models/campaign_product.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/promo_service.dart';
import '../utils/pricing.dart';

class AppProvider extends ChangeNotifier {
  AppProvider({
    ApiService? api,
    FirebaseService? firebase,
    PromoService? promo,
  })  : _api = api ?? ApiService(),
        _firebase = firebase ?? FirebaseService(),
        _promo = promo ?? PromoService();

  final ApiService _api;
  final FirebaseService _firebase;
  final PromoService _promo;

  ApiService get api => _api;
  FirebaseService get firebase => _firebase;
  PromoService get promo => _promo;

  final FocusNode searchFocusNode = FocusNode();

  static const _cartKey = 'marketcatia_cart';
  static const _userKey = 'marketcatia_user';
  static const _modalityKey = CartPaymentModality.key;
  static const _modoKey = 'marketcatia_modo';
  static const _sedeKey = 'marketcatia_sede';

  List<CartItem> carrito = [];
  AppUser? user;
  String vistaActual = 'categories';
  String busqueda = '';
  List<Product> resultadosBusqueda = [];
  String modo = 'wholesale';
  List<CategoryItem> categorias = [];
  CategoryItem? categoriaSeleccionada;
  Map<String, dynamic>? subcategoriaSeleccionada;
  List<Product> productosSubcategoria = [];
  List<Branch> sedes = [];
  Branch? sedeSeleccionada;
  String? cartPaymentModality;
  bool modeNotificationVisible = false;
  bool focusSearchRequest = false;
  String? productoIdParaScroll;
  List<Map<String, dynamic>> banners = [];
  Map<String, dynamic>? activeDailyOffer;
  List<CampaignProductView> dailyOfferProducts = [];
  bool cargandoOfertas = false;
  List<Product> bestSellers = [];

  bool loadingInit = false;
  bool cargandoCategorias = false;
  bool cargandoProductos = false;
  bool buscando = false;
  bool cargandoBanners = false;
  bool cargandoSedes = false;
  bool cargandoMasVendidos = false;
  bool firebaseReady = false;

  Timer? _searchDebounce;
  String? _pendingSedeId;

  CategoryItem? get categoriaActual => categoriaSeleccionada;
  Map<String, dynamic>? get subcategoriaActual => subcategoriaSeleccionada;

  double get totalPedido =>
      carrito.fold(0.0, (sum, item) => sum + item.totalAux);

  int get cartCount =>
      carrito.fold(0, (sum, item) => sum + item.cantidad);

  bool get isWholesale => modo == 'wholesale';
  bool get isCashea => cartPaymentModality == CartPaymentModality.cashea;

  Future<void> init() async {
    loadingInit = true;
    notifyListeners();
    try {
      await _loadPersisted();
      // Como la web: cada arranque vuelve a pedir modalidad de pago.
      cartPaymentModality = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_modalityKey);

      firebaseReady = Firebase.apps.isNotEmpty;
      if (firebaseReady) {
        await Future.wait([
          loadCategorias(),
          loadSedes(),
          loadBanners(),
          loadDailyOffers(),
          loadBestSellers(),
        ]);
        final fbUser = _firebase.auth.currentUser;
        if (fbUser != null && user == null) {
          final u = await _firebase.fetchUser(fbUser.uid);
          if (u != null) setUser(u);
        }
      }
    } catch (_) {
      firebaseReady = Firebase.apps.isNotEmpty;
    } finally {
      loadingInit = false;
      notifyListeners();
    }
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString(_cartKey);
    if (cartJson != null) {
      try {
        final list = jsonDecode(cartJson) as List;
        carrito = list
            .whereType<Map>()
            .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        cartPaymentModality = CartPaymentModality.parse(
          prefs.getString(_modalityKey),
        );
        carrito = syncCartLinesWithPaymentModality(
          carrito,
          cartPaymentModality,
        );
      } catch (_) {}
    }
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        user = AppUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(userJson) as Map),
        );
      } catch (_) {}
    }
    modo = prefs.getString(_modoKey) ?? 'wholesale';
    _pendingSedeId = prefs.getString(_sedeKey);
  }

  Future<void> _persistCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cartKey,
      jsonEncode(carrito.map((e) => e.toJson()).toList()),
    );
    if (cartPaymentModality != null) {
      await prefs.setString(_modalityKey, cartPaymentModality!);
    }
  }

  Future<void> _persistUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (user != null) {
      await prefs.setString(_userKey, jsonEncode(user!.toJson()));
    } else {
      await prefs.remove(_userKey);
    }
  }

  Future<void> loadCategorias() => _loadCategories();
  Future<void> loadSedes() => _loadBranches();
  Future<void> loadBanners() => _loadBanners();
  Future<void> loadDailyOffers() => _loadDailyOffers();
  Future<void> loadBestSellers() => _loadBestSellers();

  Future<void> _loadCategories() async {
    cargandoCategorias = true;
    notifyListeners();
    try {
      categorias = await _firebase.fetchCategories();
      // Ofertas necesitan categorías para etiquetas; re-resuelve si ya hay campaña.
      if (activeDailyOffer != null) {
        unawaited(_loadDailyOffers());
      }
    } catch (_) {
      categorias = [];
    } finally {
      cargandoCategorias = false;
      notifyListeners();
    }
  }

  void openCategoryById(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return;
    final cat = categorias.cast<CategoryItem?>().firstWhere(
          (c) => c!.id == categoryId || c.key == categoryId,
          orElse: () => null,
        );
    if (cat != null) setCategoria(cat);
  }

  void openSubcategoryByIds(String? categoryId, String? subcategoryId) {
    if (categoryId == null || subcategoryId == null) return;
    final cat = categorias.cast<CategoryItem?>().firstWhere(
          (c) => c!.id == categoryId || c.key == categoryId,
          orElse: () => null,
        );
    if (cat == null) return;
    categoriaSeleccionada = cat;
    final sub = cat.subCategories.cast<Map?>().firstWhere(
          (s) =>
              (s!['id'] ?? s['idSubCategory'] ?? '').toString() == subcategoryId,
          orElse: () => null,
        );
    if (sub == null) {
      setCategoria(cat);
      return;
    }
    setSubcategoria(Map<String, dynamic>.from(sub));
  }

  void goToCampaignProduct(CampaignProductView view) {
    openProductInCatalog(view.product, scrollToId: view.id);
  }

  void openProductInCatalog(Product product, {String? scrollToId}) {
    final raw = product.raw;
    final subCats = raw['sub_categories'] ?? raw['subCategories'];
    if (subCats is List && subCats.isNotEmpty) {
      final first = subCats.first;
      final subId = first is Map
          ? (first['id'] ?? first['_id'] ?? '').toString()
          : '';
      if (subId.isNotEmpty) {
        for (final cat in categorias) {
          final sub = cat.subCategories.cast<Map?>().firstWhere(
                (s) =>
                    (s!['id'] ?? s['_id'] ?? '').toString() == subId,
                orElse: () => null,
              );
          if (sub != null) {
            categoriaSeleccionada = cat;
            productoIdParaScroll = scrollToId ?? product.id;
            setSubcategoria(Map<String, dynamic>.from(sub));
            return;
          }
        }
      }
    }
    setBusqueda(product.name);
  }

  Future<void> _loadBranches() async {
    cargandoSedes = true;
    notifyListeners();
    try {
      sedes = await _firebase.fetchBranches();
      if (_pendingSedeId != null) {
        sedeSeleccionada = sedes.cast<Branch?>().firstWhere(
              (b) => b?.id == _pendingSedeId,
              orElse: () => sedes.isNotEmpty ? sedes.first : null,
            );
        _pendingSedeId = null;
      } else if (sedeSeleccionada == null && sedes.isNotEmpty) {
        sedeSeleccionada = sedes.first;
      }
    } catch (_) {
      sedes = [];
    } finally {
      cargandoSedes = false;
      notifyListeners();
    }
  }

  Future<void> _loadBanners() async {
    cargandoBanners = true;
    notifyListeners();
    try {
      banners = await _promo.fetchActivePromoBanners();
    } catch (_) {
      banners = [];
    } finally {
      cargandoBanners = false;
      notifyListeners();
    }
  }

  Future<void> _loadDailyOffers() async {
    cargandoOfertas = true;
    notifyListeners();
    try {
      final offer = await _promo.fetchActiveDailyOfferForToday();
      activeDailyOffer = offer;
      if (offer == null) {
        dailyOfferProducts = [];
      } else {
        dailyOfferProducts = await _promo.resolveCampaignProducts(
          offer,
          modo: modo,
          categorias: categorias,
          promoSource: 'daily_offer',
        );
      }
    } catch (_) {
      activeDailyOffer = null;
      dailyOfferProducts = [];
    } finally {
      cargandoOfertas = false;
      notifyListeners();
    }
  }

  Future<void> _loadBestSellers() async {
    cargandoMasVendidos = true;
    notifyListeners();
    try {
      bestSellers = await _firebase.fetchBestSellers();
    } catch (_) {
      bestSellers = [];
    } finally {
      cargandoMasVendidos = false;
      notifyListeners();
    }
  }

  Future<void> setCartPaymentModality(String modality) async {
    cartPaymentModality = modality;
    carrito = syncCartLinesWithPaymentModality(carrito, modality);
    await _persistCart();
    notifyListeners();
  }

  Future<void> cambiarModo(String newModo) async {
    if (modo == newModo) return;
    modo = newModo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modoKey, modo);
    await clearCart();
    modeNotificationVisible = true;
    notifyListeners();
    unawaited(_loadDailyOffers());
    Future.delayed(const Duration(seconds: 3), () {
      modeNotificationVisible = false;
      notifyListeners();
    });
  }

  void dismissModeNotification() {
    modeNotificationVisible = false;
    notifyListeners();
  }

  void resetHomeState() {
    vistaActual = 'categories';
    categoriaSeleccionada = null;
    subcategoriaSeleccionada = null;
    productosSubcategoria = [];
    busqueda = '';
    resultadosBusqueda = [];
    productoIdParaScroll = null;
    notifyListeners();
  }

  void openCategoria(CategoryItem cat) => setCategoria(cat);

  void setCategoria(CategoryItem cat) {
    categoriaSeleccionada = cat;
    subcategoriaSeleccionada = null;
    productosSubcategoria = [];
    vistaActual = cat.subCategories.isEmpty ? 'products' : 'subcategories';
    if (cat.subCategories.isEmpty) {
      _loadProductsForSubcategory(cat.id);
    }
    notifyListeners();
  }

  void openSubcategoria(Map<String, dynamic> sub) => setSubcategoria(sub);

  void setSubcategoria(Map<String, dynamic> sub) {
    subcategoriaSeleccionada = sub;
    vistaActual = 'products';
    final id = (sub['id'] ?? sub['key'] ?? '').toString();
    _loadProductsForSubcategory(id);
    notifyListeners();
  }

  Future<void> _loadProductsForSubcategory(String subId) async {
    if (subId.isEmpty) return;
    cargandoProductos = true;
    notifyListeners();
    try {
      productosSubcategoria = await _api.productsBySubcategory(subId);
    } catch (_) {
      productosSubcategoria = [];
    } finally {
      cargandoProductos = false;
      notifyListeners();
    }
  }

  void backToSubcategories() {
    if (vistaActual == 'products' &&
        categoriaSeleccionada != null &&
        categoriaSeleccionada!.subCategories.isNotEmpty) {
      vistaActual = 'subcategories';
      subcategoriaSeleccionada = null;
      productosSubcategoria = [];
    } else {
      resetHomeState();
    }
    notifyListeners();
  }

  void goBackHome() => backToSubcategories();

  void setBusqueda(String term) {
    busqueda = term;
    notifyListeners();
    _searchDebounce?.cancel();
    if (term.trim().length < 2) {
      resultadosBusqueda = [];
      notifyListeners();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      search(term);
    });
  }

  Future<void> search(String term) async {
    if (term.trim().length < 2) {
      resultadosBusqueda = [];
      notifyListeners();
      return;
    }
    buscando = true;
    notifyListeners();
    try {
      resultadosBusqueda = await _api.searchProducts(term);
    } catch (_) {
      resultadosBusqueda = [];
    } finally {
      buscando = false;
      notifyListeners();
    }
  }

  void requestSearchFocus() {
    focusSearchRequest = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (searchFocusNode.canRequestFocus) {
        searchFocusNode.requestFocus();
      }
      focusSearchRequest = false;
    });
    notifyListeners();
  }

  void clearSearchFocusRequest() {
    focusSearchRequest = false;
    notifyListeners();
  }

  Future<void> setSede(Branch branch) async {
    sedeSeleccionada = branch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sedeKey, branch.id);
    notifyListeners();
  }

  Future<void> setSedeSeleccionada(Branch? branch) async {
    if (branch == null) return;
    await setSede(branch);
  }

  String _defaultPresentacion(Product p) {
    if (isWholesale) {
      if (p.statusMayor && p.priceMayor != null) return 'Mayor';
      if (p.statusBulto && p.priceBulto != null) return 'Bulto';
    }
    return 'Unidad';
  }

  double _priceForPresentacion(Product p, String pres) {
    switch (pres) {
      case 'Mayor':
        return p.priceMayor ?? p.price ?? 0;
      case 'Bulto':
      case 'Caja':
      case 'Lote':
        return p.priceBulto ?? p.price ?? 0;
      default:
        return p.price ?? 0;
    }
  }

  Future<void> agregarProductoAlCarritoCompleto(
    Product product, {
    String? presentacion,
    int cantidad = 1,
  }) async {
    if (!isStockAllowedForAddToCart(product.stock)) return;
    final pres = presentacion ?? _defaultPresentacion(product);
    if (!isPresentationAllowedByStock(
      product.stock,
      getPresentationBaseUnits(product, pres),
    )) {
      return;
    }
    var unitPrice = _priceForPresentacion(product, pres);
    final discountPct = resolveProductLevelDiscountPercent(product.discounts);
    if (discountPct > 0) {
      unitPrice = redondear(unitPrice * (1 - discountPct / 100));
    }
    final catalogPrice = unitPrice;
    if (isCashea) {
      unitPrice = getCasheaAdjustedUnitPrice(unitPrice, pres, true);
    }

    final existingIdx = carrito.indexWhere(
      (c) => c.id == product.id && c.presentacion == pres,
    );
    if (existingIdx >= 0) {
      final item = carrito[existingIdx];
      item.cantidad += cantidad;
      item.totalAux = redondear(item.precio * item.cantidad);
      carrito[existingIdx] = item;
    } else {
      carrito.add(CartItem(
        id: product.id,
        nombre: product.name,
        codigo: product.codigo,
        precio: unitPrice,
        precioOri: catalogPrice,
        presentacion: pres,
        cantidad: cantidad,
        totalAux: redondear(unitPrice * cantidad),
        precioUnidad: product.price,
        precioMayor: product.priceMayor,
        precioBulto: product.priceBulto,
        cantidadBulto: product.cantidadBulto,
        cantidadUnidadOri: product.cantidadUnidad,
        cantidadMayorOri: product.cantidadMayor,
        cantidadBultoOri: product.cantidadBulto,
        imgUrl100: product.imgUrl100 ?? product.imgUrl,
        discounts: product.discounts,
        taxable: product.taxable,
        ivaRate: product.ivaRate,
        peso: product.peso,
        casheaSurchargeApplied: isCashea && presentationIsCasheaBulk(pres),
        precioCatalogoPresentacion: catalogPrice,
      ));
    }
    await _persistCart();
    notifyListeners();
  }

  /// Lógica del modal web `agregarProductoAlCarrito`: 1 producto por id por compra.
  /// Devuelve mensaje de error o `null` si se agregó.
  Future<String?> agregarProductoDesdeModalCarrito(
    Product product,
    String presentacion, {
    int cantidad = 1,
  }) async {
    if (presentacion.isEmpty) {
      return 'Seleccione una presentación';
    }
    if (!isPresentationAllowedByStock(
      product.stock,
      getPresentationBaseUnits(product, presentacion),
    )) {
      return 'Sin stock para esta presentación';
    }
    if (carrito.any((c) => c.id == product.id)) {
      return 'Este producto ya está en el carrito. Solo se puede agregar una vez por compra.';
    }

    final qty = cantidad < 1 ? 1 : cantidad;
    var unitPrice = _priceForPresentacion(product, presentacion);
    final discountPct = resolveProductLevelDiscountPercent(product.discounts);
    var precioFinal = unitPrice;
    if (discountPct > 0) {
      precioFinal = redondear(unitPrice * (1 - discountPct / 100));
    }
    final catalogPrice = unitPrice;
    if (isCashea && presentationIsCasheaBulk(presentacion)) {
      precioFinal = getCasheaAdjustedUnitPrice(unitPrice, presentacion, true);
    }

    carrito.add(CartItem(
      id: product.id,
      nombre: product.name,
      codigo: product.codigo,
      precio: precioFinal,
      precioOri: catalogPrice,
      presentacion: presentacion,
      cantidad: qty,
      totalAux: redondear(precioFinal * qty),
      precioUnidad: product.price,
      precioMayor: product.priceMayor,
      precioBulto: product.priceBulto,
      cantidadBulto: getPresentationBaseUnits(product, presentacion),
      cantidadUnidadOri: product.cantidadUnidad,
      cantidadMayorOri: product.cantidadMayor,
      cantidadBultoOri: product.cantidadBulto,
      imgUrl100: product.imgUrl100 ?? product.imgUrl,
      discounts: product.discounts,
      taxable: product.taxable,
      ivaRate: product.ivaRate,
      peso: product.peso,
      casheaSurchargeApplied:
          isCashea && presentationIsCasheaBulk(presentacion),
      precioCatalogoPresentacion: catalogPrice,
    ));
    await _persistCart();
    notifyListeners();
    return null;
  }

  Future<void> updateCartQty(String id, String presentacion, int qty) async {
    if (qty <= 0) {
      await removeFromCart(id, presentacion);
      return;
    }
    final idx = carrito.indexWhere(
      (c) => c.id == id && c.presentacion == presentacion,
    );
    if (idx < 0) return;
    final item = carrito[idx];
    item.cantidad = qty;
    item.totalAux = redondear(item.precio * qty);
    carrito[idx] = item;
    await _persistCart();
    notifyListeners();
  }

  Future<void> removeFromCart(String id, String presentacion) async {
    carrito.removeWhere(
      (c) => c.id == id && c.presentacion == presentacion,
    );
    await _persistCart();
    notifyListeners();
  }

  Future<void> clearCart() async {
    carrito = [];
    await _persistCart();
    notifyListeners();
  }

  void setUser(AppUser u) {
    user = u;
    _persistUser();
    notifyListeners();
  }

  Future<void> logout() async {
    await _firebase.signOut();
    user = null;
    await _persistUser();
    notifyListeners();
  }

  void setProductoIdParaScroll(String? id) {
    productoIdParaScroll = id;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchFocusNode.dispose();
    super.dispose();
  }
}
