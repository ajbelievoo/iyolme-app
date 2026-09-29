import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:proste_indexed_stack/proste_indexed_stack.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/widget/gradient_border.dart';
import 'package:shortzz/common/widget/gradient_icon.dart';
import 'package:shortzz/common/widget/smart_action_card.dart';
import 'package:shortzz/common/controller/smart_assist_controller.dart';
import 'package:shortzz/common/service/smart_assist/voice_command_service.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:shortzz/screen/explore_screen/explore_screen.dart';
import 'package:shortzz/screen/feed_screen/feed_screen.dart';
import 'package:shortzz/screen/home_screen/home_screen.dart';
import 'package:shortzz/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
import 'package:shortzz/screen/message_screen/message_screen.dart';
import 'package:shortzz/screen/profile_screen/profile_screen.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class DashboardScreen extends StatefulWidget {
  final User? myUser;

  const DashboardScreen({super.key, this.myUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late final DashboardScreenController controller;
  late final SmartAssistController smartCtrl;
  Worker? _voiceWorker;

  Future<bool> _onWillPop() async {
    if (controller.selectedPageIndex.value != 0) {
      controller.onChanged(0);
      return false;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exit'),
          content: const Text('Do you want to exit the app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      if (Platform.isAndroid) {
        SystemNavigator.pop();
        return false;
      }
      return true;
    }
    return false;
  }

  bool get _isResumed {
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    controller = Get.put(DashboardScreenController(), permanent: true);
    smartCtrl = Get.isRegistered<SmartAssistController>()
        ? Get.find<SmartAssistController>()
        : Get.put(SmartAssistController(), permanent: true);

    _voiceWorker = everAll(
      [smartCtrl.smartSuggestionsEnabled, smartCtrl.voiceCommandsEnabled],
      (_) => _syncVoiceLoop(),
    );
    _syncVoiceLoop();
  }

  Future<void> _syncVoiceLoop() async {
    // Debug wiring for Smart Suggestions → VoiceCommandService
    // This log will confirm when sync is actually invoked and what flags are.
    Loggers.info(
        '[VOICE][dash] _syncVoiceLoop isResumed=$_isResumed smartSuggestions=${smartCtrl.smartSuggestionsEnabled.value} voiceCmd=${smartCtrl.voiceCommandsEnabled.value}');
    // ignore: avoid_print
    Loggers.info(
        '[VOICE][dash] _syncVoiceLoop isResumed=$_isResumed smartSuggestions=${smartCtrl.smartSuggestionsEnabled.value} voiceCmd=${smartCtrl.voiceCommandsEnabled.value}');

    if (!_isResumed) {
      await VoiceCommandService.instance.stopForegroundLoop();
      return;
    }

    // Wake listening runs only when Smart Suggestions are enabled.
    // Actual commands execute only after wake-phrase turns Voice Commands ON.
    if (smartCtrl.isSmartSuggestionsActive) {
      Loggers.info('[VOICE][dash] starting foreground loop');
      // ignore: avoid_print
      Loggers.info('[VOICE][dash] starting foreground loop');
      await VoiceCommandService.instance.startForegroundLoop(
        onFeatureCommand: controller.onVoiceFeatureCommand,
      );
    } else {
      Loggers.info(
          '[VOICE][dash] stopping foreground loop (Smart Suggestions OFF)');
      // ignore: avoid_print
      Loggers.info('[VOICE][dash] stopping foreground loop (Smart Suggestions OFF)');
      await VoiceCommandService.instance.stopForegroundLoop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Loggers.info('[VOICE][dash] lifecycle changed: $state');
    // ignore: avoid_print
    Loggers.info('[VOICE][dash] lifecycle changed: $state');
    if (state == AppLifecycleState.resumed) {
      controller.onAppResumed();
      _syncVoiceLoop();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      VoiceCommandService.instance.stopForegroundLoop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceWorker?.dispose();
    VoiceCommandService.instance.stopForegroundLoop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: scaffoldBackgroundColor(context),
        resizeToAvoidBottomInset: true,
        body: Obx(() {
          final suggestion = controller.smartSuggestion.value;
          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ProsteIndexedStack(
                      index: controller.selectedPageIndex.value,
                      children: [
                        IndexedStackChild(
                            child: const HomeScreen(), preload: true),
                        IndexedStackChild(
                            child: FeedScreen(myUser: widget.myUser),
                            preload: true),
                        IndexedStackChild(
                            child: const LiveStreamSearchScreen(),
                            preload: false),
                        IndexedStackChild(
                            child: const ExploreScreen(), preload: true),
                        IndexedStackChild(
                            child: const MessageScreen(), preload: false),
                        IndexedStackChild(
                            child: ProfileScreen(
                                isDashBoard: true,
                                user: widget.myUser,
                                isTopBarVisible: false),
                            preload: true)
                      ],
                    ),
                  ),
                ],
              ),
              if (suggestion != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 90,
                  child: SmartActionCard(
                    title: 'Quick access',
                    actionLabel: _labelForFeature(suggestion.feature),
                    onAction: controller.onSmartSuggestionExecuted,
                    onDismiss: controller.onSmartSuggestionDismiss,
                  ),
                ),
            ],
          );
        }),
        bottomNavigationBar: _buildBottomNavigationBar(context, controller),
      ),
    );
  }

  static String _labelForFeature(String feature) {
    switch (feature) {
      case 'profile':
        return 'Profile';
      case 'chat':
        return 'Messages';
      case 'search':
        return 'Search';
      case 'live':
        return 'Go Live';
      case 'feed':
        return 'Feed';
      case 'reels':
        return 'Reels';
      case 'add':
        return 'Create Post';
      default:
        return 'Open';
    }
  }

  Widget _buildBottomNavigationBar(
      BuildContext context, DashboardScreenController controller) {
    return Obx(() {
      PostUploadingProgress postUpload = controller.postProgress.value;
      bool isPostUploading =
          postUpload.uploadType == UploadType.none ? false : true;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: blackPure(context),
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                controller.bottomIconList.length,
                (index) {
                  return _buildBottomNavItem(
                      context, controller, index, isPostUploading);
                },
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: isPostUploading ? 30 : 0,
              margin: Platform.isAndroid || !isPostUploading
                  ? EdgeInsets.zero
                  : const EdgeInsets.only(bottom: 20, top: 5),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                      height: 30,
                      decoration:
                          BoxDecoration(gradient: StyleRes.themeGradient)),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: LayoutBuilder(builder: (context, constraints) {
                      double progress =
                          (constraints.maxWidth * postUpload.progress) / 100;
                      return AnimatedContainer(
                        height: 30,
                        width: constraints.maxWidth - progress,
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(color: textDarkGrey(context)),
                      );
                    }),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (postUpload.uploadType != UploadType.error)
                          Text('${postUpload.progress.toInt()}%',
                              style: TextStyleCustom.outFitMedium500(
                                color: whitePure(context),
                                fontSize: 16,
                              )),
                        Text(' ${postUpload.uploadType.title(postUpload.type)}',
                            style: TextStyleCustom.outFitLight300(
                                color: whitePure(context), fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      );
    });
  }

  Widget _buildBottomNavItem(BuildContext context,
      DashboardScreenController controller, int index, bool isPostUploading) {
    return Obx(() {
      final isSelected = controller.selectedPageIndex.value == index;
      final scaleValue = isSelected ? controller.scaleValue.value : 1.0;
      final isHighlighted =
          controller.smartHighlightIndex.value == index && !isSelected;

      return SafeArea(
        bottom: isPostUploading ? false : true,
        child: GradientBorder(
          onPressed: () => controller.onChanged(index),
          strokeWidth: isSelected ? 2 : 0,
          radius: 30,
          gradient: isSelected ? StyleRes.themeGradient : null,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: AnimatedScale(
              scale: scaleValue,
              duration: const Duration(milliseconds: 300),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    opacity: isHighlighted ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.96, end: 1.04),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: themeAccentSolid(context)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Add button uses Flutter icon, others use image asset
                  GradientIcon(
                          gradient: isSelected
                              ? null
                              : StyleRes.textDarkGreyGradient(),
                          child: Image.asset(controller.bottomIconList[index],
                              height: 38, width: 38),
                        ),
                  if (index == 4) _buildUnreadCount(controller, context),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildUnreadCount(
      DashboardScreenController controller, BuildContext context) {
    return Obx(() {
      final count = controller.unReadCount.value;
      return count > 0
          ? Text(count > 9 ? '9+' : '$count',
              style: TextStyleCustom.outFitRegular400(
                  color: whitePure(context), fontSize: 12))
          : const SizedBox();
    });
  }
}
