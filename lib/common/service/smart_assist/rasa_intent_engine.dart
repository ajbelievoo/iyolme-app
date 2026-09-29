import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shortzz/common/service/smart_assist/intent_engine.dart';
import 'package:shortzz/common/service/smart_assist/voice_intent.dart';

class RasaIntentEngine implements IntentEngine {
  final Uri endpoint;
  final http.Client _client;

  RasaIntentEngine({required this.endpoint, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<VoiceIntent?> parse(String utterance) async {
    final res = await _client.post(
      endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'text': utterance}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) return null;

    final dynamic data = jsonDecode(res.body);
    if (data is! Map) return null;

    final action = (data['action'] ?? data['intent'] ?? '').toString();
    final target = (data['target'] ?? '').toString();
    final idx = data['index'];
    final value = data['value'];
    final conf = data['confidence'];

    return VoiceIntent(
      action: action,
      target: target,
      index: idx is num ? idx.toInt() : null,
      value: value?.toString(),
      confidence: conf is num ? conf.toDouble() : 1.0,
    );
  }
}
