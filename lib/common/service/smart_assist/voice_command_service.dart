// Voice commands disabled - speech_to_text dependency removed
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shortzz/common/controller/smart_assist_controller.dart';
import 'package:shortzz/common/service/smart_assist/intent_engine.dart';
import 'package:shortzz/common/service/smart_assist/gpt_proxy_intent_engine.dart';
import 'package:shortzz/common/service/smart_assist/local_rule_intent_engine.dart';
import 'package:shortzz/common/service/smart_assist/rasa_intent_engine.dart';
import 'package:shortzz/common/service/smart_assist/voice_ui_action_registry.dart';
import 'package:shortzz/common/service/smart_assist/voice_intent.dart';
import 'package:shortzz/common/service/smart_assist/online_audio_intent_engine.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/screen/report_sheet/report_sheet_controller.dart';
import 'package:fluttertoast/fluttertoast.dart';

class VoiceCommandService {
  VoiceCommandService._();

  static final VoiceCommandService instance = VoiceCommandService._();

  // Online audio-based intent engine (Whisper/GPT on backend).
  final OnlineAudioIntentEngine _onlineEngine = const OnlineAudioIntentEngine();

  final RxBool isListening = false.obs;
  final RxString lastWords = ''.obs;

  Timer? _autoStopTimer;
  Timer? _restartTimer;
  bool _foregroundLoopEnabled = false;
  void Function(String feature)? _onFeatureCommand;

  _DictationTarget _dictationTarget = _DictationTarget.none;

  IntentEngine _intentEngine = LocalRuleIntentEngine();

  final GPTProxyIntentEngine _gptProxyIntentEngine = GPTProxyIntentEngine();
  DateTime? _lastClarifyAt;
  static const double _minProxyConfidence = 0.60;

  String _lastCmd = '';
  DateTime? _lastCmdAt;

  bool enableVerboseLogs = true;

  void useLocalIntentEngine() {
    _intentEngine = LocalRuleIntentEngine();
  }

  void useRasaIntentEngine({required String endpoint}) {
    _intentEngine = RasaIntentEngine(endpoint: Uri.parse(endpoint));
  }

  SmartAssistController? _smartCtrl() {
    if (!Get.isRegistered<SmartAssistController>()) return null;
    return Get.find<SmartAssistController>();
  }

  bool get _wakeEnabled => _smartCtrl()?.isSmartSuggestionsActive ?? false;

  Future<void> startForegroundLoop({
    required void Function(String feature) onFeatureCommand,
  }) async {
    // Hard entry probe for debugging wiring.
    // ignore: avoid_print
    Loggers.info('VOICE >>> ENTER startForegroundLoop');
    if (enableVerboseLogs) {
      Loggers.info('[VOICE][loop] startForegroundLoop called; wakeEnabled=$_wakeEnabled isListening=${isListening.value}');
    }
    // ignore: avoid_print
    Loggers.info('[VOICE][loop] startForegroundLoop called; wakeEnabled=$_wakeEnabled isListening=${isListening.value}');
    _foregroundLoopEnabled = true;
    _onFeatureCommand = onFeatureCommand;
    Fluttertoast.showToast(msg: 'Offline voice disabled. Internet voice will work when you record and send audio.');
  }

  Future<void> stopForegroundLoop() async {
    if (enableVerboseLogs) {
      Loggers.info('[VOICE][loop] stopForegroundLoop called');
    }
    // ignore: avoid_print
    Loggers.info('[VOICE][loop] stopForegroundLoop called');
    _foregroundLoopEnabled = false;
    _onFeatureCommand = null;
    _restartTimer?.cancel();
    _restartTimer = null;
    await stopListening();
  }

