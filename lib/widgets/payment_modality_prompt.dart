import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/cart_payment_modality.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';

class PaymentModalityPrompt extends StatelessWidget {
  const PaymentModalityPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final app = context.watch<AppProvider>();

    if (!CartPaymentModality.shouldPromptOnPath(path)) {
      return const SizedBox.shrink();
    }
    if (app.cartPaymentModality != null) return const SizedBox.shrink();

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            boxShadow: AppColors.shadowLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: const Icon(Icons.smart_toy, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                '¡Bienvenido a Marketcatia!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Para comenzar, ¿cómo vas a cancelar tu pedido hoy?',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMedium, height: 1.4),
              ),
              const SizedBox(height: 20),
              _Option(
                icon: const Text('📱', style: TextStyle(fontSize: 28)),
                title: 'Pago Móvil',
                subtitle: 'Transferencia bancaria inmediata',
                onTap: () => app
                    .setCartPaymentModality(CartPaymentModality.pagoMovil),
              ),
              const SizedBox(height: 10),
              _Option(
                icon: Image.asset(
                  'assets/images/cashea.png',
                  width: 36,
                  height: 36,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.payments, color: AppColors.primary),
                ),
                title: 'Cashea',
                subtitle: 'Pago en cuotas sin tarjeta',
                onTap: () =>
                    app.setCartPaymentModality(CartPaymentModality.cashea),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        child: Row(
          children: [
            SizedBox(width: 44, child: Center(child: icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
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
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
