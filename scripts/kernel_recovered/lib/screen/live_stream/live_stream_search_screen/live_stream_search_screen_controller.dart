import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/controller/professional_controller.dart';
import 'package:shortzz/common/extensions/list_extension.dart';
import 'package:shortzz/common/extensions/user_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/config_service.dart';
import 'package:shortzz/common/service/api/livekit_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/live_stream/create_live_stream_screen/create_live_stream_screen.dart';
import 'package:shortzz/screen/live_stream/live_stream_search_screen/live_stream_feed_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/host/livestream_host_screen.dart';
import 'package:shortzz/screen/live_stream/livekit/livekit_audience_screen.dart';
import 'package:shortzz/screen/live_stream/livekit/livekit_host_screen.dart';
import 'package:shortzz/utilities/firebase_const.dart';

class LiveStreamSearchScreenController extends BaseController {
  FirebaseFirestore db = FirebaseFirestore.instance;
  RxList<Livestream> livestreamList = <Livestream>[].obs;
  RxList<Livestream> livestreamFilterList = <Livestream>[].obs;

  final RxBool isJoining = false.obs;
  final RxString joiningRoomId = ''.obs;
  StreamSubscription<QuerySnapshot<Livestream>>? livestreamListListener;

  final RxInt selectedCategoryIndex = 0.obs;
  String _searchQuery = '';

  Worker? _usersWorker;

  bool _started = false;

  String _cachedLiveProvider = '';

  Timer? _navLockTimer;
  String _navLockedRoomId = '';

  // If a livestream doc is older than this and still present, treat as stale/ghost.
  // This prevents showing ended lives when host app crashed and never deleted the doc.
  static const int _staleLiveMs = 6 * 60 * 60 * 1000; // 6 hours

  final firebaseFirestoreController = Get.find<FirebaseFirestoreController>();

  Setting? get setting => SessionManager.instance.getSettings();

  RxList<DummyLive> get dummyLives => (setting?.dummyLives ?? []).obs;

  String _viewerTypeCache = '';
  int? _viewerEnabledCache;
  bool _viewerProFetched = false;

  final Map<int, AppUser> _hostUserCache = <int, AppUser>{};
  final Set<int> _hostUserFetchInFlight = <int>{};

  bool _applyFiltersScheduled = false;

  AppUser? get _viewerAppUser {
    final uid = SessionManager.instance.getUserID();
    if (uid <= 0) return null;
    return firebaseFirestoreController.users
        .firstWhereOrNull((e) => e.userId == uid);
  }

  String get _viewerType {
    final fromCache = _viewerTypeCache.trim().toLowerCase();
    if (fromCache.isNotEmpty) return fromCache;
    return (_viewerAppUser?.professionalType ?? '').toString().trim().toLowerCase();
  }

  bool get isMinerViewer {
    return _viewerType == 'miner';
  }

  int? get _viewerEnabled {
    final c = _viewerEnabledCache;
    if (c != null) return c;
    return _viewerAppUser?.professionalEnabled;
  }

