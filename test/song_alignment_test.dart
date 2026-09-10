import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/engines/evidence_cue_engine.dart';
import 'package:road_song/engines/song_synth_engine.dart';
import 'package:road_song/engines/timeline_aligner.dart';
import 'package:road_song/engines/timeline_layout.dart';
import 'package:road_song/engines/lyricist_engine.dart';
import 'package:road_song/models/song_models.dart';
import 'package:road_song/models/trip_models.dart';

MusicalStyle _style(String id) =>
    MusicalStyle.catalog.firstWhere((MusicalStyle s) => s.id == id);

const MusicalStyle kPopPunk = MusicalStyle(
  id: 'pop-punk',
  label: 'Pop-Punk',
  tagline: 'Three chords, zero chill.',
  mood: 'Loud · fast · defiant',
  defaultBpm: 168,
  minBpm: 140,
  maxBpm: 190,
  audioAsset: 'audio/vibes/pop_punk.mp3',
);

/// Three-section fixture: intro / chorus / outro.
const LyricSong kSong = LyricSong(
  title: 'Every Wrong Turn',
  sections: <LyricSection>[
    LyricSection(
      id: 'intro',
      label: 'Intro',
      variants: <List<String>>[
        <String>['Press play on the tapes,'],
      ],
    ),
    LyricSection(
      id: 'ch',
      label: 'Chorus',
      variants: <List<String>>[
        <String>[
          'Sing it back on the long road,',
          'every wrong turn worth the detour,',
        ],
      ],
    ),
    LyricSection(
      id: 'out',
      label: 'Outro',
      variants: <List<String>>[
        <String>['Till the tape keeps rolling.'],
      ],
    ),
  ],
);

/// Six lyricist section ids, to pin the id → kind mapping.
const LyricSong kAllKindsSong = LyricSong(
  title: 'Kinds',
  sections: <LyricSection>[
    LyricSection(
      id: 'intro',
      label: 'Intro',
      variants: <List<String>>[
        <String>['one'],
      ],
    ),
    LyricSection(
      id: 'v1',
      label: 'Verse 1',
      variants: <List<String>>[
        <String>['two'],
      ],
    ),
    LyricSection(
      id: 'ch',
      label: 'Chorus',
      variants: <List<String>>[
        <String>['three'],
      ],
    ),
    LyricSection(
      id: 'v2',
      label: 'Verse 2',
      variants: <List<String>>[
        <String>['four'],
      ],
    ),
    LyricSection(
      id: 'br',
      label: 'Bridge',
      variants: <List<String>>[
        <String>['five'],
      ],
    ),
    LyricSection(
      id: 'out',
      label: 'Outro',
      variants: <List<String>>[
        <String>['six'],
      ],
    ),
  ],
);

const List<TimelineMemory> kCaboMemories = <TimelineMemory>[
  TimelineMemory(
    id: 'm1',
    author: '@alex',
    time: '11:42 PM',
    text: 'Alex tried to fight a seagull for the last churro. The seagull won.',
    imageUrl: 'https://example.com/churro.jpg',
    locationName: 'Marina Pier',
  ),
  TimelineMemory(
    id: 'm2',
    author: '@sarah',
    time: '02:15 AM',
    text: 'Ended up at a 24hr laundromat playing poker with candy wrappers.',
    locationName: 'The 24hr Laundromat',
  ),
];

