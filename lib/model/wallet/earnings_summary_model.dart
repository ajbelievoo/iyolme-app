class EarningsSummaryModel {
  EarningsSummaryModel({this.status, this.data});

  bool? status;
  EarningsSummaryData? data;

  factory EarningsSummaryModel.fromJson(Map<String, dynamic> json) {
    return EarningsSummaryModel(
      status: json['status'] as bool?,
      data: json['data'] is Map<String, dynamic>
          ? EarningsSummaryData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class EarningsSummaryData {
  EarningsSummaryData({
    this.currency,
    this.totals,
    this.rates,
  });

  String? currency;
  EarningsTotals? totals;
  EarningsRates? rates;

  factory EarningsSummaryData.fromJson(Map<String, dynamic> json) {
    return EarningsSummaryData(
      currency: json['currency']?.toString(),
      totals: json['totals'] is Map<String, dynamic>
          ? EarningsTotals.fromJson(json['totals'] as Map<String, dynamic>)
          : null,
      rates: json['rates'] is Map<String, dynamic>
          ? EarningsRates.fromJson(json['rates'] as Map<String, dynamic>)
          : null,
    );
  }
}

class EarningsTotals {
  EarningsTotals({
    this.paidCallsTokens,
    this.giftsTokens,
    this.adsTokens,
    this.tasksTokens,
    this.otherTokens,
    this.creditsBalance,
    this.coinsBalance,
    this.minerPoints,
    this.dollarEstimated,
    this.withdrawnCoinsTotal,
    this.withdrawnAmountTotal,
  });

  num? paidCallsTokens;
  num? giftsTokens;
  num? adsTokens;
  num? tasksTokens;
  num? otherTokens;

  num? creditsBalance;
  num? coinsBalance;
  num? minerPoints;

  num? dollarEstimated;

  num? withdrawnCoinsTotal;
  num? withdrawnAmountTotal;

  factory EarningsTotals.fromJson(Map<String, dynamic> json) {
    num? readNum(String key) {
      final v = json[key];
      if (v is num) return v;
      return num.tryParse('${v ?? ''}'.trim());
    }

    return EarningsTotals(
      paidCallsTokens: readNum('paid_calls_tokens'),
      giftsTokens: readNum('gifts_tokens'),
      adsTokens: readNum('ads_tokens'),
      tasksTokens: readNum('tasks_tokens'),
      otherTokens: readNum('other_tokens'),
      creditsBalance: readNum('credits_balance'),
      coinsBalance: readNum('coins_balance'),
      minerPoints: readNum('miner_points'),
      dollarEstimated: readNum('dollar_estimated'),
      withdrawnCoinsTotal: readNum('withdrawn_coins_total'),
      withdrawnAmountTotal: readNum('withdrawn_amount_total'),
    );
  }
}

class EarningsRates {
  EarningsRates({
    this.coinValueUsd,
    this.creditToCoin,
  });

  num? coinValueUsd;
  num? creditToCoin;

  factory EarningsRates.fromJson(Map<String, dynamic> json) {
    num? readNum(String key) {
      final v = json[key];
      if (v is num) return v;
      return num.tryParse('${v ?? ''}'.trim());
    }

    return EarningsRates(
      coinValueUsd: readNum('coin_value_usd'),
      creditToCoin: readNum('credit_to_coin'),
    );
  }
}
