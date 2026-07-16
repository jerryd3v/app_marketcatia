import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../constants/geo_reference.dart';
import '../providers/app_provider.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _firebase = FirebaseService();
  List<Map<String, dynamic>> _orders = [];
  bool _loadingOrders = false;

  static const _catiaLatLng = catiaReferenceLocation;

  @override
  void initState() {
    super.initState();
    _loadOrders();
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
      'label': labelCtrl.text.trim(),
      'address': addressCtrl.text.trim(),
      'lat': _catiaLatLng.latitude,
      'lng': _catiaLatLng.longitude,
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    if (user == null) {
      return const Center(child: Text('Inicia sesión para ver tu cuenta'));
    }

    final locations = user.locations;

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
          const SizedBox(height: 24),
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
          if (locations.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tienes direcciones guardadas'),
              ),
            )
          else
            ...List.generate(locations.length, (i) {
              final loc = locations[i] as Map;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: AppColors.primary),
                  title: Text((loc['label'] ?? 'Dirección').toString()),
                  subtitle: Text((loc['address'] ?? '').toString()),
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
        ],
      ),
    );
  }
}
