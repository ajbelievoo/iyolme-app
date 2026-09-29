import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/service/api/api_service.dart';

class ArService {
  ArService._();

  static final ArService instance = ArService._();

  Future<ArActiveProvider?> fetchActiveProvider({required String baseUrl}) async {
    final url = baseUrl.endsWith('/') ? '${baseUrl}api/ar/active-provider' : '$baseUrl/api/ar/active-provider';
    try {
      final raw = await ApiService.instance.get<Map<String, dynamic>>(
        url: url,
        cancelAuthToken: true,
      );
      return _parse(raw);
    } catch (e) {
      Loggers.error('[AR] active-provider failed url=$url err=$e');
      return null;
    }
  }

  ArActiveProvider? _parse(Map<String, dynamic> raw) {
    if (raw['provider'] != null) {
      return ArActiveProvider.fromJson(raw);
    }
    if (raw['status'] == true && raw['data'] is Map) {
      return ArActiveProvider.fromJson((raw['data'] as Map).cast<String, dynamic>());
    }
    return null;
  }
}

class ArActiveProvider {
  final String provider;
  final String apiKey;

  ArActiveProvider({required this.provider, required this.apiKey});

  factory ArActiveProvider.fromJson(Map<String, dynamic> json) {
    return ArActiveProvider(
      provider: (json['provider'] ?? '').toString().trim().toLowerCase(),
      apiKey: (json['api_key'] ?? json['apiKey'] ?? '').toString(),
    );
  }
}
