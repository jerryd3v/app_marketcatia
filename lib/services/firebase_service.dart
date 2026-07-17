import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';
import '../models/payment_store_settings.dart';

class FirebaseService {
  FirebaseFirestore get db => FirebaseFirestore.instance;
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseStorage get storage => FirebaseStorage.instanceFor(
        bucket: 'gs://marketcatia-c91ae.firebasestorage.app',
      );

  Future<List<CategoryItem>> fetchCategories() async {
    final snap = await db.collection('category').get();
    final list = <CategoryItem>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      String? imgUrl;
      final imageId = data['imageId']?.toString();
      if (imageId != null && imageId.isNotEmpty) {
        try {
          imgUrl = await storage
              .ref('images/icons/category/${imageId}_100x100.png')
              .getDownloadURL();
        } catch (_) {
          try {
            imgUrl = await storage
                .ref('images/icons/category/$imageId.png')
                .getDownloadURL();
          } catch (_) {}
        }
      }
      list.add(CategoryItem.fromMap(data, imgUrl: imgUrl));
    }
    return list;
  }

  Future<List<Branch>> fetchBranches() async {
    final snap = await db.collection('branches').get();
    return snap.docs
        .map((d) => Branch.fromMap(d.id, d.data()))
        .toList();
  }

  Future<List<Product>> fetchBestSellers({int limit = 12}) async {
    final snap = await db
        .collection('products')
        .where('show', isEqualTo: true)
        .get();
    final products = snap.docs
        .map((d) {
          final m = d.data();
          m['id'] = m['idProduct'] ?? d.id;
          return Product.fromMap(m);
        })
        .toList()
      ..sort((a, b) => b.ventas.compareTo(a.ventas));
    return products.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPromoBanners() async {
    try {
      final snap = await db.collection('promo_banners').get();
      return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchDailyOffers() async {
    try {
      final snap = await db.collection('daily_offers').get();
      return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (_) {
      return [];
    }
  }

  /// Misma fuente que web: `app_settings/pago_movil_store` + defaults.
  Future<PaymentStoreSettings> fetchPagoMovilStore() async {
    try {
      final doc =
          await db.collection('app_settings').doc('pago_movil_store').get();
      if (!doc.exists) return PaymentStoreSettings.defaults;
      return PaymentStoreSettings.normalize(doc.data());
    } catch (_) {
      return PaymentStoreSettings.defaults;
    }
  }

  /// Bot de la app: `app_settings/chatbot_app`. Sin doc → deshabilitado.
  Future<bool> fetchChatbotAppEnabled() async {
    try {
      final doc =
          await db.collection('app_settings').doc('chatbot_app').get();
      if (!doc.exists) return false;
      return doc.data()?['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<AppUser?> fetchUser(String uid) async {
    final doc = await db.collection('user').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['uid'] = data['uid'] ?? uid;
    return AppUser.fromJson(data);
  }

  Future<void> incrementSessions(String uid) async {
    final ref = db.collection('user').doc(uid);
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['sessions'] as num?)?.toInt() ?? 0;
      tx.update(ref, {'sessions': current + 1});
    });
  }

  Future<UserCredential> signIn(String email, String password) =>
      auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> register(String email, String password) =>
      auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> sendPasswordReset(String email) =>
      auth.sendPasswordResetEmail(email: email);

  Future<void> createUserDoc(String uid, Map<String, dynamic> data) =>
      db.collection('user').doc(uid).set(data);

  Future<void> updateUserLocations(String uid, List locations) =>
      db.collection('user').doc(uid).update({'locations': locations});

  Future<List<Map<String, dynamic>>> fetchUserOrders(String uid) async {
    // Web guarda idUser; la app antigua guardaba uid.
    final byUid = await db
        .collection('orders')
        .where('uid', isEqualTo: uid)
        .get();
    final byIdUser = await db
        .collection('orders')
        .where('idUser', isEqualTo: uid)
        .get();
    final merged = <String, Map<String, dynamic>>{};
    for (final d in [...byUid.docs, ...byIdUser.docs]) {
      merged[d.id] = {...d.data(), 'id': d.id};
    }
    return merged.values.toList();
  }

  Future<Map<String, dynamic>?> fetchOrder(String id) async {
    final doc = await db.collection('orders').doc(id).get();
    if (!doc.exists) return null;
    return {...doc.data()!, 'id': doc.id};
  }

  Future<Map<String, dynamic>?> fetchTempOrder(String id) async {
    final doc = await db.collection('orders_temp').doc(id).get();
    if (!doc.exists) return null;
    return {...doc.data()!, 'id': doc.id};
  }

  Never _networkFail(String action) {
    throw Exception(
      'Sin conexión: no se pudo $action. Revisa Wi‑Fi o datos e intenta de nuevo.',
    );
  }

  /// Crea la orden con id = [docId] (número de pedido, como la web).
  Future<String> createOrder(
    Map<String, dynamic> data, {
    required String docId,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      final info = Map<String, dynamic>.from(
        (payload['info'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      info['created_at'] = FieldValue.serverTimestamp();
      payload['info'] = info;
      // ponytail: 30s — Firestore retries forever on bad DNS
      await db
          .collection('orders')
          .doc(docId)
          .set(payload)
          .timeout(const Duration(seconds: 30));
      return docId;
    } on TimeoutException {
      _networkFail('crear el pedido');
    }
  }

  Future<void> createPayment(
    Map<String, dynamic> data, {
    String? docId,
  }) async {
    try {
      final col = db.collection('payments');
      if (docId != null && docId.isNotEmpty) {
        await col.doc(docId).set(data).timeout(const Duration(seconds: 30));
      } else {
        await col.add(data).timeout(const Duration(seconds: 30));
      }
    } on TimeoutException {
      _networkFail('registrar el pago');
    }
  }

  Future<String> uploadPaymentImage(
    String orderId,
    List<int> bytes,
    String ext,
  ) async {
    final ref = storage.ref('images/payments/$orderId.$ext');
    try {
      // ponytail: Storage backoff hangs UI; fail fast so user can retry
      await ref
          .putData(Uint8List.fromList(bytes))
          .timeout(const Duration(seconds: 45));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      _networkFail('subir el comprobante');
    } on FirebaseException catch (e) {
      if (e.code == 'retry-limit-exceeded' ||
          e.code == 'unknown' ||
          (e.message ?? '').toLowerCase().contains('network')) {
        _networkFail('subir el comprobante');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDiscounts() async {
    try {
      final snap = await db.collection('discounts').get();
      return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (_) {
      try {
        final snap = await db.collection('discount').get();
        return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<Map<String, dynamic>?> fetchBanner(String id) async {
    final doc = await db.collection('promo_banners').doc(id).get();
    if (!doc.exists) return null;
    return {...doc.data()!, 'id': doc.id};
  }

  Future<void> signOut() => auth.signOut();
}
