import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../constants/geo_reference.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../utils/password.dart';
import '../utils/user_location.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _firebase = FirebaseService();
  final _api = ApiService();
  List<Map<String, dynamic>> _orders = [];
  bool _loadingOrders = false;
  String _view = 'dashboard'; // dashboard | profile | password
  bool _saving = false;
  bool _uploadingPhoto = false;

  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();

  static const _catiaLatLng = catiaReferenceLocation;
  static const _maxPhotoBytes = 3 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final uid = context.read<AppProvider>().user?.uid;
    if (uid == null) return;
    setState(() => _loadingOrders = true);
    try {
      _orders = await _firebase.fetchUserOrders(uid);
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _addAddress() async {
    final user = context.read<AppProvider>().user;
    if (user == null) return;

    final labelCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva dirección'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Etiqueta (Casa, Trabajo...)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _catiaLatLng,
                      zoom: 14,
                    ),
                    markers: {
                      const Marker(
                        markerId: MarkerId('catia'),
                        position: _catiaLatLng,
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    final locations = List<Map<String, dynamic>>.from(
      user.locations.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    locations.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'label': labelCtrl.text.trim(),
      'title': labelCtrl.text.trim(),
      'address': addressCtrl.text.trim(),
      'lat': _catiaLatLng.latitude,
      'lng': _catiaLatLng.longitude,
      'isDefault': locations.isEmpty,
    });
    await _firebase.updateUserLocations(user.uid, locations);
    final updated = await _firebase.fetchUser(user.uid);
    if (updated != null && mounted) {
      context.read<AppProvider>().setUser(updated);
    }
  }

  Future<void> _deleteAddress(int index) async {
    final user = context.read<AppProvider>().user;
    if (user == null) return;
    final locations = List<Map<String, dynamic>>.from(
      user.locations.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    if (index < 0 || index >= locations.length) return;
    locations.removeAt(index);
    await _firebase.updateUserLocations(user.uid, locations);
    final updated = await _firebase.fetchUser(user.uid);
    if (updated != null && mounted) {
      context.read<AppProvider>().setUser(updated);
    }
  }

  Future<void> _setDefaultAddress(String id) async {
    final user = context.read<AppProvider>().user;
    if (user == null) return;
    final next = await _firebase.setDefaultUserLocation(user.uid, id);
    if (!mounted) return;
    context.read<AppProvider>().setUser(
          user.copyWith(locations: next.map((e) => e.toMap()).toList()),
        );
  }

  void _openProfile() {
    final user = context.read<AppProvider>().user;
    _nombreCtrl.text = user?.nombre ?? '';
    _telefonoCtrl.text = user?.telefono ?? '';
    setState(() => _view = 'profile');
  }

  void _openPassword() {
    _pwdCtrl.clear();
    _pwd2Ctrl.clear();
    setState(() => _view = 'password');
  }

  Future<void> _saveProfile() async {
    final user = context.read<AppProvider>().user;
    if (user == null) return;
    final nombre = _nombreCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu nombre.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _firebase.updateUserProfile(
        user.uid,
        nombre: nombre,
        telefono: telefono,
      );
      await _firebase.patchStoreCommentAuthor(user.uid, userName: nombre);
      if (!mounted) return;
      context.read<AppProvider>().setUser(
            user.copyWith(nombre: nombre, telefono: telefono),
          );
      if (mounted) {
        setState(() => _view = 'dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePassword() async {
    final user = context.read<AppProvider>().user;
    if (user == null) return;
    final pwd = _pwdCtrl.text.trim();
    final confirm = _pwd2Ctrl.text.trim();
    if (pwd != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden.')),
      );
      return;
    }
    final err = checkPwd(pwd);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.changePassword(userId: user.uid, newPassword: pwd);
      try {
        await _firebase.updateUserProfile(user.uid, password: pwd);
      } catch (_) {}
      if (mounted) {
        setState(() => _view = 'dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    final user = context.read<AppProvider>().user;
    if (user == null || _uploadingPhoto) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen muy grande. Máximo 3 MB.')),
        );
      }
      return;
    }
    setState(() => _uploadingPhoto = true);
    try {
      final url = await _firebase.uploadProfileImage(user.uid, bytes);
      await _firebase.updateUserProfile(user.uid, imageUrl: url);
      await _firebase.patchStoreCommentAuthor(user.uid, userImg: url);
      if (!mounted) return;
      context.read<AppProvider>().setUser(user.copyWith(imageUrl: url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo subir: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    final user = context.read<AppProvider>().user;
    if (user == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      await _firebase.deleteProfileImage(user.uid);
      await _firebase.updateUserProfile(user.uid, clearImage: true);
      await _firebase.patchStoreCommentAuthor(user.uid, clearImg: true);
      if (!mounted) return;
      context.read<AppProvider>().setUser(user.copyWith(clearImage: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo quitar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    if (user == null) {
      return const Center(child: Text('Inicia sesión para ver tu cuenta'));
    }

    if (_view == 'profile') return _buildProfile(user.email);
    if (_view == 'password') return _buildPassword();

    final parsed = parseUserLocations(user.locations);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: user.imageUrl != null
                        ? NetworkImage(user.imageUrl!)
                        : null,
                    child: user.imageUrl == null
                        ? Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 24,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user.email != null)
                          Text(user.email!, style: const TextStyle(color: AppColors.textLight)),
                        if (user.telefono != null)
                          Text(user.telefono!, style: const TextStyle(color: AppColors.textLight)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppColors.primary),
            title: const Text('Perfil'),
            subtitle: const Text('Edita tu información personal'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openProfile,
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: AppColors.primary),
            title: const Text('Contraseña'),
            subtitle: const Text('Cambia tu contraseña'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openPassword,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mis direcciones',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _addAddress,
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            ],
          ),
          if (parsed.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tienes direcciones guardadas'),
              ),
            )
          else
            ...List.generate(parsed.length, (i) {
              final loc = parsed[i];
              return Card(
                child: ListTile(
                  onTap: () => _setDefaultAddress(loc.id),
                  leading: Icon(
                    loc.isDefault ? Icons.home : Icons.location_on_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(loc.title),
                  subtitle: Text(
                    loc.isDefault
                        ? '${loc.address}\nPredeterminada'
                        : loc.address,
                  ),
                  isThreeLine: loc.isDefault && loc.address.isNotEmpty,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.discount),
                    onPressed: () => _deleteAddress(i),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          const Text(
            'Mis pedidos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_loadingOrders)
            const Center(child: CircularProgressIndicator())
          else if (_orders.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tienes pedidos aún'),
              ),
            )
          else
            ..._orders.map((order) {
              final id = (order['id'] ?? '').toString();
              final status = (order['status'] ?? order['estado'] ?? 'pendiente').toString();
              return Card(
                child: ListTile(
                  title: Text('Pedido #$id'),
                  subtitle: Text('Estado: $status'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/order-view-v2/$id'),
                ),
              );
            }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.read<AppProvider>().logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout, color: AppColors.discount),
              label: const Text('Cerrar sesión', style: TextStyle(color: AppColors.discount)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _confirmDeleteAccount,
              child: const Text(
                'Eliminar cuenta',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(String? email) {
    final user = context.watch<AppProvider>().user;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => setState(() => _view = 'dashboard'),
            icon: const Icon(Icons.arrow_back),
          ),
          const Text('Perfil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundImage: user?.imageUrl != null
                      ? NetworkImage(user!.imageUrl!)
                      : null,
                  child: user?.imageUrl == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _uploadingPhoto ? null : _pickPhoto,
                  child: Text(_uploadingPhoto
                      ? 'Subiendo…'
                      : user?.imageUrl != null
                          ? 'Cambiar foto'
                          : 'Agregar foto'),
                ),
                if (user?.imageUrl != null)
                  TextButton(
                    onPressed: _uploadingPhoto ? null : _removePhoto,
                    child: const Text('Quitar foto', style: TextStyle(color: AppColors.discount)),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            enabled: false,
            decoration: InputDecoration(labelText: 'Correo', hintText: email ?? ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telefonoCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => setState(() => _view = 'dashboard'),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _saveProfile,
                  child: Text(_saving ? 'Guardando…' : 'Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassword() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => setState(() => _view = 'dashboard'),
            icon: const Icon(Icons.arrow_back),
          ),
          const Text('Contraseña', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Mín. 8 caracteres, mayúscula, minúscula, número y un carácter especial.',
            style: TextStyle(color: AppColors.textLight),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwdCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nueva contraseña'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pwd2Ctrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => setState(() => _view = 'dashboard'),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _savePassword,
                  child: Text(_saving ? 'Guardando…' : 'Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordCtrl = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eliminar cuenta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se eliminará tu cuenta y los datos de perfil asociados. Esta acción no se puede deshacer.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirma tu contraseña',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final password = passwordCtrl.text;
      if (password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa tu contraseña para continuar.')),
        );
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      final app = context.read<AppProvider>();
      try {
        await app.deleteAccount(password);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Cuenta eliminada.')),
        );
        context.go('/login');
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString().contains('wrong-password') ||
                e.toString().contains('invalid-credential')
            ? 'Contraseña incorrecta.'
            : 'No se pudo eliminar la cuenta. Intenta de nuevo.';
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      // ponytail: dispose tras un frame — TextField aún cuelga del controller al cerrar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        passwordCtrl.dispose();
      });
    }
  }
}
