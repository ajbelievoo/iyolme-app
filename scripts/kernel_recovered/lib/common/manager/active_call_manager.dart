import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/model/livestream/livestream.dart';

class ActiveCallManager {
  ActiveCallManager._();
  static final ActiveCallManager instance = ActiveCallManager._();

  Room? room;
  Livestream? livestream;
  String? callId;
  String? url;
  String? token;
  bool isAudio = true;

  bool minimized = false;
  OverlayEntry? _overlay;
  StreamSubscription<DocumentSnapshot>? _callDocSub;
  VoidCallback? onOpenCall;
  VoidCallback? onCleanup;
  DateTime? startedAt;
  bool micEnabled = true;

  bool get isActive => room != null && callId != null;

  void bindSession({
    required Room room,
    required Livestream livestream,
    required String callId,
    required bool isAudio,
    String? url,
    String? token,
  }) {
    this.room = room;
    this.livestream = livestream;
    this.callId = callId;
    this.isAudio = isAudio;
    if (url != null) this.url = url;
    if (token != null) this.token = token;
    _listenCallDoc();
  }

  void updateCredentials({String? url, String? token}) {
    if (url != null) this.url = url;
    if (token != null) this.token = token;
  }

  void setStartedAt(DateTime? startedAt) {
    this.startedAt = startedAt;
  }

  void setMicEnabled(bool enabled) {
    micEnabled = enabled;
  }

  Future<void> toggleMic() async {
    final r = room;
    if (r == null) return;
    final lp = r.localParticipant;
    if (lp == null) return;
    final newEnabled = !micEnabled;
    await lp.setMicrophoneEnabled(newEnabled);
    micEnabled = newEnabled;
  }

  String durationText() {
    final s = startedAt;
    if (s == null) return '00:00';
    final diff = DateTime.now().difference(s);
    String two(int n) => n.toString().padLeft(2, '0');
    if (diff.inHours > 0) {
      return '${two(diff.inHours)}:${two(diff.inMinutes.remainder(60))}:${two(diff.inSeconds.remainder(60))}';
    }
    return '${two(diff.inMinutes.remainder(60))}:${two(diff.inSeconds.remainder(60))}';
  }

  void _listenCallDoc() {
    final id = callId;
    if (id == null || !id.startsWith('call_')) return;
    _callDocSub?.cancel();
    _callDocSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(id)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      final status = data?['status'];
      if (status == null) return;
      if (status != 'ringing' && status != 'accepted') {
        await endSession(updateFirestore: false);
      }
    });
  }

  void showOverlay([BuildContext? context]) {
    if (!isActive) return;
    if (_overlay != null) return;
    minimized = true;

    final OverlayState? overlayState =
        context != null ? Overlay.of(context, rootOverlay: true) : null;
    final ctx = overlayState?.context ?? Get.overlayContext;
    if (ctx == null) return;

    _overlay = OverlayEntry(
      builder: (_) => _ActiveCallOverlay(
        onOpen: () {
          hideOverlay();
          minimized = false;
          onOpenCall?.call();
        },
        onEnd: () async {
          await endSession(updateFirestore: true);
        },
      ),
    );
    (overlayState ?? Overlay.of(ctx, rootOverlay: true)).insert(_overlay!);
  }

  void hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Future<void> endSession({required bool updateFirestore}) async {
    final id = callId;
    final r = room;
    if (id == null || r == null) return;

    hideOverlay();
    minimized = false;

    if (updateFirestore) {
      try {
        final myId = SessionManager.instance.getUser()?.id;
        if (myId != null) {
          final snap = await FirebaseFirestore.instance
              .collection('calls')
              .doc(id)
              .get();
          final data = snap.data();
          if (data != null) {
            final status = data['status'];
            final acceptedAtRaw = data['acceptedAt'];
            final hasAccepted =
                status == 'accepted' || acceptedAtRaw is Timestamp;

            String endedBy = 'unknown';
            final callerIdRaw = data['callerId'];
            final receiverIdRaw = data['receiverId'];
            final callerId = callerIdRaw is num ? callerIdRaw.toInt() : null;
            final receiverId =
                receiverIdRaw is num ? receiverIdRaw.toInt() : null;
            if (callerId != null && myId == callerId) endedBy = 'caller';
            if (receiverId != null && myId == receiverId) endedBy = 'receiver';

            await FirebaseFirestore.instance
                .collection('calls')
                .doc(id)
                .update({
              'status': hasAccepted ? 'ended' : 'missed',
              'endedAt': FieldValue.serverTimestamp(),
              'endedBy': endedBy,
              'endReason': 'minimized_end',
            });
          }
        }
      } catch (_) {}
    }

    try {
      await r.disconnect();
    } catch (_) {}
    try {
      onCleanup?.call();
    } catch (_) {}
    onCleanup = null;
    _callDocSub?.cancel();
    _callDocSub = null;
    room = null;
    livestream = null;
    callId = null;
    url = null;
    token = null;
    startedAt = null;
    micEnabled = true;
  }
}

class _ActiveCallOverlay extends StatefulWidget {
  final VoidCallback onOpen;
  final Future<void> Function() onEnd;

  const _ActiveCallOverlay({required this.onOpen, required this.onEnd});

  @override
  State<_ActiveCallOverlay> createState() => _ActiveCallOverlayState();
}

class _ActiveCallOverlayState extends State<_ActiveCallOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callId = ActiveCallManager.instance.callId ?? '';
    final title = callId.isNotEmpty ? 'Call Running' : 'Call';
    final duration = ActiveCallManager.instance.durationText();
    final micEnabled = ActiveCallManager.instance.micEnabled;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onOpen,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.call, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$title • $duration',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () async {
                    await ActiveCallManager.instance.toggleMic();
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      micEnabled ? Icons.mic : Icons.mic_off,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () async {
                    await widget.onEnd();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'End',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
