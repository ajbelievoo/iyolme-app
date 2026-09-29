import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/smart_assist/intent_engine.dart';
import 'package:shortzz/common/service/smart_assist/voice_intent.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/utilities/const_res.dart';

class GPTProxyIntentEngine implements IntentEngine {
  final Uri endpoint;
  final http.Client _client;

  GPTProxyIntentEngine({Uri? endpoint, http.Client? client})
      : endpoint = endpoint ?? Uri.parse('${apiURL}voice_intent.php'),
        _client = client ?? http.Client();

  @override
  Future<VoiceIntent?> parse(String utterance) async {
    return parseWithContext(utterance, context: const {});
  }

  Future<Map<String, dynamic>?> parseRawWithContext(
    String utterance, {
    required Map<String, dynamic> context,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      Params.apikey: apiKey,
      Params.authToken: SessionManager.instance.getAuthToken(),
    };

    final body = jsonEncode({
      'text': utterance,
      'context': context,
    });

    final res = await _client.post(endpoint, headers: headers, body: body);

    if (res.statusCode < 200 || res.statusCode >= 300) return null;

    final dynamic data = jsonDecode(res.body);
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    return null;
  }

  Future<VoiceIntent?> parseWithContext(
    String utterance, {
    required Map<String, dynamic> context,
  }) async {
    final data = await parseRawWithContext(utterance, context: context);
    if (data == null) return null;

    final conf = data['confidence'];
    final action = (data['action'] ?? '').toString();
    final target = (data['target'] ?? '').toString();
    final idx = data['index'];
    final value = data['value'];

    return VoiceIntent(
      action: action,
      target: target,
      index: idx is num ? idx.toInt() : null,
      value: value?.toString(),
      confidence: conf is num ? conf.toDouble() : 0.0,
    );
  }
}
H