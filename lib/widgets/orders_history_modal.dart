import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// Modal "Historial de pedidos" alineado con Header.jsx / Header.css de la web.
Future<void> showOrdersHistoryModal(
  BuildContext context, {
  required Future<List<Map<String, dynamic>>> Function() loadOrders,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _OrdersHistoryDialog(loadOrders: loadOrders),
  );
}

enum _OrdersTab { proceso, completadas, programadas, expiradas }

class _OrdersHistoryDialog extends StatefulWidget {
  const _OrdersHistoryDialog({required this.loadOrders});
  final Future<List<Map<String, dynamic>>> Function() loadOrders;

  @override
  State<_OrdersHistoryDialog> createState() => _OrdersHistoryDialogState();
}

class _OrdersHistoryDialogState extends State<_OrdersHistoryDialog> {
  _OrdersTab _tab = _OrdersTab.proceso;
  late final Future<List<Map<String, dynamic>>> _future;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _future = widget.loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.9;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Historial de pedidos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textMedium),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _tabChip('En proceso', _OrdersTab.proceso),
                  _tabChip('Completadas', _OrdersTab.completadas),
                  _tabChip('Programadas', _OrdersTab.programadas),
                  _tabChip('Expiradas', _OrdersTab.expiradas),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No se pudo cargar el historial de pedidos.',
                          style: TextStyle(color: AppColors.textLight),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final all = snap.data ?? [];
                  final list = _filter(all, _tab);
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _emptyLabel(_tab),
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _OrderCard(
                      order: list[i],
                      tab: _tab,
                      expanded: _expanded.contains(_orderKey(list[i])),
                      onToggleExpand: () {
                        final k = _orderKey(list[i]);
                        setState(() {
                          if (_expanded.contains(k)) {
                            _expanded.remove(k);
                          } else {
                            _expanded.add(k);
                          }
                        });
                      },
                      onDetails: () {
                        Navigator.pop(context);
                        context.go('/order-view-v2/${list[i]['id']}');
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(String label, _OrdersTab tab) {
    final active = _tab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 8, bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _tab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.textMedium,
            ),
          ),
        ),
      ),
    );
  }

  static String _emptyLabel(_OrdersTab tab) => switch (tab) {
        _OrdersTab.proceso => 'No tienes pedidos en proceso.',
        _OrdersTab.completadas => 'No tienes pedidos completados.',
        _OrdersTab.programadas => 'No tienes pedidos programados.',
        _OrdersTab.expiradas => 'No tienes pedidos expirados.',
      };

  static String _orderKey(Map<String, dynamic> o) =>
      (o['id'] ?? o['numeroPedido'] ?? '').toString();

  static String _normStatus(Map<String, dynamic> o) =>
      (o['status'] ?? '').toString().trim().toLowerCase();

  static String _normDelivery(Map<String, dynamic> o) =>
      (o['checkDelivery'] ?? '').toString().trim().toLowerCase();

  static bool _valid(Map<String, dynamic> o) =>
      o['trash'] != true && o['type'] != 'credit_note';

  static bool _completed(Map<String, dynamic> o) =>
      _normStatus(o) == 'finalizado' || _normDelivery(o) == 'finalizado';

  static bool _expired(Map<String, dynamic> o) => _normStatus(o) == 'expirada';

  static bool _scheduled(Map<String, dynamic> o) {
    if ((o['delivery_type'] ?? o['deliveryType'] ?? '')
            .toString()
            .trim()
            .toLowerCase() !=
        'delivery') {
      return false;
    }
    final subtype =
        (o['shipping_subtype'] ?? o['shippingSubtype'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (subtype == 'programado') return true;
    return o['scheduled_delivery_date'] != null &&
        o['scheduled_delivery_date'].toString().isNotEmpty;
  }

  static int _millis(Map<String, dynamic> o) {
    final created = o['info'] is Map ? o['info']['created_at'] : null;
    if (created is Timestamp) return created.millisecondsSinceEpoch;
    if (created is Map && created['seconds'] is num) {
      return ((created['seconds'] as num) * 1000).toInt();
    }
    final iso = o['createdAt']?.toString();
    if (iso != null) {
      final d = DateTime.tryParse(iso);
      if (d != null) return d.millisecondsSinceEpoch;
    }
    return 0;
  }

  List<Map<String, dynamic>> _filter(
    List<Map<String, dynamic>> all,
    _OrdersTab tab,
  ) {
    var list = all.where(_valid).toList();
    list = switch (tab) {
      _OrdersTab.proceso =>
        list.where((o) => !_completed(o) && !_expired(o)).toList(),
      _OrdersTab.completadas => list.where(_completed).toList(),
      _OrdersTab.programadas => list.where(_scheduled).toList(),
      _OrdersTab.expiradas => list.where(_expired).toList(),
    };
    list.sort((a, b) => _millis(b).compareTo(_millis(a)));
    return list;
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.tab,
    required this.expanded,
    required this.onToggleExpand,
    required this.onDetails,
  });

  final Map<String, dynamic> order;
  final _OrdersTab tab;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final code = order['numeroPedido'] ?? order['id'] ?? '';
    final items = _items(order);
    final visible = expanded ? items : items.take(2).toList();
    final hasMore = items.length > 2;
    final total = _total(order);
    final statusLabel = tab == _OrdersTab.expiradas
        ? 'Expirada'
        : (order['status']?.toString().isNotEmpty == true
            ? order['status'].toString()
            : (tab == _OrdersTab.completadas ? 'Finalizado' : 'En proceso'));
    final completed = tab == _OrdersTab.completadas;
    final expired = tab == _OrdersTab.expiradas;
    final steps = _trackingSteps(order);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#ORD-$code',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: expired
                      ? const Color(0xFFF3F4F6)
                      : completed
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: expired
                        ? const Color(0xFF6B7280)
                        : completed
                            ? const Color(0xFF166534)
                            : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppColors.textLight),
              const SizedBox(width: 6),
              Text(
                _formatDate(order),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            ...visible.map(
              (it) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        it.$1,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      '${it.$2} unidad(es)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasMore)
              TextButton(
                onPressed: onToggleExpand,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  expanded ? 'Ver menos productos' : 'Ver más productos',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 4),
            const Divider(height: 1, color: AppColors.border),
          ],
          const SizedBox(height: 10),
          Text(
            'Total: \$${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _paymentLabel(order),
              style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
            ),
          ),
          if (expired)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Este pedido figura como expirado y no continuará el flujo de entrega.',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            const Text(
              'Seguimiento del pedido',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: steps[i].$2 || steps[i - 1].$2
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: steps[i].$2
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        child: steps[i].$2
                            ? const Icon(Icons.check,
                                size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 56,
                        child: Text(
                          steps[i].$1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: steps[i].$2
                                ? AppColors.primary
                                : AppColors.textLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onDetails,
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('Ver detalles'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: const BorderSide(color: AppColors.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openSupport(order),
                icon: const Icon(Icons.headset_mic_outlined, size: 16),
                label: const Text('Contactar soporte'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<(String, int)> _items(Map<String, dynamic> order) {
    final raw = order['productos'] ?? order['items'];
    if (raw is! List) return [];
    final out = <(String, int)>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final name = (e['nombre'] ?? e['name'] ?? 'Producto').toString();
      final qty = e['cantidad'] ?? e['qty'] ?? 1;
      final n = qty is num ? qty.toInt() : int.tryParse('$qty') ?? 1;
      out.add((name, n > 0 ? n : 1));
    }
    return out;
  }

  static double _total(Map<String, dynamic> order) {
    final v = order['costoTotal'] ?? order['total'] ?? 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  static String _paymentLabel(Map<String, dynamic> order) {
    final method = (order['payment_method'] ?? '').toString().toLowerCase();
    if (method == 'credit') return 'Crédito';
    final cond = (order['condicion'] ?? '').toString().toLowerCase();
    if (cond.contains('credito') || cond.contains('crédito')) return 'Crédito';
    return 'Contado';
  }

  static String _formatDate(Map<String, dynamic> order) {
    final created = order['info'] is Map ? order['info']['created_at'] : null;
    DateTime? d;
    if (created is Timestamp) {
      d = created.toDate();
    } else if (created is Map && created['seconds'] is num) {
      d = DateTime.fromMillisecondsSinceEpoch(
        ((created['seconds'] as num) * 1000).toInt(),
      );
    } else if (order['createdAt'] != null) {
      d = DateTime.tryParse(order['createdAt'].toString());
    }
    if (d != null) {
      return DateFormat('d/M/yyyy, h:mm:ss a').format(d);
    }
    return (order['fecha'] ?? 'Sin fecha').toString();
  }

  static List<(String, bool)> _trackingSteps(Map<String, dynamic> order) {
    final orderStatus = (order['status'] ?? '').toString().toLowerCase();
    final deliveryStatus =
        (order['checkDelivery'] ?? '').toString().toLowerCase();
    final payment = order['payment'];
    final paymentStatus = payment is Map
        ? (payment['status'] ?? '').toString().toLowerCase()
        : '';
    final isDelivered =
        orderStatus == 'finalizado' || deliveryStatus == 'finalizado';
    final isOnRoute =
        deliveryStatus == 'despachado' || deliveryStatus == 'finalizado';
    final isPaymentConfirmed = paymentStatus == 'pagado';
    final isConfirmed =
        (order['checkOrder'] ?? '').toString().toLowerCase() == 'verificado';
    return [
      (
        'Confirmado',
        isConfirmed || isPaymentConfirmed || isOnRoute || isDelivered
      ),
      ('Preparación', isPaymentConfirmed || isOnRoute || isDelivered),
      ('En camino', isOnRoute || isDelivered),
      ('Entregado', isDelivered),
    ];
  }

  static Future<void> _openSupport(Map<String, dynamic> order) async {
    final code = order['numeroPedido'] ?? order['id'] ?? 's/n';
    final text = Uri.encodeComponent(
      'Hola, necesito soporte con mi pedido #$code.',
    );
    final uri = Uri.parse('https://wa.me/584129510813?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
