import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones Firebase del proyecto marketcatia-c91ae.
/// ponytail: usa appId web hasta registrar apps nativas en Firebase Console.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDDvEeXFKg3m_R4JyBt1CouFoAcDgXzj5I',
    appId: '1:107853434846:web:6fbadc8303c53462cb174f',
    messagingSenderId: '107853434846',
    projectId: 'marketcatia-c91ae',
    authDomain: 'marketcatia-c91ae.firebaseapp.com',
    storageBucket: 'marketcatia-c91ae.firebasestorage.app',
    measurementId: 'G-0WSNYY46YY',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDDvEeXFKg3m_R4JyBt1CouFoAcDgXzj5I',
    appId: '1:107853434846:web:6fbadc8303c53462cb174f',
    messagingSenderId: '107853434846',
    projectId: 'marketcatia-c91ae',
    storageBucket: 'marketcatia-c91ae.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDDvEeXFKg3m_R4JyBt1CouFoAcDgXzj5I',
    appId: '1:107853434846:web:6fbadc8303c53462cb174f',
    messagingSenderId: '107853434846',
    projectId: 'marketcatia-c91ae',
    storageBucket: 'marketcatia-c91ae.firebasestorage.app',
    iosBundleId: 'com.marketcatia.appMarketcatia',
  );
}
