import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/cart_payment_modality.dart';
import '../constants/venezuela_banks.dart';
import '../models/models.dart';
import '../models/payment_store_settings.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../utils/delivery_cost.dart';
import '../utils/pricing.dart';
import '../widgets/add_products_modal.dart';
import '../widgets/delivery_map_section.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    this.embedded = false,
    this.initialCart,
    this.initialPaymentModality,
  });

  final bool embedded;
  final List<CartItem>? initialCart;
  final String? initialPaymentModality;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int _step = 0;
  String _deliveryType = 'pickup';
  double _bcvRate = 0;
  double _deliveryCost = 0;
  DeliveryCostRates _deliveryRates = DeliveryCostRates.defaults;
  bool _loadingRates = false;
  double? _deliveryDistanceKm;
  LatLng? _deliveryDest;
  String? _deliveryAddress;
  String? _deliveryLocationName;

  final _refCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountBsCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  String _destBank = '';
  String _issuerBank = '';
  Uint8List? _paymentImage;
  String? _paymentImageName;
  Map<String, dynamic>? _ocrResult;
  String _parseStatus = 'idle'; // idle | loading | ok | error
  String _parseMessage = '';
  PaymentStoreSettings _pagoMovilStore = PaymentStoreSettings.defaults;

  String? _createdOrderId;
  bool _submitting = false;
  String? _error;

  final _api = ApiService();
  final _firebase = FirebaseService();
  final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _fmtBs = NumberFormat('#,##0.00');

  List<CartItem> get _cart =>
      widget.initialCart ?? context.read<AppProvider>().carrito;

  String? get _modality =>
      widget.initialPaymentModality ??
      context.read<AppProvider>().cartPaymentModality;

  bool get _isCashea => _modality == CartPaymentModality.cashea;

  double get _subtotal =>
      _cart.fold(0.0, (s, i) => s + i.totalAux);

  double get _deliveryFee =>
      _deliveryType == 'delivery' ? _deliveryCost : 0;

  double get _total => redondear(_subtotal + _deliveryFee);

  double get _totalBs =>
      _bcvRate > 0 ? redondear(_total * _bcvRate) : 0;

  @override
  void initState() {
    super.initState();
    _loadRates();
    _loadPagoMovilStore();
  }

  Future<void> _loadRates() async {
    setState(() => _loadingRates = true);
    try {
      final results = await Future.wait([
        _api.fetchBcvRate(),
        _api.fetchDeliveryCost(),
      ]);
      _bcvRate = results[0] as double;
      final delivery = results[1] as Map<String, dynamic>;
      _deliveryRates = DeliveryCostRates.fromApi(delivery);
      // Sin destino aún: no fijar costo fijo; se calcula con el mapa.
      if (_deliveryType == 'pickup') {
        _deliveryCost = 0;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingRates = false);
  }

  Future<void> _loadPagoMovilStore() async {
    final settings = await _firebase.fetchPagoMovilStore();
    if (mounted) setState(() => _pagoMovilStore = settings);
  }

  Future<void> _copyDetail(String label, String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickPaymentImage() async {
    final picker = ImagePicker();
    // Como la web: input type=file (galería), no cámara.
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final name = file.name.toLowerCase();
    final okExt = name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp');
    if (!okExt) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para leer el comprobante automáticamente usa JPG, PNG o WebP.',
          ),
        ),
      );
      return;
    }
    final bytes = await file.readAsBytes();
    setState(() {
      _paymentImage = bytes;
      _paymentImageName = file.name;
      _ocrResult = null;
      _parseStatus = 'loading';
      _parseMessage = 'Leyendo datos del comprobante…';
    });
    try {
      final result = await _api.parsePaymentImage(bytes, file.name);
      final data = result['data'] ?? result;
      if (!mounted) return;
      setState(() {
        _ocrResult = result;
        if (data is Map) {
          _applyParsedPaymentData(Map<String, dynamic>.from(data));
        }
        _parseStatus = 'ok';
        _parseMessage =
            'Datos extraídos. Revisa y corrige los campos si hace falta.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _parseStatus = 'error';
        _parseMessage = e.toString().replaceFirst('Exception: ', '').isNotEmpty
            ? e.toString().replaceFirst('Exception: ', '')
            : 'No se pudo analizar la imagen. Completa los datos manualmente.';
      });
    }
  }

  void _applyParsedPaymentData(Map<String, dynamic> data) {
    final ref = (data['ref'] ?? data['reference'] ?? data['referencia'])
        ?.toString()
        .trim();
    if (ref != null && ref.isNotEmpty) _refCtrl.text = ref;

    final destRaw = [
      data['destination_bank'],
      data['destinationBank'],
    ].map((x) => x?.toString().trim()).firstWhere(
          (x) => x != null && x.isNotEmpty,
          orElse: () => null,
        );
    if (destRaw != null) _destBank = resolveBankName(destRaw);

    final issuerRaw = [
      data['issuer_bank'],
      data['issuerBank'],
      data['issuerBankCode'],
    ].map((x) => x?.toString().trim()).firstWhere(
          (x) => x != null && x.isNotEmpty,
          orElse: () => null,
        );
    if (issuerRaw != null) _issuerBank = resolveBankName(issuerRaw);

    final amount = data['amount'];
    if (amount != null) {
      final n = amount is num ? amount.toDouble() : double.tryParse('$amount');
      if (n != null && n.isFinite) {
        _amountBsCtrl.text = n.toString();
      }
    }
  }

  void _clearPaymentUpload() {
    setState(() {
      _paymentImage = null;
      _paymentImageName = null;
      _ocrResult = null;
      _parseStatus = 'idle';
      _parseMessage = '';
      _refCtrl.clear();
      _phoneCtrl.clear();
      _amountBsCtrl.clear();
      _destBank = '';
      _issuerBank = '';
    });
  }

  String? _validatePaymentProof() {
    if (_isCashea) return null;
    if (_paymentImage == null) return 'Sube el comprobante de pago.';
    if (_refCtrl.text.trim().isEmpty) {
      return 'Ingresa la referencia o número de operación.';
    }
    if (_destBank.trim().isEmpty) return 'Selecciona el banco de destino.';
    if (_issuerBank.trim().isEmpty) return 'Selecciona el banco emisor.';
    final amount = double.tryParse(
      _amountBsCtrl.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      return 'Ingresa el monto pagado en Bs (debe ser mayor a cero).';
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      return 'Ingresa el teléfono del pagador.';
    }
    return null;
  }

  Future<void> _createOrder() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final provider = context.read<AppProvider>();
      final user = provider.user;
      if (user == null) throw Exception('Debes iniciar sesión');

      if (_isCashea) {
        final validation = await _api.validateCredit({
          'uid': user.uid,
          'total': _total,
          'items': _cart.map((e) => e.toJson()).toList(),
        });
        if (validation['valid'] != true && validation['success'] != true) {
          throw Exception(
            validation['message']?.toString() ?? 'Crédito Cashea no disponible',
          );
        }
      }

      final productos = _cart.map((e) => e.toJson()).toList();
      final deliveryType =
          _deliveryType == 'delivery' ? 'delivery' : 'pickup';
      final sede = provider.sedeSeleccionada;
      final numeroPedido = await _api.fetchNextOrderNumber();
      final orderId = '$numeroPedido';
      final now = DateTime.now();
      final fecha =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      final orderData = <String, dynamic>{
        // Campos alineados con la web (impresora / admin / Mis pedidos)
        'fecha': fecha,
        'productos': productos,
        'idUser': user.uid,
        'uid': user.uid,
        'nombreUser': user.nombre,
        'telefonoUser': user.telefono,
        'documento': user.documento,
        'email': user.email,
        'numeroPedido': numeroPedido,
        'costoTotal': _total,
        'products_total': _subtotal,
        'shipping_cost': _deliveryFee,
        'status': 'Pendiente',
        'colorStatus': '#868e96',
        'preparation_status': 'Pendiente',
        'condicion': _isCashea ? 'Credito' : 'Contado',
        'payment_method': _isCashea ? 'credit' : 'cash',
        'trash': false,
        'viewOrder': false,
        'viewOrderPrinter': false,
        'impreso': false,
        'checkOrder': 'noVerificado',
        'type': 'order',
        'plataform': 'APP',
        'delivery_type': deliveryType,
        if (deliveryType == 'delivery') 'checkDelivery': 'Pendiente',
        'delivery_address': _deliveryAddress,
        'order_comment': _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
        'currency': {'name': 'USD', 'symbol': '\$'},
        'payment': {
          'total_paid': 0,
          'total_rest': _total,
          'status': 'Pendiente',
        },
        if (sede != null)
          'branch': {
            'id': sede.id,
            'name': sede.name,
          },
        if (_bcvRate > 0) 'tasa_dolar': double.parse(_bcvRate.toStringAsFixed(4)),
        // Compat app
        'items': productos,
        'subtotal': _subtotal,
        'deliveryType': deliveryType,
        'deliveryCost': _deliveryFee,
        'deliveryDistanceKm': _deliveryDistanceKm,
        'deliveryAddress': _deliveryAddress,
        'deliveryLocationName': _deliveryLocationName,
        if (_deliveryDest != null) ...{
          'deliveryLat': _deliveryDest!.latitude,
          'deliveryLng': _deliveryDest!.longitude,
        },
        'total': _total,
        'totalBs': _totalBs,
        'bcvRate': _bcvRate,
        'paymentModality': _modality,
        'comentario': _commentCtrl.text.trim(),
        'branchId': sede?.id,
        'modo': provider.modo,
        'createdAt': now.toIso8601String(),
      };

      await _firebase.createOrder(orderData, docId: orderId);

      if (_paymentImage != null) {
        final ext = _paymentImageName?.split('.').last ?? 'jpg';
        final url = await _firebase.uploadPaymentImage(
          orderId,
          _paymentImage!.toList(),
          ext,
        );
        await _firebase.createPayment(
          {
            'id': numeroPedido,
            'orderId': orderId,
            'uid': user.uid,
            'idUser': user.uid,
            'type': 'Pago móvil',
            'reference': _refCtrl.text.trim(),
            'ref': _refCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'telefonoPagador': _phoneCtrl.text.trim(),
            'bancoEmisor': _issuerBank,
            'bancoDestino': _destBank,
            'bank': _issuerBank,
            'imageUrl': url,
            'capture': url,
            'ocr': _ocrResult,
            'amount': _total,
            'amountBs': double.tryParse(
                  _amountBsCtrl.text.trim().replaceAll(',', '.'),
                ) ??
                _totalBs,
            'monto': double.tryParse(
                  _amountBsCtrl.text.trim().replaceAll(',', '.'),
                ) ??
                _totalBs,
          },
          docId: orderId,
        );
      }

      await _api.notifyOrderCreated({
        'orderId': orderId,
        'numeroPedido': numeroPedido,
        'uid': user.uid,
      });
      // API espera `order` = número secuencial (no el docId aleatorio)
      await _api.notifyPrinter({
        'order': numeroPedido,
        'sede': sede?.raw['codigo'] ?? sede?.id,
      });

      if (!widget.embedded) {
        await provider.clearCart();
      }

      setState(() {
        _createdOrderId = orderId;
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = raw.contains('Sin conexión')
            ? raw
            : (raw.isEmpty ? 'No se pudo emitir el pedido.' : raw);
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _phoneCtrl.dispose();
    _amountBsCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escucha cambios del carrito/modalidad (los getters usan read para callbacks).
    context.watch<AppProvider>();
    return ColoredBox(
      color: AppColors.lightBg,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Confirmación de pedido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CheckoutProgress(step: _step),
                  if (!widget.embedded) ...[
                    const SizedBox(height: 4),
                    _ModalitySwitcher(
                      modality: _modality,
                      onChanged: (m) =>
                          context.read<AppProvider>().setCartPaymentModality(m),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    _ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 8),
                  switch (_step) {
                    0 => _buildOrderStep(),
                    1 => _buildPaymentStep(),
                    _ => _buildTrackingStep(),
                  },
                ],
              ),
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildOrderStep() {
    final provider = context.watch<AppProvider>();
    final user = provider.user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (user != null)
          _SectionCard(
            title: 'Bienvenido, ${user.displayName}',
            icon: Icons.account_circle,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    user.email ?? '',
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await provider.logout();
                    if (mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          _SectionCard(
            title: 'Resumen del Pedido',
            icon: Icons.receipt_long,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.featured),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Debes iniciar sesión para continuar.',
                      style: TextStyle(color: AppColors.textMedium),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Iniciar sesión'),
                  ),
                ],
              ),
            ),
          ),
        _SectionCard(
          title: 'Detalle de tu pedido',
          icon: Icons.inventory_2_outlined,
          child: Column(
            children: [
              if (_cart.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: const Color(0xFFFFECB5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          color: Color(0xFF856404), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No hay productos en el pedido.',
                          style: TextStyle(
                            color: Color(0xFF856404),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                for (var i = 0; i < _cart.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.border),
                  _CartLineItem(
                    item: _cart[i],
                    embedded: widget.embedded,
                    fmt: _fmt,
                  ),
                ],
              ],
              const SizedBox(height: 16),
              _AmountBreakdown(
                subtotal: _subtotal,
                deliveryFee: _deliveryFee,
                deliveryType: _deliveryType,
                total: _total,
                totalBs: _totalBs,
                bcvRate: _bcvRate,
                loadingRates: _loadingRates,
                fmt: _fmt,
                fmtBs: _fmtBs,
              ),
              if (!widget.embedded) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => showAddProductsModal(context),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Agregar Más Productos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
            ],
          ),
        ),
        _SectionCard(
          title: 'Comentario de la orden',
          icon: Icons.edit_note,
          child: TextField(
            controller: _commentCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Indicaciones especiales (opcional)',
              filled: true,
              fillColor: AppColors.lightBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        _SectionCard(
          title: 'Ubicación de entrega',
          icon: Icons.location_on_outlined,
          child: Column(
            children: [
              _DeliveryOption(
                selected: _deliveryType == 'pickup',
                icon: Icons.storefront_outlined,
                title: 'Retiro en tienda',
                subtitle: provider.sedeSeleccionada != null
                    ? provider.sedeSeleccionada!.name
                    : 'Sin costo adicional',
                onTap: () => setState(() {
                  _deliveryType = 'pickup';
                  _deliveryCost = 0;
                  _deliveryDistanceKm = null;
                }),
              ),
              const SizedBox(height: 10),
              _DeliveryOption(
                selected: _deliveryType == 'delivery',
                icon: Icons.delivery_dining,
                title: 'Delivery a domicilio',
                subtitle: _deliveryDistanceKm != null
                    ? 'Costo: ${_fmt.format(_deliveryCost)} · ${_deliveryDistanceKm!.toStringAsFixed(1)} km'
                    : 'Marca tu ubicación en el mapa',
                onTap: () => setState(() => _deliveryType = 'delivery'),
              ),
              if (_deliveryType == 'delivery')
                DeliveryMapSection(
                  rates: _deliveryRates,
                  onCostChanged: ({
                    required cost,
                    required distanceKm,
                    destination,
                    address,
                    locationName,
                  }) {
                    setState(() {
                      _deliveryCost = cost;
                      _deliveryDistanceKm = distanceKm;
                      _deliveryDest = destination;
                      _deliveryAddress = address;
                      _deliveryLocationName = locationName;
                    });
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStep() {
    final provider = context.watch<AppProvider>();
    final sedeName = provider.sedeSeleccionada?.name ?? '—';

    if (_isCashea) {
      return _SectionCard(
        title: 'Pago con Cashea',
        icon: Icons.credit_card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Con Cashea no necesitas subir comprobante aquí. Al confirmar se registra el pedido.',
              style: TextStyle(color: AppColors.textMedium, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Image.asset(
                  'assets/images/cashea.png',
                  height: 40,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.credit_card, size: 40),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Los bultos incluyen recargo del 5%.',
                    style: TextStyle(color: AppColors.textMedium, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PaymentSummaryCard(
              total: _total,
              totalBs: _totalBs,
              fmt: _fmt,
              fmtBs: _fmtBs,
              itemCount: _cart.length,
              subtotal: _subtotal,
              deliveryFee: _deliveryFee,
              deliveryType: _deliveryType,
            ),
          ],
        ),
      );
    }

    final store = _pagoMovilStore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: 'Realiza tu pago',
          icon: Icons.credit_card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sube el comprobante (el servicio puede completar parte de los datos). Todos los campos del formulario son obligatorios antes de emitir el pedido.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _PaymentSummaryCard(
                total: _total,
                totalBs: _totalBs,
                fmt: _fmt,
                fmtBs: _fmtBs,
                itemCount: _cart.length,
                subtotal: _subtotal,
                deliveryFee: _deliveryFee,
                deliveryType: _deliveryType,
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.shadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Datos de la tienda (referencia). El comprobante debe reflejar el monto indicado.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _BankDetailRow(
                      icon: Icons.account_balance,
                      label: 'Banco receptor (pago móvil)',
                      value: store.bankDisplay,
                      onCopy: () => _copyDetail(
                        'Código banco receptor',
                        store.bankCopy,
                      ),
                    ),
                    _BankDetailRow(
                      icon: Icons.badge_outlined,
                      label: 'RIF',
                      value: store.rifDisplay,
                      valuePrefix: store.rifTypeLetter,
                      valueSuffix: store.rifRest,
                      onCopy: () => _copyDetail(
                        'Documento (RIF)',
                        store.rifCopyDigits,
                      ),
                      footer: store.showForeignDocLegend ||
                              store.rifTypeLetter == 'E'
                          ? const Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                  height: 1.35,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        'Al indicar documento en el momento de pago seleccionar de tipo ',
                                  ),
                                  TextSpan(
                                    text: 'extranjero',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  TextSpan(text: '.'),
                                ],
                              ),
                            )
                          : null,
                    ),
                    _BankDetailRow(
                      icon: Icons.phone_android,
                      label: 'Teléfono (pago móvil)',
                      value: store.phoneFormatted,
                      onCopy: () =>
                          _copyDetail('Teléfono', store.phoneForCopy),
                    ),
                    _BankDetailRow(
                      icon: Icons.storefront_outlined,
                      label: 'Sucursal',
                      value: sedeName,
                    ),
                    _BankDetailRow(
                      icon: Icons.payments_outlined,
                      label: 'Total orden',
                      value: _totalBs > 0
                          ? 'Bs. ${_fmtBs.format(_totalBs)} · ${_fmt.format(_total)}'
                          : _fmt.format(_total),
                      onCopy: _totalBs > 0
                          ? () => _copyDetail(
                                'Monto Bs',
                                _totalBs.toStringAsFixed(2),
                              )
                          : null,
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _parseStatus == 'loading' ? null : _pickPaymentImage,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Subir comprobante'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 2),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'JPG, PNG o WebP (obligatorio). Al seleccionar la imagen se envía al servicio de lectura del comprobante.',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ),
              if (_paymentImage != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  child: Image.memory(
                    _paymentImage!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: _clearPaymentUpload,
                  child: const Text('Quitar imagen'),
                ),
              ],
              if (_parseStatus != 'idle') ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _parseStatus == 'loading'
                        ? const Color(0xFFEFF6FF)
                        : _parseStatus == 'ok'
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        width: 4,
                        color: _parseStatus == 'loading'
                            ? AppColors.primary
                            : _parseStatus == 'ok'
                                ? AppColors.success
                                : AppColors.discount,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_parseStatus == 'loading') ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          _parseMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: _parseStatus == 'error'
                                ? AppColors.discount
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Datos del pago',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CheckoutField(
                controller: _refCtrl,
                label: 'Referencia / número de operación',
                hint: 'Ej. últimos dígitos o referencia completa',
              ),
              const SizedBox(height: 12),
              _BankDropdown(
                label: 'Banco de destino (receptor)',
                value: _destBank,
                extraValue: _destBank.isNotEmpty &&
                        !venezuelaBanks.any((b) => b.name == _destBank)
                    ? _destBank
                    : null,
                onChanged: (v) => setState(() => _destBank = v ?? ''),
              ),
              const SizedBox(height: 12),
              _BankDropdown(
                label: 'Banco emisor (pagador)',
                value: _issuerBank,
                extraValue: _issuerBank.isNotEmpty &&
                        !venezuelaBanks.any((b) => b.name == _issuerBank)
                    ? _issuerBank
                    : null,
                onChanged: (v) => setState(() => _issuerBank = v ?? ''),
              ),
              const SizedBox(height: 12),
              _CheckoutField(
                controller: _amountBsCtrl,
                label: 'Monto pagado (Bs)',
                hint: '0.00',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _CheckoutField(
                controller: _phoneCtrl,
                label: 'Teléfono del pagador',
                hint: 'Ej. 04141234567',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              Text(
                'Fecha del pago (automatica): ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _totalBs > 0
                    ? 'Total (Bs): Bs. ${_fmtBs.format(_totalBs)}'
                    : 'Total: ${_fmt.format(_total)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _loadingRates
                    ? 'Cargando tasa...'
                    : _bcvRate > 0
                        ? 'Tasa BCV: Bs. ${_fmtBs.format(_bcvRate)}'
                        : 'Tasa BCV no disponible',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingStep() {
    return _SectionCard(
      title: 'Seguimiento de tu pedido',
      icon: Icons.route,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: AppColors.success, size: 36),
          ),
          const SizedBox(height: 12),
          const Text(
            '¡Pedido creado!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Número de pedido: #$_createdOrderId',
            style: const TextStyle(color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          const _TrackingFlow(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  context.push('/order-view-v2/$_createdOrderId'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
              ),
              child: const Text('Ver detalle del pedido'),
            ),
          ),
          if (!widget.embedded) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 2),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                ),
                child: const Text('Seguir comprando'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_step == 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _submitting ? null : () => setState(() => _step--),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                  ),
                  child: const Text('Atrás'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          if (_step == 0) {
                            if (_cart.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Agrega productos al carrito antes de continuar.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final user = context.read<AppProvider>().user;
                            if (user == null) {
                              context.push('/login');
                              return;
                            }
                            if (_deliveryType == 'delivery' &&
                                _deliveryDest == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Marca tu ubicación en el mapa para continuar',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() => _step = 1);
                          } else {
                            if (_step == 1) {
                              final err = _validatePaymentProof();
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err)),
                                );
                                return;
                              }
                            }
                            _createOrder();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _step == 0
                              ? 'Continuar al pago'
                              : (_isCashea ? 'Pagar con Cashea' : 'Emitir Pedido'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared visual pieces (alineados a temp-order.css / ShoppingCar) ───

class _CheckoutProgress extends StatelessWidget {
  const _CheckoutProgress({required this.step});
  final int step;

  static const _labels = ['Orden', 'Pago', 'Seguimiento'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < step
                          ? AppColors.success
                          : i == step
                              ? AppColors.primary
                              : Colors.white,
                      border: Border.all(
                        color: i < step
                            ? AppColors.success
                            : i == step
                                ? AppColors.primary
                                : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                      boxShadow: i == step
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 0,
                                spreadRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                    child: i < step
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: i == step
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          i == step ? FontWeight.w600 : FontWeight.w500,
                      color: i < step
                          ? const Color(0xFF059669)
                          : i == step
                              ? AppColors.primary
                              : AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            if (i < 2)
              Container(
                width: 20,
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i < step ? AppColors.success : const Color(0xFFCBD5E1),
              ),
          ],
        ],
      ),
    );
  }
}

class _ModalitySwitcher extends StatelessWidget {
  const _ModalitySwitcher({
    required this.modality,
    required this.onChanged,
  });

  final String? modality;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isPm = modality == CartPaymentModality.pagoMovil || modality == null;
    final isCashea = modality == CartPaymentModality.cashea;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Método de pago',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModalityChip(
                    label: 'Pago Móvil',
                    active: isPm && !isCashea,
                    activeColor: const Color(0xFF4F46E5),
                    onTap: () => onChanged(CartPaymentModality.pagoMovil),
                  ),
                ),
                Expanded(
                  child: _ModalityChip(
                    label: 'Cashea',
                    active: isCashea,
                    activeColor: const Color(0xFF854D0E),
                    onTap: () => onChanged(CartPaymentModality.cashea),
                  ),
                ),
              ],
            ),
          ),
          if (isCashea)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Los bultos incluyen un recargo del 5% con Cashea.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModalityChip extends StatelessWidget {
  const _ModalityChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      elevation: active ? 1 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? activeColor : AppColors.textLight,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.discountBg,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.discount.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.discount, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.discount, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLineItem extends StatelessWidget {
  const _CartLineItem({
    required this.item,
    required this.embedded,
    required this.fmt,
  });

  final CartItem item;
  final bool embedded;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final hasDiscount = item.precioOri > 0 && item.precio < item.precioOri;
    final discountPercent = hasDiscount
        ? (((item.precioOri - item.precio) / item.precioOri) * 100).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.imgUrl100 != null && item.imgUrl100!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imgUrl100!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const Icon(
                          Icons.image_outlined,
                          color: AppColors.textMedium,
                        ),
                      )
                    : const Icon(Icons.image_outlined,
                        color: AppColors.textMedium),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textDark,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          fmt.format(item.precio),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: hasDiscount
                                ? AppColors.discount
                                : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Cód: ${item.codigo ?? item.id}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                        if (discountPercent > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.discountBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-$discountPercent%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.discount,
                              ),
                            ),
                          ),
                          Text(
                            fmt.format(item.precioOri),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.presentacion,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (item.casheaSurchargeApplied) ...[
                            const SizedBox(width: 6),
                            const Text(
                              '+Cashea',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.wholesale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!embedded)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.lightBg,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: AppColors.shadowSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QtyBtn(
                        icon: Icons.remove,
                        onTap: () => provider.updateCartQty(
                          item.id,
                          item.presentacion,
                          item.cantidad - 1,
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${item.cantidad}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      _QtyBtn(
                        icon: Icons.add,
                        onTap: () => provider.updateCartQty(
                          item.id,
                          item.presentacion,
                          item.cantidad + 1,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'x${item.cantidad}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              if (!embedded) ...[
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () =>
                        provider.removeFromCart(item.id, item.presentacion),
                    borderRadius: BorderRadius.circular(8),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.delete_outline,
                          size: 18, color: AppColors.discount),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                fmt.format(item.totalAux),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: AppColors.textMedium),
        ),
      ),
    );
  }
}

