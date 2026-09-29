import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:detectable_text_field/detectable_text_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:retrytech_plugin/retrytech_plugin.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/functions/media_picker_helper.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/add_post_story_service.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/draft_service.dart';
import 'package:shortzz/common/service/sight_engin/sight_engine_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/file_path_model.dart';
import 'package:shortzz/model/general/location_place_model.dart';
import 'package:shortzz/model/general/place_detail.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/post_story/music/music_model.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/camera_screen/camera_screen.dart';
import 'package:shortzz/screen/camera_screen/camera_screen_controller.dart';
import 'package:shortzz/screen/color_filter_screen/widget/color_filtered.dart';
import 'package:shortzz/screen/comment_sheet/helper/comment_helper.dart';
import 'package:shortzz/screen/create_feed_screen/create_feed_screen.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/screen/selected_music_sheet/selected_music_sheet_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:video_player/video_player.dart';

enum DetectType { hashTag, atSign }

class CreateFeedScreenController extends BaseController {
  final dashboardController = Get.find<DashboardScreenController>();
  Rx<FeedPostType> feedPostType = FeedPostType.text.obs;
  RxBool canComment = true.obs;
  final RxBool isUploading = false.obs;
  final RetrytechPlugin _retrytechPlugin = RetrytechPlugin();

  CommentHelper commentHelper = CommentHelper();
  User? myUser = SessionManager.instance.getUser();
  RxList<ImageWithFilter> images = <ImageWithFilter>[].obs;
  List<num> mentionUserIds = [];

  Rx<ImageWithFilter?> video = Rx(null);
  Rx<Places?> selectedLocation = Rx(null);
  RxDouble progress = 0.0.obs;
  Rx<VideoPlayerController?> videoPlayerController = Rx(null);
  RxInt selectedImageIndex = 0.obs;
  Function({Post? post, CreateFeedType? type})? onAddPost;
  CreateFeedType createType;
  Rx<PostStoryContent?> content;

  Rx<Setting?> setting = Rx(null);

  CreateFeedScreenController(this.onAddPost, this.createType, this.content);

  UploadType _lastUploadType = UploadType.none;

  String localPath = '';

  @override
  void onInit() {
    super.onInit();
    _initThumbnail();
  }

  void _initThumbnail() async {
    localPath = await PlatformPathExtension.localPath;

    // Ensure thumbnail bytes are available for reel
    if (createType == CreateFeedType.reel && content.value != null) {
      if (content.value!.thumbnailBytes == null ||
          content.value!.thumbnailBytes!.isEmpty) {
        try {
          // Check if the provided thumbnail path is a valid image
          final String thumbPath =
              (content.value!.thumbNail ?? '').toLowerCase();
          final bool isImage = thumbPath.endsWith('.jpg') ||
              thumbPath.endsWith('.jpeg') ||
              thumbPath.endsWith('.png') ||
              thumbPath.endsWith('.webp');

          if (isImage &&
              content.value!.thumbNail != null &&
              File(content.value!.thumbNail!).existsSync()) {
            content.value!.thumbnailBytes =
                await File(content.value!.thumbNail!).readAsBytes();
            content.refresh();
          } else if (content.value!.content != null) {
            // Regenerate from video if thumbnail is missing or invalid
            var file = await MediaPickerHelper.shared
                .extractThumbnail(videoPath: content.value!.content!);

            // Retry with explicit position 0 if default failed
            if (!File(file.path).existsSync() ||
                await File(file.path).length() == 0) {
              file = await MediaPickerHelper.shared.extractThumbnail(
                  videoPath: content.value!.content!, position: 0);
            }

            if (File(file.path).existsSync()) {
              content.value!.thumbNail = file.path;
              content.value!.thumbnailBytes =
                  await File(file.path).readAsBytes();
              content.refresh();
            }
          }
        } catch (e) {
          Loggers.error('Thumbnail generation error: $e');
        }
      }
    }
  }

  @override
  void onReady() {
    super.onReady();
    Future.wait({_fetchSetting()});
  }

  @override
  void onClose() {
    super.onClose();
    videoPlayerController.value?.dispose();
  }

  Future _fetchSetting() async {
    setting.value = SessionManager.instance.getSettings();
    bool result = await CommonService.instance.fetchGlobalSettings();
    if (result == true) {
      setting.value = SessionManager.instance.getSettings();
    }
  }

