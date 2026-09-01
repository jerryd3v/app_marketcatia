import 'package:flutter/material.dart';

class CartPriceNotice extends StatelessWidget {
  const CartPriceNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Precios del catálogo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Se actualizan con frecuencia. Los artículos en tu carrito conservan su precio por un tiempo breve.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
