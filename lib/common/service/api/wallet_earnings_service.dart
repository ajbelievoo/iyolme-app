import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/model/wallet/earnings_ledger_model.dart';
import 'package:shortzz/model/wallet/earnings_summary_model.dart';

class WalletEarningsService {
  WalletEarningsService._();

  static final WalletEarningsService instance = WalletEarningsService._();

  Future<EarningsSummaryModel> summary({String? from, String? to}) async {
    final param = <String, dynamic>{
      if (from != null && from.trim().isNotEmpty) 'from': from.trim(),
      if (to != null && to.trim().isNotEmpty) 'to': to.trim(),
    };

    final json = await ApiService.instance.get<Map<String, dynamic>>(
      url: WebService.wallet.earningsSummary,
      param: param.isEmpty ? null : param,
    );

    return EarningsSummaryModel.fromJson(json);
  }

  Future<EarningsLedgerModel> ledger({
    String? from,
    String? to,
    String? type,
    int? limit,
    String? lastId,
  }) async {
    final param = <String, dynamic>{
      if (from != null && from.trim().isNotEmpty) 'from': from.trim(),
      if (to != null && to.trim().isNotEmpty) 'to': to.trim(),
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      if (limit != null && limit > 0) 'limit': limit,
      if (lastId != null && lastId.trim().isNotEmpty) 'last_id': lastId.trim(),
    };

    final json = await ApiService.instance.get<Map<String, dynamic>>(
      url: WebService.wallet.earningsLedger,
      param: param.isEmpty ? null : param,
    );

    return EarningsLedgerModel.fromJson(json);
  }
}
