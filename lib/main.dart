import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/firebase_options.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    return true;
  };

  ErrorWidget.builder = (details) => Material(
        color: AppColors.lightBg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error UI:\n${details.exceptionAsString()}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    debugPrint('Firebase OK (${Platform.operatingSystem})');
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  runApp(const MarketcatiaApp());
}
