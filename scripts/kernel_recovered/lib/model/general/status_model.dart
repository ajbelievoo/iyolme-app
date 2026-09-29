class StatusModel {
  StatusModel({
    bool? status,
    String? message,
    Map<String, dynamic>? data,
  }) {
    _status = status;
    _message = message;
    _data = data;
  }

  StatusModel.fromJson(dynamic json) {
    _status = json['status'];
    _message = json['message'];
    final d = json['data'];
    if (d is Map) {
      _data = d.cast<String, dynamic>();
    }
  }

  bool? _status;
  String? _message;
  Map<String, dynamic>? _data;

  bool? get status => _status;

  String? get message => _message;

  Map<String, dynamic>? get data => _data;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['status'] = _status;
    map['message'] = _message;
    if (_data != null) map['data'] = _data;
    return map;
  }
}
(