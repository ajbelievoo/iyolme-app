import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/model/call/paid_call_create_model.dart';
import 'package:shortzz/model/call/paid_call_end_model.dart';

class PaidCallService {
  PaidCallService._();

  static final PaidCallService instance = PaidCallService._();

  Future<PaidCallCreateModel> create({
    required int receiverId,
    required int callType,
  }) async {
    final res = await ApiService.instance.call(
      url: WebService.call.create,
      fromJson: PaidCallCreateModel.fromJson,
      param: {
        Params.receiverId: receiverId,
        Params.callType: callType,
      },
    );
    return res;
  }

  Future<PaidCallEndModel> end({
    required String callId,
  }) async {
    final res = await ApiService.instance.call(
      url: WebService.call.end,
      fromJson: PaidCallEndModel.fromJson,
      param: {
        Params.callId: callId,
      },
    );
    return res;
  }
}
