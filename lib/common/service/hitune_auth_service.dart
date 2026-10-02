import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/account_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen.dart';
import 'package:shortzz/utilities/const_res.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Continue with HiTune" SSO (IYOLME_INTEGRATION.md §2).
///
/// Flow: app opens {baseURL}hitune/login in the browser → IyolMe backend
/// redirects to HiTune OAuth authorize → HiTune returns ?code → backend
/// exchanges it and deep-links back as iyolme://auth/hitune?token=…&user_id=…
/// We store the session token + user exactly like UserService.logInUser does.
class HituneAuthService {
  HituneAuthService._();
  static final HituneAuthService shared = HituneAuthService._();

  StreamSubscription<Uri>? _sub;
  bool _busy = false;

  /// Open the HiTune OAuth login page in the external browser.
  Future<void> startLogin() async {
    final uri = Uri.parse('${baseURL}hitune/login');
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _toast('HiTune', 'Could not open the browser — please try again');
      }
    } catch (e) {
      Loggers.error('HiTune login launch failed: $e');
      _toast('HiTune', 'Could not open HiTune login — please try again');
    }
  }

  /// Link the CURRENT IyolMe account to a HiTune account.
  ///
  /// Unlike [startLogin] (which logs you in as the HiTune-mapped user), this
  /// binds `hitune_sub` onto the already signed-in user: the app asks the
  /// backend for a one-time link intent, opens the OAuth URL, and the
  /// callback deep-links back as iyolme://auth/hitune_link (handled by
  /// HituneLinkService).
  Future<void> startLink() async {
    if (_busy) return;
    _busy = true;
    try {
      BaseController.share.showLoader();
      final data = await UserService.instance.hituneLinkIntent();
      BaseController.share.stopLoader();
      if (data == null) {
        _toast('HiTune', 'Could not start linking — check your connection');
        return;
      }
      if (data['already_linked'] == true) {
        final name = (data['hitune_username'] ?? '').toString();
        _toast('HiTune',
            name.isNotEmpty ? 'Already linked as @$name' : 'Already linked');
        return;
      }
      final url = (data['url'] ?? '').toString();
      if (url.isEmpty) {
        _toast('HiTune', 'Could not start linking — please try again');
        return;
      }
      final launched = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!launched) {
        _toast('HiTune', 'Could not open the browser — please try again');
      }
    } catch (e) {
      Loggers.error('HiTune link launch failed: $e');
      _toast('HiTune', 'Could not open HiTune linking — please try again');
    } finally {
      BaseController.share.stopLoader();
      _busy = false;
    }
  }

  void _toast(String title, String msg) {
    try {
      Get.snackbar(title, msg, snackPosition: SnackPosition.BOTTOM);
    } catch (_) {}
  }

  /// Listen once for the iyolme://auth/hitune deep link carrying token+user_id.
  void init({void Function(bool ok)? onDone}) {
    if (_sub != null) return;
    _sub = AppLinks().uriLinkStream.listen((uri) async {
      if (uri.scheme != 'iyolme') return;
      if (uri.host != 'auth' || uri.pathSegments.isEmpty) return;
      if (uri.pathSegments.first != 'hitune') return;

      final token = uri.queryParameters['token'] ?? '';
      final userId = int.tryParse(uri.queryParameters['user_id'] ?? '') ?? 0;
      if (token.isEmpty || userId <= 0 || _busy) return;
      _busy = true;
      try {
        await _completeLogin(token: token, userId: userId);
        onDone?.call(true);
      } catch (e) {
        Loggers.error('HiTune SSO complete failed: $e');
        onDone?.call(false);
      } finally {
        _busy = false;
      }
    });
  }

  Future<void> _completeLogin({required String token, required int userId}) async {
    // Store the auth token first so fetchUserDetails is authenticated.
    SessionManager.instance.setAuthToken(Token(authToken: token));

    final user = await UserService.instance
        .fetchUserDetails(userId: userId, forceRefresh: true);
    if (user == null) {
      throw StateError('fetchUserDetails returned null for uid=$userId');
    }
    SessionManager.instance.setUser(user);
    SessionManager.instance.setLogin(true);
    AccountManager.instance.saveCurrentSession();
    Loggers.success('HiTune SSO login complete for uid=$userId');

    // Leave the login screen for the main shell.
    await Get.offAll(() => DashboardScreen(myUser: user));
  }
}
