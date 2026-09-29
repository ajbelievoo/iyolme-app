import 'dart:convert';

class SubscriptionPlansModel {
  bool? status;
  String? message;
  List<SubscriptionPlan>? data;

  SubscriptionPlansModel({this.status, this.message, this.data});

  factory SubscriptionPlansModel.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] ??
        json['plans'] ??
        json['subscriptionPlans'] ??
        json['subscription_plans'] ??
        json['subscription_plans_list'];

    dynamic list = raw;
    if (list is Map) {
      list = list['data'] ??
          list['plans'] ??
          list['subscriptionPlans'] ??
          list['subscription_plans'] ??
          list['subscription_plans_list'];
    }
    return SubscriptionPlansModel(
      status: _toBool(json['status']),
      message: json['message'],
      data: list is List
          ? list
              .whereType<Map>()
              .map((e) => SubscriptionPlan.fromJson(e.cast<String, dynamic>()))
              .toList()
          : <SubscriptionPlan>[],
    );
  }
}

class SubscriptionPlan {
  int? id;
  String? title;
  String? description;
  int? price;
  String? currency;
  int? durationDays;
  String? googlePlayProductId;
  String? razorpayPlanId;
  int? status;
  List<String>? features;
  Map<String, bool>? featureFlags;
  String? miningMultiplier;

  SubscriptionPlan({
    this.id,
    this.title,
    this.description,
    this.price,
    this.currency,
    this.durationDays,
    this.googlePlayProductId,
    this.razorpayPlanId,
    this.status,
    this.features,
    this.featureFlags,
    this.miningMultiplier,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) => SubscriptionPlan(
        id: _toInt(json['id']),
        title: json['title'] ?? json['name'],
        description: json['description'],
        price: _toInt(json['price'] ?? json['amount']),
        currency: json['currency'],
        durationDays: _toInt(json['duration_days'] ?? json['durationDays']),
        googlePlayProductId: json['google_play_product_id'] ??
            json['googlePlayProductId'] ??
            json['playstore_product_id'],
        razorpayPlanId: json['razorpay_plan_id'] ?? json['razorpayPlanId'],
        status: _toInt(json['status']),
        features: _parseFeatures(
          json['features'] ??
              json['features_json'] ??
              json['featuresJson'] ??
              json['plan_features'] ??
              json['feature_list'] ??
              json['featureList'],
        ),
        featureFlags: _parseFeatureFlags(
          json['features'] ??
              json['features_json'] ??
              json['featuresJson'] ??
              json['plan_features'] ??
              json['feature_list'] ??
              json['featureList'],
        ),
        miningMultiplier: (json['mining_multiplier'] ??
                json['miningMultiplier'] ??
                json['mining_multiplier_value'] ??
                json['miningMultiplierValue'] ??
                json['multiplier'] ??
                json['mining']?['multiplier'])
            ?.toString(),
      );
}

List<String> _parseFeatures(dynamic raw) {
  if (raw == null) return <String>[];
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return <String>[];
    try {
      return _parseFeatures(jsonDecode(s));
    } catch (_) {
      return <String>[];
    }
  }

  // If backend sends list of strings.
  if (raw is List) {
    final out = <String>[];
    for (final v in raw) {
      if (v == null) continue;
      if (v is String) {
        if (v.trim().isNotEmpty) out.add(v.trim());
      } else if (v is Map) {
        final name = v['title'] ?? v['name'] ?? v['label'] ?? v['key'];
        if (name != null && '$name'.trim().isNotEmpty) out.add('$name'.trim());
      }
    }
    return out;
  }

  // If backend sends map of feature flags.
  if (raw is Map) {
    final flags = _parseFeatureFlags(raw);
    final out = <String>[];
    flags.forEach((k, v) {
      if (v) out.add(k);
    });
    return out;
  }

  return <String>[];
}

Map<String, bool> _parseFeatureFlags(dynamic raw) {
  if (raw == null) return <String, bool>{};
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return <String, bool>{};
    try {
      return _parseFeatureFlags(jsonDecode(s));
    } catch (_) {
      return <String, bool>{};
    }
  }
  if (raw is Map) {
    final out = <String, bool>{};
    raw.forEach((k, v) {
      final enabled = v == true || v == 1 || v == '1' || v == 'true';
      final key = '$k'.trim();
      if (key.isEmpty) return;
      out[key] = enabled;
    });
    return out;
  }
  if (raw is List) {
    final out = <String, bool>{};
    for (final v in raw) {
      if (v == null) continue;
      if (v is String) {
        final s = v.trim();
        if (s.isNotEmpty) out[s] = true;
      } else if (v is Map) {
        final name = v['title'] ?? v['name'] ?? v['label'] ?? v['key'];
        if (name != null && '$name'.trim().isNotEmpty) out['$name'.trim()] = true;
      }
    }
    return out;
  }
  return <String, bool>{};
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is bool) return v ? 1 : 0;
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse('$v') ?? 0;
}

bool? _toBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return null;
}
