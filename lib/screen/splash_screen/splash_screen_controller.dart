import 'dart:async';
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/app_open_promotion_manager.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/network_helper/network_helper.dart';
import 'package:shortzz/common/widget/no_internet_sheet.dart';
import 'package:shortzz/languages/dynamic_translations.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/screen/auth_screen/login_screen.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen.dart';
import 'package:shortzz/screen/on_boarding_screen/on_boarding_screen.dart';
import 'package:shortzz/screen/select_language_screen/select_language_screen.dart';
import 'package:shortzz/utilities/app_res.dart';

class SplashScreenController extends BaseController {
  late StreamSubscription _subscription;
  bool isOnline = true;

  static const int _maxSplashShowsPerWindow = 4;
  static const Duration _splashWindowDuration = Duration(hours: 24);

  @override
  void onReady() {
    super.onReady();

    unawaited(_runStartupFlow());

    _subscription = NetworkHelper().onConnectionChange.listen((status) {
      isOnline = status;
      if (isOnline) {
        final route = Get.currentRoute.toLowerCase();
        if (route.contains('nointernetsheet')) {
          Get.key.currentState?.maybePop();
        }
      } else {
        final route = Get.currentRoute.toLowerCase();
        if (!route.contains('nointernetsheet')) {
          Get.to(
            () => const NoInternetSheet(),
            transition: Transition.downToUp,
          );
        }
      }
    });
  }

  @override
  void onClose() {
    super.onClose();
    _subscription.cancel();
  }

  Future<void> _runStartupFlow() async {
    final allowSplash = await _shouldShowSplashAndIncrement();
    if (!allowSplash) {
      navigateWithoutRemoteSettings();
      return;
    }

    await fetchSettings();
  }

  Future<bool> _shouldShowSplashAndIncrement() async {
    try {
      final sm = SessionManager.instance;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final rawStart = sm.storage.read(SessionKeys.splashWindowStartMs);
      final rawCount = sm.storage.read(SessionKeys.splashShowCount);

      final windowStartMs = rawStart is int
          ? rawStart
          : rawStart is num
              ? rawStart.toInt()
              : rawStart is String
                  ? int.tryParse(rawStart)
                  : null;
      final count = rawCount is int
          ? rawCount
          : rawCount is num
              ? rawCount.toInt()
              : rawCount is String
                  ? int.tryParse(rawCount)
                  : null;

      final effectiveStartMs = windowStartMs ?? nowMs;
      final start = DateTime.fromMillisecondsSinceEpoch(effectiveStartMs);

      if (DateTime.now().difference(start) >= _splashWindowDuration) {
        await sm.storage.write(SessionKeys.splashWindowStartMs, nowMs);
        await sm.storage.write(SessionKeys.splashShowCount, 1);
        return true;
      }

      final currentCount = (count ?? 0);
      if (currentCount >= _maxSplashShowsPerWindow) {
        return false;
      }

      await sm.storage.write(SessionKeys.splashWindowStartMs, effectiveStartMs);
      await sm.storage.write(SessionKeys.splashShowCount, currentCount + 1);
      return true;
    } catch (e) {
      Loggers.warning('Splash gating failed, defaulting to show splash: $e');
      return true;
    }
  }

  void navigateWithoutRemoteSettings() {
    try {
      if (SessionManager.instance.isLogin()) {
        Get.off(() => const DashboardScreen());
        return;
      }

      final setting = SessionManager.instance.getSettings();
      final languages = setting?.languages ?? [];
      final isLanguageSelect = SessionManager.instance.getBool(SessionKeys.isLanguageScreenSelect);
      final onBoardingShow = SessionManager.instance.getBool(SessionKeys.isOnBoardingScreenSelect);

      if (!isLanguageSelect) {
        Get.off(() => const SelectLanguageScreen(languageNavigationType: LanguageNavigationType.fromStart));
      } else if (!onBoardingShow && (setting?.onBoarding ?? []).isNotEmpty) {
        Get.off(() => const OnBoardingScreen());
      } else if (languages.isNotEmpty) {
        Get.off(() => const LoginScreen());
      } else {
        Get.off(() => const LoginScreen());
      }
    } catch (_) {
      Get.off(() => const LoginScreen());
    }
  }

