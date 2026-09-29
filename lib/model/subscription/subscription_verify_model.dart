import 'dart:convert';

class SubscriptionVerifyModel {
  SubscriptionVerifyModel({this.status, this.message, this.data});

  bool? status;
  String? message;
  SubscriptionVerifyData? data;

  factory SubscriptionVerifyModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionVerifyModel(
      status: json['status'] as bool?,
      message: json['message']?.toString(),
      data: json['data'] is Map<String, dynamic>
          ? SubscriptionVerifyData.fromJson((json['data'] as Map).cast<String, dynamic>())
          : (json['data'] is Map)
              ? SubscriptionVerifyData.fromJson((json['data'] as Map).cast<String, dynamic>())
              : null,
    );
  }
}

class SubscriptionVerifyData {
  SubscriptionVerifyData({
    this.subscriptionEnabled,
    this.isPlusActive,
    this.expiresAt,
    this.plusPlanType,
    this.planId,
    this.features,
  });

  int? subscriptionEnabled;
  int? isPlusActive;
  String? expiresAt;
  String? plusPlanType;
  int? planId;
  Map<String, dynamic>? features;

  factory SubscriptionVerifyData.fromJson(Map<String, dynamic> json) {
    return SubscriptionVerifyData(
      subscriptionEnabled: _toInt(json['subscription_enabled']),
      isPlusActive: _toInt(json['is_plus_active']),
      expiresAt: json['expires_at']?.toString(),
      plusPlanType: json['plus_plan_type']?.toString(),
      planId: _toInt(json['plan_id'] ?? json['planId']),
      features: _parseFeatures(json['features'] ?? json['features_json'] ?? json['featuresJson']),
    );
  }
}

Map<String, dynamic>? _parseFeatures(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) return raw.cast<String, dynamic>();
  if (raw is List) {
    final out = <String, dynamic>{'features': raw};
    for (final v in raw) {
      if (v is String && v.trim().isNotEmpty) out[v.trim()] = true;
      if (v is Map) {
        final key = v['key'] ?? v['name'] ?? v['title'] ?? v['label'];
        if (key != null && '$key'.trim().isNotEmpty) out['$key'.trim()] = true;
      }
    }
    return out;
  }
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      final decoded = jsonDecode(s);
      return _parseFeatures(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}
