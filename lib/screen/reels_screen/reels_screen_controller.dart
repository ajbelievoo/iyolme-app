import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/service/admob_native_service.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/video_cache_helper/video_cache_helper.dart';
import 'package:shortzz/model/admob/admob_native_models.dart';
import 'package:shortzz/model/post_story/comment/fetch_comment_model.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/screen/comment_sheet/helper/comment_helper.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:shortzz/screen/home_screen/home_screen_controller.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:shortzz/screen/report_sheet/report_sheet.dart';
import 'package:shortzz/screen/scratch_collect/scratch_collect_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:video_player/video_player.dart';

class ReelsScreenController extends BaseController {
  static const tag = 'REEL';
  RxBool isVideoDisposing = false.obs;

  static const int _minWatchSecondsForReward = 15;
  static const int _watchTickMs = 1000;  // Reduced from 500ms to 1000ms to save battery
  final Map<int, Timer> _watchTimers = <int, Timer>{};
  final Map<int, int> _watchedMs = <int, int>{};
  final Set<int> _viewRewardedPostIds = <int>{};
  final Set<int> _failedInitIndices = <int>{};
  int _currentlyPlayingIndex = -1;

  DashboardScreenController dashboardController =
  Get.find<DashboardScreenController>();

  HomeScreenController homeScreenController = Get.find<HomeScreenController>();
  
  // Scratch & Collect controller for tracking progress
  ScratchCollectController? _scratchCollectController;
  
  ScratchCollectController get scratchCollectController {
    _scratchCollectController ??= Get.put(ScratchCollectController(), permanent: true);
    return _scratchCollectController!;
  }

  final RxDouble previousPosition = 0.0.obs;

  RxMap<int, VideoPlayerController> videoControllers =
      <int, VideoPlayerController>{}.obs;

  RxList<Post> reels = <Post>[].obs;
  RxList<FeedItem> feedItems = <FeedItem>[].obs;
  
  // AdMob native ad service
  final AdMobNativeService _adMobService = AdMobNativeService.instance;
  int _admobAdCounter = 0;

  RxInt position = 0.obs;
  Rx<TabType> selectedReelCategory = TabType.values.first.obs;
  PageController pageController = PageController();
  CommentHelper commentHelper = CommentHelper();
  Future<void> Function()? onFetchMoreData;
  Future<void> Function()? onRefresh;
  Function(int postId)? onLikeAction;
  Function(int postId)? onViewAction;
  Function(int postId)? onCommentAction;
  bool isHomePage;
  bool isFromTask;  // Flag for task flow - enables 15-sec delay
  String? taskType; // Task type for conditional logic

  ReelsScreenController(
      {required this.reels,
        required this.position,
        required this.onFetchMoreData,
        this.onRefresh,
        this.onLikeAction,
        this.onViewAction,
        this.onCommentAction,
        required this.isHomePage,
        this.isFromTask = false,  // Default false for normal flow
        this.taskType});

  // FIXED: Track scratch card position and state
  final RxInt _scratchCardIndex = (-1).obs;
  final RxBool _isViewingScratchCard = false.obs;
  
  /// Check if scroll should be allowed - ALWAYS true now
  bool get canScroll => true;

  static String _makePrewarmTag() => 'REEL_PREWARM_${DateTime.now().millisecondsSinceEpoch}';

  static Future<String> prewarm({
    required RxList<Post> reels,
    required int position,
    Future<void> Function()? onFetchMoreData,
    Future<void> Function()? onRefresh,
    Function(int postId)? onLikeAction,
    Function(int postId)? onViewAction,
    Function(int postId)? onCommentAction,
    required bool isHomePage,
    bool isFromTask = false,
    String? taskType,
    String? controllerTag,
  }) async {
    final tagToUse = isHomePage ? ReelsScreenController.tag : (controllerTag ?? _makePrewarmTag());
    if (Get.isRegistered<ReelsScreenController>(tag: tagToUse)) {
      final existing = Get.find<ReelsScreenController>(tag: tagToUse);
      await existing.prewarmFirstReel(atIndex: position);
      return tagToUse;
    }

    final controller = Get.put(
      ReelsScreenController(
        reels: reels,
        position: position.obs,
        onFetchMoreData: onFetchMoreData,
        onRefresh: onRefresh,
        onLikeAction: onLikeAction,
        onViewAction: onViewAction,
        onCommentAction: onCommentAction,
        isHomePage: isHomePage,
        isFromTask: isFromTask,
        taskType: taskType,
      ),
      tag: tagToUse,
    );
    await controller.prewarmFirstReel(atIndex: position);
    return tagToUse;
  }

