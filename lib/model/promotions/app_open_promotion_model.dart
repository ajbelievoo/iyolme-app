class AppOpenPromotionResponse {
  AppOpenPromotionResponse({
    bool? status,
    String? message,
    AppOpenPromotion? data,
  }) {
    _status = status;
    _message = message;
    _data = data;
  }

  AppOpenPromotionResponse.fromJson(dynamic json) {
    _status = json['status'];
    _message = json['message'];
    _data = json['data'] != null ? AppOpenPromotion.fromJson(json['data']) : null;
  }

  bool? _status;
  String? _message;
  AppOpenPromotion? _data;

  bool? get status => _status;

  String? get message => _message;

  AppOpenPromotion? get data => _data;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['status'] = _status;
    map['message'] = _message;
    if (_data != null) {
      map['data'] = _data?.toJson();
    }
    return map;
  }
}

class AppOpenPromotion {
  AppOpenPromotion({
    this.id,
    this.title,
    this.subtitle,
    this.mediaType,
    this.mediaUrl,
    this.thumbnailUrl,
    this.cta,
    this.action,
    this.actionValue,
    this.frequency,
    this.frequencyHours,
    this.startsAt,
    this.endsAt,
    this.priority,
    this.metadata,
  });

  AppOpenPromotion.fromJson(dynamic json) {
    id = json['id'];
    title = json['title'];
    subtitle = json['subtitle'];
    mediaType = json['media_type'];
    mediaUrl = json['media_url'];
    thumbnailUrl = json['thumbnail_url'];
    cta = json['cta'];
    action = json['action'];
    actionValue = json['action_value'];
    frequency = json['frequency'];
    frequencyHours = json['frequency_hours'];
    startsAt = json['starts_at'];
    endsAt = json['ends_at'];
    priority = json['priority'];
    metadata = json['metadata'];
  }

  int? id;
  String? title;
  String? subtitle;
  String? mediaType;
  String? mediaUrl;
  String? thumbnailUrl;
  String? cta;
  String? action;
  String? actionValue;
  String? frequency;
  num? frequencyHours;
  String? startsAt;
  String? endsAt;
  num? priority;
  dynamic metadata;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['title'] = title;
    map['subtitle'] = subtitle;
    map['media_type'] = mediaType;
    map['media_url'] = mediaUrl;
    map['thumbnail_url'] = thumbnailUrl;
    map['cta'] = cta;
    map['action'] = action;
    map['action_value'] = actionValue;
    map['frequency'] = frequency;
    map['frequency_hours'] = frequencyHours;
    map['starts_at'] = startsAt;
    map['ends_at'] = endsAt;
    map['priority'] = priority;
    map['metadata'] = metadata;
    return map;
  }
}
