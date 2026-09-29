class AdSpendSummaryResponse {
  AdSpendSummaryResponse({
    bool? status,
    String? message,
    AdSpendSummary? data,
  }) {
    _status = status;
    _message = message;
    _data = data;
  }

  AdSpendSummaryResponse.fromJson(dynamic json) {
    _status = json['status'];
    _message = json['message'];
    _data = json['data'] != null ? AdSpendSummary.fromJson(json['data']) : null;
  }

  bool? _status;
  String? _message;
  AdSpendSummary? _data;

  bool? get status => _status;

  String? get message => _message;

  AdSpendSummary? get data => _data;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['status'] = _status;
    map['message'] = _message;
    if (_data != null) {
      map['data'] = _data?.toJson();
    }
    return map;
  }
}

class AdSpendSummary {
  AdSpendSummary({
    this.totalBudget,
    this.totalSpend,
    this.availableBalance,
    this.currency,
  });

  AdSpendSummary.fromJson(dynamic json) {
    totalBudget = json['total_budget'];
    totalSpend = json['total_spend'];
    availableBalance = json['available_balance'];
    currency = json['currency'];
  }

  num? totalBudget;
  num? totalSpend;
  num? availableBalance;
  String? currency;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['total_budget'] = totalBudget;
    map['total_spend'] = totalSpend;
    map['available_balance'] = availableBalance;
    map['currency'] = currency;
    return map;
  }
}
