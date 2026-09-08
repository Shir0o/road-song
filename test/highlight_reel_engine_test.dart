import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/engines/highlight_reel_engine.dart';
import 'package:road_song/models/song_models.dart';
import 'package:road_song/models/trip_models.dart';

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
          'endMs': 2000,
          'lines': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': 'Ready set go',
              'startMs': 0,
              'endMs': 2000,
              'words': <Map<String, dynamic>>[
                <String, dynamic>{'word': 'Ready', 'startMs': 0, 'endMs': 600, 'syllables': 2},
                <String, dynamic>{'word': 'set', 'startMs': 600, 'endMs': 1200, 'syllables': 1},
                <String, dynamic>{'word': 'go', 'startMs': 1200, 'endMs': 2000, 'syllables': 1},
              ],
            },
          ],
        },
        <String, dynamic>{
          'id': 'chorus-1',
          'label': 'Chorus',
          'kind': 'chorus',
          'startMs': 2000,
          'endMs': 6000,
          'lines': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': 'Loud voices roar',
              'startMs': 2000,
              'endMs': 4000,
              'words': <Map<String, dynamic>>[
                <String, dynamic>{'word': 'Loud', 'startMs': 2000, 'endMs': 2600, 'syllables': 1},
                <String, dynamic>{'word': 'voices', 'startMs': 2600, 'endMs': 3300, 'syllables': 2},
                <String, dynamic>{'word': 'roar', 'startMs': 3300, 'endMs': 4000, 'syllables': 1},
              ],
            },
            <String, dynamic>{
              'text': 'Never look back',
              'startMs': 4000,
              'endMs': 6000,
              'words': <Map<String, dynamic>>[
                <String, dynamic>{'word': 'Never', 'startMs': 4000, 'endMs': 4600, 'syllables': 2},
                <String, dynamic>{'word': 'look', 'startMs': 4600, 'endMs': 5200, 'syllables': 1},
                <String, dynamic>{'word': 'back', 'startMs': 5200, 'endMs': 6000, 'syllables': 1},
              ],
            },
          ],
        },
        <String, dynamic>{
          'id': 'outro',
          'label': 'Outro',
          'kind': 'outro',
          'startMs': 6000,
          'endMs': 8000,
          'lines': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': 'Fade away',
              'startMs': 6000,
              'endMs': 8000,
              'words': <Map<String, dynamic>>[
                <String, dynamic>{'word': 'Fade', 'startMs': 6000, 'endMs': 7000, 'syllables': 1},
                <String, dynamic>{'word': 'away', 'startMs': 7000, 'endMs': 8000, 'syllables': 2},
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
        <String, dynamic>{
          'timeMs': 4500,
          'kind': 'sticker',
          'label': 'Pacific Ocean Pin',
          'memoryId': 'mem-2',
        },
      ],
    };

List<TimelineMemory> sampleMemories() => [
      const TimelineMemory(
        id: 'mem-1',
        author: 'Maya',
        time: '10:00 AM',
        text: 'Best glazed donut ever',
        photoCaption: 'A fresh box of donuts',
      ),
      const TimelineMemory(
        id: 'mem-2',
        author: 'Sam',
        time: '1:30 PM',
        text: 'Pacific ocean waves',
        locationName: 'Pacific Coast Hwy',
      ),
    ];