class _AmountBreakdown extends StatelessWidget {
  const _AmountBreakdown({
    required this.subtotal,
    required this.deliveryFee,
    required this.deliveryType,
    required this.total,
    required this.totalBs,
    required this.bcvRate,
    required this.loadingRates,
    required this.fmt,
    required this.fmtBs,
  });

  final double subtotal;
  final double deliveryFee;
  final String deliveryType;
  final double total;
  final double totalBs;
  final double bcvRate;
  final bool loadingRates;
  final NumberFormat fmt;
  final NumberFormat fmtBs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _BreakdownRow(label: 'Subtotal', value: fmt.format(subtotal)),
          const SizedBox(height: 10),
          _BreakdownRow(
            label: 'Envío',
            value: deliveryType == 'delivery' && deliveryFee > 0
                ? fmt.format(deliveryFee)
                : 'Gratis',
          ),
          const Divider(height: 24, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (totalBs > 0)
                    Text(
                      'Bs. ${fmtBs.format(totalBs)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  Text(
                    fmt.format(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: loadingRates
                ? const SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : Text(
                    bcvRate > 0
                        ? 'Tasa BCV: Bs. ${fmtBs.format(bcvRate)}'
                        : 'Tasa BCV no disponible',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textDark)),
        Text(value, style: const TextStyle(color: AppColors.textDark)),
      ],
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.06)
          : AppColors.lightBg,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.textLight,
                size: 22,
              ),
              const SizedBox(width: 12),
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({
    required this.total,
    required this.totalBs,
    required this.fmt,
    required this.fmtBs,
    this.itemCount = 0,
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.deliveryType = 'pickup',
  });

  final double total;
  final double totalBs;
  final NumberFormat fmt;
  final NumberFormat fmtBs;
  final int itemCount;
  final double subtotal;
  final double deliveryFee;
  final String deliveryType;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      child: Column(
        children: [
          if (itemCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Productos',
                    style: TextStyle(color: AppColors.textDark)),
                Text(
                  '$itemCount artículo(s)',
                  style: const TextStyle(color: AppColors.textDark),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal',
                    style: TextStyle(color: AppColors.textDark)),
                Text(fmt.format(subtotal),
                    style: const TextStyle(color: AppColors.textDark)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Envío',
                    style: TextStyle(color: AppColors.textDark)),
                Text(
                  deliveryType == 'delivery' && deliveryFee > 0
                      ? fmt.format(deliveryFee)
                      : 'Gratis',
                  style: const TextStyle(color: AppColors.textDark),
                ),
              ],
            ),
            const Divider(height: 20, color: AppColors.border),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total a pagar',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textDark,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (totalBs > 0)
                    Text(
                      'Bs. ${fmtBs.format(totalBs)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  Text(
                    fmt.format(total),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BankDetailRow extends StatelessWidget {
  const _BankDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valuePrefix,
    this.valueSuffix,
    this.onCopy,
    this.footer,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? valuePrefix;
  final String? valueSuffix;
  final VoidCallback? onCopy;
  final Widget? footer;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF334155),
                      height: 1.35,
                    ),
                    children: [
                      TextSpan(
                        text: '$label: ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (valuePrefix != null)
                        TextSpan(
                          text: valuePrefix,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      TextSpan(
                        text: valueSuffix ??
                            (valuePrefix == null ? value : ''),
                      ),
                    ],
                  ),
                ),
              ),
              if (onCopy != null)
                IconButton(
                  onPressed: onCopy,
                  tooltip: 'Copiar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy, size: 18),
                  color: AppColors.primary,
                ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}