void main() {
  group('SimulatedSongSynth', () {
    const SimulatedSongSynth synth = SimulatedSongSynth();

    test(
      'renders a positive-duration take for the chosen vibe and tempo',
      () async {
        final SynthResult audio = await synth.synthesize(
          song: kSong,
          style: kPopPunk,
          bpm: kPopPunk.defaultBpm,
        );
        expect(audio.audioId, isNotEmpty);
        expect(audio.durationMs, greaterThan(0));
      },
    );

    test('is deterministic for the same lyrics, vibe and tempo', () async {
      final SynthResult first = await synth.synthesize(
        song: kSong,
        style: kPopPunk,
        bpm: 168,
      );
      final SynthResult second = await synth.synthesize(
        song: kSong,
        style: kPopPunk,
        bpm: 168,
      );
      expect(second.audioId, first.audioId);
      expect(second.durationMs, first.durationMs);
    });

    test('a faster tempo renders a shorter track', () async {
      final SynthResult fast = await synth.synthesize(
        song: kSong,
        style: kPopPunk,
        bpm: 190,
      );
      final SynthResult slow = await synth.synthesize(
        song: kSong,
        style: _style('sad-boy-indie'),
        bpm: 70,
      );
      expect(fast.durationMs, lessThan(slow.durationMs));
    });
  });

  group('DeterministicTimelineAligner', () {
    const DeterministicTimelineAligner aligner = DeterministicTimelineAligner();

    Future<SongTimeline> alignAgainst(int durationMs) => aligner.align(
      song: kSong,
      style: kPopPunk,
      bpm: 168,
      audio: SynthResult(audioId: 'sim://vocal/test', durationMs: durationMs),
    );

    /// Structural invariants every forced alignment must hold.
    void expectValidTimeline(SongTimeline timeline, int durationMs) {
      expect(timeline.durationMs, durationMs);
      expect(timeline.bpm, 168);
      expect(timeline.styleId, kPopPunk.id);
      int cursor = 0;
      for (final TimelineSection section in timeline.sections) {
        expect(
          section.startMs,
          greaterThanOrEqualTo(cursor),
          reason: 'sections must not overlap',
        );
        expect(section.startMs, greaterThanOrEqualTo(0));
        expect(
          section.endMs,
          lessThanOrEqualTo(durationMs),
          reason: 'sections must fit inside the audio',
        );
        expect(section.endMs, greaterThanOrEqualTo(section.startMs));
        cursor = section.endMs;
        for (final TimelineLine line in section.lines) {
          expect(line.startMs, greaterThanOrEqualTo(section.startMs));
          expect(line.endMs, lessThanOrEqualTo(section.endMs));
          expect(line.words, isNotEmpty);
          expect(
            line.startMs,
            line.words.first.startMs,
            reason: 'a line spans its words',
          );
          expect(line.endMs, line.words.last.endMs);
          for (int i = 0; i < line.words.length; i++) {
            final TimelineWord word = line.words[i];
            expect(word.endMs, greaterThanOrEqualTo(word.startMs));
            expect(word.syllables, countSyllables(word.word));
            if (i > 0) {
              expect(
                word.startMs,
                line.words[i - 1].endMs,
                reason: 'words must be contiguous within a line',
              );
            }
          }
        }
      }
      expect(timeline.downbeat.beatIntervalMs, closeTo(60000 / 168, 0.01));
      expect(timeline.downbeat.durationMs, durationMs);
    }

    test('forces the lyrics into the synthesized audio span', () async {
      const SimulatedSongSynth synth = SimulatedSongSynth();
      final SynthResult audio = await synth.synthesize(
        song: kSong,
        style: kPopPunk,
        bpm: 168,
      );
      final SongTimeline timeline = await aligner.align(
        song: kSong,
        style: kPopPunk,
        bpm: 168,
        audio: audio,
      );
      expectValidTimeline(timeline, audio.durationMs);
      expect(
        timeline.sections.first.startMs,
        greaterThan(0),
        reason: 'instrumental lead-in',
      );
      expect(
        timeline.sections.last.endMs,
        lessThan(audio.durationMs),
        reason: 'instrumental tail',
      );
      expect(timeline.wordCount, 23);
    });

    test('maps lyricist section ids to musical kinds', () async {
      final SongTimeline timeline = await aligner.align(
        song: kAllKindsSong,
        style: kPopPunk,
        bpm: 120,
        audio: const SynthResult(audioId: 'a', durationMs: 12000),
      );
      expect(
        timeline.sections.map((TimelineSection s) => s.kind).toList(),
        <TimelineSectionKind>[
          TimelineSectionKind.intro,
          TimelineSectionKind.verse,
          TimelineSectionKind.chorus,
          TimelineSectionKind.verse,
          TimelineSectionKind.bridge,
          TimelineSectionKind.outro,
        ],
      );
    });

    test(
      'a longer audio stretches word spans, a shorter one compresses them',
      () async {
        final SongTimeline normal = await alignAgainst(10000);
        final SongTimeline stretched = await alignAgainst(20000);
        expectValidTimeline(stretched, 20000);
        expect(
          stretched.sections.last.endMs,
          greaterThan(normal.sections.last.endMs),
        );
        final int normalFirstWordMs =
            normal.sections.first.lines.first.words.first.endMs -
            normal.sections.first.lines.first.words.first.startMs;
        final int stretchedFirstWordMs =
            stretched.sections.first.lines.first.words.first.endMs -
            stretched.sections.first.lines.first.words.first.startMs;
        expect(stretchedFirstWordMs, greaterThan(normalFirstWordMs));
      },
    );

    test(
      'an absurdly short audio still yields a valid monotonic timeline',
      () async {
        final SongTimeline timeline = await alignAgainst(1000);
        expectValidTimeline(timeline, 1000);
      },
    );

    test('an empty song produces an empty section list', () async {
      const LyricSong empty = LyricSong(
        title: 'Silence',
        sections: <LyricSection>[],
      );
      final SongTimeline timeline = await aligner.align(
        song: empty,
        style: kPopPunk,
        bpm: 168,
        audio: const SynthResult(audioId: 'a', durationMs: 8000),
      );
      expect(timeline.sections, isEmpty);
      expect(timeline.wordCount, 0);
    });
  });

  group('KeywordEvidenceCueEngine', () {
    const KeywordEvidenceCueEngine engine = KeywordEvidenceCueEngine();

    const LyricSong kCueSong = LyricSong(
      title: 'Cues',
      sections: <LyricSection>[
        LyricSection(
          id: 'v1',
          label: 'Verse 1',
          variants: <List<String>>[
            <String>[
              'We watched the pier from the boardwalk,',
              'with snacks from the 24hr laundromat,',
              'a seagull stole the show near the pier.',
              'then played poker till sunrise.',
            ],
          ],
        ),
      ],
    );

    const List<TimelineMemory> kMemories = <TimelineMemory>[
      TimelineMemory(
        id: 'm1',
        author: '@alex',
        time: '11:42 PM',
        text: 'Seagull drama by the water.',
        imageUrl: 'https://example.com/pier.jpg',
        locationName: 'Marina Pier',
      ),
      TimelineMemory(
        id: 'm2',
        author: '@sarah',
        time: '02:15 AM',
        text: 'Dryer number three ate a sock.',
        locationName: 'The 24hr Laundromat',
      ),
      TimelineMemory(
        id: 'm3',
        author: '@group',
        time: '03:30 AM',
        text: 'Seagull strikes again.',
      ),
      TimelineMemory(
        id: 'm4',
        author: '@sam',
        time: '04:00 AM',
        text: 'Bought too much candy with the last of our money.',
        locationName: 'Candy Shop',
      ),
      TimelineMemory(
        id: 'm5',
        author: '@kim',
        time: '05:00 AM',
        text: 'Chips were the currency of the whole trip honestly.',
        photoCaption:
            'The infamous poker night that shall not be named ever again okay fine maybe once',
      ),
    ];

    Future<SongTimeline> timelineFor(LyricSong song) async {
      const SimulatedSongSynth synth = SimulatedSongSynth();
      final SynthResult audio = await synth.synthesize(
        song: song,
        style: kPopPunk,
        bpm: 120,
      );
      return const DeterministicTimelineAligner().align(
        song: song,
        style: kPopPunk,
        bpm: 120,
        audio: audio,
      );
    }

    test(
      'maps lyric keywords to photo and sticker cues at word starts',
      () async {
        final SongTimeline timeline = await timelineFor(kCueSong);
        final List<EvidenceCue> cues = await engine.cues(
          timeline: timeline,
          memories: kMemories,
        );

        final Map<String, EvidenceCue> byMemory = <String, EvidenceCue>{
          for (final EvidenceCue cue in cues) cue.memoryId: cue,
        };
        expect(
          byMemory.keys.toSet(),
          <String>{'m1', 'm2', 'm3', 'm5'},
          reason:
              'm4 shares no keyword with the lyrics; stopword "with" must not match',
        );

        final EvidenceCue m1 = byMemory['m1']!;
        expect(m1.kind, EvidenceCueKind.photo, reason: 'm1 carries a photo');
        expect(m1.label, 'Marina Pier');
        final TimelineWord pierWord = <TimelineWord>[
          for (final TimelineLine line in timeline.sections.expand(
            (TimelineSection s) => s.lines,
          ))
            ...line.words,
        ].firstWhere((TimelineWord w) => w.word == 'pier');
        expect(
          m1.timeMs,
          pierWord.startMs,
          reason: 'cue fires when the keyword is sung',
        );

        expect(byMemory['m2']!.kind, EvidenceCueKind.sticker);
        expect(byMemory['m2']!.label, 'The 24hr Laundromat');
        expect(
          byMemory['m3']!.kind,
          EvidenceCueKind.sticker,
          reason: 'no photo means a sticker popup',
        );
        expect(byMemory['m3']!.label, 'Seagull strikes again.');
      },
    );

    test(
      'falls back to a truncated caption label when no location is pinned',
      () async {
        final SongTimeline timeline = await timelineFor(kCueSong);
        final List<EvidenceCue> cues = await engine.cues(
          timeline: timeline,
          memories: kMemories,
        );
        final EvidenceCue m5 = cues.singleWhere(
          (EvidenceCue c) => c.memoryId == 'm5',
        );
        expect(m5.label, startsWith('The infamous poker night'));
        expect(m5.label.length, lessThanOrEqualTo(41));
      },
    );

    test('cues are sorted by time', () async {
      final SongTimeline timeline = await timelineFor(kCueSong);
      final List<EvidenceCue> cues = await engine.cues(
        timeline: timeline,
        memories: kMemories,
      );
      final List<int> times = cues.map((EvidenceCue c) => c.timeMs).toList();
      expect(times, times.toList()..sort());
    });

    test('returns nothing when no keyword lands in the lyrics', () async {
      final SongTimeline timeline = await timelineFor(kCueSong);
      const List<TimelineMemory> strangers = <TimelineMemory>[
        TimelineMemory(
          id: 'x1',
          author: '@zed',
          time: '09:00 AM',
          text: 'Lost the rental keys in Vegas.',
          locationName: 'Desert Motel',
        ),
      ];
      expect(
        await engine.cues(timeline: timeline, memories: strangers),
        isEmpty,
      );
    });
  });

  group('end-to-end pipeline', () {
    test(
      'lyricist → synth → aligner → cues round-trips through canonical JSON',
      () async {
        final LyricSong song = await const TemplateLyricist().composeSong(
          tripName: "Cabo Fail '23",
          participants: const <String>['Maya', 'Tom'],
          memories: kCaboMemories,
        );
        const MusicalStyle style = MusicalStyle(
          id: 'pop-punk',
          label: 'Pop-Punk',
          tagline: 'Three chords, zero chill.',
          mood: 'Loud · fast · defiant',
          defaultBpm: 168,
          minBpm: 140,
          maxBpm: 190,
          audioAsset: 'audio/vibes/pop_punk.mp3',
        );
        final SynthResult audio = await const SimulatedSongSynth().synthesize(
          song: song,
          style: style,
          bpm: style.defaultBpm,
        );
        final SongTimeline timeline = await const DeterministicTimelineAligner()
            .align(
              song: song,
              style: style,
              bpm: style.defaultBpm,
              audio: audio,
            );
        final List<EvidenceCue> cues = await const KeywordEvidenceCueEngine()
            .cues(timeline: timeline, memories: kCaboMemories);
        final SongTimeline complete = timeline.withCues(cues);

        expect(
          cues,
          isNotEmpty,
          reason: 'Cabo lyrics name Marina Pier and the seagull fight',
        );
        for (final EvidenceCue cue in complete.cues) {
          expect(cue.timeMs, lessThanOrEqualTo(complete.durationMs));
          expect(
            kCaboMemories.any((TimelineMemory m) => m.id == cue.memoryId),
            isTrue,
          );
        }
        final SongTimeline parsed = SongTimeline.fromJson(complete.toJson());
        expect(parsed.toJson(), complete.toJson());
      },
    );
  });
}
