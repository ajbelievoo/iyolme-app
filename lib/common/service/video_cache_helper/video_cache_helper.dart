import 'dart:async';
import 'dart:io' as io;
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shortzz/common/manager/logger.dart';

class VideoCacheHelper {
  static const _keyPrefix = 'video_cache_';
  static const expirationMinutes = 360;

  static int _activeDownloads = 0;
  static const int _maxConcurrentDownloads = 3;
  static final Set<String> _downloadQueue = <String>{};

  static final GetStorage _storage = GetStorage(_keyPrefix);
  static const key = 'customCacheKey';
  static final CacheManager _cacheManager = CacheManager(
    Config(
      key,
      // ❗ How long a file is considered "fresh".
      // After 10 minute, it's marked as "stale" and can be re-downloaded.
      stalePeriod: const Duration(minutes: expirationMinutes),

      // ❗ Maximum number of cached videos allowed.
      // If more than 50 videos are cached, the oldest will be deleted automatically.
      maxNrOfCacheObjects: 50,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileSystem: IOFileSystem(key),
      fileService: HttpFileService(),
    ),
  );

  /// Returns local file if valid cache exists, otherwise null
  static Future<FileInfo?> getValidCachedVideo(String url) async {
    final storageKey = '$_keyPrefix$url';
    final timestampStr = _storage.read<String>(storageKey);

    if (timestampStr != null) {
      final timestamp = DateTime.tryParse(timestampStr);
      if (timestamp != null &&
          DateTime.now().difference(timestamp).inMinutes < expirationMinutes) {
        final cachedFile = await _cacheManager.getFileFromCache(storageKey);
        if (cachedFile != null) {
          Loggers.info('[CACHE] Valid cached video found: ${cachedFile.file.path}');
          return cachedFile;
        }
      }
    }

    Loggers.info('[CACHE] No valid cache or cache expired for $url');
    return null;
  }

  /// Downloads video and stores timestamp
  static Future<FileInfo> downloadAndCacheVideo(String url) async {
    final storageKey = '$_keyPrefix$url';
    Loggers.info('[DOWNLOAD] Downloading $url');
    final fileInfo = await _cacheManager.downloadFile(url, key: storageKey);
    Loggers.info('[DOWNLOAD] Download complete: ${fileInfo.file.path}');

    _storage.write(storageKey, DateTime.now().toIso8601String());
    return fileInfo;
  }

  static void enqueueDownload(String url) {
    if (url.isEmpty) return;
    _downloadQueue.add(url);
    _processQueue();
  }

  static void _processQueue() {
    // Fire up to _maxConcurrentDownloads parallel downloads — serial fetching
    // made the next reel wait behind the current one (slow scrolling reels).
    while (_downloadQueue.isNotEmpty &&
        _activeDownloads < _maxConcurrentDownloads) {
      final url = _downloadQueue.first;
      _downloadQueue.remove(url);
      _activeDownloads++;
      () async {
        try {
          await downloadAndCacheVideo(url);
        } catch (_) {
        } finally {
          _activeDownloads--;
          _processQueue();
        }
      }();
    }
  }

  /// Clears all expired videos manually
  static Future<void> clearExpiredVideos() async {
    try {
      final allKeys = _storage.getKeys().toList();
      final List<String> validPaths = [];

      for (final key in allKeys) {
        final file = await _cacheManager.getFileFromCache(key);
        if (file != null) {
          // Keep track of valid files
          validPaths.add(file.file.path);
        } else {
          // If not in cache, remove the timestamp
          await _storage.remove(key);
          Loggers.info('[CLEAR] Removed expired storage key: $key');
        }
      }

      // Read actual files from the cache directory
      final cacheDir = await getTemporaryDirectory();
      final cachePath = '${cacheDir.path}/$key/';
      final dir = io.Directory(cachePath);

      if (await dir.exists()) {
        final List<FileSystemEntity> allFiles = dir.listSync();

        // Delete files not in validPaths list
        for (final file in allFiles) {
          if (!validPaths.contains(file.path)) {
            await file.delete();
            Loggers.info('[CLEAR] Deleted unused file: ${file.path}');
          }
        }

        Loggers.info('[CLEAR] Valid cached paths: ${validPaths.length}');
        Loggers.info(
            '[CLEAR] Total files deleted: ${allFiles.length - validPaths.length}');
      } else {
        Loggers.info('[CLEAR] Cache directory does not exist: $cachePath');
      }
    } catch (e) {
      Loggers.info('[ERROR] clearExpiredVideos: $e');
    }
  }

  /// Clears all video cache and related timestamp storage
  static Future<void> clearAllCache() async {
    try {
      // Delete all files from the cache directory
      final cacheDir = await getTemporaryDirectory();
      final cachePath = '${cacheDir.path}/$key/';
      final dir = io.Directory(cachePath);

      if (await dir.exists()) {
        final files = dir.listSync();
        for (final file in files) {
          try {
            await file.delete();
          } catch (e) {
            Loggers.info('[WARNING] Failed to delete file: ${file.path}, error: $e');
          }
        }
        Loggers.info('[CACHE] Cache directory cleared: $cachePath');
      } else {
        Loggers.info('[CACHE] Cache directory not found: $cachePath');
      }

      // Clear all storage keys
      final allKeys = List<String>.from(_storage.getKeys());
      for (final key in allKeys) {
        await _storage.remove(key);
      }

      Loggers.info('[CACHE] All cache keys cleared');
    } catch (e) {
      Loggers.info('[ERROR] clearAllCache: $e');
    }
  }
}
