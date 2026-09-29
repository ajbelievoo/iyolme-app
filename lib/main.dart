import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shortzz/common/controller/ads_controller.dart';
import 'package:shortzz/common/controller/smart_assist_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/subscription/subscription_manager.dart';
import 'package:shortzz/common/widget/restart_widget.dart';
import 'package:shortzz/languages/dynamic_translations.dart';
import 'package:shortzz/screen/splash_screen/splash_screen.dart';
import 'package:shortzz/screen/splash_screen/splash_screen_controller.dart';
import 'package:shortzz/utilities/theme_res.dart';

import 'common/service/network_helper/network_helper.dart';

import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';

import 'package:shortzz/common/service/admob_native_service.dart';
import 'package:shortzz/common/service/draft_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Loggers.success("Handling a background message: ${message.data}");
  await _ensureFirebaseInitialized();
  if (message.notification == null) {
    await FirebaseNotificationManager.showBackgroundNotification(message);
  }
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp();
}

Future<void> _bootstrapFirebaseAndServices() async {
  Loggers.info('[BOOTSTRAP] _bootstrapFirebaseAndServices STARTED');
  try {
    await _ensureFirebaseInitialized();

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Init notification manager (requests permissions etc.)
    FirebaseNotificationManager.instance;

    // Firestore listeners should start only after Firebase is ready.
    if (!Get.isRegistered<FirebaseFirestoreController>()) {
      Get.put(FirebaseFirestoreController(), permanent: true);
    }

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      FirebaseNotificationManager.instance
          .handleNotification(jsonEncode(initialMessage.toMap()));
    }

    // Init RevenueCat (handle errors gracefully)
    try {
      await SubscriptionManager.shared.initPlatformState();
    } catch (e, st) {
      Loggers.error('SubscriptionManager init error: $e\n$st');
    }
    (await AudioSession.instance)
        .configure(const AudioSessionConfiguration.speech());

    // Init Ads with configuration for both debug and release modes
    try {
      Loggers.info('[BOOTSTRAP] About to initialize MobileAds...');
      
      // ONLY use test device IDs in DEBUG mode, not in release
      // COMMENT OUT THE BELOW LINES TO TEST REAL ADS IN DEBUG MODE
      /*
      if (kDebugMode) {
        final config = RequestConfiguration(
          testDeviceIds: const [
            '74460AD8FC5BB6EE4397FEB984A8519E', // Your device ID from logs
          ],
        );
        await MobileAds.instance.updateRequestConfiguration(config);
        Loggers.info('[MobileAds] RequestConfiguration updated with test device ID (DEBUG MODE)');
      } else {
      */
        // RELEASE MODE: No test device IDs = real ads
        Loggers.info('[MobileAds] Using real ad unit IDs (no test device ID registered)');
      // }
      
      await MobileAds.instance.initialize();
      Loggers.info('[MobileAds] ✅ MobileAds initialized successfully');
    } catch (e, st) {
      Loggers.info('[MobileAds] ❌ Initialization error: $e');
      Loggers.info('[MobileAds] Stack: $st');
    }

    NetworkHelper().initialize();

    Get.put(DraftService());
    await DraftService.instance.init();
  } catch (e, st) {
    Loggers.error('Fatal crash during app startup $st');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await GetStorage.init('shortzz');
    try {
      await dotenv.load(fileName: '.env');
    } catch (e, st) {
      Loggers.error('Failed to load .env: $e\n$st');
    }

    unawaited(_ensureFirebaseInitialized());

    // Load Translations
    Get.put(DynamicTranslations());

    // Run app
    runApp(const RestartWidget(child: MyApp()));

    Loggers.info('[MAIN] Calling _bootstrapFirebaseAndServices...');
    try {
      await _bootstrapFirebaseAndServices();
    } catch (e, st) {
      Loggers.info('[MAIN] _bootstrapFirebaseAndServices error: $e');
      Loggers.info('[MAIN] Stack trace: $st');
    }
    
    // Manually ensure AdsController is initialized and ads are loaded
    Loggers.info('[MAIN] Ensuring AdsController is initialized...');
    try {
      if (!Get.isRegistered<AdsController>()) {
        Loggers.info('[MAIN] AdsController not registered, putting it now...');
        Get.put(AdsController(), permanent: true);
      } else {
        Loggers.info('[MAIN] AdsController already registered');
        // Try to reload ads if controller exists but ads aren't loaded
        final adsController = Get.find<AdsController>();
        if (adsController.interstitialAd == null) {
          Loggers.info('[MAIN] Reloading interstitial ad...');
          adsController.loadInterstitialAd();
        }
        if (adsController.rewardedAd == null) {
          Loggers.info('[MAIN] Reloading rewarded ad...');
          adsController.loadRewardedAd();
        }
      }
    } catch (e, st) {
      Loggers.info('[MAIN] AdsController init error: $e');
      Loggers.info('[MAIN] Stack: $st');
    }
  } catch (e, st) {
    Loggers.error('Fatal crash during app startup $st');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _popRouteHandling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChannels.navigation.setMethodCallHandler((call) async {
      if (call.method != 'popRoute') return null;
      if (_popRouteHandling) return true;
      _popRouteHandling = true;
      try {
        await _handleBack();
      } finally {
        _popRouteHandling = false;
      }
      return true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // Check for incoming calls when app resumes
      DashboardScreenController.checkIncomingCalls();
    }
  }

  Future<void> _handleBack() async {
    Loggers.info('[BACK] _handleBack invoked');

    final nav = Get.key.currentState;
    if (nav?.canPop() == true) {
      nav!.pop();
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exit'),
          content: const Text('Do you want to exit the app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      if (Platform.isAndroid) {
        SystemNavigator.pop();
        return;
      }
      nav?.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: Get.key,
      builder: (context, child) {
        return ScrollConfiguration(behavior: MyBehavior(), child: child!);
      },
      initialBinding: InitialBinding(),
      translations: Get.find<DynamicTranslations>(),
      locale: Locale(SessionManager.instance.getLang()),
      fallbackLocale: Locale(SessionManager.instance.getFallbackLang()),
      themeMode: ThemeMode.light,
      darkTheme: ThemeRes.darkTheme(context),
      theme: ThemeRes.lightTheme(context),
      debugShowCheckedModeBanner: false,
      home: const StartupGate(),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  static const int _maxSplashShowsPerWindow = 4;
  static const Duration _splashWindowDuration = Duration(hours: 24);

  late final Future<bool> _showSplashFuture;

  @override
  void initState() {
    super.initState();
    _showSplashFuture = _initAndDecide();
  }

  Future<bool> _initAndDecide() async {
    await _ensureFirebaseInitialized();
    return _shouldShowSplashAndIncrement();
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
      Loggers.warning('StartupGate splash gating failed, defaulting to show splash: $e');
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _showSplashFuture,
      builder: (context, snapshot) {
        final decided = snapshot.connectionState == ConnectionState.done;
        final showSplash = snapshot.data ?? true;

        if (!decided) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFFFFF),
            body: Center(
              child: SizedBox(
                width: 140,
                height: 140,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x00000000)),
                  child: Image(
                    image: AssetImage('assets/images/app_logo.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        }

        if (showSplash) {
          return const SplashScreen();
        }

        final ctrl = Get.put(SplashScreenController());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ctrl.navigateWithoutRemoteSettings();
        });
        return const SizedBox.shrink();
      },
    );
  }
}

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AdsController>()) {
      Get.put(AdsController(), permanent: true);
    }
    if (!Get.isRegistered<SmartAssistController>()) {
      Get.put(SmartAssistController(), permanent: true);
    }
    if (!Get.isRegistered<DraftService>()) {
      Get.put(DraftService(), permanent: true);
      DraftService.instance.init();
    }
    // Initialize AdMob Native Ad Service
    if (!Get.isRegistered<AdMobNativeService>()) {
      Get.put(AdMobNativeService(), permanent: true);
    }
    // NOTE: ScratchCollectController is intentionally NOT registered here.
    // It is created lazily (reels tracking / vault open) so its APIs don't
    // fire before the user is logged in.
  }
}

class MyBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
