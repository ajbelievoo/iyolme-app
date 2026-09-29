import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:webrtc_interface/webrtc_interface.dart';

import 'media_stream_track_impl.dart';
import 'utils.dart';

class NativeAudioManagement {
  static Future<void> selectAudioInput(String deviceId) async {
    await WebRTC.invokeMethod(
      'selectAudioInput',
      <String, dynamic>{'deviceId': deviceId},
    );
  }

  static Future<void> setSpeakerphoneOn(bool enable) async {
    await WebRTC.invokeMethod(
      'enableSpeakerphone',
      <String, dynamic>{'enable': enable},
    );
  }

  static Future<void> ensureAudioSession() async {
    await WebRTC.invokeMethod('ensureAudioSession');
  }

  static Future<void> setSpeakerphoneOnButPreferBluetooth() async {
    await WebRTC.invokeMethod('enableSpeakerphoneButPreferBluetooth');
  }

  static Future<void> setVolume(double volume, MediaStreamTrack track) async {
    if (track.kind == 'audio') {
      if (kIsWeb) {
        final constraints = track.getConstraints();
        constraints['volume'] = volume;
        await track.applyConstraints(constraints);
      } else {
        await WebRTC.invokeMethod('setVolume', <String, dynamic>{
          'trackId': track.id,
          'volume': volume,
          'peerConnectionId':
              track is MediaStreamTrackNative ? track.peerConnectionId : null
        });
      }
    }

    return Future.value();
  }

  static Future<void> setMicrophoneMute(
      bool mute, MediaStreamTrack track) async {
    if (track.kind != 'audio') {
      throw 'The is not an audio track => $track';
    }

    if (!kIsWeb) {
      try {
        await WebRTC.invokeMethod(
          'setMicrophoneMute',
          <String, dynamic>{'trackId': track.id, 'mute': mute},
        );
      } on PlatformException catch (e) {
        throw 'Unable to MediaStreamTrack::setMicrophoneMute: ${e.message}';
      }
    }
    track.enabled = !mute;
  }

  // ADM APIs
  static Future<void> startLocalRecording() async {
    if (!kIsWeb) {
      try {
        await WebRTC.invokeMethod(
          'startLocalRecording',
          <String, dynamic>{},
        );
      } on PlatformException catch (e) {
        throw 'Unable to start local recording: ${e.message}';
      }
    }
  }

  static Future<void> stopLocalRecording() async {
    if (!kIsWeb) {
      try {
        await WebRTC.invokeMethod(
          'stopLocalRecording',
          <String, dynamic>{},
        );
      } on PlatformException catch (e) {
        throw 'Unable to stop local recording: ${e.message}';
      }
    }
  }

  static Future<bool> isVoiceProcessingEnabled() async {
    if (kIsWeb) return false;

    try {
      final result = await WebRTC.invokeMethod(
        'isVoiceProcessingEnabled',
        <String, dynamic>{},
      );
      return result as bool;
    } on PlatformException catch (e) {
      throw 'Unable to get isVoiceProcessingEnabled: ${e.message}';
    }
  }

  static Future<bool> isVoiceProcessingBypassed() async {
    if (kIsWeb) return false;

    try {
      final result = await WebRTC.invokeMethod(
        'isVoiceProcessingBypassed',
        <String, dynamic>{},
      );
      return result as bool;
    } on PlatformException catch (e) {
      throw 'Unable to get isVoiceProcessingBypassed: ${e.message}';
    }
  }

  static Future<void> setIsVoiceProcessingBypassed(bool value) async {
    if (kIsWeb) return;

    try {
      await WebRTC.invokeMethod(
        'setIsVoiceProcessingBypassed',
        <String, dynamic>{"value": value},
      );
    } on PlatformException catch (e) {
      throw 'Unable to set isVoiceProcessingBypassed: ${e.message}';
    }
  }

  static Future<void> liveMusicMixStart({
    required String filePath,
    double volume = 0.6,
  }) async {
    if (kIsWeb) return;

    try {
      await WebRTC.invokeMethod(
        'liveMusicMixStart',
        <String, dynamic>{
          'filePath': filePath,
          'volume': volume,
        },
      );
    } on PlatformException catch (e) {
      throw 'Unable to start live music mix: ${e.message}';
    }
  }

  static Future<void> liveMusicMixStop() async {
    if (kIsWeb) return;
    try {
      await WebRTC.invokeMethod('liveMusicMixStop');
    } on PlatformException catch (e) {
      throw 'Unable to stop live music mix: ${e.message}';
    }
  }

  static Future<void> liveMusicMixPause() async {
    if (kIsWeb) return;
    try {
      await WebRTC.invokeMethod('liveMusicMixPause');
    } on PlatformException catch (e) {
      throw 'Unable to pause live music mix: ${e.message}';
    }
  }

  static Future<void> liveMusicMixResume() async {
    if (kIsWeb) return;
    try {
      await WebRTC.invokeMethod('liveMusicMixResume');
    } on PlatformException catch (e) {
      throw 'Unable to resume live music mix: ${e.message}';
    }
  }

  static Future<void> liveMusicMixSetVolume(double volume) async {
    if (kIsWeb) return;
    try {
      await WebRTC.invokeMethod(
        'liveMusicMixSetVolume',
        <String, dynamic>{
          'volume': volume,
        },
      );
    } on PlatformException catch (e) {
      throw 'Unable to set live music mix volume: ${e.message}';
    }
  }

  static Future<void> liveMusicMixSetMicVolume(double volume) async {
    if (kIsWeb) return;
    try {
      await WebRTC.invokeMethod(
        'liveMusicMixSetMicVolume',
        <String, dynamic>{
          'volume': volume,
        },
      );
    } on PlatformException catch (e) {
      throw 'Unable to set live music mic volume: ${e.message}';
    }
  }

  static Future<void> liveMusicMixSeek(int positionMs) async {
    if (kIsWeb) return;
    try {
      await WebRTC.invokeMethod(
        'liveMusicMixSeek',
        <String, dynamic>{
          'positionMs': positionMs,
        },
      );
    } on PlatformException catch (e) {
      throw 'Unable to seek live music mix: ${e.message}';
    }
  }

  static Future<int> liveMusicMixGetPositionMs() async {
    if (kIsWeb) return 0;
    try {
      final result = await WebRTC.invokeMethod('liveMusicMixGetPositionMs');
      return (result as int?) ?? 0;
    } on PlatformException catch (e) {
      throw 'Unable to get live music mix position: ${e.message}';
    }
  }

  static Future<int> liveMusicMixGetDurationMs() async {
    if (kIsWeb) return 0;
    try {
      final result = await WebRTC.invokeMethod('liveMusicMixGetDurationMs');
      return (result as int?) ?? 0;
    } on PlatformException catch (e) {
      throw 'Unable to get live music mix duration: ${e.message}';
    }
  }
}
