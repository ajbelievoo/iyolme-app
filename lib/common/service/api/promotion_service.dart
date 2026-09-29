import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/model/promotions/app_open_promotion_model.dart';

class PromotionService {
  PromotionService._();

  static final PromotionService instance = PromotionService._();

  Future<AppOpenPromotionResponse> fetchActiveAppOpenPromotion() async {
    AppOpenPromotionResponse model = await ApiService.instance.call(
      url: WebService.promotions.fetchActiveAppOpenPromotion,
      fromJson: AppOpenPromotionResponse.fromJson,
    );
    return model;
  }

  Future<StatusModel> trackPromotionEvent({
    int? promotionId,
    String? event,
    String? placement,
    String? action,
    String? metadataJson,
  }) async {
    StatusModel model = await ApiService.instance.call(
      url: WebService.promotions.trackPromotionEvent,
      fromJson: StatusModel.fromJson,
      param: {
        if (promotionId != null) Params.promotionId: promotionId,
        if (event != null) Params.event: event,
        if (placement != null) Params.placement: placement,
        if (action != null) Params.action: action,
        if (metadataJson != null) Params.metadataJson: metadataJson,
      },
    );
    return model;
  }
}
