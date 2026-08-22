// ponytail: one-shot check — falla si "lapicero" no parsea (bug iva_rate string).
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:app_marketcatia/models/models.dart';

Future<void> main() async {
  final res = await http.post(
    Uri.parse('https://marketcatia-api.up.railway.app/products/system_report'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'name': 'lapicero', 'show': true}),
  );
  if (res.statusCode >= 400) {
    stderr.writeln('HTTP ${res.statusCode}');
    exit(1);
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  var ok = 0;
  var fail = 0;
  var lap = 0;
  for (final raw in (data['data'] as List? ?? [])) {
    if (raw is! Map) continue;
    try {
      final p = Product.fromMap(Map<String, dynamic>.from(raw));
      ok++;
      if (p.name.toLowerCase().contains('lapicero')) {
        lap++;
        stdout.writeln('OK ${p.name} iva=${p.ivaRate}');
      }
    } catch (e) {
      fail++;
      stderr.writeln('FAIL $e');
    }
  }
  stdout.writeln('ok=$ok fail=$fail lapiceros=$lap');
  if (fail > 0 || lap < 1) exit(1);
}
