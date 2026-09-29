import 'dart:ui';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/utilities/app_res.dart';

class SessionManager {
  static var instance = SessionManager();
  var storage = GetStorage('shortzz');
  final List<VoidCallback> _subscriptions = [];
  var conversationId = '';
  RxInt notifyCount = 0.obs;
  RxInt isModerator = 0.obs;
  RxInt isVerify = 0.obs;
  RxInt isPlusActive = 0.obs;
  RxInt activeChatThemeId = 0.obs;
  RxString activeChatThemeBackgroundUrl = ''.obs;
  RxInt verificationStatus = (-1).obs; // -1 unknown, 0 pending, 1 approved, 2 rejected
  RxInt verificationRequestId = 0.obs;

  SessionManager() {
    listenNotifyCount();
    listenModerator();
    listenSubscription();
    listenPlus();
    listenChatTheme();
    listenVerification();
  }

  void _listen(String key, void Function(dynamic) callback) {
    final cancel = storage.listenKey(key, callback);
    _subscriptions.add(cancel);
  }

  void dispose() {
    for (final cancel in _subscriptions) {
      cancel();
    }
    _subscriptions.clear();
  }

  void listenChatTheme() {
    activeChatThemeId.value = getActiveChatThemeId;
    activeChatThemeBackgroundUrl.value = getActiveChatThemeBackgroundUrl ?? '';
    _listen(SessionKeys.activeChatThemeId, (value) {
      activeChatThemeId.value = value ?? 0;
    });
    _listen(SessionKeys.activeChatThemeBackgroundUrl, (value) {
      activeChatThemeBackgroundUrl.value = value?.toString() ?? '';
    });
  }

  int get getActiveChatThemeId => storage.read(SessionKeys.activeChatThemeId) ?? 0;

  String? get getActiveChatThemeBackgroundUrl => storage.read(SessionKeys.activeChatThemeBackgroundUrl);

  void setActiveChatTheme({required int themeId, String? backgroundImageUrl}) {
    storage.write(SessionKeys.activeChatThemeId, themeId);
    storage.write(SessionKeys.activeChatThemeBackgroundUrl, backgroundImageUrl);
  }

  void listenVerification() {
    verificationStatus.value = getVerificationStatus;
    verificationRequestId.value = getVerificationRequestId;
    _listen(SessionKeys.verificationStatus, (value) {
      verificationStatus.value = value ?? -1;
    });
    _listen(SessionKeys.verificationRequestId, (value) {
      verificationRequestId.value = value ?? 0;
    });
  }

  int get getVerificationStatus => storage.read(SessionKeys.verificationStatus) ?? -1;
  int get getVerificationRequestId => storage.read(SessionKeys.verificationRequestId) ?? 0;

  void setVerificationState({int? status, int? requestId}) {
    if (status != null) storage.write(SessionKeys.verificationStatus, status);
    if (requestId != null) storage.write(SessionKeys.verificationRequestId, requestId);
  }

  void setAuthToken(Token? token) {
    storage.write(SessionKeys.authToken, token);
  }

  String getAuthToken() {
    return getToken()?.authToken ?? 'AUTH TOKEN EMPTY';
  }

  void setPassword(String? password) {
    storage.write(SessionKeys.password, password);
  }

  String? getPassword() {
    return storage.read(SessionKeys.password);
  }

  Token? getToken() {
    var token = storage.read(SessionKeys.authToken);
    if (token is Token?) {
      return token;
    } else {
      return Token.fromJson(token);
    }
  }

  void setNotifyCount(int count) {
    int oldCount = getNotifyCount;
    oldCount += count;
    storage.write(SessionKeys.notifyCount, oldCount);
  }

  int get getNotifyCount {
    return storage.read(SessionKeys.notifyCount) ?? 0;
  }

  void listenNotifyCount() {
    notifyCount.value = getNotifyCount;
    _listen(SessionKeys.notifyCount, (value) {
      notifyCount.value = value;
    });
  }

  void listenModerator() {
    isModerator.value = getUser()?.isModerator ?? 0;
    _listen(SessionKeys.user, (value) {
      User? user = value as User?;
      isModerator.value = user?.isModerator ?? 0;
    });
  }

