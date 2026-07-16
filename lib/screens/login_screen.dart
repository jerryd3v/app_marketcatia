import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool loading = false;
  String? error;

  final correo = TextEditingController();
  final password = TextEditingController();
  bool showPwd = false;

  final name = TextEditingController();
  final apellido = TextEditingController();
  final email = TextEditingController();
  final regPwd = TextEditingController();
  final regPwd2 = TextEditingController();
  final telefono = TextEditingController();
  final documento = TextEditingController();
  String tipoDoc = 'V';
  bool acceptTerms = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AppProvider>().user;
      if (user != null) context.go('/');
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    correo.dispose();
    password.dispose();
    name.dispose();
    apellido.dispose();
    email.dispose();
    regPwd.dispose();
    regPwd2.dispose();
    telefono.dispose();
    documento.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });
    final app = context.read<AppProvider>();
    try {
      final cred = await app.firebase.signIn(correo.text.trim(), password.text);
      await app.firebase.incrementSessions(cred.user!.uid);
      final u = await app.firebase.fetchUser(cred.user!.uid);
      if (u != null) {
        app.setUser(u);
        if (mounted) context.go('/');
      } else {
        setState(() => error = 'Usuario sin perfil en Firestore');
      }
    } catch (e) {
      setState(() => error = 'Error al iniciar sesión');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _register() async {
    if (!acceptTerms) {
      setState(() => error = 'Debes aceptar los términos');
      return;
    }
    if (regPwd.text != regPwd2.text) {
      setState(() => error = 'Las contraseñas no coinciden');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    final app = context.read<AppProvider>();
    try {
      final cred =
          await app.firebase.register(email.text.trim(), regPwd.text);
      final uid = cred.user!.uid;
      final data = {
        'uid': uid,
        'email': email.text.trim(),
        'nombre': name.text.trim(),
        'apellido': apellido.text.trim(),
        'telefono': telefono.text.trim(),
        'documento': '$tipoDoc${documento.text.trim()}',
        'locations': [],
        'sessions': 1,
        'createdAt': Timestamp.now(),
      };
      await app.firebase.createUserDoc(uid, data);
      app.setUser(AppUser.fromJson(data));
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => error = 'Error al registrarse');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.cardBg,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Iniciar sesión'),
              Tab(text: 'Registrarse'),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(error!, style: const TextStyle(color: AppColors.discount)),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _loginForm(),
              _registerForm(),
            ],
          ),
        ),
        if (loading) const LinearProgressIndicator(),
      ],
    );
  }

  Widget _loginForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: correo,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: !showPwd,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            suffixIcon: IconButton(
              icon: Icon(showPwd ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => showPwd = !showPwd),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.go('/recovery-password'),
            child: const Text('¿Olvidaste tu contraseña?'),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: loading ? null : _login,
          child: const Text('Entrar'),
        ),
      ],
    );
  }

  Widget _registerForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: apellido,
          decoration: const InputDecoration(labelText: 'Apellido'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: telefono,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: DropdownButtonFormField<String>(
                initialValue: tipoDoc,
                items: const [
                  DropdownMenuItem(value: 'V', child: Text('V')),
                  DropdownMenuItem(value: 'E', child: Text('E')),
                  DropdownMenuItem(value: 'J', child: Text('J')),
                ],
                onChanged: (v) => setState(() => tipoDoc = v ?? 'V'),
                decoration: const InputDecoration(labelText: 'Tipo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: documento,
                decoration: const InputDecoration(labelText: 'Documento'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: regPwd,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Contraseña'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: regPwd2,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
        ),
        CheckboxListTile(
          value: acceptTerms,
          onChanged: (v) => setState(() => acceptTerms = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('Acepto términos y condiciones',
              style: TextStyle(fontSize: 13)),
        ),
        ElevatedButton(
          onPressed: loading ? null : _register,
          child: const Text('Crear cuenta'),
        ),
      ],
    );
  }
}
