import '../services/promo_service.dart';
import 'caracas_date.dart';

Set<String> _activePromoCampaignIds = {};
bool _loaded = false;
Future<void>? _loadingPromise;

bool isPromoCampaignActive(String? promoCampaignId) {
  if (promoCampaignId == null || promoCampaignId.isEmpty) return true;
  if (!_loaded) return false;
  return _activePromoCampaignIds.contains(promoCampaignId);
}

bool areActivePromoCampaignIdsLoaded() => _loaded;

Future<void> refreshActivePromoCampaignIds(PromoService promo) async {
  if (_loadingPromise != null) return _loadingPromise!;
  _loadingPromise = _doRefresh(promo);
  return _loadingPromise!;
}

Future<void> _doRefresh(PromoService promo) async {
  final ids = <String>{};
  final today = caracasDateString();

  try {
    final banners = await promo.fetchActivePromoBanners();
    for (final b in banners) {
      final id = b['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final action = b['ctaAction']?.toString() ?? '';
      if (action == 'offer_flyer') {
        if (isDateInCaracasRange(b['startDate'], b['endDate'], today)) {
          ids.add(id);
        }
      } else {
        ids.add(id);
      }
    }
  } catch (_) {
    // ignore
  }

  try {
    final offer = await promo.fetchActiveDailyOfferForToday();
    if (offer != null) {
      final id = offer['id']?.toString() ?? '';
      if (id.isNotEmpty &&
          isDateInCaracasRange(offer['startDate'], offer['endDate'], today)) {
        ids.add(id);
      }
    }
  } catch (_) {
    // ignore
  }

  _activePromoCampaignIds = ids;
  _loaded = true;
}
