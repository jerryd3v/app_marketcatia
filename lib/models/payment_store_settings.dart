/// Defaults beneficiario pago móvil — mismos que `paymentStoreDefaults.js` web.
class PaymentStoreDefaults {
  static const bankDisplay = 'Banesco';
  static const bankCopy = '0134';
  static const rifTypeLetter = 'E';
  static const rifRest = ' - 82.270.232';
  static const rifCopyDigits = '82270232';
  static const phone = '04129333199';
  static const showForeignDocLegend = true;
}

class PaymentStoreSettings {
  const PaymentStoreSettings({
    required this.bankDisplay,
    required this.bankCopy,
    required this.rifTypeLetter,
    required this.rifRest,
    required this.rifCopyDigits,
    required this.phone,
    required this.showForeignDocLegend,
  });

  final String bankDisplay;
  final String bankCopy;
  final String rifTypeLetter;
  final String rifRest;
  final String rifCopyDigits;
  final String phone;
  final bool showForeignDocLegend;

  String get bankLabel {
    final code = bankCopy.trim();
    final name = bankDisplay.trim();
    if (code.isNotEmpty && name.isNotEmpty) return '$code — $name';
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
    return '—';
  }

  String get rifDisplay => '$rifTypeLetter$rifRest';

  String get phoneFormatted {
    var cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 9) cleaned = '0$cleaned';
    if (cleaned.length == 10 && !cleaned.startsWith('0')) {
      cleaned = '0$cleaned';
    }
    if (cleaned.length == 11) {
      return '(${cleaned.substring(0, 4)}) ${cleaned.substring(4, 8)}-${cleaned.substring(8)}';
    }
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 4)}) ${cleaned.substring(4, 8)}-${cleaned.substring(8)}';
    }
    return phone;
  }

  /// Teléfono normalizado para copiar (como web).
  String get phoneForCopy {
    var d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return phone;
    if (d.startsWith('58') && d.length >= 10) return '0${d.substring(2)}';
    if (d.startsWith('0')) return d;
    if (d.length == 10 && d.startsWith('4')) return '0$d';
    return d;
  }

  static const defaults = PaymentStoreSettings(
    bankDisplay: PaymentStoreDefaults.bankDisplay,
    bankCopy: PaymentStoreDefaults.bankCopy,
    rifTypeLetter: PaymentStoreDefaults.rifTypeLetter,
    rifRest: PaymentStoreDefaults.rifRest,
    rifCopyDigits: PaymentStoreDefaults.rifCopyDigits,
    phone: PaymentStoreDefaults.phone,
    showForeignDocLegend: PaymentStoreDefaults.showForeignDocLegend,
  );

  factory PaymentStoreSettings.normalize(Map<String, dynamic>? data) {
    final d = data ?? const {};
    final rifType = (d['rifTypeLetter'] ?? PaymentStoreDefaults.rifTypeLetter)
        .toString()
        .trim()
        .toUpperCase();
    final letter = rifType.isEmpty
        ? PaymentStoreDefaults.rifTypeLetter
        : rifType.substring(0, 1);

    final showLegend = d['showForeignDocLegend'] != null
        ? d['showForeignDocLegend'] == true
        : letter == 'E';

    return PaymentStoreSettings(
      bankDisplay: (d['bankDisplay'] ?? PaymentStoreDefaults.bankDisplay)
          .toString()
          .trim(),
      bankCopy:
          (d['bankCopy'] ?? PaymentStoreDefaults.bankCopy).toString().trim(),
      rifTypeLetter: letter,
      rifRest: (d['rifRest'] ?? PaymentStoreDefaults.rifRest).toString(),
      rifCopyDigits: (d['rifCopyDigits'] ?? PaymentStoreDefaults.rifCopyDigits)
          .toString()
          .replaceAll(RegExp(r'\D'), ''),
      phone: (d['phone'] ?? PaymentStoreDefaults.phone)
          .toString()
          .replaceAll(RegExp(r'\D'), ''),
      showForeignDocLegend: showLegend,
    );
  }
}
