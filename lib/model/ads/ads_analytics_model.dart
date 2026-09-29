class AdsAnalyticsResponse {
  bool? status;
  String? message;
  AdsAnalytics? data;

  AdsAnalyticsResponse({this.status, this.message, this.data});

  AdsAnalyticsResponse.fromJson(dynamic json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? AdsAnalytics.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['status'] = status;
    map['message'] = message;
    if (data != null) {
      map['data'] = data?.toJson();
    }
    return map;
  }
}

class AdsAnalytics {
  num? impressions;
  num? clicks;
  num? reach;
  num? spend;
  String? currency;

  AdsAnalytics({
    this.impressions,
    this.clicks,
    this.reach,
    this.spend,
    this.currency,
  });

  AdsAnalytics.fromJson(dynamic json) {
    impressions = json['impressions'];
    clicks = json['clicks'];
    reach = json['reach'];
    spend = json['spend'];
    currency = json['currency'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['impressions'] = impressions;
    map['clicks'] = clicks;
    map['reach'] = reach;
    map['spend'] = spend;
    map['currency'] = currency;
    return map;
  }
}
