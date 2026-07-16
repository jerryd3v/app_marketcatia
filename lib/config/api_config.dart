class ApiConfig {
  static const String apiBase =
      String.fromEnvironment(
        'API_URL',
        defaultValue: 'https://marketcatia-api.up.railway.app',
      );

  static const String productsReport = '$apiBase/products/system_report';
  static const String taxesObtener = '$apiBase/taxes/obtener';
  static const String deliveryCost = '$apiBase/taxes/delivery-cost';
  static const String parsePaymentImage = '$apiBase/payments/parse-image';
  static const String validateCredit = '$apiBase/orders/validate-credit-purchase';
  static const String notifyPrinter = '$apiBase/orders/notify-printer';
  static const String chatbotEnabled = '$apiBase/chatbot/enabled';
  static const String orderNotification =
      'https://chatbot-marketcatia.up.railway.app/api/notification';

  static const String googleMapsApiKey =
      'AIzaSyDCOzZYe2dmIivoziaGME-SrjdhS23N6rw';

  static String chatbotWsUrl(String? sessionId) {
    final u = Uri.parse(apiBase);
    final protocol = u.scheme == 'https' ? 'wss' : 'ws';
    final params = <String, String>{'channel': 'mobile'};
    if (sessionId != null &&
        RegExp(r'^[a-zA-Z0-9._-]{8,200}$').hasMatch(sessionId)) {
      params['sessionId'] = sessionId;
    }
    return Uri(
      scheme: protocol,
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: '/ws',
      queryParameters: params,
    ).toString();
  }
}
