class VerificationStatusModel {
  VerificationStatusModel({this.status, this.message, this.data});

  bool? status;
  String? message;
  VerificationStatusData? data;

  factory VerificationStatusModel.fromJson(Map<String, dynamic> json) {
    return VerificationStatusModel(
      status: json['status'] as bool?,
      message: json['message']?.toString(),
      data: json['data'] is Map
          ? VerificationStatusData.fromJson((json['data'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

class VerificationStatusData {
  VerificationStatusData({
    this.requestId,
    this.verificationStatus,
    this.statusCode,
    this.rejectionReason,
    this.isVerify,
  });

  int? requestId;
  String? verificationStatus;
  int? statusCode;
  String? rejectionReason;
  int? isVerify;

  factory VerificationStatusData.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] ?? json['verification_status'] ?? json['verificationStatus'];
    return VerificationStatusData(
      requestId: _toInt(json['verification_request_id'] ?? json['request_id'] ?? json['id']),
      verificationStatus: rawStatus?.toString(),
      statusCode: _toInt(rawStatus),
      rejectionReason: (json['reason'] ?? json['rejection_reason'] ?? json['rejectionReason'] ?? json['message'])?.toString(),
      isVerify: _toInt(json['is_verify'] ?? json['isVerify'] ?? json['verified']),
    );
  }

  bool get isApproved {
    final s = (verificationStatus ?? '').toLowerCase().trim();
    return statusCode == 1 || s == 'approved' || s == 'verified' || s == 'success' || (isVerify ?? 0) == 1;
  }

  bool get isRejected {
    final s = (verificationStatus ?? '').toLowerCase().trim();
    return statusCode == 2 || s == 'rejected' || s == 'declined' || s == 'failed';
  }

  bool get isInReview {
    final s = (verificationStatus ?? '').toLowerCase().trim();
    return statusCode == 0 || s == 'pending' || s == 'in_review' || s == 'review' || s == 'in review';
  }
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}
