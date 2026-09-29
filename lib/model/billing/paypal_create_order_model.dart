class PaypalCreateOrderModel {
  bool? status;
  String? message;
  PaypalCreateOrderData? data;

  PaypalCreateOrderModel({this.status, this.message, this.data});

  factory PaypalCreateOrderModel.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] ?? json;
    return PaypalCreateOrderModel(
      status: json['status'],
      message: json['message'],
      data: raw is Map<String, dynamic>
          ? PaypalCreateOrderData.fromJson(raw)
          : null,
    );
  }
}

class PaypalCreateOrderData {
  String? orderId;
  String? approvalUrl;

  PaypalCreateOrderData({this.orderId, this.approvalUrl});

  factory PaypalCreateOrderData.fromJson(Map<String, dynamic> json) =>
      PaypalCreateOrderData(
        orderId: json['order_id'] ?? json['id'],
        approvalUrl: json['approval_url'] ?? json['approvalUrl'],
      );
}
