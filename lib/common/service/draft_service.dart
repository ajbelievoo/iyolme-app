import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shortzz/screen/camera_screen/camera_screen_controller.dart';
import 'package:shortzz/screen/selected_music_sheet/selected_music_sheet_controller.dart';
import 'package:shortzz/model/post_story/music/music_model.dart';
import 'package:uuid/uuid.dart';
import 'package:shortzz/common/manager/logger.dart';

class DraftService extends GetxService {
  static DraftService get instance => Get.find<DraftService>();
  final _box = GetStorage('shortzz_drafts');
  final _keyDrafts = 'drafts_list';

  Future<void> init() async {
    await deleteExpiredDrafts();
  }

  Future<void> saveDraft(PostStoryContent content) async {
    final drafts = getDrafts();

    // If updating existing draft, remove old one first
    String id;
    if (content.draftId != null && drafts.any((d) => d.id == content.draftId)) {
      id = content.draftId!;
      // We don't delete files immediately because we might need them for the update
      // But we should clean up the old entry
      drafts.removeWhere((d) => d.id == id);
      // NOTE: Real implementation might be more complex to avoid overwriting files in use
      // For now, we'll reuse the ID but clear the folder if needed,
      // or simpler: just delete old draft and create new one with SAME ID.
      await deleteDraft(id);
      // Re-use ID
    } else {
      // Check limit for new drafts
      if (drafts.length >= 10) {
        final oldest =
            drafts.reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b);
        await deleteDraft(oldest.id);
      }
      id = const Uuid().v4();
    }

    final docDir = await getApplicationDocumentsDirectory();
    final draftDir = Directory(p.join(docDir.path, 'drafts', id));
    if (!await draftDir.exists()) {
      await draftDir.create(recursive: true);
    }
    // ... copy logic follows ...

    // Copy files to permanent storage
    String? contentPath = content.content;
    try {
      if (contentPath != null && File(contentPath).existsSync()) {
        final fileName = p.basename(contentPath);
        final newPath = p.join(draftDir.path, fileName);
        await File(contentPath).copy(newPath);
        contentPath = newPath;
      }
    } catch (e) {
      Loggers.info('Draft content copy error: $e');
    }

    String? thumbPath = content.thumbNail;
    try {
      if (thumbPath != null && File(thumbPath).existsSync()) {
        final fileName = p.basename(thumbPath);
        final newPath = p.join(draftDir.path, fileName);
        await File(thumbPath).copy(newPath);
        thumbPath = newPath;
      }
    } catch (e) {
      Loggers.info('Draft thumbnail copy error: $e');
    }

    List<String>? additionalContent;
    if (content.additionalContent != null) {
      additionalContent = [];
      for (var path in content.additionalContent!) {
        if (File(path).existsSync()) {
          final fileName = p.basename(path);
          final newPath = p.join(draftDir.path, fileName);
          await File(path).copy(newPath);
          additionalContent.add(newPath);
        }
      }
    }

    final draft = DraftModel(
      id: id,
      createdAt: DateTime.now(),
      type: content.type.index,
      contentPath: contentPath,
      thumbnailPath: thumbPath,
      duration: content.duration,
      additionalContent: additionalContent,
      speeds: content.speeds,
      hasAudio: content.hasAudio,
      isFrontCamera: content.isFrontCamera,
      // Store music info if needed
      musicId: content.sound?.music?.id?.toString(),
      musicTitle: content.sound?.music?.title,
      musicUrl: content.sound?.downloadedURL,
      musicStartMs: content.sound?.audioStartMS,
    );

    final currentList = getDrafts();
    currentList.add(draft);
    await _box.write(_keyDrafts, currentList.map((e) => e.toJson()).toList());
  }

  List<DraftModel> getDrafts() {
    final raw = _box.read(_keyDrafts);
    if (raw == null) return [];
    if (raw is! List) return [];
    return raw.map((e) => DraftModel.fromJson(e)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
  }

  Future<void> deleteDraft(String id) async {
    final drafts = getDrafts();
    final draft = drafts.firstWhereOrNull((element) => element.id == id);
    if (draft != null) {
      // Delete files
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final draftDir = Directory(p.join(docDir.path, 'drafts', id));
        if (await draftDir.exists()) {
          await draftDir.delete(recursive: true);
        }
      } catch (e) {
        Loggers.info('Error deleting draft files: $e');
      }

      drafts.removeWhere((element) => element.id == id);
      await _box.write(_keyDrafts, drafts.map((e) => e.toJson()).toList());
    }
  }

  Future<void> deleteExpiredDrafts() async {
    final drafts = getDrafts();
    final now = DateTime.now();
    final expired =
        drafts.where((d) => now.difference(d.createdAt).inDays >= 7).toList();

    for (var draft in expired) {
      await deleteDraft(draft.id);
    }
  }
}

class DraftModel {
  final String id;
  final DateTime createdAt;
  final int type;
  final String? contentPath;
  final String? thumbnailPath;
  final int? duration;
  final List<String>? additionalContent;
  final List<double>? speeds;
  final bool hasAudio;
  final bool isFrontCamera;

  // Music info
  final String? musicId;
  final String? musicTitle;
  final String? musicUrl;
  final int? musicStartMs;

  DraftModel({
    required this.id,
    required this.createdAt,
    required this.type,
    this.contentPath,
    this.thumbnailPath,
    this.duration,
    this.additionalContent,
    this.speeds,
    this.hasAudio = true,
    this.isFrontCamera = false,
    this.musicId,
    this.musicTitle,
    this.musicUrl,
    this.musicStartMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'type': type,
        'contentPath': contentPath,
        'thumbnailPath': thumbnailPath,
        'duration': duration,
        'additionalContent': additionalContent,
        'speeds': speeds,
        'hasAudio': hasAudio,
        'isFrontCamera': isFrontCamera,
        'musicId': musicId,
        'musicTitle': musicTitle,
        'musicUrl': musicUrl,
        'musicStartMs': musicStartMs,
      };

  factory DraftModel.fromJson(Map<String, dynamic> json) => DraftModel(
        id: json['id'],
        createdAt: DateTime.parse(json['createdAt']),
        type: json['type'],
        contentPath: json['contentPath'],
        thumbnailPath: json['thumbnailPath'],
        duration: json['duration'],
        additionalContent: (json['additionalContent'] as List?)
            ?.map((e) => e.toString())
            .toList(),
        speeds: (json['speeds'] as List?)
            ?.map((e) => double.parse(e.toString()))
            .toList(),
        hasAudio: json['hasAudio'] ?? true,
        isFrontCamera: json['isFrontCamera'] ?? false,
        musicId: json['musicId'],
        musicTitle: json['musicTitle'],
        musicUrl: json['musicUrl'],
        musicStartMs: json['musicStartMs'],
      );

  PostStoryContent toContent() {
    SelectedMusic? music;
    if (musicId != null) {
      final musicObj = Music(
        id: int.tryParse(musicId ?? ''),
        title: musicTitle,
      );

      music = SelectedMusic(
        musicObj,
        musicStartMs,
        musicUrl,
        (musicStartMs ?? 0) + (duration ?? 0), // Estimate endMilliSec
      );
    }

    return PostStoryContent(
      type: PostStoryContentType.values[type],
      content: contentPath,
      thumbNail: thumbnailPath,
      duration: duration,
      additionalContent: additionalContent,
      speeds: speeds,
      hasAudio: hasAudio,
      isFrontCamera: isFrontCamera,
      sound: music,
      draftId: id, // Pass ID back so we can update it later
    );
  }
}
