import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';

class SubscriptionManager {
  static final SubscriptionManager shared = SubscriptionManager();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  Future<void> initPlatformState() async {
    try {
      await _iap.isAvailable();
    } catch (_) {}
    // Only refresh subscription if user is logged in
    if (SessionManager.instance.isLogin()) {
      await refreshSubscriptionState();
    }
    _purchaseSub ??= _iap.purchaseStream.listen((_) {});
  }

  Future<void> refreshSubscriptionState() async {
    try {
      final res = await UserService.instance.subscriptionStatus();
      final d = res.data;
      if (d != null) {
        SessionManager.instance.setPlusState(
          subscriptionEnabled: d.subscriptionEnabled ?? 0,
          isPlusActive: d.isPlusActive ?? 0,
          expiresAt: d.expiresAt,
          features: d.features,
        );
        Loggers.success(
          '[PLUS] status refreshed enabled=${d.subscriptionEnabled} active=${d.isPlusActive} expiresAt=${d.expiresAt}',
        );
      } else {
        Loggers.error('[PLUS] subscriptionStatus returned null data');
      }
    } catch (e) {
      Loggers.error('[PLUS] refreshSubscriptionState failed: $e');
      rethrow;
    }
  }

  Future<bool> checkSubscriptionStatus() async {
    await refreshSubscriptionState();
    return SessionManager.instance.isPlusEffectiveActive;
  }

  Future<void> subscriptionListener() async {
    await refreshSubscriptionState();
  }

  Future<void> login(String appUserID) async {
    // No-op for custom billing
  }
}
