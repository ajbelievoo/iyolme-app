import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/model/general/status_model.dart';

class AdEventService {
  AdEventService._();

  static final AdEventService instance = AdEventService._();

  final Set<String> _viewedOnce = <String>{};

  Future<StatusModel> logAdEvent({
    required String eventType,
    required int adId,
    int? contentUserId,
    int? viewerId,
    String? placement,
    String? country,
    String? context,
  }) async {
    if (eventType == 'view') {
      final key = '${adId}_${placement ?? context ?? ''}';
      if (_viewedOnce.contains(key)) {
        return StatusModel(status: true, message: 'already_viewed');
      }
      _viewedOnce.add(key);
    }

    final StatusModel model = await ApiService.instance.call(
      url: WebService.user.logAdEvent,
      fromJson: StatusModel.fromJson,
      param: {
        Params.eventType: eventType,
        Params.adId: adId,
        if (contentUserId != null) 'content_user_id': contentUserId,
        if (viewerId != null) 'viewer_id': viewerId,
        if ((placement ?? '').trim().isNotEmpty) Params.placement: placement,
        if ((country ?? '').trim().isNotEmpty) Params.country: country,
        if ((context ?? '').trim().isNotEmpty) Params.context: context,
      },
    );
    return model;
  }

  Future<Map<String, dynamic>> getAppOpenPopup() async {
    final Map<String, dynamic> json = await ApiService.instance.get<Map<String, dynamic>>(
      url: WebService.user.getAppOpenPopup,
    );
    return json;
  }
}
