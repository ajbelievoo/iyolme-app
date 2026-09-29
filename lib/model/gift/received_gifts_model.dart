class ReceivedGiftsModel {
  bool? status;
  String? message;
  ReceivedGiftsData? data;

  ReceivedGiftsModel({this.status, this.message, this.data});

  ReceivedGiftsModel.fromJson(dynamic json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? ReceivedGiftsData.fromJson(json['data']) : null;
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

class ReceivedGiftsData {
  List<ReceivedGiftItem>? items;
  int? lastItemId;

  ReceivedGiftsData({this.items, this.lastItemId});

  ReceivedGiftsData.fromJson(dynamic json) {
    if (json == null) return;

    final rawItems = json['items'] ?? json['data'] ?? json['list'];
    if (rawItems is List) {
      items = rawItems
          .map((e) => ReceivedGiftItem.fromJson(e))
          .whereType<ReceivedGiftItem>()
          .toList();
    }

    final rawLast =
        json['last_item_id'] ?? json['lastItemId'] ?? json['next'] ?? json['cursor'];
    if (rawLast is num) {
      lastItemId = rawLast.toInt();
    } else if (rawLast is String) {
      lastItemId = int.tryParse(rawLast.trim());
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['items'] = items?.map((e) => e.toJson()).toList();
    map['last_item_id'] = lastItemId;
    return map;
  }
}

class ReceivedGiftItem {
  int? id;
  int? giftId;
  String? giftImage;
  int? coinPrice;
  int? count;
  int? senderUserId;
  String? createdAt;

  ReceivedGiftItem(
      {this.id,
      this.giftId,
      this.giftImage,
      this.coinPrice,
      this.count,
      this.senderUserId,
      this.createdAt});

  ReceivedGiftItem.fromJson(dynamic json) {
    if (json == null) return;
    id = json['id'];
    giftId = json['gift_id'] ?? json['giftId'];
    giftImage = json['gift_image'] ?? json['giftImage'] ?? json['image'];
    coinPrice = json['coin_price'] ?? json['coinPrice'] ?? json['coins'];
    final rawCount = json['count'] ?? json['qty'] ?? json['quantity'];
    if (rawCount is num) {
      count = rawCount.toInt();
    } else if (rawCount is String) {
      count = int.tryParse(rawCount.trim());
    }
    senderUserId = json['sender_user_id'] ?? json['senderUserId'];
    createdAt = json['created_at'] ?? json['createdAt'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['gift_id'] = giftId;
    map['gift_image'] = giftImage;
    map['coin_price'] = coinPrice;
    map['count'] = count;
    map['sender_user_id'] = senderUserId;
    map['created_at'] = createdAt;
    return map;
  }
}
