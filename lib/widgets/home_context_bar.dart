import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../utils/delivery_cost.dart';
import '../utils/user_location.dart';
import 'delivery_map_section.dart';

class HomeContextBar extends StatefulWidget {
  const HomeContextBar({super.key});

  @override
  State<HomeContextBar> createState() => _HomeContextBarState();
}

class _HomeContextBarState extends State<HomeContextBar> {
  final _api = ApiService();
  final _firebase = FirebaseService();
  final _fmt = NumberFormat('#,##0.00', 'es_VE');
  double? _rate;
  List<UserLocation> _locations = [];

  @override
  void initState() {
    super.initState();
    _loadRate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLocations());
  }

  Future<void> _loadRate() async {
    try {
      final rate = await _api.fetchBcvRate();
      if (mounted && rate > 0) setState(() => _rate = rate);
    } catch (_) {}
  }

  Future<void> _syncLocations() async {
    final uid = context.read<AppProvider>().user?.uid;
    if (uid == null) {
      if (mounted) setState(() => _locations = []);
      return;
    }
    try {
      final list = await _firebase.fetchUserLocations(uid);
      if (mounted) setState(() => _locations = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final loggedIn = app.user != null;
    final fromUser = parseUserLocations(app.user?.locations ?? const []);
    final locs = fromUser.isNotEmpty ? fromUser : _locations;
    final label = shortLocationLabel(
      pickDefaultLocation(locs),
      loggedIn: loggedIn,
    );
    final rateText = _rate == null ? '—' : _fmt.format(_rate);

    return Material(
      color: AppColors.cardBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _openLocationSheet(locs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _openRateSheet,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Tasa de cambio',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                          color: AppColors.textLight,
                        ),
                      ),
                      Text(
                        'Bs. $rateText',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLocationSheet(List<UserLocation> locs) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        locations: locs,
        onChanged: (next) {
          final app = context.read<AppProvider>();
          final user = app.user;
          if (user != null) {
            app.setUser(user.copyWith(locations: next.map((e) => e.toMap()).toList()));
          }
          setState(() => _locations = next);
        },
      ),
    );
    await _syncLocations();
  }

  void _openRateSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExchangeRateSheet(rate: _rate),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({
    required this.locations,
    required this.onChanged,
  });

  final List<UserLocation> locations;
  final ValueChanged<List<UserLocation>> onChanged;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _firebase = FirebaseService();
  late List<UserLocation> _locations;
  bool _map = false;
  bool _autoGps = false;
  bool _saving = false;
  LatLng? _dest;
  String? _address;
  String? _name;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _locations = widget.locations;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    final def = pickDefaultLocation(_locations);
    return _SheetShell(
      title: _map ? 'Selecciona en el mapa' : 'Elige tu ubicación',
      subtitle: _map
          ? null
          : 'Las opciones de envío pueden variar según la dirección.',
      child: user == null
          ? Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/login');
                    },
                    child: const Text('Inicia sesión para ver tus direcciones'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Después podrás usar tu GPS o elegir en el mapa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textLight, fontSize: 13),
                ),
              ],
            )
          : _map
              ? Column(
                  children: [
                    DeliveryMapSection(
                      rates: DeliveryCostRates.defaults,
                      autoGps: _autoGps,
                      onCostChanged: ({
                        required cost,
                        required distanceKm,
                        destination,
                        address,
                        locationName,
                      }) {
                        _dest = destination;
                        _address = address;
                        _name = locationName;
                        _distanceKm = distanceKm;
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : () => _confirmMap(user.uid),
                        child: Text(_saving ? 'Guardando…' : 'Confirmar y guardar'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                  _map = false;
                                  _autoGps = false;
                                }),
                        child: const Text('Volver'),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _option(
                      Icons.near_me,
                      'Usar mi ubicación actual',
                      () => setState(() {
                        _map = true;
                        _autoGps = true;
                      }),
                    ),
                    _option(
                      Icons.map_outlined,
                      'Seleccionar en el mapa',
                      () => setState(() {
                        _map = true;
                        _autoGps = false;
                      }),
                    ),
                    if (_locations.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(0, 12, 0, 8),
                        child: Text(
                          'UBICACIONES GUARDADAS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textLight,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      ..._locations.map((loc) {
                        final selected = def?.id == loc.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: _saving ? null : () => _selectSaved(user.uid, loc),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  width: 2,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                                color: selected
                                    ? AppColors.primary.withValues(alpha: 0.06)
                                    : AppColors.cardBg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${loc.title}${loc.isDefault ? ' · Predeterminada' : ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  if (loc.address.isNotEmpty)
                                    Text(
                                      loc.address,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
    );
  }

  Widget _option(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.primary),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textDark,
          side: const BorderSide(color: AppColors.border, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Future<void> _selectSaved(String uid, UserLocation loc) async {
    setState(() => _saving = true);
    try {
      final next = await _firebase.setDefaultUserLocation(uid, loc.id);
      widget.onChanged(next);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la ubicación predeterminada.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmMap(String uid) async {
    final dest = _dest;
    if (dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un punto en el mapa o usa tu ubicación actual.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final named = _name?.trim() ?? '';
      final fromAddress = extractCity(_address ?? '');
      final title = named.isNotEmpty
          ? named
          : (fromAddress.isNotEmpty ? fromAddress : 'Casa');
      final created = UserLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        address: _address ??
            '${dest.latitude}, ${dest.longitude}',
        lat: dest.latitude,
        lng: dest.longitude,
        distanceKm: _distanceKm,
        zone: (_address ?? title).split(',').first,
        mapUrl: 'https://www.google.com/maps?q=${dest.latitude},${dest.longitude}',
        isDefault: true,
      );
      await _firebase.addUserLocation(uid, created);
      final next = await _firebase.setDefaultUserLocation(uid, created.id);
      widget.onChanged(next);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la ubicación.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ExchangeRateSheet extends StatefulWidget {
  const _ExchangeRateSheet({required this.rate});
  final double? rate;

  @override
  State<_ExchangeRateSheet> createState() => _ExchangeRateSheetState();
}

class _ExchangeRateSheetState extends State<_ExchangeRateSheet> {
  late final TextEditingController _usd;
  late final TextEditingController _bs;

  double? get _rate => widget.rate;

  @override
  void initState() {
    super.initState();
    _usd = TextEditingController(text: '1');
    final r = _rate;
    _bs = TextEditingController(
      text: r != null && r > 0 ? _round2(r).toString() : '',
    );
  }

  @override
  void dispose() {
    _usd.dispose();
    _bs.dispose();
    super.dispose();
  }

  double _round2(double n) => (n * 100).round() / 100;

  void _fromUsd(String value) {
    final n = double.tryParse(value.replaceAll(',', '.'));
    final r = _rate;
    if (n == null || r == null || r <= 0) {
      _bs.text = '';
      return;
    }
    _bs.text = '${_round2(n * r)}';
  }

  void _fromBs(String value) {
    final n = double.tryParse(value.replaceAll(',', '.'));
    final r = _rate;
    if (n == null || r == null || r <= 0) {
      _usd.text = '';
      return;
    }
    _usd.text = '${_round2(n / r)}';
  }

  @override
  Widget build(BuildContext context) {
    final r = _rate;
    final rateLabel = r == null
        ? '—'
        : NumberFormat('#,##0.00', 'es_VE').format(r);
    return _SheetShell(
      title: 'Tasa de cambio',
      subtitle: '1 USD = Bs. $rateLabel',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _field('USD', '\$', _usd, _fromUsd)),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 6, right: 6),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFEEF2FF),
                  child: Icon(Icons.swap_horiz, color: AppColors.primary, size: 18),
                ),
              ),
              Expanded(child: _field('VES', 'Bs', _bs, _fromBs)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '*Tasa de cambio de acuerdo al Banco Central de Venezuela',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    String prefix,
    TextEditingController ctrl,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixText: '$prefix ',
            filled: true,
            fillColor: AppColors.cardBg,
          ),
        ),
      ],
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