  void listenSubscription() {
    isVerify.value = getUser()?.isVerify ?? 0;
    _listen(SessionKeys.user, (value) {
      User? user = value as User?;
      isVerify.value = user?.isVerify ?? 0;
    });
  }

  void listenPlus() {
    isPlusActive.value = getPlusActive;
    _listen(SessionKeys.plusActive, (value) {
      isPlusActive.value = value ?? 0;
    });
  }

  void setPlusState({
    required int subscriptionEnabled,
    required int isPlusActive,
    String? expiresAt,
    Map<String, dynamic>? features,
  }) {
    storage.write(SessionKeys.subscriptionEnabled, subscriptionEnabled);
    storage.write(SessionKeys.plusActive, isPlusActive);
    storage.write(SessionKeys.plusExpiresAt, expiresAt);
    storage.write(SessionKeys.plusFeatures, features);
  }

  int get getSubscriptionEnabled => storage.read(SessionKeys.subscriptionEnabled) ?? 0;

  int get getPlusActive => storage.read(SessionKeys.plusActive) ?? 0;

  String? get getPlusExpiresAt => storage.read(SessionKeys.plusExpiresAt);

  DateTime? get getPlusExpiresAtDate {
    final raw = (getPlusExpiresAt ?? '').trim();
    if (raw.isEmpty) return null;
    try {
      return DateTime.tryParse(raw) ??
          DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  bool get isPlusExpired {
    final exp = getPlusExpiresAtDate;
    if (exp == null) return false;
    return !exp.isAfter(DateTime.now());
  }

  bool get isPlusEffectiveActive {
    if (getPlusActive != 1) return false;
    return !isPlusExpired;
  }

  Map<String, dynamic>? get getPlusFeatures {
    final v = storage.read(SessionKeys.plusFeatures);
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }

  bool hasPlusFeature(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;
    final features = getPlusFeatures;
    if (features == null || features.isEmpty) return false;

    final v = features[k];
    if (v is bool) return v;
    if (v is num) return v.toInt() == 1;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == '1' || s == 'true' || s == 'yes') return true;
      if (s == '0' || s == 'false' || s == 'no') return false;
    }

    final list = features['features'];
    if (list is List) {
      return list.whereType<String>().any((e) => e.trim() == k);
    }
    return false;
  }

  bool get isExclusiveStickersEnabled => hasPlusFeature('exclusive_stickers');

  bool get isChatThemesEnabled =>
      hasPlusFeature('chat_themes') ||
      hasPlusFeature('custom_chat_theme') ||
      hasPlusFeature('chat_theme') ||
      hasPlusFeature('chat_theme_enabled') ||
      (getSubscriptionEnabled == 1 && getPlusActive == 1);

  bool get isVidsAiFreeEnabled => hasPlusFeature('vids_ai_free');

  bool get isAdmin {
    return getUser()?.isAdmin ?? false;
  }

  bool hasPermission(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;
    if (isAdmin) return true;

    final p = getUser()?.permissions ?? const <String>[];
    return p.contains(k);
  }

  void setUser(User? user) {
    if (user != null) {
      // Convert the object to a JSON map and set 'stories' to null
      Map<String, dynamic> json = user.toJson();
      json['stories'] = null;

      // Re-create the User object from the modified JSON map
      User newUser = User.fromJson(json);

      // Log the updated user object and store it
      // Loggers.success(user.toJson());
      storage.write(SessionKeys.user, newUser);
    }
  }

  User? getUser() {
    var user = storage.read(SessionKeys.user);

    if (user == null || user is User?) {
      return user;
    } else if (user is Map<String, dynamic>) {
      return User.fromJson(user);
    } else {
      return null;
    }
  }

  int getUserID() {
    return (getUser()?.id ?? 0).toInt();
  }

  String getCurrency() {
    return getSettings()?.currency ?? AppRes.currency;
  }

  void setSettings(Setting settings) {
    storage.write(SessionKeys.setting, settings.toJson());
  }

  Setting? getSettings() {
    var data = storage.read(SessionKeys.setting);
    if (data is Map<String, dynamic>) {
      return Setting.fromJson(data);
    } else if (data is Setting) {
      return data;
    }
    return null;
  }

  void setLang(String langCode) {
    storage.write(SessionKeys.lang, langCode);
    UserService.instance.updateUserDetails(appLanguage: langCode);
  }

