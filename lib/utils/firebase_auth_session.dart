import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_provider.dart';

class FirebaseAuthSession {
  static const expiredTitle = 'Sesión expirada';
  static const expiredText =
      'Su sesión ha expirado. Por favor, vuelve a iniciar sesión.';

  static Future<bool> hasValidSession(FirebaseAuth auth) async {
    final current = auth.currentUser;
    if (current == null) return false;
    try {
      await current.getIdToken(false);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> showExpiredDialog(
    BuildContext context, {
    String returnTo = '/cart',
  }) async {
    final goLogin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(expiredTitle),
        content: const Text(expiredText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Iniciar sesión'),
          ),
        ],
      ),
    );
    if (goLogin == true && context.mounted) {
      final encoded = Uri.encodeComponent(returnTo);
      context.push('/login?returnTo=$encoded');
    }
    return goLogin == true;
  }

  /// Si había usuario guardado pero Firebase Auth expiró, limpia y avisa.
  static Future<bool> ensureSessionOrPrompt(
    BuildContext context,
    AppProvider app, {
    String returnTo = '/cart',
  }) async {
    if (await hasValidSession(app.firebase.auth)) return true;
    if (app.user == null) return false;
    await app.clearStaleUser();
    if (!context.mounted) return false;
    await showExpiredDialog(context, returnTo: returnTo);
    return false;
  }

  static Future<void> checkPagoMovilSelection(
    BuildContext context,
    AppProvider app, {
    String returnTo = '/',
  }) async {
    if (app.user == null) return;
    if (await hasValidSession(app.firebase.auth)) return;
    await app.clearStaleUser();
    if (!context.mounted) return;
    await showExpiredDialog(context, returnTo: returnTo);
  }
}
