import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/manager/story_view/controller/story_controller.dart';
import 'package:shortzz/common/service/api/moderator_service.dart';
import 'package:shortzz/common/service/api/platform_ads_service.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/model/platform_ads/platform_ads_model.dart';
import 'package:shortzz/model/post_story/story/story_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';

import '../../common/manager/story_view/widgets/story_view.dart';

class StoryViewScreenController extends BaseController {
  StoryController storyController = StoryController();
  List<List<StoryItem>> stories = [];
  List<User> users = [];
  PageController pageController;
  int userIndex = 0;
  Function(Story? story) onUpdateStoryDelete;
  
  // Story ads
  final RxList<PlatformAd> _storyAds = <PlatformAd>[].obs;

  StoryViewScreenController(this.users, this.userIndex, this.pageController,
      this.onUpdateStoryDelete) {
    _initialize();
  }
  
  void _initialize() async {
    // Fetch story ads first
    await _fetchStoryAds();
    
    // Inject ads into story feed
    _injectAdsIntoStories();
    
    for (var user in users) {
      List<StoryItem> userStories =
          user.stories?.map((e) => e.toStoryItem(storyController)).toList() ??
              [];
      stories.add(userStories);
    }
    update();
  }
  
  Future<void> _fetchStoryAds() async {
    try {
      final ads = await PlatformAdsService.instance.fetchPlatformAds(placement: 'story');
      _storyAds.assignAll(ads);
      Loggers.info('Fetched ${_storyAds.length} ads for stories');
    } catch (e) {
      Loggers.error('Failed to fetch story ads: $e');
    }
  }
  
  void _injectAdsIntoStories() {
    if (_storyAds.isEmpty) return;
    
    // Inject an ad user every 5 users
    int adIndex = 0;
    List<User> usersWithAds = [];
    
    for (int i = 0; i < users.length; i++) {
      usersWithAds.add(users[i]);
      
      if ((i + 1) % 5 == 0 && adIndex < _storyAds.length) {
        final ad = _storyAds[adIndex % _storyAds.length];
        final adUser = _createAdUser(ad);
        usersWithAds.add(adUser);
        adIndex++;
      }
    }
    
    users = usersWithAds;
  }
  
  User _createAdUser(PlatformAd ad) {
    // Create a synthetic user with ad content as story
    final adStory = Story(
      id: -1 * (ad.id ?? 0), // Negative ID to identify as ad
      userId: 0,
      type: 0, // Image type
      content: ad.mediaUrl ?? ad.thumbnailUrl,
      thumbnail: ad.thumbnailUrl,
      duration: '10', // 10 seconds duration for ad
    );
    
    // Add ad metadata to story as JSON string
    adStory.metadata = jsonEncode({
      'isAd': true,
      'adId': ad.id,
      'title': ad.title,
      'cta': ad.cta,
      'destinationUrl': ad.destinationUrl,
      'sponsoredLabel': 'Sponsored',
    });
    
    return User(
      id: 0,
      username: ad.advertiserName ?? 'Sponsored',
      stories: [adStory],
    );
  }

  void onStoryShow(StoryItem value) async {
    final myId = SessionManager.instance.getUserID().toString();
    if (!value.viewedByUsersIds.contains(myId)) {
      value.viewedByUsersIds.add(myId);
      value.shown = true;
      update();

      if (value.story == null) {
        // If backend injects a story-ad item in future, it should include enough
        // metadata to map to an ad_id; until then, skip.
        return;
      }

      _markStoryViewedLocally(value, myId);
      final Story? story =
          await PostService.instance.viewStory(storyId: value.id.toInt());
      if (story != null) {
        if (userIndex < users.length) {
          final List<Story> userStories = users[userIndex].stories ?? [];
          final int storyIndex =
              userStories.indexWhere((element) => element.id == story.id);
          if (storyIndex != -1) {
            story.user = value.story?.user;
            userStories[storyIndex] = story;
            update();
          }
        }
      }
    }
  }

  void _markStoryViewedLocally(StoryItem value, String myId) {
    if (userIndex >= users.length) return;
    final List<Story> userStories = users[userIndex].stories ?? [];
    final int storyIndex =
        userStories.indexWhere((element) => element.id == value.id);
    if (storyIndex == -1) return;

    final Story s = userStories[storyIndex];
    final parts = (s.viewByUserIds ?? '').split(',').where((e) => e.isNotEmpty);
    final set = <String>{...parts};
    if (!set.contains(myId)) {
      set.add(myId);
      s.viewByUserIds = set.join(',');
      userStories[storyIndex] = s;
    }
  }

  void onStoryDelete(Story? story, {required bool isModerator}) {
    int storyID = story?.id ?? -1;

    if (storyID == -1) {
      return Loggers.error('Invalid Story ID : $storyID');
    }
    Get.bottomSheet(
      ConfirmationSheet(
        title: LKey.deleteStoryTitle.tr,
        description: LKey.deleteStoryMessage.tr,
        onTap: () async {
          showLoader();
          StatusModel status;
          if (isModerator) {
            status = await ModeratorService.instance
                .moderatorDeleteStory(storyId: story?.id ?? -1);
          } else {
            status = await PostService.instance
                .deleteStory(storyId: story?.id ?? -1);
          }
          stopLoader();
          if (status.status == true) {
            onUpdateStoryDelete.call(story);
            Get.back();
          } else {
            showSnackBar(status.message);
          }
        },
      ),
    );
  }

  void onPreviousUser() {
    if (userIndex == 0) {
      return;
    }
    pageController.animateToPage(userIndex - 1,
        duration: const Duration(milliseconds: 300), curve: Curves.linear);
    update();
  }

  void onNext() {
    if (userIndex == (stories.length - 1)) {
      Get.back(result: users[userIndex]);
      return;
    }
    pageController.animateToPage(userIndex + 1,
        duration: const Duration(milliseconds: 300), curve: Curves.linear);
    update();
  }

  void onPageChange(int value) {
    userIndex = value;
    update();
  }

  @override
  void onClose() {
    super.onClose();
    storyController.dispose();
  }
}