  String getLang() {
    return storage.read(SessionKeys.lang) ?? getFallbackLang();
  }

  void setFallbackLang(String langCode) {
    storage.write(SessionKeys.fallbackLang, langCode);
  }

  String getFallbackLang() {
    return storage.read(SessionKeys.fallbackLang) ?? 'en';
  }

  DateTime? getLastMessageReadDate({required String spaceId}) {
    var date = storage.read(spaceId);
    if (date is DateTime) {
      return date;
    } else {
      return null;
    }
  }

  void setLastMessageReadDate({required String spaceId}) {
    storage.write(spaceId, DateTime.now());
  }

  bool isLogin() {
    return storage.read(SessionKeys.isLogin) ?? false;
  }

  void setLogin(bool isLog) {
    storage.write(SessionKeys.isLogin, true);
  }

  bool get shouldOpenEULASheet {
    return storage.read(SessionKeys.shouldOpenEULA) ?? true;
  }

  Future<void> setOpenEulaSheet(bool isLog) async {
    await storage.write(SessionKeys.shouldOpenEULA, isLog);
  }

  Future<void> setBool(String key, bool value) async {
    await storage.write(key, value);
  }

  Future<void> setSmartSuggestionsEnabled(bool enabled) async {
    await storage.write(SessionKeys.smartSuggestionsEnabled, enabled);
  }

  bool getSmartSuggestionsEnabled() {
    return storage.read(SessionKeys.smartSuggestionsEnabled) ?? false;
  }

  Future<void> setVoiceCommandsEnabled(bool enabled) async {
    await storage.write(SessionKeys.voiceCommandsEnabled, enabled);
  }

  bool getVoiceCommandsEnabled() {
    return storage.read(SessionKeys.voiceCommandsEnabled) ?? false;
  }

  bool getBool(String key) {
    return storage.read(key) ?? false;
  }

  String _callCooldownKey(int otherUserId) => 'call_cooldown_until_$otherUserId';

  DateTime? getCallCooldownUntil({required int otherUserId}) {
    final raw = storage.read(_callCooldownKey(otherUserId));
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      final v = int.tryParse(raw);
      if (v != null) return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return null;
  }

  Future<void> setCallCooldownUntil({required int otherUserId, required DateTime until}) async {
    await storage.write(_callCooldownKey(otherUserId), until.millisecondsSinceEpoch);
  }

  int callCooldownRemainingSeconds({required int otherUserId}) {
    final until = getCallCooldownUntil(otherUserId: otherUserId);
    if (until == null) return 0;
    final diff = until.difference(DateTime.now());
    final seconds = diff.inSeconds;
    return seconds > 0 ? seconds : 0;
  }

  void clear() {
    storage.erase();
  }

  void clearSomeKey() {
    storage.remove(SessionKeys.isLogin);
    storage.remove(SessionKeys.user);
    storage.remove(SessionKeys.authToken);
    storage.remove(SessionKeys.password);
    storage.remove(SessionKeys.notifyCount);
    storage.remove(SessionKeys.fallbackLang);
    storage.remove(SessionKeys.lang);
  }
}

class SessionKeys {
  static const isLogin = "login";
  static const shouldOpenEULA = "should_open_eula";
  static const fallbackLang = "fallback_lang";
  static const lang = "lang";
  static const setting = "setting";
  static const user = "user";
  static const authToken = "authToken";
  static const password = "password";
  static const notifyCount = "notify_count";
  static const isLanguageScreenSelect = "is_language_screen_select";
  static const isOnBoardingScreenSelect = "is_on_boarding_screen_select";
  static const subscriptionEnabled = "subscription_enabled";
  static const plusActive = "is_plus_active";
  static const plusExpiresAt = "plus_expires_at";
  static const plusFeatures = "plus_features";
  static const activeChatThemeId = "active_chat_theme_id";
  static const activeChatThemeBackgroundUrl = "active_chat_theme_background_url";
  static const verificationStatus = "verification_status_code";
  static const verificationRequestId = "verification_request_id";

  static const splashWindowStartMs = "splash_window_start_ms";
  static const splashShowCount = "splash_show_count";

  static const smartSuggestionsEnabled = "smart_suggestions_enabled";
  static const voiceCommandsEnabled = "voice_commands_enabled";
}
