class RazorpayCreateOrderModel {
  bool? status;
  String? message;
  RazorpayCreateOrderData? data;

  RazorpayCreateOrderModel({this.status, this.message, this.data});

  factory RazorpayCreateOrderModel.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] ?? json;
    return RazorpayCreateOrderModel(
      status: json['status'],
      message: json['message'],
      data: raw is Map<String, dynamic>
          ? RazorpayCreateOrderData.fromJson(raw)
          : null,
    );
  }
}

class RazorpayCreateOrderData {
  String? razorpayOrderId;
  String? keyId;
  int? amount;
  String? currency;

  RazorpayCreateOrderData({
    this.razorpayOrderId,
    this.keyId,
    this.amount,
    this.currency,
  });

  factory RazorpayCreateOrderData.fromJson(Map<String, dynamic> json) =>
      RazorpayCreateOrderData(
        razorpayOrderId:
            json['razorpay_order_id'] ?? json['razorpayOrderId'] ?? json['order_id'],
        keyId: json['key_id'] ?? json['keyId'],
        amount: json['amount'],
        currency: json['currency'],
      );
}
+