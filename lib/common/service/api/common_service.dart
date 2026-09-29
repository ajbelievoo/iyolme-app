import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/model/general/file_path_model.dart';
import 'package:shortzz/model/general/location_place_model.dart';
import 'package:shortzz/model/general/place_detail.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/utilities/app_res.dart';

class CommonService {
  CommonService._();

  static final CommonService instance = CommonService._();

  static Future<bool>? _settingsInFlight;
  static int _settingsLastFetchedAtMs = 0;
  static const int _settingsCacheMs = 10 * 60 * 1000; // 10 minutes

  void showToast(String msg) {
    Fluttertoast.showToast(msg: msg);
  }

  static const MethodChannel _appConfigChannel =
      MethodChannel('com.retrytech.shortzz/app_config');
  static Future<String?>? _cachedGoogleMapsApiKey;

  Future<String?> _getGoogleMapsApiKeyFromPlatform() {
    _cachedGoogleMapsApiKey ??= () async {
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          final key = await _appConfigChannel.invokeMethod<String>(
            'getGoogleMapsApiKey',
          );
          if (key != null && key.trim().isNotEmpty) {
            return key.trim();
          }
        }
      } catch (_) {}
      return null;
    }();

    return _cachedGoogleMapsApiKey!;
  }

  Future<String?> _resolvePlacesApiKey() async {
    final settings = SessionManager.instance.getSettings();
    final raw = (settings?.placeApiAccessToken ?? '').trim();

    // The settings field is named like an access token, but Places API expects an API key.
    // We treat OAuth tokens (ya29...) as invalid here.
    if (raw.isNotEmpty && raw.startsWith('AIza')) {
      return raw;
    }

    if (raw.isNotEmpty && raw.startsWith('ya29.')) {
      Loggers.error('❌ placeApiAccessToken looks like OAuth token (ya29...), not an API key');
    }

    final fallback = await _getGoogleMapsApiKeyFromPlatform();
    if (fallback == null || fallback.isEmpty) {
      Loggers.error('❌ Google Maps API key not found for Places API');
    }
    return fallback;
  }

  Future<List<DummyLive>> fetchDummyLives() async {
    final dynamic raw = await ApiService.instance.call(
      url: WebService.setting.fetchDummyLives,
      cancelAuthToken: true,
    );

    if (raw is! Map<String, dynamic>) return <DummyLive>[];

    dynamic data = raw['data'] ?? raw['dummyLives'] ?? raw['dummy_lives'];
    if (data is Map<String, dynamic>) {
      data = data['dummyLives'] ?? data['dummy_lives'] ?? data['data'];
    }

    if (data is! List) return <DummyLive>[];

    return data
        .whereType<Map>()
        .map((e) => DummyLive.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<bool> fetchGlobalSettings({bool forceRefresh = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = SessionManager.instance.getSettings();
    if (!forceRefresh && cached != null) {
      final age = now - _settingsLastFetchedAtMs;
      if (_settingsLastFetchedAtMs > 0 && age >= 0 && age < _settingsCacheMs) {
        return true;
      }
    }

    if (!forceRefresh && _settingsInFlight != null) {
      return _settingsInFlight!;
    }

    _settingsInFlight = () async {
      try {
        final dynamic raw = await ApiService.instance.call<dynamic>(
          url: WebService.setting.fetchSettings,
          cancelAuthToken: false,
        );

        if (raw is Map<String, dynamic>) {
          int len(dynamic v) {
            if (v is List) return v.length;
            if (v is Map) {
              final dynamic next = v['data'] ?? v['items'] ?? v['list'] ?? v['packages'];
              if (next is List) return next.length;
            }
            return -1;
          }

          dynamic dig(dynamic v) {
            if (v is Map) {
              return v['adWalletPackages'] ??
                  v['adsWalletPackages'] ??
                  v['ad_wallet_packages'] ??
                  v['ads_wallet_packages'] ??
                  v['ad_wallet_plans'] ??
                  v['ads_wallet_plans'] ??
                  v['adWalletPlans'] ??
                  v['adsWalletPlans'];
            }
            return null;
          }

          final top = dig(raw);
          final data = dig(raw['data']);
          final nestedData = (raw['data'] is Map) ? dig((raw['data'] as Map)['data']) : null;
          final settings = (raw['data'] is Map) ? dig((raw['data'] as Map)['settings']) : null;

          Loggers.info(
            '[SETTINGS_RAW] keys=${raw.keys.toList()} topLen=${len(top)} dataLen=${len(data)} nestedDataLen=${len(nestedData)} settingsLen=${len(settings)}',
          );
        }

        final SettingModel settingsModel =
            (raw is Map<String, dynamic>) ? SettingModel.fromJson(raw) : SettingModel.fromJson({});

        var setting = settingsModel.data;
        if (setting != null) {
          Loggers.info(
              '[SETTINGS] itemBaseUrl=${(setting.itemBaseUrl ?? '').trim()} luts=${setting.luts?.length ?? 0} deepARFilters=${setting.deepARFilters?.length ?? 0}');
          Loggers.info(
              '[SETTINGS] coinPackages=${setting.coinPackages?.length ?? 0} adWalletPackages=${setting.adWalletPackages?.length ?? 0}');
          SessionManager.instance.setSettings(setting);
          _settingsLastFetchedAtMs = DateTime.now().millisecondsSinceEpoch;
          return true;
        }
        return false;
      } catch (e) {
        Loggers.error('[SETTINGS] fetchGlobalSettings failed: $e');
        return false;
      } finally {
        _settingsInFlight = null;
      }
    }();

    return _settingsInFlight!;
  }

  Future<FilePathModel> uploadFileGivePath(XFile files,
      {Function(double percentage)? onProgress}) async {
    FilePathModel model = await ApiService.instance.multiPartCallApi(
      url: WebService.setting.uploadFileGivePath,
      filesMap: {
        Params.file: [files]
      },
      onProgress: onProgress,
      fromJson: FilePathModel.fromJson,
    );

    return model;
  }

  Future<StatusModel> deleteFile(String filePath) async {
    StatusModel model = await ApiService.instance.call(
        url: WebService.setting.deleteFile,
        param: {Params.filePath: filePath},
        fromJson: StatusModel.fromJson);
    return model;
  }

  Future<List<Places>> searchPlace({String title = ''}) async {
    if (title.trim().isEmpty) {
      return <Places>[];
    }
    final apiKey = (await _resolvePlacesApiKey()) ?? '';
    if (apiKey.trim().isEmpty) {
      return <Places>[];
    }

    Map<String, String> header = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': '*',
    };

    Map<String, dynamic> body = {
      Params.textQuery: title,
      Params.maxResultCount: '${AppRes.paginationLimit}'
    };

    Uri uri = Uri.parse(WebService.google.searchTextByPlace);

    Loggers.info(uri);
    Loggers.info(header);
    Loggers.info(body);

    Response response = await post(uri, headers: header, body: jsonEncode(body));
    if (response.statusCode != 200) {
      Loggers.error(
          '❌ Places searchText failed status=${response.statusCode} body=${response.body}');
      return <Places>[];
    }
    LocationPlaceModel model =
        LocationPlaceModel.fromJson(jsonDecode(response.body));

    Loggers.error(model.error?.toJson() ?? 'NO ERROR');
    Loggers.success(model.places?.map((e) => e.toJson()));

    return model.places ?? [];
  }

  Future<List<Places>> searchNearBy(
      {required double lat, required double lon}) async {
    final apiKey = (await _resolvePlacesApiKey()) ?? '';
    if (apiKey.trim().isEmpty) {
      return <Places>[];
    }

    Map<String, String> header = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': '*',
    };
    Map<String, dynamic> locationRestriction = {
      Params.circle: {
        Params.center: {Params.latitude: '$lat', Params.longitude: '$lon'},
        Params.radius: '${AppRes.nearBySearchRadius}'
      }
    };
    Map<String, dynamic> body = {
      Params.includedTypes: AppRes.nearbySearchTypes,
      Params.maxResultCount: AppRes.paginationLimit.toString(),
      Params.locationRestriction: locationRestriction
    };

    Uri uri = Uri.parse(WebService.google.searchNearByPlace(lat, lon));

    Loggers.info('URI : $uri');
    Loggers.info('HEADER : $header');
    Loggers.info('BODY : $body');
    Response response =
        await post(uri, headers: header, body: jsonEncode(body));
    if (response.statusCode != 200) {
      Loggers.error(
          '❌ Places searchNearby failed status=${response.statusCode} body=${response.body}');
      return <Places>[];
    }
    LocationPlaceModel model =
        LocationPlaceModel.fromJson(jsonDecode(response.body));

    Loggers.error(model.error?.toJson() ?? 'NO ERROR');
    Loggers.success(model.places?.map((e) => e.toJson()));

    return model.places ?? [];
  }

  Future<PlaceDetail> getIPPlaceDetail() async {
    Map<String, dynamic> detail =
        await ApiService.instance.callGet(url: WebService.common.ipApi);
    return PlaceDetail.fromJson(detail);
  }
}
