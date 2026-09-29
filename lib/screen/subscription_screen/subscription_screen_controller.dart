import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfdropcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/service/api/billing_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/subscription/subscription_manager.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/subscription/subscription_plans_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/subscription_screen/subscription_congrats_screen.dart';
import 'package:shortzz/screen/verification_screen/verification_details_form_screen.dart';
import 'package:shortzz/common/widget/payment_webview_screen.dart';

class SubscriptionScreenController extends BaseController {
  Function(User? user)? onUpdateUser;
  final isRefreshing = false.obs;

  final isLoadingPlans = false.obs;
  final RxList<SubscriptionPlan> plans = <SubscriptionPlan>[].obs;
  final RxString plansDebug = ''.obs;

  Setting? get settings => SessionManager.instance.getSettings();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Map<String, SubscriptionPlan> _productIdToPlan = {};
  final Map<String, ProductDetails> _productIdToDetails = {};

  Razorpay? _razorpay;
  final CFPaymentGatewayService _cashfree = CFPaymentGatewayService();
  SubscriptionPlan? _cashfreePendingPlan;
  final Map<String, SubscriptionPlan> _cashfreeOrderIdToPlan =
      <String, SubscriptionPlan>{};
  final Map<String, String> _cashfreeOrderIdToEnv = <String, String>{};

  bool _paypalVerifyTriggered = false;

  SubscriptionScreenController(this.onUpdateUser);

  bool _planIncludesVerifiedBadge(SubscriptionPlan plan) {
    final flags = plan.featureFlags ?? const <String, bool>{};
    if (flags.isNotEmpty) {
      return flags['verified_badge'] == true;
    }
    final list = plan.features ?? const <String>[];
    return list.any((e) => e.trim() == 'verified_badge');
  }

  Future<void> _goToAfterPurchase(SubscriptionPlan plan,
      {String? paymentId}) async {
    if (_planIncludesVerifiedBadge(plan)) {
      stopLoader();
      try {
        if (Get.isSnackbarOpen) {
          Get.closeAllSnackbars();
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 120));
      Get.to(
        () => VerificationDetailsFormScreen(
          planName: plan.title,
          subscriptionId: (plan.id ?? 0) > 0 ? (plan.id ?? 0) : null,
          paymentId: paymentId,
        ),
      );
      return;
    }
    await _goToCongratsForPlan(plan);
  }

  Future<void> _goToCongratsForPlan(SubscriptionPlan plan) async {
    // Make navigation resilient: ensure loaders/snackbars/bottom-sheets don't block route push.
    stopLoader();
    try {
      if (Get.isSnackbarOpen) {
        Get.closeAllSnackbars();
      }
    } catch (_) {
      // ignore
    }

    // Let overlay pop settle before pushing a new route.
    await Future.delayed(const Duration(milliseconds: 120));

    Get.to(
      () => SubscriptionCongratsScreen(
        planName: plan.title,
        benefits: _benefitsFromPlan(plan),
        user: SessionManager.instance.getUser(),
      ),
    );
  }

  @override
  void onInit() {
    super.onInit();
    refreshStatus();
    fetchPlans();
    _refreshVerificationStatusIfNeeded();
    _purchaseSub ??= _iap.purchaseStream.listen(_onPurchaseUpdate);
    _razorpay = Razorpay();
    _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
    _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
    _razorpay?.on(Razorpay.EVENT_EXTERNAL_WALLET, _onRazorpayExternalWallet);
    try {
      _cashfree.setCallback(_onCashfreeVerify, _onCashfreeError);
    } catch (e) {
      Loggers.error('[SUB] Cashfree init error: $e');
    }
  }

