import '../hive/hive_service.dart';
import 'api_service.dart';

enum BannerFrequency { once, daily, always }

class BannerData {
  final int id;
  final String imageUrl;
  final String? linkUrl;
  final BannerFrequency frequency;

  BannerData({
    required this.id,
    required this.imageUrl,
    this.linkUrl,
    required this.frequency,
  });

  factory BannerData.fromJson(Map<String, dynamic> json) => BannerData(
        id: json['id'] as int,
        imageUrl: json['image_url'] as String,
        linkUrl: json['link_url'] as String?,
        frequency: _parseFrequency(json['display_frequency'] as String?),
      );

  static BannerFrequency _parseFrequency(String? value) {
    switch (value) {
      case 'daily':  return BannerFrequency.daily;
      case 'always': return BannerFrequency.always;
      default:       return BannerFrequency.once;
    }
  }
}

class BannerService {
  static const _fetchKey     = 'bannerFetchedAt';
  static const _imageKey     = 'bannerImageUrl';
  static const _linkKey      = 'bannerLinkUrl';
  static const _idKey        = 'bannerId';
  static const _freqKey      = 'bannerFrequency';
  static const _shownIdsKey  = 'bannerShownIds';
  static const _lastShownKey = 'bannerLastShownAt';

  // In-memory: banner IDs already shown in this app session
  static final Set<int> _sessionShownIds = {};

  // Cache 1 jam jika ada banner, 15 menit jika tidak ada banner
  static const _cacheHours        = 1;
  static const _noActiveCacheMin  = 15;

  static Future<BannerData?> getActive() async {
    final box    = HiveService.user;
    final cached = _readCache(box);

    if (cached != null) {
      // Ada data di cache — langsung cek apakah perlu ditampilkan
      return _shouldShow(box, cached) ? cached : null;
    }

    // Cache expired atau kosong — fetch dari server
    try {
      final res  = await ApiService().dio.get('/banner/active');
      final data = res.data['data'];
      final now  = DateTime.now().toIso8601String();

      if (data == null) {
        // Fix Bug 2: tidak ada banner aktif, cache 15 menit saja
        _clearBannerData(box);
        await box.put(_fetchKey, now);
        return null;
      }

      final banner = BannerData.fromJson(Map<String, dynamic>.from(data));
      await box.put(_fetchKey, now);
      await box.put(_imageKey, banner.imageUrl);
      await box.put(_linkKey, banner.linkUrl);
      await box.put(_idKey, banner.id);
      await box.put(_freqKey, banner.frequency.name);

      return _shouldShow(box, banner) ? banner : null;
    } catch (_) {
      return null;
    }
  }

  // Baca dari cache — return null jika expired
  static BannerData? _readCache(dynamic box) {
    final lastFetchStr = box.get(_fetchKey) as String?;
    if (lastFetchStr == null) return null;

    final lastFetch = DateTime.tryParse(lastFetchStr);
    if (lastFetch == null) return null;

    final diff    = DateTime.now().difference(lastFetch);
    final imageUrl = box.get(_imageKey) as String?;

    // Tidak ada banner aktif — cache 15 menit
    if (imageUrl == null) {
      return diff.inMinutes < _noActiveCacheMin ? null : null;
      // Selalu return null supaya re-fetch setelah 15 menit
    }

    // Ada banner — cache 1 jam
    if (diff.inHours >= _cacheHours) return null;

    return BannerData(
      id: box.get(_idKey) as int? ?? 0,
      imageUrl: imageUrl,
      linkUrl: box.get(_linkKey) as String?,
      frequency: BannerData._parseFrequency(box.get(_freqKey) as String?),
    );
  }

  static bool _shouldShow(dynamic box, BannerData banner) {
    switch (banner.frequency) {
      case BannerFrequency.always:
        return !_sessionShownIds.contains(banner.id);

      case BannerFrequency.once:
        return !_getShownIds(box).contains(banner.id);

      case BannerFrequency.daily:
        final lastShownStr =
            box.get('${_lastShownKey}_${banner.id}') as String?;
        if (lastShownStr == null) return true;
        final lastShown = DateTime.tryParse(lastShownStr);
        if (lastShown == null) return true;
        return DateTime.now().difference(lastShown).inHours >= 24;
    }
  }

  // Dipanggil setelah banner ditampilkan ke user
  static Future<void> markShown(BannerData banner) async {
    final box = HiveService.user;
    switch (banner.frequency) {
      case BannerFrequency.once:
        final ids = _getShownIds(box);
        if (!ids.contains(banner.id)) ids.add(banner.id);
        // Fix Bug 4: batasi maksimal 100 ID supaya tidak terus bertambah
        final trimmed = ids.length > 100 ? ids.sublist(ids.length - 100) : ids;
        await box.put(_shownIdsKey, trimmed);
        // Fix Bug 1: hapus cache supaya next open fetch banner baru dari server
        await box.delete(_fetchKey);
        _clearBannerData(box);
        break;

      case BannerFrequency.daily:
        await box.put(
          '${_lastShownKey}_${banner.id}',
          DateTime.now().toIso8601String(),
        );
        break;

      case BannerFrequency.always:
        _sessionShownIds.add(banner.id);
        break;
    }
  }

  static List<int> _getShownIds(dynamic box) =>
      (box.get(_shownIdsKey) as List?)?.map((e) => e as int).toList() ?? [];

  static void _clearBannerData(dynamic box) {
    box.delete(_imageKey);
    box.delete(_linkKey);
    box.delete(_idKey);
    box.delete(_freqKey);
  }
}
