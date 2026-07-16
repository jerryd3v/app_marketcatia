import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/firebase_service.dart';
import '../theme/app_colors.dart';

class OrderViewScreen extends StatefulWidget {
  const OrderViewScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderViewScreen> createState() => _OrderViewScreenState();
}

class _OrderViewScreenState extends State<OrderViewScreen> {
  final _firebase = FirebaseService();
  Map<String, dynamic>? _order;
  bool _loading = true;
  final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _order = await _firebase.fetchOrder(widget.orderId);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              Expanded(
                child: Text(
                  'Pedido #${widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _order == null
                  ? const Center(child: Text('Pedido no encontrado'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoCard(order: _order!),
                          const SizedBox(height: 16),
                          const Text(
                            'Productos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...((_order!['items'] as List? ?? []).map((item) {
                            if (item is! Map) return const SizedBox.shrink();
                            final name = (item['nombre'] ?? item['name'] ?? '')
                                .toString();
                            final qty = item['cantidad'] ?? 1;
                            final total = item['totalAux'] ?? item['precio'];
                            return Card(
                              child: ListTile(
                                title: Text(name),
                                subtitle: Text('Cantidad: $qty'),
                                trailing: Text(
                                  _fmt.format(
                                    (total as num?)?.toDouble() ?? 0,
                                  ),
                                ),
                              ),
                            );
                          })),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _Row(
                                    'Subtotal',
                                    _fmt.format(
                                      (_order!['subtotal'] as num?)
                                              ?.toDouble() ??
                                          0,
                                    ),
                                  ),
                                  if (_order!['deliveryCost'] != null &&
                                      (_order!['deliveryCost'] as num) > 0)
                                    _Row(
                                      'Delivery',
                                      _fmt.format(
                                        (_order!['deliveryCost'] as num)
                                            .toDouble(),
                                      ),
                                    ),
                                  const Divider(),
                                  _Row(
                                    'Total',
                                    _fmt.format(
                                      (_order!['total'] as num?)?.toDouble() ??
                                          0,
                                    ),
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final status =
        (order['status'] ?? order['estado'] ?? 'pendiente').toString();
    final delivery = (order['deliveryType'] ?? 'pickup').toString();
    final payment = (order['paymentModality'] ?? '').toString();

    Color statusColor = AppColors.featured;
    if (status.contains('complet') || status.contains('entreg')) {
      statusColor = AppColors.success;
    } else if (status.contains('cancel')) {
      statusColor = AppColors.discount;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Estado: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Entrega: ${delivery == 'delivery' ? 'Delivery' : 'Retiro en tienda'}',
            ),
            if (payment.isNotEmpty) Text('Pago: $payment'),
            if (order['createdAt'] != null)
              Text(
                'Fecha: ${order['createdAt']}',
                style: const TextStyle(color: AppColors.textLight, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});

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
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
