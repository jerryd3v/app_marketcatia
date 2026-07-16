import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';

class CampaignScreen extends StatefulWidget {
  const CampaignScreen({
    super.key,
    this.bannerId,
    this.isDailyOffers = false,
  });

  final String? bannerId;
  final bool isDailyOffers;

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  final _firebase = FirebaseService();
  Map<String, dynamic>? _banner;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.bannerId != null) _loadBanner();
  }

  Future<void> _loadBanner() async {
    setState(() => _loading = true);
    try {
      _banner = await _firebase.fetchBanner(widget.bannerId!);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDailyOffers) {
      return _DailyOffersPage();
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_banner == null) {
      return const Center(child: Text('Campaña no encontrada'));
    }

    final imageUrl =
        (_banner!['imageUrl'] ?? _banner!['imgUrl'] ?? '').toString();
    final title = (_banner!['title'] ?? _banner!['nombre'] ?? 'Campaña').toString();
    final description =
        (_banner!['description'] ?? _banner!['descripcion'] ?? '').toString();
    final link = (_banner!['link'] ?? _banner!['url'] ?? '').toString();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _placeholder(title),
            )
          else
            _placeholder(title),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(description, style: const TextStyle(color: AppColors.textMedium)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Ver productos'),
                ),
                if (link.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Más información'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String title) {
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DailyOffersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final offers = context.watch<AppProvider>().dailyOffers;

    if (offers.isEmpty) {
      return const Center(child: Text('No hay ofertas del día disponibles'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final offer = offers[index];
        final name = (offer['name'] ?? offer['title'] ?? 'Oferta').toString();
        final pct = offer['percent'] ?? offer['discount'];
        final desc = (offer['description'] ?? '').toString();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (pct != null)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.discountBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '-$pct%',
                      style: const TextStyle(
                        color: AppColors.discount,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (desc.isNotEmpty)
                        Text(desc, style: const TextStyle(color: AppColors.textLight)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