class _BankDropdown extends StatelessWidget {
  const _BankDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    this.extraValue,
  });

  final String label;
  final String value;
  final String? extraValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '',
        child: Text('Seleccione un banco'),
      ),
      ...venezuelaBanks.map(
        (b) => DropdownMenuItem(
          value: b.name,
          child: Text(b.label, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];
    if (extraValue != null &&
        extraValue!.isNotEmpty &&
        !venezuelaBanks.any((b) => b.name == extraValue)) {
      items.add(
        DropdownMenuItem(
          value: extraValue,
          child: Text(
            '$extraValue (texto detectado)',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    final effectiveValue = value.isEmpty
        ? ''
        : (items.any((i) => i.value == value) ? value : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMedium,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: effectiveValue.isEmpty ? '' : effectiveValue,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.lightBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckoutField extends StatelessWidget {
  const _CheckoutField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMedium,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.lightBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackingFlow extends StatelessWidget {
  const _TrackingFlow();

  @override
  Widget build(BuildContext context) {
    Widget step({
      required String label,
      required String date,
      required _TrackState state,
    }) {
      final Color dotColor;
      final Color labelColor;
      switch (state) {
        case _TrackState.completed:
          dotColor = AppColors.success;
          labelColor = const Color(0xFF059669);
        case _TrackState.active:
          dotColor = AppColors.primary;
          labelColor = AppColors.primary;
        case _TrackState.pending:
          dotColor = const Color(0xFFCBD5E1);
          labelColor = AppColors.textLight;
      }

      return Expanded(
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state == _TrackState.pending ? Colors.white : dotColor,
                border: Border.all(color: dotColor, width: 2),
              ),
              child: state == _TrackState.completed
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            Text(
              date,
              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        step(
          label: 'Orden',
          date: 'Registrada',
          state: _TrackState.completed,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 13),
          child: Container(width: 24, height: 2, color: AppColors.success),
        ),
        step(
          label: 'Pago',
          date: 'En curso',
          state: _TrackState.active,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 13),
          child: Container(width: 24, height: 2, color: const Color(0xFFCBD5E1)),
        ),
        step(
          label: 'Entregado',
          date: 'Pendiente',
          state: _TrackState.pending,
        ),
      ],
    );
  }
}

enum _TrackState { completed, active, pending }