  Future<void> prewarmFirstReel({required int atIndex}) async {
    if (reels.isEmpty) return;
    final idx = atIndex.clamp(0, reels.length - 1);
    // Warm the poster thumbnails for the first reels so the placeholder is
    // instant while the video initializes.
    for (int i = idx; i <= idx + 2 && i < reels.length; i++) {
      _precacheThumbnail(reels[i]);
    }
    await _initializeControllerAtIndex(idx);
    final vc = videoControllers[idx];
    if (vc != null && vc.value.isInitialized) {
      final rawMp4 = (reels[idx].video ?? '').trim();
      final mp4Url = rawMp4.isNotEmpty ? rawMp4.addBaseURL() : '';
      if (mp4Url.isNotEmpty) {
        final lower = mp4Url.toLowerCase();
        final isMp4 = lower.endsWith('.mp4') || lower.contains('.mp4?');
        if (isMp4) {
          VideoCacheHelper.enqueueDownload(mp4Url);
        }
      }
    }
  }

  void _precacheThumbnail(Post reel) {
    final url = reel.getThumbnail.trim();
    if (url.isEmpty) return;
    DefaultCacheManager()
        .getSingleFile(url.addBaseURL())
        .then((_) {})
        .catchError((_) {});
  }

  void startIfNeeded() {
    // Start video player if not already started
    if (reels.isNotEmpty) {
      initVideoPlayer();
    }
  }

