import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/service/api/wallet_earnings_service.dart';
import 'package:shortzz/model/wallet/earnings_ledger_model.dart';
import 'package:shortzz/model/wallet/earnings_summary_model.dart';

class EarningsHistoryScreenController extends BaseController {
  final summaryData = Rxn<EarningsSummaryData>();
  final items = <EarningsLedgerItem>[].obs;

  final selectedType = 'all'.obs;

  final isLoadingSummary = false.obs;
  final isLoadingLedger = false.obs;
  final hasMore = true.obs;

  String? _lastId;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    _lastId = null;
    hasMore.value = true;
    await Future.wait([
      fetchSummary(),
      fetchLedger(reset: true),
    ]);
  }

  Future<void> fetchSummary({String? from, String? to}) async {
    if (isLoadingSummary.value) return;
    isLoadingSummary.value = true;
    try {
      final res = await WalletEarningsService.instance.summary(from: from, to: to);
      if (res.status == true) {
        summaryData.value = res.data;
      }
    } catch (e) {
      // ignore
    } finally {
      isLoadingSummary.value = false;
    }
  }

  Future<void> fetchLedger({
    bool reset = false,
    String? from,
    String? to,
  }) async {
    if (isLoadingLedger.value) return;
    if (!hasMore.value && !reset) return;

    isLoadingLedger.value = true;
    try {
      if (reset) {
        items.clear();
        _lastId = null;
        hasMore.value = true;
      }

      final res = await WalletEarningsService.instance.ledger(
        from: from,
        to: to,
        type: selectedType.value,
        limit: 20,
        lastId: _lastId,
      );

      final next = res.data?.items ?? const <EarningsLedgerItem>[];
      if (next.isEmpty) {
        hasMore.value = false;
      } else {
        items.addAll(next);
        _lastId = next.last.id;
      }
    } catch (e) {
      // ignore
    } finally {
      isLoadingLedger.value = false;
    }
  }

  void onTypeChanged(String type) {
    final t = type.trim().toLowerCase();
    if (selectedType.value == t) return;
    selectedType.value = t;
    fetchLedger(reset: true);
  }
}
