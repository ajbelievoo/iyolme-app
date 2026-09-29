import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/model/misc/activity_notification_model.dart';
import 'package:shortzz/model/misc/admin_notification_model.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/const_res.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  Future<List<AdminNotificationData>> fetchAdminNotifications(
      {int? lastItemId}) async {
    AdminNotificationModel response = await ApiService.instance.call(
        url: WebService.notification.fetchAdminNotifications,
        fromJson: AdminNotificationModel.fromJson,
        param: {
          Params.limit: AppRes.paginationLimit,
          Params.lastItemId: lastItemId
        });
    if (response.status == true) {
      return response.data ?? [];
    }
    return [];
  }

  Future<List<ActivityNotification>> fetchActivityNotifications(
      {int? lastItemId}) async {
    ActivityNotificationModel response = await ApiService.instance.call(
        url: WebService.notification.fetchActivityNotifications,
        fromJson: ActivityNotificationModel.fromJson,
        param: {
          Params.limit: AppRes.paginationLimit,
          Params.lastItemId: lastItemId,
        });
    if (response.status == true) {
      return response.data ?? [];
    } else {
      return [];
    }
  }

  Future pushNotification(
      {required NotificationType type,
      required String title,
      required String body,
      Map<String, dynamic>? data,
      String? token,
      String? topic,
      num? deviceType,
      String? authorizationToken,
      String? sound}) async {
    bool isIOS = deviceType == 1;

    final callId = data?['call_id']?.toString();
    final isCall = type == NotificationType.call ||
        (sound == 'call_ring') ||
        body.contains('Incoming Audio Call') ||
        body.contains('Incoming Video Call');

    Map<String, dynamic> messageData = {
      "apns": {
        "headers": {"apns-priority": "10"},
        "payload": {
          "aps": {
            "sound": sound ?? "default",
            "alert": {"title": title, "body": body},
            "content-available": 1,
          }
        }
      },
      "data": {
        "title": title,
        "body": body,
        'type': type.type,
        if (callId != null && callId.isNotEmpty) 'call_id': callId,
        if (data != null) "notification_data": jsonEncode(data)
      }
    };

    // For Android call UX (lock screen / app killed): prefer data-only + local fullScreenIntent.
    // For iOS: must include notification/APNS alert to reliably wake UI.
    if (!(isCall && !isIOS)) {
      messageData["notification"] = {
        "body": body,
        "title": title,
        if (sound != null) "sound": sound,
        if (sound != null) "android_channel_id": "call_channel"
      };
    }

    if (isCall) {
      messageData["android"] = {
        "priority": "high",
        "notification": {
          "channel_id": "call_channel",
          "sound": sound ?? "default",
        }
      };
    }
    if (token != null) {
      messageData["token"] = token;
    }
    if (topic != null) {
      messageData["topic"] = topic;
    }

    Map<String, dynamic> inputData = {"message": messageData};

    var prettyString = const JsonEncoder.withIndent('  ').convert(inputData);
    Loggers.info(prettyString);
    try {
      final url = WebService.notification.pushNotificationToSingleUser;
      final authToken = authorizationToken ?? SessionManager.instance.getAuthToken();
      Loggers.info(
          '[PUSH_NOTIFICATION] url=$url hasAuthToken=${(authToken).isNotEmpty} isIOS=$isIOS deviceType=$deviceType hasToken=${(token ?? '').isNotEmpty}');

      http.Response response = await http.post(
          Uri.parse(url),
          headers: {
            Params.apikey: apiKey,
            Params.authToken: authToken,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(inputData));
      Loggers.info(
          '[PUSH_NOTIFICATION] statusCode=${response.statusCode} body=${response.body}');
      if (response.statusCode != 200) {
        Loggers.error(
            '[PUSH_NOTIFICATION] failed statusCode=${response.statusCode}');
      }
    } catch (e) {
      Loggers.error(e);
    }
  }
}
