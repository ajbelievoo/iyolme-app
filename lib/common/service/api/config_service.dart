import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/web_service.dart';

class ConfigService {
  ConfigService._();

  static final ConfigService instance = ConfigService._();

  static const _liveProviderKey = 'config_live_provider';
  static const _liveProviderFetchedAtKey = 'config_live_provider_fetched_at';
  static const _arProviderKey = 'config_ar_provider';
  static const _arProviderApiKeyKey = 'config_ar_provider_api_key';
  static const _arProviderFetchedAtKey = 'config_ar_provider_fetched_at';

  static const Duration _defaultTtl = Duration(seconds: 10);

  String getCachedLiveProvider() {
    return (SessionManager.instance.storage.read(_liveProviderKey) ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }

  ArProviderConfig? getCachedArProvider() {
    final provider = (SessionManager.instance.storage.read(_arProviderKey) ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final apiKey =
        (SessionManager.instance.storage.read(_arProviderApiKeyKey) ?? '')
            .toString();
    if (provider.isEmpty) return null;
    return ArProviderConfig(provider: provider, apiKey: apiKey);
  }

  Future<String> getLiveProvider({bool forceRefresh = false, Duration? ttl}) async {
    final cached = getCachedLiveProvider();
    final t = ttl ?? _defaultTtl;

    final fetchedAtMs =
        (SessionManager.instance.storage.read(_liveProviderFetchedAtKey) ?? 0)
            as int;
    final isFresh = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(fetchedAtMs)) <
        t;

    if (!forceRefresh && cached.isNotEmpty && isFresh) {
      Loggers.info(
          '[CONFIG] live provider cache hit provider=$cached ageMs=${DateTime.now().millisecondsSinceEpoch - fetchedAtMs}');
      return cached;
    }

    try {
      Loggers.info(
          '[CONFIG] live provider fetch url=${WebService.config.getLiveProvider} forceRefresh=$forceRefresh');
      final raw = await ApiService.instance.get<Map<String, dynamic>>(
        url: WebService.config.getLiveProvider,
      );

      final provider = _parseProvider(raw);
      Loggers.info(
          '[CONFIG] live provider rawKeys=${raw.keys.toList()} resolved=$provider');
      if (provider.isNotEmpty) {
        SessionManager.instance.storage.write(_liveProviderKey, provider);
        SessionManager.instance.storage
            .write(_liveProviderFetchedAtKey, DateTime.now().millisecondsSinceEpoch);
        return provider;
      }
    } catch (e) {
      Loggers.error('[CONFIG] get-live-provider failed: $e');
    }

    if (cached.isNotEmpty) {
      Loggers.info('[CONFIG] live provider fallback to cached=$cached');
    } else {
      Loggers.info('[CONFIG] live provider fallback empty (no cached)');
    }
    return cached;
  }

  Future<ArProviderConfig?> getArProvider(
      {bool forceRefresh = false, Duration? ttl}) async {
    final cached = getCachedArProvider();
    final t = ttl ?? _defaultTtl;

    final fetchedAtMs =
        (SessionManager.instance.storage.read(_arProviderFetchedAtKey) ?? 0) as int;
    final isFresh = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(fetchedAtMs)) <
        t;

    if (!forceRefresh && cached != null && isFresh) {
      Loggers.info(
          '[CONFIG] ar provider cache hit provider=${cached.provider} ageMs=${DateTime.now().millisecondsSinceEpoch - fetchedAtMs}');
      return cached;
    }

    try {
      Loggers.info(
          '[CONFIG] ar provider fetch url=${WebService.config.getArProvider} forceRefresh=$forceRefresh');
      final raw = await ApiService.instance.get<Map<String, dynamic>>(
        url: WebService.config.getArProvider,
      );

      final provider = _parseProvider(raw);
      final apiKey = _parseApiKey(raw);
      Loggers.info(
          '[CONFIG] ar provider rawKeys=${raw.keys.toList()} resolved=$provider apiKeyPresent=${apiKey.trim().isNotEmpty}');
      if (provider.isNotEmpty) {
        final cfg = ArProviderConfig(provider: provider, apiKey: apiKey);
        SessionManager.instance.storage.write(_arProviderKey, provider);
        SessionManager.instance.storage.write(_arProviderApiKeyKey, apiKey);
        SessionManager.instance.storage
            .write(_arProviderFetchedAtKey, DateTime.now().millisecondsSinceEpoch);
        return cfg;
      }
    } catch (e) {
      Loggers.error('[CONFIG] get-ar-provider failed: $e');
    }

    if (cached != null) {
      Loggers.info(
          '[CONFIG] ar provider fallback to cached provider=${cached.provider} apiKeyPresent=${cached.apiKey.trim().isNotEmpty}');
    } else {
      Loggers.info('[CONFIG] ar provider fallback empty (no cached)');
    }
    return cached;
  }

  String _parseProvider(Map<String, dynamic> raw) {
    final direct = raw['provider'] ??
        raw['live_provider'] ??
        raw['ar_provider'] ??
        raw['value'] ??
        raw['name'];
    if (direct != null) {
      return direct.toString().trim().toLowerCase();
    }

    if (raw['status'] == true && raw['data'] is Map) {
      final data = (raw['data'] as Map).cast<String, dynamic>();
      final v = data['provider'] ??
          data['live_provider'] ??
          data['ar_provider'] ??
          data['value'] ??
          data['name'];
      if (v != null) return v.toString().trim().toLowerCase();
    }

    return '';
  }

  String _parseApiKey(Map<String, dynamic> raw) {
    final direct = raw['api_key'] ?? raw['apiKey'] ?? raw['key'] ?? raw['license_key'];
    if (direct != null) return direct.toString();

    if (raw['status'] == true && raw['data'] is Map) {
      final data = (raw['data'] as Map).cast<String, dynamic>();
      final v = data['api_key'] ??
          data['apiKey'] ??
          data['key'] ??
          data['license_key'];
      if (v != null) return v.toString();
    }

    return '';
  }
}

class ArProviderConfig {
  final String provider;
  final String apiKey;

  ArProviderConfig({required this.provider, required this.apiKey});
}
