import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/location/location_service.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/model/post_story/story/story_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/common/service/api/boost_service.dart';
import 'package:shortzz/common/service/api/platform_ads_service.dart';
import 'package:shortzz/model/platform_ads/platform_ads_model.dart';
import 'package:shortzz/screen/camera_screen/camera_screen.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/screen/story_view_screen/story_view_screen.dart';

class FeedScreenController extends BaseController {
  RxList<Post> posts = RxList();
  RxList<User> stories = RxList();
  Rx<PostCategory> selectedPostCategory = PostCategory.discover.obs;
  ScrollController postScrollController = ScrollController();
  RxBool isStoriesLoading = false.obs;
  RxBool endOfFeed = false.obs;
  Rx<User?> myUser;
  final RxList<PlatformAd> _platformAds = <PlatformAd>[].obs;
  final RxList<Post> _boostedPosts = <Post>[].obs;

  FeedScreenController(this.myUser);

  final GlobalKey<RefreshIndicatorState> refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void onInit() {
    super.onInit();
    initData();
    postScrollController.addListener(_loadMoreData);
  }

  initData() async {
    await Future.wait([
      _fetchStory(),
      _fetchPlatformAds(),
      _fetchBoostedPosts(),
    ]);
    await fetchDiscoverPost();
  }

  Future<void> _fetchPlatformAds() async {
    try {
      Loggers.info('[Feed][_fetchPlatformAds] Starting fetch for feed...');
      final ads = await PlatformAdsService.instance.fetchPlatformAds(placement: 'feed');
      _platformAds.assignAll(ads);
      Loggers.info('[Feed][_fetchPlatformAds] SUCCESS: Fetched ${_platformAds.length} platform ads');
      if (_platformAds.isEmpty) {
        Loggers.warning('[Feed][_fetchPlatformAds] No platform ads returned from backend!');
      } else {
        for (int i = 0; i < _platformAds.length && i < 3; i++) {
          Loggers.info('[Feed][_fetchPlatformAds] Ad $i: id=${_platformAds[i].id}, title=${_platformAds[i].title}');
        }
      }
    } catch (e) {
      Loggers.error('[Feed][_fetchPlatformAds] ERROR: Failed to fetch platform ads: $e');
    }
  }

  Future<void> _fetchBoostedPosts() async {
    try {
      Loggers.info('[Feed][_fetchBoostedPosts] Starting fetch for feed...');
      final posts = await BoostService.instance.fetchBoostedPosts(placement: 'feed');
      _boostedPosts.assignAll(posts);
      Loggers.info('[Feed][_fetchBoostedPosts] SUCCESS: Fetched ${_boostedPosts.length} boosted posts');
      if (_boostedPosts.isEmpty) {
        Loggers.warning('[Feed][_fetchBoostedPosts] No boosted posts returned from backend!');
      } else {
        for (int i = 0; i < _boostedPosts.length && i < 3; i++) {
          Loggers.info('[Feed][_fetchBoostedPosts] Post $i: id=${_boostedPosts[i].id}');
        }
      }
    } catch (e) {
      Loggers.error('[Feed][_fetchBoostedPosts] ERROR: Failed to fetch boosted posts: $e');
    }
  }

  Future<void> _fetchMyUser() async {
    myUser.value = await UserService.instance.fetchUserDetails(
      forceRefresh: true,
    );
  }

  Future<void> _fetchStory({bool isEmpty = false}) async {
    isStoriesLoading.value = true;
    List<User> items = await PostService.instance.fetchStory();
    if (isEmpty) {
      stories.clear();
    }
    stories.addAll(items);
    isStoriesLoading.value = false;
  }

  Future<void> fetchDiscoverPost({bool isEmpty = false}) async {
    if (isLoading.value) return;
    isLoading.value = true;
    Loggers.info('FeedScreenController: fetchDiscoverPost(isEmpty=$isEmpty)');
    try {
      List<Post> post = await PostService.instance.fetchPostsDiscover(
          type: '2,3,4',
          lastItemId: isEmpty ? null : posts.lastOrNull?.id);
      Loggers.info('FeedScreenController: Received ${post.length} posts');
      await _addDataInPostList(post, isEmpty);
      if (!isEmpty && post.isEmpty) {
        endOfFeed.value = true;
      }
    } catch (e) {
      isLoading.value = false;
      Loggers.error('Fetch Feed Post Error: $e');
    }
  }