void main() {
  group('HighlightReelEngine frame calculations', () {
    final SongTimeline timeline = SongTimeline.fromJson(sampleTimelineJson());
    final List<TimelineMemory> memories = sampleMemories();

    test('calculates active word, line, and word progress at t = 300ms', () {
      final HighlightReelFrame frame = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 300,
      );

      expect(frame.positionMs, 300);
      expect(frame.activeSection?.id, 'intro');
      expect(frame.activeLine?.text, 'Ready set go');
      expect(frame.activeWord?.word, 'Ready');
      // Ready span is 0..600ms, so 300ms is exactly 0.5
      expect(frame.wordProgress, closeTo(0.5, 0.001));
      expect(frame.karaokeFillRatio, closeTo(0.5, 0.001));
    });

    test('calculates kinetic animation style per section kind', () {
      // Intro section at 300ms: bounce style
      final HighlightReelFrame introFrame = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 300,
      );
      expect(introFrame.kineticStyle, KineticWordEffect.bounce);
      expect(introFrame.wordBounceY, isNonZero);

      // Chorus section at 2500ms: shake + burst
      final HighlightReelFrame chorusFrame = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 2500,
      );
      expect(chorusFrame.kineticStyle, KineticWordEffect.shake);
      expect(chorusFrame.wordShakeOffset.dx.abs() + chorusFrame.wordShakeOffset.dy.abs(), greaterThan(0));
      expect(chorusFrame.wordScale, greaterThan(1.0));
    });

    test('switches beat media on musical downbeats and calculates Ken Burns pan/zoom', () {
      // Downbeats are every bar (2000ms: 0, 2000, 4000, 6000, 8000)
      final HighlightReelFrame frame1 = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 500,
      );
      expect(frame1.mediaIndex, 0);
      expect(frame1.mediaMemory.id, 'mem-1');
      expect(frame1.kenBurnsZoom, inInclusiveRange(1.0, 1.3));

      // After 2000ms (bar downbeat 1), switches to memory index 1
      final HighlightReelFrame frame2 = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 2200,
      );
      expect(frame2.mediaIndex, 1);
      expect(frame2.mediaMemory.id, 'mem-2');
      expect(frame2.kenBurnsZoom, inInclusiveRange(1.0, 1.3));
    });

    test('computes evidence sticker popup presence and scale', () {
      // Cue 1 is at 1000ms. At 900ms, not active
      final HighlightReelFrame beforeCue = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 900,
      );
      expect(beforeCue.activeCue, isNull);

      // At 1200ms (within 1000ms..3000ms window), active cue popup with spring scale
      final HighlightReelFrame duringCue = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 1200,
      );
      expect(duringCue.activeCue?.memoryId, 'mem-1');
      expect(duringCue.cuePopupScale, greaterThan(0.8));
      expect(duringCue.cuePopupOpacity, greaterThan(0.8));

      // At 3600ms (window closed for cue 1, cue 2 is at 4500ms), null
      final HighlightReelFrame afterCue = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 3600,
      );
      expect(afterCue.activeCue, isNull);
    });

    test('computes cassette reel rotation angles continuously with time', () {
      final HighlightReelFrame f0 = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 0,
      );
      final HighlightReelFrame f1 = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 1000,
      );
      final HighlightReelFrame f2 = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 2000,
      );

      expect(f0.leftReelAngle, 0.0);
      expect(f1.leftReelAngle, greaterThan(f0.leftReelAngle));
      expect(f2.leftReelAngle, greaterThan(f1.leftReelAngle));
      expect(f1.rightReelAngle, greaterThan(0.0));
      expect(f0.leftReelTapeRadius, greaterThan(f2.leftReelTapeRadius));
      expect(f0.rightReelTapeRadius, lessThan(f2.rightReelTapeRadius));
    });

    test('handles boundary positions (before start, at end, after duration)', () {
      final HighlightReelFrame fStart = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: -100,
      );
      expect(fStart.positionMs, 0);

      final HighlightReelFrame fEnd = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 9999,
      );
      expect(fEnd.positionMs, 8000);
    });

    test('supports drop and bridge section kinetic styles and fadeout cue state', () {
      // Cue fade-out window: cue starts at 1000ms, lasts 2400ms (ends 3400ms).
      // Between 3100 and 3400ms is the fadeout window.
      final HighlightReelFrame fadeFrame = HighlightReelEngine.computeFrame(
        timeline: timeline,
        memories: memories,
        positionMs: 3250,
      );
      expect(fadeFrame.activeCue?.memoryId, 'mem-1');
      expect(fadeFrame.cuePopupOpacity, lessThan(1.0));

      // Test bridge and drop kinds
      final SongTimeline customTimeline = SongTimeline(
        title: 'Mixed',
        styleId: 'pop-punk',
        bpm: 120,
        durationMs: 4000,
        downbeat: timeline.downbeat,
        sections: const [
          TimelineSection(
            id: 's1',
            label: 'Bridge',
            kind: TimelineSectionKind.bridge,
            startMs: 0,
            endMs: 2000,
            lines: [
              TimelineLine(text: 'Bridge line', startMs: 0, endMs: 2000, words: [
                TimelineWord(word: 'Bridge', startMs: 0, endMs: 1000, syllables: 1),
                TimelineWord(word: 'line', startMs: 1000, endMs: 2000, syllables: 1),
              ]),
            ],
          ),
          TimelineSection(
            id: 's2',
            label: 'Drop',
            kind: TimelineSectionKind.drop,
            startMs: 2000,
            endMs: 4000,
            lines: [
              TimelineLine(text: 'Drop bass', startMs: 2000, endMs: 4000, words: [
                TimelineWord(word: 'Drop', startMs: 2000, endMs: 3000, syllables: 1),
                TimelineWord(word: 'bass', startMs: 3000, endMs: 4000, syllables: 1),
              ]),
            ],
          ),
        ],
      );

      final HighlightReelFrame bridgeFrame = HighlightReelEngine.computeFrame(
        timeline: customTimeline,
        memories: const [],
        positionMs: 500,
      );
      expect(bridgeFrame.kineticStyle, KineticWordEffect.karaokeFill);
      expect(bridgeFrame.mediaMemory.id, HighlightReelEngine.fallbackMemory.id);

      final HighlightReelFrame dropFrame = HighlightReelEngine.computeFrame(
        timeline: customTimeline,
        memories: memories,
        positionMs: 2500,
      );
      expect(dropFrame.kineticStyle, KineticWordEffect.burst);
      expect(dropFrame.wordScale, greaterThan(1.0));
    });

    test('clamps closest section, line and word when timestamp is in lead-in or tail gap', () {
      final SongTimeline gapTimeline = SongTimeline(
        title: 'Gap',
        styleId: 'pop-punk',
        bpm: 120,
        durationMs: 10000,
        downbeat: timeline.downbeat,
        sections: const [
          TimelineSection(
            id: 's1',
            label: 'Verse',
            kind: TimelineSectionKind.verse,
            startMs: 2000,
            endMs: 4000,
            lines: [
              TimelineLine(text: 'Hello', startMs: 2500, endMs: 3500, words: [
                TimelineWord(word: 'Hello', startMs: 2700, endMs: 3300, syllables: 2),
              ]),
            ],
          ),
          TimelineSection(
            id: 's2',
            label: 'Chorus',
            kind: TimelineSectionKind.chorus,
            startMs: 6000,
            endMs: 8000,
            lines: [
              TimelineLine(text: 'World', startMs: 6500, endMs: 7500, words: [
                TimelineWord(word: 'World', startMs: 6700, endMs: 7300, syllables: 1),
              ]),
            ],
          ),
        ],
      );

      // In lead-in (1000ms < 2000ms)
      final HighlightReelFrame fLeadIn = HighlightReelEngine.computeFrame(
        timeline: gapTimeline,
        memories: memories,
        positionMs: 1000,
      );
      expect(fLeadIn.activeSection?.id, 's1');
      expect(fLeadIn.activeLine?.text, 'Hello');
      expect(fLeadIn.activeWord?.word, 'Hello');

      // In tail (9000ms > 8000ms)
      final HighlightReelFrame fTail = HighlightReelEngine.computeFrame(
        timeline: gapTimeline,
        memories: memories,
        positionMs: 9000,
      );
      expect(fTail.activeSection?.id, 's2');
      expect(fTail.activeLine?.text, 'World');
      expect(fTail.activeWord?.word, 'World');

      // Inside section s1, but before line starts (2100ms < 2500ms)
      final HighlightReelFrame fBeforeLine = HighlightReelEngine.computeFrame(
        timeline: gapTimeline,
        memories: memories,
        positionMs: 2100,
      );
      expect(fBeforeLine.activeLine?.text, 'Hello');

      // Inside section s1, but after line ends (3800ms > 3500ms)
      final HighlightReelFrame fAfterLine = HighlightReelEngine.computeFrame(
        timeline: gapTimeline,
        memories: memories,
        positionMs: 3800,
      );
      expect(fAfterLine.activeLine?.text, 'Hello');
    });
  });
}