  Future<void> _ensureViewerProfessionalCached({bool forceRefresh = false}) async {
    if (_viewerProFetched && !forceRefresh) return;
    final uid = SessionManager.instance.getUserID();
    if (uid <= 0) return;
    try {
      _viewerProFetched = true;
      final snap = await db.collection(FirebaseConst.appUsers).doc('$uid').get();
      final data = snap.data();
      if (data == null) {
        // Allow retry later.
        if (forceRefresh) _viewerProFetched = false;
        return;
      }

      final rawType = data['professional_type'] ??
          data['dashboard_type'] ??
          data['professionalType'] ??
          data['user_type'] ??
          data['type'];
      final t = '${rawType ?? ''}'.trim().toLowerCase();
      if (t.isNotEmpty) {
        _viewerTypeCache = t;
      }

      final rawEnabled = data['professional_enabled'] ??
          data['professionalEnabled'] ??
          data['is_professional'] ??
          data['isProfessional'];
      if (rawEnabled is bool) {
        _viewerEnabledCache = rawEnabled ? 1 : 0;
      } else if (rawEnabled is num) {
        _viewerEnabledCache = rawEnabled.toInt();
      } else if (rawEnabled is String) {
        _viewerEnabledCache = int.tryParse(rawEnabled.trim()) ?? 0;
      }

      debugPrint(
          '[LIVE_LIST][VIEWER_PRO] uid=$uid typeCache="$_viewerTypeCache" enabledCache=${_viewerEnabledCache ?? 'null'} rawKeys=${data.keys.toList()}');
    } catch (_) {
      // ignore
      if (forceRefresh) _viewerProFetched = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _startIfNeeded();
  }

  void _startIfNeeded() {
    if (_started) return;
    _started = true;
    debugPrint('[LIVE_LIST] controller start');
    // Cache provider early to reduce join latency on first tap.
    ConfigService.instance
        .getLiveProvider(forceRefresh: false)
        .then((v) => _cachedLiveProvider = v.trim().toLowerCase())
        .catchError((_) => '');
    Future.wait({fetchLiveStreams(), addDummyUsers()});
  }

  @override
  void onReady() {
    super.onReady();
    debugPrint('[LIVE_LIST] controller onReady');
    _startIfNeeded();

    _ensureDefaultCategoryForViewer();

    // Firestore fallback for viewer pro type/enabled (app_users can load late).
    Future(() async {
      await _ensureViewerProfessionalCached();
      _ensureDefaultCategoryForViewer();
      _scheduleApplyFilters();
    });

     // Re-assign host users when app_users list updates (otherwise category filters
     // can hide everything until the next livestream snapshot update).
    _usersWorker = ever<List<AppUser>>(
      firebaseFirestoreController.users,
      (_) => _assignHostUsersToStreams(),
    );
  }

  void _ensureDefaultCategoryForViewer() {
    // Always default to All so professionals can discover each other's live streams.
    // Users can still manually filter via tabs.
    const targetIndex = 0;
    if (selectedCategoryIndex.value != targetIndex) {
      selectedCategoryIndex.value = targetIndex;
      _scheduleApplyFilters();
    }
  }

  void setCategory(int index) {
    selectedCategoryIndex.value = index;
    debugPrint('[LIVE_LIST] setCategory index=$index');
    _scheduleApplyFilters();
  }

  @override
  void onClose() {
    super.onClose();
    livestreamListListener?.cancel();
    _usersWorker?.dispose();
    _navLockTimer?.cancel();
  }

  Future<void> refreshLiveStreams() async {
    livestreamListListener?.cancel();
    livestreamListListener = null;
    livestreamList.clear();
    livestreamFilterList.clear();
    await fetchLiveStreams();
  }

  Future<void> fetchLiveStreams() async {
    isLoading.value = true;
    await Future.delayed(const Duration(milliseconds: 50));

    final uid = SessionManager.instance.getUserID();
    debugPrint(
        '[LIVE_LIST] attaching listener collection=${FirebaseConst.liveStreams} viewer(uid=$uid type="$_viewerType" enabled=${_viewerEnabled ?? 'null'})');

    livestreamListListener = db
        .collection(FirebaseConst.liveStreams)
        .withConverter(
          fromFirestore: (snapshot, options) =>
              Livestream.fromJson(snapshot.data()!),
          toFirestore: (Livestream livestream, options) => livestream.toJson(),
        )
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final items = <Livestream>[];
      for (final d in snapshot.docs) {
        final s = d.data();
        if ((s.roomID ?? '').isEmpty) continue;

        // Filter out stale/ghost lives (common when host app is killed).
        final createdAt = s.createdAt;
        final isStale = createdAt != null && (now - createdAt) > _staleLiveMs;
        if (isStale && s.type != LivestreamType.dummy) {
          final hostId = s.hostId;
          if (hostId != null) {
            // Fire-and-forget cleanup.
            deleteStreamOnFirebase(hostId);
          }
          continue;
        }
        items.add(s);
      }

      livestreamList.value = items;
      if (items.isNotEmpty) {
        final s = items.first;
        Loggers.info(
            '[LIVE_LIST] docs=${items.length} sample(room=${s.roomID} host=${s.hostId} type=${s.type?.value})');
        debugPrint(
            '[LIVE_LIST] docs=${items.length} sample(room=${s.roomID} host=${s.hostId} type=${s.type?.value})');
      } else {
        Loggers.info('[LIVE_LIST] docs=0');
        debugPrint('[LIVE_LIST] docs=0');
      }
      _scheduleApplyFilters();
      // Perform any additional cleanup or transformations
      removeDummyLive();

      _assignHostUsersToStreams();
      isLoading.value = false; // Hide loader after initial fetch
    }, onError: (error) {
      isLoading.value = false;
      if (error is FirebaseException && error.code == 'permission-denied') {
        Loggers.error('Firestore permission denied (liveStreams): $error');
        debugPrint('[LIVE_LIST] Firestore permission denied (liveStreams): $error');
        showSnackBar('Live streams access denied');
        livestreamListListener?.cancel();
        return;
      }
      Loggers.error('Firestore liveStreams listener error: $error');
      debugPrint('[LIVE_LIST] Firestore liveStreams listener error: $error');
    });
  }

  void _assignHostUsersToStreams() {
    final userMap = _userMapFromList(firebaseFirestoreController.users);
    final missingHostIds = <int>{};
    for (var stream in livestreamList) {
      final hid = stream.hostId;
      if (hid == null || hid <= 0) continue;

      final resolved = userMap[hid] ?? _hostUserCache[hid];
      stream.hostUser = resolved;

      if (resolved == null || _normType(resolved).isEmpty) {
        missingHostIds.add(hid);
      }
    }
    if (missingHostIds.isNotEmpty) {
      _fetchHostUsersFromFirestore(missingHostIds);
    }
    _scheduleApplyFilters();
  }

  void _fetchHostUsersFromFirestore(Set<int> hostIds) {
    for (final id in hostIds) {
      if (id <= 0) continue;
      if (_hostUserCache.containsKey(id)) continue;
      if (_hostUserFetchInFlight.contains(id)) continue;
      _hostUserFetchInFlight.add(id);

      db.collection(FirebaseConst.appUsers).doc('$id').get().then((snap) {
        final data = snap.data();
        if (data == null) return;
        final u = AppUser.fromJson(data);
        final uid = u.userId;
        if (uid != null && uid > 0) {
          _hostUserCache[uid] = u;
        } else {
          _hostUserCache[id] = u;
        }
      }).catchError((_) {}).whenComplete(() {
        _hostUserFetchInFlight.remove(id);
        // Re-apply so category tabs update as soon as host types arrive.
        _scheduleApplyFilters();
      });
    }
  }

  void _scheduleApplyFilters() {
    if (_applyFiltersScheduled) return;
    _applyFiltersScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFiltersScheduled = false;
      _applyFilters();
    });
  }

  String _normType(AppUser? u) {
    final t = (u?.professionalType ?? '').toString().trim().toLowerCase();
    return t;
  }

  bool _matchesCategory(Livestream s) {
    // All tab: show all (including miner), but never show unknown/empty type.
    // Category tabs (Creators/Astrologers/Business): filter by host professionalType.
    final selected = selectedCategoryIndex.value;
    final isAllTab = selected == 0;
    if (!isAllTab) {
      // Never show dummy/glitch lives inside category tabs.
      if (s.type == LivestreamType.dummy) return false;
    }
    // hostUser can be null briefly if app_users list hasn't loaded/assigned yet.
    // In that case, lookup from the shared users list to avoid category leakage.
    final hid = s.hostId;
    final u = s.hostUser ??
        (hid == null
            ? null
            : (firebaseFirestoreController.users
                    .firstWhereOrNull((e) => e.userId == hid) ??
                _hostUserCache[hid]));
    final t = _normType(u);
    // If we can't resolve host user yet (app_users not loaded / doc missing),
    // don't hide the live from the All tab. Otherwise the list can look empty.
    if (u == null) {
      if (!isAllTab && hid != null && hid > 0) {
        _fetchHostUsersFromFirestore({hid});
      }
      return isAllTab;
    }

    // If backend hasn't set professional type yet, still show in All tab.
    // Category tabs remain strict.
    if (t.isEmpty) {
      if (!isAllTab && hid != null && hid > 0) {
        _fetchHostUsersFromFirestore({hid});
      }
      return isAllTab;
    }

    if (isAllTab) {
      return true;
    }

    // Miner lives should only be visible in All tab.
    if (t == 'miner') return false;

    switch (selectedCategoryIndex.value) {
      case 1: // Creators
        // Creators should not be blocked by professional_enabled.
        // Don't leak professional lives into creators.
        if (t.contains('business') || t.contains('astrologer') || t.contains('astro')) {
          return false;
        }
        return t == 'creator' || t == 'creator_miner';
      case 2: // Astrologers
        // If professional_enabled is missing/null, treat as enabled.
        if ((u.professionalEnabled ?? 1) != 1) return false;
        // Must be explicit astrologer type.
        return t == 'astrologer' || t.contains('astrologer') || t.contains('astro');
      case 3: // Business
        // If professional_enabled is missing/null, treat as enabled.
        if ((u.professionalEnabled ?? 1) != 1) return false;
        // Must be explicit business type.
        return t == 'business' || t.contains('business');
      default:
        return true;
    }
  }

  Future<void> onGoLive() async {
    // Force refresh because user might have just enabled Professional mode.
    await _ensureViewerProfessionalCached(forceRefresh: true);
    var viewerType = _viewerType;
    // If professional_enabled is missing/null, treat as enabled.
    var viewerEnabled = _viewerEnabled ?? 1;

    // Strong fallback: Professional Dashboard state should not be blocked by stale app_users.
    try {
      if (Get.isRegistered<ProfessionalController>()) {
        final pc = Get.find<ProfessionalController>();
        final t = (pc.stats.value?.professionalType ?? '').trim().toLowerCase();
        if (viewerType.isEmpty && t.isNotEmpty) {
          viewerType = t;
        }
        if (viewerEnabled != 1 && pc.stats.value != null) {
          viewerEnabled = pc.stats.value!.professionalEnabled ? 1 : 0;
        }
      }
    } catch (_) {}

    // Final fallback: fetch from backend (authoritative) if Firestore/app_users is stale.
    if (viewerType.isEmpty || viewerEnabled != 1) {
      try {
        final s = await UserService.instance.professionalStats();
        // IMPORTANT: do not rely on ProfessionalStatsModel.professionalType defaulting to 'creator'.
        dynamic raw = s.data?['professional_type'] ??
            s.data?['type'] ??
            s.data?['professionalType'] ??
            s.data?['dashboard_type'] ??
            s.data?['user_type'] ??
            s.data?['userType'];
        if (raw == null) {
          final u = s.data?['user'];
          if (u is Map) {
            raw = u['professional_type'] ?? u['type'] ?? u['user_type'] ?? u['userType'] ?? u['dashboard_type'];
          }
        }
        if (raw == null) {
          final p = s.data?['profile'];
          if (p is Map) {
            raw = p['professional_type'] ?? p['type'] ?? p['user_type'] ?? p['userType'] ?? p['dashboard_type'];
          }
        }
        final t = '${raw ?? ''}'.trim().toLowerCase();
        if (viewerType.isEmpty && t.isNotEmpty) viewerType = t;
        if (viewerEnabled != 1) {
          viewerEnabled = s.professionalEnabled ? 1 : 0;
        }
      } catch (_) {}
    }
    debugPrint(
        '[LIVE_LIST][GO_LIVE] type="$viewerType" enabled=$viewerEnabled appUserType="${_viewerAppUser?.professionalType}" appUserEnabled=${_viewerAppUser?.professionalEnabled}');
    if (viewerType.isEmpty) {
      showSnackBar('Please enable Professional Mode first');
      return;
    }
    // Strict: if professional is not enabled, do not allow going live (for any type).
    if (viewerEnabled != 1) {
      showSnackBar('Please enable Professional Mode first');
      return;
    }

    User? myUser = SessionManager.instance.getUser();
    bool isExist = livestreamList.any((element) => element.hostId == myUser?.id);
    if (myUser?.isDummy == 1 && isExist) {
      showLoader();
      await deleteStreamOnFirebase(myUser?.id);
      stopLoader();
    }

    Get.to(() => const CreateLiveStreamScreen());
  }

  void _applyFilters() {
    final base = livestreamList.toList();
    final filtered = base.where(_matchesCategory).toList();
    filtered.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    final q = _searchQuery.trim();

    if (base.isNotEmpty) {
      final s = base.first;
      final u = s.hostUser;
      debugPrint(
          '[LIVE_LIST] filter tab=${selectedCategoryIndex.value} base=${base.length} afterCategory=${filtered.length} q="$q" sample(host=${s.hostId} room=${s.roomID} dummy=${s.isDummyLive} proType=${u?.professionalType} proEnabled=${u?.professionalEnabled})');
    } else {
      debugPrint(
          '[LIVE_LIST] filter tab=${selectedCategoryIndex.value} base=0 afterCategory=0 q="$q"');
    }

    if (q.isEmpty) {
      livestreamFilterList.value = filtered;
      return;
    }
    livestreamFilterList.value = filtered.search(q, (p0) {
      return p0.hostUser?.username ?? '';
    }, (p1) => p1.description ?? '');
  }

  Map<int, AppUser> _userMapFromList(List<AppUser> list) {
    return {
      for (var user in list)
        if (user.userId != null) user.userId!: user,
    };
  }

  void onLiveUserTap(Livestream stream) async {
    final roomId = (stream.roomID ?? '').trim();

    debugPrint('[LIVE_TAP] room=$roomId host=${stream.hostId} type=${stream.type?.value}');

    if (roomId.isEmpty) {
      return;
    }

    if (isJoining.value) {
      debugPrint('[LIVE_TAP] blocked: isJoining=true joiningRoom=${joiningRoomId.value}');
      return;
    }
    if (joiningRoomId.value.isNotEmpty && joiningRoomId.value == roomId) {
      debugPrint('[LIVE_TAP] blocked: joiningRoomId already same=$roomId');
      return;
    }

    // Short lock to prevent double navigation for the same room.
    if (_navLockedRoomId == roomId) {
      return;
    }
    _navLockedRoomId = roomId;
    _navLockTimer?.cancel();
    _navLockTimer = Timer(const Duration(milliseconds: 350), () {
      if (_navLockedRoomId == roomId) _navLockedRoomId = '';
    });

    isJoining.value = true;
    joiningRoomId.value = roomId;
    try {
      // IMPORTANT: do not await network/config on tap; it makes the first tap feel stuck.
      // We cache provider in _startIfNeeded(). If it's still empty, fall back to local setting.
      var provider = _cachedLiveProvider;
      if (provider.isEmpty) provider = (setting?.liveProvider ?? '').trim().toLowerCase();
      debugPrint('[LIVE_TAP] provider=$provider cached="$_cachedLiveProvider"');
      if (provider == 'livekit') {
        debugPrint('[LIVEKIT_JOIN] start room=$roomId');
        await _joinLiveKit(stream);
        debugPrint('[LIVEKIT_JOIN] done room=$roomId');
        _navLockedRoomId = '';
        return;
      }
      User? myUser = SessionManager.instance.getUser();
      if (stream.hostId == myUser?.id) {
        Future.microtask(() {
          debugPrint('[LIVE_NAV] host -> LivestreamHostScreen room=$roomId');
          Get.to(() => LivestreamHostScreen(isHost: true, livestream: stream));
        });
      } else {
        final idx = livestreamFilterList.indexWhere((e) => e.roomID == stream.roomID);
        Future.microtask(() {
          debugPrint('[LIVE_NAV] audience -> LiveStreamFeedScreen room=$roomId idx=$idx');
          Get.to(() => LiveStreamFeedScreen(
                controller: this,
                initialIndex: idx < 0 ? 0 : idx,
              ));
        });
      }
      _navLockedRoomId = '';
    } catch (e) {
      debugPrint('[LIVE_NAV] error room=$roomId err=$e');
      Loggers.error('[LIVE_NAV] error room=$roomId err=$e');
      if (_navLockedRoomId == roomId) _navLockedRoomId = '';
    } finally {
      isJoining.value = false;
      joiningRoomId.value = '';
    }
  }

  Future<void> _joinLiveKit(Livestream stream) async {
    final wsUrl = (setting?.livekitWsUrl ?? '').trim();
    if (wsUrl.isEmpty) {
      showSnackBar('LiveKit is selected but not configured');
      return;
    }

    final user = SessionManager.instance.getUser();
    final userId = user?.id ?? -1;
    if (user == null || userId <= 0) {
      showSnackBar('User not found');
      return;
    }

    final isMyHostedLive = (stream.hostId ?? -1) == userId;

    final roomName = (stream.roomID ?? stream.hostId?.toString() ?? '').trim();
    if (roomName.isEmpty) {
      showSnackBar('Invalid live room');
      return;
    }

    showLoader(barrierDismissible: false);
    try {
      final tokenResp = await LiveKitService.instance.generateToken(
        roomName: roomName,
        userIdentity: userId.toString(),
        userName: (user.username ?? user.fullname ?? '').toString(),
      );
      if (tokenResp == null || tokenResp.token.trim().isEmpty) {
        showSnackBar('Failed to generate LiveKit token');
        return;
      }

      final t = tokenResp.token.trim();
      final masked =
          t.length <= 16 ? '***' : '${t.substring(0, 8)}...${t.substring(t.length - 6)}';
      Loggers.info(
          '[LIVEKIT] viewer token generated room=${tokenResp.roomName} url=${tokenResp.livekitUrl} token=$masked');

      final url = tokenResp.livekitUrl.isNotEmpty ? tokenResp.livekitUrl : wsUrl;
      // IMPORTANT: close loader before navigation, otherwise closing the loader can pop the new route.
      stopLoader();
      if (isMyHostedLive) {
        Get.to(() => LiveKitHostScreen(
              livestream: stream,
              url: url,
              token: tokenResp.token,
            ));
      } else {
        Get.to(() => LiveKitAudienceScreen(
              livestream: stream,
              url: url,
              token: tokenResp.token,
            ));
      }
    } catch (e) {
      Loggers.error('[LIVEKIT] viewer token failed: $e');
      showSnackBar('LiveKit token error');
    } finally {
      stopLoader();
    }
  }

  onSearchChange(String value) {
    _searchQuery = value;
    _scheduleApplyFilters();
  }

  Future<void> addDummyUsers() async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      // Fetch existing livestreams from Firestore
      final livestreamList = await db
          .collection(FirebaseConst.liveStreams)
          .withConverter<Livestream>(
            fromFirestore: (snapshot, _) =>
                Livestream.fromJson(snapshot.data()!),
            toFirestore: (livestream, _) => livestream.toJson(),
          )
          .get();

      // Collect existing stream IDs
      final existingIds = livestreamList.docs.map((doc) => doc.id).toSet();

      for (var dummy in dummyLives) {
        final dummyId = dummy.userId;

        // Skip invalid IDs
        if (dummyId == -1) continue;

        final alreadyExists = existingIds.contains('$dummyId');
        if (!alreadyExists && dummy.status == 1) {
          // Create new dummy livestream
          await createLiveStream(dummy);
          Loggers.info('✅ Created dummy livestream: $dummyId');
        } else if (alreadyExists && dummy.status == 0) {
          // Delete if status is inactive
          await deleteStreamOnFirebase(dummyId);
          Loggers.info('🗑️ Deleted inactive dummy livestream: $dummyId');
        } else {
          Loggers.info(
              'ℹ️ No action for: $dummyId (exists: $alreadyExists, status: ${dummy.status})');
        }
      }
    } catch (e, _) {
      Loggers.error('❌ Error in addDummyUsers: $e');
    }
  }

  Future<void> createLiveStream(DummyLive? dummyLive) async {
    User? dummyUser = dummyLive?.user;
    if (dummyUser == null) {
      Loggers.error('Dummy User Not found');
      return;
    }
    int userId = dummyLive?.userId ?? -1;

    DocumentReference livestreamRef =
        db.collection(FirebaseConst.liveStreams).doc('$userId');

    int time = DateTime.now().millisecondsSinceEpoch;

    // Livestream model
    Livestream livestream = dummyUser.livestream(
        type: LivestreamType.dummy,
        time: time,
        dummyUserLink: dummyLive?.link,
        isDummyLive: 1,
        description: dummyLive?.title);

    // LivestreamUser model
    AppUser? livestreamUser = dummyUser.appUser;

    // LivestreamUserState model
    LivestreamUserState livestreamUserState =
        dummyUser.streamState(time: time, stateType: LivestreamUserType.host);

    try {
      DocumentReference usersRef =
          db.collection(FirebaseConst.appUsers).doc('$userId');
      DocumentReference userStateRef =
          livestreamRef.collection(FirebaseConst.userState).doc('$userId');

      WriteBatch batch = db.batch();

      bool isExist = (await livestreamRef.get()).exists;
      bool isUserExist = (await usersRef.get()).exists;

      if (isExist) {
        // Update existing documents
        batch.update(livestreamRef, livestream.toJson());
        batch.update(userStateRef, livestreamUserState.toJson());
      } else {
        // Create new documents
        batch.set(livestreamRef, livestream.toJson());
        batch.set(userStateRef, livestreamUserState.toJson());
      }
      if (isUserExist) {
        batch.update(usersRef, livestreamUser.toJson());
      } else {
        batch.set(usersRef, livestreamUser.toJson());
      }

      await batch.commit();
      Loggers.success(isExist ? 'Updated Dummy Live' : 'Created Dummy Live');
    } catch (e, stackTrace) {
      Loggers.error('Failed to create/update live stream: $e');
      Loggers.error('StackTrace: $stackTrace');
    }
  }

  Future<void> deleteStreamOnFirebase(int? dummyUserId) async {
    if (dummyUserId == null) return;

    final String roomId = dummyUserId.toString();

    final DocumentReference livestreamRef =
        db.collection(FirebaseConst.liveStreams).doc(roomId);

    final CollectionReference usersStateRef =
        livestreamRef.collection(FirebaseConst.userState);

    final CollectionReference commentsRef =
        livestreamRef.collection(FirebaseConst.comments);

    try {
      // Fetch both collections in parallel
      final results = await Future.wait([
        usersStateRef.get(),
        commentsRef.get(),
      ]);

      final QuerySnapshot usersSnapshot = results[0];
      final QuerySnapshot commentsSnapshot = results[1];

      final WriteBatch batch = db.batch();

      // Queue deletions for user states
      for (final doc in usersSnapshot.docs) {
        batch.delete(doc.reference);
      }
      Loggers.info('Queued ${usersSnapshot.size} user state deletions.');

      // Queue deletions for comments
      for (final doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      Loggers.info('Queued ${commentsSnapshot.size} comment deletions.');

      // Delete the livestream document
      batch.delete(livestreamRef);

      // Commit all deletions in one batch
      await batch.commit();
      Loggers.success(
          'Deleted live stream, user states, and comments from Firestore.');
      Loggers.error('Live Stream Search Delete The Data');
    } catch (e, stackTrace) {
      Loggers.error('Failed to delete live stream: $e');
      Loggers.error('StackTrace: $stackTrace');
    }
  }

  void removeDummyLive() {
    final dummyStream =
        livestreamFilterList.where((e) => e.isDummyLive == 1).toList();
    if (dummyStream.isEmpty) return;
    if (setting?.liveDummyShow == 0) {
      for (var element in dummyStream) {
        deleteStreamOnFirebase(element.hostId);
      }
    } else {
      for (var element in dummyStream) {
        final shouldDelete = dummyLives.isEmpty ||
            !dummyLives.any((e) => e.userId == element.hostId);
        if (shouldDelete) {
          deleteStreamOnFirebase(element.hostId);
        }
      }
    }
  }
}
