import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/service/api/gift_wallet_service.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfdropcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:shortzz/common/service/api/billing_service.dart';
import 'package:flutter/material.dart';
import 'package:shortzz/common/widget/payment_webview_screen.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';

class CoinWalletScreenController extends BaseController {
  Rx<User?> myUser = Rx<User?>(null);
  final InAppPurchase _iap = InAppPurchase.instance;
  final Razorpay _razorpay = Razorpay();
  final CFPaymentGatewayService _cashfree = CFPaymentGatewayService();

  bool _paypalVerifyTriggered = false;

  final Map<String, CoinPlan> _productIdToPlan = {};
  final Map<String, ProductDetails> _productIdToDetails = {};
  final isStoreAvailable = false.obs;
  final RxString coinPlansDebug = ''.obs;

  Setting? get settings => SessionManager.instance.getSettings();
  RxList<CoinPlan> coinPlans = <CoinPlan>[].obs;

  bool canPurchase(CoinPlan offer) {
    final gateways = settings?.gateways;
    final otherGatewaysActive = (gateways?.razorpay == true) ||
        (gateways?.cashfree == true) ||
        (gateways?.paypal == true) ||
        (gateways?.stripe == true);

    if (otherGatewaysActive) return true;

    if (offer.id.isEmpty) return false;
    return _productIdToDetails.containsKey(offer.id);
  }

