import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:path/path.dart' as p;

import 'video_segment.dart';
import 'package:shortzz/common/manager/logger.dart';

class VideoTimelineService {
  VideoTimelineService._();

  static final VideoTimelineService shared = VideoTimelineService._();

  String _h264Encoder() {
    return 'libx264';
  }

  String get _h264CompatFlags => '-profile:v high -level 4.1';

  void _logLong(String message, {int chunkSize = 800}) {
    // debugPrint truncates long messages; print chunked so it is searchable in console.
    final m = message;
    for (var i = 0; i < m.length; i += chunkSize) {
      final end = (i + chunkSize < m.length) ? i + chunkSize : m.length;
      // ignore: avoid_print
      Loggers.info(m.substring(i, end));
    }
  }

  Future<double> getDurationSec(String inputPath) async {
    final session = await FFprobeKit.getMediaInformation(inputPath);
    final info = session.getMediaInformation();
    final durationStr = info?.getDuration();
    final d = double.tryParse(durationStr ?? '');
    return d ?? 0.0;
  }

  Future<MapEntry<int, int>> getVideoSize(String inputPath) async {
    final session = await FFprobeKit.getMediaInformation(inputPath);
    final info = session.getMediaInformation();
    final streams = info?.getStreams() ?? const [];
    for (final s in streams) {
      final type = (s.getType() ?? '').toString().toLowerCase();
      if (type != 'video') continue;
      final w = int.tryParse('${s.getWidth() ?? ''}') ?? 0;
      final h = int.tryParse('${s.getHeight() ?? ''}') ?? 0;
      if (w > 0 && h > 0) {
        return MapEntry(w, h);
      }
    }
    return const MapEntry(0, 0);
  }