  Future<void> _refreshVerificationStatusIfNeeded() async {
    try {
      final isPlus = SessionManager.instance.getPlusActive == 1;
      if (!isPlus) return;

      final features = SessionManager.instance.getPlusFeatures;
      final requiresVerification = features != null &&
          (features['verified_badge'] == true ||
              features['verified_badge'] == 1 ||
              features['verified_badge'] == '1');
      if (!requiresVerification) return;

      final isVerified = SessionManager.instance.isVerify.value == 1;
      if (isVerified) return;

      final reqId = SessionManager.instance.verificationRequestId.value;
      final res = await UserService.instance
          .fetchVerificationStatus(requestId: reqId > 0 ? reqId : null);
      final d = res.data;
      if (d == null) return;
      final code =
          d.isApproved ? 1 : (d.isRejected ? 2 : (d.isInReview ? 0 : -1));
      SessionManager.instance
          .setVerificationState(status: code, requestId: d.requestId ?? reqId);
      if (d.isApproved) {
        final current = SessionManager.instance.getUser();
        if (current != null && (current.isVerify ?? 0) != 1) {
          SessionManager.instance.setUser(current.copyWith(isVerify: 1));
        }
      }
    } catch (_) {
      // ignore background refresh failures
    }
  }

  List<String> _benefitsFromPlan(SubscriptionPlan? plan) {
    if (plan == null) return const [];
    final List<String> out = [];

    // Prefer richer list if backend provided it.
    final list = (plan.features ?? [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    out.addAll(list);

    final flags = plan.featureFlags ?? const <String, bool>{};
    if (flags.isNotEmpty) {
      for (final entry in flags.entries) {
        if (entry.value != true) continue;
        final k = entry.key.trim();
        if (k.isEmpty) continue;
        out.add(k.replaceAll('_', ' '));
      }
    }

    final mm = (plan.miningMultiplier ?? '').trim();
    if (mm.isNotEmpty && mm != '0' && mm.toLowerCase() != 'null') {
      out.add('Mining multiplier: $mm');
    }

    // Remove duplicates while keeping order.
    final seen = <String>{};
    return out.where((e) => seen.add(e)).toList();
  }

  @override
  void onClose() {
    _purchaseSub?.cancel();
    _razorpay?.clear();
    super.onClose();
  }

  Future<void> refreshStatus() async {
    if (isRefreshing.value) return;
    isRefreshing.value = true;
    try {
      await SubscriptionManager.shared.refreshSubscriptionState();
    } catch (e) {
      Get.rawSnackbar(
        message: 'Subscription status refresh failed. Please retry.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } finally {
      isRefreshing.value = false;
    }
  }

  Future<void> fetchPlans() async {
    if (isLoadingPlans.value) return;
    isLoadingPlans.value = true;
    plansDebug.value = '';
    try {
      try {
        final res = await UserService.instance.subscriptionPlans();
        final list =
            (res.data ?? []).where((p) => (p.status ?? 1) == 1).toList();
        plans.assignAll(list);
        Loggers.success(
            '[SUB] plans api ok total=${(res.data ?? []).length} active=${list.length}');
        final enabled = SessionManager.instance.getSubscriptionEnabled;
        plansDebug.value =
            'enabled=$enabled apiTotal=${(res.data ?? []).length} active=${list.length}';
        await _fetchPlayProductsForPlans(list);
        plansDebug.value =
            '${plansDebug.value} playResolved=${_productIdToDetails.length}';
        Loggers.success(
            '[SUB] play products resolved=${_productIdToDetails.length}');
      } on TimeoutException {
        Loggers.error('[SUB] fetchPlans timeout');
        plans.clear();
        plansDebug.value = 'fetchPlans timeout (server slow / URL issue)';
      } catch (e) {
        Loggers.error('[SUB] fetchPlans failed: $e');
        plans.clear();
        plansDebug.value = 'fetchPlans failed: $e';
      }
    } finally {
      isLoadingPlans.value = false;
    }
  }

  Future<void> _fetchPlayProductsForPlans(List<SubscriptionPlan> list) async {
    final available = await _iap.isAvailable();
    _productIdToPlan.clear();
    _productIdToDetails.clear();
    if (!available) {
      plansDebug.value = '${plansDebug.value} storeAvailable=false';
      return;
    }

    final productIds = <String>{};
    for (final p in list) {
      final id = p.googlePlayProductId;
      if (id == null || id.isEmpty) continue;
      productIds.add(id);
      _productIdToPlan[id] = p;
    }
    if (productIds.isEmpty) {
      plansDebug.value = '${plansDebug.value} productIds=0';
      return;
    }

    try {
      final response = await _iap
          .queryProductDetails(productIds)
          .timeout(const Duration(seconds: 10));
      plansDebug.value =
          '${plansDebug.value} productIds=${productIds.length} found=${response.productDetails.length} notFound=${response.notFoundIDs.length}';
      for (final d in response.productDetails) {
        _productIdToDetails[d.id] = d;
      }
    } on TimeoutException {
      plansDebug.value = '${plansDebug.value} queryProductDetails timeout';
    }
  }

  Future<void> buyWithGooglePlay(SubscriptionPlan plan) async {
    final productId = plan.googlePlayProductId;
    if (productId == null || productId.isEmpty) {
      Get.rawSnackbar(
        message: 'Google Play Product ID missing for this plan.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    final details = _productIdToDetails[productId];
    if (details == null) {
      await _fetchPlayProductsForPlans([plan]);
    }
    final d = _productIdToDetails[productId];
    if (d == null) {
      Get.rawSnackbar(
        message: 'Purchase not available: product not found in Google Play.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    showLoader(barrierDismissible: false);
    try {
      final param = PurchaseParam(productDetails: d);
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      Loggers.error('[SUB] buyNonConsumable failed: $e');
      stopLoader();
      Get.rawSnackbar(
        message: 'Google Play purchase failed. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.pending) continue;

      if (p.status == PurchaseStatus.error ||
          p.status == PurchaseStatus.canceled) {
        stopLoader();
        Get.rawSnackbar(
          message: p.status == PurchaseStatus.canceled
              ? 'Purchase canceled.'
              : 'Purchase failed. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        continue;
      }

      final plan = _productIdToPlan[p.productID];
      if (plan == null) {
        stopLoader();
        Get.rawSnackbar(
          message: 'Purchase received for unknown plan. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        continue;
      }

      final purchaseToken = p.verificationData.serverVerificationData;
      if (purchaseToken.isEmpty) {
        stopLoader();
        Get.rawSnackbar(
          message: 'Purchase verification token missing. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        continue;
      }

      try {
        await UserService.instance.verifySubscription(
          gateway: 'google_play',
          planId: plan.id ?? 0,
          productId: p.productID,
          purchaseToken: purchaseToken,
        );
        await refreshStatus();
        await _goToAfterPurchase(plan, paymentId: purchaseToken);
      } catch (e) {
        Loggers.error('[SUB] verifySubscription google_play failed: $e');
        Get.rawSnackbar(
          message: 'Verification failed. Please contact support.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      } finally {
        // loader is stopped on success before navigation; keep safe for failure paths.
        stopLoader();
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      }
    }
  }

  // Razorpay
  SubscriptionPlan? _razorpayPendingPlan;
  Future<void> buyWithRazorpay(SubscriptionPlan plan) async {
    if (plan.id == null || (plan.id ?? 0) <= 0) {
      Get.rawSnackbar(
        message: 'Plan ID missing. Please contact support.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return;
    }
    if (plan.price == null || (plan.price ?? 0) <= 0) {
      Get.rawSnackbar(
        message: 'Plan price missing. Please contact support.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    showLoader(barrierDismissible: false);
    try {
      var currencyCode = (plan.currency ?? '').trim();
      // Razorpay expects ISO currency code (e.g. INR), not symbol ($/₹).
      if (currencyCode.isEmpty) {
        currencyCode = 'INR';
      }
      if (currencyCode.contains(r'$') || currencyCode.contains('₹')) {
        currencyCode = 'INR';
      }
      currencyCode = currencyCode.toUpperCase();
      if (currencyCode.length != 3) {
        currencyCode = 'INR';
      }

      final create = await BillingService.instance.createRazorpayOrder(
        purpose: 'subscription',
        planId: plan.id,
        // amount: plan.price, // Removing amount to avoid 500 error, assuming backend uses planId
        currency: currencyCode,
      );
      final data = create.data;
      final orderId = data?.razorpayOrderId;
      final keyId = data?.keyId;
      if (orderId == null ||
          orderId.isEmpty ||
          keyId == null ||
          keyId.isEmpty) {
        stopLoader();
        Get.rawSnackbar(
          message: 'Razorpay order create failed. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }
      _razorpayPendingPlan = plan;
      stopLoader();

      _razorpay?.open({
        'key': keyId,
        'order_id': orderId,
        'amount': data?.amount,
        'currency': data?.currency,
        'name': SessionManager.instance.getSettings()?.appName ?? 'App',
        'prefill': {
          'email': SessionManager.instance.getUser()?.userEmail,
          'contact': SessionManager.instance.getUser()?.userMobileNo,
        },
      });
    } catch (e) {
      Loggers.error('[SUB] buyWithRazorpay failed: $e');
      stopLoader();
      Get.rawSnackbar(
        message: 'Razorpay init failed. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _onRazorpaySuccess(PaymentSuccessResponse resp) async {
    final plan = _razorpayPendingPlan;
    _razorpayPendingPlan = null;
    if (plan == null) return;

    showLoader(barrierDismissible: false);
    try {
      await UserService.instance.verifySubscription(
        gateway: 'razorpay',
        planId: plan.id ?? 0,
        razorpayOrderId: resp.orderId,
        razorpayPaymentId: resp.paymentId,
        razorpaySignature: resp.signature,
      );
      await refreshStatus();
      await _goToAfterPurchase(plan, paymentId: resp.paymentId);
    } catch (e) {
      Loggers.error('[SUB] verifySubscription razorpay failed: $e');
      Get.rawSnackbar(
        message: 'Verification failed. Please contact support.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } finally {
      stopLoader();
    }
  }

  void _onRazorpayError(PaymentFailureResponse resp) {
    _razorpayPendingPlan = null;
    Get.rawSnackbar(
      message: 'Payment failed/canceled. Please try again.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  void _onRazorpayExternalWallet(ExternalWalletResponse resp) {
    // no-op
  }

  // Cashfree
  Future<void> buyWithCashfree(SubscriptionPlan plan) async {
    if (plan.id == null || (plan.id ?? 0) <= 0) {
      Get.rawSnackbar(message: 'Plan ID missing.');
      return;
    }
    _cashfreePendingPlan = plan;
    showLoader(barrierDismissible: false);
    try {
      var currencyCode = (settings?.currency ?? 'INR').trim();
      if (currencyCode == '\$' || currencyCode == '₹') currencyCode = 'INR';
      if (currencyCode.length != 3) currencyCode = 'INR';

      // Cashfree requires minimum amount of 1.00
      double amount = (plan.price ?? 0).toDouble();
      if (amount < 1.0) {
        amount = 1.0;
      }

      final create = await BillingService.instance.createCashfreeOrder(
        purpose: 'subscription',
        planId: plan.id,
        amount: amount,
        currency: currencyCode,
      );

      if (create.status != true || create.data == null) {
        throw Exception(create.message ?? 'Failed to create Cashfree order');
      }

      final data = create.data!;
      // Cashfree environment logic
      var env = CFEnvironment.SANDBOX;
      // Prefer backend response env, then settings, then default.
      if (data.environment != null) {
        final e = data.environment!.toUpperCase();
        if (e == 'PRODUCTION') {
          env = CFEnvironment.PRODUCTION;
        } else if (e == 'SANDBOX') {
          env = CFEnvironment.SANDBOX;
        }
      } else if (data.isProduction == true) {
        env = CFEnvironment.PRODUCTION;
      } else if (settings?.cashfreeEndpoint != null &&
          (settings!.cashfreeEndpoint!.contains('api.cashfree.com') ||
              settings!.cashfreeEndpoint!.contains('production'))) {
        env = CFEnvironment.PRODUCTION;
      }

      // Let's Log the environment we are using
      Loggers.info(
          'Cashfree Environment: ${env == CFEnvironment.PRODUCTION ? "PRODUCTION" : "SANDBOX"}');

      if (data.orderId != null && data.orderId!.trim().isNotEmpty) {
        _cashfreeOrderIdToPlan[data.orderId!.trim()] = plan;
        _cashfreeOrderIdToEnv[data.orderId!.trim()] =
            env == CFEnvironment.PRODUCTION ? 'PRODUCTION' : 'SANDBOX';
      }

      final session = CFSessionBuilder()
          .setEnvironment(env)
          .setOrderId(data.orderId!)
          .setPaymentSessionId(data.paymentSessionId!)
          .build();

      final cfPayment =
          CFDropCheckoutPaymentBuilder().setSession(session).build();
      stopLoader();

      Loggers.info(
          '[SUB][CASHFREE] About to open payment sheet orderId=${data.orderId} env=${env == CFEnvironment.PRODUCTION ? "PRODUCTION" : "SANDBOX"}');
      // Cashfree SDK UI opening is sensitive to timing/Activity state.
      // Schedule on next frame after loader/dialog is dismissed.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 150));
        Loggers.info(
            '[SUB][CASHFREE] doPayment about to call orderId=${data.orderId} sessionIdLen=${data.paymentSessionId?.length ?? 0}');
        Loggers.info('[SUB][CASHFREE] doPayment about to call');
        try {
          _cashfree.doPayment(cfPayment);
          Loggers.info('[SUB][CASHFREE] doPayment invoked');
          Loggers.info('[SUB][CASHFREE] doPayment invoked');
        } catch (e) {
          Loggers.info('[SUB][CASHFREE] doPayment threw: $e');
          Loggers.error('[SUB][CASHFREE] doPayment threw: $e');
          showSnackBar('Cashfree doPayment failed: $e');
        }
      });
    } catch (e) {
      stopLoader();
      showSnackBar('Cashfree init failed: $e');
    }
  }

  void _onCashfreeVerify(String orderId) async {
    Loggers.success('[SUB][CASHFREE] verify callback orderId=$orderId');
    final key = orderId.trim();
    final plan = _cashfreeOrderIdToPlan[key] ?? _cashfreePendingPlan;
    final env = _cashfreeOrderIdToEnv[key];
    _cashfreePendingPlan = null;
    _cashfreeOrderIdToPlan.remove(key);
    _cashfreeOrderIdToEnv.remove(key);

    if (plan == null) {
      stopLoader();
      return;
    }
    try {
      await UserService.instance.verifySubscription(
        gateway: 'cashfree',
        planId: plan.id ?? 0,
        cashfreeOrderId: orderId,
        environment: env,
      );
      await refreshStatus();
      await _goToAfterPurchase(plan, paymentId: orderId);
    } catch (e) {
      Loggers.error('[SUB] verifySubscription cashfree failed: $e');
      showSnackBar('Verification failed. Please contact support.');
    } finally {
      stopLoader();
    }
  }

  void _onCashfreeError(CFErrorResponse error, String orderId) {
    Loggers.error(
        '[SUB][CASHFREE] error callback orderId=$orderId msg=${error.getMessage()}');
    stopLoader();
    showSnackBar('Payment Failed: ${error.getMessage()}');
  }

  // PayPal
  Future<void> buyWithPaypal(SubscriptionPlan plan) async {
    if (plan.id == null || (plan.id ?? 0) <= 0) {
      Get.rawSnackbar(message: 'Plan ID missing.');
      return;
    }
    showLoader(barrierDismissible: false);
    try {
      _paypalVerifyTriggered = false;
      final create = await BillingService.instance.createPaypalOrder(
        purpose: 'subscription',
        planId: plan.id,
        amount: plan.price,
        currency: plan.currency ?? 'USD',
      );
      stopLoader();
      if (create.status != true || create.data?.approvalUrl == null) {
        throw Exception(create.message ?? 'Failed to create PayPal order');
      }

      Get.to(() => PaymentWebViewScreen(
            url: create.data!.approvalUrl!,
            title: 'PayPal Subscription',
            onUrlChanged: (url) {
              if (_paypalVerifyTriggered) return;
              final uri = Uri.tryParse(url);
              final lower = url.toLowerCase();

              final qp = uri?.queryParameters ?? const <String, String>{};
              final hasSuccessSignal = lower.contains('success') ||
                  lower.contains('return') ||
                  qp.containsKey('token') ||
                  qp.containsKey('payerid') ||
                  qp.containsKey('paymentid') ||
                  qp.containsKey('orderid');
              final hasCancelSignal = lower.contains('cancel') ||
                  lower.contains('cancelled') ||
                  qp['cancel'] == 'true' ||
                  qp['cancel'] == '1';

              if (hasCancelSignal) {
                _paypalVerifyTriggered = true;
                Get.back();
                Get.rawSnackbar(message: 'PayPal payment cancelled');
                return;
              }
              if (hasSuccessSignal) {
                _paypalVerifyTriggered = true;
                Get.back();
                _verifyPaypalSubscription(plan, create.data!.orderId);
              }
            },
          ));
    } catch (e) {
      stopLoader();
      showSnackBar('PayPal init failed: $e');
    }
  }

  Future<void> _verifyPaypalSubscription(
      SubscriptionPlan plan, String? orderId) async {
    showLoader(barrierDismissible: false);
    try {
      await UserService.instance.verifySubscription(
        gateway: 'paypal',
        planId: plan.id ?? 0,
        paypalOrderId: orderId,
      );
      await refreshStatus();
      await _goToAfterPurchase(plan, paymentId: orderId);
    } catch (e) {
      Loggers.error('[SUB] verifySubscription paypal failed: $e');
      showSnackBar('Verification failed. Please contact support.');
    } finally {
      stopLoader();
    }
  }

  // Stripe
  Future<void> buyWithStripe(SubscriptionPlan plan) async {
    if (plan.id == null || (plan.id ?? 0) <= 0) {
      Get.rawSnackbar(message: 'Plan ID missing.');
      return;
    }
    showLoader(barrierDismissible: false);
    try {
      final create = await BillingService.instance.createStripeOrder(
        purpose: 'subscription',
        planId: plan.id,
        amount: plan.price,
        currency: plan.currency ?? 'USD',
      );
      stopLoader();
      if (create.status != true || create.data?.clientSecret == null) {
        throw Exception(create.message ?? 'Failed to create Stripe order');
      }

      // If backend provides a checkout URL, we could use WebView.
      // But Stripe usually uses native SDK with client_secret.
      Get.rawSnackbar(
          message: 'Stripe integration requires native SDK.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      stopLoader();
      Get.rawSnackbar(
          message: 'Stripe init failed: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _verifyStripeSubscription(
      SubscriptionPlan plan, String? paymentIntentId) async {
    showLoader(barrierDismissible: false);
    try {
      await UserService.instance.verifySubscription(
        gateway: 'stripe',
        planId: plan.id ?? 0,
        stripePaymentIntentId: paymentIntentId,
      );
      await refreshStatus();
      await _goToAfterPurchase(plan, paymentId: paymentIntentId);
    } catch (e) {
      Loggers.error('[SUB] verifySubscription stripe failed: $e');
      Get.rawSnackbar(message: 'Verification failed. Please contact support.');
    } finally {
      stopLoader();
    }
  }
}