  Future<void> _startOnce() async {
    // Always allow wake-phrase listening when Smart Suggestions are ON.
    // Commands execute only when voiceCommandsEnabled is ON.
    if (enableVerboseLogs) {
      Loggers.info('[VOICE][start] _startOnce wakeEnabled=$_wakeEnabled isListening=${isListening.value} hasFeatureHandler=${_onFeatureCommand != null}');
    }
    // ignore: avoid_print
    Loggers.info('[VOICE][start] _startOnce wakeEnabled=$_wakeEnabled isListening=${isListening.value} hasFeatureHandler=${_onFeatureCommand != null}');

    if (!_wakeEnabled) {
      if (enableVerboseLogs) {
        Loggers.info('[VOICE][start] abort: wake disabled (Smart Suggestions OFF)');
      }
      // ignore: avoid_print
      Loggers.info('[VOICE][start] abort: wake disabled (Smart Suggestions OFF)');
      return;
    }
    if (isListening.value) {
      if (enableVerboseLogs) {
        Loggers.info('[VOICE][start] abort: already listening');
      }
      // ignore: avoid_print
      Loggers.info('[VOICE][start] abort: already listening');
      return;
    }
    if (_onFeatureCommand == null) {
      if (enableVerboseLogs) {
        Loggers.info('[VOICE][start] abort: onFeatureCommand handler is null');
      }
      // ignore: avoid_print
      Loggers.info('[VOICE][start] abort: onFeatureCommand handler is null');
      return;
    }

    await _ensureMicPermission();
    Fluttertoast.showToast(msg: 'Offline voice disabled. Use online voice.');
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 700), () {
      _startOnce();
    });
  }

  bool _handleSimpleCommand(String cmd) {
    final lower = cmd.toLowerCase();

    if (lower.contains('profile')) {
      // ignore: avoid_print
      Loggers.info('[VOICE][action] OPEN_PROFILE for cmd="$cmd"');
      _onFeatureCommand?.call('profile');
      return true;
    }

    if (lower.contains('home')) {
      // Map "home" to main feed screen.
      // ignore: avoid_print
      Loggers.info('[VOICE][action] OPEN_FEED for cmd="$cmd"');
      _onFeatureCommand?.call('feed');
      return true;
    }

    if (lower.contains('live')) {
      // ignore: avoid_print
      Loggers.info('[VOICE][action] OPEN_LIVE for cmd="$cmd"');
      _onFeatureCommand?.call('live');
      return true;
    }

    // Not handled here.
    // ignore: avoid_print
    Loggers.info('[VOICE][intent] simple handler could not map cmd="$cmd"');
    return false;
  }

  /// Send a recorded audio clip to the backend online intent engine and
  /// execute the returned intent, if any.
  ///
  /// This does NOT start/stop any recorder by itself; it expects a short
  /// audio buffer captured elsewhere (e.g. 3–5 seconds from mic).
  Future<void> handleOnlineAudio(Uint8List audioBytes) async {
    if (audioBytes.isEmpty) return;

    final ctx = VoiceUiActionRegistry.instance.buildContextPayload();
    // ignore: avoid_print
    Loggers.info('[VOICE][online] SEND audio bytes=${audioBytes.lengthInBytes} ctx=$ctx');

    try {
      final intent = await _onlineEngine.sendAudioAndGetIntent(
        audioBytes: audioBytes,
        context: ctx,
      );

      if (intent == null) {
        // ignore: avoid_print
        Loggers.info('[VOICE][online] no intent returned');
        return;
      }

      // ignore: avoid_print
      Loggers.info('[VOICE][online] PARSED intent=${intent.toJson()}');

      final executed = _executeVoiceIntent(intent);
      if (enableVerboseLogs) {
        if (executed) {
          Loggers.success('[VOICE][online] intent executed');
        } else {
          Loggers.info('[VOICE][online] intent not executed by any handler');
        }
      }
    } catch (e) {
      // ignore: avoid_print
      Loggers.info('[VOICE][online_error] $e');
      if (enableVerboseLogs) {
        Loggers.error('[VOICE][online_error] $e');
      }
    }
  }

  /// DEBUG ONLY: Send the bundled sample recording through the online
  /// audio intent engine. This helps verify the end-to-end pipeline
  /// (Flutter → backend STT/intent → VoiceIntent execution) without
  /// wiring mic recording yet.
  Future<void> debugSendSampleRecording() async {
    try {
      final data = await rootBundle.load('assets/audios/recording.mp4');
      final bytes = data.buffer.asUint8List();
      // ignore: avoid_print
      Loggers.info('[VOICE][online_debug] loaded sample recording bytes=${bytes.lengthInBytes}');
      await handleOnlineAudio(bytes);
    } catch (e) {
      // ignore: avoid_print
      Loggers.info('[VOICE][online_debug_error] $e');
      if (enableVerboseLogs) {
        Loggers.error('[VOICE][online_debug_error] $e');
      }
    }
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      if (enableVerboseLogs) {
        Loggers.info('[VOICE][perm] microphone already granted');
      }
      // ignore: avoid_print
      Loggers.info('[VOICE][perm] microphone already granted');
      return true;
    }

    if (enableVerboseLogs) {
      Loggers.info('[VOICE][perm] microphone not granted, requesting');
    }
    // ignore: avoid_print
    Loggers.info('[VOICE][perm] microphone not granted, requesting');

    final req = await Permission.microphone.request();
    if (!req.isGranted) {
      if (enableVerboseLogs) {
        Loggers.error('[VOICE][perm] microphone denied by user');
      }
      Fluttertoast.showToast(msg: 'Mic permission denied. Please allow microphone for IyolMe voice commands.');
      return false;
    }

    if (enableVerboseLogs) {
      Loggers.info('[VOICE][perm] microphone granted after request');
    }
    // ignore: avoid_print
    Loggers.info('[VOICE][perm] microphone granted after request');
    return true;
  }

  Future<void> startListening({
    required void Function(String feature) onFeatureCommand,
  }) async {
    await startForegroundLoop(onFeatureCommand: onFeatureCommand);
  }

  Future<void> stopListening() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    if (isListening.value) {
      isListening.value = false;
    }
  }

  static VoiceIntent? _intentFromProxyRaw(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final conf = raw['confidence'];
    final action = (raw['action'] ?? '').toString();
    final target = (raw['target'] ?? '').toString();
    final idx = raw['index'];
    final value = raw['value'];
    return VoiceIntent(
      action: action,
      target: target,
      index: idx is num ? idx.toInt() : null,
      value: value?.toString(),
      confidence: conf is num ? conf.toDouble() : 0.0,
    );
  }

  static bool _isVoiceOffCommand(String cmd) {
    return cmd.contains('voice commands off') ||
        cmd.contains('stop listening') ||
        cmd.contains('voice off') ||
        cmd.contains('band') ||
        cmd.contains('बंद') ||
        cmd.contains('band karo') ||
        cmd.contains('band karo');
  }

  static bool _isVoiceOnCommand(String cmd) {
    return cmd.contains('voice commands on') ||
        cmd.contains('hey vidmite') ||
        cmd.contains('vidmite listen') ||
        cmd.contains('listen vidmite') ||
        cmd.contains('iyol voice commands on') ||
        cmd.contains('iyol voice on') ||
        cmd.contains('iyol listen') ||
        cmd.contains('smart voice start') ||
        cmd.contains('voice on') ||
        cmd.contains('start listening');
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _stripWakeWord(String cmd) {
    var out = cmd;
    if (out.startsWith('iyol ')) {
      out = out.substring('iyol '.length);
    }
    if (out == 'iyol') return '';
    return out.trim();
  }

  Future<bool> _routeThroughIntentEngine(String cmd) async {
    // Hard debug: entry log for intent engine routing
    // ignore: avoid_print
    Loggers.info('[VOICE][intent] _routeThroughIntentEngine ENTER cmd="$cmd"');

    VoiceIntent? intent;
    try {
      intent = await _intentEngine.parse(cmd);
    } catch (_) {
      intent = null;
    }

    if (intent != null && intent.confidence >= _minProxyConfidence) {
      if (enableVerboseLogs) {
        Loggers.info('[VOICE][local] intent=${intent.toJson()}');
      }
      // ignore: avoid_print
      Loggers.info('[VOICE][local] using local intent: ${intent.toJson()}');
      return _executeVoiceIntent(intent);
    }

    // Fallback: ask backend (GPT proxy) with current UI context.
    try {
      final context = VoiceUiActionRegistry.instance.buildContextPayload();
      if (enableVerboseLogs) {
        Loggers.info('[VOICE][proxy] send text="$cmd" ctx=$context');
      }
      // ignore: avoid_print
      Loggers.info('[VOICE][proxy] SEND text="$cmd" ctx=$context');

      final raw = await _gptProxyIntentEngine.parseRawWithContext(cmd, context: context);
      if (enableVerboseLogs) {
        Loggers.info('[VOICE][proxy] resp=$raw');
      }
      // ignore: avoid_print
      Loggers.info('[VOICE][proxy] RAW resp=$raw');
      final proxy = _intentFromProxyRaw(raw);

      if (proxy == null) {
        // ignore: avoid_print
        Loggers.info('[VOICE][proxy] proxy intent NULL for cmd="$cmd"');
        _maybeAskClarify();
        return false;
      }

      // ignore: avoid_print
      Loggers.info('[VOICE][proxy] PARSED intent=${proxy.toJson()}');

      if (proxy.confidence < _minProxyConfidence) {
        if (enableVerboseLogs) {
          Loggers.info('[VOICE][proxy] low confidence=${proxy.confidence} intent=${proxy.toJson()}');
        }
        _maybeAskClarify();
        return false;
      }

      return _executeVoiceIntent(proxy);
    } catch (e) {
      if (enableVerboseLogs) {
        Loggers.error('[VOICE][proxy_error] $e');
      }
      // ignore: avoid_print
      Loggers.info('[VOICE][proxy_error] $e');
      _maybeAskClarify();
      return false;
    }
  }

  bool _shouldIgnoreDuplicate(String cmd) {
    final c = cmd.trim();
    if (c.isEmpty) return true;

    final now = DateTime.now();
    final lastAt = _lastCmdAt;

    if (lastAt != null && c == _lastCmd) {
      if (now.difference(lastAt) < const Duration(milliseconds: 700)) {
        return true;
      }
    }

    _lastCmd = c;
    _lastCmdAt = now;
    return false;
  }

  void _maybeAskClarify() {
    final now = DateTime.now();
    if (_lastClarifyAt != null && now.difference(_lastClarifyAt!) < const Duration(seconds: 6)) {
      return;
    }
    _lastClarifyAt = now;
    try {
      final ctx = Get.overlayContext;
      if (ctx == null) return;
      Get.rawSnackbar(
        message: 'Samajh nahi aaya. Please phir se bolo ya pehli/dusri (1/2) batao.',
        duration: const Duration(seconds: 2),
      );
    } catch (_) {
      // Avoid crashing if overlay/snackbar context is not available.
    }
  }

  bool _executeVoiceIntent(VoiceIntent intent) {
    if (intent.action == 'unknown' || intent.confidence <= 0) {
      if (enableVerboseLogs) {
        Loggers.info('[VOICE] intent ignored (unknown/low confidence): ${intent.toJson()}');
      }
      return false;
    }

    if (intent.target == 'disambiguation' && intent.action == 'select') {
      final idx = intent.index;
      if (idx != null) {
        VoiceUiActionRegistry.instance.selectIndex(idx);
      }
      return true;
    }

    // Global navigation: back (be liberal on target, rely mainly on action)
    if (intent.action == 'back') {
      if (enableVerboseLogs) {
        Loggers.success('[VOICE] execute back navigation intent=${intent.toJson()}');
      }
      try {
        if (Get.isDialogOpen == true) {
          // Close dialog via root navigator to avoid GetX snackbar controller issues
          final ctx = Get.overlayContext;
          if (ctx != null && Navigator.of(ctx, rootNavigator: true).canPop()) {
            Navigator.of(ctx, rootNavigator: true).pop();
          } else {
            // fallback: try Get.back only if overlay exists
            try { Get.back(); } catch (_) {}
          }
        } else {
          // For non-dialog navigation, use root navigator safely
          final ctx = Get.overlayContext;
          if (ctx != null && Navigator.of(ctx, rootNavigator: true).canPop()) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        }
      } catch (_) {
        // ignore navigation errors
      }
      return true;
    }

    // Open high-level app sections (tabs/screens)
    if (intent.action == 'open') {
      String? feature;
      switch (intent.target) {
        case 'home_tab':
        case 'feed':
        case 'screen':
          feature = 'feed';
          break;
        case 'profile_tab':
        case 'profile':
          feature = 'profile';
          break;
        case 'messages':
          feature = 'chat';
          break;
        case 'live':
          feature = 'live';
          break;
        case 'settings':
          feature = 'settings';
          break;
        default:
          feature = intent.target.isNotEmpty ? intent.target : null;
      }

      if (feature != null) {
        _onFeatureCommand?.call(feature);
        if (enableVerboseLogs) {
          Loggers.success('[VOICE] execute open feature="$feature" from intent');
        }
        return true;
      }
    }

    // Navigate within current screen (e.g., next/scroll profile/feed)
    if (intent.action == 'navigate') {
      if (intent.target == 'profile' || intent.target == 'profile_tab') {
        _onFeatureCommand?.call('profile');
        if (enableVerboseLogs) {
          Loggers.success('[VOICE] execute navigate profile from intent');
        }
        return true;
      }

      if (intent.target == 'home_tab' || intent.target == 'feed' || intent.target == 'screen') {
        _onFeatureCommand?.call('feed');
        if (enableVerboseLogs) {
          Loggers.success('[VOICE] execute navigate feed from intent');
        }
        return true;
      }
    }

    // Feed post actions
    if (intent.target == 'feed_post') {
      final reg = VoiceUiActionRegistry.instance;
      final ids = reg.feedPostIds;
      if (ids.isEmpty) return false;

      final idx = intent.index;
      if (idx == null) {
        final count = ids.length >= 2 ? 2 : 1;
        reg.requestDisambiguation(
          count: count,
          onChosen: (i) {
            _executeVoiceIntent(VoiceIntent(
              action: intent.action,
              target: intent.target,
              index: i,
              value: intent.value,
              confidence: intent.confidence,
            ));
          },
        );
        return true;
      }

      if (intent.action == 'like') {
        if (enableVerboseLogs) Loggers.success('[VOICE] execute like feed_post index=$idx');
        reg.likeFeedPostByIndex(idx);
        return true;
      }
      if (intent.action == 'comment') {
        if (enableVerboseLogs) Loggers.success('[VOICE] execute comment feed_post index=$idx');
        reg.commentFeedPostByIndex(idx);
        return true;
      }
      if (intent.action == 'report') {
        if (enableVerboseLogs) Loggers.success('[VOICE] execute report feed_post index=$idx');
        reg.reportFeedPostByIndex(idx);
        return true;
      }
    }

    // Report sheet intents
    if (intent.target == 'report_reason') {
      if (!Get.isRegistered<ReportSheetController>()) return false;
      final c = Get.find<ReportSheetController>();

      if (intent.index != null) {
        final i = intent.index ?? 0;
        if (i >= 0 && i < c.reports.length) {
          c.selectedValue.value = c.reports[i];
        }
        return true;
      }

      final v = (intent.value ?? '').trim().toLowerCase();
      if (v.isNotEmpty) {
        for (final e in c.reports) {
          final t = (e.title ?? '').toLowerCase();
          if (t.isNotEmpty && t.contains(v)) {
            c.selectedValue.value = e;
            return true;
          }
        }
      }

      if (c.reports.length >= 2) {
        final max = c.reports.length >= 3 ? 3 : 2;
        VoiceUiActionRegistry.instance.requestDisambiguation(
          count: max,
          onChosen: (i) {
            if (i >= 0 && i < c.reports.length) {
              c.selectedValue.value = c.reports[i];
            }
          },
        );
        return true;
      }
    }

    if (intent.target == 'report_description') {
      if (!Get.isRegistered<ReportSheetController>()) return false;
      final c = Get.find<ReportSheetController>();

      if (intent.action == 'stop_typing') {
        _dictationTarget = _DictationTarget.none;
        return true;
      }

      if (intent.action == 'type') {
        _dictationTarget = _DictationTarget.reportDescription;
        final v = (intent.value ?? '').trim();
        if (v.isNotEmpty) {
          _appendToController(c.descriptionController, v);
        }
        return true;
      }
    }

    if (intent.target == 'report_sheet' && intent.action == 'submit') {
      if (!Get.isRegistered<ReportSheetController>()) return false;
      final c = Get.find<ReportSheetController>();
      if (enableVerboseLogs) Loggers.success('[VOICE] execute submit report_sheet');
      c.onReportSubmit();
      _dictationTarget = _DictationTarget.none;
      return true;
    }

    if (enableVerboseLogs) {
      Loggers.info('[VOICE] intent not executed (no handler): ${intent.toJson()}');
    }
    return false;
  }

  bool _handleReportSheetCommands(String cmd) {
    if (!Get.isRegistered<ReportSheetController>()) return false;
    final c = Get.find<ReportSheetController>();

    // Exit dictation
    if (cmd.contains('stop typing') || cmd.contains('typing band') || cmd.contains('लिखना बंद')) {
      _dictationTarget = _DictationTarget.none;
      return true;
    }

    // Submit
    if (cmd.contains('submit') || cmd.contains('ससबमिट') || cmd.contains('सबमिट')) {
      c.onReportSubmit();
      _dictationTarget = _DictationTarget.none;
      return true;
    }

    // Select reason
    if (cmd.contains('reason') || cmd.contains('कारण') || cmd.contains('reason select')) {
      final idx = _extractIndex(cmd);
      if (idx != null) {
        final i = idx;
        if (i >= 0 && i < c.reports.length) {
          c.selectedValue.value = c.reports[i];
        }
        return true;
      }

      final after = _afterKeywords(cmd, const ['reason', 'कारण']);
      if (after.isNotEmpty) {
        for (final e in c.reports) {
          final t = (e.title ?? '').toLowerCase();
          if (t.isNotEmpty && t.contains(after)) {
            c.selectedValue.value = e;
            return true;
          }
        }
      }

      // If user said just "reason", show quick chooser
      if (c.reports.length >= 2) {
        final max = c.reports.length >= 3 ? 3 : 2;
        VoiceUiActionRegistry.instance.requestDisambiguation(
          count: max,
          onChosen: (i) {
            if (i >= 0 && i < c.reports.length) {
              c.selectedValue.value = c.reports[i];
            }
          },
        );
      }
      return true;
    }

    // Start description dictation
    if (cmd.contains('description') || cmd.contains('विवरण') || cmd.contains('discription') || cmd.contains('likh') || cmd.contains('लिख')) {
      _dictationTarget = _DictationTarget.reportDescription;
      final after = _afterKeywords(cmd, const ['description', 'विवरण', 'discription', 'likh', 'लिख']);
      if (after.isNotEmpty) {
        _appendToController(c.descriptionController, after);
      }
      return true;
    }

    // If dictation active, append anything else
    if (_dictationTarget == _DictationTarget.reportDescription) {
      if (cmd.isNotEmpty) {
        _appendToController(c.descriptionController, cmd);
        return true;
      }
    }

    return false;
  }

  static int? _extractIndex(String cmd) {
    if (cmd.contains('first') || cmd.contains('pehli') || cmd.contains('पहली') || cmd.contains('1')) {
      return 0;
    }
    if (cmd.contains('second') || cmd.contains('dusri') || cmd.contains('दूसरी') || cmd.contains('2')) {
      return 1;
    }
    if (cmd.contains('third') || cmd.contains('teesri') || cmd.contains('तीसरी') || cmd.contains('3')) {
      return 2;
    }
    return null;
  }

  static String _afterKeywords(String cmd, List<String> keywords) {
    final lower = cmd.toLowerCase();
    for (final k in keywords) {
      final kk = k.toLowerCase();
      final idx = lower.indexOf(kk);
      if (idx >= 0) {
        final out = lower.substring(idx + kk.length).trim();
        if (out.isNotEmpty) return out;
      }
    }
    return '';
  }

  static void _appendToController(TextEditingController c, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final existing = c.text.trim();
    c.text = existing.isEmpty ? t : '$existing $t';
    c.selection = TextSelection.fromPosition(TextPosition(offset: c.text.length));
  }

  bool _handleFeedPostActions(String cmd) {
    final reg = VoiceUiActionRegistry.instance;
    final ids = reg.feedPostIds;
    if (ids.isEmpty) return false;

    final wantsLike = cmd.contains('like') || cmd.contains('heart') || cmd.contains('लाइक');
    final wantsComment = cmd.contains('comment') || cmd.contains('कमेंट') || cmd.contains('टिप्पणी');
    final wantsReport = cmd.contains('report') || cmd.contains('रिपोर्ट');

    if (!wantsLike && !wantsComment && !wantsReport) return false;

    final index = reg.resolveFeedIndexFromCmd(cmd);
    if (index == null) {
      final count = ids.length >= 2 ? 2 : 1;
      reg.requestDisambiguation(
        count: count,
        onChosen: (i) {
          if (wantsLike) {
            reg.likeFeedPostByIndex(i);
          } else if (wantsComment) {
            reg.commentFeedPostByIndex(i);
          } else if (wantsReport) {
            reg.reportFeedPostByIndex(i);
          }
        },
      );
      return true;
    }

    if (wantsLike) {
      reg.likeFeedPostByIndex(index);
      return true;
    }
    if (wantsComment) {
      reg.commentFeedPostByIndex(index);
      return true;
    }
    if (wantsReport) {
      reg.reportFeedPostByIndex(index);
      return true;
    }

    return false;
  }

  static _VoiceAction? _matchCommand(String cmd) {
    if (cmd.isEmpty) return null;

    // Profile
    if (cmd.contains('profile') || cmd.contains('प्रोफाइल')) {
      return const _VoiceAction(_VoiceActionType.feature, 'profile');
    }

    // Chat / Messages
    if (cmd.contains('chat') || cmd.contains('message') || cmd.contains('messages')) {
      return const _VoiceAction(_VoiceActionType.feature, 'chat');
    }

    // Search
    if (cmd.contains('search') || cmd.contains('खोज')) {
      return const _VoiceAction(_VoiceActionType.feature, 'search');
    }

    // Live
    if (cmd.contains('go live') || cmd.contains('live') || cmd.contains('लाइव')) {
      return const _VoiceAction(_VoiceActionType.feature, 'live');
    }

    // Feed / Home
    if (cmd.contains('feed') || cmd.contains('home')) {
      return const _VoiceAction(_VoiceActionType.feature, 'feed');
    }

    // Reels
    if (cmd.contains('reel') || cmd.contains('reels')) {
      return const _VoiceAction(_VoiceActionType.feature, 'reels');
    }

    // Wallet / Earnings
    if (cmd.contains('wallet') || cmd.contains('earning') || cmd.contains('earnings') || cmd.contains('कमाई')) {
      return const _VoiceAction(_VoiceActionType.wallet, 'wallet');
    }

    // Upload
    if (cmd.contains('upload') || cmd.contains('post') || cmd.contains('video')) {
      return const _VoiceAction(_VoiceActionType.upload, 'upload');
    }

    return null;
  }
}

enum _VoiceActionType { feature, wallet, upload }

enum _DictationTarget { none, reportDescription }

class _VoiceAction {
  final _VoiceActionType type;
  final String payload;

  const _VoiceAction(this.type, this.payload);
}
