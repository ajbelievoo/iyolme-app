import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/hitune_auth_service.dart';
import 'package:shortzz/model/post_story/music/music_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// "My Music" — the logged-in user's own HiTune sounds for the reel
/// picker: AI Studio generated songs + HiTune Distribution releases.
/// Returns the tapped Music to the caller via Get.back(result:).
class MyMusicController extends BaseController {
  RxList<Music> aiSongs = <Music>[].obs;
  RxList<Music> releases = <Music>[].obs;
  RxBool notLinked = false.obs;
  RxBool fetched = false.obs;

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  Future<void> refresh() async {
    isLoading.value = true;
    notLinked.value = false;
    try {
      final resp = await PostService.instance.fetchMyHituneMusic();
      if (resp.status != true) {
        if (resp.linked == false || resp.message == 'hitune_not_linked') {
          notLinked.value = true;
        }
        aiSongs.clear();
        releases.clear();
      } else {
        final items = resp.data ?? <Music>[];
        aiSongs.value = items.where((m) => m.isAiStudioSong).toList();
        releases.value = items.where((m) => !m.isAiStudioSong).toList();
      }
    } catch (e) {
      Loggers.error('fetchMyHituneMusic failed: $e');
    } finally {
      fetched.value = true;
      isLoading.value = false;
    }
  }

  void onTapMusic(Music music) {
    Get.back(result: music);
  }

  Future<void> onConnectHitune() async {
    if (SessionManager.instance.isLogin()) {
      await HituneAuthService.shared.startLink();
    } else {
      await HituneAuthService.shared.startLogin();
    }
  }

  Future<void> onOpenAiStudio() async {
    try {
      await launchUrl(Uri.parse('https://music.hitune.in/ai-studio'),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      Loggers.error('ai-studio launch failed: $e');
    }
  }
}
