import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class Loggers {
  static const int _maxLogChars = 600;

  static String _safe(Object? msg) {
    final s = '${msg ?? ''}';
    if (s.length <= _maxLogChars) return s;
    return '${s.substring(0, _maxLogChars)}…';
  }

  static void info(Object? msg) {
    if (!kDebugMode) return;
    final s = _safe(msg);
    debugPrint(s);
    developer.log(s, name: 'INFO');
  }

  static void success(Object? msg) {
    if (!kDebugMode) return;
    final s = _safe(msg);
    debugPrint('✅✅✅: $s');
    developer.log('✅✅✅: $s', name: 'SUCCESS');
  }

  static void warning(Object? msg) {
    if (!kDebugMode) return;
    final s = _safe(msg);
    debugPrint('⚠️⚠️⚠️: $s');
    developer.log('⚠️⚠️⚠️: $s', name: 'WARNING');
  }

  static void error(Object? msg) {
    if (!kDebugMode) return;
    final s = _safe(msg);
    debugPrint('🔴🔴🔴: $s');
    developer.log('🔴🔴🔴: $s', name: 'ERROR');
  }
}
