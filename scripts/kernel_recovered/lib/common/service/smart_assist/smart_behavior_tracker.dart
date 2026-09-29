import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shortzz/common/controller/smart_assist_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';

class SmartBehaviorTracker {
  SmartBehaviorTracker._();

  static final SmartBehaviorTracker instance = SmartBehaviorTracker._();

  static const int _maxEvents = 200;

  static const String _kEvents = 'smart_assist_events_v1';
  static const String _kCounts = 'smart_assist_counts_v1';
  static const String _kLast5 = 'smart_assist_last5_v1';
  static const String _kSessionStart = 'smart_assist_session_start_v1';

  GetStorage get _storage => SessionManager.instance.storage;

  GetStorage get storage => _storage;

  SmartAssistController? _smartCtrl() {
    if (!Get.isRegistered<SmartAssistController>()) return null;
    return Get.find<SmartAssistController>();
  }

  bool get _enabled => _smartCtrl()?.isSmartSuggestionsActive ?? false;

  void onSessionStart() {
    if (!_enabled) return;
    _storage.write(_kSessionStart, DateTime.now().millisecondsSinceEpoch);
  }

  void onSessionEnd() {
    if (!_enabled) return;
    final startMs = _storage.read(_kSessionStart);
    if (startMs is int) {
      final sessionSeconds =
          (DateTime.now().millisecondsSinceEpoch - startMs) ~/ 1000;
      _appendEvent({
        't': DateTime.now().millisecondsSinceEpoch,
        'type': 'session_end',
        'seconds': sessionSeconds,
      });
    }
  }

  void trackFeatureOpen({required String feature}) {
    if (!_enabled) return;

    final now = DateTime.now();
    final bucket = _timeBucket(now);

    _appendEvent({
      't': now.millisecondsSinceEpoch,
      'type': 'feature_open',
      'feature': feature,
      'bucket': bucket,
      'hour': now.hour,
      'dow': now.weekday,
    });

    _incrementCount(feature: feature, bucket: bucket);
    _pushLast5(feature);
  }

  List<Map<String, dynamic>> readRecentEvents() {
    final raw = _storage.read(_kEvents);
    if (raw is List) {
      return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }
    return [];
  }

  List<String> readLast5Features() {
    final raw = _storage.read(_kLast5);
    if (raw is List) return raw.whereType<String>().toList();
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    }
    return [];
  }

  Map<String, dynamic> readCounts() {
    final raw = _storage.read(_kCounts);
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  void _incrementCount({required String feature, required String bucket}) {
    final counts = readCounts();

    final String keyAll = 'feature:$feature:all';
    final String keyBucket = 'feature:$feature:bucket:$bucket';

    counts[keyAll] = ((counts[keyAll] as num?) ?? 0).toInt() + 1;
    counts[keyBucket] = ((counts[keyBucket] as num?) ?? 0).toInt() + 1;
    counts['feature:$feature:last_used_ms'] = DateTime.now().millisecondsSinceEpoch;

    _storage.write(_kCounts, counts);
  }

  void _pushLast5(String feature) {
    final list = readLast5Features();
    final updated = <String>[feature, ...list.where((e) => e != feature)];
    if (updated.length > 5) {
      updated.removeRange(5, updated.length);
    }
    _storage.write(_kLast5, updated);
  }

  void _appendEvent(Map<String, dynamic> event) {
    final events = readRecentEvents();
    events.insert(0, event);
    if (events.length > _maxEvents) {
      events.removeRange(_maxEvents, events.length);
    }
    _storage.write(_kEvents, events);
  }

  static String _timeBucket(DateTime dt) {
    final h = dt.hour;
    if (h >= 5 && h < 12) return 'morning';
    if (h >= 12 && h < 17) return 'afternoon';
    if (h >= 17 && h < 22) return 'evening';
    return 'night';
  }
}
