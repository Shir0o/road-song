import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/engines/ffmpeg_export_engine.dart';
import 'package:road_song/models/song_models.dart';
import 'package:road_song/models/trip_models.dart';

Map<String, dynamic> sampleTimelineJson() => <String, dynamic>{
      'schemaVersion': 1,
      'title': 'Highway Sunrise',
      'styleId': 'pop-punk',
      'bpm': 120,
      'durationMs': 4000,
      'downbeat': <String, dynamic>{
        'beatIntervalMs': 500.0,
        'beatsPerBar': 4,
        'offsetMs': 0,
        'durationMs': 4000,
      },
      'sections': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'verse-1',
          'label': 'Verse 1',
          'kind': 'verse',
          'startMs': 0,
          'endMs': 2000,
          'lines': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': 'We hit the gas',
              'startMs': 0,
              'endMs': 2000,
              'words': <Map<String, dynamic>>[
                <String, dynamic>{'word': 'We', 'startMs': 0, 'endMs': 500, 'syllables': 1},
                <String, dynamic>{'word': 'hit', 'startMs': 500, 'endMs': 1000, 'syllables': 1},
                <String, dynamic>{'word': 'the', 'startMs': 1000, 'endMs': 1400, 'syllables': 1},
                <String, dynamic>{'word': 'gas', 'startMs': 1400, 'endMs': 2000, 'syllables': 1},
              ],
            },
          ],
        },
        <String, dynamic>{
          'id': 'chorus-1',
          'label': 'Chorus',
          'kind': 'chorus',
          'startMs': 2000,
          'endMs': 4000,
          'lines': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': 'Roar of the engine',
              'startMs': 2000,
              'endMs': 4000,
              'words': <Map<String, dynamic>>[
                <String, dynamic>{'word': 'Roar', 'startMs': 2000, 'endMs': 3000, 'syllables': 1},
                <String, dynamic>{'word': 'engine', 'startMs': 3000, 'endMs': 4000, 'syllables': 2},
              ],
            },
          ],
        },
      ],
      'cues': <Map<String, dynamic>>[],
    };

List<TimelineMemory> sampleMemories() => [
      const TimelineMemory(
        id: 'mem-1',
        author: 'Maya',
        time: '10:00 AM',
        text: 'Sunrise coffee stop',
        imageUrl: 'https://roadsong.app/photos/1.jpg',
      ),
      const TimelineMemory(
        id: 'mem-2',
        author: 'Tom',
        time: '11:00 AM',
        text: 'Desert highway stretch',
        imageUrl: 'https://roadsong.app/photos/2.jpg',
      ),
    ];

void main() {
  group('FFmpegExportEngine & Recipe Tests', () {
    late SongTimeline timeline;
    late List<TimelineMemory> memories;

    setUp(() {
      timeline = SongTimeline.fromJson(sampleTimelineJson());
      memories = sampleMemories();
    });

    test('builds 9:16 vertical 1080x1920 recipe correctly', () {
      final recipe = FFmpegExportEngine.buildRecipe(
        timeline: timeline,
        memories: memories,
        aspectRatio: VideoAspectRatio.vertical9x16,
      );

      expect(recipe.aspectRatio, VideoAspectRatio.vertical9x16);
      expect(recipe.targetWidth, 1080);
      expect(recipe.targetHeight, 1920);
      expect(recipe.estimatedDurationMs, 4000);

      // Verify command arguments
      expect(recipe.arguments, contains('-c:v'));
      expect(recipe.arguments, contains('libx264'));
      expect(recipe.arguments, contains('-crf'));
      expect(recipe.arguments, contains('18'));
      expect(recipe.arguments, contains('-r'));
      expect(recipe.arguments, contains('60'));
      expect(recipe.arguments, contains('highlight_reel_1080p.mp4'));

      // Verify filtergraph contains zoompan and subtitles
      expect(recipe.filtergraph, contains('zoompan='));
      expect(recipe.filtergraph, contains('s=1080x1920'));
      expect(recipe.filtergraph, contains('subtitles=subtitles.ass'));
      expect(recipe.filtergraph, contains('concat=n='));

      // Check commandString
      expect(recipe.commandString.startsWith('ffmpeg'), isTrue);
    });

    test('builds 16:9 widescreen 1920x1080 recipe correctly', () {
      final recipe = FFmpegExportEngine.buildRecipe(
        timeline: timeline,
        memories: memories,
        aspectRatio: VideoAspectRatio.widescreen16x9,
      );

      expect(recipe.aspectRatio, VideoAspectRatio.widescreen16x9);
      expect(recipe.targetWidth, 1920);
      expect(recipe.targetHeight, 1080);
      expect(recipe.filtergraph, contains('s=1920x1080'));
    });

    test('generates ASS subtitles with karaoke syllables and Brutalist styling', () {
      final ass = FFmpegExportEngine.generateAssSubtitles(
        timeline: timeline,
        aspectRatio: VideoAspectRatio.vertical9x16,
      );

      expect(ass, contains('[Script Info]'));
      expect(ass, contains('PlayResX: 1080'));
      expect(ass, contains('PlayResY: 1920'));
      expect(ass, contains('[V4+ Styles]'));
      expect(ass, contains('LyricDefault'));
      expect(ass, contains('LyricChorus'));
      expect(ass, contains('[Events]'));

      // Check karaoke tags {\k...}
      expect(ass, contains(r'{\k'));
      expect(ass, contains('We'));
      expect(ass, contains('gas'));
      expect(ass, contains('Roar'));
    });

    test('handles empty memories fallback smoothly', () {
      final recipe = FFmpegExportEngine.buildRecipe(
        timeline: timeline,
        memories: const [],
        aspectRatio: VideoAspectRatio.vertical9x16,
      );

      expect(recipe.arguments, isNotEmpty);
      expect(recipe.filtergraph, contains('scale=2160:3840'));
    });
  });
}
