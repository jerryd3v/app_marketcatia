import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';

class ModeNotification extends StatelessWidget {
  const ModeNotification({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.modeNotificationVisible) return const SizedBox.shrink();

    final isWholesale = app.modo == 'wholesale';
    final label = isWholesale ? 'Mayorista' : 'Minorista';
    final color = isWholesale ? AppColors.wholesale : AppColors.retail;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 90,
      left: 24,
      right: 24,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Modo $label activado. El carrito se reinició.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