  Future<void> _ensureParentDir(String filePath) async {
    final dir = Directory(p.dirname(filePath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  Future<void> _runFFmpeg(String command) async {
    _logLong('FFMPEG_CMD: $command');
    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();
    if (rc == null || !ReturnCode.isSuccess(rc)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg failed (rc=${rc?.getValue()}): $logs');
    }
  }

  String _escape(String path) {
    return path.replaceAll('\\', '/').replaceAll("'", "\\'");
  }

  Future<String> burnInPngOverlay({
    required String inputVideoPath,
    required String overlayPngPath,
    required String outputPath,
  }) async {
    final inV = inputVideoPath.trim();
    final inO = overlayPngPath.trim();
    final out = outputPath.trim();
    if (inV.isEmpty || inO.isEmpty || out.isEmpty) {
      throw ArgumentError('Invalid paths for burnInPngOverlay');
    }
    await _ensureParentDir(out);

    const filter =
        '"[1:v][0:v]scale2ref=w=iw:h=ih[ov][base];[base][ov]overlay=0:0:format=auto"';
    final cmd =
        "-y -i '${_escape(inV)}' -i '${_escape(inO)}' -filter_complex $filter -map 0:v -map 0:a? -c:v ${_h264Encoder()} $_h264CompatFlags -preset veryfast -crf 23 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k '${_escape(out)}'";
    await _runFFmpeg(cmd);
    return out;
  }

  Future<String> burnInGifOverlays({
    required String inputVideoPath,
    required List<String> gifPaths,
    required List<ui.Rect> placements,
    required String outputPath,
  }) async {
    final inV = inputVideoPath.trim();
    final out = outputPath.trim();
    if (inV.isEmpty || out.isEmpty) {
      throw ArgumentError('Invalid paths for burnInGifOverlays');
    }
    if (gifPaths.isEmpty || placements.isEmpty) {
      return inputVideoPath;
    }
    if (gifPaths.length != placements.length) {
      throw ArgumentError('gifPaths and placements must have same length');
    }
    await _ensureParentDir(out);

    final args = <String>[];
    args.add("-y -i '${_escape(inV)}'");
    for (final g in gifPaths) {
      args.add("-ignore_loop 0 -i '${_escape(g)}'");
    }

    final filters = <String>[];
    String last = '[0:v]';
    for (var i = 0; i < gifPaths.length; i++) {
      final p = placements[i];
      final w = p.width.round().clamp(2, 4096);
      final h = p.height.round().clamp(2, 4096);
      final x = p.left.round().clamp(-4096, 4096);
      final y = p.top.round().clamp(-4096, 4096);

      final gi = i + 1;
      final gTag = '[g$i]';
      final ovTag = '[v$i]';
      filters.add('[$gi:v]scale=$w:$h:flags=lanczos,format=rgba$gTag');

      // Overlay with shortest=1 so it stops when base stops.
      final base = (i == 0) ? '[0:v]' : last;
      filters.add('$base$gTag overlay=$x:$y:format=auto:shortest=1$ovTag');
      last = ovTag;
    }

    final filterComplex = '"${filters.join(';')}"';
    final cmd =
        "${args.join(' ')} -filter_complex $filterComplex -map '$last' -map 0:a? -c:v ${_h264Encoder()} $_h264CompatFlags -preset veryfast -crf 23 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k '${_escape(out)}'";
    await _runFFmpeg(cmd);
    return out;
  }

  Future<String> applyCubeLut({
    required String inputVideoPath,
    required String cubeFilePath,
    required String outputPath,
    double strength = 1.0,
    double? startSec,
    double? durationSec,
  }) async {
    final inV = inputVideoPath.trim();
    final cube = cubeFilePath.trim();
    final out = outputPath.trim();
    if (inV.isEmpty || cube.isEmpty || out.isEmpty) {
      throw ArgumentError('Invalid paths for applyCubeLut');
    }
    await _ensureParentDir(out);

    final s = strength.clamp(0.0, 1.0);
    final seek = (startSec != null && startSec >= 0) ? "-ss $startSec " : '';
    final dur =
        (durationSec != null && durationSec > 0) ? "-t $durationSec " : '';

    // Apply LUT and optionally blend with original for intensity (Instagram-like strength slider).
    // blend works on video only, audio is copied if present.
    final filter = s >= 0.999
        ? "lut3d='${_escape(cube)}'"
        : "[0:v]split=2[base][l0];[l0]lut3d='${_escape(cube)}'[lut];[base][lut]blend=all_mode=normal:all_opacity=$s";

    final vf = "-vf \"$filter\"";
    final cmd =
        "-y $seek$dur-i '${_escape(inV)}' $vf -map 0:v -map 0:a? -c:v ${_h264Encoder()} $_h264CompatFlags -preset veryfast -crf 23 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k '${_escape(out)}'";
    await _runFFmpeg(cmd);
    return out;
  }

  Future<String> applyHorizontalFlip({
    required String inputPath,
    required String outputPath,
  }) async {
    await _ensureParentDir(outputPath);
    final cmd =
        "-y -i '${_escape(inputPath)}' -vf hflip -map 0:v -map 0:a? -c:v ${_h264Encoder()} $_h264CompatFlags -preset veryfast -crf 23 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k '${_escape(outputPath)}'";
    await _runFFmpeg(cmd);
    return outputPath;
  }

  Future<String> applyPipOverlay({
    required String inputVideoPath,
    required String pipVideoPath,
    required String outputPath,
    double scaleFraction = 0.32,
    int marginPx = 18,
  }) async {
    final base = inputVideoPath.trim();
    final pip = pipVideoPath.trim();
    final out = outputPath.trim();
    if (base.isEmpty || pip.isEmpty || out.isEmpty) {
      throw ArgumentError('Invalid paths for applyPipOverlay');
    }
    await _ensureParentDir(out);

    final size = await getVideoSize(base);
    final baseW = size.key;
    final baseH = size.value;
    if (baseW <= 0 || baseH <= 0) {
      throw Exception('Failed to detect base video size');
    }

    final frac = scaleFraction.clamp(0.1, 0.8);
    final pipW = (baseW * frac).round().clamp(2, 4096);
    final m = marginPx.clamp(0, 4096);

    // Keep main audio (0:a) only. Ignore PiP audio.
    final filter =
        '"[1:v]scale=$pipW:-1:flags=lanczos[pip];[0:v][pip]overlay=W-w-$m:H-h-$m:format=auto:shortest=1[v]"';

    final cmd =
        "-y -i '${_escape(base)}' -i '${_escape(pip)}' -filter_complex $filter -map '[v]' -map 0:a? -c:v ${_h264Encoder()} $_h264CompatFlags -preset veryfast -crf 23 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k '${_escape(out)}'";
    await _runFFmpeg(cmd);
    return out;
  }

  List<MapEntry<double, double>> _parseSilenceKeepRanges({
    required String logs,
    required double totalDurationSec,
  }) {
    final total = totalDurationSec <= 0 ? 0.0 : totalDurationSec;
    if (total <= 0) return const [];

    final silenceStartRe = RegExp(r'silence_start:\s*([0-9.]+)');
    final silenceEndRe = RegExp(
        r'silence_end:\s*([0-9.]+)\s*\|\s*silence_duration:\s*([0-9.]+)');

    final silenceRanges = <MapEntry<double, double>>[];
    double? pendingStart;

    for (final line in logs.split('\n')) {
      final s = silenceStartRe.firstMatch(line);
      if (s != null) {
        pendingStart = double.tryParse(s.group(1) ?? '');
        continue;
      }
      final e = silenceEndRe.firstMatch(line);
      if (e != null) {
        final end = double.tryParse(e.group(1) ?? '');
        final start = pendingStart;
        pendingStart = null;
        if (start != null && end != null && end > start) {
          silenceRanges.add(MapEntry(start, end));
        }
      }
    }

    // If silence starts but never ends, assume until end of media.
    if (pendingStart != null) {
      silenceRanges.add(MapEntry(pendingStart, total));
    }

    if (silenceRanges.isEmpty) {
      return [MapEntry(0.0, total)];
    }

    // Build keep ranges: [0..s1.start], [s1.end..s2.start], ...
    final keep = <MapEntry<double, double>>[];
    double cursor = 0.0;
    for (final r in silenceRanges) {
      final start = r.key.clamp(0.0, total);
      final end = r.value.clamp(0.0, total);
      if (start > cursor) {
        keep.add(MapEntry(cursor, start));
      }
      cursor = end;
    }
    if (cursor < total) {
      keep.add(MapEntry(cursor, total));
    }

    // Remove tiny clips (< 120ms) which can cause concat issues.
    return keep.where((k) => (k.value - k.key) >= 0.12).toList();
  }

  Future<String> cutSilences({
    required String inputPath,
    required String outputPath,
    double noiseDb = -35.0,
    double minSilenceDurationSec = 0.35,
    double padSec = 0.05,
    void Function(double progress, String stage)? onProgress,
  }) async {
    await _ensureParentDir(outputPath);

    final total = await getDurationSec(inputPath);
    if (total <= 0) {
      return inputPath;
    }

    onProgress?.call(0.0, 'Detecting silences');

    // 1) Detect silence ranges
    final logBuf = StringBuffer();
    final detectCmd =
        "-y -i '${_escape(inputPath)}' -af silencedetect=noise=${noiseDb}dB:d=$minSilenceDurationSec -f null -";

    final detectCompleter = Completer<void>();
    FFmpegKit.executeAsync(
      detectCmd,
      (session) async {
        final rc = await session.getReturnCode();
        if (rc == null || !ReturnCode.isSuccess(rc)) {
          final logs = await session.getAllLogsAsString();
          detectCompleter.completeError(
              Exception('silencedetect failed (rc=${rc?.getValue()}): $logs'));
          return;
        }
        detectCompleter.complete();
      },
      (log) {
        try {
          logBuf.writeln(log.getMessage());
        } catch (_) {}
      },
    );

    await detectCompleter.future;

    final keepRanges = _parseSilenceKeepRanges(
      logs: logBuf.toString(),
      totalDurationSec: total,
    );

    if (keepRanges.length <= 1 && keepRanges.isNotEmpty) {
      // No real silence detected.
      onProgress?.call(1.0, 'Done');
      return inputPath;
    }
    if (keepRanges.isEmpty) {
      // Everything was silence; keep original.
      onProgress?.call(1.0, 'Done');
      return inputPath;
    }

    // Apply padding so we don't cut too tight.
    final padded = keepRanges
        .map((r) => MapEntry(
              (r.key - padSec).clamp(0.0, total),
              (r.value + padSec).clamp(0.0, total),
            ))
        .toList();

    // 2) Render segments (re-encode for safe cutting)
    onProgress?.call(0.0, 'Cutting clips');
    final tmpDir = Directory(p.join(p.dirname(outputPath),
        'cut_silences_${DateTime.now().millisecondsSinceEpoch}'));
    if (!tmpDir.existsSync()) tmpDir.createSync(recursive: true);

    final segmentPaths = <String>[];
    for (var i = 0; i < padded.length; i++) {
      final r = padded[i];
      final start = r.key;
      final end = r.value;
      final dur = (end - start).clamp(0.0, 1e9);
      if (dur < 0.12) continue;

      final segPath =
          p.join(tmpDir.path, 'seg_${i.toString().padLeft(3, '0')}.mp4');
      final cmd =
          "-y -ss $start -i '${_escape(inputPath)}' -t $dur -map 0:v -map 0:a? -c:v ${_h264Encoder()} $_h264CompatFlags -preset veryfast -crf 23 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k '${_escape(segPath)}'";

      final segCompleter = Completer<void>();
      FFmpegKit.executeAsync(
        cmd,
        (session) async {
          final rc = await session.getReturnCode();
          if (rc == null || !ReturnCode.isSuccess(rc)) {
            final logs = await session.getAllLogsAsString();
            segCompleter.completeError(Exception(
                'segment encode failed (rc=${rc?.getValue()}): $logs'));
            return;
          }
          segCompleter.complete();
        },
        null,
        (stats) {
          try {
            // stats.getTime() is in ms
            final pSeg = (stats.getTime() / (dur * 1000.0)).clamp(0.0, 1.0);
            final overall = ((i + pSeg) / padded.length).clamp(0.0, 1.0);
            onProgress?.call(overall, 'Cutting clips');
          } catch (_) {}
        },
      );
      await segCompleter.future;
      segmentPaths.add(segPath);
    }

    if (segmentPaths.isEmpty) {
      onProgress?.call(1.0, 'Done');
      return inputPath;
    }

    // 3) Concat
    onProgress?.call(0.0, 'Joining clips');
    final listFile = File(p.join(tmpDir.path, 'concat.txt'));
    await listFile.writeAsString(
      segmentPaths.map((e) => "file '${_escape(e)}'").join('\n'),
    );

    // Copy should work because all segments are encoded same.
    final concatCmd =
        "-y -f concat -safe 0 -i '${_escape(listFile.path)}' -c copy '${_escape(outputPath)}'";

    final concatCompleter = Completer<void>();
    FFmpegKit.executeAsync(
      concatCmd,
      (session) async {
        final rc = await session.getReturnCode();
        if (rc == null || !ReturnCode.isSuccess(rc)) {
          final logs = await session.getAllLogsAsString();
          concatCompleter.completeError(
              Exception('concat failed (rc=${rc?.getValue()}): $logs'));
          return;
        }
        concatCompleter.complete();
      },
      null,
      (stats) {
        try {
          final overall = (stats.getTime() / (total * 1000.0)).clamp(0.0, 1.0);
          onProgress?.call(overall, 'Joining clips');
        } catch (_) {}
      },
    );

    try {
      await concatCompleter.future;
    } finally {
      // Best-effort cleanup
      try {
        if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      } catch (_) {}
    }

    onProgress?.call(1.0, 'Done');
    return outputPath;
  }

  Future<String> cutSegment({
    required String inputPath,
    required double startSec,
    required double endSec,
    required String outputPath,
  }) async {
    await _ensureParentDir(outputPath);
    final start = startSec < 0 ? 0 : startSec;
    final dur = (endSec - start).clamp(0.0, 1e9);
    final cmd =
        "-y -ss $start -i '${_escape(inputPath)}' -t $dur -c copy '${_escape(outputPath)}'";
    await _runFFmpeg(cmd);
    return outputPath;
  }

  String _cropFilter(VideoCropPreset preset) {
    switch (preset) {
      case VideoCropPreset.original:
        return '';
      case VideoCropPreset.square1x1:
        return "crop='if(gt(iw,ih),ih,iw)':'if(gt(iw,ih),ih,iw)'";
      case VideoCropPreset.portrait4x5:
        return "crop='if(gt(iw/ih,4/5),ih*4/5,iw)':'if(gt(iw/ih,4/5),ih,iw*5/4)'";
      case VideoCropPreset.landscape16x9:
        return "crop='if(gt(iw/ih,16/9),ih*16/9,iw)':'if(gt(iw/ih,16/9),ih,iw*9/16)'";
      case VideoCropPreset.portrait9x16:
        return "crop='if(gt(iw/ih,9/16),ih*9/16,iw)':'if(gt(iw/ih,9/16),ih,iw*16/9)'";
    }
  }

  String _audioFxFilter(VideoAudioFx fx) {
    switch (fx) {
      case VideoAudioFx.none:
        return '';
      case VideoAudioFx.echo:
        return 'aecho=0.8:0.88:60:0.4';
      case VideoAudioFx.robot:
        return 'acrusher=bits=8:mix=0.8';
      case VideoAudioFx.chipmunk:
        return 'asetrate=44100*1.25,atempo=0.8';
    }
  }

  String _atempoChain(double speed) {
    final s = speed.clamp(0.5, 2.0);
    // atempo supports 0.5..2.0, so we only support that range here.
    return 'atempo=$s';
  }

  Future<String> renderSegmentEdits({
    required String inputPath,
    required VideoSegmentEdits edits,
    required String outputPath,
    bool isPreview = false,
  }) async {
    await _ensureParentDir(outputPath);

    final vfParts = <String>[];
    final afParts = <String>[];

    final crop = _cropFilter(edits.crop);
    if (crop.isNotEmpty) vfParts.add(crop);

    if (isPreview) {
      // Force fixed resolution 360x640 (9:16) for preview to ensure concat works.
      // Use pad to handle aspect ratio differences.
      // fps=30 ensures constant frame rate. setsar=1 ensures square pixels.
      vfParts.add(
          'scale=360:640:force_original_aspect_ratio=decrease,pad=360:640:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30');
      vfParts.add('format=yuv420p');
    }

    if (edits.speed != 1.0) {
      vfParts.add('setpts=PTS/${edits.speed}');
      afParts.add(_atempoChain(edits.speed));
    }

    // Ensure audio sync and consistency
    afParts.add('aresample=async=1:min_comp=0.01:comp_duration=1');

    final audioFx = _audioFxFilter(edits.audioFx);
    if (audioFx.isNotEmpty) afParts.add(audioFx);

    final vf = vfParts.isEmpty ? '' : "-vf \"${vfParts.join(',')}\"";
    final af = afParts.isEmpty ? '' : "-af \"${afParts.join(',')}\"";

    // LGPL build: use stream copy if no filters; otherwise re-encode using built-in encoders.
    // NOTE: For preview, we ALWAYS re-encode to ensure consistent format for concat
    if (vfParts.isEmpty && afParts.isEmpty && !isPreview) {
      final cmd =
          "-y -i '${_escape(inputPath)}' -c copy '${_escape(outputPath)}'";
      await _runFFmpeg(cmd);
      return outputPath;
    }

    // Use lower quality for preview (CRF 28) vs export (CRF 23)
    final crf = isPreview ? 28 : 23;
    final preset = isPreview ? 'ultrafast' : 'veryfast';
    // Use smaller GOP for better seeking in previews
    final gop = isPreview ? '-g 15' : '';
    // fps filter handles frame rate, so we don't need -r here for preview, but keeping it doesn't hurt.
    // However, -r can drop frames differently. Let's rely on fps filter for preview.
    final fps = isPreview ? '' : '';
    // Force audio format for consistency
    final audioFmt = isPreview ? '-ar 44100 -ac 2' : '';
    // Tune for zero latency to help seeking
    final tune = isPreview ? '-tune zerolatency' : '';

    final cmd =
        "-y -i '${_escape(inputPath)}' $vf $af -map 0:v -map 0:a? -c:v ${_h264Encoder()} $_h264CompatFlags -preset $preset -crf $crf $gop $fps $tune -pix_fmt yuv420p -movflags +faststart $audioFmt -c:a aac -b:a 128k '${_escape(outputPath)}'";
    await _runFFmpeg(cmd);
    return outputPath;
  }

  Future<String> concatSegments({
    required List<String> inputPaths,
    required String outputPath,
  }) async {
    await _ensureParentDir(outputPath);
    final listFile = File(p.join(p.dirname(outputPath),
        'concat_${DateTime.now().millisecondsSinceEpoch}.txt'));
    final content = inputPaths.map((e) => "file '${_escape(e)}'").join('\n');
    await listFile.writeAsString(content);

    // Add -fflags +genpts -avoid_negative_ts make_zero to fix timestamp issues at boundaries
    final cmd =
        "-y -f concat -safe 0 -i '${_escape(listFile.path)}' -c copy -fflags +genpts -avoid_negative_ts make_zero '${_escape(outputPath)}'";
    await _runFFmpeg(cmd);

    try {
      if (listFile.existsSync()) listFile.deleteSync();
    } catch (_) {}

    return outputPath;
  }

  Future<String> mixVideoWithExternalAudio({
    required String inputVideoPath,
    required String inputAudioPath,
    required String outputPath,
    required int audioStartMs,
    required double originalVolume,
    required double musicVolume,
    required bool includeOriginalAudio,
  }) async {
    final out = outputPath.trim();
    if (out.isEmpty) {
      throw ArgumentError('outputPath is empty');
    }
    await _ensureParentDir(out);

    final start = audioStartMs < 0 ? 0 : audioStartMs;
    final ov = originalVolume.clamp(0.0, 1.0);
    final mv = musicVolume.clamp(0.0, 1.0);

    // adelay needs per-channel; use same value for 2 channels.
    final delayStr = '$start|$start';

    String filter;
    if (includeOriginalAudio) {
      // Mix original audio [0:a] with delayed music [1:a]
      filter = '[0:a]volume=$ov[a0];'
          '[1:a]adelay=$delayStr,volume=$mv[a1];'
          '[a0][a1]amix=inputs=2:duration=first:dropout_transition=2[aout]';
    } else {
      // Ignore original audio, just use music (delayed)
      filter = '[1:a]adelay=$delayStr,volume=$mv[aout]';
    }

    final cmd =
        "-y -i '${_escape(inputVideoPath)}' -i '${_escape(inputAudioPath)}' -filter_complex \"$filter\" -map 0:v -map '[aout]' -c:v copy -c:a aac -b:a 128k '${_escape(out)}'";
    await _runFFmpeg(cmd);

    return out;
  }

  String _getFfmpegTransitionName(VideoTransitionType t) {
    switch (t) {
      case VideoTransitionType.fade:
        return 'fade';
      case VideoTransitionType.dissolve:
        return 'fade'; // 'dissolve' in xfade is cross-dissolve, 'fade' is also cross-fade.
      case VideoTransitionType.slideLeft:
        return 'slideleft';
      case VideoTransitionType.slideRight:
        return 'slideright';
      case VideoTransitionType.wipeLeft:
        return 'wipeleft';
      case VideoTransitionType.wipeRight:
        return 'wiperight';
      default:
        return 'fade';
    }
  }

  Future<String> concatSegmentsWithTransitions({
    required List<String> inputPaths,
    required List<VideoTransitionType> transitions,
    required String outputPath,
    double transitionDuration = 0.5,
  }) async {
    await _ensureParentDir(outputPath);

    if (inputPaths.isEmpty) {
      throw ArgumentError('No input paths for concat');
    }
    if (inputPaths.length == 1) {
      // Just copy the single file
      final cmd =
          "-y -i '${_escape(inputPaths.first)}' -c copy '${_escape(outputPath)}'";
      await _runFFmpeg(cmd);
      return outputPath;
    }

    // Check if we can use fast concat (all transitions are none)
    // Note: transitions[0] is for the first clip (ignored/none).
    // transitions[i] is transition FROM i-1 TO i.
    bool allNone = true;
    for (var i = 1; i < inputPaths.length; i++) {
      if (i < transitions.length &&
          transitions[i] != VideoTransitionType.none) {
        allNone = false;
        break;
      }
    }

    if (allNone) {
      return concatSegments(inputPaths: inputPaths, outputPath: outputPath);
    }

    // Use xfade/concat filter complex
    // 1. Get durations for all segments to calculate offsets
    final durations = <double>[];
    for (final p in inputPaths) {
      durations.add(await getDurationSec(p));
    }

    final inputs = <String>[];
    final filters = <String>[];

    // Inputs
    for (var i = 0; i < inputPaths.length; i++) {
      inputs.add("-i '${_escape(inputPaths[i])}'");
    }

    // Filter chain
    // We accumulate [v_curr] and [a_curr]
    // currentDuration tracks the length of [v_curr]
    String currV = '[0:v]';
    String currA = '[0:a]';
    double currDur = durations[0];

    for (var i = 1; i < inputPaths.length; i++) {
      final nextV = '[$i:v]';
      final nextA = '[$i:a]';
      final nextDur = durations[i];
      final trans =
          (i < transitions.length) ? transitions[i] : VideoTransitionType.none;

      final outV = '[v$i]';
      final outA = '[a$i]';

      if (trans == VideoTransitionType.none) {
        // Hard cut (concat filter)
        filters.add('$currV$nextV concat=n=2:v=1:a=0 $outV'); // Video concat
        filters.add('$currA$nextA concat=n=2:v=0:a=1 $outA'); // Audio concat

        currDur += nextDur;
      } else {
        // Xfade
        // Ensure transition duration isn't longer than clips
        final tDur = transitionDuration.clamp(
            0.1, currDur < nextDur ? currDur : nextDur);
        final offset = currDur - tDur;
        final tName = _getFfmpegTransitionName(trans);

        filters.add(
            '$currV$nextV xfade=transition=$tName:duration=$tDur:offset=$offset $outV');
        filters.add('$currA$nextA acrossfade=d=$tDur:c1=tri:c2=tri $outA');

        currDur = currDur + nextDur - tDur;
      }

      currV = outV;
      currA = outA;
    }

    final filterComplex = filters.join(';');
    final cmd =
        "-y ${inputs.join(' ')} -filter_complex \"$filterComplex\" -map '$currV' -map '$currA' -c:v ${_h264Encoder()} $_h264CompatFlags -preset veryfast -crf 23 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k '${_escape(outputPath)}'";

    await _runFFmpeg(cmd);
    return outputPath;
  }
}
