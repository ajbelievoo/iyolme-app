import 'dart:math';

import 'package:shortzz/common/service/smart_assist/smart_behavior_tracker.dart';

class SmartSuggestion {
  final String feature;
  final double confidence;
  final Map<String, double> scores;

  const SmartSuggestion({
    required this.feature,
    required this.confidence,
    required this.scores,
  });
}

class SmartPredictionEngine {
  SmartPredictionEngine._();

  static final SmartPredictionEngine instance = SmartPredictionEngine._();

  static const String kSuggestionMeta = 'smart_assist_suggestion_meta_v1';

  static const double _minConfidence = 0.70;

  static const Duration _noRepeatWindow = Duration(hours: 24);

  SmartSuggestion? predictNext({
    required List<String> candidateFeatures,
  }) {
    final tracker = SmartBehaviorTracker.instance;
    final counts = tracker.readCounts();

    if (counts.isEmpty) return null;

    final now = DateTime.now();
    final bucket = _timeBucket(now);
    final last5 = tracker.readLast5Features();

    final scores = <String, double>{};
    for (final f in candidateFeatures) {
      final all = _asInt(counts['feature:$f:all']);
      if (all <= 0) {
        scores[f] = 0;
        continue;
      }

      final bucketCount = _asInt(counts['feature:$f:bucket:$bucket']);
      final lastUsedMs = _asInt(counts['feature:$f:last_used_ms']);

      final freq = _normalize(all.toDouble(), 1, 50);
      final bucketBoost = _normalize(bucketCount.toDouble(), 0, 25);
      final recencyBoost = _recencyScore(lastUsedMs);
      final last5Boost = last5.isNotEmpty && last5.first == f ? 0.20 : 0.0;

      final raw = (freq * 0.45) +
          (bucketBoost * 0.25) +
          (recencyBoost * 0.25) +
          last5Boost;
      scores[f] = applyPenalty(feature: f, score: raw);
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) return null;

    final top = sorted.first;
    final second = sorted.length > 1 ? sorted[1] : null;

    final confidence = _confidence(top.value, second?.value ?? 0);

    if (confidence < _minConfidence) return null;

    if (_isInNoRepeatWindow(feature: top.key, now: now)) return null;

    return SmartSuggestion(feature: top.key, confidence: confidence, scores: scores);
  }

  bool _isInNoRepeatWindow({required String feature, required DateTime now}) {
    final meta = _readMeta();
    final lastShownMs = _asInt(meta['last_shown_ms:$feature']);
    if (lastShownMs <= 0) return false;

    final last = DateTime.fromMillisecondsSinceEpoch(lastShownMs);
    return now.difference(last) < _noRepeatWindow;
  }

  void markSuggestionShown({required String feature}) {
    final meta = _readMeta();
    meta['last_shown_ms:$feature'] = DateTime.now().millisecondsSinceEpoch;
    _writeMeta(meta);
  }

  void markSuggestionDismissed({required String feature}) {
    final meta = _readMeta();
    final currentPenalty = (_asDouble(meta['penalty:$feature'])).clamp(0, 1);
    meta['penalty:$feature'] = min(1.0, currentPenalty + 0.25);
    _writeMeta(meta);
  }

  double applyPenalty({required String feature, required double score}) {
    final meta = _readMeta();
    final penalty = (_asDouble(meta['penalty:$feature'])).clamp(0, 1);
    return score * (1.0 - (penalty * 0.5));
  }

  Map<String, dynamic> _readMeta() {
    final raw = SmartBehaviorTracker.instance.storage.read(kSuggestionMeta);
    if (raw is Map) return raw.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  void _writeMeta(Map<String, dynamic> meta) {
    SmartBehaviorTracker.instance.storage.write(kSuggestionMeta, meta);
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static double _normalize(double v, double minV, double maxV) {
    if (maxV <= minV) return 0;
    return ((v - minV) / (maxV - minV)).clamp(0.0, 1.0);
  }

  static double _recencyScore(int lastUsedMs) {
    if (lastUsedMs <= 0) return 0;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastUsedMs));
    final hours = age.inMinutes / 60.0;
    if (hours <= 1) return 1.0;
    if (hours <= 6) return 0.8;
    if (hours <= 24) return 0.5;
    if (hours <= 72) return 0.25;
    return 0.1;
  }

  static double _confidence(double top, double second) {
    if (top <= 0) return 0;
    final gap = (top - second).clamp(0, 1);
    return (0.55 + (gap * 0.45)).clamp(0.0, 1.0);
  }

  static String _timeBucket(DateTime dt) {
    final h = dt.hour;
    if (h >= 5 && h < 12) return 'morning';
    if (h >= 12 && h < 17) return 'afternoon';
    if (h >= 17 && h < 22) return 'evening';
    return 'night';
  }
}