  void _redirectToProfileTab() {
    try {
      final user = SessionManager.instance.getUser();
      Get.offAll(() => DashboardScreen(myUser: user));
    } catch (_) {}

    try {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (Get.isRegistered<DashboardScreenController>()) {
          Get.find<DashboardScreenController>().onChanged(5);
        }
      });
    } catch (_) {}
  }

  void handleUpload() async {
    if (isUploading.value) return;
    FocusManager.instance.primaryFocus?.unfocus();

    // Early return if nothing to upload for feed posts
    if (_shouldAbortUpload()) {
      Loggers.warning('Nothing to upload. Aborting...');
      return;
    }

    isUploading.value = true;
    final rawDescription = commentHelper.detectableTextController.text;

    final postParams = await _buildPostParams(rawDescription);

    Loggers.info('Post Data: $postParams');

    // Background upload logic
    CommonService.instance.showToast('Upload started in background...');

    // Close screen immediately BEFORE starting upload
    // Force navigation to Profile (Index 5)
    Get.offAll(
        () => DashboardScreen(myUser: SessionManager.instance.getUser()));

    // Switch to Profile Tab
    Future.delayed(const Duration(milliseconds: 300), () {
      if (Get.isRegistered<DashboardScreenController>()) {
        Get.find<DashboardScreenController>().onChanged(5);
      }
    });

    // Execute upload in background
    _executeBackgroundUpload(postParams, rawDescription);
  }

  Future<void> _executeBackgroundUpload(
      Map<String, dynamic> postParams, String rawDescription) async {
    try {
      if (createType == CreateFeedType.reel) {
        await _uploadPostHandler(postParams);
      } else {
        runContentModerationAndUpload(
          description: rawDescription,
          params: postParams,
        );
      }
    } catch (e) {
      Loggers.error('Background upload failed: $e');
      CommonService.instance.showToast('Upload failed: $e');
    }
  }

  bool _shouldAbortUpload() {
    return createType == CreateFeedType.feed &&
        images.isEmpty &&
        video.value == null &&
        commentHelper.detectableTextController.text.isEmpty;
  }

  Future<Map<String, dynamic>> _buildPostParams(String rawDescription) async {
    final params = <String, dynamic>{
      if (rawDescription.isNotEmpty) Params.description: rawDescription,
      Params.canComment: canComment.value ? 1 : 0,
    };

    _addTextDetections(params, rawDescription);
    _addLocationData(params);

    if (selectedLocation.value == null && createType == CreateFeedType.reel) {
      await _addCurrentLocationData(params);
    }

    return params;
  }

  void _addTextDetections(Map<String, dynamic> params, String rawDescription) {
    final mentionUsernames = _extractUniqueMentions(rawDescription);
    final hashtags = _extractUniqueHashtags(rawDescription);
    final processedDescription =
        _processMentions(rawDescription, mentionUsernames);

    if (processedDescription != rawDescription) {
      params[Params.description] = processedDescription;
    }

    if (hashtags.isNotEmpty) {
      params[Params.hashtags] = hashtags.join(',');
    }

    if (mentionUserIds.isNotEmpty) {
      params[Params.mentionedUserIds] = mentionUserIds.join(',');
    }
  }

  List<String> _extractUniqueMentions(String text) {
    return TextPatternDetector.extractDetections(text, atSignRegExp)
        .where((text) => text.contains('@'))
        .map((text) => text.replaceAll('@', ''))
        .toSet()
        .toList();
  }

  List<String> _extractUniqueHashtags(String text) {
    return TextPatternDetector.extractDetections(text, hashTagRegExp)
        .where((text) => text.contains('#'))
        .map((text) => text.replaceAll('#', ''))
        .toSet()
        .toList();
  }

  String _processMentions(String text, List<String> mentionUsernames) {
    var processedText = text;

    for (final username in mentionUsernames) {
      final user = commentHelper.allMentionUsers
          .firstWhereOrNull((u) => u.username == username);
      if (user != null && user.id != null) {
        processedText = processedText.replaceAllMapped(
          RegExp(RegExp.escape('@$username')),
          (_) => '@${user.id}',
        );
        mentionUserIds.addIf(!mentionUserIds.contains(user.id), user.id!);
      }
    }

    return processedText;
  }

  void _addLocationData(Map<String, dynamic> params) {
    final location = selectedLocation.value;
    if (location == null) return;

    params.addAll({
      Params.country: location.shortCountry,
      Params.state: location.shortState,
      Params.placeTitle: location.placeTitle,
      Params.placeLat: '${location.location?.latitude ?? ''}',
      Params.placeLon: '${location.location?.longitude ?? ''}',
    });
  }

  Future<void> _addCurrentLocationData(Map<String, dynamic> params) async {
    Position? position;
    PlaceDetail? detail;
    try {
      position = await Geolocator.getCurrentPosition();
      detail = await CommonService.instance.getIPPlaceDetail();
    } catch (e) {
      Loggers.error('_addCurrentLocationData $e');
    }
    if (detail != null && detail.status == 'success') {
      params.addAll({
        Params.country: detail.country,
        Params.state: detail.region,
        Params.placeLat: '${position?.latitude ?? detail.lat}',
        Params.placeLon: '${position?.longitude ?? detail.lon}',
      });
    }
  }

  void runContentModerationAndUpload(
      {required String description, required Map<String, dynamic> params}) {
    switch (feedPostType.value) {
      case FeedPostType.image:
        Loggers.info('Running SightEngine image moderation...');
        List<XFile> imageFiles = images.map((img) => img.media).toList();
        SightEngineService.shared.checkImagesInSightEngine(
          xFiles: imageFiles,
          completion: () {
            _uploadPostHandler(params);
          },
        );
        break;
      case FeedPostType.text:
        Loggers.info('Running SightEngine text moderation...');
        SightEngineService.shared.chooseTextModeration(
          text: description,
          completion: () {
            _uploadPostHandler(params);
          },
        );
        break;
      case FeedPostType.video:
        Loggers.info('Running SightEngine video moderation...');
        SightEngineService.shared.checkVideoInSightEngine(
          xFile: video.value!.media,
          duration: videoPlayerController.value?.value.duration.inSeconds ?? 0,
          completion: () {
            _uploadPostHandler(params);
          },
        );
        break;
    }
  }

  Future<void> _uploadPostHandler(Map<String, dynamic> postParams) async {
    Loggers.info('Post upload initiated...');

    PostModel? postResponse;
    _lastUploadType = UploadType.uploading;
    updateUploadingProgress(progress: 0);

    await Future.delayed(const Duration(seconds: 1));

    try {
      // Handle post upload based on post type
      switch (createType) {
        case CreateFeedType.reel:
          Loggers.info('Uploading Reel...');
          postResponse = await _handleReelUpload(content.value, postParams);
          break;

        case CreateFeedType.feed:
          switch (feedPostType.value) {
            case FeedPostType.image:
              Loggers.info('Uploading Image post...');
              postResponse = await _handleImageUpload(postParams);
              break;
            case FeedPostType.text:
              Loggers.info('Uploading Text post...');

              updateUploadingProgress(progress: 90);
              if (commentHelper.metaData.value != null) {
                postParams[Params.metadata] =
                    jsonEncode(commentHelper.metaData.value);
              }
              postResponse = await AddPostStoryService.instance
                  .addPostFeedText(param: postParams);
              break;
            case FeedPostType.video:
              Loggers.info('Uploading Video post...');
              postResponse = await _handleVideoUpload(postParams);
              break;
          }
      }

      // Check result and update progress
      if (postResponse?.status == true) {
        Post? post = postResponse?.data;
        if (post == null) {
          failedResponseSnackBar(message: 'Post not found');
          return;
        }
        Loggers.success('Post uploaded successfully ✅');

        // Notify profile controller if available
        if (Get.isRegistered<ProfileScreenController>(
            tag: ProfileScreenController.tag)) {
          final profileController = Get.find<ProfileScreenController>(
              tag: ProfileScreenController.tag);
          profileController.onAddPost(post: post, type: createType);
        }
        Loggers.info('''
                Post ID: ${post.id}
                Mention User IDs: ${post.mentionedUsers?.map((e) => e.id).toList()} 
              ''');
        _notifyMentionedUsers(post);
        _lastUploadType = UploadType.finish;
        updateUploadingProgress(progress: 100);

        // Only redirect after successful upload.
        _redirectToProfileTab();
      } else {
        Loggers.error('Post upload failed ❌: ${postResponse?.message}');

        await failedResponseSnackBar(message: postResponse?.message);
      }
    } catch (e, stacktrace) {
      Loggers.error('Exception during post upload: $e');
      Loggers.error(stacktrace.toString());
      await failedResponseSnackBar(message: '$e');
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> _notifyMentionedUsers(Post post) async {
    const int batchSize = 5;
    List<Future> batch = [];

    for (final mentionUser in (post.mentionedUsers ?? [])) {
      if (mentionUser.notifyMention == 1 && mentionUser.id != myUser?.id) {
        batch.add(
            FirebaseNotificationManager.instance.sendLocalisationNotification(
          LKey.notifyMentionedInPost,
          type: NotificationType.post,
          body: NotificationInfo(id: post.id),
          deviceType: mentionUser.device,
          deviceToken: mentionUser.deviceToken ?? '',
          languageCode: mentionUser.appLanguage,
        ));

        if (batch.length >= batchSize) {
          await Future.wait(batch);
          batch.clear();
        }
      }
    }

    if (batch.isNotEmpty) {
      await Future.wait(batch);
    }
  }

  Future<PostModel?> _handleReelUpload(
      PostStoryContent? content, Map<String, dynamic> params) async {
    if (content == null) {
      return failedResponseSnackBar(message: 'Invalid content');
    }

    final String videoPath = content.content ?? '';
    final String extractAudioPath = '${localPath}extract_audio.m4a';
    if (videoPath.isEmpty) {
      return failedResponseSnackBar(message: 'Video not found');
    }

    String? resolvedThumbPath;
    try {
      final rawThumb = (content.thumbNail ?? '').trim();
      if (rawThumb.isNotEmpty) {
        resolvedThumbPath = rawThumb;
      } else if (content.thumbnailBytes != null &&
          content.thumbnailBytes!.isNotEmpty) {
        resolvedThumbPath =
            '${localPath}reel_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(resolvedThumbPath).writeAsBytes(content.thumbnailBytes!);
      }
    } catch (e) {
      Loggers.error('Failed to resolve reel thumbnail: $e');
    }
    if (resolvedThumbPath == null || resolvedThumbPath.trim().isEmpty) {
      deleteFiles([videoPath, extractAudioPath]);
      return failedResponseSnackBar(message: 'Thumbnail not found');
    }

    SelectedMusic? selectedMusic = content.sound;
    bool hasAudio = content.hasAudio;
    Music? uploadedMusic;

    if (hasAudio) {
      if (selectedMusic == null) {
        final duration = Duration(seconds: content.duration ?? 0);

        final String artistName = myUser?.username ?? 'Unknown';

        Loggers.info('Extracting audio from video...');
        bool? success = await _retrytechPlugin.extractAudio(
            inputPath: videoPath, outputPath: extractAudioPath);

        if (success == false) {
          deleteFiles([videoPath, extractAudioPath]);
          return failedResponseSnackBar(message: 'Audio extraction failed.');
        }

        Loggers.success('Audio extracted at: $extractAudioPath');

        // Load profile image or fallback to thumbnail
        final XFile? profileImage =
            await _loadProfileOrThumbnailImage(content.thumbNail);

        Loggers.info('Uploading extracted music...');
        uploadedMusic = await PostService.instance.addUserMusic(
          title: AppRes.addMusicName,
          duration: '${duration.inMinutes}:${duration.inSeconds % 60}',
          artist: artistName,
          sound: XFile(extractAudioPath),
          image: profileImage,
        );

        Loggers.success('Music uploaded: ${uploadedMusic?.title}');
      } else {
        uploadedMusic = selectedMusic.music;
      }

      params[Params.soundID] = uploadedMusic?.id;

      if (uploadedMusic == null) {
        deleteFiles([videoPath, extractAudioPath]);
        return failedResponseSnackBar(message: 'Music not found');
      }
    }

    // progress.value = 10;
    updateUploadingProgress(progress: 10);

    // Step 5: Upload video & thumbnail
    Loggers.info('Compressing video to fix rotation...');
    XFile? compressedFile =
        await MediaPickerHelper.shared.compressVideo(videoPath, localPath);
    String uploadPath = compressedFile?.path ?? videoPath;

    Loggers.info('Uploading video...');
    FilePathModel uploadedVideo =
        await CommonService.instance.uploadFileGivePath(XFile(uploadPath));

    Loggers.info('Uploading thumbnail...');
    FilePathModel uploadedThumb = await CommonService.instance
        .uploadFileGivePath(XFile(resolvedThumbPath));

    // Step 6: Check upload success
    if (uploadedVideo.status == false || uploadedThumb.status == false) {
      deleteFiles([videoPath, resolvedThumbPath, extractAudioPath]);
      return failedResponseSnackBar(message: uploadedVideo.message);
    }

    // progress.value = 90;
    updateUploadingProgress(progress: 90);

    // Prepare final post params
    params[Params.video] = uploadedVideo.data;
    params[Params.thumbnail] = uploadedThumb.data;
    params[Params.type] = 'reel';
    params[Params.videoHls] = ''; // Ensure backend knows to generate HLS
    
    // Final post upload
    try {
      Loggers.info('Uploading final post...');
      PostModel result =
          await AddPostStoryService.instance.addPostReel(param: params);
      return result;
    } catch (e) {
      return failedResponseSnackBar(message: '$e');
    }
  }

  Future<XFile?> _loadProfileOrThumbnailImage(String? fallbackThumb) async {
    try {
      String profileImage = myUser?.profilePhoto ?? '';

      if (profileImage.isEmpty) {
        return null;
      }

      final file =
          await DefaultCacheManager().getSingleFile(profileImage.addBaseURL());
      Loggers.success('Loaded profile image from URL.');
      return XFile(file.path);
    } catch (e) {
      Loggers.error('Error loading profile image: $e');
    }

    Loggers.info('Using fallback thumbnail.');
    return XFile(fallbackThumb ?? '');
  }

  Future<PostModel?> _handleImageUpload(Map<String, dynamic> params) async {
    if (images.isEmpty) {
      Loggers.warning('No images selected for upload.');
      return failedResponseSnackBar(message: 'No images to upload');
    }

    Loggers.info('Starting image upload...');

    // Step 1: Apply filters if any
    List<XFile> filterImages = await Future.wait(
      images.map((image) async {
        bool isFilterApply = !listEquals(image.colorFilter, defaultFilter);
        if (isFilterApply) {
          Loggers.info('Applying color filter to image at ${image.media.path}');
          String outputPath =
              '$localPath${images.indexOf(image)}filter_image.jpg';
          bool? result = await _retrytechPlugin.applyFilterToImage(
              inputPath: image.media.path,
              filterValues: image.colorFilter,
              outputPath: outputPath);
          if (result == true) {
            Loggers.success('Filter applied: $outputPath');
            return XFile(outputPath);
          } else {
            Loggers.warning('Filter failed, using original image.');
          }
        }
        return XFile(image.media.path);
      }),
    );

    Loggers.info('Apply Filters : ${filterImages.map((e) => e.path)}');

    updateUploadingProgress(progress: 10);

    List<String> compressImages = [];

    // Step 2: Compress each image
    if (setting.value?.isCompress == 1) {
      for (int i = 0; i < filterImages.length; i++) {
        XFile? imageFile = filterImages[i];

        Loggers.info('Compressing image: ${imageFile.path}');
        XFile? compressImageFile = await MediaPickerHelper.shared
            .compressImage(
                imageFile.path, '${localPath}compress_images_$i.jpg');
        if (compressImageFile != null) {
          compressImages.add(compressImageFile.path);
        } else {
          compressImages.add(imageFile.path);
        }
        Loggers.info('Uploading image: ${imageFile.path}');
      }
    } else {
      for (int i = 0; i < filterImages.length; i++) {
        compressImages.add(filterImages[i].path);
      }
    }

    updateUploadingProgress(progress: 30);

    Loggers.info('Compress image : ${compressImages.map((e) => e)}');

    // Step 3: Uploading each image
    List<String> uploadedImagePaths = [];
    for (final image in compressImages) {
      final result =
          await CommonService.instance.uploadFileGivePath(XFile(image));
      if (result.status == true && result.data != null) {
        uploadedImagePaths.add(result.data!);
        Loggers.success('Image uploaded: ${result.data}');
      } else {
        Loggers.error('Image upload failed: ${result.message}');
        await deleteFiles(images.map((e) => e.media.path).toList() +
            filterImages.map((e) => e.path).toList() +
            compressImages);
        await failedResponseSnackBar(message: result.message);
        return null;
      }
    }
    updateUploadingProgress(progress: 90);

    // Step 4: Add uploaded image paths to params
    // Backend expects `post_images` as an array.
    params[Params.postImages] = uploadedImagePaths;

    // Delete temporary files
    deleteFiles(images.map((e) => e.media.path).toList() +
        filterImages.map((e) => e.path).toList() +
        compressImages);

    Loggers.info('Uploading final post... $params');

    // Step 5: Upload final post
    try {
      final postResult =
          await AddPostStoryService.instance.addPostFeedImage(param: params);
      return postResult;
    } catch (e) {
      Loggers.error('Exception during post upload: $e');
      await failedResponseSnackBar(message: '$e');
      return null;
    }
  }

  Future<PostModel?> _handleVideoUpload(Map<String, dynamic> params) async {
    ImageWithFilter? videoData = video.value;
    if (videoData == null) {
      return failedResponseSnackBar(message: 'Video not found');
    }
    Loggers.info('Starting video upload...');

    String inputVideoPath = videoData.media.path;
    XFile? finalThumbnailFile = videoData.thumbnail;
    bool isApplyFilter = !listEquals(videoData.colorFilter, defaultFilter);

    XFile? finalVideoFile;
    String outputVideoPath = '${localPath}filter_video.mp4';

    if (inputVideoPath.isEmpty) {
      Loggers.error('Input video path is empty');
      return null;
    }

    // Step 1: Apply color filter if present
    if (isApplyFilter) {
      bool? result = await _retrytechPlugin.applyFilterAndAudioToVideo(
          inputPath: inputVideoPath,
          outputPath: outputVideoPath,
          filterValues: videoData.colorFilter,
          shouldBothMusics: true);
      if (result == true) {
        Loggers.info('Applying color filter to video...');
        finalVideoFile = XFile(outputVideoPath);
        // Step 2: Extract thumbnail from the final video
        Loggers.info('Extracting thumbnail...');
        finalThumbnailFile = await MediaPickerHelper.shared
            .extractThumbnail(videoPath: finalVideoFile.path);
      } else {
        return failedResponseSnackBar(message: 'Color filter failed');
      }
    } else {
      finalVideoFile = XFile(inputVideoPath);
      Loggers.info('No color Add, using original video.');
    }

    updateUploadingProgress(progress: 10);

    // Step 3: Optional compression
    if (setting.value?.isCompress == 1) {
      Loggers.info('Compressing video and thumbnail...');
      XFile? compressVideoFile = await MediaPickerHelper.shared
          .compressVideo(finalVideoFile.path, localPath);
      if (compressVideoFile != null) {
        finalVideoFile = compressVideoFile;
      } else {
        Loggers.error('Compression failed: null video');
      }

      XFile? compressThumbFile = await MediaPickerHelper.shared.compressImage(
          finalThumbnailFile.path, '${localPath}compress_video_thumb.jpg');
      if (compressThumbFile != null) {
        finalThumbnailFile = compressThumbFile;
      } else {
        Loggers.error('Compression failed: null Thumbnail');
      }
    }

    updateUploadingProgress(progress: 30);

    // Step 5: Upload video
    Loggers.info('Uploading video...');
    FilePathModel uploadedVideo =
        await CommonService.instance.uploadFileGivePath(finalVideoFile);

    Loggers.info('Uploading thumbnail...');
    FilePathModel uploadedThumbnail =
        await CommonService.instance.uploadFileGivePath(finalThumbnailFile);
    deleteFiles([finalVideoFile.path, finalThumbnailFile.path]);
    // Step 6: Check upload success
    if (uploadedVideo.status == false || uploadedThumbnail.status == false) {
      return failedResponseSnackBar(message: uploadedVideo.message);
    }

    updateUploadingProgress(progress: 90);

    // Step 7: Finalize post params and upload
    params[Params.video] = uploadedVideo.data;
    params[Params.thumbnail] = uploadedThumbnail.data;

    Loggers.success('Uploading final video post...');
    try {
      final result =
          await AddPostStoryService.instance.addPostFeedVideo(param: params);

      return result;
    } catch (e) {
      Loggers.error('Exception while uploading video post: $e');
      return failedResponseSnackBar(message: '$e');
    }
  }

  void updateUploadingProgress({
    required double progress,
  }) {
    dashboardController.onProgress.call(
      PostUploadingProgress(
        uploadType: _lastUploadType,
        progress: progress,
        type: CameraScreenType.post,
      ),
    );

    if (progress == 100) {
      _resetUploadingProgressAfterDelay();
    }
  }

  void _resetUploadingProgressAfterDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      dashboardController.onProgress.call(
        PostUploadingProgress(
          uploadType: UploadType.none,
          progress: 0,
          type: CameraScreenType.post, // or use last type if needed
        ),
      );
    });
  }

  Future<PostModel?> failedResponseSnackBar({String? message}) async {
    _lastUploadType = UploadType.error;
    updateUploadingProgress(progress: 100);

    // Surface the real error to user instead of only generic "Uploading failed".
    BaseController.share.showSnackBar(
        message?.isNotEmpty == true ? message : LKey.uploadingFailed.tr);
    return null;
  }

  Future<void> deleteFiles(List<String?> paths) async {
    await Future(() async {
      for (final path in paths.whereType<String>()) {
        final file = File(path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            Loggers.error('❌ Failed to delete: $path — $e');
          }
        }
      }
      Loggers.info('📁 Deleted files: $paths');
    });
  }

  onLocationTap(Places place) {
    selectedLocation.value = place;
  }

  onMediaTap(FeedPostType type) {
    commentHelper.detectableTextFocusNode.unfocus();
    switch (type) {
      case FeedPostType.image:
        selectImages();
        break;
      case FeedPostType.text:
        break;
      case FeedPostType.video:
        pickVideo();
        break;
    }
  }

  Future<void> selectImages() async {
    final int remainingSlots =
        setting.value?.maxImagesPerPost ?? AppRes.imageLimit - images.length;

    if (remainingSlots >= 2) {
      final List<XFile> imageFiles =
          await MediaPickerHelper.shared.multipleImages(limit: remainingSlots);

      images.addAll(imageFiles.map(
        (file) => ImageWithFilter(media: file, thumbnail: file),
      ));
    } else {
      final XFile? imageFile =
          await MediaPickerHelper.shared.pickImage(source: ImageSource.gallery);

      if (imageFile != null) {
        images.add(ImageWithFilter(media: imageFile, thumbnail: imageFile));
      }
    }
    if (images.isNotEmpty) {
      feedPostType.value = FeedPostType.image;
    }
  }

  void onDeleteSelectedImages() {
    if (images.isNotEmpty) {
      // Remove the selected file
      images.removeAt(selectedImageIndex.value);
      images.refresh();

      // Adjust the selected index only if files are not empty after removal
      if (images.isNotEmpty) {
        if (selectedImageIndex.value >= images.length) {
          selectedImageIndex.value = images.length - 1;
        }
      } else {
        // Reset index to 0 if all files are removed
        selectedImageIndex.value = 0;
        feedPostType.value = FeedPostType.text;
      }
    }
  }

  pickVideo() async {
    MediaFile? file =
        await MediaPickerHelper.shared.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      video.value =
          ImageWithFilter(media: file.file, thumbnail: file.thumbNail);
      videoPlayerController.value =
          VideoPlayerController.file(File(file.file.path))
            ..initialize().then((value) => videoPlayerController.refresh());
    }
    feedPostType.value = FeedPostType.video;
  }

  void onChangeReelCover() async {
    Get.bottomSheet(
      Container(
        color: Colors.white,
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Select from Gallery'),
              onTap: () async {
                Get.back();
                XFile? file = await MediaPickerHelper.shared
                    .pickImage(source: ImageSource.gallery);
                if (file != null) {
                  Uint8List bytes = await file.readAsBytes();
                  content.update((val) {
                    val?.thumbnailBytes = bytes;
                    val?.thumbNail = file.path;
                  });
                }
              },
            ),
            if (content.value?.content != null)
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Select from Video'),
                onTap: () {
                  Get.back();
                  _showVideoFramePicker(content.value!.content!);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showVideoFramePicker(String videoPath) async {
    if (videoPlayerController.value == null) {
      showLoader();
      try {
        final controller = VideoPlayerController.file(File(videoPath));
        await controller.initialize();
        videoPlayerController.value = controller;
      } catch (e) {
        stopLoader();
        Loggers.error('Error initializing video player: $e');
        return;
      }
      stopLoader();
    }

    final controller = videoPlayerController.value!;
    final wasPlaying = controller.value.isPlaying;
    controller.pause();

    Get.bottomSheet(
      StatefulBuilder(builder: (context, setState) {
        final duration = controller.value.duration.inMilliseconds.toDouble();
        double currentVal = controller.value.position.inMilliseconds.toDouble();

        return Container(
          color: Colors.black,
          padding: const EdgeInsets.all(16),
          height: Get.height * 0.6,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      if (wasPlaying) controller.play();
                      Get.back();
                    },
                    child:
                        const Text('Cancel', style: TextStyle(color: Colors.white)),
                  ),
                  const Text('Select Cover',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () async {
                      final position = controller.value.position.inMilliseconds;
                      Get.back(); // Close sheet first

                      showLoader();
                      try {
                        final bytes =
                            await MediaPickerHelper.shared.extractThumbnailByte(
                          videoPath: videoPath,
                          position: position,
                        );

                        if (bytes != null) {
                          content.value!.thumbnailBytes = bytes;
                          final String tempPath =
                              '${localPath}reel_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final file = File(tempPath);
                          await file.writeAsBytes(bytes);
                          content.value!.thumbNail = tempPath;

                          content.refresh();
                        }
                      } catch (e) {
                        Loggers.error('Error generating cover: $e');
                      } finally {
                        stopLoader();
                        if (wasPlaying) controller.play();
                      }
                    },
                    child: const Text('Done', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Slider(
                value: currentVal.clamp(0.0, duration),
                min: 0.0,
                max: duration,
                onChanged: (val) {
                  setState(() {
                    currentVal = val;
                  });
                  controller.seekTo(Duration(milliseconds: val.toInt()));
                },
                activeColor: Colors.white,
                inactiveColor: Colors.grey,
              ),
            ],
          ),
        );
      }),
      isScrollControlled: true,
      enableDrag: false,
    );
  }

  void selectedVideoDelete() {
    video.value = null;
    videoPlayerController.value?.dispose();
    feedPostType.value = FeedPostType.text;
  }

  final RxBool isSaving = false.obs;

  void onSaveDraft() async {
    if (isSaving.value) return;
    if (createType != CreateFeedType.reel || content.value == null) {
      Get.snackbar('Error', 'Only reels can be saved as drafts');
      return;
    }

    try {
      isSaving.value = true;
      CommonService.instance.showToast('Saving draft...');
      // Force close keyboard
      FocusManager.instance.primaryFocus?.unfocus();

      await DraftService.instance.saveDraft(content.value!);
      CommonService.instance.showToast('Draft saved successfully');

      // Force navigation to Profile (Index 5)
      // This ensures we leave the Create screen completely.
      Get.offAll(
          () => DashboardScreen(myUser: SessionManager.instance.getUser()));

      // After a short delay, switch to profile tab
      Future.delayed(const Duration(milliseconds: 500), () {
        if (Get.isRegistered<DashboardScreenController>()) {
          Get.find<DashboardScreenController>().onChanged(5);
        }
        // Force profile controller to switch to drafts tab
        if (Get.isRegistered<ProfileScreenController>()) {
          Get.find<ProfileScreenController>().onTabChanged(3);
        } else {
          // If controller not ready, we can try to find it later or use a global event
          // But usually Dashboard initializes it.
        }
      });
    } catch (e) {
      CommonService.instance.showToast('Failed to save draft: $e');
    } finally {
      isSaving.value = false;
    }
  }
}

