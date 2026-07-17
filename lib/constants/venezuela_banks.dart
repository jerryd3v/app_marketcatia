/// Bancos Venezuela — misma lista que `venezuelaBanks.js` web.
class VeBank {
  const VeBank({required this.code, required this.name});
  final String code;
  final String name;
  String get label => '$code — $name';
}

const venezuelaBanks = <VeBank>[
  VeBank(code: '0102', name: 'Banco de Venezuela S.A.C.A. Banco Universal'),
  VeBank(code: '0104', name: 'Venezolano de Crédito, S.A. Banco Universal'),
  VeBank(code: '0105', name: 'Banco Mercantil, C.A. Banco Universal'),
  VeBank(code: '0108', name: 'Banco Provincial, S.A. Banco Universal'),
  VeBank(code: '0114', name: 'Bancaribe C.A. Banco Universal'),
  VeBank(code: '0115', name: 'Banco Exterior C.A. Banco Universal'),
  VeBank(code: '0128', name: 'Banco Caroní C.A. Banco Universal'),
  VeBank(code: '0134', name: 'Banesco Banco Universal S.A.C.A.'),
  VeBank(code: '0138', name: 'Banco Plaza, Banco Universal'),
  VeBank(code: '0151', name: 'BFC Banco Fondo Común C.A. Banco Universal'),
  VeBank(code: '0156', name: '100% Banco, Banco Universal C.A.'),
  VeBank(code: '0163', name: 'Banco del Tesoro, C.A. Banco Universal'),
  VeBank(code: '0166', name: 'Banco Agrícola de Venezuela, C.A. Banco Universal'),
  VeBank(code: '0168', name: 'Bancrecer, S.A. Banco Microfinanciero'),
  VeBank(code: '0169', name: 'Mi Banco, Banco Microfinanciero C.A.'),
  VeBank(code: '0171', name: 'Banco Activo, Banco Universal'),
  VeBank(code: '0172', name: 'Bancamica, Banco Microfinanciero C.A.'),
  VeBank(
    code: '0173',
    name: 'Banco Internacional de Desarrollo, C.A. Banco Universal',
  ),
  VeBank(code: '0174', name: 'Banplus Banco Universal, C.A'),
  VeBank(
    code: '0175',
    name:
        'Banco Bicentenario del Pueblo de la Clase Obrera, Mujer y Comunas B.U.',
  ),
  VeBank(
    code: '0177',
    name: 'Banco de la Fuerza Armada Nacional Bolivariana, B.U.',
  ),
  VeBank(code: '0191', name: 'Banco Nacional de Crédito, C.A. Banco Universal'),
];

VeBank? findBankByCode(String? code) {
  if (code == null || code.trim().isEmpty) return null;
  final digits = code.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty || digits.length > 4) return null;
  final padded = digits.padLeft(4, '0');
  for (final b in venezuelaBanks) {
    if (b.code == padded) return b;
  }
  return null;
}

VeBank? findBankByName(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  final t = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  for (final b in venezuelaBanks) {
    if (b.name.toLowerCase() == t) return b;
  }
  for (final b in venezuelaBanks) {
    if (t.contains(b.code)) return b;
  }
  for (final b in venezuelaBanks) {
    final n = b.name.toLowerCase();
    final short = n.split(',').first.split('banco').first.trim();
    if (t.contains(n) || n.contains(t)) return b;
    if (short.length > 4 && t.contains(short)) return b;
  }
  return null;
}

String resolveBankName(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final found = findBankByCode(raw) ?? findBankByName(raw);
  return found?.name ?? raw.trim();
}
