import 'package:shortzz/common/service/smart_assist/voice_intent.dart';

abstract class IntentEngine {
  Future<VoiceIntent?> parse(String utterance);
}
