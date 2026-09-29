class CashfreeCreateOrderModel {
  bool? status;
  String? message;
  CashfreeCreateOrderData? data;

  CashfreeCreateOrderModel({this.status, this.message, this.data});

  factory CashfreeCreateOrderModel.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] ?? json;
    return CashfreeCreateOrderModel(
      status: json['status'],
      message: json['message'],
      data: raw is Map<String, dynamic>
          ? CashfreeCreateOrderData.fromJson(raw)
          : null,
    );
  }
}

class CashfreeCreateOrderData {
  String? cfOrderId;
  String? paymentSessionId;
  String? orderId;
  String? currency;
  dynamic amount;
  String? environment;
  bool? isProduction;

  CashfreeCreateOrderData({
    this.cfOrderId,
    this.paymentSessionId,
    this.orderId,
    this.currency,
    this.amount,
    this.environment,
    this.isProduction,
  });

  factory CashfreeCreateOrderData.fromJson(Map<String, dynamic> json) =>
      CashfreeCreateOrderData(
        cfOrderId: json['cf_order_id']?.toString(),
        paymentSessionId: json['payment_session_id'],
        orderId: json['order_id'],
        currency: json['currency'],
        amount: json['amount'],
        environment: json['environment'],
        isProduction: json['is_production'],
      );
}
3