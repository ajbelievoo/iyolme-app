import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/common/service/api/billing_service.dart';
import 'package:shortzz/common/widget/payment_webview_screen.dart';
import 'package:shortzz/screen/ads_manager/data/ads_dto.dart';
import 'package:shortzz/screen/ads_manager/data/ads_repository.dart';
import 'package:shortzz/screen/ads_manager/widget/ads_section_header.dart';
import 'package:shortzz/screen/ads_manager/widget/ads_empty_state.dart';
import 'package:shortzz/screen/ads_manager/widget/ads_skeleton_card.dart';
import 'package:shortzz/screen/ads_manager/widget/ads_wallet_hero_card.dart';
import 'package:shortzz/utilities/theme_res.dart';

class AdsWalletTab extends StatefulWidget {
  const AdsWalletTab({super.key});

  @override
  State<AdsWalletTab> createState() => _AdsWalletTabState();
}

class _AdsWalletTabState extends State<AdsWalletTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AdsManagerRepository _repo = AdsManagerRepository();
  final Razorpay _razorpay = Razorpay();
  final CFPaymentGatewayService _cashfree = CFPaymentGatewayService();
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _paypalVerifyTriggered = false;

  AdsManagerWalletDto? _wallet;
  bool _loading = true;
  String? _error;
  String _txFilter = 'all';

  final Map<num, String> _googlePlaySkuByAmount = <num, String>{};

  num _pendingTopUpAmount = 0;
  String _pendingTopUpCurrency = 'USD';
  CFEnvironment _pendingCashfreeEnv = CFEnvironment.SANDBOX;
  String _pendingGoogleProductId = '';
  String _pendingStripePaymentIntentId = '';

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onRazorpayWallet);
    try {
      _cashfree.setCallback(_onCashfreeVerify, _onCashfreeError);
    } catch (_) {}

    _purchaseSub = _iap.purchaseStream.listen(_onPurchaseUpdate);
    _fetch();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final w = await _repo.fetchWalletRaw();
      if (!mounted) return;
      setState(() {
        _wallet = w;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wallet = null;
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _dateLabel(DateTime? date) {
    final d = date ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  bool _isRefund(AdsManagerWalletTransactionDto t) {
    return (t.type ?? '').toLowerCase().contains('refund');
  }

  List<AdsManagerWalletTransactionDto> _applyTxFilter(
    List<AdsManagerWalletTransactionDto> tx,
  ) {
    if (_txFilter == 'refund') {
      return tx.where(_isRefund).toList();
    }
    if (_txFilter == 'spend') {
      return tx.where((t) => !_isRefund(t)).toList();
    }
    return tx;
  }

  Future<void> _openAddMoneySheet() async {
    final User? user = SessionManager.instance.getUser();

    // Ensure we have the latest backend packages (adWalletPackages) instead of stale cached settings.
    await CommonService.instance.fetchGlobalSettings(forceRefresh: true);

    final settings = SessionManager.instance.getSettings();
    debugPrint(
      '[ADS_WALLET] adWalletPackages loaded: ${(settings?.adWalletPackages ?? const []).length}',
    );
    String currencyCode = (settings?.currency ?? 'USD').trim();
    if (currencyCode == r'$' || currencyCode == '₹') currencyCode = 'USD';
    if (currencyCode.length != 3) currencyCode = 'USD';

    final presets = <_AdsWalletTopUpPreset>[];
    final rawPackages = settings?.adWalletPackages ?? const [];
    for (final p in rawPackages) {
      final status = p.status;
      if (status != null && status != 1) continue;
      final amount = p.amount;
      if (amount == null) continue;
      final v = amount;
      if (v <= 0) continue;
      presets.add(
        _AdsWalletTopUpPreset(
          amount: v,
          androidProductId: (p.androidProductId ?? '').trim().isEmpty
              ? null
              : p.androidProductId,
        ),
      );
    }

    presets.sort((a, b) => a.amount.compareTo(b.amount));

    final fallback = <_AdsWalletTopUpPreset>[
      const _AdsWalletTopUpPreset(amount: 10, androidProductId: 'ads_credit_10'),
      const _AdsWalletTopUpPreset(amount: 25, androidProductId: 'ads_credit_25'),
      const _AdsWalletTopUpPreset(amount: 50, androidProductId: 'ads_credit_50'),
      const _AdsWalletTopUpPreset(amount: 100, androidProductId: 'ads_credit_100'),
    ];

    final effectivePresets = presets.isNotEmpty ? presets : fallback;

    _googlePlaySkuByAmount
      ..clear()
      ..addEntries(
        effectivePresets
            .where((e) => (e.androidProductId ?? '').trim().isNotEmpty)
            .map((e) => MapEntry(e.amount, e.androidProductId!.trim())),
      );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scaffoldBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _AdsAddMoneySheet(
          currencyCode: currencyCode,
          presets: effectivePresets,
          onPayRazorpay: (amount) => _startRazorpayTopUp(
            amount: amount,
            currencyCode: currencyCode,
            settings: settings,
            bottomSheetContext: ctx,
          ),
          onPayCashfree: (amount) => _startCashfreeTopUp(
            amount: amount,
            currencyCode: currencyCode,
            settings: settings,
            bottomSheetContext: ctx,
          ),
          onPayPaypal: (amount) => _startPaypalTopUp(
            amount: amount,
            currencyCode: currencyCode,
            bottomSheetContext: ctx,
          ),
          onPayGooglePlay: (amount) => _startGooglePlayTopUp(
            amount: amount,
            currencyCode: currencyCode,
            bottomSheetContext: ctx,
          ),
          onPayStripe: (amount) => _startStripeTopUp(
            amount: amount,
            currencyCode: currencyCode,
            bottomSheetContext: ctx,
          ),
        );
      },
    );
  }

  bool _isPurposeInvalidMessage(String message) {
    final m = message.toLowerCase();
    return m.contains('selected purpose is invalid') ||
        (m.contains('purpose') && m.contains('invalid'));
  }

  List<String> _purposeCandidates() {
    return const <String>[
      'ads_wallet',
      'adsWallet',
      'ads',
      'wallet',
      'ad_wallet',
      'ads_credit',
      'ads_credits',
    ];
  }

  Future<T> _billingWithPurposeFallback<T>({
    required Future<T> Function(String purpose) action,
  }) async {
    Object? lastError;
    for (final p in _purposeCandidates()) {
      try {
        final res = await action(p);
        return res;
      } catch (e) {
        lastError = e;
        if (!_isPurposeInvalidMessage(e.toString())) {
          rethrow;
        }
      }
    }
    throw Exception(lastError?.toString() ?? 'The selected purpose is invalid.');
  }

  Future<void> _startPaypalTopUp({
    required num amount,
    required String currencyCode,
    required BuildContext bottomSheetContext,
  }) async {
    _pendingTopUpAmount = amount;
    _pendingTopUpCurrency = currencyCode;
    _paypalVerifyTriggered = false;

    final order = await _billingWithPurposeFallback(
      action: (purpose) => BillingService.instance.createPaypalOrder(
        purpose: purpose,
        amount: amount,
        currency: currencyCode,
      ),
    );

    if (order.status != true || order.data?.approvalUrl == null) {
      throw Exception(order.message ?? 'Failed to create PayPal order');
    }

    if (bottomSheetContext.mounted) {
      Navigator.of(bottomSheetContext).maybePop();
    }

    Get.to(
      () => PaymentWebViewScreen(
        url: order.data!.approvalUrl!,
        title: 'PayPal Payment',
        onUrlChanged: (url) {
          if (_paypalVerifyTriggered) return;

          final uri = Uri.tryParse(url);
          final lower = url.toLowerCase();
          final qp = uri?.queryParameters ?? const <String, String>{};

          final hasCancelSignal = lower.contains('cancel') ||
              lower.contains('cancelled') ||
              qp['cancel'] == 'true' ||
              qp['cancel'] == '1';
          if (hasCancelSignal) {
            _paypalVerifyTriggered = true;
            Get.back();
            BaseController.share.showSnackBar('You cancelled the PayPal payment');
            return;
          }

          final hasSuccessSignal = lower.contains('success') ||
              lower.contains('return') ||
              qp.containsKey('token') ||
              qp.containsKey('payerid') ||
              qp.containsKey('paymentid') ||
              qp.containsKey('orderid');
          if (hasSuccessSignal) {
            _paypalVerifyTriggered = true;
            Get.back();
            _creditWalletViaBackend(
              payload: <String, dynamic>{
                'amount': _pendingTopUpAmount,
                'currency': _pendingTopUpCurrency,
                'gateway': 'paypal',
                'paypal_order_id': order.data!.orderId,
              },
            );
          }
        },
      ),
      preventDuplicates: false,
    );
  }

  Future<void> _startStripeTopUp({
    required num amount,
    required String currencyCode,
    required BuildContext bottomSheetContext,
  }) async {
    _pendingTopUpAmount = amount;
    _pendingTopUpCurrency = currencyCode;

    final create = await _billingWithPurposeFallback(
      action: (purpose) => BillingService.instance.createStripeOrder(
        purpose: purpose,
        amount: amount,
        currency: currencyCode,
      ),
    );

    if (create.status != true || create.data?.clientSecret == null) {
      throw Exception(create.message ?? 'Failed to create Stripe order');
    }

    final clientSecret = create.data!.clientSecret!.trim();
    final publishableKey = (create.data!.publishableKey ?? '').trim();
    if (publishableKey.isEmpty) {
      throw Exception('Stripe publishable key missing');
    }

    final idx = clientSecret.indexOf('_secret');
    final paymentIntentId = idx > 0 ? clientSecret.substring(0, idx) : '';
    if (paymentIntentId.isEmpty) {
      throw Exception('Stripe payment intent id missing');
    }
    _pendingStripePaymentIntentId = paymentIntentId;

    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();

    if (bottomSheetContext.mounted) {
      Navigator.of(bottomSheetContext).maybePop();
    }

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Ads Wallet',
        style: ThemeMode.system,
      ),
    );
    await Stripe.instance.presentPaymentSheet();

    await _creditWalletViaBackend(
      payload: <String, dynamic>{
        'amount': _pendingTopUpAmount,
        'currency': _pendingTopUpCurrency,
        'gateway': 'stripe',
        'stripe_payment_intent_id': _pendingStripePaymentIntentId,
      },
    );
  }

  Future<void> _startRazorpayTopUp({
    required num amount,
    required String currencyCode,
    required dynamic settings,
    required BuildContext bottomSheetContext,
  }) async {
    _pendingTopUpAmount = amount;
    _pendingTopUpCurrency = currencyCode;

    final order = await _billingWithPurposeFallback(
      action: (purpose) => BillingService.instance.createRazorpayOrder(
        purpose: purpose,
        amount: amount,
        currency: currencyCode,
      ),
    );

    if (order.status != true || order.data == null) {
      throw Exception(order.message ?? 'Failed to create order');
    }

    final data = order.data!;
    final keyId = (data.keyId ?? settings?.razorpayKeyId)?.trim();
    if (keyId == null || keyId.isEmpty) {
      throw Exception('Razorpay Key ID missing');
    }

    if (bottomSheetContext.mounted) {
      Navigator.of(bottomSheetContext).maybePop();
    }

    final options = {
      'key': keyId,
      'amount': data.amount,
      'name': settings?.appName ?? 'App',
      'order_id': data.razorpayOrderId,
      'description': 'Ads wallet top-up',
      'prefill': {
        'contact': SessionManager.instance.getUser()?.userMobileNo ?? '',
        'email': SessionManager.instance.getUser()?.userEmail ?? '',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 150));
      _razorpay.open(options);
    });
  }

  Future<void> _startCashfreeTopUp({
    required num amount,
    required String currencyCode,
    required dynamic settings,
    required BuildContext bottomSheetContext,
  }) async {
    _pendingTopUpAmount = amount;
    _pendingTopUpCurrency = currencyCode;

    final order = await _billingWithPurposeFallback(
      action: (purpose) => BillingService.instance.createCashfreeOrder(
        purpose: purpose,
        amount: amount,
        currency: currencyCode,
      ),
    );

    if (order.status != true || order.data == null) {
      throw Exception(order.message ?? 'Failed to create order');
    }

    final data = order.data!;
    var env = CFEnvironment.SANDBOX;
    if (data.environment != null) {
      final e = data.environment!.toUpperCase();
      if (e == 'PRODUCTION') {
        env = CFEnvironment.PRODUCTION;
      } else if (e == 'SANDBOX') {
        env = CFEnvironment.SANDBOX;
      }
    } else if (data.isProduction == true) {
      env = CFEnvironment.PRODUCTION;
    } else if ((settings?.cashfreeEndpoint ?? '').contains('api.cashfree.com') ||
        (settings?.cashfreeEndpoint ?? '').contains('production')) {
      env = CFEnvironment.PRODUCTION;
    }
    _pendingCashfreeEnv = env;

    if (bottomSheetContext.mounted) {
      Navigator.of(bottomSheetContext).maybePop();
    }

    final session = CFSessionBuilder()
        .setEnvironment(env)
        .setOrderId(data.orderId!)
        .setPaymentSessionId(data.paymentSessionId!)
        .build();
    final cfPayment = CFWebCheckoutPaymentBuilder().setSession(session).build();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 150));
      _cashfree.doPayment(cfPayment);
    });
  }

  Future<void> _startGooglePlayTopUp({
    required num amount,
    required String currencyCode,
    required BuildContext bottomSheetContext,
  }) async {
    if (!GetPlatform.isAndroid) {
      throw Exception('Google Play is available only on Android');
    }

    final skuByAmount = <num, String>{
      10: 'ads_credit_10',
      25: 'ads_credit_25',
      50: 'ads_credit_50',
      100: 'ads_credit_100',
    };

    final productId = _googlePlaySkuByAmount[amount] ?? skuByAmount[amount];
    if (productId == null || productId.trim().isEmpty) {
      throw Exception('Product not found in Google Play: ads_credit_$amount');
    }

    _pendingTopUpAmount = amount;
    _pendingTopUpCurrency = currencyCode;
    _pendingGoogleProductId = productId;

    final response = await _iap.queryProductDetails(<String>{productId});
    if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
      throw Exception('Product not found in google play: $productId');
    }

    if (bottomSheetContext.mounted) {
      Navigator.of(bottomSheetContext).maybePop();
    }

    final details = response.productDetails.first;
    final param = PurchaseParam(productDetails: details);
    await _iap.buyConsumable(purchaseParam: param);
  }

  Future<void> _creditWalletViaBackend({
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _repo.topUpAdsWallet(payload: payload);
      BaseController.share.showSnackBar('Wallet credited');
      _fetch();
    } catch (e) {
      BaseController.share.showSnackBar(e.toString());
    }
  }

  void _onRazorpaySuccess(PaymentSuccessResponse response) {
    final amount = _pendingTopUpAmount;
    final currency = _pendingTopUpCurrency;
    if (amount <= 0) {
      BaseController.share.showSnackBar('Top-up amount missing');
      return;
    }
    _creditWalletViaBackend(
      payload: <String, dynamic>{
        'amount': amount,
        'currency': currency,
        'gateway': 'razorpay',
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
      },
    );
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    BaseController.share.showSnackBar(response.message ?? 'Payment failed');
  }

  void _onRazorpayWallet(ExternalWalletResponse response) {
    BaseController.share
        .showSnackBar('External wallet selected: ${response.walletName}');
  }

  void _onCashfreeVerify(String orderId) {
    final amount = _pendingTopUpAmount;
    final currency = _pendingTopUpCurrency;
    if (amount <= 0) {
      BaseController.share.showSnackBar('Top-up amount missing');
      return;
    }
    _creditWalletViaBackend(
      payload: <String, dynamic>{
        'amount': amount,
        'currency': currency,
        'gateway': 'cashfree',
        'cashfree_order_id': orderId,
        'environment':
            _pendingCashfreeEnv == CFEnvironment.PRODUCTION ? 'PRODUCTION' : 'SANDBOX',
      },
    );
  }

  void _onCashfreeError(CFErrorResponse error, String orderId) {
    BaseController.share.showSnackBar(
      'Payment failed: ${error.getMessage()}',
    );
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.pending) {
        continue;
      }

      if (p.status == PurchaseStatus.error || p.status == PurchaseStatus.canceled) {
        if (_pendingGoogleProductId.isNotEmpty) {
          BaseController.share.showSnackBar('Payment cancelled');
        }
        continue;
      }

      if (_pendingGoogleProductId.isEmpty || _pendingTopUpAmount <= 0) {
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        continue;
      }

      if (p.productID != _pendingGoogleProductId) {
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        continue;
      }

      final token = p.verificationData.serverVerificationData;
      if (token.trim().isEmpty) {
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        continue;
      }

      try {
        await _creditWalletViaBackend(
          payload: <String, dynamic>{
            'amount': _pendingTopUpAmount,
            'currency': _pendingTopUpCurrency,
            'gateway': 'google_play',
            'product_id': _pendingGoogleProductId,
            'purchase_token': token,
          },
        );

        if (GetPlatform.isAndroid) {
          final addition =
              _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
          await addition.consumePurchase(p);
        }
      } finally {
        _pendingGoogleProductId = '';
        _pendingTopUpAmount = 0;
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final User? user = SessionManager.instance.getUser();
    final canManage = user?.hasPermission('wallet_manage') == true;
    if (!canManage) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AdsSectionHeader(title: 'Wallet'),
          SizedBox(height: 10),
          AdsEmptyState(
            title: 'Wallet locked',
            subtitle: 'You do not have permission to manage wallet.',
            icon: Icons.lock_outline,
          ),
        ],
      );
    }

    final wallet = _wallet;

    Widget body;
    if (_loading) {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AdsSkeletonCard(height: 92),
          SizedBox(height: 16),
          AdsSkeletonCard(height: 110),
          SizedBox(height: 10),
          AdsSkeletonCard(height: 110),
        ],
      );
    } else if ((_error ?? '').trim().isNotEmpty) {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdsSectionHeader(
            title: 'Wallet',
            action: TextButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ),
          const SizedBox(height: 10),
          AdsEmptyState(
            title: 'Could not load wallet',
            subtitle: _error,
            icon: Icons.wifi_off,
            action: ElevatedButton(
              onPressed: _fetch,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    } else if (wallet == null) {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdsSectionHeader(title: 'Wallet'),
          const SizedBox(height: 10),
          AdsEmptyState(
            title: 'Wallet not available',
            subtitle: 'Please try again later.',
            icon: Icons.account_balance_wallet_outlined,
            action: OutlinedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ),
        ],
      );
    } else {
      final tx = wallet.transactions;
      final visibleTx = _applyTxFilter(tx);
      final accent = themeAccentSolid(context);

      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdsWalletHeroCard(
            balance: wallet.balance,
            onAddMoney: () {
              _openAddMoneySheet();
            },
          ),
          const SizedBox(height: 16),
          AdsSectionHeader(
            title: 'Transactions',
            action: TextButton(
              onPressed: () {
                BaseController.share.showSnackBar('Export (mock)');
              },
              child: const Text('Export'),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(
                  'All',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _txFilter == 'all'
                        ? Colors.white
                        : textDarkGrey(context),
                  ),
                ),
                selected: _txFilter == 'all',
                onSelected: (_) => setState(() => _txFilter = 'all'),
                selectedColor: accent,
                backgroundColor: Theme.of(context).cardColor,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: _txFilter == 'all'
                        ? accent
                        : textLightGrey(context).withValues(alpha: 0.30),
                  ),
                ),
              ),
              ChoiceChip(
                label: Text(
                  'Spend',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _txFilter == 'spend'
                        ? Colors.white
                        : textDarkGrey(context),
                  ),
                ),
                selected: _txFilter == 'spend',
                onSelected: (_) => setState(() => _txFilter = 'spend'),
                selectedColor: accent,
                backgroundColor: Theme.of(context).cardColor,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: _txFilter == 'spend'
                        ? accent
                        : textLightGrey(context).withValues(alpha: 0.30),
                  ),
                ),
              ),
              ChoiceChip(
                label: Text(
                  'Refund',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _txFilter == 'refund'
                        ? Colors.white
                        : textDarkGrey(context),
                  ),
                ),
                selected: _txFilter == 'refund',
                onSelected: (_) => setState(() => _txFilter = 'refund'),
                selectedColor: accent,
                backgroundColor: Theme.of(context).cardColor,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: _txFilter == 'refund'
                        ? accent
                        : textLightGrey(context).withValues(alpha: 0.30),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (visibleTx.isEmpty)
            AdsEmptyState(
              title: _txFilter == 'refund'
                  ? 'No refunds'
                  : _txFilter == 'spend'
                      ? 'No spend history'
                      : 'No transactions',
              subtitle: _txFilter == 'refund'
                  ? 'Refunds will appear here if any campaign is refunded.'
                  : _txFilter == 'spend'
                      ? 'Your campaign spends will appear here.'
                      : 'Your wallet history will appear here.',
              icon: _txFilter == 'refund'
                  ? Icons.replay_circle_filled_outlined
                  : Icons.receipt_long_outlined,
            ),
          ...visibleTx.map((t) {
            final isRefund = _isRefund(t);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: textLightGrey(context).withValues(alpha: 0.16),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  isRefund
                      ? Icons.replay_circle_filled_outlined
                      : Icons.payments_outlined,
                  color: textDarkGrey(context).withValues(alpha: 0.85),
                ),
                title: Text(
                  t.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: textDarkGrey(context),
                  ),
                ),
                subtitle: Text(
                  _dateLabel(t.date),
                  style: TextStyle(color: textLightGrey(context), fontSize: 12),
                ),
                trailing: Text(
                  '${isRefund ? '+' : '-'}${t.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isRefund
                        ? Colors.green.withValues(alpha: 0.85)
                        : Colors.red.withValues(alpha: 0.85),
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: body,
    );
  }
}

