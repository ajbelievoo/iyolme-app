import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/manager/share_manager.dart';
import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/api/platform_ads_service.dart';
import 'package:shortzz/common/service/api/boost_service.dart';
import 'package:shortzz/model/platform_ads/platform_ads_model.dart';
import 'package:shortzz/common/service/location/location_service.dart';
import 'package:shortzz/common/service/navigation/navigate_with_controller.dart';
import 'package:shortzz/model/general/place_detail.dart';
import 'package:shortzz/model/post_story/post_by_id.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/post_screen/single_post_screen.dart';
import 'package:shortzz/screen/reels_screen/reels_screen.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/utilities/app_res.dart';

class HomeScreenController extends BaseController with GetSingleTickerProviderStateMixin {
  Rx<TabType> selectedReelCategory = TabType.values.first.obs;
  RxList<Post> reels = <Post>[].obs;
  RxBool endOfFeed = false.obs;
  final RxList<PlatformAd> _platformAds = <PlatformAd>[].obs;
  final RxList<Post> _boostedPosts = <Post>[].obs;
  late AnimationController controller;
  late Animation<double> animation;
  RxBool isAnimateTab = false.obs;
  StreamSubscription<Map>? streamSubscription;
  CancelToken token = CancelToken();
  bool _isDisposed = false;

  Rx<User?> get myUser => Rx(SessionManager.instance.getUser());

  @override
  void onInit() {
    controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    animation = CurvedAnimation(parent: controller, curve: Curves.linear);

    // Call both methods concurrently
    Future.wait([
      onRefreshPage(),
      _onNotificationTap(),
      _fetchLocation(),
      _readDeepLink(),
    ]);

    super.onInit();
  }

  @override
  void onReady() {
    isLoading.value = true;
    super.onReady();
  }

  @override
  void onClose() {
    _isDisposed = true;
    super.onClose();
    controller.dispose();
    streamSubscription?.cancel();
  }

  Future<void> _onNotificationTap() async {
    if (Platform.isIOS) {
      // Handle the iOS notification payload once
      final payload = FirebaseNotificationManager.instance.notificationPayload.value;
      if (payload.isNotEmpty) {
        FirebaseNotificationManager.instance.handleNotification(payload);
      }
    } else {
      // Set up a listener to handle future payload changes
      // Android: Get the message if the app was opened via notification
      RemoteMessage? message = await FirebaseMessaging.instance.getInitialMessage();

      if (message != null) {
        await FirebaseNotificationManager.instance.handleNotification(jsonEncode(message.toMap()));
      }
    }

    FirebaseNotificationManager.instance.notificationPayload.listen((p0) {
      if (p0.isNotEmpty) {
        FirebaseNotificationManager.instance.handleNotification(p0);
      }
    });
  }

