import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/smart_assist/voice_intent.dart';
import 'package:shortzz/utilities/const_res.dart';

/// Online audio-based intent engine.
///
/// Responsibility:
/// - Accept short recorded audio bytes from mic (3–5 seconds).
/// - Send them to backend as multipart/form-data.
/// - Parse JSON response into [VoiceIntent].
///
/// NOTE: This is only a skeleton. Backend endpoint, headers and
/// HTTP client wiring should be filled by the team using the
/// existing ApiService / SessionManager utilities.
class OnlineAudioIntentEngine {
  const OnlineAudioIntentEngine();

  /// Send audio buffer to backend and receive a [VoiceIntent].
  ///
  /// [audioBytes] should be a small mono clip (e.g. 16 kHz WAV/PCM/Opus).
  /// [context] should match the structure already used for text intent API
  /// (screen, visible_items, etc.).
  ///
  /// Returns null if backend cannot determine any reliable intent.
  Future<VoiceIntent?> sendAudioAndGetIntent({
    required Uint8List audioBytes,
    required Map<String, dynamic> context,
  }) async {
    if (audioBytes.isEmpty) return null;

    // Write the raw bytes to a temporary file so we can send it via
    // ApiService.multiPartCallApi, which expects XFile/File paths.
    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    final file = File(filePath);
    await file.writeAsBytes(audioBytes, flush: true);

    final xFile = XFile(file.path, name: 'voice.wav');

    try {
      final Map<String, dynamic> resp = await ApiService.instance
          .multiPartCallApi<Map<String, dynamic>>(
        url: '${apiURL}voice_intent_audio.php',
        param: <String, dynamic>{
          // Backend accepts context either as array or JSON string; we
          // send it as JSON string to be safe.
          'context': jsonEncode(context),
        },
        filesMap: <String, List<XFile?>>{
          'audio': <XFile?>[xFile],
        },
        fromJson: (json) => json,
      );

      if (resp['ok'] != true) {
        return null;
      }

      final intentData = resp['intent'];
      if (intentData is! Map<String, dynamic>) return null;

      final conf = intentData['confidence'];
      final action = (intentData['action'] ?? '').toString();
      final target = (intentData['target'] ?? '').toString();
      final idx = intentData['index'];
      final value = intentData['value'];

      return VoiceIntent(
        action: action,
        target: target,
        index: idx is num ? idx.toInt() : null,
        value: value?.toString(),
        confidence: conf is num ? conf.toDouble() : 0.0,
      );
    } catch (_) {
      return null;
    } finally {
      // Best-effort cleanup of the temp file.
      await ApiService.instance.useAndDeleteFile(file);
    }
  }
}
[