import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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
    try {
      final res = await http
          .get(Uri.parse(ApiConfig.taxesObtener))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 400) throw Exception('Error tasa BCV');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = data['data'] is Map
          ? (data['data'] as Map)['promedio']
          : data['promedio'];
      if (raw is num) return raw.toDouble();
      return double.tryParse('$raw') ?? 0;
    } on TimeoutException {
      throw Exception('Tiempo agotado al cargar la tasa BCV');
    }
  }

  Future<Map<String, dynamic>> fetchDeliveryCost() async {
    try {
      final res = await http
          .get(Uri.parse(ApiConfig.deliveryCost))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 400) return {};
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return Map<String, dynamic>.from(data['data'] ?? data);
    } catch (_) {
      return {};
    }
  }

  MediaType _imageContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    return MediaType('image', 'jpeg');
  }

  Future<Map<String, dynamic>> parsePaymentImage(
    List<int> bytes,
    String filename,
  ) async {
    var safeName = filename.trim();
    if (safeName.isEmpty || !safeName.contains('.')) {
      safeName = 'comprobante.jpg';
    }
    final req = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.parsePaymentImage),
    );
    req.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: safeName,
        contentType: _imageContentType(safeName),
      ),
    );
    // ponytail: 60s ceiling — Gemini OCR can be slow; avoids infinite "Leyendo…"
    late final http.StreamedResponse streamed;
    try {
      streamed = await req.send().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw Exception(
        'Sin respuesta del servidor (tiempo agotado). Revisa la conexión Wi‑Fi/datos e intenta de nuevo.',
      );
    } on SocketException {
      throw Exception(
        'Sin conexión a internet. Activa Wi‑Fi o datos y vuelve a intentar.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        e.message.contains('Failed host lookup') ||
                e.message.contains('Network is unreachable')
            ? 'Sin conexión a internet. Activa Wi‑Fi o datos y vuelve a intentar.'
            : 'Error de red: ${e.message}',
      );
    }
    final body = await streamed.stream.bytesToString();
    Map<String, dynamic> json = {};
    try {
      if (body.isNotEmpty) {
        json = Map<String, dynamic>.from(jsonDecode(body) as Map);
      }
    } catch (_) {}
    if (streamed.statusCode >= 400) {
      final msg = (json['error'] ?? json['message'] ?? body).toString();
      throw Exception(
        msg.isNotEmpty ? msg : 'OCR falló: ${streamed.statusCode}',
      );
    }
    if (json['success'] == false) {
      throw Exception(
        (json['error'] ?? json['message'] ?? 'No se pudieron leer los datos')
            .toString(),
      );
    }
    return json;
  }

  Future<Map<String, dynamic>> validateCredit(Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse(ApiConfig.validateCredit),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<int> fetchNextOrderNumber() async {
    final res = await http
        .get(Uri.parse(ApiConfig.nextOrderNumber))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode >= 400) {
      throw Exception('No se pudo obtener el número de pedido');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final n = data['nextNumber'];
    if (n is num && n > 0) return n.toInt();
    throw Exception('Número de pedido inválido');
  }

  Future<void> notifyPrinter(Map<String, dynamic> body) async {
    try {
      await http
          .post(
            Uri.parse(ApiConfig.notifyPrinter),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {/* ignore — web también traga errores */}
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
      await http
          .post(
            Uri.parse(ApiConfig.orderNotification),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {/* ignore */}
  }
}
