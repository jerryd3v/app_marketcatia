class CartPaymentModality {
  static const String key = 'cart_payment_modality';
  static const String pagoMovil = 'pago_movil';
  static const String cashea = 'cashea';

  static String? parse(String? raw) {
    if (raw == cashea || raw == pagoMovil) return raw;
    return null;
  }

  static bool shouldPromptOnPath(String path) {
    if (path == '/login' || path == '/recovery-password') return false;
    if (path.startsWith('/temp-order/')) return false;
    return true;
  }
}
