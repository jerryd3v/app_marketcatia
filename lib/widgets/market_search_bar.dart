import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra de búsqueda estilo web (SearchContainer / search-modal).
class MarketSearchBar extends StatelessWidget {
  const MarketSearchBar({
    super.key,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.hintText = 'Buscar productos...',
    this.value,
    this.onClear,
    this.autofocus = false,
    this.fillColor = const Color(0xFFF8FAFC),
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final String? value;
  final VoidCallback? onClear;
  final bool autofocus;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    final showClear = onClear != null &&
        ((controller != null && controller!.text.isNotEmpty) ||
            (value != null && value!.isNotEmpty));

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF1E293B),
            height: 1.3,
          ),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
            ),
            filled: true,
            fillColor: fillColor,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(
              48,
              14,
              showClear ? 44 : 16,
              14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
          ),
        ),
        const Positioned(
          left: 16,
          child: Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
        ),
        if (showClear)
          Positioned(
            right: 4,
            child: IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
              tooltip: 'Limpiar',
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}

/// Chip UND/Mayor/Bulto del modal carrito (pres-chip-template).
class PresChipTag extends StatelessWidget {
  const PresChipTag({
    super.key,
    required this.label,
    this.selected = false,
    this.disabled = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;

    if (disabled) {
      bg = const Color(0xFFE2E8F0);
      fg = const Color(0xFF94A3B8);
      border = const Color(0xFFCBD5E1);
    } else if (selected) {
      bg = const Color(0xFF6366F1);
      fg = Colors.white;
      border = const Color(0xFF6366F1);
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
      border = const Color(0xFFE2E8F0);
    }

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.2,
            fontWeight: FontWeight.w500,
            color: fg,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
