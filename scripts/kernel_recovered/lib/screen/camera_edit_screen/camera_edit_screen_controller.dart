import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_native_video_trimmer/flutter_native_video_trimmer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:retrytech_plugin/retrytech_plugin.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/enum/chat_enum.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/functions/generate_color.dart';
import 'package:shortzz/common/functions/media_picker_helper.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/screenshot_manager.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/notification_service.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/sight_engin/sight_engine_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/post_story/story/story_model.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/screen/camera_screen/camera_screen.dart';
import 'package:shortzz/screen/camera_screen/camera_screen_controller.dart';
import 'package:shortzz/screen/chat_screen/chat_screen_controller.dart';
import 'package:shortzz/screen/color_filter_screen/widget/color_filtered.dart';
import 'package:shortzz/screen/create_feed_screen/create_feed_screen.dart';
import 'package:shortzz/screen/camera_edit_screen/text_story/story_text_view_controller.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:shortzz/screen/feed_screen/feed_screen_controller.dart';
import 'package:shortzz/screen/music_sheet/music_sheet.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/screen/selected_music_sheet/selected_music_sheet.dart';
import 'package:shortzz/screen/selected_music_sheet/selected_music_sheet_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:uuid/uuid.dart';

import 'package:shortzz/common/service/video_timeline/video_segment.dart';
import 'package:shortzz/common/service/video_timeline/video_timeline_service.dart';

import 'text_story/widget/text_editor_sheet.dart';

@immutable
class TimelineTextClip {
  final String id;
  final int startMs;
  final int durationMs;

  const TimelineTextClip({
    required this.id,
    required this.startMs,
    required this.durationMs,
  });

