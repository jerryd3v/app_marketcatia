import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import 'app_scaffold.dart';

/// Barra inferior: base ~52px (+17%); en Android +16% extra.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // Base (+17%). Android: ×1.16.
  static double get _barH => _android ? 60.3 : 52;
  static double get _iconSize => _android ? 27.8 : 24;
  static double get _labelSize => _android ? 12.4 : 10.7;
  static double get _iconGap => _android ? 2.3 : 2;
  static double get _badgeSize => _android ? 19.7 : 17;
  static double get _badgeFont => _android ? 11 : 9.5;

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
          height: _barH,
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
                  size: BottomNav._iconSize,
                  color: active ? AppColors.primary : AppColors.textLight,
                ),
                SizedBox(height: BottomNav._iconGap),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: BottomNav._labelSize,
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
                  width: BottomNav._android ? 22 : 19,
                  height: BottomNav._android ? 2.9 : 2.5,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            if (badge > 0)
              Positioned(
                top: 2,
                right: BottomNav._android ? 16 : 18,
                child: Container(
                  constraints: BoxConstraints(minWidth: BottomNav._badgeSize),
                  height: BottomNav._badgeSize,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.discount,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: BottomNav._badgeFont,
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
