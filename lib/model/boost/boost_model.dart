class BoostRequestsResponse {
  BoostRequestsResponse({
    bool? status,
    String? message,
    List<BoostRequest>? data,
  }) {
    _status = status;
    _message = message;
    _data = data;
  }

  BoostRequestsResponse.fromJson(dynamic json) {
    _status = json['status'];
    _message = json['message'];
    dynamic raw = (json is Map)
        ? (json['data'] ??
            json['items'] ??
            json['list'] ??
            json['requests'] ??
            json['results'] ??
            json['rows'] ??
            json['boostRequests'])
        : json;

    if (raw is Map) {
      raw = raw['data'] ?? raw['items'] ?? raw['list'] ?? raw['results'] ?? raw['rows'];
    }

    if (raw is List) {
      _data = <BoostRequest>[];
      for (final v in raw) {
        _data?.add(BoostRequest.fromJson(v));
      }
    }
  }

  bool? _status;
  String? _message;
  List<BoostRequest>? _data;

  bool? get status => _status;

  String? get message => _message;

  List<BoostRequest>? get data => _data;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['status'] = _status;
    map['message'] = _message;
    if (_data != null) {
      map['data'] = _data?.map((v) => v.toJson()).toList();
    }
    return map;
  }
}

class BoostRequest {
  BoostRequest({
    this.id,
    this.postId,
    this.userId,
    this.status,
    this.budget,
    this.spend,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.updatedAt,
    this.targetCountry,
    this.targetAgeMin,
    this.targetAgeMax,
    this.targetGender,
    this.metadata,
  });

  BoostRequest.fromJson(dynamic json) {
    id = json['id'];
    postId = json['post_id'];
    userId = json['user_id'];
    status = json['status'];
    budget = json['budget'];
    spend = json['spend'];
    startsAt = json['starts_at'];
    endsAt = json['ends_at'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    targetCountry = json['target_country'];
    targetAgeMin = json['target_age_min'];
    targetAgeMax = json['target_age_max'];
    targetGender = json['target_gender'];
    metadata = json['metadata'];
  }

  int? id;
  int? postId;
  int? userId;
  String? status;
  num? budget;
  num? spend;
  String? startsAt;
  String? endsAt;
  String? createdAt;
  String? updatedAt;
  String? targetCountry;
  int? targetAgeMin;
  int? targetAgeMax;
  int? targetGender;
  dynamic metadata;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['post_id'] = postId;
    map['user_id'] = userId;
    map['status'] = status;
    map['budget'] = budget;
    map['spend'] = spend;
    map['starts_at'] = startsAt;
    map['ends_at'] = endsAt;
    map['created_at'] = createdAt;
    map['updated_at'] = updatedAt;
    map['target_country'] = targetCountry;
    map['target_age_min'] = targetAgeMin;
    map['target_age_max'] = targetAgeMax;
    map['target_gender'] = targetGender;
    map['metadata'] = metadata;
    return map;
  }
}