  @override
  void onInit() {
    super.onInit();
    fetchData();
    Future.microtask(() async {
      await _ensureSettings();
      await fetchProducts();
    });
    _iap.purchaseStream.listen(_onPurchaseUpdate);
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onRazorpayWallet);
    try {
      _cashfree.setCallback(_onCashfreeVerify, _onCashfreeError);
    } catch (e) {
      Loggers.error('[COIN] Cashfree init error: $e');
    }
  }

  @override
  void onClose() {
    _razorpay.clear();
    super.onClose();
  }

  Future<void> _ensureSettings() async {
    final current = settings;
    if (current != null && (current.coinPackages?.isNotEmpty ?? false)) {
      coinPlansDebug.value =
          'settings coinPackages=${current.coinPackages?.length ?? 0}';
      return;
    }
    try {
      await CommonService.instance.fetchGlobalSettings();
      coinPlansDebug.value =
          'settings refreshed coinPackages=${settings?.coinPackages?.length ?? 0}';
    } catch (e) {
      Loggers.error('[COIN] fetchGlobalSettings failed: $e');
      coinPlansDebug.value = 'fetchGlobalSettings failed: $e';
    }
  }

  void fetchData() {
    myUser.value = SessionManager.instance.getUser();
  }

  Future<void> fetchProducts() async {
    final available = await _iap.isAvailable();
    isStoreAvailable.value = available;
    coinPlansDebug.value = 'storeAvailable=$available';

    coinPlans.clear();
    _productIdToPlan.clear();
    _productIdToDetails.clear();

    final packages = settings?.coinPackages;
    Loggers.info(
        '[COIN] storeAvailable=$available packages=${packages?.length ?? 0}');
    coinPlansDebug.value =
        '${coinPlansDebug.value} packages=${packages?.length ?? 0}';
    if (packages == null || packages.isEmpty) return;

    final productIds = <String>{};
    for (final p in packages) {
      if (p.status != 1) continue;
      final id = p.playStoreProductId;
      if (id == null || id.isEmpty) continue;
      productIds.add(id);
      _productIdToPlan[id] = CoinPlan(
        p.coinAmount ?? 0,
        p.id ?? -1,
        id,
        '',
        coinPlanPrice: p.coinPlanPrice,
      );
    }
    // If store is not available or productIds are missing, still show plans using backend values.
    if (!available || productIds.isEmpty) {
      final currency = settings?.currency ?? '';
      coinPlans.assignAll(
        packages
            .where((p) => p.status == 1)
            .map(
              (p) => CoinPlan(
                p.coinAmount ?? 0,
                p.id ?? -1,
                p.playStoreProductId ?? '',
                '${p.coinPlanPrice ?? 0} $currency',
                coinPlanPrice: p.coinPlanPrice,
              ),
            )
            .toList(),
      );
      coinPlansDebug.value =
          '${coinPlansDebug.value} productIds=${productIds.length} ready=${coinPlans.length}';
      return;
    }

    final response = await _iap.queryProductDetails(productIds);
    coinPlansDebug.value =
        '${coinPlansDebug.value} productIds=${productIds.length} found=${response.productDetails.length} notFound=${response.notFoundIDs.length}';
    Loggers.info(
        '[COIN] queryProductDetails found=${response.productDetails.length} notFound=${response.notFoundIDs.length}');
    for (final d in response.productDetails) {
      _productIdToDetails[d.id] = d;
      final plan = _productIdToPlan[d.id];
      if (plan != null) {
        plan.priceString = d.price;
      }
    }

    // If some product IDs are not found in Play Console, still show them with fallback price.
    final fallbackById = <String, CoinPlan>{};
    final currency = settings?.currency ?? '';
    for (final p in packages) {
      if (p.status != 1) continue;
      final id = p.playStoreProductId;
      if (id == null || id.isEmpty) continue;
      fallbackById[id] = CoinPlan(
        p.coinAmount ?? 0,
        p.id ?? -1,
        id,
        '${p.coinPlanPrice ?? 0} $currency',
        coinPlanPrice: p.coinPlanPrice,
      );
    }

    final merged = <CoinPlan>[];
    for (final id in productIds) {
      final d = _productIdToDetails[id];
      if (d != null) {
        merged.add(_productIdToPlan[id]!);
      } else {
        final fb = fallbackById[id];
        if (fb != null) merged.add(fb);
      }
    }

    coinPlans.assignAll(merged);
    Loggers.success('[COIN] coinPlans ready=${coinPlans.length}');
    coinPlansDebug.value = '${coinPlansDebug.value} ready=${coinPlans.length}';
  }

  Future<void> onPurchase(CoinPlan offer) async {
    final gateways = settings?.gateways;
    final googleActive =
        isStoreAvailable.value && _productIdToDetails.containsKey(offer.id);
    final razorpayActive = gateways?.razorpay == true;
    final cashfreeActive = gateways?.cashfree == true;
    final paypalActive = gateways?.paypal == true;
    final stripeActive = gateways?.stripe == true;

    final options = <Map<String, dynamic>>[];
    if (googleActive) {
      options
          .add({'name': 'Google Play', 'icon': Icons.shop, 'type': 'google'});
    }
    if (razorpayActive) {
      options
          .add({'name': 'Razorpay', 'icon': Icons.payment, 'type': 'razorpay'});
    }
    if (cashfreeActive) {
      options.add({
        'name': 'Cashfree',
        'icon': Icons.currency_rupee,
        'type': 'cashfree'
      });
    }
    if (paypalActive) {
      options.add({'name': 'PayPal', 'icon': Icons.payment, 'type': 'paypal'});
    }
    if (stripeActive) {
      options
          .add({'name': 'Stripe', 'icon': Icons.credit_card, 'type': 'stripe'});
    }

    if (options.isEmpty) {
      // Fallback to Google Play logic if nothing else (or just try Google Play)
      _purchaseViaGooglePlay(offer);
      return;
    }

    if (options.length == 1) {
      final type = options.first['type'];
      if (type == 'google') _purchaseViaGooglePlay(offer);
      if (type == 'razorpay') _purchaseViaRazorpay(offer);
      if (type == 'cashfree') _purchaseViaCashfree(offer);
      if (type == 'paypal') _purchaseViaPaypal(offer);
      if (type == 'stripe') _purchaseViaStripe(offer);
      return;
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: ShapeDecoration(
          color: whitePure(Get.context!),
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.only(
              topLeft: SmoothRadius(cornerRadius: 18, cornerSmoothing: 1),
              topRight: SmoothRadius(cornerRadius: 18, cornerSmoothing: 1),
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${offer.coin} Coins',
                style: TextStyleCustom.unboundedMedium500(
                  fontSize: 16,
                  color: textDarkGrey(Get.context!),
                ),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextButtonCustom(
                    onTap: () {
                      Get.key.currentState?.pop();
                      final type = opt['type'];
                      if (type == 'google') _purchaseViaGooglePlay(offer);
                      if (type == 'razorpay') _purchaseViaRazorpay(offer);
                      if (type == 'cashfree') _purchaseViaCashfree(offer);
                      if (type == 'paypal') _purchaseViaPaypal(offer);
                      if (type == 'stripe') _purchaseViaStripe(offer);
                    },
                    title: opt['name'],
                    backgroundColor: opt['type'] == 'google'
                        ? themeAccentSolid(Get.context!)
                        : textDarkGrey(Get.context!),
                    titleColor: whitePure(Get.context!),
                    horizontalMargin: 0,
                    btnHeight: 44,
                  ),
                );
              }),
              const SizedBox(height: 4),
              TextButtonCustom(
                onTap: () => Get.key.currentState?.pop(),
                title: 'Cancel',
                backgroundColor: bgLightGrey(Get.context!),
                titleColor: textDarkGrey(Get.context!),
                horizontalMargin: 0,
                btnHeight: 44,
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _purchaseViaGooglePlay(CoinPlan offer) async {
    var details = _productIdToDetails[offer.id];
    if (details == null) {
      // Try resolving this one product again (useful when list was loaded with fallback prices).
      try {
        if (offer.id.isNotEmpty && await _iap.isAvailable()) {
          final resp = await _iap.queryProductDetails({offer.id});
          if (resp.productDetails.isNotEmpty) {
            details = resp.productDetails.first;
            _productIdToDetails[details.id] = details;
          }
        }
      } catch (_) {
        // ignore and fall back to user-facing message
      }
    }
    if (details == null) {
      Get.rawSnackbar(
        message:
            'Purchase not available: product not found in Google Play. Please verify Play Console product ID and publish/test it.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return;
    }
    showLoader(barrierDismissible: false);
    try {
      final param = PurchaseParam(productDetails: details);
      await _iap.buyConsumable(purchaseParam: param);
    } catch (_) {
      stopLoader();
    }
  }

  Future<void> _purchaseViaRazorpay(CoinPlan offer) async {
    try {
      _pendingCoinPackageId = offer.coinPackageId;
      showLoader();
      var currencyCode = (settings?.currency ?? 'INR').trim();
      if (currencyCode == '\$' || currencyCode == '₹') currencyCode = 'INR';
      if (currencyCode.length != 3) currencyCode = 'INR';

      final order = await BillingService.instance.createRazorpayOrder(
        purpose: 'coins',
        coinPackageId: offer.coinPackageId,
        currency: currencyCode,
      );

      if (order.status != true || order.data == null) {
        throw Exception(order.message ?? 'Failed to create order');
      }

      final data = order.data!;
      final keyId = (data.keyId ?? settings?.razorpayKeyId)?.trim();
      if (keyId == null || keyId.isEmpty) {
        throw Exception('Razorpay Key ID missing');
      }

      var options = {
        'key': keyId,
        'amount': data.amount, // in paise
        'name': settings?.appName ?? 'App',
        'order_id': data.razorpayOrderId,
        'description': 'Buy ${offer.coin} Coins',
        'prefill': {
          'contact': myUser.value?.userMobileNo ?? '',
          'email': myUser.value?.userEmail ?? '',
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      stopLoader();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 150));
        try {
          _razorpay.open(options);
        } catch (e) {
          showSnackBar('Razorpay open failed: $e');
        }
      });
    } catch (e) {
      stopLoader();
      showSnackBar('Razorpay init failed: $e');
    }
  }

  Future<void> _purchaseViaCashfree(CoinPlan offer) async {
    try {
      _pendingCoinPackageId = offer.coinPackageId;
      showLoader();

      var currencyCode = (settings?.currency ?? 'INR').trim();
      if (currencyCode == '\$' || currencyCode == '₹') currencyCode = 'INR';
      if (currencyCode.length != 3) currencyCode = 'INR';

      // Cashfree requires minimum amount of 1.00
      double amount = (offer.coinPlanPrice ?? 0).toDouble();
      if (amount < 1.0) {
        amount = 1.0;
      }

      final order = await BillingService.instance.createCashfreeOrder(
        purpose: 'coins',
        coinPackageId: offer.coinPackageId,
        amount: amount,
        currency: currencyCode,
      );

      if (order.status != true || order.data == null) {
        throw Exception(order.message ?? 'Failed to create order');
      }

      final data = order.data!;
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
      Loggers.info(
          'Cashfree Environment: ${env == CFEnvironment.PRODUCTION ? "PRODUCTION" : "SANDBOX"}');

      final session = CFSessionBuilder()
          .setEnvironment(env)
          .setOrderId(data.orderId!)
          .setPaymentSessionId(data.paymentSessionId!)
          .build();

      final cfPayment =
          CFDropCheckoutPaymentBuilder().setSession(session).build();
      stopLoader();

      // Cashfree SDK UI opening can be sensitive to timing/Activity state.
      // Schedule on next frame after loader/bottomsheet is dismissed.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 150));
        Loggers.info(
            '[COIN][CASHFREE] doPayment about to call orderId=${data.orderId} sessionIdLen=${data.paymentSessionId?.length ?? 0}');
        Loggers.info('[COIN][CASHFREE] doPayment about to call');
        try {
          _cashfree.doPayment(cfPayment);
          Loggers.info('[COIN][CASHFREE] doPayment invoked');
          Loggers.info('[COIN][CASHFREE] doPayment invoked');
        } catch (e) {
          Loggers.info('[COIN][CASHFREE] doPayment threw: $e');
          Loggers.error('[COIN][CASHFREE] doPayment threw: $e');
          showSnackBar('Cashfree doPayment failed: $e');
        }
      });
    } catch (e) {
      stopLoader();
      showSnackBar('Cashfree init failed: $e');
    }
  }

  Future<void> _purchaseViaPaypal(CoinPlan offer) async {
    try {
      _pendingCoinPackageId = offer.coinPackageId;
      _paypalVerifyTriggered = false;
      showLoader();

      var currencyCode = (settings?.currency ?? 'USD').trim();
      if (currencyCode == '\$' || currencyCode == '₹') currencyCode = 'USD';
      // PayPal defaults to USD if not standard
      if (currencyCode.length != 3) currencyCode = 'USD';

      final order = await BillingService.instance.createPaypalOrder(
        purpose: 'coins',
        coinPackageId: offer.coinPackageId,
        currency: currencyCode,
      );

      stopLoader();
      if (order.status != true || order.data?.approvalUrl == null) {
        throw Exception(order.message ?? 'Failed to create PayPal order');
      }

      Get.to(() => PaymentWebViewScreen(
            url: order.data!.approvalUrl!,
            title: 'PayPal Payment',
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
                Get.key.currentState?.pop();
                showSnackBar('You cancelled the PayPal payment');
                return;
              }
              if (hasSuccessSignal) {
                _paypalVerifyTriggered = true;
                Get.key.currentState?.pop();
                _verifyPaypalPayment(order.data!.orderId);
              }
            },
          ));
    } catch (e) {
      stopLoader();
      showSnackBar('PayPal init failed: $e');
    }
  }

  Future<void> _verifyPaypalPayment(String? orderId) async {
    try {
      showLoader();
      final user = await GiftWalletService.instance.buyCoinsVerified(
        coinPackageId: _pendingCoinPackageId,
        gateway: 'paypal',
        paypalOrderId: orderId,
      );
      _handleSuccess(user);
    } catch (e) {
      stopLoader();
      showSnackBar('Verification failed: $e');
    }
  }

  Future<void> _purchaseViaStripe(CoinPlan offer) async {
    try {
      _pendingCoinPackageId = offer.coinPackageId;
      showLoader();

      var currencyCode = (settings?.currency ?? 'USD').trim();
      if (currencyCode == '\$' || currencyCode == '₹') currencyCode = 'USD';
      if (currencyCode.length != 3) currencyCode = 'USD';

      final order = await BillingService.instance.createStripeOrder(
        purpose: 'coins',
        coinPackageId: offer.coinPackageId,
        currency: currencyCode,
      );

      stopLoader();
      if (order.status != true || order.data?.clientSecret == null) {
        throw Exception(order.message ?? 'Failed to create Stripe order');
      }

      // For Stripe, if we don't have native SDK, we might need a hosted checkout page
      // or implement native Stripe SDK. Assuming the backend provides a way to pay.
      // If backend provides a hosted URL, we use it. If not, we might need flutter_stripe.
      // Given the previous pattern, let's assume verification happens after some client-side action.
      // If client_secret is provided, it usually means we use the native SDK.

      showSnackBar('Stripe integration requires native SDK or hosted checkout.');
    } catch (e) {
      stopLoader();
      showSnackBar('Stripe init failed: $e');
    }
  }

  Future<void> _verifyStripePayment(String? paymentIntentId) async {
    try {
      showLoader();
      final user = await GiftWalletService.instance.buyCoinsVerified(
        coinPackageId: _pendingCoinPackageId,
        gateway: 'stripe',
        stripePaymentIntentId: paymentIntentId,
      );
      _handleSuccess(user);
    } catch (e) {
      stopLoader();
      showSnackBar('Verification failed: $e');
    }
  }

  void _onRazorpaySuccess(PaymentSuccessResponse response) async {
    // Verify on backend
    try {
      final user = await GiftWalletService.instance.buyCoinsVerified(
        coinPackageId: _pendingCoinPackageId,
        gateway: 'razorpay',
        razorpayPaymentId: response.paymentId,
        razorpayOrderId: response.orderId,
        razorpaySignature: response.signature,
      );
      _handleSuccess(user);
    } catch (e) {
      stopLoader();
      showSnackBar('Verification failed: $e');
    }
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    stopLoader();
    showSnackBar(response.message ?? 'Payment Failed');
  }

  void _onRazorpayWallet(ExternalWalletResponse response) {
    stopLoader();
    showSnackBar('External wallet selected: ${response.walletName}');
  }

  void _onCashfreeVerify(String orderId) async {
    try {
      final user = await GiftWalletService.instance.buyCoinsVerified(
        coinPackageId: _pendingCoinPackageId,
        gateway: 'cashfree',
        cashfreeOrderId: orderId,
      );
      _handleSuccess(user);
    } catch (e) {
      stopLoader();
      showSnackBar('Verification failed: $e');
    }
  }

  void _onCashfreeError(CFErrorResponse error, String orderId) {
    stopLoader();
    showSnackBar('Payment Failed: ${error.getMessage()}');
  }

  void _handleSuccess(User? user) async {
    stopLoader();
    if (user != null) {
      final latest =
          await UserService.instance.fetchUserDetails(userId: myUser.value?.id);
      if (latest != null) {
        myUser.value = latest;
        SessionManager.instance.setUser(myUser.value);
      }
      showSnackBar('Coins purchased successfully!');
    }
  }

  int _pendingCoinPackageId = -1;

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.pending) {
        continue;
      }

      if (p.status == PurchaseStatus.error ||
          p.status == PurchaseStatus.canceled) {
        stopLoader();
        continue;
      }

      final plan = _productIdToPlan[p.productID];
      if (plan == null) {
        stopLoader();
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        continue;
      }

      final purchaseToken = p.verificationData.serverVerificationData;
      if (purchaseToken.isEmpty) {
        stopLoader();
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        continue;
      }

      try {
        final user = await GiftWalletService.instance.buyCoinsVerified(
          coinPackageId: plan.coinPackageId,
          gateway: 'google_play',
          purchaseToken: purchaseToken,
        );

        if (user != null) {
          final latest = await UserService.instance
              .fetchUserDetails(userId: myUser.value?.id);
          if (latest != null) {
            myUser.value = latest;
            SessionManager.instance.setUser(myUser.value);
          }
        }

        if (GetPlatform.isAndroid) {
          final addition =
              _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
          await addition.consumePurchase(p);
        }
      } finally {
        stopLoader();
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      }
    }
  }
}

class CoinPlan {
  int coin;
  int coinPackageId;
  String id;
  String priceString;
  int? coinPlanPrice;

  CoinPlan(this.coin, this.coinPackageId, this.id, this.priceString,
      {this.coinPlanPrice});
}
