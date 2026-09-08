import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/controllers/video_export_controller.dart';
import 'package:road_song/engines/ffmpeg_export_engine.dart';
import 'package:road_song/models/song_models.dart';
import 'package:road_song/models/trip_models.dart';

void main() {
  group('VideoExportController Lifecycle Tests', () {
    late SongTimeline timeline;
    late List<TimelineMemory> memories;

    setUp(() {
      timeline = const SongTimeline(
        schemaVersion: 1,
        title: 'Highway Sunrise',
        styleId: 'pop-punk',
        bpm: 120,
        durationMs: 4000,
        downbeat: DownbeatGrid(
          beatIntervalMs: 500.0,
          beatsPerBar: 4,
          offsetMs: 0,
          durationMs: 4000,
        ),
        sections: [],
        cues: [],
      );
      memories = const [
        TimelineMemory(
          id: 'mem-1',
          author: 'Maya',
          time: '10:00 AM',
          text: 'Sunrise',
        ),
      ];
    });

    test('initial state is idle', () {
      final controller = VideoExportController();
      expect(controller.state.status, VideoExportStatus.idle);
      expect(controller.state.progress, 0.0);
      controller.dispose();
    });

    test('export transitions through preparing -> encoding -> completed', () async {
      final controller = VideoExportController();
      bool completedCalled = false;

      controller.startExport(
        timeline: timeline,
        memories: memories,
        aspectRatio: VideoAspectRatio.vertical9x16,
        stepDuration: const Duration(milliseconds: 10),
        totalSteps: 5,
        onComplete: () => completedCalled = true,
      );

      expect(controller.state.status, VideoExportStatus.preparing);
      expect(controller.state.recipe, isNotNull);

      // Wait for completion
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(controller.state.status, VideoExportStatus.completed);
      expect(controller.state.progress, 1.0);
      expect(controller.state.outputPath, isNotNull);
      expect(completedCalled, isTrue);

      controller.dispose();
    });

    test('cancelExport terminates active export cleanly', () async {
      final controller = VideoExportController();

      controller.startExport(
        timeline: timeline,
        memories: memories,
        aspectRatio: VideoAspectRatio.widescreen16x9,
        stepDuration: const Duration(milliseconds: 50),
        totalSteps: 10,
      );

      expect(controller.state.status, VideoExportStatus.preparing);

      controller.cancelExport();
      expect(controller.state.status, VideoExportStatus.cancelled);

      controller.dispose();
    });

    test('reset clears state back to idle', () {
      final controller = VideoExportController();
      controller.startExport(
        timeline: timeline,
        memories: memories,
      );

      controller.reset();
      expect(controller.state.status, VideoExportStatus.idle);
      expect(controller.state.progress, 0.0);
      controller.dispose();
    });
  });
}
