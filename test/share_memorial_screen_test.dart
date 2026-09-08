import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/models/song_models.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/screens/share_memorial_screen.dart';
import 'package:road_song/widgets/avatar_stack.dart';

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
    ];

List<CrewMember> sampleCrew() => [
      const CrewMember(
        id: 'maya',
        name: 'Maya Chen',
        handle: '@maya',
        initial: 'M',
        color: Color(0xFF7D8663),
      ),
      const CrewMember(
        id: 'tom',
        name: 'Tom Alvarez',
        handle: '@tom',
        initial: 'T',
        color: Color(0xFFB08A3E),
      ),
    ];

void main() {
  group('ShareMemorialScreen Widget Tests', () {
    late SongTimeline timeline;
    late List<TimelineMemory> memories;
    late List<CrewMember> crew;

    setUp(() {
      timeline = SongTimeline.fromJson(sampleTimelineJson());
      memories = sampleMemories();
      crew = sampleCrew();
    });

    testWidgets('renders keepsake card, tape mounts, avatar stack, and metadata', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ShareMemorialScreen(
            tripName: "Cabo Fail '23",
            tripDateRange: 'JAN 7 – JAN 12',
            timeline: timeline,
            memories: memories,
            crew: crew,
          ),
        ),
      );

      // Top title and keepsake label
      expect(find.text('SHARE MEMORIAL'), findsOneWidget);
      expect(find.text('KEEPSAKE'), findsOneWidget);

      // Card details
      expect(find.text("Cabo Fail '23"), findsOneWidget);
      expect(find.text('Highway Sunrise'), findsOneWidget);
      expect(find.text('JAN 7 – JAN 12'), findsOneWidget);
      expect(find.text('120 BPM · POP-PUNK'), findsOneWidget);
      expect(find.text('2 road crew contributors'), findsOneWidget);

      // Lyric quote
      expect(find.text('“We hit the gas”'), findsOneWidget);

      // Share link and copy action
      expect(find.textContaining('https://roadsong.app/m/cabo-fail-23-highway-sunrise'), findsOneWidget);
      expect(find.byKey(const ValueKey('copy-share-link-button')), findsOneWidget);

      // Web card preview
      expect(find.text('Social Web Preview Card'), findsOneWidget);
      expect(find.text('iMessage · X · Discord'), findsOneWidget);
      expect(find.text('roadsong.app'), findsOneWidget);

      // Export section
      expect(find.text('1080p MP4 Video Export'), findsOneWidget);
      expect(find.text('60 FPS'), findsOneWidget);
      expect(find.byKey(const ValueKey('aspect-vertical-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('aspect-widescreen-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('export-mp4-button')), findsOneWidget);
    });

    testWidgets('copy button triggers copied state feedback', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ShareMemorialScreen(
            tripName: 'Desert Run',
            timeline: timeline,
            memories: memories,
            crew: crew,
          ),
        ),
      );

      expect(find.text('COPY'), findsOneWidget);

      // Tap copy button
      await tester.tap(find.byKey(const ValueKey('copy-share-link-button')));
      await tester.pump();

      expect(find.text('COPIED!'), findsOneWidget);

      // Wait for timer reset
      await tester.pump(const Duration(milliseconds: 2000));
      expect(find.text('COPY'), findsOneWidget);
    });

    testWidgets('aspect ratio toggle switches between 9:16 and 16:9', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ShareMemorialScreen(
            tripName: 'Desert Run',
            timeline: timeline,
            memories: memories,
            crew: crew,
          ),
        ),
      );

      expect(find.text('Export 1080p MP4 (9:16 Vertical)'), findsOneWidget);

      // Tap 16:9 widescreen button
      await tester.scrollUntilVisible(find.byKey(const ValueKey('aspect-widescreen-button')), 100);
      await tester.tap(find.byKey(const ValueKey('aspect-widescreen-button')));
      await tester.pump();

      expect(find.text('Export 1080p MP4 (16:9 Widescreen)'), findsOneWidget);
    });

    testWidgets('export button triggers progress bar and reaches completion', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ShareMemorialScreen(
            tripName: 'Desert Run',
            timeline: timeline,
            memories: memories,
            crew: crew,
          ),
        ),
      );

      // Scroll to and start export
      await tester.scrollUntilVisible(find.byKey(const ValueKey('export-mp4-button')), 100);
      await tester.tap(find.byKey(const ValueKey('export-mp4-button')));
      await tester.pump();

      // Verify preparing progress
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Pump through encoding steps to completion
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('1080p MP4 Ready for Socials'), findsOneWidget);
      expect(find.text('Re-export Video'), findsOneWidget);
    });

    testWidgets('copy ffmpeg recipe button copies command and shows confirmation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ShareMemorialScreen(
            tripName: 'Desert Run',
            timeline: timeline,
            memories: memories,
            crew: crew,
          ),
        ),
      );

      final copyCmdFinder = find.byKey(const ValueKey('copy-ffmpeg-recipe-button'));
      await tester.scrollUntilVisible(copyCmdFinder, 100);
      expect(copyCmdFinder, findsOneWidget);

      await tester.tap(copyCmdFinder);
      await tester.pump();

      expect(find.text('Command Copied to Clipboard!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2000));
      expect(find.text('Copy FFmpeg Command Recipe'), findsOneWidget);
    });

    testWidgets('AvatarStack renders fallback names, empty crew, and overflow count correctly', (tester) async {
      // Test fallback names and overflow (+2)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarStack(
              fallbackNames: ['Alex', 'Brian', 'Charlie', 'Dana', 'Elena', 'Frank'],
              maxVisible: 4,
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);

      // Test completely empty crew
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarStack(),
          ),
        ),
      );

      expect(find.text('YOU'), findsOneWidget);
    });
  });
}
