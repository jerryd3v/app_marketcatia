import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';

class RecoveryPasswordScreen extends StatefulWidget {
  const RecoveryPasswordScreen({super.key});

  @override
  State<RecoveryPasswordScreen> createState() => _RecoveryPasswordScreenState();
}

class _RecoveryPasswordScreenState extends State<RecoveryPasswordScreen> {
  final email = TextEditingController();
  bool loading = false;
  String? message;
  bool success = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      await context.read<AppProvider>().firebase.sendPasswordReset(email.text.trim());
      setState(() {
        success = true;
        message = 'Revisa tu correo para restablecer la contraseña';
      });
    } catch (_) {
      setState(() {
        success = false;
        message = 'No se pudo enviar el correo';
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Recuperar contraseña',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Te enviaremos un enlace a tu correo.',
          style: TextStyle(color: AppColors.textMedium),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo'),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            style: TextStyle(
              color: success ? AppColors.success : AppColors.discount,
            ),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: loading ? null : _send,
          child: loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar enlace'),
        ),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Volver al login'),
        ),
      ],
    );
  }
}