  void ensureControllerAtIndex(int index) {
    if (index < 0 || index >= reels.length) return;
    if (_failedInitIndices.contains(index)) return;
    if (videoControllers.containsKey(index)) return;
    _initializeControllerAtIndex(index);
  }

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: position.value);
    
    // Initialize feed items with AdMob ads
    ever(reels, (_) {
      _buildFeedItems();
    });
    _buildFeedItems();
    
    if (isHomePage) {
      _setupDashboardController();
    }
    if (!isHomePage) {
      initVideoPlayer();
    }
  }

  @override
  void onClose() {
    // Clear all AdMob ads
    _adMobService.clearAllAds();
    disposeAllController();
    super.onClose();
  }

  void _setupDashboardController() {
    dashboardController.onBottomIndexChanged = (index) {
      if (index == 0) {
        videoControllers[position.value]?.play();
      } else {
        videoControllers[position.value]?.pause();
      }
    };
  }

  Future<void> _fetchMoreData() async {
    if (position >= reels.length - 3) {
      await onFetchMoreData?.call();
      _initializeControllerAtIndex(position.value + 1);
    }
  }

  void onReportTap() {
    Get.bottomSheet(
        ReportSheet(
            reportType: ReportType.post, id: reels[position.value].id?.toInt()),
        isScrollControlled: true);
  }

  Future<void> initVideoPlayer() async {
    /// Initialize 1st video
    await _initializeControllerAtIndex(position.value);

    /// Play 1st video
    _playControllerAtIndex(position.value);

    /// Initialize 2nd vide
    if (position >= 0) {
      await _initializeControllerAtIndex(position.value - 1);
    }
    await _initializeControllerAtIndex(position.value + 1);
  }

  void _playNextReel(int index) {
    // Check if next item is an ad - don't play video if it is
    if (index >= 0 && index < feedItems.length) {
      final nextItem = feedItems[index];
      if (nextItem.isAdMobNative || nextItem.isBackendAd || nextItem.isScratchCard) {
        // Stop previous video but don't play new one (it's an ad)
        _stopControllerAtIndex(index - 1);
        _disposeControllerAtIndex(index - 2);
        Loggers.info('[REELS_DEBUG] Skipping video play - next item is ${nextItem.type.name}');
        return;
      }
    }
    
    _stopControllerAtIndex(index - 1);
    _disposeControllerAtIndex(index - 2);
    _playControllerAtIndex(index);
    _initializeControllerAtIndex(index + 1);
  }

  void _playPreviousReel(int index) {
    // Check if previous item is an ad - don't play video if it is
    if (index >= 0 && index < feedItems.length) {
      final prevItem = feedItems[index];
      if (prevItem.isAdMobNative || prevItem.isBackendAd || prevItem.isScratchCard) {
        // Stop next video but don't play new one (it's an ad)
        _stopControllerAtIndex(index + 1);
        _disposeControllerAtIndex(index + 2);
        Loggers.info('[REELS_DEBUG] Skipping video play - previous item is ${prevItem.type.name}');
        return;
      }
    }
    
    _stopControllerAtIndex(index + 1);
    _disposeControllerAtIndex(index + 2);
    _playControllerAtIndex(index);
    _initializeControllerAtIndex(index - 1);
  }

  Future _initializeControllerAtIndex(int index) async {
    if (index < 0 || index >= reels.length) {
      Loggers.error('🚫 Invalid index: $index, Reels Length: ${reels.length}');
      return;
    }

    if (_failedInitIndices.contains(index)) {
      return;
    }
    
    if (videoControllers.containsKey(index)) {
      return;
    }

    await _doInitializeControllerAtIndex(index);
  }
  
  Future _doInitializeControllerAtIndex(int index) async {

    _precacheThumbnail(reels[index]);

    final VideoPlayerController controller;
    String? videoUrl;
    String? hlsUrl;

    if (reels.first.id == -1) {
      controller = VideoPlayerController.file(File(reels.first.video ?? ''));
    } else {
      // Check for HLS first (better streaming), fallback to MP4
      hlsUrl = reels[index].videoHls?.addBaseURL();
      videoUrl = reels[index].video?.addBaseURL();

      if ((hlsUrl?.isEmpty ?? true) && (videoUrl?.isEmpty ?? true)) {
        Loggers.error('Video URL not found!!!');
        return;
      }

      // Prefer HLS if available, otherwise use MP4
      final urlToUse = (hlsUrl?.isNotEmpty ?? false) ? hlsUrl! : videoUrl!;
      Loggers.info('🎬 Using ${hlsUrl?.isNotEmpty ?? false ? "HLS" : "MP4"} for reel $index: $urlToUse');

      controller = await getVideoPlayerController(
        urlToUse,
        prefetch: index != position.value,
      );
    }

    /// Add to [controllers] list
    videoControllers[index] = controller;

    /// Initialize
    try {
      await controller.initialize().timeout(const Duration(seconds: 10));  // Reduced timeout
      Loggers.info('🚀🚀🚀 INITIALIZED $index');
      _failedInitIndices.remove(index);
    } catch (e) {
      // If HLS failed, try MP4 fallback
      if (hlsUrl?.isNotEmpty ?? false) {
        Loggers.warning('🟠 HLS failed for reel $index, trying MP4 fallback: $e');
        try {
          await controller.dispose();
        } catch (_) {}
        videoControllers.remove(index);

        if (videoUrl?.isNotEmpty ?? false) {
          try {
            final fallbackController = await getVideoPlayerController(
              videoUrl!,
              prefetch: index != position.value,
            );
            videoControllers[index] = fallbackController;
            await fallbackController.initialize().timeout(const Duration(seconds: 8));  // Reduced timeout for fallback
            Loggers.success('✅ MP4 fallback initialized for reel $index');
            _failedInitIndices.remove(index);
            return;
          } catch (e2) {
            Loggers.error('❌ MP4 fallback also failed for reel $index: $e2');
            videoControllers.remove(index);
          }
        }
      }

      Loggers.error('❌ Video init failed at index=$index url=${hlsUrl ?? videoUrl}: $e');
      try {
        await controller.dispose();
      } catch (_) {}
      videoControllers.remove(index);
      _failedInitIndices.add(index);
    }
  }

  Future<VideoPlayerController> getVideoPlayerController(
      String videoUrl, {required bool prefetch}) async {
    final cached = await VideoCacheHelper.getValidCachedVideo(videoUrl);
    VideoPlayerController controller;

    if (cached != null) {
      controller = VideoPlayerController.file(cached.file);
    } else {
      // Add proper HTTP headers for CDN access
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36',
        'Accept': '*/*',
        'Accept-Encoding': 'identity;q=1, *;q=0',
        'Referer': 'https://hitune.in/',
      };
      
      controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: headers,
      );
      
      if (prefetch) {
        VideoCacheHelper.enqueueDownload(videoUrl);
      }
    }

    return controller;
  }

  Future<void> _playControllerAtIndex(int index) async {
    if (dashboardController.selectedPageIndex.value != 0 && isHomePage) return;
    if (index < 0 || index >= reels.length) return;
    
    // Already playing this index
    if (_currentlyPlayingIndex == index) return;
    
    // End watch time for previous reel if any
    if (_currentlyPlayingIndex >= 0 && _currentlyPlayingIndex != index) {
      final prevReel = reels[_currentlyPlayingIndex];
      scratchCollectController.endReelWatch(prevReel.id?.toInt() ?? 0);
    }
    
    _currentlyPlayingIndex = index;
    
    // Stop others first
    _hardPauseAndMuteAllExcept(index);
    
    // Check if initialized
    var controller = videoControllers[index];
    if (controller == null || !controller.value.isInitialized) {
      // Try to init first
      await _initializeControllerAtIndex(index);
      controller = videoControllers[index];
    }
    
    if (controller != null && controller.value.isInitialized) {
      controller.setLooping(true);
      controller.setVolume(1);
      controller.play();
      _startWatchGate(index);
      
      // Start watch time tracking for this reel
      final currentReel = reels[index];
      scratchCollectController.startReelWatch(currentReel.id?.toInt() ?? 0);
      
      Loggers.info('🚀🚀🚀 PLAYING $index');
    }
  }

  void _startWatchGate(int index) {
    _cancelWatchGate(index);

    final post = (index >= 0 && index < reels.length) ? reels[index] : null;
    final postId = post?.id?.toInt() ?? -1;
    if (postId == -1) return;

    final controllerTag = postId.toString();
    final reelController = Get.isRegistered<ReelController>(tag: controllerTag) 
        ? Get.find<ReelController>(tag: controllerTag) 
        : null;
    
    // ALWAYS disable all actions initially for ALL reels (15 sec delay)
    if (reelController != null) {
      reelController.disableAllActionsForTask();
      Loggers.info('[WATCH_GATE] Disabled actions for post $postId - 15 sec delay active');
    }

    _watchedMs[index] = 0;
    _watchTimers[index] = Timer.periodic(const Duration(milliseconds: _watchTickMs), (t) {
      // Stop if index is no longer current
      if (position.value != index) {
        _cancelWatchGate(index);
        return;
      }

      final vc = videoControllers[index];
      if (vc == null || !vc.value.isInitialized) {
        _cancelWatchGate(index);
        return;
      }

      // Avoid extra work while buffering; it can cause jank on low-end devices.
      if (vc.value.isBuffering) {
        return;
      }

      if (vc.value.isPlaying) {
        _watchedMs[index] = (_watchedMs[index] ?? 0) + _watchTickMs;
      }

      final watched = _watchedMs[index] ?? 0;
      final durationMs = vc.value.duration.inMilliseconds;
      final requiredMs = (durationMs > 0 && durationMs < _minWatchSecondsForReward * 1000)
          ? durationMs
          : _minWatchSecondsForReward * 1000;

      final posMs = vc.value.position.inMilliseconds;
      final bool isAtEnd = (durationMs > 0) && (posMs >= durationMs - 250);
      final bool isVideoShort = durationMs > 0 && durationMs < _minWatchSecondsForReward * 1000;

      // Enable actions after 15 seconds OR when short video ends (for ALL reels)
      if (reelController != null) {
        if (watched >= requiredMs || (isVideoShort && isAtEnd)) {
          reelController.enableAllActions();
          Loggers.info('[WATCH_GATE] Enabled all actions for post $postId after ${watched}ms watch');
          
          // Reward view only once per post per session
          if (!_viewRewardedPostIds.contains(postId)) {
            _viewRewardedPostIds.add(postId);
            _increaseViewsCount(post);
          }
          
          _cancelWatchGate(index);
        }
      }
    });
  }

  void _cancelWatchGate(int index) {
    final timer = _watchTimers.remove(index);
    timer?.cancel();
    _watchedMs.remove(index);
  }

  void _increaseViewsCount(Post? post) async {
    if (post == null || post.id == null) {
      return Loggers.error('Post not found or ID is null');
    }

    final postId = post.id ?? -1;
    if (postId == -1) {
      return Loggers.error('Post ID $postId not found in reels');
    }

    final reelIndex = reels.indexWhere((element) => element.id == postId);
    if (reelIndex == -1) {
      return Loggers.error('Post ID $postId not found in reels');
    }

    final response =
    await PostService.instance.increaseViewsCount(postId: postId);

    if (response.status == true) {
      // Loggers.info('🚀 INCREASE VIEWS COUNT SUCCESSFUL');
      final controllerTag = postId.toString();
      if (Get.isRegistered<ReelController>(tag: controllerTag)) {
        Get.find<ReelController>(tag: controllerTag)
            .updateReelData(reel: post, isIncreaseCoin: true);
      }
      
      // Call task callback for view action
      onViewAction?.call(postId);
      
      // REMOVED: Duplicate incrementReelsWatched call - now only called in _tryShowScratchCardOnScroll
      // This was causing double counting of reels watched
    }
  }

  void _stopControllerAtIndex(int index) {
    if (reels.length > index && index >= 0) {
      _cancelWatchGate(index);
      final controller = videoControllers[index];
      if (controller != null) {
        controller.setVolume(0);
        controller.pause();
        controller.seekTo(Duration.zero);
        Loggers.info('🚀🚀🚀 STOPPED $index');
      }
    }
  }

  void _hardPauseAndMuteAllExcept(int currentIndex) {
    final keys = videoControllers.keys.toList(growable: false);
    for (final k in keys) {
      final c = videoControllers[k];
      if (c == null) continue;
      if (k == currentIndex) {
        c.setLooping(true);
        c.setVolume(1);
        if (!c.value.isPlaying) c.play();
        continue;
      }
      c.setVolume(0);
      c.pause();
      c.seekTo(Duration.zero);
    }
  }

  void _disposeControllerAtIndex(int index) {
    if (reels.length > index && index >= 0) {
      _cancelWatchGate(index);
      final VideoPlayerController? controller = videoControllers[index];
      if (controller != null) {
        try {
          controller.dispose();
        } catch (_) {}
        videoControllers.remove(index);
        Loggers.info('🚀🚀🚀 DISPOSED $index');
      }
    }
  }

  Future<void> disposeAllController() async {
    final controllersToDispose = videoControllers.values
        .toList(); // clone to avoid concurrent modification
    videoControllers
        .clear(); // clear early to prevent usage during async dispose

    for (final t in _watchTimers.values) {
      t.cancel();
    }
    _watchTimers.clear();
    _watchedMs.clear();

    for (var controller in controllersToDispose) {
      try {
        if (controller.value.isInitialized) {
          await controller.pause(); // Optional: pause before disposing
        }
        await controller.dispose();
      } catch (e) {
        Loggers.error('❌ Failed to dispose controller: $e');
      }
    }
  }

  /// Called when page changes - handles video playback and ad visibility
  Future<void> onPageChanged(int index) async {
    commentHelper.detectableTextFocusNode.unfocus();
    commentHelper.detectableTextController.clear();
    
    final previous = position.value;
    position.value = index;
    
    // Get current feed item type
    if (index >= 0 && index < feedItems.length) {
      final currentItem = feedItems[index];
      
      // Pause all videos when viewing ads or scratch cards
      if (currentItem.isAdMobNative || currentItem.isBackendAd || currentItem.isScratchCard) {
        _hardPauseAndMuteAllExcept(-1); // Pause all
        Loggers.info('[REELS_DEBUG] Paused all videos - viewing ${currentItem.type.name} at index $index');
      } else if (currentItem.isPost) {
        // Regular reel - handle normally
        _hardPauseAndMuteAllExcept(index);
      }
    }
    
    if (index > previous) {
      _fetchMoreData();
      
      // FIXED: Only play next reel if current item is a real post, not an ad
      final currentItem = feedItems[index];
      if (currentItem.isPost) {
        _playNextReel(index);
      } else {
        // For ads/scratch cards, just stop the previous video
        _stopControllerAtIndex(index - 1);
        _disposeControllerAtIndex(index - 2);
        Loggers.info('[REELS_DEBUG] Skipped _playNextReel for ${currentItem.type.name} at index $index');
      }
      
      // FIXED: Record scroll speed for dynamic scratch card frequency
      scratchCollectController.recordScrollEvent();
      
      // FIXED: Check if we just scrolled to the scratch card
      if (index == _scratchCardIndex.value) {
        _isViewingScratchCard.value = true;
        // Pause the previous reel (if any)
        if (previous >= 0 && previous < videoControllers.length) {
          final prevController = videoControllers[previous];
          if (prevController != null && prevController.value.isInitialized) {
            prevController.pause();
          }
        }
        Loggers.info('[REELS_DEBUG] Now viewing scratch card at $index, scroll blocked');
      }
      
      // Track scratch & collect progress on reel scroll (only for real reels)
      _tryShowScratchCardOnScroll(index);
    } else {
      // FIXED: Only play previous reel if current item is a real post, not an ad
      final currentItem = feedItems[index];
      if (currentItem.isPost) {
        _playPreviousReel(index);
      } else {
        // For ads/scratch cards, just stop the next video
        _stopControllerAtIndex(index + 1);
        _disposeControllerAtIndex(index + 2);
        Loggers.info('[REELS_DEBUG] Skipped _playPreviousReel for ${currentItem.type.name} at index $index');
      }
      
      // FIXED: If scrolling back from scratch card, allow scroll again
      if (previous == _scratchCardIndex.value) {
        _isViewingScratchCard.value = false;
      }
    }
  }
  
  // FIXED: New user priority - Backend cards first, then algorithm
  // Algorithm: Check for backend pending cards first, then use earned cards
  void _tryShowScratchCardOnScroll(int currentIndex) {
    final scratchController = scratchCollectController;
    
    // FIXED: Only count actual reels, not ads or scratch cards
    if (currentIndex < 0 || currentIndex >= feedItems.length) return;
    
    final currentItem = feedItems[currentIndex];
    
    // Skip if current item is not a real reel (ad, scratch card, etc.)
    if (!currentItem.isPost) {
      Loggers.info('[REELS_DEBUG] Skipping increment - not a real reel (type: ${currentItem.type.name})');
      return;
    }
    
    // DEBUG: Check current state
    Loggers.info('[REELS_DEBUG] _tryShowScratchCardOnScroll: reelsWatched=${scratchController.reelsWatched.value}, minReels=${scratchController.minReelsForScratch}, backendCards=${scratchController.backendScratchCards.value}, earnedCards=${scratchController.scratchCardsAvailable.value}');
    
    // PRIORITY 1: Check if backend has pending cards (admin added)
    if (scratchController.hasBackendScratchCards) {
      Loggers.info('[REELS_DEBUG] PRIORITY: Backend card available - inserting immediately');
      _insertScratchCardInFeed(isBackendCard: true);
      scratchController.decrementBackendScratchCards();
      return; // Don't count this reel, backend card shown
    }
    
    // PRIORITY 2: Use earned/algorithm cards
    scratchController.incrementReelsWatched();
    
    // DEBUG: Check after increment
    Loggers.info('[REELS_DEBUG] After increment: reelsWatched=${scratchController.reelsWatched.value}, earnedCards=${scratchController.scratchCardsAvailable.value}');
    
    // If algorithm earned card is available, INSERT INLINE
    if (scratchController.hasScratchCardsAvailable) {
      Loggers.info('[REELS_DEBUG] ALGORITHM CARD EARNED - inserting in feed');
      _insertScratchCardInFeed(isBackendCard: false);
      scratchController.decrementScratchCards();
    }
  }
  
  /// Insert scratch card inline in reels feed (like ads)
  /// [isBackendCard] - true if from admin/backend, false if algorithm earned
  void _insertScratchCardInFeed({bool isBackendCard = false}) {
    final currentPos = position.value;
    final items = feedItems.toList();
    final scratchCardIndex = currentPos + 1;
    
    // Insert scratch card after current reel
    items.insert(scratchCardIndex, FeedItem.scratchCard());
    feedItems.value = items;
    
    // FIXED: Store scratch card index for tracking
    _scratchCardIndex.value = scratchCardIndex;
    
    final cardType = isBackendCard ? 'BACKEND (ADMIN)' : 'ALGORITHM (EARNED)';
    Loggers.info('[REELS_DEBUG] Inserted $cardType scratch card at position $scratchCardIndex');
    
    // NO AUTO-SCROLL - Let user scroll naturally to scratch card
  }

  void onUpdateComment(Comment comment, bool isReplyComment) {
    final post = reels.firstWhereOrNull((e) => e.id == comment.postId);
    if (post == null) {
      return Loggers.error('Post not found');
    }
    final controllerTag = post.id.toString();
    if (Get.isRegistered<ReelController>(tag: controllerTag)) {
      Get.find<ReelController>(tag: controllerTag)
          .reelData
          .update((val) => val?.updateCommentCount(1));
    }
    
    // Call task callback for comment action
    final postId = post.id?.toInt();
    if (postId != null) {
      onCommentAction?.call(postId);
    }
  }

  Future<void> onRefreshPage(List<Post> reels) async {
    if (reels.isEmpty) {
      return;
    }
    if (onRefresh != null) {
      position.value = 0;

      if (pageController.hasClients) {
        pageController.jumpToPage(position.value);
      }

      String videoUrl = reels[position.value].video?.addBaseURL() ?? '';
      String hlsUrl = reels[position.value].videoHls?.addBaseURL() ?? '';
      
      // Prefer HLS if available
      final urlToUse = hlsUrl.isNotEmpty ? hlsUrl : videoUrl;
      if (urlToUse.isEmpty) {
        Loggers.error('❌ Video URL not found on refresh!');
        return;
      }
      
      Loggers.info('🎬 Refresh using ${hlsUrl.isNotEmpty ? "HLS" : "MP4"}: $urlToUse');

      final VideoPlayerController controller =
      await getVideoPlayerController(urlToUse, prefetch: false);
      try {
        await controller.initialize().timeout(const Duration(seconds: 10));  // Reduced timeout
      } catch (e) {
        Loggers.error('❌ Video init failed on refresh url=$videoUrl: $e');
        try {
          await controller.dispose();
        } catch (_) {}
        return;
      }

      // Step 2: Dispose old controllers not needed anymore
      disposeAllController();
      videoControllers[position.value] = controller;

      /// Play 1st video
      _playControllerAtIndex(position.value);
      await _initializeControllerAtIndex(position.value + 1);
    }
  }

  /// Pause current playing video (used by scratch card)
  void pauseCurrentVideo() {
    if (_currentlyPlayingIndex >= 0 && _currentlyPlayingIndex < videoControllers.length) {
      final controller = videoControllers[_currentlyPlayingIndex];
      if (controller != null && controller.value.isInitialized) {
        controller.pause();
        controller.setVolume(0);
        Loggers.info('[REELS_DEBUG] Video paused for scratch card at index $_currentlyPlayingIndex');
      }
    }
  }
  
  /// Resume current video (used after scratch card closes)
  void resumeCurrentVideo() {
    if (_currentlyPlayingIndex >= 0 && _currentlyPlayingIndex < videoControllers.length) {
      final controller = videoControllers[_currentlyPlayingIndex];
      if (controller != null && controller.value.isInitialized) {
        controller.play();
        controller.setVolume(1);
        Loggers.info('[REELS_DEBUG] Video resumed after scratch card at index $_currentlyPlayingIndex');
      }
    }
  }

  /// Build feed items with AdMob native ads inserted
  void _buildFeedItems() {
    final List<FeedItem> items = [];
    int postCount = 0;
    _admobAdCounter = 0;
    
    Loggers.info('[REELS_DEBUG] Starting _buildFeedItems. reels.length=${reels.length}, isEnabled=${_adMobService.isEnabled}, interval=${_adMobService.config.value.adInterval}');
    
    for (int i = 0; i < reels.length; i++) {
      final reel = reels[i];
      
      // If it's a backend ad, add it as-is
      if (reel.isAd) {
        items.add(FeedItem.backendAd(reel));
        postCount = 0;
        continue;
      }
      
      // Add regular post
      items.add(FeedItem.post(reel));
      postCount++;
      
      // Check if we should insert an AdMob ad after this post
      if (_shouldInsertAdMobAd(postCount, items.length - 1)) {
        _admobAdCounter++;
        items.add(FeedItem.adMobNative(_admobAdCounter));
        postCount = 0;
        
        Loggers.info('[REELS_DEBUG] Inserting AdMob ad #$_admobAdCounter at position ${items.length - 1}');
        
        // Preload this ad
        _preloadAdMobAd(_admobAdCounter);
      }
    }
    
    feedItems.value = items;
    Loggers.info('[REELS_DEBUG] Built feed items: ${items.length} total (${reels.length} posts + $_admobAdCounter AdMob ads). FeedItem types: ${items.map((i) => i.type.name).toList()}');
  }
  
  /// Remove scratch card from feed after completion
  void removeScratchCardFromFeed(int index) {
    if (index >= 0 && index < feedItems.length) {
      final items = feedItems.toList();
      items.removeAt(index);
      feedItems.value = items;
      Loggers.info('[REELS_DEBUG] Removed scratch card from feed at index $index');
      
      // FIXED: Clear scratch card tracking
      _scratchCardIndex.value = -1;
      _isViewingScratchCard.value = false;
      
      // FIXED: Resume the reel before the scratch card (user will land there)
      final reelIndex = index - 1;
      if (reelIndex >= 0 && reelIndex < videoControllers.length) {
        final controller = videoControllers[reelIndex];
        if (controller != null && controller.value.isInitialized) {
          controller.play();
          Loggers.info('[REELS_DEBUG] Resumed reel $reelIndex after scratch card');
        }
      }
      
      // Reset scroll tracking since user completed scratch card
      scratchCollectController.resetScrollTracking();
    }
  }

  /// Check if we should insert an AdMob ad
  bool _shouldInsertAdMobAd(int postsSinceLastAd, int currentIndex) {
    // Don't show if AdMob is disabled
    if (!_adMobService.isEnabled) {
      Loggers.info('[REELS_DEBUG] _shouldInsertAdMobAd: DISABLED (isEnabled=false)');
      return false;
    }
    
    final interval = _adMobService.config.value.adInterval;
    if (interval <= 0) {
      Loggers.info('[REELS_DEBUG] _shouldInsertAdMobAd: DISABLED (interval=$interval)');
      return false;
    }
    
    final shouldInsert = postsSinceLastAd >= interval;
    Loggers.info('[REELS_DEBUG] _shouldInsertAdMobAd: postsSinceLastAd=$postsSinceLastAd, interval=$interval, shouldInsert=$shouldInsert');
    
    return shouldInsert;
  }
  
  /// Preload an AdMob ad
  void _preloadAdMobAd(int adIndex) {
    Future.delayed(const Duration(milliseconds: 500), () {
      _adMobService.loadNativeAd(adIndex);
    });
  }
  
  /// Update feed items when reels change
  void updateFeedItems() {
    _buildFeedItems();
  }
  
  /// Called when new reels are fetched
  void onReelsUpdated() {
    _buildFeedItems();
    // Preload ads for the first few positions
    _preloadUpcomingAds();
  }
  
  /// Preload ads for upcoming positions
  void _preloadUpcomingAds() {
    if (!_adMobService.isEnabled) return;
    
    int adsPreloaded = 0;
    int postCount = 0;
    
    for (int i = 0; i < feedItems.length && adsPreloaded < 3; i++) {
      final item = feedItems[i];
      
      if (item.isPost) {
        postCount++;
      } else if (item.isAdMobNative) {
        postCount = 0;
      }
      
      // Check if next position should have an ad
      if (item.isPost && _shouldInsertAdMobAd(postCount, i)) {
        final adIndex = _admobAdCounter + adsPreloaded + 1;
        _preloadAdMobAd(adIndex);
        adsPreloaded++;
      }
    }
  }
}
