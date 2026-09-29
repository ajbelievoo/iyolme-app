import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/battle_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/live_stream_bottom_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/livestream_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/battle_start_countdown_overlay.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_music_floating_button.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_stream_background_blur_image.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:convert';

class LiveKitHostScreen extends StatefulWidget {
  final Livestream livestream;
  final String url;
  final String token;

  const LiveKitHostScreen({
    super.key,
    required this.livestream,
    required this.url,
    required this.token,
  });

  @override
  State<LiveKitHostScreen> createState() => _LiveKitHostScreenState();
}

class _LiveKitHostScreenState extends State<LiveKitHostScreen>
    with WidgetsBindingObserver {
  final Room _room = Room();
  bool _connecting = true;
  bool _camEnabled = true;
  String? _error;
  int _connectAttempt = 0;

  Timer? _arHealthTimer;

  Timer? _speakingPollTimer;
  Timer? _arProviderPollTimer;

  bool _externalVideoProcessingEnabled = false;

  String? _cameraDeviceId;

  int _lastViewerCount = 0;
  final Set<int> _syncedCoHostIds = <int>{};

  late final LivestreamScreenController _controller;

  Worker? _userStateWorker;

  // Prevent subscription flapping (can cause audible glitches).
  final Map<int, bool> _lastRemoteAudioSubDecision = <int, bool>{};

  Future<void> Function()? _unsubEvents;

  Future<void> _syncRemoteAudioSubscriptions() async {
    try {
      final hostId = widget.livestream.hostId ?? 0;
      for (final p in _room.remoteParticipants.values) {
        final userId = int.tryParse(p.identity);
        if (userId == null || userId <= 0) continue;

        final st = _controller.liveUsersStates
            .firstWhereOrNull((e) => e.userId == userId);
        final status = st?.audioStatus;

        bool shouldSubscribe = true;
        if (status != null) {
          shouldSubscribe = status == VideoAudioStatus.on;
        }

        if (_controller.isAudioRoom && !_controller.isUserSeated(userId)) {
          shouldSubscribe = false;
        }

        // Host music should remain audible to everyone regardless of host mic toggle.
        if (userId == hostId && _controller.isLiveMusicEnabled) {
          shouldSubscribe = true;
        }

        final prev = _lastRemoteAudioSubDecision[userId];
        if (prev == shouldSubscribe) {
          continue;
        }
        _lastRemoteAudioSubDecision[userId] = shouldSubscribe;

        for (final pub in p.audioTrackPublications) {
          try {
            if (shouldSubscribe) {
              await pub.subscribe();
            } else {
              await pub.unsubscribe();
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  String? _lastArTrackId;
  String? _lastArParamsHash;

  String? _activeArProvider;
  String? _activeArApiKey;

  String _friendlyConnectError(Object e) {
    if (e is ConnectException) {
      if (e.reason == ConnectionErrorReason.Timeout) {
        return 'Network timeout. Please check your internet and try again.';
      }
      return 'Unable to connect. Please check your internet and try again.';
    }
    if (e is MediaConnectException) {
      return 'Network issue while connecting media. Please try again.';
    }
    if (e is LiveKitException) {
      return 'Unable to join live. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  bool _shouldAutoRetryConnect(Object e) {
    if (_connectAttempt >= 2) return false;
    if (e is ConnectException && e.reason == ConnectionErrorReason.Timeout) {
      return true;
    }
    if (e is MediaConnectException) return true;
    return false;
  }

  Future<void> _resolveArFromSettings({bool refresh = false}) async {
    try {
      if (refresh) {
        try {
          await CommonService.instance
              .fetchGlobalSettings()
              .timeout(const Duration(seconds: 8), onTimeout: () => false);
        } catch (e) {
          Loggers.error('[LIVEKIT] fetchSettings refresh failed: $e');
        }
      }

      final setting = SessionManager.instance.getSettings();
      final engine = (setting?.cameraEngine ?? '').trim().toLowerCase();

      // Map camera_engine -> livekit provider.
      final provider = engine == 'deep_ar' ? 'deepar' : '';

      String? apiKey;
      if (provider == 'deepar') {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          apiKey = setting?.deeparIOSKey;
        } else {
          apiKey = setting?.deeparAndroidKey;
        }
      }

      _activeArProvider = provider;
      _activeArApiKey = apiKey;
    } catch (e) {
      Loggers.error('[LIVEKIT] resolveArFromSettings failed: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = Get.put(
      LivestreamScreenController(
        widget.livestream.obs,
        true,
        bootstrapProvider: false,
      ),
    );

    _userStateWorker = ever<List<LivestreamUserState>>(
      _controller.liveUsersStates,
      (_) {
        _controller.applyLocalAudioGate();
        _syncRemoteAudioSubscriptions();
      },
    );

    _wireControllerCallbacks();
    _connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      try {
        // Keep user in live while minimized (audio should keep working).
        // Disable camera only; microphone publish is controlled by applyLocalAudioGate.
        _controller.livekitSetCameraEnabled?.call(false);
      } catch (_) {}
      return;
    }

    if (state == AppLifecycleState.resumed) {
      Future.microtask(() async {
        try {
          await _controller.applyLocalAudioGate();
        } catch (_) {}
        try {
          await _controller.livekitSetCameraEnabled?.call(_camEnabled);
        } catch (_) {}
        try {
          _syncAllVideoToStreamViews();
        } catch (_) {}
      });
    }
  }

  String _stableJsonEncode(Object? value) {
    Object? normalize(Object? v) {
      if (v is num) {
        return double.parse(v.toDouble().toStringAsFixed(4));
      }
      if (v is Map) {
        final entries = v.entries
            .map((e) => MapEntry(e.key.toString(), normalize(e.value)))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return <String, Object?>{for (final e in entries) e.key: e.value};
      }
      if (v is Iterable) {
        return v.map(normalize).toList(growable: false);
      }
      return v;
    }

    return jsonEncode(normalize(value));
  }

  Future<void> _syncArProviderToLocalTrack({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await _resolveArFromSettings(refresh: true);
      } else {
        await _resolveArFromSettings(refresh: false);
      }

      final lp = _room.localParticipant;
      final localPubs = lp?.videoTrackPublications ?? const [];
      final localVideoPub =
          localPubs.firstWhereOrNull((p) => p.track is LocalVideoTrack);
      final track = localVideoPub?.track;
      if (track is! LocalVideoTrack) {
        Loggers.info('[LIVEKIT] ar-provider skip: no LocalVideoTrack');
        return;
      }

      final provider = (_activeArProvider ?? '').trim().toLowerCase();
      // Allow if settings say so, OR if user manually enabled AR in controller.
      // This prevents the poll from disabling AR if the server setting is lagging or different.
      final shouldAllowExternal =
          provider == 'deepar' || _controller.isArEnabled.value;

      if (!shouldAllowExternal && _externalVideoProcessingEnabled) {
        await Helper.setExternalVideoProcessingEnabled(
          track.mediaStreamTrack,
          false,
        );
        _externalVideoProcessingEnabled = false;
        _lastArTrackId = null;
        _lastArParamsHash = null;
      }
    } catch (e) {
      Loggers.error('[LIVEKIT] syncArProviderToLocalTrack failed: $e');
    }
  }

  void _startArProviderPoll() {
    _arProviderPollTimer?.cancel();
    _arProviderPollTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final prevProvider = _activeArProvider;
        final prevKey = _activeArApiKey;
        await _resolveArFromSettings(refresh: true);
        final nextProvider = _activeArProvider;
        final nextKey = _activeArApiKey;
        final changed = nextProvider != prevProvider || nextKey != prevKey;

        if (changed) {
          await _syncArProviderToLocalTrack(forceRefresh: false);
          await _controller.applyLivekitArSettings();
        }
      } catch (e) {
        Loggers.error('[LIVEKIT] ar-provider poll failed: $e');
      }
    });
  }

  void _startSpeakingPoll() {
    _speakingPollTimer?.cancel();
    _speakingPollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      try {
        final speaking = <dynamic>[];

        final lp = _room.localParticipant;
        if (lp != null) {
          try {
            if ((lp as dynamic).isSpeaking == true) {
              speaking
                  .add((lp as dynamic).identity ?? widget.livestream.hostId);
            }
          } catch (_) {}
        }

        for (final p in _room.remoteParticipants.values) {
          try {
            if ((p as dynamic).isSpeaking == true) {
              speaking.add((p as dynamic).identity);
            }
          } catch (_) {}
        }

        _controller.setSpeakingUsersFromIdentities(speaking);
      } catch (_) {}
    });
  }

  void _syncAllVideoToStreamViews() {
    try {
      final next = <StreamView>[];
      final hostId = (widget.livestream.hostId ?? 0).toString();

      // 1) local host track
      final lp = _room.localParticipant;
      final localPubs = lp?.videoTrackPublications ?? const [];
      final localVideoPub =
          localPubs.firstWhereOrNull((p) => p.track is LocalVideoTrack);
      final VideoTrack? localTrack = localVideoPub?.track as VideoTrack?;
      if (localTrack != null) {
        next.add(StreamView(hostId, -1, _CoverVideoTrack(localTrack), false));
      }

      // 2) remote participants tracks (co-hosts)
      for (final p in _room.remoteParticipants.values) {
        for (final pub in p.videoTrackPublications) {
          final VideoTrack? t = pub.track as VideoTrack?;
          if (t != null) {
            // identity should be numeric userId in our backend token
            next.add(StreamView(p.identity, -1, _CoverVideoTrack(t), false));

            final parsed = int.tryParse(p.identity);
            if (parsed != null &&
                parsed > 0 &&
                !_syncedCoHostIds.contains(parsed)) {
              _syncedCoHostIds.add(parsed);
              _controller.updateLiveStreamData(
                  coHostId: FieldValue.arrayUnion([parsed]));
            }
            break;
          }
        }
      }

      _controller.streamViews.assignAll(next);
    } catch (e) {
      Loggers.error('[LIVEKIT] syncAllVideo failed: $e');
    }
  }

  void _syncViewerCount() {
    // Count everyone in room. remoteParticipants includes audience + cohosts.
    final nextCount = _room.remoteParticipants.length;
    final delta = nextCount - _lastViewerCount;
    if (delta != 0) {
      _lastViewerCount = nextCount;
      _controller.updateLiveStreamData(watchingCount: delta);
    }
  }

  void _wireControllerCallbacks() {
    _controller.livekitSetMicrophoneEnabled = (enabled) async {
      await _room.localParticipant?.setMicrophoneEnabled(enabled);
    };
    _controller.livekitSetCameraEnabled = (enabled) async {
      await _room.localParticipant?.setCameraEnabled(enabled);
      if (mounted) setState(() => _camEnabled = enabled);
      _syncAllVideoToStreamViews();
    };
    _controller.livekitApplyArSettings = (params) async {
      try {
        final lp = _room.localParticipant;
        final localPubs = lp?.videoTrackPublications ?? const [];
        final localVideoPub =
            localPubs.firstWhereOrNull((p) => p.track is LocalVideoTrack);
        final track = localVideoPub?.track;
        if (track is! LocalVideoTrack) {
          Loggers.info('[LIVEKIT] applyArSettings skip: no LocalVideoTrack');
          return;
        }

        const provider = 'deepar';
        final trackId = track.sid;
        final paramsHash = _stableJsonEncode(params);

        if (_lastArTrackId == trackId && _lastArParamsHash == paramsHash) {
          return;
        }
        _lastArTrackId = trackId;
        _lastArParamsHash = paramsHash;

        await Helper.setExternalVideoProcessingProvider(
          track.mediaStreamTrack,
          provider,
          params: params,
        );

        if (!_externalVideoProcessingEnabled) {
          await Helper.setExternalVideoProcessingEnabled(
            track.mediaStreamTrack,
            true,
          );
          _externalVideoProcessingEnabled = true;
        }

        // Health-check logic (optional, keep if useful)
        _arHealthTimer?.cancel();
        _arHealthTimer = null;
      } catch (e) {
        Loggers.error('[LIVEKIT] applyArSettings failed: $e');
      }
    };
    _controller.livekitSwitchCamera = () async {
      try {
        final lp = _room.localParticipant;
        final pubs = lp?.videoTrackPublications ?? const [];
        final videoPub =
            pubs.firstWhereOrNull((p) => p.track is LocalVideoTrack);
        final track = videoPub?.track;
        if (track is! LocalVideoTrack) return;

        final devices = await Hardware.instance.enumerateDevices();
        final videoInputs = devices.where((d) {
          final k = d.kind;
          return k.toString().toLowerCase().contains('videoinput');
        }).toList();
        if (videoInputs.isEmpty) return;

        final currentId = _cameraDeviceId;
        final nextDevice = videoInputs.firstWhereOrNull(
              (d) => currentId != null && d.deviceId != currentId,
            ) ??
            videoInputs.first;

        _cameraDeviceId = nextDevice.deviceId;
        await track.switchCamera(nextDevice.deviceId);
      } catch (e) {
        Loggers.error('[LIVEKIT] switchCamera failed: $e');
      }
    };
    _controller.livekitDisconnect = () async {
      await _room.disconnect();
      // Host screen uses PopScope. Allow programmatic pop.
      _controller.allowRoutePop.value = true;
      if (mounted) Get.back();
    };
  }

  Future<void> _connect() async {
    try {
      _connectAttempt++;
      await WakelockPlus.enable();

      // Avoid duplicate event listeners on retry/reconnect.
      try {
        _unsubEvents?.call();
      } catch (_) {}
      _unsubEvents = null;

      _unsubEvents = _room.events.listen((event) {
        if (event is RoomConnectedEvent) {
          Loggers.info('[LIVEKIT] host connected');
          _syncAllVideoToStreamViews();
          _syncViewerCount();
          _startSpeakingPoll();
          _startArProviderPoll();
          _syncArProviderToLocalTrack(forceRefresh: true);
          // Apply DeepAR/LUT params once local video track is published.
          _controller.applyLivekitArSettings();
          _syncRemoteAudioSubscriptions();
        }
        if (event is RoomDisconnectedEvent) {
          Loggers.info('[LIVEKIT] disconnected reason=${event.reason}');
          _controller.setSpeakingUsersFromIdentities(const []);
          _arProviderPollTimer?.cancel();
          _arProviderPollTimer = null;

          // Reset AR cache so next connect reapplies once.
          _lastArTrackId = null;
          _lastArParamsHash = null;
          _externalVideoProcessingEnabled = false;
        }
        if (event is ParticipantConnectedEvent) {
          _syncAllVideoToStreamViews();
          _syncViewerCount();
        }
        if (event is ParticipantDisconnectedEvent) {
          final parsed = int.tryParse(event.participant.identity);
          if (parsed != null) {
            // Do not remove coHostIds on disconnect.
            // Cohost rights should persist until host explicitly removes/kicks,
            // or the livestream ends.
            _syncedCoHostIds.remove(parsed);

            // If this is an audio-room, free their seat on disconnect (force-exit / app kill).
            try {
              if (_controller.isAudioRoom) {
                _controller.clearSeatForUserLatest(parsed);
              }
            } catch (_) {}
          }
          _syncAllVideoToStreamViews();
          _syncViewerCount();
        }
        if (event is TrackSubscribedEvent || event is TrackUnsubscribedEvent) {
          _syncAllVideoToStreamViews();
          _syncViewerCount();
          _syncRemoteAudioSubscriptions();
        }
      });

      const opts = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      );

      await _room.connect(
        widget.url,
        widget.token,
        roomOptions: opts,
      );

      // Publish mic/camera must respect seat + mic/video status rules.
      // (audio room: mic only when seated + audioStatus ON)
      await _controller.applyLocalAudioGate();
      await _controller.livekitSetCameraEnabled?.call(_camEnabled);

      _syncAllVideoToStreamViews();

      await _syncArProviderToLocalTrack(forceRefresh: true);

      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = null;
        _connectAttempt = 0;
      });
    } catch (e, stackTrace) {
      Loggers.error('[LIVEKIT] host connect failed: $e');
      Loggers.error('[LIVEKIT] host connect stack: $stackTrace');
      if (!mounted) return;

      if (_shouldAutoRetryConnect(e)) {
        Loggers.info(
            '[LIVEKIT] host connect auto-retry attempt=$_connectAttempt');
        try {
          await _room.disconnect();
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        setState(() {
          _connecting = true;
          _error = null;
        });
        await _connect();
        return;
      }

      setState(() {
        _connecting = false;
        _error = _friendlyConnectError(e);
      });
      _controller.showSnackBar('LiveKit connect failed');
    }
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
      _speakingPollTimer?.cancel();
      _arProviderPollTimer?.cancel();
      _arHealthTimer?.cancel();
      _arHealthTimer = null;
      _unsubEvents?.call();
      _room.disconnect();
    } catch (_) {}

    // Best-effort cleanup when host leaves/crashes out of the screen.
    // 1) stop live music so audience doesn't keep hearing stale playback
    // 2) clear seat assignment if this is an audio room
    try {
      Future.microtask(() async {
        try {
          await _controller.stopLiveMusic();
        } catch (_) {}
        try {
          if (_controller.isAudioRoom) {
            await _controller.clearSeatForUserLatest(_controller.myUserId);
          }
        } catch (_) {}
      });
    } catch (_) {}
    _userStateWorker?.dispose();
    WakelockPlus.disable();
    if (Get.isRegistered<LivestreamScreenController>()) {
      Get.delete<LivestreamScreenController>();
    }
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackPure(context),
      resizeToAvoidBottomInset: false,
      body: Obx(
        () => PopScope(
          canPop: _controller.allowRoutePop.value,
          onPopInvoked: (didPop) {
            if (didPop) return;
            if (_controller.allowRoutePop.value) return;
            if (Get.isBottomSheetOpen == true || Get.isDialogOpen == true) {
              return;
            }
            // Back should behave same as exit button (Stop/Exit/Cancel sheet)
            _controller.onExitButtonTap();
          },
          child: _connecting
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error ?? 'Unable to join live.',
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await _room.disconnect();
                                    } catch (_) {}
                                    if (!mounted) return;
                                    setState(() {
                                      _connecting = true;
                                      _error = null;
                                      _connectAttempt = 0;
                                    });
                                    await _connect();
                                  },
                                  child: const Text('Retry'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await _room.disconnect();
                                    } catch (_) {}
                                    _controller.allowRoutePop.value = true;
                                    if (mounted) Get.back();
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        const LiveStreamBlurBackgroundImage(),
                        Obx(() {
                          switch (_controller.liveData.value.type) {
                            case null:
                            case LivestreamType.livestream:
                              return LivestreamView(
                                  streamViews: _controller.streamViews,
                                  controller: _controller);
                            case LivestreamType.battle:
                              return BattleView(
                                  isAudience: false,
                                  controller: _controller,
                                  margin: const EdgeInsets.only(top: 60));
                            case LivestreamType.dummy:
                              return const SizedBox();
                          }
                        }),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LiveStreamHostTopView(controller: _controller),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LiveStreamBottomView(controller: _controller),
                        ),
                        Positioned(
                          top: 70,
                          right: 12,
                          child:
                              LiveMusicFloatingButton(controller: _controller),
                        ),
                        Obx(
                          () {
                            Livestream stream = _controller.liveData.value;
                            bool isBattleWaiting =
                                stream.battleType == BattleType.waiting;
                            if (isBattleWaiting) {
                              return BattleStartCountdownOverlay(
                                  isHost: true, stream: stream);
                            }
                            return const SizedBox();
                          },
                        )
                      ],
                    ),
        ),
      ),
    );
  }
}

class _CoverVideoTrack extends StatelessWidget {
  final VideoTrack track;

  const _CoverVideoTrack(this.track);

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: VideoTrackRenderer(
        track,
        fit: VideoViewFit.cover,
        autoCenter: false,
      ),
    );
  }
}
