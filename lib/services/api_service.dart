import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/models.dart';

class ApiService {
  Future<List<Product>> searchProducts(String term, {int limit = 20}) async {
    if (term.trim().length < 2) return [];
    return reportProducts(name: term.trim(), limit: limit);
  }

  /// Misma API que el modal web (`POST /products/system_report`).
  /// Sin [name] envía `{}` y trae el listado inicial al abrir el modal.
  Future<List<Product>> reportProducts({String? name, int? limit}) async {
    final body = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    }
    final res = await http.post(
      Uri.parse(ApiConfig.productsReport),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) {
      throw Exception('Error búsqueda: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    var list = (data['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    if (limit != null) list = list.take(limit).toList();
    return list;
  }

  Future<List<Product>> productsBySubcategory(
    String subCategoryId, {
    int limit = 100,
  }) async {
    final accumulated = <Product>[];
    final seen = <String>{};
    var page = 1;
    const maxPages = 30;

    while (page <= maxPages) {
      final uri = Uri.parse('${ApiConfig.productsReport}?limit=$limit&page=$page');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'show': true, 'sub_category': subCategoryId}),
      );
      if (res.statusCode >= 400) {
        throw Exception('Error productos: ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final pageList = (data['data'] as List? ?? []);
      if (pageList.isEmpty) break;

      for (final raw in pageList) {
        if (raw is! Map) continue;
        final p = Product.fromMap(Map<String, dynamic>.from(raw));
        if (p.id.isEmpty || seen.contains(p.id)) continue;
        seen.add(p.id);
        accumulated.add(p);
      }
      if (pageList.length < limit) break;
      page++;
    }
    return accumulated;
  }

  Future<double> fetchBcvRate() async {
    final res = await http.get(Uri.parse(ApiConfig.taxesObtener));
    if (res.statusCode >= 400) throw Exception('Error tasa BCV');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final promedio = data['data']?['promedio'] ?? data['promedio'];
    return (promedio as num?)?.toDouble() ?? 0;
  }

  Future<Map<String, dynamic>> fetchDeliveryCost() async {
    final res = await http.get(Uri.parse(ApiConfig.deliveryCost));
    if (res.statusCode >= 400) return {};
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(data['data'] ?? data);
  }

  Future<Map<String, dynamic>> parsePaymentImage(List<int> bytes, String filename) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.parsePaymentImage),
    );
    req.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: filename,
    ));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 400) {
      throw Exception('OCR falló: ${streamed.statusCode}');
    }
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  }

  Future<Map<String, dynamic>> validateCredit(Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse(ApiConfig.validateCredit),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<void> notifyPrinter(Map<String, dynamic> body) async {
    try {
      await http.post(
        Uri.parse(ApiConfig.notifyPrinter),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {/* ignore */}
  }

  Future<Map<String, dynamic>> chatbotEnabled() async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.chatbotEnabled));
      if (res.statusCode >= 400) return {'enabled': false};
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {
      return {'enabled': false};
    }
  }

  Future<void> notifyOrderCreated(Map<String, dynamic> body) async {
    try {
      await http.post(
        Uri.parse(ApiConfig.orderNotification),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {/* ignore */}
  }
}
