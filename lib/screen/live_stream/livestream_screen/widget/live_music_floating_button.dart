import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_music_player_sheet.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LiveMusicFloatingButton extends StatefulWidget {
  final LivestreamScreenController controller;

  const LiveMusicFloatingButton({
    super.key,
    required this.controller,
  });

  @override
  State<LiveMusicFloatingButton> createState() => _LiveMusicFloatingButtonState();
}

class _LiveMusicFloatingButtonState extends State<LiveMusicFloatingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _syncAnim(bool playing) {
    if (playing) {
      if (!_anim.isAnimating) {
        _anim.repeat();
      }
    } else {
      if (_anim.isAnimating) {
        _anim.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = widget.controller.isLiveMusicEnabled;
      if (!enabled) return const SizedBox();

      final playing = widget.controller.isLiveMusicPlaying;
      _syncAnim(playing);

      return GestureDetector(
        onTap: () {
          Get.bottomSheet(
            LiveMusicPlayerSheet(controller: widget.controller),
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            enableDrag: true,
          );
        },
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: blackPure(context).withValues(alpha: .35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: whitePure(context).withValues(alpha: .12),
            ),
          ),
          child: Center(
            child: RotationTransition(
              turns: _anim,
              child: Image.asset(
                AssetRes.icMusic,
                height: 22,
                width: 22,
                color: whitePure(context),
              ),
            ),
          ),
        ),
      );
    });
  }
}