  Future<void> _fetchPostsFollowing({bool isEmpty = false}) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      List<Post> post =
          await PostService.instance.fetchPostsFollowing(
              type: '2,3,4',
              lastItemId: isEmpty ? null : posts.lastOrNull?.id);
      await _addDataInPostList(post, isEmpty);
      if (!isEmpty && post.isEmpty) {
        endOfFeed.value = true;
      }
    } catch (e) {
      isLoading.value = false;
    }
  }

  Future<void> _fetchPostsNearBy({bool isEmpty = false}) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      Position position = await LocationService.instance
          .getCurrentLocation(isPermissionDialogShow: true);

      List<Post> post = await PostService.instance.fetchPostsNearBy(
          type: '2,3,4',
          placeLat: position.latitude,
          placeLon: position.longitude,
          lastItemId: isEmpty ? null : posts.lastOrNull?.id);

      await _addDataInPostList(post, isEmpty);
      if (!isEmpty && post.isEmpty) {
        endOfFeed.value = true;
      }
    } catch (e) {
      isLoading.value = false;
    }
  }

  Future<void> _addDataInPostList(List<Post> newList, bool isEmpty) async {
    if (isEmpty) {
      posts.clear();
      endOfFeed.value = false;
    }

    List<Post> dataToAdd = newList;
    final totalSponsored = _platformAds.length + _boostedPosts.length;

    if (totalSponsored > 0 && newList.isNotEmpty) {
      dataToAdd = [];
      int adIndex = 0;
      int boostIndex = 0;
      int injectionCount = 0;

      for (int i = 0; i < newList.length; i++) {
        dataToAdd.add(newList[i]);
        
        // Inject sponsored content every 5 posts
        if ((i + 1) % 5 == 0) {
          bool injected = false;
          
          // Strategy: Alternate between Platform Ads and Boosted Posts
          // If injectionCount is even -> Try Platform Ad first
          // If injectionCount is odd -> Try Boosted Post first
          
          if (injectionCount % 2 == 0) {
            // Priority: Platform Ad
            if (_platformAds.isNotEmpty) {
              final ad = _platformAds[adIndex % _platformAds.length];
              dataToAdd.add(_convertAdToPost(ad));
              adIndex++;
              injected = true;
            } else if (_boostedPosts.isNotEmpty) {
              final p = _boostedPosts[boostIndex % _boostedPosts.length];
              // Clone or use as is, ensure sponsored flag
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

    posts.addAll(dataToAdd);
    await Future.delayed(const Duration(milliseconds: 200));
    isLoading.value = false;
  }

  Post _convertAdToPost(PlatformAd ad) {
    return Post(
      id: -1 * (ad.id ?? 0),
      feedItemType: 'ad',
      postType: PostType.image, // Default to image, simpler
      description: ad.title,
      thumbnail: ad.thumbnailUrl ?? ad.mediaUrl,
      userId: 0, // System user
    )
      ..isSponsored = true
      ..sponsoredAdId = ad.id
      ..sponsoredCta = ad.cta
      ..sponsoredLabel = 'Sponsored'
      ..sponsoredUrl = ad.destinationUrl;
  }

  void _removeAndDisposeListener() {
    postScrollController.removeListener(_loadMoreData);
    postScrollController.dispose();
  }

  Future<void> onChangeCategory(PostCategory value) async {
    selectedPostCategory.value = value;
    isLoading.value = false;
    endOfFeed.value = false;
    switch (value) {
      case PostCategory.discover:
        await fetchDiscoverPost(isEmpty: true);
      case PostCategory.nearby:
        try {
          await _fetchPostsNearBy(isEmpty: true);
        } catch (e) {
          selectedPostCategory.value = PostCategory.discover;
          await fetchDiscoverPost(isEmpty: true);
        }
      case PostCategory.following:
        await _fetchPostsFollowing(isEmpty: true);
    }
  }

  Future<void> onRefresh() async {
    await Future.wait([
      _fetchPlatformAds(),
      _fetchBoostedPosts(),
    ]);
    await onChangeCategory(selectedPostCategory.value);
    await _fetchStory(isEmpty: true);
    await _fetchMyUser();
  }

  void onCreateStory() {
    Get.to(() => const CameraScreen(cameraType: CameraScreenType.story));
  }

  void onAddStory(Story? story) {
    if (story == null) return; // Exit early if story is null
    myUser.update((val) {
      val?.stories?.add(story);
    });
  }

  void onWatchStory(List<User> users, int index, String watchType) {
    Get.bottomSheet(
      StoryViewSheet(
        stories: users,
        userIndex: index,
        onUpdateDeleteStory: (story) {
          final userId = story?.userId;
          final storyId = story?.id;

          if (userId == SessionManager.instance.getUserID()) {
            // Update profile screen controller if registered
            if (Get.isRegistered<ProfileScreenController>(
                tag: ProfileScreenController.tag)) {
              final controller = Get.find<ProfileScreenController>(
                  tag: ProfileScreenController.tag);
              controller.userData.update((val) {
                val?.stories?.removeWhere((s) => s.id == storyId);
              });
            }

            // Update current user stories
            myUser.update((val) {
              val?.stories?.removeWhere((s) => s.id == storyId);
            });
          } else {
            // Remove story from other user's list
            final userIndex = stories.indexWhere((u) => u.id == userId);
            if (userIndex != -1) {
              (stories[userIndex].stories ?? [])
                  .removeWhere((s) => s.id == storyId);
            }
          }
        },
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
      useRootNavigator:
          true, // Ensures the BottomSheet is on top of all navigators
    ).then((value) {
      // For check story view or not
      switch (watchType) {
        case 'my_story':
          _fetchMyUser();
          break;
        case 'other_story':
          _fetchStory(isEmpty: true);
      }
    });
  }

  Future<void> _loadMoreData() async {
    if (postScrollController.position.pixels >=
            (postScrollController.position.maxScrollExtent - 300) &&
        !isLoading.value &&
        !endOfFeed.value) {
      switch (selectedPostCategory.value) {
        case PostCategory.discover:
          await fetchDiscoverPost();
        case PostCategory.nearby:
          await _fetchPostsNearBy();
        case PostCategory.following:
          await _fetchPostsFollowing();
      }
    }
  }

  @override
  void onClose() {
    super.onClose();
    _removeAndDisposeListener();
  }
}

enum PostCategory {
  discover,
  nearby,
  following;

  String get title {
    switch (this) {
      case PostCategory.discover:
        return LKey.discover.tr;
      case PostCategory.nearby:
        return LKey.nearby.tr;
      case PostCategory.following:
        return LKey.following.tr;
    }
  }
}
