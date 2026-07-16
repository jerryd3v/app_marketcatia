import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones Firebase del proyecto marketcatia-c91ae
/// (alineadas con google-services.json y GoogleService-Info.plist).
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
    apiKey: 'AIzaSyC5KojJdDISz0LgA6ERKWRGso4JHKsfOIY',
    appId: '1:107853434846:android:fabde4681ae9c0c0cb174f',
    messagingSenderId: '107853434846',
    projectId: 'marketcatia-c91ae',
    storageBucket: 'marketcatia-c91ae.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBU2BqvHoVK0Mm6h3ztGnC-ywSFonoWxWw',
    appId: '1:107853434846:ios:d3faf3690aa578eecb174f',
    messagingSenderId: '107853434846',
    projectId: 'marketcatia-c91ae',
    storageBucket: 'marketcatia-c91ae.firebasestorage.app',
    iosBundleId: 'com.marketcatia.appMarketcatia',
  );
}
