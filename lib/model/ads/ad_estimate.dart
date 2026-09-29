class AdEstimateResponse {
  bool? status;
  String? message;
  AdEstimateData? data;

  AdEstimateResponse({this.status, this.message, this.data});

  AdEstimateResponse.fromJson(dynamic json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? AdEstimateData.fromJson(json['data']) : null;
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

class AdEstimateData {
  int? estimatedImpressionsMin;
  int? estimatedImpressionsMax;
  int? estimatedClicksMin;
  int? estimatedClicksMax;
  String? estimatedCostEfficiency; // e.g., "High", "Medium", "Low" or numerical score

  AdEstimateData({
    this.estimatedImpressionsMin,
    this.estimatedImpressionsMax,
    this.estimatedClicksMin,
    this.estimatedClicksMax,
    this.estimatedCostEfficiency,
  });

  AdEstimateData.fromJson(dynamic json) {
    estimatedImpressionsMin = json['estimated_impressions_min'];
    estimatedImpressionsMax = json['estimated_impressions_max'];
    estimatedClicksMin = json['estimated_clicks_min'];
    estimatedClicksMax = json['estimated_clicks_max'];
    estimatedCostEfficiency = json['estimated_cost_efficiency'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['estimated_impressions_min'] = estimatedImpressionsMin;
    map['estimated_impressions_max'] = estimatedImpressionsMax;
    map['estimated_clicks_min'] = estimatedClicksMin;
    map['estimated_clicks_max'] = estimatedClicksMax;
    map['estimated_cost_efficiency'] = estimatedCostEfficiency;
    return map;
  }
}
