class PlatformAdsResponse {
  PlatformAdsResponse({
    bool? status,
    String? message,
    List<PlatformAd>? data,
  }) {
    _status = status;
    _message = message;
    _data = data;
  }

  PlatformAdsResponse.fromJson(dynamic json) {
    _status = json['status'];
    _message = json['message'];
    if (json['data'] != null) {
      _data = [];
      json['data'].forEach((v) {
        _data?.add(PlatformAd.fromJson(v));
      });
    }
  }

  bool? _status;
  String? _message;
  List<PlatformAd>? _data;

  bool? get status => _status;

  String? get message => _message;

  List<PlatformAd>? get data => _data;

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

class PlatformAd {
  PlatformAd({
    this.id,
    this.source,
    this.placement,
    this.adType,
    this.title,
    this.subtitle,
    this.mediaUrl,
    this.thumbnailUrl,
    this.postId,
    this.destinationUrl,
    this.cta,
    this.advertiserName,
    this.startsAt,
    this.endsAt,
    this.priority,
    this.metadata,
  });

  PlatformAd.fromJson(dynamic json) {
    id = json['id'];
    source = json['source'];
    placement = json['placement'];
    adType = json['type'] ?? json['ad_type'];
    title = json['title'];
    subtitle = json['description'] ?? json['subtitle'];
    mediaUrl = json['url'] ?? json['media_url'];
    thumbnailUrl = json['thumbnail_url'];
    postId = json['post_id'];
    destinationUrl = json['click_url'] ?? json['cta_url'] ?? json['destination_url'];
    cta = json['cta_text'] ?? json['cta'];
    advertiserName = json['advertiser_name'];
    startsAt = json['starts_at'];
    endsAt = json['ends_at'];
    priority = json['priority'];
    metadata = json['metadata'];
  }

  int? id;
  String? source;
  String? placement;
  String? adType;
  String? title;
  String? subtitle;
  String? mediaUrl;
  String? thumbnailUrl;
  int? postId;
  String? destinationUrl;
  String? cta;
  String? advertiserName;
  String? startsAt;
  String? endsAt;
  num? priority;
  dynamic metadata;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['source'] = source;
    map['placement'] = placement;
    map['ad_type'] = adType;
    map['title'] = title;
    map['subtitle'] = subtitle;
    map['media_url'] = mediaUrl;
    map['thumbnail_url'] = thumbnailUrl;
    map['post_id'] = postId;
    map['destination_url'] = destinationUrl;
    map['cta'] = cta;
    map['advertiser_name'] = advertiserName;
    map['starts_at'] = startsAt;
    map['ends_at'] = endsAt;
    map['priority'] = priority;
    map['metadata'] = metadata;
    return map;
  }
}
z