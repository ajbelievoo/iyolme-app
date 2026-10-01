import 'package:get/get.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/auth_screen/login_screen.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen.dart';

/// One remembered login — enough state to restore a session instantly.
class SavedAccount {
  final int userId;
  final String username;
  final String fullname;
  final String profilePhoto;
  final Map<String, dynamic> userJson;
  final Map<String, dynamic> tokenJson;
  final String? password;
  final int savedAt;

  SavedAccount({
    required this.userId,
    required this.username,
    required this.fullname,
    required this.profilePhoto,
    required this.userJson,
    required this.tokenJson,
    this.password,
    required this.savedAt,
  });

  factory SavedAccount.fromJson(Map<String, dynamic> j) => SavedAccount(
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        username: j['username']?.toString() ?? '',
        fullname: j['fullname']?.toString() ?? '',
        profilePhoto: j['profile_photo']?.toString() ?? '',
        userJson: Map<String, dynamic>.from(j['user'] is Map ? j['user'] : {}),
        tokenJson: Map<String, dynamic>.from(j['token'] is Map ? j['token'] : {}),
        password: j['password']?.toString(),
        savedAt: (j['saved_at'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'fullname': fullname,
        'profile_photo': profilePhoto,
        'user': userJson,
        'token': tokenJson,
        'password': password,
        'saved_at': savedAt,
      };
}

/// Instagram/Facebook-style multi-account switcher.
///
/// Every successful login calls [saveCurrentSession], which upserts the
/// account into `saved_accounts` inside the shared GetStorage box. The
/// list survives logout ([SessionManager.clearSomeKey] doesn't touch it),
/// so tapping a saved account restores its token + user instantly.
class AccountManager {
  AccountManager._();

  static final AccountManager instance = AccountManager._();
  static const _key = 'saved_accounts';

  List<SavedAccount> getSavedAccounts() {
    final raw = SessionManager.instance.storage.read(_key);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => SavedAccount.fromJson(Map<String, dynamic>.from(e)))
        .where((a) => a.userId > 0 && a.tokenJson.isNotEmpty)
        .toList();
  }

  void _writeAll(List<SavedAccount> list) {
    SessionManager.instance.storage
        .write(_key, list.map((a) => a.toJson()).toList());
  }

  /// Call after every successful login (password, Google, HiTune SSO).
  void saveCurrentSession() {
    final user = SessionManager.instance.getUser();
    final token = SessionManager.instance.getToken();
    if (user == null || (token?.authToken ?? '').isEmpty) return;

    final userJson = Map<String, dynamic>.from(user.toJson());
    final list = getSavedAccounts()
      ..removeWhere((a) => a.userId == user.id?.toInt());
    list.insert(
      0,
      SavedAccount(
        userId: user.id?.toInt() ?? 0,
        username: user.username ?? '',
        fullname: user.fullname ?? '',
        profilePhoto: user.profilePhoto ?? '',
        userJson: userJson,
        tokenJson: token!.toJson(),
        password: SessionManager.instance.getPassword(),
        savedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _writeAll(list);
  }

  void removeAccount(int userId) {
    _writeAll(getSavedAccounts()..removeWhere((a) => a.userId == userId));
  }

  /// Switch to a remembered account without re-entering credentials.
  Future<void> switchTo(SavedAccount account) async {
    if (account.userId == SessionManager.instance.getUserID()) return;
    SessionManager.instance.setUser(User.fromJson(account.userJson));
    SessionManager.instance.setAuthToken(Token.fromJson(account.tokenJson));
    SessionManager.instance.setPassword(account.password);
    SessionManager.instance.setLogin(true);

    // Refresh profile + re-register this device's push token for the
    // newly active account.
    UserService.instance.fetchUserDetails(forceRefresh: true);
    UserService.instance.syncDeviceToken();

    await Get.offAll(() =>
        DashboardScreen(myUser: SessionManager.instance.getUser()));
  }

  /// "Add account" — park the current session (it stays in saved_accounts)
  /// and go to the login screen for a fresh login.
  Future<void> addAccount() async {
    saveCurrentSession();
    SessionManager.instance.clearSomeKey();
    await Get.offAll(() => const LoginScreen());
  }
}
