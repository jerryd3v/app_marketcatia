import 'package:flutter/material.dart';

import '../providers/app_provider.dart';

/// Refresca precios del carrito al volver a la app (equivalente al foco en web).
class CartPriceSyncLifecycle extends StatefulWidget {
  const CartPriceSyncLifecycle({
    super.key,
    required this.provider,
    required this.child,
  });

  final AppProvider provider;
  final Widget child;

  @override
  State<CartPriceSyncLifecycle> createState() => _CartPriceSyncLifecycleState();
}

class _CartPriceSyncLifecycleState extends State<CartPriceSyncLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.provider.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
