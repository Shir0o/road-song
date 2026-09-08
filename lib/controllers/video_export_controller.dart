import 'dart:async';
import 'package:flutter/foundation.dart';

import '../engines/ffmpeg_export_engine.dart';
import '../models/song_models.dart';
import '../models/trip_models.dart';

/// Status of the video export process.
enum VideoExportStatus {
  idle,
  preparing,
  encoding,
  completed,
  failed,
  cancelled,
}

/// State snapshot of the export process.
class VideoExportState {
  final VideoExportStatus status;
  final double progress; // 0.0 to 1.0
  final String statusMessage;
  final String? outputPath;
  final String? errorMessage;
  final FFmpegRecipe? recipe;

  const VideoExportState({
    required this.status,
    required this.progress,
    required this.statusMessage,
    this.outputPath,
    this.errorMessage,
    this.recipe,
  });

  factory VideoExportState.idle() => const VideoExportState(
        status: VideoExportStatus.idle,
        progress: 0.0,
        statusMessage: 'Ready to export',
      );

  VideoExportState copyWith({
    VideoExportStatus? status,
    double? progress,
    String? statusMessage,
    String? outputPath,
    String? errorMessage,
    FFmpegRecipe? recipe,
  }) {
    return VideoExportState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
      recipe: recipe ?? this.recipe,
    );
  }
}

/// Lifecycle controller & state machine for highlight reel video export.
class VideoExportController extends ChangeNotifier {
  VideoExportState _state = VideoExportState.idle();
  Timer? _exportTimer;
  bool _disposed = false;

  VideoExportState get state => _state;

  /// Starts exporting the highlight reel video based on the provided recipe parameters.
  /// Uses deterministic progress simulation in client environment while outputting full
  /// production FFmpeg recipe.
  void startExport({
    required SongTimeline timeline,
    required List<TimelineMemory> memories,
    VideoAspectRatio aspectRatio = VideoAspectRatio.vertical9x16,
    Duration stepDuration = const Duration(milliseconds: 60),
    int totalSteps = 10,
    VoidCallback? onComplete,
  }) {
    if (_state.status == VideoExportStatus.preparing ||
        _state.status == VideoExportStatus.encoding) {
      return;
    }

    _exportTimer?.cancel();

    // 1. Preparing stage
    final FFmpegRecipe recipe = FFmpegExportEngine.buildRecipe(
      timeline: timeline,
      memories: memories,
      aspectRatio: aspectRatio,
    );

    _state = VideoExportState(
      status: VideoExportStatus.preparing,
      progress: 0.05,
      statusMessage: 'Assembling filtergraph and kinetic subtitles…',
      recipe: recipe,
    );
    notifyListeners();

    int step = 0;
    _exportTimer = Timer.periodic(stepDuration, (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }

      step++;
      final double progress = (step / totalSteps).clamp(0.0, 1.0);

      if (step < totalSteps) {
        _state = _state.copyWith(
          status: VideoExportStatus.encoding,
          progress: progress,
          statusMessage: 'Encoding 1080p MP4 (${(progress * 100).toInt()}%)…',
        );
        notifyListeners();
      } else {
        timer.cancel();
        _state = _state.copyWith(
          status: VideoExportStatus.completed,
          progress: 1.0,
          statusMessage: 'Highlight reel exported successfully!',
          outputPath: recipe.outputPath,
        );
        notifyListeners();
        onComplete?.call();
      }
    });
  }

  /// Cancels an in-progress export.
  void cancelExport() {
    if (_state.status == VideoExportStatus.preparing ||
        _state.status == VideoExportStatus.encoding) {
      _exportTimer?.cancel();
      _state = _state.copyWith(
        status: VideoExportStatus.cancelled,
        statusMessage: 'Export cancelled.',
      );
      notifyListeners();
    }
  }

  /// Resets state back to idle.
  void reset() {
    _exportTimer?.cancel();
    _state = VideoExportState.idle();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _exportTimer?.cancel();
    super.dispose();
  }
}
