import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/screen/camera_screen/camera_screen.dart';
import 'package:shortzz/screen/selected_music_sheet/selected_music_sheet_controller.dart';
import 'package:shortzz/screen/story_view_screen/story_view_screen.dart';

/// Routes iyolme:// deep links that are NOT auth callbacks:
///
///   iyolme://reel/create?hitune_track_hash=..&title=..&artist=..&cover=..
///       &duration_ms=..&hitune_url=..&ai_pct=..&ai_badge=..&audio_url=..
///     -> resolve the sound on the backend, download it, open the camera
///        with the song attached ("Create Reel" from the HiTune Music app).
///
///   iyolme://story/<id>
///     -> fetch the story and open the story viewer (used by the HiTune
///        Music app's IyolMe stories rail).
///
/// iyolme://auth/hitune stays handled by HituneAuthService — it subscribes
/// to the same stream and ignores non-auth hosts.
class HituneLinkService {
  HituneLinkService._();
  static final HituneLinkService shared = HituneLinkService._();

  StreamSubscription<Uri>? _sub;
  bool _busy = false;

  void init() {
    if (_sub != null) return;
    _sub = AppLinks().uriLinkStream.listen(_handle);
    // Cold start — the auth stream doesn't replay the launch link.
    AppLinks().getInitialLink().then((uri) {
      if (uri != null) _handle(uri);
    }).catchError((_) {});
  }

  Future<void> _handle(Uri uri) async {
    if (uri.scheme != 'iyolme' || _busy) return;

    if (uri.host == 'reel' && uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'create') {
      await _openReelCreate(uri.queryParameters);
    } else if (uri.host == 'auth' &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == 'hitune_link') {
      await _handleHituneLinked(uri.queryParameters);
    } else if (uri.host == 'story' && uri.pathSegments.isNotEmpty) {
      if (uri.pathSegments.first == 'create') {
        await _openStoryCreate();
        return;
      }
      final id = int.tryParse(uri.pathSegments.first) ?? 0;
      if (id > 0) await _openStory(id);
    } else if (uri.host == 'home' || uri.host == '') {
      // iyolme://home — plain app launch, nothing to route.
      return;
    }
  }

  /// iyolme://story/create — open the story camera (HiTune "Your story").
  Future<void> _openStoryCreate() async {
    if (!_isLoggedIn) {
      Loggers.info('iyolme://story/create — login required');
      _toast('Login required', 'Log in to post a story');
      return;
    }
    Get.to(() => const CameraScreen(cameraType: CameraScreenType.story));
  }

  bool get _isLoggedIn => SessionManager.instance.isLogin();

  void _toast(String title, String msg) {
    try {
      Get.snackbar(title, msg, snackPosition: SnackPosition.BOTTOM);
    } catch (_) {}
  }

  Future<void> _openReelCreate(Map<String, String> q) async {
    final hash = q['hitune_track_hash'] ?? q['sound'] ?? '';
    if (hash.isEmpty) return;
    if (!_isLoggedIn) {
      Loggers.info('iyolme://reel/create — login required');
      _toast('Login required', 'Log in to create a reel with this song');
      return;
    }

    _busy = true;
    BaseController.share.showLoader();
    try {
      final music = await PostService.instance.resolveHituneSound(
        hituneTrackHash: hash,
        title: q['title'],
        artist: q['artist'],
        cover: q['cover'],
        durationMs: int.tryParse(q['duration_ms'] ?? ''),
        hituneUrl: q['hitune_url'],
        attributionLabel: q['attribution_label'],
        aiPct: int.tryParse(q['ai_pct'] ?? ''),
        aiBadge: q['ai_badge'],
        audioUrl: q['audio_url'],
      );
      if (music == null) {
        Loggers.error('reel/create: sound resolve failed for $hash');
        _toast('Sound unavailable', 'This sound could not be loaded');
        return;
      }

      final downloaded =
          await DefaultCacheManager().getSingleFile(music.sound?.addBaseURL() ?? '');
      final selected = SelectedMusic(music, 0, downloaded.path, 0);
      Get.to(() => CameraScreen(
            cameraType: CameraScreenType.post,
            selectedMusic: selected,
          ));
    } catch (e) {
      Loggers.error('reel/create failed: $e');
    } finally {
      BaseController.share.stopLoader();
      _busy = false;
    }
  }

  /// iyolme://auth/hitune_link?ok=1&username=x — result of the account-link
  /// flow (HituneAuthService.startLink). Refresh the profile so the
  /// "HiTune: @user" rows update immediately.
  Future<void> _handleHituneLinked(Map<String, String> q) async {
    if (q['ok'] == '1') {
      final name = q['username'] ?? '';
      _toast('HiTune linked',
          name.isNotEmpty ? 'Connected as @$name' : 'Account linked');
      final uid = SessionManager.instance.getUserID();
      if (uid > 0) {
        try {
          await UserService.instance
              .fetchUserDetails(userId: uid, forceRefresh: true);
        } catch (_) {}
      }
    } else {
      _toast('HiTune link failed',
          (q['error'] ?? 'Please try again').replaceAll('+', ' '));
    }
  }

  Future<void> _openStory(int storyId) async {
    if (!_isLoggedIn) {
      Loggers.info('iyolme://story — login required');
      _toast('Login required', 'Log in to view this story');
      return;
    }
    _busy = true;
    BaseController.share.showLoader();
    try {
      final story = await PostService.instance.fetchStoryByID(storyId);
      final user = story?.user;
      if (story == null || user == null) {
        Loggers.error('story open failed: id=$storyId');
        return;
      }
      user.stories = [story];
      Get.bottomSheet(
        StoryViewSheet(
          stories: [user],
          userIndex: 0,
          onUpdateDeleteStory: (_) {},
        ),
        isScrollControlled: true,
        ignoreSafeArea: false,
      );
    } catch (e) {
      Loggers.error('story open failed: $e');
    } finally {
      BaseController.share.stopLoader();
      _busy = false;
    }
  }
}
