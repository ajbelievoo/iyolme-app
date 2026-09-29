import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/model/chat_theme/chat_themes_model.dart';

class ChatThemeSheetController extends BaseController {
  RxList<ChatThemeItem> themes = <ChatThemeItem>[].obs;
  RxBool isLoadingThemes = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchThemes();
  }

  Future<void> fetchThemes() async {
    if (isLoadingThemes.value) return;
    isLoadingThemes.value = true;
    try {
      final res = await UserService.instance.getChatThemes();
      Loggers.info(
          '[ChatThemes] status=${res.status} message=${res.message} count=${res.data?.length ?? 0}');
      themes.assignAll(res.data ?? <ChatThemeItem>[]);
    } catch (e) {
      themes.clear();
      Loggers.error('[ChatThemes] fetch failed: $e');
      showSnackBar('Failed to load chat themes');
    } finally {
      isLoadingThemes.value = false;
    }
  }

  Future<void> selectTheme(ChatThemeItem theme) async {
    final id = theme.id ?? 0;
    if (id <= 0) return;
    showLoader(barrierDismissible: false);
    try {
      final res = await UserService.instance.setChatTheme(themeId: id);
      if (res.status == true) {
        SessionManager.instance.setActiveChatTheme(
          themeId: id,
          backgroundImageUrl: theme.backgroundImageUrl,
        );
      } else {
        showSnackBar(res.message ?? 'Failed to set theme');
      }
    } catch (_) {
      showSnackBar('Failed to set theme');
    } finally {
      stopLoader();
    }
  }
}
9