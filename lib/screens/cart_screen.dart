import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/cart_payment_modality.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../utils/pricing.dart';

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
  bool _loadingRates = false;

  // Pago móvil
  final _refCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  Uint8List? _paymentImage;
  String? _paymentImageName;
  Map<String, dynamic>? _ocrResult;
  Map<String, dynamic>? _pagoMovilStore;

  // Seguimiento
  String? _createdOrderId;
  bool _submitting = false;
  String? _error;

  final _api = ApiService();
  final _firebase = FirebaseService();
  final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

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
      _deliveryCost =
          ((delivery['cost'] ?? delivery['price'] ?? 0) as num).toDouble();
    } catch (_) {}
    if (mounted) setState(() => _loadingRates = false);
  }

  Future<void> _loadPagoMovilStore() async {
    _pagoMovilStore = await _firebase.fetchPagoMovilStore();
    if (mounted) setState(() {});
  }

  Future<void> _pickPaymentImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _paymentImage = bytes;
      _paymentImageName = file.name;
      _ocrResult = null;
    });
    try {
      final result = await _api.parsePaymentImage(bytes, file.name);
      setState(() {
        _ocrResult = result;
        final data = result['data'] ?? result;
        if (data is Map) {
          _refCtrl.text = (data['reference'] ?? data['referencia'] ?? _refCtrl.text).toString();
          _phoneCtrl.text = (data['phone'] ?? data['telefono'] ?? _phoneCtrl.text).toString();
        }
      });
    } catch (_) {}
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

      final orderData = {
        'uid': user.uid,
        'email': user.email,
        'nombre': user.nombre,
        'telefono': user.telefono,
        'items': _cart.map((e) => e.toJson()).toList(),
        'subtotal': _subtotal,
        'deliveryType': _deliveryType,
        'deliveryCost': _deliveryFee,
        'total': _total,
        'totalBs': _totalBs,
        'bcvRate': _bcvRate,
        'paymentModality': _modality,
        'branchId': provider.sedeSeleccionada?.id,
        'modo': provider.modo,
        'status': 'pendiente',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final orderId = await _firebase.createOrder(orderData);

      if (_paymentImage != null) {
        final ext = _paymentImageName?.split('.').last ?? 'jpg';
        final url = await _firebase.uploadPaymentImage(
          orderId,
          _paymentImage!.toList(),
          ext,
        );
        await _firebase.createPayment({
          'orderId': orderId,
          'uid': user.uid,
          'type': _modality,
          'reference': _refCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'bank': _bankCtrl.text.trim(),
          'imageUrl': url,
          'ocr': _ocrResult,
          'amount': _total,
          'amountBs': _totalBs,
        });
      }

      await _api.notifyOrderCreated({'orderId': orderId, 'uid': user.uid});
      await _api.notifyPrinter({'orderId': orderId});

      if (!widget.embedded) {
        await provider.clearCart();
      }

      setState(() {
        _createdOrderId = orderId;
        _step = 2;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _phoneCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cart.isEmpty && _step == 0 && !widget.embedded) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined,
                size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            const Text('Tu carrito está vacío'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Ir a comprar'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildStepIndicator(_step),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: const TextStyle(color: AppColors.discount)),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: switch (_step) {
              0 => _buildOrderStep(),
              1 => _buildPaymentStep(),
              _ => _buildTrackingStep(),
            },
          ),
        ),
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildStepIndicator(int current) {
    const labels = ['Orden', 'Pago', 'Seguimiento'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: AppColors.cardBg,
      child: Row(
        children: List.generate(3, (i) {
          final active = i <= current;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      active ? AppColors.primary : AppColors.border,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: active ? Colors.white : AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == current ? FontWeight.bold : FontWeight.normal,
                      color: i == current ? AppColors.primary : AppColors.textLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (i < 2)
                  Container(
                    width: 8,
                    height: 1,
                    color: AppColors.border,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOrderStep() {
    final provider = context.watch<AppProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Productos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ..._cart.map((item) => _CartLineItem(
              item: item,
              embedded: widget.embedded,
              fmt: _fmt,
            )),
        const SizedBox(height: 16),
        const Text('Tipo de entrega', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'pickup', label: Text('Retiro en tienda')),
            ButtonSegment(value: 'delivery', label: Text('Delivery')),
          ],
          selected: {_deliveryType},
          onSelectionChanged: (s) => setState(() => _deliveryType = s.first),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _TotalRow('Subtotal', _fmt.format(_subtotal)),
                if (_deliveryFee > 0)
                  _TotalRow('Delivery', _fmt.format(_deliveryFee)),
                const Divider(),
                _TotalRow('Total USD', _fmt.format(_total), bold: true),
                if (_loadingRates)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (_bcvRate > 0) ...[
                  const SizedBox(height: 8),
                  _TotalRow(
                    'Tasa BCV',
                    NumberFormat('#,##0.00').format(_bcvRate),
                  ),
                  _TotalRow('Total Bs.', _fmt.format(_totalBs), bold: true),
                ],
              ],
            ),
          ),
        ),
        if (provider.sedeSeleccionada != null) ...[
          const SizedBox(height: 8),
          Text(
            'Sede: ${provider.sedeSeleccionada!.name}',
            style: const TextStyle(color: AppColors.textLight),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentStep() {
    if (_isCashea) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/cashea.png',
                height: 40,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.credit_card, size: 40),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pago con Cashea',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Tu pedido será procesado a crédito. Los bultos incluyen recargo del 5%.',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total a financiar: ${_fmt.format(_total)}'),
                  if (_totalBs > 0)
                    Text('Equivalente: ${_fmt.format(_totalBs)} Bs.'),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pago Móvil',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_pagoMovilStore != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Datos para transferir:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Banco: ${_pagoMovilStore!['bank'] ?? ''}'),
                  Text('Teléfono: ${_pagoMovilStore!['phone'] ?? ''}'),
                  Text('RIF/CI: ${_pagoMovilStore!['rif'] ?? ''}'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _refCtrl,
          decoration: const InputDecoration(labelText: 'Referencia'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(labelText: 'Teléfono emisor'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bankCtrl,
          decoration: const InputDecoration(labelText: 'Banco emisor'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickPaymentImage,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Capturar comprobante (OCR)'),
        ),
        if (_paymentImage != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(_paymentImage!, height: 120, fit: BoxFit.cover),
          ),
        ],
        if (_ocrResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'OCR: datos detectados automáticamente',
              style: const TextStyle(color: AppColors.success, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildTrackingStep() {
    return Column(
      children: [
        const Icon(Icons.check_circle, size: 64, color: AppColors.success),
        const SizedBox(height: 16),
        const Text(
          '¡Pedido creado!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('Número de pedido: #$_createdOrderId'),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.push('/order-view-v2/$_createdOrderId'),
          child: const Text('Ver detalle del pedido'),
        ),
        const SizedBox(height: 12),
        if (!widget.embedded)
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Seguir comprando'),
          ),
      ],
    );
  }

  Widget _buildBottomActions() {
    if (_step == 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0)
              TextButton(
                onPressed: _submitting ? null : () => setState(() => _step--),
                child: const Text('Atrás'),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: _submitting
                  ? null
                  : () {
                      if (_step == 0) {
                        setState(() => _step = 1);
                      } else {
                        _createOrder();
                      }
                    },
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_step == 0 ? 'Continuar al pago' : 'Confirmar pedido'),
            ),
          ],
        ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            if (item.imgUrl100 != null && item.imgUrl100!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: item.imgUrl100!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.image, size: 56),
              )
            else
              const Icon(Icons.image, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.nombre, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(
                    '${item.presentacion} · ${fmt.format(item.precio)}',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                  if (item.casheaSurchargeApplied)
                    const Text(
                      'Recargo Cashea',
                      style: TextStyle(color: AppColors.wholesale, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (!embedded)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () => provider.updateCartQty(
                      item.id,
                      item.presentacion,
                      item.cantidad - 1,
                    ),
                  ),
                  Text('${item.cantidad}'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () => provider.updateCartQty(
                      item.id,
                      item.presentacion,
                      item.cantidad + 1,
                    ),
                  ),
                ],
              )
            else
              Text('x${item.cantidad}'),
            Text(fmt.format(item.totalAux)),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              )),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
    );
  }
}
