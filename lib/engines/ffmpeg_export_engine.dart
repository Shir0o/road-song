import 'dart:math' as math;

import '../models/song_models.dart';
import '../models/trip_models.dart';

/// Aspect ratio presets for video export.
enum VideoAspectRatio {
  /// Vertical video (1080x1920) optimized for TikTok, Instagram Reels, and YouTube Shorts.
  vertical9x16,

  /// Widescreen video (1920x1080) optimized for YouTube and desktop viewing.
  widescreen16x9;

  int get width => switch (this) {
        VideoAspectRatio.vertical9x16 => 1080,
        VideoAspectRatio.widescreen16x9 => 1920,
      };

  int get height => switch (this) {
        VideoAspectRatio.vertical9x16 => 1920,
        VideoAspectRatio.widescreen16x9 => 1080,
      };

  String get label => switch (this) {
        VideoAspectRatio.vertical9x16 => '9:16 Vertical',
        VideoAspectRatio.widescreen16x9 => '16:9 Widescreen',
      };

  String get targetPlatform => switch (this) {
        VideoAspectRatio.vertical9x16 => 'TikTok / Reels / Shorts',
        VideoAspectRatio.widescreen16x9 => 'YouTube / Desktop',
      };
}

/// Representation of an assembled FFmpeg export recipe.
class FFmpegRecipe {
  final VideoAspectRatio aspectRatio;
  final int targetWidth;
  final int targetHeight;
  final List<String> arguments;
  final String filtergraph;
  final String subtitleScript;
  final String outputPath;
  final int estimatedDurationMs;

  const FFmpegRecipe({
    required this.aspectRatio,
    required this.targetWidth,
    required this.targetHeight,
    required this.arguments,
    required this.filtergraph,
    required this.subtitleScript,
    required this.outputPath,
    required this.estimatedDurationMs,
  });

  /// Complete command-line invocation string for inspection or execution.
  String get commandString =>
      'ffmpeg ${arguments.map((arg) => arg.contains(' ') || arg.contains(';') || arg.contains('[') ? '"$arg"' : arg).join(' ')}';
}

/// Pure Dart FFmpeg export engine translating [SongTimeline] and trip media into
/// 1080p MP4 rendering recipes.
class FFmpegExportEngine {
  /// Fallback memory image if none exists.
  static const String fallbackImageUrl = 'assets/images/default_memory.png';

  /// Generates a full FFmpeg recipe for rendering a 1080p MP4.
  static FFmpegRecipe buildRecipe({
    required SongTimeline timeline,
    required List<TimelineMemory> memories,
    VideoAspectRatio aspectRatio = VideoAspectRatio.vertical9x16,
    String audioPath = 'audio_track.mp3',
    String subtitlePath = 'subtitles.ass',
    String outputPath = 'highlight_reel_1080p.mp4',
    int fps = 60,
  }) {
    final List<TimelineMemory> validMemories = memories.isNotEmpty
        ? memories
        : [
            const TimelineMemory(
              id: 'default',
              author: 'Road Song Crew',
              time: '12:00 PM',
              text: 'Trip memories on repeat',
            ),
          ];

    final int targetW = aspectRatio.width;
    final int targetH = aspectRatio.height;
    final int durationMs = timeline.durationMs;
    final double totalSec = durationMs / 1000.0;

    // 1. Calculate media segments on downbeats
    final List<double> downbeats = timeline.downbeat.downbeatTimes;
    final List<double> cutPoints = [0.0];
    for (final double db in downbeats) {
      if (db > 0.0 && db < durationMs) {
        cutPoints.add(db);
      }
    }
    if (!cutPoints.contains(durationMs.toDouble())) {
      cutPoints.add(durationMs.toDouble());
    }

    final int segmentCount = math.max(1, cutPoints.length - 1);

    // Build filtergraph
    final StringBuffer fg = StringBuffer();
    final List<String> inputs = [];

    // Inputs: media images/videos
    for (int i = 0; i < segmentCount; i++) {
      final TimelineMemory memory = validMemories[i % validMemories.length];
      final String mediaPath =
          memory.imageUrl ?? memory.photoCaption ?? 'memory_${memory.id}.jpg';
      inputs.addAll(['-loop', '1', '-t', '0', '-i', mediaPath]);
    }

    // Input: Audio track
    inputs.addAll(['-i', audioPath]);

    // Build segment zoom/pan filters
    final List<String> segmentLabels = [];
    for (int i = 0; i < segmentCount; i++) {
      final double startMs = cutPoints[i];
      final double endMs = cutPoints[i + 1];
      final double segDurationSec = math.max(0.1, (endMs - startMs) / 1000.0);
      final int frames = math.max(1, (segDurationSec * fps).round());

      // Alternate Ken Burns zoom-in and zoom-out
      final bool zoomIn = i % 2 == 0;
      final String zoomExpr =
          zoomIn ? "min(zoom+0.0015,1.25)" : "max(1.25-0.0015*on,1.0)";
      final String xExpr = "(iw-iw/zoom)/2";
      final String yExpr = "(ih-ih/zoom)/2";

      final String segLabel = 'v$i';
      segmentLabels.add('[$segLabel]');

      fg.write(
        '[$i:v]scale=${targetW * 2}:${targetH * 2}:force_original_aspect_ratio=increase,'
        'crop=${targetW * 2}:${targetH * 2},'
        'zoompan=z=\'$zoomExpr\':x=\'$xExpr\':y=\'$yExpr\':d=$frames:s=${targetW}x$targetH:fps=$fps,'
        'trim=duration=$segDurationSec,setpts=PTS-STARTPTS[$segLabel];',
      );
    }

    // Concat segments
    fg.write('${segmentLabels.join()}concat=n=$segmentCount:v=1:a=0[vconcat];');

    // Subtitle overlay and final format
    fg.write('[vconcat]subtitles=$subtitlePath[vsub];');
    fg.write('[vsub]format=yuv420p[vout]');

    // Generate ASS Subtitles script
    final String assScript = generateAssSubtitles(
      timeline: timeline,
      aspectRatio: aspectRatio,
    );

    // Full CLI Arguments
    final List<String> args = [
      '-y',
      ...inputs,
      '-filter_complex',
      fg.toString(),
      '-map',
      '[vout]',
      '-map',
      '$segmentCount:a',
      '-c:v',
      'libx264',
      '-preset',
      'fast',
      '-crf',
      '18',
      '-b:v',
      '8M',
      '-r',
      '$fps',
      '-c:a',
      'aac',
      '-b:a',
      '320k',
      '-t',
      totalSec.toStringAsFixed(3),
      outputPath,
    ];

    return FFmpegRecipe(
      aspectRatio: aspectRatio,
      targetWidth: targetW,
      targetHeight: targetH,
      arguments: args,
      filtergraph: fg.toString(),
      subtitleScript: assScript,
      outputPath: outputPath,
      estimatedDurationMs: durationMs,
    );
  }

