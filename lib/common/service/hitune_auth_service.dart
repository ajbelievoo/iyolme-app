import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      Loggers.error('HiTune login launch failed: $e');
    }
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
