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
    final snap = await db
        .collection('orders')
        .where('uid', isEqualTo: uid)
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
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

  Future<String> createOrder(Map<String, dynamic> data) async {
    final ref = await db.collection('orders').add(data);
    return ref.id;
  }

  Future<void> createPayment(Map<String, dynamic> data) =>
      db.collection('payments').add(data);

  Future<String> uploadPaymentImage(
    String orderId,
    List<int> bytes,
    String ext,
  ) async {
    final ref = storage.ref('images/payments/$orderId.$ext');
    await ref.putData(Uint8List.fromList(bytes));
    return ref.getDownloadURL();
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