class _AdsWalletTopUpPreset {
  const _AdsWalletTopUpPreset({
    required this.amount,
    this.androidProductId,
  });

  final num amount;
  final String? androidProductId;
}

class _AdsAddMoneySheet extends StatefulWidget {
  const _AdsAddMoneySheet({
    required this.currencyCode,
    required this.presets,
    required this.onPayRazorpay,
    required this.onPayCashfree,
    required this.onPayPaypal,
    required this.onPayGooglePlay,
    required this.onPayStripe,
  });

  final String currencyCode;
  final List<_AdsWalletTopUpPreset> presets;
  final Future<void> Function(num amount) onPayRazorpay;
  final Future<void> Function(num amount) onPayCashfree;
  final Future<void> Function(num amount) onPayPaypal;
  final Future<void> Function(num amount) onPayGooglePlay;
  final Future<void> Function(num amount) onPayStripe;

  @override
  State<_AdsAddMoneySheet> createState() => _AdsAddMoneySheetState();
}

class _AdsAddMoneySheetState extends State<_AdsAddMoneySheet> {
  final TextEditingController _controller = TextEditingController();
  num _selected = 10;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.presets.isNotEmpty) {
      _selected = widget.presets.first.amount;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  num _resolvedAmount() {
    final custom = num.tryParse(_controller.text.trim());
    final amount = (custom != null && custom > 0) ? custom : _selected;
    return amount;
  }

  Widget _amountChip(num v, bool isSelected, void Function() onTap) {
    final accent = themeAccentSolid(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
        label: Text(
          v.toString(),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.white : textDarkGrey(context),
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: accent,
        backgroundColor: Theme.of(context).cardColor,
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected
                ? accent
                : textLightGrey(context).withValues(alpha: 0.30),
          ),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function(num amount) fn) async {
    if (_busy) return;
    final amount = _resolvedAmount();
    if (amount <= 0) {
      BaseController.share.showSnackBar('Please enter amount');
      return;
    }

    setState(() => _busy = true);
    try {
      await fn(amount);
    } catch (e) {
      BaseController.share.showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add money',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: textDarkGrey(context),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _busy ? null : () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close, color: textDarkGrey(context)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Select amount',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: textDarkGrey(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                children: widget.presets.map((p) {
                  return _amountChip(p.amount, _selected == p.amount, () {
                    setState(() => _selected = p.amount);
                  });
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Custom amount (${widget.currencyCode})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _run(widget.onPayRazorpay),
                  child: _busy
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: textLightGrey(context),
                          ),
                        )
                      : const Text(
                          'Pay with Razorpay',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _run(widget.onPayCashfree),
                  child: const Text(
                    'Pay with Cashfree',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _run(widget.onPayPaypal),
                  child: const Text(
                    'Pay with PayPal',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _run(widget.onPayGooglePlay),
                  child: const Text(
                    'Pay with Google Play',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _run(widget.onPayStripe),
                  child: const Text(
                    'Pay with Stripe',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
