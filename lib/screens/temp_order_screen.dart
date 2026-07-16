import 'package:flutter/material.dart';

import '../constants/cart_payment_modality.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../utils/pricing.dart';
import 'cart_screen.dart';

class TempOrderScreen extends StatefulWidget {
  const TempOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<TempOrderScreen> createState() => _TempOrderScreenState();
}

class _TempOrderScreenState extends State<TempOrderScreen> {
  final _firebase = FirebaseService();
  bool _loading = true;
  String? _error;
  List<CartItem> _cart = [];
  String? _paymentModality;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final parsed = parseTempOrderId(widget.orderId);
    try {
      final data = await _firebase.fetchTempOrder(parsed.id);
      if (data == null) {
        setState(() {
          _error = 'Pedido temporal no encontrado';
          _loading = false;
        });
        return;
      }
      final items = (data['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _paymentModality = parsed.paymentType ??
          CartPaymentModality.parse(data['paymentModality']?.toString());
      _cart = syncCartLinesWithPaymentModality(items, _paymentModality);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Error al cargar el pedido';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: AppColors.discount)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.cardBg,
          child: const Text(
            'Completar pedido',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: CartScreen(
            embedded: true,
            initialCart: _cart,
            initialPaymentModality: _paymentModality,
          ),
        ),
      ],
    );
  }
}
