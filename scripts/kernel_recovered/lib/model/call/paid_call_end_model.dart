class PaidCallEndModel {
  bool? status;
  String? message;

  int? totalCost;
  int? commission;
  int? earning;
  double? commissionPercent;
  int? costPerMinute;
  int? durationSeconds;

  PaidCallEndModel({
    this.status,
    this.message,
    this.totalCost,
    this.commission,
    this.earning,
    this.commissionPercent,
    this.costPerMinute,
    this.durationSeconds,
  });

  factory PaidCallEndModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final Map<String, dynamic> d =
        data is Map ? Map<String, dynamic>.from(data) : const {};

    return PaidCallEndModel(
      status: json['status'] as bool?,
      message: json['message']?.toString(),
      totalCost: _toInt(json['totalCost'] ?? json['total_cost'] ?? d['totalCost'] ?? d['total_cost'] ?? d['amount']),
      commission: _toInt(json['commission'] ?? json['companyCommission'] ?? json['company_commission'] ?? d['commission'] ?? d['companyCommission'] ?? d['company_commission']),
      earning: _toInt(json['earning'] ?? json['receiverEarning'] ?? json['receiver_earning'] ?? d['earning'] ?? d['receiverEarning'] ?? d['receiver_earning']),
      commissionPercent: _toDouble(json['commissionPercent'] ??
          json['commission_percent'] ??
          d['commissionPercent'] ??
          d['commission_percent']),
      costPerMinute: _toInt(json['costPerMinute'] ?? json['cost_per_minute'] ?? d['costPerMinute'] ?? d['cost_per_minute'] ?? d['rate']),
      durationSeconds: _toInt(json['duration'] ?? json['duration_seconds'] ?? d['duration'] ?? d['duration_seconds']),
    );
  }
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

;