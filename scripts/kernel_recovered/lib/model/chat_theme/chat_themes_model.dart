class ChatThemesModel {
  bool? status;
  String? message;
  List<ChatThemeItem>? data;

  ChatThemesModel({this.status, this.message, this.data});

  factory ChatThemesModel.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    return ChatThemesModel(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => ChatThemeItem.fromJson(e.cast<String, dynamic>()))
              .toList()
          : <ChatThemeItem>[],
    );
  }
}

class ChatThemeItem {
  int? id;
  String? title;
  String? backgroundImage;
  String? backgroundImageUrl;

  ChatThemeItem({
    this.id,
    this.title,
    this.backgroundImage,
    this.backgroundImageUrl,
  });

  factory ChatThemeItem.fromJson(Map<String, dynamic> json) {
    return ChatThemeItem(
      id: _toInt(json['id']),
      title: (json['title'] ?? json['name'])?.toString(),
      backgroundImage: json['background_image']?.toString(),
      backgroundImageUrl: (json['background_image_url'] ?? json['backgroundImageUrl'])?.toString(),
    );
  }
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}
5