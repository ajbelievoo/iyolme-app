class VerificationSubmitModel {
  VerificationSubmitModel({this.status, this.message, this.data});

  bool? status;
  String? message;
  VerificationSubmitData? data;

  factory VerificationSubmitModel.fromJson(Map<String, dynamic> json) {
    return VerificationSubmitModel(
      status: json['status'] as bool?,
      message: json['message']?.toString(),
      data: json['data'] is Map
          ? VerificationSubmitData.fromJson((json['data'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

class VerificationSubmitData {
  VerificationSubmitData({
    this.requestId,
    this.status,
  });

  int? requestId;
  String? status;

  factory VerificationSubmitData.fromJson(Map<String, dynamic> json) {
    return VerificationSubmitData(
      requestId: _toInt(json['verification_request_id'] ?? json['request_id'] ?? json['id']),
      status: json['verification_status']?.toString() ?? json['status']?.toString(),
    );
  }
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}
+