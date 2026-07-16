class Product {
  Product({
    required this.id,
    required this.name,
    this.codigo,
    this.price,
    this.priceMayor,
    this.priceBulto,
    this.cantidadUnidad = 1,
    this.cantidadMayor = 6,
    this.cantidadBulto = 12,
    this.statusUnidad = true,
    this.statusMayor = false,
    this.statusBulto = false,
    this.imgUrl,
    this.imgUrl100,
    this.imgUrl250,
    this.discounts = const [],
    this.stock,
    this.ventas = 0,
    this.taxable,
    this.ivaRate,
    this.peso = 0,
    this.show = true,
    this.raw = const {},
  });

  final String id;
  final String name;
  final String? codigo;
  final double? price;
  final double? priceMayor;
  final double? priceBulto;
  final num cantidadUnidad;
  final num cantidadMayor;
  final num cantidadBulto;
  final bool statusUnidad;
  final bool statusMayor;
  final bool statusBulto;
  final String? imgUrl;
  final String? imgUrl100;
  final String? imgUrl250;
  final List<dynamic> discounts;
  final dynamic stock;
  final num ventas;
  final bool? taxable;
  final num? ivaRate;
  final num peso;
  final bool show;
  final Map<String, dynamic> raw;

  String get displayImage =>
      imgUrl250 ?? imgUrl100 ?? imgUrl ?? '';

  factory Product.fromMap(Map<String, dynamic> m) {
    final id = (m['idProduct'] ?? m['id'] ?? '').toString();
    return Product(
      id: id,
      name: (m['name'] ?? m['nombre'] ?? '').toString(),
      codigo: m['codigo']?.toString(),
      price: _toDouble(m['price']),
      priceMayor: _toDouble(m['priceMayor']),
      priceBulto: _toDouble(m['priceBulto']),
      cantidadUnidad: m['cantidadUnidad'] ?? 1,
      cantidadMayor: m['cantidadMayor'] ?? 6,
      cantidadBulto: m['cantidadBulto'] ?? 12,
      statusUnidad: m['statusUnidad'] != false,
      statusMayor: m['statusMayor'] != false &&
          (m['priceMayor'] != null || m['precioMayor'] != null),
      statusBulto: m['statusBulto'] != false &&
          (m['priceBulto'] != null || m['precioBulto'] != null),
      imgUrl: m['imgUrl']?.toString(),
      imgUrl100: m['imgUrl100']?.toString(),
      imgUrl250: m['imgUrl250']?.toString(),
      discounts: m['discounts'] is List ? List.from(m['discounts']) : const [],
      stock: m['stock'] ?? m['existencia'] ?? m['quantity'],
      ventas: m['ventas'] ?? 0,
      taxable: m['taxable'] is bool ? m['taxable'] as bool : null,
      ivaRate: m['iva_rate'] ?? m['ivaRate'],
      peso: m['peso'] ?? 0,
      show: m['show'] != false,
      raw: Map<String, dynamic>.from(m),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'idProduct': id,
        'name': name,
        'nombre': name,
        'codigo': codigo,
        'price': price,
        'priceMayor': priceMayor,
        'priceBulto': priceBulto,
        'cantidadUnidad': cantidadUnidad,
        'cantidadMayor': cantidadMayor,
        'cantidadBulto': cantidadBulto,
        'statusUnidad': statusUnidad,
        'statusMayor': statusMayor,
        'statusBulto': statusBulto,
        'imgUrl': imgUrl,
        'imgUrl100': imgUrl100,
        'imgUrl250': imgUrl250,
        'discounts': discounts,
        'stock': stock,
        'ventas': ventas,
        'taxable': taxable,
        'iva_rate': ivaRate,
        'peso': peso,
        'show': show,
        ...raw,
      };

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class CartItem {
  CartItem({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.precioOri,
    required this.presentacion,
    required this.cantidad,
    required this.totalAux,
    this.codigo,
    this.precioUnidad,
    this.precioMayor,
    this.precioBulto,
    this.cantidadBulto = 1,
    this.cantidadUnidadOri,
    this.cantidadMayorOri,
    this.cantidadBultoOri,
    this.imgUrl100,
    this.discounts = const [],
    this.taxable,
    this.ivaRate,
    this.peso = 0,
    this.casheaSurchargeApplied = false,
    this.precioCatalogoPresentacion,
    this.presentaciones = const [],
  });

  final String id;
  final String nombre;
  final String? codigo;
  double precio;
  double precioOri;
  String presentacion;
  int cantidad;
  double totalAux;
  final double? precioUnidad;
  final double? precioMayor;
  final double? precioBulto;
  num cantidadBulto;
  final num? cantidadUnidadOri;
  final num? cantidadMayorOri;
  final num? cantidadBultoOri;
  final String? imgUrl100;
  final List<dynamic> discounts;
  final bool? taxable;
  final num? ivaRate;
  final num peso;
  bool casheaSurchargeApplied;
  double? precioCatalogoPresentacion;
  final List<dynamic> presentaciones;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'codigo': codigo,
        'precio': precio,
        'precioOri': precioOri,
        'presentacion': presentacion,
        'cantidad': cantidad,
        'totalAux': totalAux,
        'precioUnidad': precioUnidad,
        'precioMayor': precioMayor,
        'precioBulto': precioBulto,
        'cantidadBulto': cantidadBulto,
        'cantidadUnidadOri': cantidadUnidadOri,
        'cantidadMayorOri': cantidadMayorOri,
        'cantidadBultoOri': cantidadBultoOri,
        'imgUrl100': imgUrl100,
        'discounts': discounts,
        'taxable': taxable,
        'iva_rate': ivaRate,
        'peso': peso,
        'casheaSurchargeApplied': casheaSurchargeApplied,
        'precioCatalogoPresentacion': precioCatalogoPresentacion,
        'presentaciones': presentaciones,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        id: (j['id'] ?? '').toString(),
        nombre: (j['nombre'] ?? j['name'] ?? '').toString(),
        codigo: j['codigo']?.toString(),
        precio: (j['precio'] as num?)?.toDouble() ?? 0,
        precioOri: (j['precioOri'] as num?)?.toDouble() ??
            (j['precio'] as num?)?.toDouble() ??
            0,
        presentacion: (j['presentacion'] ?? 'Unidad').toString(),
        cantidad: (j['cantidad'] as num?)?.toInt() ?? 1,
        totalAux: (j['totalAux'] as num?)?.toDouble() ?? 0,
        precioUnidad: (j['precioUnidad'] as num?)?.toDouble(),
        precioMayor: (j['precioMayor'] as num?)?.toDouble(),
        precioBulto: (j['precioBulto'] as num?)?.toDouble(),
        cantidadBulto: j['cantidadBulto'] ?? 1,
        cantidadUnidadOri: j['cantidadUnidadOri'],
        cantidadMayorOri: j['cantidadMayorOri'],
        cantidadBultoOri: j['cantidadBultoOri'],
        imgUrl100: j['imgUrl100']?.toString(),
        discounts: j['discounts'] is List ? List.from(j['discounts']) : const [],
        taxable: j['taxable'] is bool ? j['taxable'] as bool : null,
        ivaRate: j['iva_rate'] ?? j['ivaRate'],
        peso: j['peso'] ?? 0,
        casheaSurchargeApplied: j['casheaSurchargeApplied'] == true,
        precioCatalogoPresentacion:
            (j['precioCatalogoPresentacion'] as num?)?.toDouble(),
        presentaciones:
            j['presentaciones'] is List ? List.from(j['presentaciones']) : const [],
      );

  CartItem copyWith({
    double? precio,
    double? precioOri,
    String? presentacion,
    int? cantidad,
    double? totalAux,
    num? cantidadBulto,
    bool? casheaSurchargeApplied,
    double? precioCatalogoPresentacion,
  }) {
    return CartItem(
      id: id,
      nombre: nombre,
      codigo: codigo,
      precio: precio ?? this.precio,
      precioOri: precioOri ?? this.precioOri,
      presentacion: presentacion ?? this.presentacion,
      cantidad: cantidad ?? this.cantidad,
      totalAux: totalAux ?? this.totalAux,
      precioUnidad: precioUnidad,
      precioMayor: precioMayor,
      precioBulto: precioBulto,
      cantidadBulto: cantidadBulto ?? this.cantidadBulto,
      cantidadUnidadOri: cantidadUnidadOri,
      cantidadMayorOri: cantidadMayorOri,
      cantidadBultoOri: cantidadBultoOri,
      imgUrl100: imgUrl100,
      discounts: discounts,
      taxable: taxable,
      ivaRate: ivaRate,
      peso: peso,
      casheaSurchargeApplied:
          casheaSurchargeApplied ?? this.casheaSurchargeApplied,
      precioCatalogoPresentacion:
          precioCatalogoPresentacion ?? this.precioCatalogoPresentacion,
      presentaciones: presentaciones,
    );
  }
}

class CategoryItem {
  CategoryItem({
    required this.id,
    required this.nombre,
    this.key,
    this.imgUrl,
    this.icon,
    this.subCategories = const [],
    this.raw = const {},
  });

  final String id;
  final String nombre;
  final String? key;
  final String? imgUrl;
  final String? icon;
  final List<Map<String, dynamic>> subCategories;
  final Map<String, dynamic> raw;

  factory CategoryItem.fromMap(Map<String, dynamic> m, {String? imgUrl}) {
    final subs = <Map<String, dynamic>>[];
    final rawSubs = m['sub_categories'];
    if (rawSubs is List) {
      for (final s in rawSubs) {
        if (s is Map) subs.add(Map<String, dynamic>.from(s));
      }
    }
    return CategoryItem(
      id: (m['id'] ?? m['key'] ?? '').toString(),
      nombre: (m['value'] ?? m['nombre'] ?? '').toString(),
      key: (m['key'] ?? m['id'])?.toString(),
      imgUrl: imgUrl ?? m['imgUrl']?.toString(),
      icon: m['icon']?.toString() ?? '🛒',
      subCategories: subs,
      raw: Map<String, dynamic>.from(m),
    );
  }
}

class Branch {
  Branch({required this.id, required this.name, this.raw = const {}});

  final String id;
  final String name;
  final Map<String, dynamic> raw;

  factory Branch.fromMap(String id, Map<String, dynamic> m) => Branch(
        id: id,
        name: (m['name'] ?? m['nombre'] ?? '').toString(),
        raw: m,
      );
}

class AppUser {
  AppUser({
    required this.uid,
    this.email,
    this.nombre,
    this.apellido,
    this.telefono,
    this.documento,
    this.direccion,
    this.imageUrl,
    this.locations = const [],
    this.raw = const {},
  });

  final String uid;
  final String? email;
  final String? nombre;
  final String? apellido;
  final String? telefono;
  final String? documento;
  final String? direccion;
  final String? imageUrl;
  final List<dynamic> locations;
  final Map<String, dynamic> raw;

  String get displayName {
    final n = [nombre, apellido]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(' ');
    return n.isEmpty ? (email ?? 'Usuario') : n;
  }

  Map<String, dynamic> toJson() => {
        ...raw,
        'uid': uid,
        'email': email,
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'documento': documento,
        'direccion': direccion,
        'imageUrl': imageUrl,
        'locations': locations,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        uid: (j['uid'] ?? '').toString(),
        email: j['email']?.toString(),
        nombre: j['nombre']?.toString(),
        apellido: j['apellido']?.toString(),
        telefono: j['telefono']?.toString(),
        documento: j['documento']?.toString(),
        direccion: j['direccion']?.toString(),
        imageUrl: (j['imageUrl'] ?? j['img'])?.toString(),
        locations: j['locations'] is List ? List.from(j['locations']) : const [],
        raw: Map<String, dynamic>.from(j),
      );
}