  /// Generates an Advanced SubStation Alpha (.ass) subtitle script with karaoke
  /// syllable timing and Neo-Brutalist styling.
  static String generateAssSubtitles({
    required SongTimeline timeline,
    required VideoAspectRatio aspectRatio,
  }) {
    final int playResX = aspectRatio.width;
    final int playResY = aspectRatio.height;
    final int fontSize =
        aspectRatio == VideoAspectRatio.vertical9x16 ? 56 : 48;
    final int marginV =
        aspectRatio == VideoAspectRatio.vertical9x16 ? 260 : 120;

    final StringBuffer ass = StringBuffer();

    // Script Info
    ass.writeln('[Script Info]');
    ass.writeln('Title: Road Song Highlight Reel Subtitles');
    ass.writeln('ScriptType: v4.00+');
    ass.writeln('WrapStyle: 0');
    ass.writeln('PlayResX: $playResX');
    ass.writeln('PlayResY: $playResY');
    ass.writeln('ScaledBorderAndShadow: yes');
    ass.writeln('');

    // V4+ Styles
    ass.writeln('[V4+ Styles]');
    ass.writeln(
      'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding',
    );
    ass.writeln(
      'Style: LyricDefault,Karla,$fontSize,&H00FFF8EC,&H0047E0FD,&H00293744,&H80000000,-1,0,0,0,100,100,0,0,1,3.5,2,2,40,40,$marginV,1',
    );
    ass.writeln(
      'Style: LyricChorus,Space Mono,${fontSize + 6},&H0047E0FD,&H00FFFFFF,&H00293744,&HB0000000,-1,0,0,0,100,100,1,0,1,4.0,3,2,40,40,$marginV,1',
    );
    ass.writeln('');

    // Events
    ass.writeln('[Events]');
    ass.writeln(
      'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text',
    );

    for (final TimelineSection section in timeline.sections) {
      final String style = section.kind == TimelineSectionKind.chorus
          ? 'LyricChorus'
          : 'LyricDefault';

      for (final TimelineLine line in section.lines) {
        final String startFormatted = _formatAssTimestamp(line.startMs);
        final String endFormatted = _formatAssTimestamp(line.endMs);

        // Build karaoke tag string: {\k<centiseconds>}Word
        final StringBuffer lineText = StringBuffer();
        for (final TimelineWord word in line.words) {
          final int wordDurationCs =
              math.max(1, (word.endMs - word.startMs) ~/ 10);
          lineText.write('{\\k$wordDurationCs}${word.word} ');
        }

        final String text = lineText.toString().trim();
        ass.writeln(
          'Dialogue: 0,$startFormatted,$endFormatted,$style,,0,0,0,,{\\blur2}$text',
        );
      }
    }

    return ass.toString();
  }

  static String _formatAssTimestamp(int ms) {
    final int hours = ms ~/ 3600000;
    final int minutes = (ms % 3600000) ~/ 60000;
    final int seconds = (ms % 60000) ~/ 1000;
    final int centiseconds = (ms % 1000) ~/ 10;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}';
  }
}
