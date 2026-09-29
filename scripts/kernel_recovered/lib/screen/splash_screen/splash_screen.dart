import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/screen/splash_screen/splash_screen_controller.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _videoController;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<SplashScreenController>()) {
      Get.find<SplashScreenController>();
    } else {
      Get.put(SplashScreenController());
    }

    _videoController = VideoPlayerController.asset(
      'assets/video/intro.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      await _videoController.initialize();
      await _videoController.setLooping(false);
      await _videoController.setVolume(1.0);
      _videoController.addListener(() {
        if (_ended) return;
        final value = _videoController.value;
        if (!value.isInitialized) return;
        final duration = value.duration;
        final position = value.position;
        if (duration != Duration.zero && position >= duration) {
          _ended = true;
          _videoController.pause();
          _videoController.seekTo(duration);
          if (mounted) setState(() {});
        }
      });
      await _videoController.play();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // If video fails, controller will still navigate via SplashScreenController.
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialized = _videoController.value.isInitialized;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FAFF),
                    Color(0xFFFFFFFF),
                  ],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: initialized
                  ? FittedBox(
                      key: const ValueKey('video'),
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _videoController.value.size.width,
                        height: _videoController.value.size.height,
                        child: VideoPlayer(_videoController),
                      ),
                    )
                  : Container(
                      key: const ValueKey('placeholder'),
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      alignment: Alignment.center,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
~