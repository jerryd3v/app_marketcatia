import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import 'orders_history_modal.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final isCartFlow =
        path == '/cart' || path.startsWith('/temp-order/');

    return Material(
      color: AppColors.cardBg,
      elevation: 1,
      shadowColor: Colors.black12,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Consumer<AppProvider>(
            builder: (context, app, _) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _BranchSelector(app: app)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          app.resetHomeState();
                          context.go('/');
                        },
                        child: Image.asset(
                          'assets/images/icon.png',
                          height: 32,
                          errorBuilder: (_, __, ___) => const Text(
                            'Marketcatia',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isCartFlow && app.user != null)
                        _MisPedidosButton(uid: app.user!.uid)
                      else
                        _ModeToggle(app: app),
                      const SizedBox(width: 8),
                      if (!isCartFlow) _CartButton(count: app.cartCount),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({required this.app});
  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.wholesale.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront, size: 14, color: AppColors.wholesale),
          const SizedBox(width: 6),
          Flexible(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Branch>(
                isDense: true,
                isExpanded: true,
                value: app.sedeSeleccionada,
                hint: Text(
                  app.cargandoSedes ? 'Cargando sedes...' : 'Seleccionar sede',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.wholesale,
                  ),
                ),
                icon: const Icon(Icons.arrow_drop_down,
                    color: AppColors.wholesale, size: 18),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.wholesale,
                ),
                items: app.sedes
                    .map(
                      (b) => DropdownMenuItem(
                        value: b,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: app.setSedeSeleccionada,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.app});
  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final isWholesale = app.modo == 'wholesale';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip('Minorista', !isWholesale, AppColors.retail, () {
            app.cambiarModo('retail');
          }),
          _chip('Mayorista', isWholesale, AppColors.wholesale, () {
            app.cambiarModo('wholesale');
          }),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    bool active,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textLight,
          ),
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/cart'),
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
            if (count > 0)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.discount,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
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
    );
  }
}

class _MisPedidosButton extends StatelessWidget {
  const _MisPedidosButton({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _showOrders(context, uid),
      icon: const Icon(Icons.receipt_long, size: 18),
      label: const Text('Mis pedidos'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Future<void> _showOrders(BuildContext context, String uid) async {
    final app = context.read<AppProvider>();
    await showOrdersHistoryModal(
      context,
      loadOrders: () => app.firebase.fetchUserOrders(uid),
    );
  }
}