enum FeedTagType {
  mention(AssetRes.icAt, LKey.mention),
  hashtag(AssetRes.icHashtag, LKey.hashtags),
  location(AssetRes.icLocation, LKey.location);

  final String image;
  final String titleKey;

  const FeedTagType(this.image, this.titleKey);

  String get title => titleKey.tr;
}

enum FeedPostType { image, text, video }

class ReelData {
  XFile? videoFile;
  XFile? thumbnailFile;
  Uint8List? thumbnailBytes;
  Color? bgColor;
  SelectedMusic? selectedMusic;
  int? videoDurationMs;
  Filters? selectedFilter;

  ReelData({
    required this.videoFile,
    required this.thumbnailFile,
    this.thumbnailBytes,
    this.videoDurationMs,
    this.bgColor,
    this.selectedFilter,
    this.selectedMusic,
  });

  ReelData copyWith({
    XFile? videoFile,
    XFile? thumbnailFile,
    Uint8List? thumbnailBytes,
    Color? bgColor,
    SelectedMusic? selectedMusic,
    int? audioStartDurationMs,
    int? videoDurationMs,
    Filters? selectedFilter,
  }) {
    return ReelData(
        videoFile: videoFile ?? this.videoFile,
        thumbnailFile: thumbnailFile ?? this.thumbnailFile,
        thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
        bgColor: bgColor ?? this.bgColor,
        selectedMusic: selectedMusic ?? this.selectedMusic,
        videoDurationMs: videoDurationMs ?? this.videoDurationMs,
        selectedFilter: selectedFilter ?? this.selectedFilter);
  }
}

class ImageWithFilter {
  XFile media;
  XFile thumbnail;
  List<double> colorFilter;

  ImageWithFilter(
      {required this.media,
      this.colorFilter = defaultFilter,
      required this.thumbnail});
}

enum ImageWithFilterType {
  video,
  image;
}