  TimelineTextClip copyWith({String? id, int? startMs, int? durationMs}) {
    return TimelineTextClip(
      id: id ?? this.id,
      startMs: startMs ?? this.startMs,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}

class EditorStateSnapshot {
  final List<VideoSegment> segments;
  final List<TimelineTextClip> textClips;
  final int musicStartMs;

  EditorStateSnapshot({
    required this.segments,
    required this.textClips,
    required this.musicStartMs,
  });
}

enum StoryAudience { public, closeFriends, aiMate }

class CameraEditScreenController extends BaseController {
  Rx<PostStoryContent> content;

  CameraEditScreenController(this.content);

  final Rx<StoryAudience> storyAudience = StoryAudience.public.obs;

  void setStoryAudience(StoryAudience audience) {
    storyAudience.value = audience;
  }

  final _dashboardController = Get.find<DashboardScreenController>();
  final _retrytechPlugin = RetrytechPlugin();
  UploadType _lastUploadType = UploadType.none;

  final RxBool isUploading = false.obs;

  Rx<List<double>> selectedFilter = Rx([]);
  Rx<VideoPlayerController?> videoPlayerController = Rx<VideoPlayerController?>(
    null,
  );
  List<LinearGradient> storyGradientColor = GenerateColor.instance.gradientList;

  PlayerController audioPlayer = PlayerController();

  final RxInt selectedFilterIndex = 0.obs;
  final RxString filterNameOverlay = ''.obs;
  Timer? _filterNameTimer;

  void nextFilter() {
    int next = selectedFilterIndex.value + 1;
    if (next >= filters.length) next = 0;
    _applyFilter(next);
  }

  void prevFilter() {
    int prev = selectedFilterIndex.value - 1;
    if (prev < 0) prev = filters.length - 1;
    _applyFilter(prev);
  }

  void _applyFilter(int index) {
    selectedFilterIndex.value = index;
    selectedFilter.value = filters[index].colorFilter;

    // Show overlay
    filterNameOverlay.value = filters[index].filterName;
    _filterNameTimer?.cancel();
    _filterNameTimer = Timer(const Duration(seconds: 2), () {
      filterNameOverlay.value = '';
    });
  }

  RxInt currentStoryDurationIndex = 0.obs;
  RxInt selectedBgIndex = 0.obs;
  int selectStorySecond = AppRes.storyDurations.first;

  Timer? _timer;
  bool _isRestartingPlayback = false;

  RxBool isFilterShow = false.obs;
  RxBool isMergingVideo = false.obs;
  bool hasAudio = true;

  final RxDouble trimStartSec = 0.0.obs;
  final RxDouble trimEndSec = 0.0.obs;
  final RxBool isTrimApplied = false.obs;
  final RxBool isTrimmingVideo = false.obs;
  final VideoTrimmer _videoTrimmer = VideoTrimmer();

  final RxDouble playbackSpeed = 1.0.obs;
  final RxDouble coverPositionSec = 0.0.obs;
  final RxBool isGeneratingCover = false.obs;
  final RxDouble videoVolume = 1.0.obs;
  final RxDouble musicVolume = 1.0.obs;

  void _syncExternalAudioPlaybackSpeed() {
    if (content.value.sound == null) return;

    final effectiveVideoSpeed =
        _shouldUseTimelinePlayback ? 1.0 : playbackSpeed.value;
    var rate = 1.0;
    if (effectiveVideoSpeed != 0.0) {
      rate = 1.0 / effectiveVideoSpeed;
    }
    rate = rate.clamp(0.5, 2.0);

    try {
      final ap = audioPlayer as dynamic;
      try {
        ap.setRate(rate);
        return;
      } catch (_) {}
      try {
        ap.setSpeed(rate);
        return;
      } catch (_) {}
    } catch (_) {}
  }

  final RxBool isVoiceoverRecording = false.obs;
  final RxnString voiceoverFilePath = RxnString();
  final RxDouble voiceoverVolume = 1.0.obs;
  final RxInt voiceoverStartMs = 0.obs;
  RecorderController? _voiceoverRecorder;

  final RxList<VideoSegment> segments = <VideoSegment>[].obs;
  final RxList<EditorStateSnapshot> _undoStack = <EditorStateSnapshot>[].obs;
  final RxList<EditorStateSnapshot> _redoStack = <EditorStateSnapshot>[].obs;

  void saveStateForUndo() => _saveStateForUndo();

  void _saveStateForUndo() {
    // Deep copy segments
    final segs =
        segments.map((s) => s.copyWith(edits: s.edits.copyWith())).toList();
    // Deep copy text clips
    final texts = textClips.map((t) => t.copyWith()).toList();
    // Save music start
    final musicStart = content.value.sound?.audioStartMS ?? 0;

    final snapshot = EditorStateSnapshot(
      segments: segs,
      textClips: texts,
      musicStartMs: musicStart,
    );

    _undoStack.add(snapshot);
    _redoStack.clear();

    if (_undoStack.length > 20) {
      _undoStack.removeAt(0);
    }
  }

  void undo() {
    if (_undoStack.isEmpty) return;

    // Save current state to redo stack
    final currentSegs =
        segments.map((s) => s.copyWith(edits: s.edits.copyWith())).toList();
    final currentTexts = textClips.map((t) => t.copyWith()).toList();
    final currentMusic = content.value.sound?.audioStartMS ?? 0;

    _redoStack.add(EditorStateSnapshot(
      segments: currentSegs,
      textClips: currentTexts,
      musicStartMs: currentMusic,
    ));

    final prev = _undoStack.removeLast();
    _restoreState(prev);
  }

  void redo() {
    if (_redoStack.isEmpty) return;

    // Save current state to undo stack
    final currentSegs =
        segments.map((s) => s.copyWith(edits: s.edits.copyWith())).toList();
    final currentTexts = textClips.map((t) => t.copyWith()).toList();
    final currentMusic = content.value.sound?.audioStartMS ?? 0;

    _undoStack.add(EditorStateSnapshot(
      segments: currentSegs,
      textClips: currentTexts,
      musicStartMs: currentMusic,
    ));

    final next = _redoStack.removeLast();
    _restoreState(next);
  }

  void _restoreState(EditorStateSnapshot snapshot) {
    segments.assignAll(snapshot.segments);
    textClips.assignAll(snapshot.textClips);

    if (content.value.sound != null) {
      content.update((val) {
        val?.sound?.audioStartMS = snapshot.musicStartMs;
      });
      // Seek audio player if needed
      audioPlayer.seekTo(snapshot.musicStartMs);
    }

    // Reset selection if out of bounds
    if (activeSegmentIndex.value >= segments.length) {
      activeSegmentIndex.value = segments.length - 1;
    }
    _scheduleTimelinePlaybackRebuild();
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  final RxInt activeSegmentIndex = 0.obs;
  final RxBool isTimelineExporting = false.obs;
  final RxBool isSplitting = false.obs;
  final RxBool isReplacingSegment = false.obs;
  final RxBool isCuttingSilences = false.obs;
  final RxDouble cutSilencesProgress = 0.0.obs;
  final RxString cutSilencesStage = ''.obs;
  final _uuid = const Uuid();

  Timer? _previewRenderDebounce;
  int _previewRenderRequestId = 0;

  Future<void> addSegmentFromGallery() async {
    final type = content.value.type;
    if (![
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(type)) {
      return;
    }

    try {
      final picker = ImagePicker();
      final x = await picker.pickVideo(source: ImageSource.gallery);
      if (x == null) return;
      final path = x.path;
      if (path.trim().isEmpty) return;

      final dur = await VideoTimelineService.shared.getDurationSec(path);
      final seg = VideoSegment(
        id: _uuid.v4(),
        path: path,
        originalPath: path,
        originalDurationSec: dur,
        durationSec: dur,
      );

      _saveStateForUndo(); // Save state before adding

      final newList = <VideoSegment>[...segments, seg];
      segments.assignAll(newList);
      await selectSegment(newList.length - 1);
    } catch (e) {
      Loggers.error('addSegmentFromGallery failed: $e');
      showSnackBar('Failed to add clip');
    }
  }

  void removeActiveSegment() {
    if (segments.isEmpty) return;
    if (segments.length == 1) {
      // If deleting the last/only segment, we might want to discard edits or clear everything.
      // For now, prevent deleting the last clip to avoid empty state issues.
      // Or we can allow it and exit editor mode.
      showSnackBar('Cannot delete the only clip. Discard instead?');
      return;
    }

    final idx = activeSegmentIndex.value;
    if (idx < 0 || idx >= segments.length) return;

    _saveStateForUndo(); // Save state before removing

    final newList = <VideoSegment>[...segments];
    newList.removeAt(idx); // Remove ONLY the selected segment
    segments.assignAll(newList);

    // Update active index to valid range
    final nextIndex = idx.clamp(0, newList.length - 1);
    activeSegmentIndex.value = nextIndex;
    selectSegment(nextIndex);

    // Rebuild timeline playback since structure changed
    _scheduleTimelinePlaybackRebuild();
  }

  Future<void> reorderSegments(int oldIndex, int newIndex) async {
    if (segments.length < 2) return;
    if (oldIndex < 0 || oldIndex >= segments.length) return;

    final selectedIdBefore = activeSegment?.id;

    final list = <VideoSegment>[...segments];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= list.length) newIndex = list.length - 1;

    _saveStateForUndo(); // Save state before reordering

    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    segments.assignAll(list);

    // Preserve selection by id.
    if (selectedIdBefore != null) {
      final idx = segments.indexWhere((s) => s.id == selectedIdBefore);
      if (idx >= 0) {
        await selectSegment(idx);
      }
    }
  }

  final GlobalKey overlayContainerKey = GlobalKey();
  String? _overlayPngPath;
  ui.Size? _overlayCanvasSize;
  final RxBool isCapturingOverlay = false.obs;
  final RxnString pipVideoPath = RxnString();
  final RxBool isApplyingPip = false.obs;
  final Rxn<LutItem> selectedLut = Rxn<LutItem>();
  String? _selectedLutLocalPath;
  final RxDouble lutStrength = 1.0.obs;
  final RxBool isRenderingLutPreview = false.obs;
  Timer? _lutPreviewDebounce;
  String? _lutPreviewVideoPath;
  String? _playbackPathOverride;
  String? _timelinePlaybackPath;
  Timer? _timelinePlaybackBuildDebounce;
  int _timelinePlaybackBuildRequestId = 0;
  final RxInt editorCategoryIndex = 0.obs;

  bool get _shouldUseTimelinePlayback {
    final type = content.value.type;
    final isVideoType = [
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(type);
    if (!isVideoType) return false;
    if (segments.isEmpty) return false;
    if (segments.length > 1) return true;
    final s = segments.first;
    // If the single segment is different from the original file (e.g. a cut segment), we must use timeline
    final originalPath = (content.value.content ?? '').trim();
    if (s.path.trim() != originalPath) return true;

    final hasEdits = s.edits.crop != VideoCropPreset.original ||
        s.edits.audioFx != VideoAudioFx.none ||
        s.edits.speed != 1.0;
    return hasEdits;
  }

  String? _lastExportedSignature;
  bool _previewToggle = false;

  Future<void> _ensureTimelinePlaybackReady({
    bool force = false,
    bool keepPosition = true,
  }) async {
    if (!_shouldUseTimelinePlayback) {
      _timelinePlaybackPath = null;
      return;
    }

    if (!force && (_timelinePlaybackPath ?? '').trim().isNotEmpty) {
      _playbackPathOverride = _timelinePlaybackPath;
      return;
    }

    final posMs = keepPosition ? currentPositionMs : 0;
    final requestId = ++_timelinePlaybackBuildRequestId;
    final fallback = (content.value.content ?? '').trim();

    // Create a signature of current segment state
    final signature =
        segments.map((s) => '${s.id}_${s.edits.hashCode}').join('|');

    // Skip export if nothing changed and we have a valid path
    if (!force &&
        _lastExportedSignature == signature &&
        _timelinePlaybackPath != null) {
      return;
    }

    final out = await exportTimelineToSingleVideo(fallback, isPreview: true);
    if (requestId != _timelinePlaybackBuildRequestId) return;

    final p = out.trim();
    if (p.isEmpty) return;

    _lastExportedSignature = signature;
    _timelinePlaybackPath = p;
    _playbackPathOverride = p;

    if (keepPosition && videoPlayerController.value != null) {
      // Seamless reload
      await _reloadVideoControllerSeamlessly(p, posMs);
    } else {
      _disposeControllers();
      await _initVideoController();
    }
  }

  final List<VideoPlayerController> _disposalQueue = [];

  void _safelyDisposeController(VideoPlayerController? c) {
    if (c == null) return;
    try {
      c.removeListener(_handleVideoCompletion);
      c.setVolume(0);
      c.pause();
    } catch (_) {}

    _disposalQueue.add(c);

    // If we have too many pending controllers, dispose the oldest immediately
    // Reduce limit to 1 to prevent buffer pool thrashing on Android
    while (_disposalQueue.length > 1) {
      final old = _disposalQueue.removeAt(0);
      try {
        old.dispose();
      } catch (_) {}
    }

    // Schedule final disposal with shorter delay (500ms instead of 2000ms)
    // to release hardware decoders faster.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_disposalQueue.contains(c)) {
        _disposalQueue.remove(c);
        try {
          c.dispose();
        } catch (_) {}
      }
    });
  }

  Future<void> _reloadVideoControllerSeamlessly(String path, int posMs) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return;

      // 1. Initialize new controller
      final newController = VideoPlayerController.file(file);
      await newController.initialize();

      // FIX: If we are playing the timeline (which has speed burned in),
      // the player speed should be 1.0.
      await newController.setPlaybackSpeed(1.0);

      _syncExternalAudioPlaybackSpeed();

      await newController.setVolume(videoVolume.value);
      await newController.setLooping(true);

      if (posMs > 0) {
        await newController.seekTo(Duration(milliseconds: posMs));
      }

      // 2. Check if we should play immediately
      final wasPlaying = videoPlayerController.value?.value.isPlaying ?? false;
      if (wasPlaying) {
        await newController.play();
      }

      // 3. Swap controllers
      final old = videoPlayerController.value;
      videoPlayerController.value = newController;
      _setVideoController(newController);

      // 4. Safely dispose old controller
      // If new controller is playing, we can be more aggressive with disposal
      if (newController.value.isPlaying) {
        // Give it a tiny moment to render the first frame, then dispose old immediately
        Future.delayed(const Duration(milliseconds: 100), () {
          _safelyDisposeController(old);
        });
      } else {
        _safelyDisposeController(old);
      }

      // 5. Ensure playback state consistency
      if (wasPlaying && !newController.value.isPlaying) {
        // If it didn't start playing above, force it now
        await newController.play();
      }
    } catch (e) {
      Loggers.error('Seamless reload failed: $e');
    }
  }

  void _scheduleTimelinePlaybackRebuild() {
    _timelinePlaybackBuildDebounce?.cancel();
    _timelinePlaybackBuildDebounce = Timer(
      const Duration(milliseconds: 800),
      () async {
        try {
          await _ensureTimelinePlaybackReady(force: true, keepPosition: true);
        } catch (e) {
          Loggers.error('[Timeline Playback] rebuild failed: $e');
        }
      },
    );
  }

  final RxList<TimelineTextClip> textClips = <TimelineTextClip>[].obs;
  final RxnString selectedTextClipId = RxnString();

  final RxBool isEditorMode = false.obs;
  final RxBool clipToolsVisible = false.obs;

  List<LutItem> get availableLuts {
    return SessionManager.instance.getSettings()?.luts ?? <LutItem>[];
  }

  VoidCallback? onNewTexFieldAdd;

  List<TextWidgetData>? _pendingMetaTexts;
  List<ImageStickerData>? _pendingMetaStickers;

  String localPath = '';

  Future<void> enterEditorMode() async {
    clipToolsVisible.value = true;
    isEditorMode.value = true;
    try {
      await _pausePlayback();
      await _resetPlaybackPositions();
    } catch (_) {}
  }

  void exitEditorMode() {
    isEditorMode.value = false;
    clipToolsVisible.value = false;
  }

  Future<void> userSelectSegment(int index) async {
    clipToolsVisible.value = true;
    await selectSegment(index);
  }

  int get currentPositionMs {
    final c = videoPlayerController.value;
    if (c == null || !c.value.isInitialized) return 0;
    return c.value.position.inMilliseconds;
  }

  int get timelineTotalMs {
    if (segments.isNotEmpty) {
      final sum = segments.fold<double>(0.0, (p, e) => p + e.durationSec);
      final v = (sum * 1000.0).round();
      return v <= 0 ? ((content.value.duration ?? 0) * 1000) : v;
    }
    return (content.value.duration ?? 0) * 1000;
  }

  Future<void> setMusicStartMs(int startMs) async {
    final s = content.value.sound;
    if (s == null) return;

    // Save state before modification
    _saveStateForUndo();

    final next = startMs < 0 ? 0 : startMs;
    s.audioStartMS = next;
    content.refresh();

    final audioPath = s.downloadedURL;
    if (audioPath != null) {
      try {
        await _prepareAudioPlayer(audioPath: audioPath, milliSecond: next);
      } catch (_) {}
    }
    try {
      await _restartVideoAndAudio();
    } catch (_) {}
  }

  Future<void> setMusicDuration(int durationMs) async {
    final s = content.value.sound;
    if (s == null) return;

    _saveStateForUndo();

    // Update duration (converting to seconds as stored in model)
    s.duration = (durationMs / 1000).ceil();
    content.refresh();

    try {
      await _restartVideoAndAudio();
    } catch (_) {}
  }

  void selectTextClip(String? id) {
    selectedTextClipId.value = id;
  }

  void registerTextClipForWidget(TextWidgetData data, {int? startMs}) {
    final id = data.id;
    if (id.trim().isEmpty) return;
    final exists = textClips.indexWhere((e) => e.id == id);
    if (exists >= 0) return;

    // Save state before modification
    _saveStateForUndo();

    final start = (startMs ?? currentPositionMs).clamp(0, timelineTotalMs);
    final clip = TimelineTextClip(id: id, startMs: start, durationMs: 2000);
    textClips.add(clip);
  }

  void updateTextClip(String id, {int? startMs, int? durationMs}) {
    final idx = textClips.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final cur = textClips[idx];
    final nextStart = (startMs ?? cur.startMs).clamp(0, timelineTotalMs);
    final nextDur = (durationMs ?? cur.durationMs).clamp(200, timelineTotalMs);
    textClips[idx] = cur.copyWith(startMs: nextStart, durationMs: nextDur);
  }

  void updateTextClipWithUndo(String id, {int? startMs, int? durationMs}) {
    _saveStateForUndo();
    updateTextClip(id, startMs: startMs, durationMs: durationMs);
  }

  Future<void> setAudioFx(VideoAudioFx fx) async {
    final seg = activeSegment;
    if (seg == null) return;
    if (seg.edits.audioFx == fx) return;

    _saveStateForUndo();
    _setActiveSegmentEdits(seg.edits.copyWith(audioFx: fx));
  }

  Future<void> pickPipVideoFromGallery() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickVideo(source: ImageSource.gallery);
      if (x == null) return;
      final p = x.path.trim();
      if (p.isEmpty) return;
      if (!File(p).existsSync()) {
        showSnackBar('Video not found');
        return;
      }
      pipVideoPath.value = p;
      showSnackBar('PiP added');
    } catch (e) {
      Loggers.error('[PiP] pick failed: $e');
      showSnackBar('Failed to add PiP');
    }
  }

  Future<String> _applyPipIfNeeded(String inputPath) async {
    final pip = (pipVideoPath.value ?? '').trim();
    if (pip.isEmpty || !File(pip).existsSync()) return inputPath;

    isApplyingPip.value = true;
    try {
      final out =
          '${localPath}pip_${DateTime.now().millisecondsSinceEpoch}.mp4';
      return await VideoTimelineService.shared.applyPipOverlay(
        inputVideoPath: inputPath,
        pipVideoPath: pip,
        outputPath: out,
      );
    } catch (e) {
      Loggers.error('[PiP] apply failed: $e');
      return inputPath;
    } finally {
      isApplyingPip.value = false;
    }
  }

  @override
  Future<void> onReady() async {
    super.onReady();
    selectedFilter.value = content.value.filter;
    if (selectedFilter.value.isEmpty) {
      selectedFilterIndex.value = 0;
      selectedFilter.value = filters.first.colorFilter;
    } else {
      final index = filters.indexWhere(
          (element) => listEquals(element.colorFilter, selectedFilter.value));
      if (index != -1) {
        selectedFilterIndex.value = index;
      } else {
        selectedFilterIndex.value = 0;
        selectedFilter.value = filters.first.colorFilter;
      }
    }
    localPath = await PlatformPathExtension.localPath;
    await _initTimelineIfNeeded();

    final type = content.value.type;
    final isVideoType = [
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(type);

    if (isVideoType) {
      try {
        await _ensureTimelinePlaybackReady(force: true, keepPosition: false);
        await _initVideoController().timeout(const Duration(seconds: 12));
      } catch (e) {
        Loggers.error('[Editor] init video controller failed: $e');
        try {
          _disposeControllers();
        } catch (_) {}
        showSnackBar('Failed to load video');
      }
    }
  }

  Future<void> startVoiceoverRecording() async {
    if (isVoiceoverRecording.value) return;
    _voiceoverRecorder ??= RecorderController();
    final granted = await _voiceoverRecorder!.checkPermission();
    if (!granted) {
      showSnackBar('Microphone permission denied');
      return;
    }

    try {
      final out =
          '${localPath}voiceover_${DateTime.now().millisecondsSinceEpoch}.m4a';
      voiceoverFilePath.value = null;
      await _voiceoverRecorder!.record(
        path: out,
        androidEncoder: AndroidEncoder.aac,
        androidOutputFormat: AndroidOutputFormat.mpeg4,
        iosEncoder: IosEncoder.kAudioFormatMPEG4AAC,
      );
      isVoiceoverRecording.value = true;
    } catch (e) {
      Loggers.error('[VOICEOVER] record start failed: $e');
      showSnackBar('Voiceover record failed');
    }
  }

  Future<void> stopVoiceoverRecording() async {
    if (!isVoiceoverRecording.value) return;
    try {
      final p = await _voiceoverRecorder?.stop();
      if (p != null && p.trim().isNotEmpty) {
        voiceoverFilePath.value = p;
        voiceoverStartMs.value =
            (videoPlayerController.value?.value.position.inMilliseconds ?? 0);
      }
    } catch (e) {
      Loggers.error('[VOICEOVER] record stop failed: $e');
      showSnackBar('Voiceover record failed');
    } finally {
      isVoiceoverRecording.value = false;
      try {
        _voiceoverRecorder?.dispose();
      } catch (_) {}
      _voiceoverRecorder = null;
    }
  }

  void clearVoiceover() {
    voiceoverFilePath.value = null;
    voiceoverStartMs.value = 0;
  }

  Future<void> setSelectedLut(LutItem? lut) async {
    selectedLut.value = lut;
    _selectedLutLocalPath = null;
    if (lut == null) {
      _clearLutPreview();
      return;
    }
    await _ensureSelectedLutReady();
    _scheduleLutPreviewRender();
  }

  void setLutStrength(double v) {
    lutStrength.value = v.clamp(0.0, 1.0);
    if (selectedLut.value == null) return;
    _scheduleLutPreviewRender();
  }

  Future<String?> _ensureSelectedLutReady() async {
    final lut = selectedLut.value;
    if (lut == null) return null;
    final file = (lut.file ?? '').trim();
    if (file.isEmpty) return null;
    if (_selectedLutLocalPath != null &&
        File(_selectedLutLocalPath!).existsSync()) {
      return _selectedLutLocalPath;
    }

    try {
      final url = file.addBaseURL();
      final f = await DefaultCacheManager().getSingleFile(url);
      _selectedLutLocalPath = f.path;
      return f.path;
    } catch (e) {
      Loggers.error('[LUT] download failed: $e');
      return null;
    }
  }

  void _clearLutPreview() {
    _lutPreviewDebounce?.cancel();
    _playbackPathOverride = null;
    final p = (_lutPreviewVideoPath ?? '').trim();
    _lutPreviewVideoPath = null;
    if (p.isNotEmpty) {
      try {
        final f = File(p);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  void _scheduleLutPreviewRender() {
    _lutPreviewDebounce?.cancel();
    _lutPreviewDebounce = Timer(const Duration(milliseconds: 320), () {
      _renderLutPreview();
    });
  }

  Future<void> _renderLutPreview() async {
    final lutPath = (_selectedLutLocalPath ?? '').trim();
    if (lutPath.isEmpty || !File(lutPath).existsSync()) {
      _clearLutPreview();
      return;
    }

    final seg = activeSegment;
    final basePath =
        (seg?.previewPath ?? seg?.path ?? content.value.content ?? '').trim();
    if (basePath.isEmpty || !File(basePath).existsSync()) return;

    final c = videoPlayerController.value;
    final posSec = c?.value.isInitialized == true
        ? (c!.value.position.inMilliseconds / 1000.0)
        : 0.0;
    final total =
        seg?.durationSec ?? (content.value.duration?.toDouble() ?? 0.0);
    final start = posSec.clamp(0.0, total > 0.2 ? (total - 0.2) : 0.0);

    isRenderingLutPreview.value = true;
    try {
      final outDir = Directory('${localPath}timeline/preview');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final out =
          '${outDir.path}/lut_preview_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final preview = await VideoTimelineService.shared.applyCubeLut(
        inputVideoPath: basePath,
        cubeFilePath: lutPath,
        outputPath: out,
        strength: lutStrength.value,
        startSec: start,
        durationSec: 2.5,
      );

      final old = (_lutPreviewVideoPath ?? '').trim();
      if (old.isNotEmpty && old != preview) {
        try {
          final f = File(old);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      _lutPreviewVideoPath = preview;

      await _switchPlayerToPreviewPath(preview);
    } catch (e) {
      Loggers.error('[LUT] preview render failed: $e');
    } finally {
      isRenderingLutPreview.value = false;
    }
  }

  Future<void> _prepareOverlayIfNeeded() async {
    _overlayPngPath = null;
    _overlayCanvasSize = null;
    final type = content.value.type;
    if (![
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(type)) {
      return;
    }

    try {
      final ctx = overlayContainerKey.currentContext;
      final obj = ctx?.findRenderObject();
      if (obj is RenderBox) {
        _overlayCanvasSize = obj.size;
      }
    } catch (_) {}

    StoryTextViewController? text;
    try {
      text = Get.find<StoryTextViewController>();
    } catch (_) {
      text = null;
    }
    if (text == null) return;
    if (text.textWidgets.isEmpty && text.imageStickers.isEmpty) return;

    isCapturingOverlay.value = true;
    try {
      final name = 'overlay_${DateTime.now().millisecondsSinceEpoch}.png';
      final x = await ScreenshotManager.captureScreenshot(
        overlayContainerKey,
        outputFileName: name,
      );
      final pth = x?.path ?? '';
      if (pth.trim().isEmpty) return;
      _overlayPngPath = pth;
    } catch (e) {
      Loggers.error('[OVERLAY] capture failed: $e');
    } finally {
      isCapturingOverlay.value = false;
    }
  }

  bool isGifUrl(String url) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return false;
    final noQuery = u.split('?').first;
    return noQuery.endsWith('.gif');
  }

  Future<String> _applyAnimatedGifOverlaysIfNeeded(String inputPath) async {
    return inputPath;
    final type = content.value.type;
    if (![
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(type)) {
      return inputPath;
    }

    StoryTextViewController? text;
    try {
      text = Get.find<StoryTextViewController>();
    } catch (_) {
      text = null;
    }
    if (text == null) return inputPath;

    final gifStickers =
        text.imageStickers.where((e) => isGifUrl(e.url)).toList();
    if (gifStickers.isEmpty) return inputPath;

    try {
      final size = await VideoTimelineService.shared.getVideoSize(inputPath);
      final videoW = size.key;
      final videoH = size.value;
      final canvas = _overlayCanvasSize;
      if (videoW <= 0 ||
          videoH <= 0 ||
          canvas == null ||
          canvas.width <= 0 ||
          canvas.height <= 0) {
        return inputPath;
      }

      final scaleX = videoW / canvas.width;
      final scaleY = videoH / canvas.height;

      final gifPaths = <String>[];
      final placements = <ui.Rect>[];

      for (final s in gifStickers) {
        try {
          final f = await DefaultCacheManager().getSingleFile(s.url);
          if (!f.existsSync()) continue;

          // Base sticker widget is 120x120 in UI.
          final baseSize = 120.0 * s.scale;
          final w = baseSize * scaleX;
          final h = baseSize * scaleY;
          final x = s.left * scaleX;
          final y = s.top * scaleY;

          gifPaths.add(f.path);
          placements.add(ui.Rect.fromLTWH(x, y, w, h));
        } catch (_) {
          // ignore individual gif failures
        }
      }

      if (gifPaths.isEmpty) return inputPath;

      final out =
          '${localPath}gif_overlay_${DateTime.now().millisecondsSinceEpoch}.mp4';
      return await VideoTimelineService.shared.burnInGifOverlays(
        inputVideoPath: inputPath,
        gifPaths: gifPaths,
        placements: placements,
        outputPath: out,
      );
    } catch (e) {
      Loggers.error('[Reel Upload] GIF overlay failed: $e');
      return inputPath;
    }
  }

  Future<void> cutSilences() async {
    final type = content.value.type;
    if (![
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(type)) {
      return;
    }

    if (isCuttingSilences.value || isTimelineExporting.value) return;

    _saveStateForUndo();

    final post = content.value;
    final input = await exportTimelineToSingleVideo(post.content ?? '');
    if (input.trim().isEmpty) return;

    await _pausePlayback();

    isCuttingSilences.value = true;
    cutSilencesProgress.value = 0.0;
    cutSilencesStage.value = 'Preparing';

    try {
      final outDir = Directory('${localPath}timeline');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final outputPath =
          '${outDir.path}/cut_silences_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final resultPath = await VideoTimelineService.shared.cutSilences(
        inputPath: input,
        outputPath: outputPath,
        onProgress: (p, stage) {
          cutSilencesProgress.value = p.clamp(0.0, 1.0);
          cutSilencesStage.value = stage;
        },
      );

      final finalPath = (resultPath).trim().isEmpty ? input : resultPath;

      // Replace editor source with new single-clip output
      final dur = await VideoTimelineService.shared.getDurationSec(finalPath);
      segments.assignAll([
        VideoSegment(
          id: _uuid.v4(),
          path: finalPath,
          originalPath: finalPath,
          originalDurationSec: dur,
          durationSec: dur,
          thumbnailPath: content.value.thumbNail,
        ),
      ]);
      activeSegmentIndex.value = 0;

      content.update((v) {
        if (v == null) return;
        v.content = finalPath;
        v.duration = dur.round();
      });

      _disposeControllers();
      await _initVideoController();
    } catch (e) {
      Loggers.error('[CUT_SILENCES] failed: $e');
      showSnackBar('Cut silences failed');
    } finally {
      isCuttingSilences.value = false;
    }
  }

  Future<void> _initTimelineIfNeeded() async {
    final type = content.value.type;
    if (![
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(type)) {
      return;
    }
    if (segments.isNotEmpty) return;

    final chunks = content.value.additionalContent;
    final speeds = content.value.speeds;

    if (chunks != null && chunks.isNotEmpty) {
      List<VideoSegment> newSegments = [];
      for (int i = 0; i < chunks.length; i++) {
        final path = chunks[i];
        if (path.trim().isEmpty) continue;

        final speed = (speeds != null && i < speeds.length) ? speeds[i] : 1.0;
        final dur = await VideoTimelineService.shared.getDurationSec(path);

        double effectiveDuration = dur;
        if (speed != 1.0 && speed > 0) {
          effectiveDuration = dur / speed;
        }

        newSegments.add(VideoSegment(
          id: _uuid.v4(),
          path: path,
          originalPath: path,
          originalDurationSec: dur,
          durationSec: effectiveDuration,
          thumbnailPath: content.value.thumbNail,
          edits: VideoSegmentEdits(speed: speed),
        ));
      }
      if (newSegments.isNotEmpty) {
        segments.assignAll(newSegments);
        activeSegmentIndex.value = 0;
        return;
      }
    }

    final path = (content.value.content ?? '').trim();
    if (path.isEmpty) return;
    final dur = await VideoTimelineService.shared.getDurationSec(path);
    segments.assignAll([
      VideoSegment(
        id: _uuid.v4(),
        path: path,
        originalPath: path,
        originalDurationSec: dur,
        durationSec: dur,
        thumbnailPath: content.value.thumbNail,
      ),
    ]);
    activeSegmentIndex.value = 0;
  }

  VideoSegment? get activeSegment {
    final i = activeSegmentIndex.value;
    if (i < 0 || i >= segments.length) return null;
    return segments[i];
  }

  Future<void> selectSegment(int index) async {
    if (index < 0 || index >= segments.length) return;
    activeSegmentIndex.value = index;
    final seg = segments[index];
    playbackSpeed.value = seg.edits.speed;
    _syncExternalAudioPlaybackSpeed();
  }

  Future<void> _switchPlayerToPreviewPath(String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    try {
      await _pausePlayback();
    } catch (_) {}

    _playbackPathOverride = p;
    _disposeControllers();
    await _initVideoController();
  }

  void _setActiveSegmentEdits(VideoSegmentEdits edits) {
    final seg = activeSegment;
    if (seg == null) return;
    final idx = activeSegmentIndex.value;

    // Recalculate duration if speed changed
    final oldSpeed = seg.edits.speed;
    final newSpeed = edits.speed;
    double newDuration = seg.durationSec;

    if (oldSpeed != newSpeed && newSpeed > 0) {
      final baseDuration = seg.durationSec * oldSpeed;
      newDuration = baseDuration / newSpeed;
    }

    final updated = seg.copyWith(edits: edits, durationSec: newDuration);
    final newList = <VideoSegment>[...segments];
    newList[idx] = updated;
    segments.assignAll(newList);

    _scheduleTimelinePlaybackRebuild();
    _schedulePreviewRenderForActiveSegment();
  }

  void _schedulePreviewRenderForActiveSegment() {
    _previewRenderDebounce?.cancel();
    _previewRenderDebounce = Timer(const Duration(milliseconds: 250), () {
      _renderPreviewForActiveSegment();
    });
  }

  Future<void> _renderPreviewForActiveSegment() async {
    final seg = activeSegment;
    if (seg == null) return;

    final edits = seg.edits;
    final needsRender = edits.crop != VideoCropPreset.original ||
        edits.audioFx != VideoAudioFx.none ||
        edits.speed != 1.0;

    final reqId = ++_previewRenderRequestId;
    if (!needsRender) {
      _updateSegmentPreviewPath(seg.id, null);
      return;
    }

    try {
      final outDir = Directory('${localPath}timeline/preview');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final outPath = '${outDir.path}/${seg.id}_preview.mp4';

      final previewPath = await VideoTimelineService.shared.renderSegmentEdits(
        inputPath: seg.path,
        edits: edits,
        outputPath: outPath,
        isPreview:
            true, // IMPORTANT: Use preview settings for speed and consistency
      );

      if (reqId != _previewRenderRequestId) return;
      _updateSegmentPreviewPath(seg.id, previewPath);
    } catch (e) {
      Loggers.error('[Preview Render] failed: $e');
    }
  }

  void _updateSegmentPreviewPath(String segmentId, String? previewPath) {
    final idx = segments.indexWhere((s) => s.id == segmentId);
    if (idx < 0) return;
    final seg = segments[idx];
    final updated = seg.copyWith(previewPath: previewPath);
    final newList = <VideoSegment>[...segments];
    newList[idx] = updated;
    segments.assignAll(newList);
  }

  Future<void> _switchPlayerToPath(String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    try {
      await _pausePlayback();
    } catch (_) {}

    content.update((v) {
      if (v == null) return;
      v.content = p;
    });

    _disposeControllers();
    await _initVideoController();
  }

  @override
  void onClose() {
    _lutPreviewDebounce?.cancel();
    _clearLutPreview();
    try {
      _voiceoverRecorder?.dispose();
    } catch (_) {}
    super.onClose();
    _previewRenderDebounce?.cancel();
    _disposeControllers();
  }

  void changedFilter(List<double> filter) {
    selectedFilter.value = filter;
    final index = filters
        .indexWhere((element) => listEquals(element.colorFilter, filter));
    if (index != -1) {
      selectedFilterIndex.value = index;
    }
  }

  Future<void> addStory({
    required String content,
    String? thumbnail,
    required PostStoryContentType type,
    required int duration,
    int? musicId,
  }) async {
    try {
      final int audienceType = switch (storyAudience.value) {
        StoryAudience.public => 0,
        StoryAudience.closeFriends => 1,
        StoryAudience.aiMate => 2,
      };
      StoryModel? response = await PostService.instance.createStory(
        files: {
          Params.content: [XFile(content)],
          if (type == PostStoryContentType.storyVideo)
            Params.thumbnail: [XFile(thumbnail!)],
        },
        param: {
          Params.type: type == PostStoryContentType.storyVideo ? 1 : 0,
          Params.duration: duration,
          if (musicId != -1) Params.soundID: musicId,
          Params.audienceType: audienceType,
        },
      );
      Loggers.info(response.message);
      if (response.status == true && response.data != null) {
        await addStoryResponse(response.data!);
      } else {
        failedResponseSnackBar();
      }
    } catch (e) {
      failedResponseSnackBar();
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

  Future<void> addStoryResponse(Story story) async {
    story.user = SessionManager.instance.getUser();
    Get.isRegistered<ProfileScreenController>(tag: ProfileScreenController.tag)
        ? Get.find<ProfileScreenController>(
            tag: ProfileScreenController.tag,
          ).onAddStory(story)
        : null;

    Get.isRegistered<FeedScreenController>()
        ? Get.find<FeedScreenController>().onAddStory(story)
        : null;

    _persistStoryEditorMeta(story);
    await _finalizeQuestionReplyIfNeeded(story);
    _lastUploadType = UploadType.finish;
    updateUploadingProgress(progress: 100);
  }

  Future<void> _finalizeQuestionReplyIfNeeded(Story story) async {
    final extra = content.value.additionalContent;
    if (extra == null || extra.isEmpty) return;
    final token =
        extra.firstWhereOrNull((e) => (e).trim().startsWith('__qreply_to__:'));
    if (token == null) return;

    final payload = token.trim().replaceFirst('__qreply_to__:', '').trim();
    final parts = payload.split(':');
    if (parts.length < 8) return;

    final origStoryId = int.tryParse(parts[0]) ?? -1;
    final replyDocId = parts[1].trim();
    final answererId = int.tryParse(parts[2]) ?? -1;
    final answererUsername = parts[3];
    final answererFullname = parts[4];
    final answererProfile = parts[5];
    final answerText = parts.sublist(6).join(':').trim();

    if (origStoryId <= 0 || replyDocId.isEmpty || answererId <= 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await FirebaseFirestore.instance
          .collection('story_question_replies')
          .doc(origStoryId.toString())
          .collection('items')
          .doc(replyDocId)
          .set({
        'replied': true,
        'replied_at': now,
        'reply_story_id': story.id,
      }, SetOptions(merge: true));
    } catch (e) {
      Loggers.error('Finalize question reply firestore failed: $e');
    }

    // Fetch answerer device token
    String? tokenPush;
    num? deviceType;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_users')
          .doc(answererId.toString())
          .get();
      final data = snap.data();
      tokenPush =
          (data?['device_token'] ?? data?['deviceToken'] ?? '').toString();
      final rawDevice = data?['device'];
      if (rawDevice is num) {
        deviceType = rawDevice;
      } else {
        deviceType = num.tryParse((rawDevice ?? '').toString());
      }
    } catch (_) {}

    // Push notification to answerer
    try {
      if ((tokenPush ?? '').trim().isNotEmpty) {
        final me = SessionManager.instance.getUser();
        NotificationService.instance.pushNotification(
          type: NotificationType.other,
          title: me?.fullname?.isNotEmpty == true
              ? (me?.fullname ?? '')
              : (me?.username ?? ''),
          body: 'replied to your answer',
          token: tokenPush,
          deviceType: deviceType,
          data: {
            'story_id': story.id,
            'type': 'story_question_reply',
            'orig_story_id': origStoryId,
          },
        );
      }
    } catch (e) {
      Loggers.error('Finalize question reply notification failed: $e');
    }

    // Also send to chat as story reply
    try {
      final myId = SessionManager.instance.getUserID();
      if (myId <= 0) return;
      final ids = [myId, answererId]..sort();
      final conversationId = '${ids[0]}_${ids[1]}';
      final thread = ChatThread(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        lastMsg: '',
        msgCount: 0,
        isDeleted: false,
        deletedId: 0,
        iAmBlocked: false,
        iBlocked: false,
        requestType: UserRequestAction.accept.title,
        chatType: ChatType.approved,
        conversationId: conversationId,
        userId: answererId,
      );
      thread.chatUser = AppUser(
        userId: answererId,
        username: answererUsername,
        fullname: answererFullname,
        profile: answererProfile,
      );

      final chat =
          Get.put(ChatScreenController(thread.obs), tag: conversationId);
      chat.sendStoryReply(story: story, textReply: answerText);
    } catch (e) {
      Loggers.error('Finalize question reply chat failed: $e');
    }
  }

  Future<void> _persistStoryEditorMeta(Story story) async {
    final storyId = story.id;
    if (storyId == null || storyId <= 0) return;

    StoryTextViewController? textCtrl;
    try {
      textCtrl = Get.find<StoryTextViewController>();
    } catch (_) {
      textCtrl = null;
    }
    final texts = textCtrl?.textWidgets.toList() ?? _pendingMetaTexts;
    final stickers = textCtrl?.imageStickers.toList() ?? _pendingMetaStickers;
    if ((texts == null || texts.isEmpty) &&
        (stickers == null || stickers.isEmpty)) {
      return;
    }

    final allText =
        (texts ?? const <TextWidgetData>[]).map((e) => e.text).join(' ');
    final mentionRegex = RegExp(r'@([A-Za-z0-9_]{1,30})');
    final hashtagRegex = RegExp(r'#([A-Za-z0-9_]{1,50})');

    final mentions = mentionRegex
        .allMatches(allText)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final hashtags = hashtagRegex
        .allMatches(allText)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final myId = SessionManager.instance.getUserID();
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await FirebaseFirestore.instance
          .collection('story_editor_meta')
          .doc(storyId.toString())
          .set({
        'story_id': storyId,
        'owner_id': myId,
        'created_at': now,
        'mentions': mentions,
        'hashtags': hashtags,
        'texts': (texts ?? const <TextWidgetData>[])
            .map((t) => {
                  'id': t.id,
                  'text': t.text,
                  'top': t.top,
                  'left': t.left,
                  'font_size': t.fontSize,
                  'font_scale': t.fontScale,
                  'font_angle': t.fontAngle,
                  'opacity': t.opacity,
                })
            .toList(),
        'stickers': (stickers ?? const <ImageStickerData>[])
            .map((s) => {
                  'url': s.url,
                  'top': s.top,
                  'left': s.left,
                  'scale': s.scale,
                  'angle': s.angle,
                })
            .toList(),
      }, SetOptions(merge: true));
    } catch (e) {
      Loggers.error('Story editor meta save failed: $e');
    }
  }

  void onDiscard() {
    Get.bottomSheet(
      ConfirmationSheet(
        title: LKey.discardEditsTitle.tr,
        description: LKey.discardEditsMessage.tr,
        onTap: Get.back,
      ),
    );
  }

  void onFilterToggle() {
    isFilterShow.toggle();
  }

  Future<void> _initVideoController() async {
    if ([
      PostStoryContentType.storyImage,
      PostStoryContentType.storyText,
    ].contains(content.value.type)) {
      SelectedMusic? sound = content.value.sound;
      if (sound != null && sound.downloadedURL != null) {
        String audioPath = sound.downloadedURL ?? '';
        await _prepareAudioPlayer(
          audioPath: audioPath,
          milliSecond: sound.audioStartMS,
        );
        _playAudioOnly();
      }
      return;
    }

    final inputPath =
        (_playbackPathOverride ?? content.value.content ?? '').trim();
    if (inputPath.isEmpty) {
      throw Exception('Missing input video path');
    }

    final file = File(inputPath);
    if (!file.existsSync()) {
      throw Exception('Video file not found: $inputPath');
    }

    videoPlayerController.value = VideoPlayerController.file(file);

    try {
      await videoPlayerController.value?.initialize();
    } catch (e) {
      try {
        await videoPlayerController.value?.dispose();
      } catch (_) {}
      videoPlayerController.value = null;
      rethrow;
    }

    final c = videoPlayerController.value;
    if (c != null && c.value.isInitialized) {
      await c.setPlaybackSpeed(playbackSpeed.value);
      await c.setVolume(videoVolume.value);
    }

    hasAudio = await RetrytechPlugin.shared.hasAudio(
          inputPath: content.value.content ?? '',
        ) ??
        true;
    videoPlayerController.refresh();
    videoPlayerController.value?.setLooping(true);
    content.update(
      (val) => val?.duration =
          videoPlayerController.value?.value.duration.inSeconds ?? 0,
    );

    final dur =
        (videoPlayerController.value?.value.duration.inMilliseconds ?? 0) /
            1000.0;
    if (!isTrimApplied.value) {
      trimStartSec.value = 0.0;
      trimEndSec.value = dur;
    } else {
      trimEndSec.value = dur;
      if (trimStartSec.value > trimEndSec.value) {
        trimStartSec.value = 0.0;
      }
    }

    if (coverPositionSec.value <= 0.0 || coverPositionSec.value > dur) {
      coverPositionSec.value = dur > 0 ? (dur / 2.0) : 0.0;
    }

    SelectedMusic? sound = content.value.sound;

    if (sound?.downloadedURL != null) {
      String audioPath = sound?.downloadedURL ?? '';
      await _prepareAudioPlayer(
        audioPath: audioPath,
        milliSecond: sound?.audioStartMS,
      );
      videoPlayerController.value?.setVolume(0.0);
    }
    _startPlayback();
    _setVideoController(videoPlayerController.value!);
  }

  void setTrimRange({required double startSec, required double endSec}) {
    final start = startSec < 0 ? 0.0 : startSec;
    final end = endSec < start ? start : endSec;
    trimStartSec.value = start;
    trimEndSec.value = end;
  }

  Future<void> seekToTrimStart() async {
    final c = videoPlayerController.value;
    if (c == null || !c.value.isInitialized) return;
    await c.seekTo(Duration(milliseconds: (trimStartSec.value * 1000).round()));
  }

  Future<bool> applyTrim() async {
    final post = content.value;
    if (![
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(post.type)) {
      return false;
    }

    final inputPath = post.content ?? '';
    if (inputPath.trim().isEmpty) return false;

    final startMs = (trimStartSec.value * 1000).round();
    final endMs = (trimEndSec.value * 1000).round();
    if (endMs <= startMs + 50) return false;

    _saveStateForUndo();

    isTrimmingVideo.value = true;
    try {
      await _pausePlayback();
      await _videoTrimmer.loadVideo(inputPath);
      final outPath = await _videoTrimmer.trimVideo(
        startTimeMs: startMs,
        endTimeMs: endMs,
        includeAudio: true,
      );

      final trimmed = (outPath ?? '').trim();
      if (trimmed.isEmpty) return false;

      content.update((v) {
        if (v == null) return;
        v.content = trimmed;
      });
      isTrimApplied.value = true;

      _disposeControllers();
      await _initVideoController();
      return true;
    } catch (e) {
      Loggers.error('[TRIM] applyTrim failed: $e');
      return false;
    } finally {
      isTrimmingVideo.value = false;
    }
  }

  void _setVideoController(VideoPlayerController controller) {
    controller.removeListener(
      _handleVideoCompletion,
    ); // Remove if already exists
    controller.addListener(_handleVideoCompletion);
  }

  /// Listener to handle video playback completion and restart logic
  void _handleVideoCompletion() {
    final controller = videoPlayerController.value;
    if (controller == null || !controller.value.isInitialized) return;

    final position = controller.value.position;
    final duration = controller.value.duration;

    // Use a tighter threshold for smoother looping
    final isVideoComplete = (duration - position).inMilliseconds.abs() < 200;

    if (!isVideoComplete) return;

    // Guard against repeated triggers
    if (_isRestartingPlayback) return;

    // If native looping is on, video restarts automatically.
    // We only need to restart external audio if present.
    if (controller.value.isLooping) {
      if (content.value.sound != null) {
        final startMs = content.value.sound?.audioStartMS ?? 0;
        // Only seek audio if it's significantly off?
        // Actually, just restarting it is safer to sync with video loop.
        audioPlayer.seekTo(startMs);
        audioPlayer.startPlayer(forceRefresh: false);
      }
      return;
    }

    _isRestartingPlayback = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      _isRestartingPlayback = false;
    });

    // Manual looping logic to avoid "push on" stutter
    switch (content.value.type) {
      case PostStoryContentType.reel:
      case PostStoryContentType.storyVideo:
        _restartVideoAndAudio();
        break;
      case PostStoryContentType.storyText:
      case PostStoryContentType.storyImage:
        _playAudioOnly();
        break;
    }
  }

  /// Restarts video and audio from the beginning
  Future<void> _restartVideoAndAudio() async {
    // Smoother restart: Seek to 0 and ensure playing
    final c = videoPlayerController.value;
    if (c != null) {
      await c.seekTo(Duration.zero);
      if (!c.value.isPlaying) {
        await c.play();
      }
    }

    final s = content.value.sound;
    if (s != null) {
      final startMs = s.audioStartMS ?? 0;
      audioPlayer.seekTo(startMs);
      audioPlayer.startPlayer(forceRefresh: false);
    }
  }

  /// Starts both video and audio playback
  void _startPlayback() {
    videoPlayerController.value?.play();
    audioPlayer.startPlayer(forceRefresh: false);
  }

  /// Pauses both video and audio playback
  Future<void> _pausePlayback() async {
    videoPlayerController.value?.pause();
    if (content.value.sound != null) {
      audioPlayer.pausePlayer();
    }
  }

  /// Resets video and audio position to the beginning
  Future<void> _resetPlaybackPositions() async {
    await videoPlayerController.value?.seekTo(Duration.zero);
    final startMs = content.value.sound?.audioStartMS ?? 0;
    // await audioPlayer.pausePlayer();
    if (content.value.sound != null) {
      audioPlayer.seekTo(startMs);
    }
    Loggers.info('✂️ Reset Play back');
  }

  /// Toggles between playing and pausing
  void onPlayPauseToggle() {
    final isPlaying = videoPlayerController.value?.value.isPlaying ?? false;
    isPlaying ? _pausePlayback() : _startPlayback();
  }

  void _disposeControllers() {
    _timer?.cancel();
    audioPlayer.release();
    audioPlayer.dispose();
    videoPlayerController.value?.removeListener(_handleVideoCompletion);
    videoPlayerController.value?.dispose();
    videoPlayerController.value = null;
  }

  Future<void> splitAtCurrentPosition() async {
    final seg = activeSegment;
    if (seg == null) return;
    final c = videoPlayerController.value;
    if (c == null || !c.value.isInitialized) return;

    final posSec = c.value.position.inMilliseconds / 1000.0;
    if (posSec <= 0.25 || posSec >= (seg.durationSec - 0.25)) {
      showSnackBar('Invalid split point');
      return;
    }

    isSplitting.value = true;
    try {
      _saveStateForUndo(); // Save state before splitting

      final outDir = Directory('${localPath}timeline');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);

      final leftPath = '${outDir.path}/${_uuid.v4()}_a.mp4';
      final rightPath = '${outDir.path}/${_uuid.v4()}_b.mp4';

      await VideoTimelineService.shared.cutSegment(
        inputPath: seg.path,
        startSec: 0.0,
        endSec: posSec,
        outputPath: leftPath,
      );
      await VideoTimelineService.shared.cutSegment(
        inputPath: seg.path,
        startSec: posSec,
        endSec: seg.durationSec,
        outputPath: rightPath,
      );

      final leftDur = await VideoTimelineService.shared.getDurationSec(
        leftPath,
      );
      final rightDur = await VideoTimelineService.shared.getDurationSec(
        rightPath,
      );

      final leftSeg = VideoSegment(
        id: _uuid.v4(),
        path: leftPath,
        durationSec: leftDur,
        edits: seg.edits,
        originalPath: seg.originalPath ?? seg.path,
        originalDurationSec: seg.originalDurationSec ?? seg.durationSec,
        trimStartSec: seg.trimStartSec,
      );
      final rightSeg = VideoSegment(
        id: _uuid.v4(),
        path: rightPath,
        durationSec: rightDur,
        edits: seg.edits,
        originalPath: seg.originalPath ?? seg.path,
        originalDurationSec: seg.originalDurationSec ?? seg.durationSec,
        trimStartSec: seg.trimStartSec + posSec,
      );

      final idx = activeSegmentIndex.value;
      final newList = <VideoSegment>[...segments];
      newList.removeAt(idx);
      newList.insertAll(idx, [leftSeg, rightSeg]);
      segments.assignAll(newList);

      await selectSegment(idx);
    } catch (e) {
      Loggers.error('splitAtCurrentPosition failed: $e');
      showSnackBar('Split failed');
    } finally {
      isSplitting.value = false;
    }
  }

  Future<void> trimActiveSegment(
      double startDeltaSec, double endDeltaSec) async {
    final seg = activeSegment;
    if (seg == null) return;

    // Minimum duration check (0.5s)
    final currentDur = seg.durationSec;
    final newDur = currentDur - startDeltaSec + endDeltaSec;
    if (newDur < 0.5) return;

    isTrimmingVideo.value = true;
    try {
      _saveStateForUndo();

      final outDir = Directory('${localPath}timeline');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final outputPath = '${outDir.path}/${_uuid.v4()}_trim.mp4';

      // Use original path if available, else current path (fallback for old segments)
      final sourcePath = seg.originalPath ?? seg.path;
      final currentStartOffset = seg.trimStartSec;

      // Calculate new start/end in terms of source video
      var newStart = currentStartOffset + startDeltaSec;
      var newEnd = newStart + newDur;

      // Bounds checking
      if (newStart < 0) {
        newStart = 0;
      }

      // Check max duration
      double maxDur = seg.originalDurationSec ?? 0.0;
      if (maxDur <= 0) {
        // If we don't have it stored, try to get it from source
        maxDur = await VideoTimelineService.shared.getDurationSec(sourcePath);
      }

      if (newEnd > maxDur) {
        newEnd = maxDur;
      }

      if (newEnd <= newStart + 0.1) {
        return; // Invalid range
      }

      await VideoTimelineService.shared.cutSegment(
        inputPath: sourcePath,
        startSec: newStart,
        endSec: newEnd,
        outputPath: outputPath,
      );

      final finalDur =
          await VideoTimelineService.shared.getDurationSec(outputPath);

      final updated = seg.copyWith(
        id: _uuid.v4(),
        path: outputPath,
        durationSec: finalDur,
        trimStartSec: newStart, // Update offset
        edits: seg.edits, // Preserve edits
      );

      final idx = activeSegmentIndex.value;
      final newList = <VideoSegment>[...segments];
      newList[idx] = updated;
      segments.assignAll(newList);

      await selectSegment(idx);
      _scheduleTimelinePlaybackRebuild();
    } catch (e) {
      Loggers.error('trimActiveSegment failed: $e');
      showSnackBar('Trim failed');
    } finally {
      isTrimmingVideo.value = false;
    }
  }

  Future<void> replaceActiveSegmentFromGallery() async {
    final seg = activeSegment;
    if (seg == null) return;

    isReplacingSegment.value = true;
    try {
      final picker = ImagePicker();
      final x = await picker.pickVideo(source: ImageSource.gallery);
      if (x == null) return;
      final path = x.path;
      final dur = await VideoTimelineService.shared.getDurationSec(path);

      _saveStateForUndo(); // Save state before replacing

      final updated = seg.copyWith(
        path: path,
        durationSec: dur,
        originalPath: path,
        originalDurationSec: dur,
        trimStartSec: 0.0,
      );

      final idx = activeSegmentIndex.value;
      final newList = <VideoSegment>[...segments];
      newList[idx] = updated;
      segments.assignAll(newList);

      await selectSegment(idx);
      _scheduleTimelinePlaybackRebuild(); // Trigger rebuild
    } catch (e) {
      Loggers.error('replaceActiveSegmentFromGallery failed: $e');
      showSnackBar('Replace failed');
    } finally {
      isReplacingSegment.value = false;
    }
  }

  void setActiveSegmentCrop(VideoCropPreset preset) {
    final seg = activeSegment;
    if (seg == null) return;
    if (seg.edits.crop == preset) return;
    _saveStateForUndo();
    _setActiveSegmentEdits(seg.edits.copyWith(crop: preset));
  }

  void setActiveSegmentAudioFx(VideoAudioFx fx) {
    final seg = activeSegment;
    if (seg == null) return;
    if (seg.edits.audioFx == fx) return;
    _saveStateForUndo();
    _setActiveSegmentEdits(seg.edits.copyWith(audioFx: fx));
  }

  void setSegmentTransition(int index, VideoTransitionType transition) {
    if (index < 0 || index >= segments.length) return;
    final seg = segments[index];
    if (seg.edits.transition == transition) return;

    _saveStateForUndo();

    final newSeg = seg.copyWith(
      edits: seg.edits.copyWith(transition: transition),
    );
    final newList = <VideoSegment>[...segments];
    newList[index] = newSeg;
    segments.assignAll(newList);

    // Transitions require re-rendering the whole timeline
    _scheduleTimelinePlaybackRebuild();
  }

  Future<String> exportTimelineToSingleVideo(
    String fallbackInputPath, {
    bool isPreview = false,
  }) async {
    final type = content.value.type;
    if (![
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(type)) {
      return fallbackInputPath;
    }

    if (segments.isEmpty) {
      return fallbackInputPath;
    }

    if (!isPreview) {
      isTimelineExporting.value = true;
    }

    try {
      final outDir = Directory(
        '${localPath}timeline${isPreview ? "/preview" : ""}',
      );
      if (!outDir.existsSync()) outDir.createSync(recursive: true);

      final renderedPaths = <String>[];
      for (final s in segments) {
        // If preview, we MUST render to ensure consistent resolution/FPS for smooth concat
        final needsRender = isPreview ||
            s.edits.crop != VideoCropPreset.original ||
            s.edits.audioFx != VideoAudioFx.none ||
            s.edits.speed != 1.0;
        if (!needsRender) {
          renderedPaths.add(s.path);
          continue;
        }

        // Cache optimization: Skip render if file exists for same edits
        final editHash = s.edits.hashCode;
        final outPath =
            '${outDir.path}/${s.id}_${editHash}_${isPreview ? "p" : "f"}.mp4';

        if (File(outPath).existsSync()) {
          renderedPaths.add(outPath);
          continue;
        }

        final p = await VideoTimelineService.shared.renderSegmentEdits(
          inputPath: s.path,
          edits: s.edits,
          outputPath: outPath,
          isPreview: isPreview,
        );
        renderedPaths.add(p);
      }

      if (renderedPaths.length == 1) {
        return renderedPaths.first;
      }

      String outPath;
      if (isPreview) {
        // Use alternating filenames for preview to avoid disk spam and help player caching
        _previewToggle = !_previewToggle;
        final name = _previewToggle ? 'preview_A.mp4' : 'preview_B.mp4';
        outPath = '${outDir.path}/$name';
      } else {
        outPath =
            '${outDir.path}/timeline_${DateTime.now().millisecondsSinceEpoch}.mp4';
      }

      // Collect transitions
      final transitions = segments.map((s) => s.edits.transition).toList();
      final hasTransitions =
          transitions.any((t) => t != VideoTransitionType.none);

      if (hasTransitions) {
        return await VideoTimelineService.shared.concatSegmentsWithTransitions(
          inputPaths: renderedPaths,
          transitions: transitions,
          outputPath: outPath,
        );
      } else {
        return await VideoTimelineService.shared.concatSegments(
          inputPaths: renderedPaths,
          outputPath: outPath,
        );
      }
    } finally {
      if (!isPreview) {
        isTimelineExporting.value = false;
      }
    }
  }

  /// Starts looping audio playback for image/text story types
  void _playAudioOnly() {
    if (content.value.sound?.music == null) return;

    audioPlayer.startPlayer();
    _timer = Timer(Duration(seconds: selectStorySecond), () async {
      await _pauseAudioOnly();
      _playAudioOnly();
    });
  }

  /// Pauses audio and resets to the defined start position
  Future<void> _pauseAudioOnly() async {
    _timer?.cancel();
    await audioPlayer.pausePlayer();
    await audioPlayer.seekTo(content.value.sound?.audioStartMS ?? 0);
  }

  /// Toggles video player volume between mute and full volume
  void toggleVideoVolume() {
    final controller = videoPlayerController.value;
    if (controller == null) return;

    final isMuted = controller.value.volume == 0.0;
    final next = isMuted ? 1.0 : 0.0;
    videoVolume.value = next;
    controller.setVolume(next);
  }

  Future<void> setVideoVolume(double v) async {
    final vol = v.clamp(0.0, 1.0);
    videoVolume.value = vol;
    final c = videoPlayerController.value;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setVolume(vol);
    } catch (_) {}
  }

  Future<void> setMusicVolume(double v) async {
    final vol = v.clamp(0.0, 1.0);
    musicVolume.value = vol;
    final s = content.value.sound;
    if (s != null) {
      s.volume = vol;
      content.refresh();
    }
    try {
      await audioPlayer.setVolume(vol);
    } catch (_) {}
  }

  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed.value = speed;
    final seg = activeSegment;
    if (seg != null) {
      if (seg.edits.speed != speed) {
        _saveStateForUndo();
        _setActiveSegmentEdits(seg.edits.copyWith(speed: speed));
      }
    }

    _syncExternalAudioPlaybackSpeed();

    // If playing raw single clip (not timeline), apply player speed directly
    if (!_shouldUseTimelinePlayback) {
      final c = videoPlayerController.value;
      if (c != null && c.value.isInitialized) {
        try {
          await c.setPlaybackSpeed(speed);
        } catch (_) {}
      }
    } else {
      // Ensure preview updates quickly while timeline export rebuilds
      _schedulePreviewRenderForActiveSegment();
    }
  }

  Future<bool> generateCoverAt(double positionSec) async {
    final post = content.value;
    if (![
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(post.type)) {
      return false;
    }

    final inputPath = (post.content ?? '').trim();
    if (inputPath.isEmpty) return false;

    isGeneratingCover.value = true;
    coverPositionSec.value = positionSec;
    try {
      final ms = (positionSec * 1000).round();
      final thumb = await VideoCompress.getFileThumbnail(
        inputPath,
        quality: AppRes.imageQuality,
        position: ms,
      );
      if (thumb.path.isEmpty) return false;

      content.update((v) {
        if (v == null) return;
        v.thumbNail = thumb.path;
      });
      return true;
    } catch (e) {
      Loggers.error('generateCoverAt failed: $e');
      return false;
    } finally {
      isGeneratingCover.value = false;
    }
  }

  Future<void> seekToCoverPosition() async {
    final c = videoPlayerController.value;
    if (c == null || !c.value.isInitialized) return;
    final ms = (coverPositionSec.value * 1000).round();
    try {
      await c.seekTo(Duration(milliseconds: ms));
    } catch (_) {}
  }

  Future<void> handleContentUpload() async {
    final currentContent = content.value;
    if (currentContent.type == PostStoryContentType.reel) {
      final videoPath = currentContent.content ?? '';
      if (videoPath.isNotEmpty) {
        SightEngineService.shared.checkVideoInSightEngine(
          xFile: XFile(videoPath),
          duration: videoPlayerController.value?.value.duration.inSeconds ?? 0,
          completion: handleReelUpload,
        );
      } else {
        showSnackBar(LKey.videoPathNotFound.tr);
      }
    } else if ([
      PostStoryContentType.storyText,
      PostStoryContentType.storyImage,
      PostStoryContentType.storyVideo,
    ].contains(currentContent.type)) {
      handleStoryUpload();
    }
  }

  /// Entry point for post upload after moderation check
  Future<void> handleReelUpload() async {
    final hasAudio = content.value.sound != null;
    isMergingVideo.value = true;

    await _prepareOverlayIfNeeded();
    await _ensureSelectedLutReady();

    if (hasAudio) {
      await _applyFilterAndAudioToReel();
    } else {
      await _applyFilterOnlyToReel();
    }
  }

  /// Applies only filters (no external audio)
  Future<void> _applyFilterOnlyToReel() async {
    Loggers.info('[Reel Upload] Processing video without external audio');

    final post = content.value;
    var inputPath = await exportTimelineToSingleVideo(post.content ?? '');

    inputPath = await _applyPipIfNeeded(inputPath);

    final overlayPath = (_overlayPngPath ?? '').trim();
    if (overlayPath.isNotEmpty && File(overlayPath).existsSync()) {
      try {
        final out =
            '${localPath}overlay_${DateTime.now().millisecondsSinceEpoch}.mp4';
        inputPath = await VideoTimelineService.shared.burnInPngOverlay(
          inputVideoPath: inputPath,
          overlayPngPath: overlayPath,
          outputPath: out,
        );
      } catch (e) {
        Loggers.error('[Reel Upload] overlay burn-in failed: $e');
      }
    }

    inputPath = await _applyAnimatedGifOverlaysIfNeeded(inputPath);

    final lutPath = (_selectedLutLocalPath ?? '').trim();
    if (lutPath.isNotEmpty && File(lutPath).existsSync()) {
      try {
        final out =
            '${localPath}lut_${DateTime.now().millisecondsSinceEpoch}.mp4';
        inputPath = await VideoTimelineService.shared.applyCubeLut(
          inputVideoPath: inputPath,
          cubeFilePath: lutPath,
          outputPath: out,
          strength: lutStrength.value,
        );
      } catch (e) {
        Loggers.error('[Reel Upload] LUT apply failed: $e');
      }
    }

    final vPath = (voiceoverFilePath.value ?? '').trim();
    if (vPath.isNotEmpty && File(vPath).existsSync()) {
      try {
        final out =
            '${localPath}voice_${DateTime.now().millisecondsSinceEpoch}.mp4';
        inputPath = await VideoTimelineService.shared.mixVideoWithExternalAudio(
          inputVideoPath: inputPath,
          inputAudioPath: vPath,
          outputPath: out,
          audioStartMs: voiceoverStartMs.value,
          originalVolume: 1.0,
          musicVolume: voiceoverVolume.value,
          includeOriginalAudio: true,
        );
      } catch (e) {
        Loggers.error('[Reel Upload] voiceover mix failed: $e');
      }
    }
    final outputPath = '${localPath}filter_video.mp4';
    String finalPath = inputPath;

    if (!listEquals(selectedFilter.value, filters.first.colorFilter)) {
      Loggers.info('Filter Applying..');
      try {
        final result = await _retrytechPlugin.applyFilterAndAudioToVideo(
          inputPath: inputPath,
          outputPath: outputPath,
          filterValues: selectedFilter.value,
          shouldBothMusics: true,
        );

        if (result == true) {
          finalPath = outputPath;
        } else {
          Loggers.error('[Reel Upload] Failed to apply filter');
          return;
        }
      } catch (e) {
        Loggers.error('[Reel Upload] Filter application error: $e');
        return;
      } finally {
        isMergingVideo.value = false;
      }
    } else {
      Loggers.info('Filter not applying..');
      isMergingVideo.value = false;
    }

    _pausePlayback();
    await _goToCreateFeedScreen(finalPath);
    _restartVideoAndAudio();
  }

  /// Applies filter + audio overlay
  Future<void> _applyFilterAndAudioToReel() async {
    Loggers.info('[Reel Upload] Processing video with audio');

    final post = content.value;
    var inputPath = await exportTimelineToSingleVideo(post.content ?? '');

    inputPath = await _applyPipIfNeeded(inputPath);

    final overlayPath = (_overlayPngPath ?? '').trim();
    if (overlayPath.isNotEmpty && File(overlayPath).existsSync()) {
      try {
        final out =
            '${localPath}overlay_${DateTime.now().millisecondsSinceEpoch}.mp4';
        inputPath = await VideoTimelineService.shared.burnInPngOverlay(
          inputVideoPath: inputPath,
          overlayPngPath: overlayPath,
          outputPath: out,
        );
      } catch (e) {
        Loggers.error('[Reel Upload] overlay burn-in failed: $e');
      }
    }

    final lutPath = (_selectedLutLocalPath ?? '').trim();
    if (lutPath.isNotEmpty && File(lutPath).existsSync()) {
      try {
        final out =
            '${localPath}lut_${DateTime.now().millisecondsSinceEpoch}.mp4';
        inputPath = await VideoTimelineService.shared.applyCubeLut(
          inputVideoPath: inputPath,
          cubeFilePath: lutPath,
          outputPath: out,
          strength: lutStrength.value,
        );
      } catch (e) {
        Loggers.error('[Reel Upload] LUT apply failed: $e');
      }
    }

    final audioPath = post.sound?.downloadedURL;
    final filterOutPath = '${localPath}filter_video_tmp.mp4';
    final outputPath = '${localPath}merge_audio_filter_video.mp4';
    String finalPath = inputPath;
    final List<double> filtersValue =
        listEquals(selectedFilter.value, defaultFilter)
            ? []
            : selectedFilter.value;
    final mixOriginalAudio = videoVolume.value > 0.0;
    final audioStartTimeInMS =
        double.tryParse('${post.sound?.audioStartMS ?? 0}') ?? 0.0;
    final audioStartMs = audioStartTimeInMS.round();

    if (inputPath.trim().isEmpty || audioPath == null) {
      Loggers.error('[Reel Upload] Missing input or audio path');
      return;
    }

    try {
      // Step 1: Apply filter only (if needed)
      if (filtersValue.isNotEmpty) {
        final r = await _retrytechPlugin.applyFilterAndAudioToVideo(
          inputPath: inputPath,
          outputPath: filterOutPath,
          filterValues: filtersValue,
          shouldBothMusics: true,
        );
        if (r != true) {
          Loggers.error('[Reel Upload] Filter apply failed');
          return;
        }
        finalPath = filterOutPath;
      }

      finalPath = await _applyAnimatedGifOverlaysIfNeeded(finalPath);

      // Step 2: Mix external music with proper volumes using FFmpeg
      finalPath = await VideoTimelineService.shared.mixVideoWithExternalAudio(
        inputVideoPath: finalPath,
        inputAudioPath: audioPath,
        outputPath: outputPath,
        audioStartMs: audioStartMs,
        originalVolume: videoVolume.value,
        musicVolume: musicVolume.value,
        includeOriginalAudio: mixOriginalAudio,
      );

      final vPath = (voiceoverFilePath.value ?? '').trim();
      if (vPath.isNotEmpty && File(vPath).existsSync()) {
        final out =
            '${localPath}voice_${DateTime.now().millisecondsSinceEpoch}.mp4';
        finalPath = await VideoTimelineService.shared.mixVideoWithExternalAudio(
          inputVideoPath: finalPath,
          inputAudioPath: vPath,
          outputPath: out,
          audioStartMs: voiceoverStartMs.value,
          originalVolume: 1.0,
          musicVolume: voiceoverVolume.value,
          includeOriginalAudio: true,
        );
      }
    } catch (e) {
      Loggers.error('[Reel Upload] Filter/audio merge error: $e');
      return;
    } finally {
      isMergingVideo.value = false;
    }

    _pausePlayback();
    await _goToCreateFeedScreen(finalPath);
    _restartVideoAndAudio();
  }

  /// Extracts thumbnail and navigates to the CreateFeed screen for reels
  Future<void> _goToCreateFeedScreen(String videoFilePath) async {
    try {
      Uint8List? thumbnailBytes;
      XFile thumbnailFile;

      final coverPath = (content.value.thumbNail ?? '').trim();
      if (coverPath.isNotEmpty && File(coverPath).existsSync()) {
        thumbnailFile = XFile(coverPath);
        try {
          thumbnailBytes = await File(coverPath).readAsBytes();
        } catch (_) {}
      } else {
        thumbnailBytes = await MediaPickerHelper.shared.extractThumbnailByte(
          videoPath: videoFilePath,
        );
        thumbnailFile = await MediaPickerHelper.shared.extractThumbnail(
          videoPath: videoFilePath,
        );
      }

      // Prepare content model for the next screen
      final PostStoryContent reelContent = PostStoryContent(
        type: PostStoryContentType.reel,
        content: videoFilePath,
        thumbNail: thumbnailFile.path,
        thumbnailBytes: thumbnailBytes,
        filter: selectedFilter.value,
        duration: content.value.duration,
        sound: content.value.sound,
        bgGradient: content.value.bgGradient,
        hasAudio: hasAudio,
      );

      // Stop any loading indicators
      isMergingVideo.value = false;

      // Navigate to the CreateFeed screen with reel content
      await Get.to(
        () => CreateFeedScreen(
          createType: CreateFeedType.reel,
          content: reelContent,
        ),
      );
    } catch (e) {
      Loggers.error('Failed to navigate to reel composer: $e');
      isMergingVideo.value = false;
    }
  }

  Future<void> handleStoryUpload() async {
    if (isUploading.value) return;
    isUploading.value = true;
    final story = content.value;
    final filePath = story.content ?? '';
    final isTextOrImage = [
      PostStoryContentType.storyImage,
      PostStoryContentType.storyText,
    ].contains(story.type);
    final duration = isTextOrImage ? selectStorySecond : story.duration ?? 0;

    try {
      _capturePendingStoryEditorMeta();
      _redirectToProfileTab();
      _lastUploadType = UploadType.uploading;
      if (story.type == PostStoryContentType.storyVideo) {
        await _processVideoStory(
          story: story,
          inputFile: filePath,
          storyDuration: duration,
        );
      } else {
        await _processImageOrTextStory(duration);
      }
    } finally {
      isUploading.value = false;
    }
  }

  void _capturePendingStoryEditorMeta() {
    try {
      final textCtrl = Get.find<StoryTextViewController>();
      _pendingMetaTexts = List<TextWidgetData>.from(textCtrl.textWidgets);
      _pendingMetaStickers =
          List<ImageStickerData>.from(textCtrl.imageStickers);
    } catch (_) {
      _pendingMetaTexts = null;
      _pendingMetaStickers = null;
    }
  }

  /// Handles video story: moderation, filtering, music overlay
  Future<void> _processVideoStory({
    required PostStoryContent story,
    required String inputFile,
    required int storyDuration,
  }) async {
    final outputPath = '${localPath}video_story.mp4';

    Loggers.info('[Story Upload] Checking moderation for video...');

    var timelineInput = await exportTimelineToSingleVideo(inputFile);

    timelineInput = await _applyPipIfNeeded(timelineInput);

    await SightEngineService.shared.checkVideoInSightEngine(
      xFile: XFile(timelineInput),
      duration: storyDuration,
      completion: () async {
        Loggers.info('[Story Upload] Moderation completed.');
        updateUploadingProgress(progress: 20);

        String finalVideoPath = timelineInput;
        final hasUserVoice = videoVolume.value > 0.0;
        List<double> filtersValue =
            listEquals(selectedFilter.value, filters.first.colorFilter)
                ? []
                : selectedFilter.value;
        String? audioPath = story.sound?.downloadedURL;
        double audioStartMS =
            double.tryParse('${story.sound?.audioStartMS ?? 0}') ?? 0.0;
        // Apply filter + music with volumes
        if (audioPath != null) {
          try {
            String base = timelineInput;
            if (filtersValue.isNotEmpty) {
              final tmp = '${localPath}story_filter_tmp.mp4';
              final r = await _retrytechPlugin.applyFilterAndAudioToVideo(
                inputPath: timelineInput,
                outputPath: tmp,
                shouldBothMusics: true,
                filterValues: filtersValue,
              );
              if (r != true) {
                Loggers.error('[Story Upload] Failed to apply filter');
                failedResponseSnackBar();
                return;
              }
              base = tmp;
            }

            finalVideoPath =
                await VideoTimelineService.shared.mixVideoWithExternalAudio(
              inputVideoPath: base,
              inputAudioPath: audioPath,
              outputPath: outputPath,
              audioStartMs: audioStartMS.round(),
              originalVolume: videoVolume.value,
              musicVolume: musicVolume.value,
              includeOriginalAudio: hasUserVoice,
            );
          } catch (e) {
            Loggers.error('[Story Upload] Failed to apply filter/audio: $e');
            failedResponseSnackBar();
            return;
          }
        } else if (filtersValue.isNotEmpty) {
          try {
            final r = await _retrytechPlugin.applyFilterAndAudioToVideo(
              inputPath: timelineInput,
              outputPath: outputPath,
              shouldBothMusics: true,
              filterValues: filtersValue,
            );
            if (r == true) finalVideoPath = outputPath;
          } catch (e) {
            Loggers.error('[Story Upload] Failed to apply filter: $e');
          }
        }

        updateUploadingProgress(progress: 90);

        try {
          String thumbPath = (story.thumbNail ?? '').trim();
          if (thumbPath.isEmpty || !File(thumbPath).existsSync()) {
            try {
              final x = await MediaPickerHelper.shared.extractThumbnail(
                videoPath: finalVideoPath,
              );
              thumbPath = x.path;
            } catch (e) {
              Loggers.error('[Story Upload] thumbnail extract failed: $e');
            }
          }

          if (thumbPath.trim().isEmpty) {
            failedResponseSnackBar();
            return;
          }
          await addStory(
            content: finalVideoPath,
            duration: storyDuration,
            type: PostStoryContentType.storyVideo,
            musicId: story.sound?.music?.id ?? -1,
            thumbnail: thumbPath,
          );
        } catch (e) {
          Loggers.error('❌ Error posting image/text story: $e');
        } finally {
          isMergingVideo.value = false;
        }
      },
    );
  }

  /// Handles image/text story: moderation, screenshot, optional music or filter
  Future<void> _processImageOrTextStory(int storyDuration) async {
    final story = content.value;
    final controller = Get.find<StoryTextViewController>();
    showLoader();
    final screenshot = await ScreenshotManager.captureScreenshot(
      controller.previewContainer,
    );
    if (screenshot == null) {
      stopLoader();
      return Loggers.error('❌ Failed to capture screenshot');
    }

    final imagePath = screenshot.path;
    MediaPickerHelper.shared
        .compressImage(screenshot.path, '${localPath}compress_images.jpg')
        .then((value) async {
      stopLoader();
      if (value == null) {
        return Loggers.error('❌ Failed to compress image');
      }
      await SightEngineService.shared.checkImagesInSightEngine(
        xFiles: [value],
        completion: () async {
          Loggers.info('[Story Upload] Moderation completed.');
          updateUploadingProgress(progress: 20);

          final audioPath = story.sound?.downloadedURL;
          final audioStartMS =
              double.tryParse('${story.sound?.audioStartMS ?? 0.0}') ?? 0.0;
          final musicId = story.sound?.music?.id ?? -1;
          final videoPath = '${localPath}image_to_video.mp4';

          if (audioPath != null) {
            Loggers.info('🎵 Music found, generating video from image...');

            bool? success = await _retrytechPlugin.createVideoFromImage(
              inputPath: imagePath,
              outputPath: videoPath,
              audioStartTimeInMS: audioStartMS,
              audioPath: audioPath,
              videoTotalDurationInSec: storyDuration.toDouble(),
            );

            final contentPath = success == true ? videoPath : imagePath;

            updateUploadingProgress(progress: 90);

            await addStory(
              duration: storyDuration,
              content: contentPath,
              type: PostStoryContentType.storyVideo,
              musicId: musicId,
              thumbnail: imagePath,
            );
          } else {
            updateUploadingProgress(progress: 90);
            await addStory(
              duration: storyDuration,
              content: imagePath,
              type: PostStoryContentType.storyImage,
              musicId: -1,
            );
          }
        },
      );
    });
  }

  void updateUploadingProgress({required double progress}) {
    _dashboardController.onProgress.call(
      PostUploadingProgress(
        uploadType: _lastUploadType,
        progress: progress,
        type: CameraScreenType.story,
      ),
    );

    if (progress == 100) {
      _resetUploadingProgressAfterDelay();
    }
  }

  void _resetUploadingProgressAfterDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      _dashboardController.onProgress.call(
        PostUploadingProgress(
          uploadType: UploadType.none,
          progress: 0,
          type: CameraScreenType.post, // or use last type if needed
        ),
      );
    });
  }

  Future<void> failedResponseSnackBar() async {
    _lastUploadType = UploadType.error;
    updateUploadingProgress(progress: 100);
    return;
  }

  void onMusicDelete() {
    content.update((val) => val?.sound = null);
    audioPlayer.stopPlayer();
    audioPlayer.release();
    videoPlayerController.value?.setVolume(1);
  }

  /// Opens the music selection sheet and applies the selected music to the story
  Future<void> handleMusicSelection({SelectedMusic? initialMusic}) async {
    final isTextOrImage = [
      PostStoryContentType.storyImage,
      PostStoryContentType.storyText,
    ].contains(content.value.type);

    // Pause appropriate media before opening selection
    isTextOrImage ? _pauseAudioOnly() : _pausePlayback();

    final duration =
        isTextOrImage ? selectStorySecond : content.value.duration ?? 0;

    videoPlayerController.value?.pause();

    final SelectedMusic? selectedMusic = await Get.bottomSheet<SelectedMusic?>(
      initialMusic != null
          ? SelectedMusicSheet(
              selectedMusic: initialMusic,
              totalVideoSecond: duration,
            )
          : MusicSheet(videoDurationInSecond: duration),
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
    );

    // Handle result
    await _processSelectedMusic(selectedMusic, isTextOrImage);
  }

  /// Shared logic to apply selected music and resume playback
  Future<void> _processSelectedMusic(
    SelectedMusic? selectedMusic,
    bool isTextOrImage,
  ) async {
    if (selectedMusic == null) {
      isTextOrImage ? _playAudioOnly() : _startPlayback();
      return;
    }

    // Ensure we preserve/initialize music volume
    selectedMusic.volume = (selectedMusic.volume).clamp(0.0, 1.0);
    musicVolume.value = selectedMusic.volume;
    content.update((val) => val?.sound = selectedMusic);

    final audioUrl = selectedMusic.downloadedURL;
    final startMs = selectedMusic.audioStartMS ?? 0;

    if (audioUrl != null) {
      await _prepareAudioPlayer(audioPath: audioUrl, milliSecond: startMs);

      switch (content.value.type) {
        case PostStoryContentType.storyImage:
        case PostStoryContentType.storyText:
          _playAudioOnly();
          break;
        case PostStoryContentType.reel:
        case PostStoryContentType.storyVideo:
          videoPlayerController.value?.setVolume(0.0);
          _restartVideoAndAudio();
          break;
      }
    }
  }

  Future<void> _prepareAudioPlayer({
    required String audioPath,
    int? milliSecond,
  }) async {
    await audioPlayer.preparePlayer(path: audioPath);
    await audioPlayer.seekTo(milliSecond ?? 0);
    audioPlayer.setFinishMode(finishMode: FinishMode.pause);
    try {
      await audioPlayer.setVolume(musicVolume.value.clamp(0.0, 1.0));
    } catch (_) {}
  }

  changeBg(bool isTextStory) async {
    if (isTextStory) {
      selectedBgIndex.value =
          (selectedBgIndex.value + 1) % storyGradientColor.length;
    } else {
      final gradient = await content.value.content?.getGradientFromImage;
      content.update((val) => val?.bgGradient = gradient);
    }
  }

  changeStoryTime() async {
    currentStoryDurationIndex.value =
        (currentStoryDurationIndex.value + 1) % AppRes.storyDurations.length;
    selectStorySecond = AppRes.storyDurations[currentStoryDurationIndex.value];
    if (content.value.sound != null) {
      await _pauseAudioOnly();
      _playAudioOnly();
    }
  }
}
