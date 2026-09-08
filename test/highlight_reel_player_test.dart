import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/models/song_models.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/widgets/highlight_reel_player.dart';

Map<String, dynamic> sampleTimelineJson() => <String, dynamic>{
      'schemaVersion': 1,
      'title': 'Highway Sunrise',
      'styleId': 'pop-punk',
      'bpm': 120,
      'durationMs': 8000,
      'downbeat': <String, dynamic>{
        'beatIntervalMs': 500.0,
        'beatsPerBar': 4,
        'offsetMs': 0,
        'durationMs': 8000,
      },
      'sections': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'intro',
          'label': 'Intro',
          'kind': 'intro',
          'startMs': 0,
          'endMs': 4000,
          'lines': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': 'Ready set go',
              'startMs': 0,
              'endMs': 4000,
              'words': <Map<String, dynamic>>[
                <String, dynamic>{'word': 'Ready', 'startMs': 0, 'endMs': 1200, 'syllables': 2},
                <String, dynamic>{'word': 'set', 'startMs': 1200, 'endMs': 2400, 'syllables': 1},
                <String, dynamic>{'word': 'go', 'startMs': 2400, 'endMs': 4000, 'syllables': 1},
              ],
            },
          ],
        },
        <String, dynamic>{
          'id': 'chorus',
          'label': 'Chorus',
          'kind': 'chorus',
          'startMs': 4000,
          'endMs': 8000,
          'lines': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': 'Loud roar',
              'startMs': 4000,
              'endMs': 8000,
              'words': <Map<String, dynamic>>[
                <String, dynamic>{'word': 'Loud', 'startMs': 4000, 'endMs': 6000, 'syllables': 1},
                <String, dynamic>{'word': 'roar', 'startMs': 6000, 'endMs': 8000, 'syllables': 1},
              ],
            },
          ],
        },
      ],
      'cues': <Map<String, dynamic>>[
        <String, dynamic>{
          'timeMs': 1000,
          'kind': 'photo',
          'label': 'Gas Station Donut',
          'memoryId': 'mem-1',
        },
      ],
    };

List<TimelineMemory> sampleMemories() => [
      const TimelineMemory(
        id: 'mem-1',
        author: 'Maya',
        time: '10:00 AM',
        text: 'Best glazed donut ever',
        locationName: 'Donut Stop',
      ),
    ];

void main() {
  group('HighlightReelPlayer Widget Tests', () {
    late SongTimeline timeline;
    late List<TimelineMemory> memories;

    setUp(() {
      timeline = SongTimeline.fromJson(sampleTimelineJson());
      memories = sampleMemories();
    });

    testWidgets('renders player header, canvas stage, cassette reels, and controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HighlightReelPlayer(
            timeline: timeline,
            memories: memories,
          ),
        ),
      );

      // Verify song title in top bar
      expect(find.text('Highway Sunrise'), findsOneWidget);
      expect(find.text('120 BPM · POP-PUNK'), findsOneWidget);
      expect(find.text('60 FPS'), findsOneWidget);

      // Verify playback controls
      expect(find.byKey(const ValueKey('reel-play-pause-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('reel-restart-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('reel-scrubber-slider')), findsOneWidget);

      // Initial state is playing
      expect(find.text('● TAPE PLAYING'), findsOneWidget);

      // Close button exists
      expect(find.byKey(const ValueKey('reel-close-button')), findsOneWidget);
    });

    testWidgets('play and pause toggle toggles tape indicator and ticker', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HighlightReelPlayer(
            timeline: timeline,
            memories: memories,
          ),
        ),
      );

      // Tap pause
      await tester.tap(find.byKey(const ValueKey('reel-play-pause-button')));
      await tester.pump();

      expect(find.text('❚❚ PAUSED'), findsOneWidget);

      // Tap play again
      await tester.tap(find.byKey(const ValueKey('reel-play-pause-button')));
      await tester.pump();

      expect(find.text('● TAPE PLAYING'), findsOneWidget);
    });

    testWidgets('scrubbing updates timecode and positions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HighlightReelPlayer(
            timeline: timeline,
            memories: memories,
          ),
        ),
      );

      // Pause to test stationary position
      await tester.tap(find.byKey(const ValueKey('reel-play-pause-button')));
      await tester.pump();

      // Scrubber interaction
      final Finder sliderFinder = find.byKey(const ValueKey('reel-scrubber-slider'));
      expect(sliderFinder, findsOneWidget);

      // Tap restart button to seek to 0:00
      await tester.tap(find.byKey(const ValueKey('reel-restart-button')));
      await tester.pump();

      expect(find.text('0:00 / 0:08'), findsOneWidget);
    });

    testWidgets('close callback triggers when close button tapped', (tester) async {
      bool closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: HighlightReelPlayer(
            timeline: timeline,
            memories: memories,
            onClose: () => closed = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('reel-close-button')));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('share callback triggers when share button tapped', (tester) async {
      bool shared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: HighlightReelPlayer(
            timeline: timeline,
            memories: memories,
            onShare: () => shared = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('reel-share-button')));
      await tester.pump();

      expect(shared, isTrue);
    });
  });
}