  Future<void> fetchSettings() async {
    bool showNavigate = await CommonService.instance
        .fetchGlobalSettings()
        .timeout(const Duration(seconds: 8), onTimeout: () => false);
    if (showNavigate) {
      try {
        final dummyLives = await CommonService.instance
            .fetchDummyLives()
            .timeout(const Duration(seconds: 8), onTimeout: () => <DummyLive>[]);
        final current = SessionManager.instance.getSettings();
        if (current != null) {
          final patched = Setting.fromJson({
            ...current.toJson(),
            'dummyLives': dummyLives.map((e) => e.toJson()).toList(),
          });
          SessionManager.instance.setSettings(patched);
        }
      } catch (e) {
        Loggers.error('fetchDummyLives failed: $e');
      }
      final translations = Get.find<DynamicTranslations>();
      var setting = SessionManager.instance.getSettings();
      var languages = setting?.languages ?? [];
      List<Language> downloadLanguages = languages.where((element) => element.status == 1).toList();
      if (downloadLanguages.isEmpty) {
        showSnackBar(AppRes.languageAdd, second: 5);
        // Do not block the user on splash if the backend hasn't configured languages yet.
        // Fallback to login so the app can still be used.
        Get.off(() => const LoginScreen());
        return;
      }

      var defaultLang = languages.firstWhereOrNull((element) => element.isDefault == 1);
      final fallbackCode = defaultLang?.code ?? 'en';
      SessionManager.instance.setFallbackLang(fallbackCode);

      final selectedLang = SessionManager.instance.getLang();
      final languageToDownload = downloadLanguages.firstWhereOrNull(
            (l) => l.code == selectedLang,
          ) ??
          downloadLanguages.firstWhereOrNull((l) => l.code == fallbackCode) ??
          downloadLanguages.first;

      final downloadedFiles = await downloadAndParseLanguages([languageToDownload])
          .timeout(const Duration(seconds: 8), onTimeout: () => <String, Map<String, String>>{});

      if (downloadedFiles.isNotEmpty) {
        translations.addTranslations(downloadedFiles);
      }

      try {
        await AppOpenPromotionManager.instance
            .maybeShowAppOpenPromotion()
            .timeout(const Duration(seconds: 6));
      } catch (e) {
        Loggers.warning('maybeShowAppOpenPromotion skipped due to error/timeout: $e');
      }

      if (SessionManager.instance.isLogin()) {
        final int userId = SessionManager.instance.getUserID();
        if (userId <= 0) {
          Get.off(() => const LoginScreen());
          return;
        }

        try {
          final value = await UserService.instance
              .fetchUserDetails(userId: userId)
              .timeout(const Duration(seconds: 8), onTimeout: () => null);
          if (isClosed) return;

          if (value != null) {
            Get.off(() => DashboardScreen(myUser: value));
          } else {
            Get.off(() => const LoginScreen());
          }
        } catch (e) {
          Loggers.error('fetchUserDetails failed: $e');
          if (isClosed) return;
          Get.off(() => const LoginScreen());
        }
      } else {
        bool isLanguageSelect = SessionManager.instance.getBool(SessionKeys.isLanguageScreenSelect);
        bool onBoardingShow = SessionManager.instance.getBool(SessionKeys.isOnBoardingScreenSelect);
        if (isLanguageSelect == false) {
          Get.off(() => const SelectLanguageScreen(languageNavigationType: LanguageNavigationType.fromStart));
        } else if (onBoardingShow == false && (setting?.onBoarding ?? []).isNotEmpty) {
          Get.off(() => const OnBoardingScreen());
        } else {
          Get.off(() => const LoginScreen());
        }
      }
    } else {
      // Fallback: proceed with minimal flow if settings couldn't be fetched
      var setting = SessionManager.instance.getSettings();
      if (setting == null) {
        Get.off(() => const LoginScreen());
        return;
      }

      var languages = setting.languages ?? [];
      if (languages.isEmpty) {
        Get.off(() => const LoginScreen());
        return;
      }

      bool isLanguageSelect = SessionManager.instance.getBool(SessionKeys.isLanguageScreenSelect);
      bool onBoardingShow = SessionManager.instance.getBool(SessionKeys.isOnBoardingScreenSelect);
      if (isLanguageSelect == false) {
        Get.off(() => const SelectLanguageScreen(languageNavigationType: LanguageNavigationType.fromStart));
      } else if (onBoardingShow == false && (setting.onBoarding ?? []).isNotEmpty) {
        Get.off(() => const OnBoardingScreen());
      } else {
        Get.off(() => const LoginScreen());
      }
    }
  }

  Future<Map<String, Map<String, String>>> downloadAndParseLanguages(List<Language> languages) async {
    final languageData = <String, Map<String, String>>{};

    for (var language in languages) {
      if (language.code != null && language.csvFile != null) {
        await downloadAndProcessLanguage(language, languageData);
      }
    }

    return languageData;
  }

  Future<void> downloadAndProcessLanguage(Language language, Map<String, Map<String, String>> languageData) async {
    try {
      final response = await http.get(Uri.parse(language.csvFile?.addBaseURL() ?? ''));
      if (response.statusCode == 200) {
        final csvContent = utf8.decode(response.bodyBytes);
        // Parse the CSV into a map
        final parsedMap = _parseCsvToMap(csvContent);
        languageData[language.code!] = parsedMap;

        Loggers.info('Downloaded and parsed: ${language.code}');
      } else {
        Loggers.error('Failed to download ${language.code}: ${response.statusCode}');
      }
    } catch (e) {
      Loggers.error('Error downloading ${language.code}: $e');
    }
  }

  Map<String, String> _parseCsvToMap(String csvContent) {
    final rows = const CsvToListConverter().convert(csvContent);
    final map = <String, String>{};

    for (var row in rows) {
      if (row.length >= 2) {
        map[row[0].toString()] = row[1].toString();
      }
    }
    return map;
  }
}
