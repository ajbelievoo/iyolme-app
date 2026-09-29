class BoostEstimateResponse {
  bool? status;
  String? message;
  BoostEstimateData? data;

  BoostEstimateResponse({this.status, this.message, this.data});

  BoostEstimateResponse.fromJson(dynamic json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? BoostEstimateData.fromJson(json['data']) : null;
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

class BoostEstimateData {
  int? estimatedImpressionsMin;
  int? estimatedImpressionsMax;
  int? estimatedReachMin;
  int? estimatedReachMax;
  int? estimatedClicksMin;
  int? estimatedClicksMax;

  BoostEstimateData({
    this.estimatedImpressionsMin,
    this.estimatedImpressionsMax,
    this.estimatedReachMin,
    this.estimatedReachMax,
    this.estimatedClicksMin,
    this.estimatedClicksMax,
  });

  BoostEstimateData.fromJson(dynamic json) {
    estimatedImpressionsMin = json['estimated_impressions_min'];
    estimatedImpressionsMax = json['estimated_impressions_max'];
    estimatedReachMin = json['estimated_reach_min'];
    estimatedReachMax = json['estimated_reach_max'];
    estimatedClicksMin = json['estimated_clicks_min'];
    estimatedClicksMax = json['estimated_clicks_max'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['estimated_impressions_min'] = estimatedImpressionsMin;
    map['estimated_impressions_max'] = estimatedImpressionsMax;
    map['estimated_reach_min'] = estimatedReachMin;
    map['estimated_reach_max'] = estimatedReachMax;
    map['estimated_clicks_min'] = estimatedClicksMin;
    map['estimated_clicks_max'] = estimatedClicksMax;
    return map;
  }
}
?