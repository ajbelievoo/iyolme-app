import 'package:shortzz/model/post_story/post_model.dart';

class PostsModel {
  PostsModel({
    bool? status,
    String? message,
    List<Post>? data,
    bool? endOfFeed,
    int? itemsCount,
    String? reason,
  }) {
    _status = status;
    _message = message;
    _data = data;
    _endOfFeed = endOfFeed;
    _itemsCount = itemsCount;
    _reason = reason;
  }

  PostsModel.fromJson(dynamic json) {
    _status = json['status'];
    _message = json['message'];
    _endOfFeed = json['endOfFeed'] ?? json['end_of_feed'];
    _itemsCount = json['itemsCount'] ?? json['items_count'];
    _reason = json['reason'];
    final dynamic rawData = json['data'];
    if (rawData == null) return;

    dynamic rawPosts = rawData;
    if (rawData is Map<String, dynamic>) {
      _endOfFeed = rawData['endOfFeed'] ?? rawData['end_of_feed'] ?? _endOfFeed;
      _itemsCount = rawData['itemsCount'] ?? rawData['items_count'] ?? _itemsCount;
      _reason = rawData['reason'] ?? _reason;
      rawPosts = rawData['posts'] ?? rawData['data'];
    }

    if (rawPosts is List) {
      _data = [];
      for (final v in rawPosts) {
        _data?.add(Post.fromJson(v));
      }
    }
  }

  bool? _status;
  String? _message;
  List<Post>? _data;
  bool? _endOfFeed;
  int? _itemsCount;
  String? _reason;

  bool? get status => _status;

  String? get message => _message;

  List<Post>? get data => _data;
  bool? get endOfFeed => _endOfFeed;
  int? get itemsCount => _itemsCount;
  String? get reason => _reason;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['status'] = _status;
    map['message'] = _message;
    map['endOfFeed'] = _endOfFeed;
    map['itemsCount'] = _itemsCount;
    map['reason'] = _reason;
    if (_data != null) {
      map['data'] = _data?.map((v) => v.toJson()).toList();
    }
    return map;
  }
}
K