import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/model/ads/ad_spend_model.dart';
import 'package:shortzz/model/general/status_model.dart';

class AdSpendService {
  AdSpendService._();

  static final AdSpendService instance = AdSpendService._();

  Future<AdSpendSummaryResponse> fetchMyAdSpendSummary() async {
    final AdSpendSummaryResponse model = await ApiService.instance.call(
      url: WebService.analytics.fetchMyAdSpendSummary,
      fromJson: AdSpendSummaryResponse.fromJson,
      param: const {},
    );
    return model;
  }

  Future<StatusModel> topUpAdsWallet({
    required String amount,
    required String transactionId,
    required String purchaseToken,
    required String gateway, // google_play | app_store
    int? packageId,
  }) async {
    final user = SessionManager.instance.getUser();
    final param = {
      if (user?.id != null) Params.userId: user?.id,
      Params.amount: amount,
      Params.transactionId: transactionId,
      Params.purchaseToken: purchaseToken,
      'status': 'completed',
      Params.paymentGateway: gateway,
      if (packageId != null) Params.packageId: packageId,
    };

    final StatusModel model = await ApiService.instance.call(
      url: WebService.adsManager.topUpAdsWallet,
      fromJson: StatusModel.fromJson,
      param: param,
    );
    return model;
  }
}