  Future<void> _readDeepLink() async {
    ShareManager.shared.listen((key, value) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (key == ShareKeys.post.value) {
        PostByIdModel model = await PostService.instance.fetchPostById(postId: value);
        if (model.status == true) {
          Post? post = model.data?.post;
          if (post != null) {
            await Get.to(() => SinglePostScreen(post: post, isFromNotification: true), preventDuplicates: false);
          }
        }
      } else if (key == ShareKeys.reel.value) {
        PostByIdModel model = await PostService.instance.fetchPostById(postId: value);
        if (model.status == true) {
          Post? post = model.data?.post;
          if (post != null) {
            final tag = await ReelsScreenController.prewarm(
              reels: [post].obs,
              position: 0,
              isHomePage: false,
            );
            await Get.to(
              () => ReelsScreen(reels: [post].obs, position: 0, controllerTag: tag),
              preventDuplicates: false,
            );
          }
        }
      } else if (key == ShareKeys.user.value) {
        User? user = await UserService.instance.fetchUserDetails(userId: value);
        if (user != null) {
          await NavigationService.shared.openProfileScreen(user);
        }
      }
    });
  }

  Future<void> onRefreshPage({bool reset = true}) async {
    if (reset) {
      isLoading.value = true;
      endOfFeed.value = false;
    }
    // Fetch ads/boosted posts in the BACKGROUND — they must not block the
    // reel feed. If an ad API hangs, reels would never load on cold start.
    unawaited(_fetchPlatformAds());
    unawaited(_fetchBoostedPosts());
    try {
      switch (selectedReelCategory.value) {
        case TabType.discover:
          await fetchDiscoverPost(reset);
          break;
        case TabType.following:
          await _fetchFollowingPost(reset);
          break;
        case TabType.nearby:
          try {
            await _fetchPostsNearBy(reset);
          } catch (e) {
            selectedReelCategory.value = TabType.discover;
          }
          break;
      }
    } catch (e) {
      isLoading.value = false;
      Loggers.error('onRefreshPage failed: $e');
    }
  }

  onTabTypeChanged(TabType tabType) async {
    onAnimationBack();
    if (selectedReelCategory.value == tabType) {
      return;
    }
    selectedReelCategory.value = tabType;
    await onRefreshPage.call(reset: true);
  }

  onToggleDropDown() {
    if (_isDisposed) return;
    if (animation.status != AnimationStatus.completed) {
      controller.forward();
      isAnimateTab.value = true;
    } else {
      onAnimationBack();
    }
  }

  onAnimationBack() {
    isAnimateTab.value = false;
    controller.animateBack(0, duration: const Duration(milliseconds: 250), curve: Curves.linear);
  }

  Future<void> fetchDiscoverPost(bool resetData) async {
    isLoading.value = true;
    Loggers.info('HomeScreenController: fetchDiscoverPost(reset=$resetData)');
    try {
      List<Post> newPosts = await PostService.instance.fetchPostsDiscover(
          type: PostType.reels,
          cancelToken: token,
          lastItemId: resetData ? null : reels.lastOrNull?.id);
      Loggers.info('HomeScreenController: Received ${newPosts.length} reels');
      addResponseData(newPosts, resetData);
      if (!resetData && newPosts.isEmpty) {
        endOfFeed.value = true;
      }
    } catch (e) {
      isLoading.value = false;
      Loggers.error('Fetch Discover Post Error: $e');
      // Cold-start calls can race auth/network readiness — retry once.
      if (resetData && !_isDisposed) {
        await Future.delayed(const Duration(seconds: 2));
        if (_isDisposed) return;
        try {
          isLoading.value = true;
          Loggers.info('fetchDiscoverPost: retrying after failure...');
          final retry = await PostService.instance.fetchPostsDiscover(
              type: PostType.reels, cancelToken: token);
          addResponseData(retry, true);
        } catch (e2) {
          Loggers.error('Fetch Discover Post retry failed: $e2');
        }
      }
    }
  }

  Future<void> _fetchFollowingPost(bool resetData) async {
    isLoading.value = true;
    List<Post> newPosts = await PostService.instance.fetchPostsFollowing(
        type: PostType.reels,
        cancelToken: token,
        lastItemId: resetData ? null : reels.lastOrNull?.id);

    addResponseData(newPosts, resetData);
  }

  Future<void> _fetchPostsNearBy(bool resetData) async {
    isLoading.value = true;
    Position position = await LocationService.instance.getCurrentLocation(isPermissionDialogShow: true);
    List<Post> newPosts = await PostService.instance.fetchPostsNearBy(
        type: PostType.reels,
        placeLat: position.latitude,
        placeLon: position.longitude,
        cancelToken: token,
        lastItemId: resetData ? null : reels.lastOrNull?.id);
    addResponseData(newPosts, resetData);
  }

  void addResponseData(List<Post> newPosts, bool resetData) {
    if (resetData) {
      reels.clear();
      if (Get.isRegistered<ReelsScreenController>(tag: ReelsScreenController.tag)) {
        var controller = Get.find<ReelsScreenController>(tag: ReelsScreenController.tag);
        controller.onRefreshPage(newPosts);
      }
      endOfFeed.value = false;
    }

    // Inject ads and boosted posts into the reels list
    List<Post> dataToAdd = newPosts;
    final totalSponsored = _platformAds.length + _boostedPosts.length;

    if (totalSponsored > 0 && newPosts.isNotEmpty) {
      dataToAdd = [];
      int adIndex = 0;
      int boostIndex = 0;
      int injectionCount = 0;

      for (int i = 0; i < newPosts.length; i++) {
        dataToAdd.add(newPosts[i]);

        // Inject sponsored content every 5 reels
        if ((i + 1) % 5 == 0) {
          bool injected = false;

          // Strategy: Alternate between Platform Ads and Boosted Posts
          if (injectionCount % 2 == 0) {
            // Priority: Platform Ad
            if (_platformAds.isNotEmpty) {
              final ad = _platformAds[adIndex % _platformAds.length];
              dataToAdd.add(_convertAdToPost(ad));
              adIndex++;
              injected = true;
            } else if (_boostedPosts.isNotEmpty) {
              final p = _boostedPosts[boostIndex % _boostedPosts.length];
              p.feedItemType = 'ad';
              p.isSponsored = true;
              p.sponsoredLabel = 'Sponsored';
              dataToAdd.add(p);
              boostIndex++;
              injected = true;
            }
          } else {
            // Priority: Boosted Post
            if (_boostedPosts.isNotEmpty) {
              final p = _boostedPosts[boostIndex % _boostedPosts.length];
              p.feedItemType = 'ad';
              p.isSponsored = true;
              p.sponsoredLabel = 'Sponsored';
              dataToAdd.add(p);
              boostIndex++;
              injected = true;
            } else if (_platformAds.isNotEmpty) {
              final ad = _platformAds[adIndex % _platformAds.length];
              dataToAdd.add(_convertAdToPost(ad));
              adIndex++;
              injected = true;
            }
          }

          if (injected) injectionCount++;
        }
      }
    }

    if (dataToAdd.isNotEmpty) {
      reels.addAll(dataToAdd);
    }

    if (newPosts.isEmpty && !resetData) {
      endOfFeed.value = true;
    }
    isLoading.value = false;
  }

  Future<void> _fetchLocation() async {
    PlaceDetail? detail;
    try {
      detail = await CommonService.instance.getIPPlaceDetail();
    } catch (e) {
      Loggers.error('Location error : $e');
    }

    if (detail != null) {
      UserService.instance
          .updateUserDetails(region: detail.region, regionName: detail.regionName, timezone: detail.timezone);
    }
  }

  Future<void> _fetchPlatformAds() async {
    try {
      Loggers.info('[_fetchPlatformAds] Starting fetch for reels...');
      final ads = await PlatformAdsService.instance.fetchPlatformAds(placement: 'reels');
      _platformAds.assignAll(ads);
      Loggers.info('[_fetchPlatformAds] SUCCESS: Fetched ${_platformAds.length} platform ads for reels');
      if (_platformAds.isEmpty) {
        Loggers.warning('[_fetchPlatformAds] No platform ads returned from backend!');
      } else {
        for (int i = 0; i < _platformAds.length; i++) {
          final ad = _platformAds[i];
          Loggers.info('[_fetchPlatformAds] Ad $i: id=${ad.id}, title=${ad.title}, placement=${ad.placement}');
        }
      }
    } catch (e) {
      Loggers.error('[_fetchPlatformAds] ERROR: Failed to fetch platform ads for reels: $e');
    }
  }

  Future<void> _fetchBoostedPosts() async {
    try {
      Loggers.info('[_fetchBoostedPosts] Starting fetch for reels...');
      final posts = await BoostService.instance.fetchBoostedPosts(placement: 'reels');
      _boostedPosts.assignAll(posts);
      Loggers.info('[_fetchBoostedPosts] SUCCESS: Fetched ${_boostedPosts.length} boosted posts for reels');
      if (_boostedPosts.isEmpty) {
        Loggers.warning('[_fetchBoostedPosts] No boosted posts returned from backend!');
      } else {
        for (int i = 0; i < _boostedPosts.length; i++) {
          final post = _boostedPosts[i];
          Loggers.info('[_fetchBoostedPosts] Post $i: id=${post.id}, type=${post.feedItemType}');
        }
      }
    } catch (e) {
      Loggers.error('[_fetchBoostedPosts] ERROR: Failed to fetch boosted posts for reels: $e');
    }
  }

  Post _convertAdToPost(PlatformAd ad) {
    return Post(
      id: -1 * (ad.id ?? 0),
      feedItemType: 'ad',
      postType: PostType.image,
      description: ad.title,
      thumbnail: ad.thumbnailUrl ?? ad.mediaUrl,
      userId: 0,
    )
      ..isSponsored = true
      ..sponsoredAdId = ad.id
      ..sponsoredCta = ad.cta
      ..sponsoredLabel = 'Sponsored'
      ..sponsoredUrl = ad.destinationUrl;
  }
}
