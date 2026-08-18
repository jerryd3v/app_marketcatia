import 'package:flutter/material.dart';

/// Iconos que rotan en Y (estrellas / rayos de la web).
class SpinYIcons extends StatefulWidget {
  const SpinYIcons({
    super.key,
    required this.icon,
    this.count = 5,
    this.color = const Color(0xFFF59E0B),
    this.size = 16,
  });

  final IconData icon;
  final int count;
  final Color color;
  final double size;

  @override
  State<SpinYIcons> createState() => _SpinYIconsState();
}

class _SpinYIconsState extends State<SpinYIcons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.count, (i) {
            final t = (_ctrl.value + i * 0.08) % 1;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(t * 6.28318),
              child: Icon(widget.icon, size: widget.size, color: widget.color),
            );
          }),
        );
      },
    );
  }
}
