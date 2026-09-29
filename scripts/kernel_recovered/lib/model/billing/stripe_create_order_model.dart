class StripeCreateOrderModel {
  bool? status;
  String? message;
  StripeCreateOrderData? data;

  StripeCreateOrderModel({this.status, this.message, this.data});

  factory StripeCreateOrderModel.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] ?? json;
    return StripeCreateOrderModel(
      status: json['status'],
      message: json['message'],
      data: raw is Map<String, dynamic>
          ? StripeCreateOrderData.fromJson(raw)
          : null,
    );
  }
}

class StripeCreateOrderData {
  String? clientSecret;
  String? publishableKey;
  String? orderId;

  StripeCreateOrderData({this.clientSecret, this.publishableKey, this.orderId});

  factory StripeCreateOrderData.fromJson(Map<String, dynamic> json) =>
      StripeCreateOrderData(
        clientSecret: json['client_secret'] ?? json['clientSecret'],
        publishableKey: json['publishable_key'] ?? json['publishableKey'],
        orderId: json['order_id'] ?? json['orderId'],
      );
}
#