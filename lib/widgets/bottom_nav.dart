import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import 'app_scaffold.dart';

/// Barra inferior: ~51px (+15%) + poco aire sobre el home indicator.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final app = context.watch<AppProvider>();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // No sumar el safe-area completo: la barra se veía demasiado alta.
    final bottomPad = bottomInset > 0 ? (bottomInset - 16).clamp(4.0, 18.0) : 2.0;

    return Material(
      color: AppColors.cardBg.withValues(alpha: 0.97),
      elevation: 6,
      shadowColor: Colors.black26,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: SizedBox(
          height: 51,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Inicio',
                active: path == '/' && app.vistaActual == 'categories',
                onTap: () {
                  context.go('/');
                  app.resetHomeState();
                },
              ),
              _NavItem(
                icon: Icons.search_rounded,
                label: 'Buscar',
                active: false,
                onTap: () {
                  context.go('/');
                  goHomeAndSearch(context);
                },
              ),
              _NavItem(
                icon: Icons.shopping_cart_rounded,
                label: 'Carrito',
                active: path == '/cart',
                badge: app.cartCount,
                onTap: () => context.go('/cart'),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Cuenta',
                active: path == '/account',
                onTap: () => context.go('/account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: active ? AppColors.primary : AppColors.textLight,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? AppColors.primary : AppColors.textLight,
                    height: 1,
                  ),
                ),
              ],
            ),
            if (active)
              Positioned(
                top: 2,
                child: Container(
                  width: 18,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            if (badge > 0)
              Positioned(
                top: 2,
                right: 18,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.discount,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
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
