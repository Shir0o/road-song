import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/engines/timeline_layout.dart';
import 'package:road_song/models/song_models.dart';

/// Canonical SongTimeline JSON (schema v1) in the documented wire format.
/// The parser must accept this shape as-is — not only its own [SongTimeline.toJson]
/// output — so hand-written producers stay compatible.
Map<String, dynamic> canonicalTimelineJson() => <String, dynamic>{
  'schemaVersion': 1,
  'title': 'Every Wrong Turn',
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
      'id': 'intro',
      'label': 'Intro',
      'kind': 'intro',
      'startMs': 0,
      'endMs': 2000,
      'lines': <Map<String, dynamic>>[
        <String, dynamic>{
          'text': 'Press play',
          'startMs': 0,
          'endMs': 1000,
          'words': <Map<String, dynamic>>[
            <String, dynamic>{
              'word': 'Press',
              'startMs': 0,
              'endMs': 500,
              'syllables': 1,
            },
            <String, dynamic>{
              'word': 'play',
              'startMs': 500,
              'endMs': 1000,
              'syllables': 1,
            },
          ],
        },
      ],
    },
    <String, dynamic>{
      'id': 'ch',
      'label': 'Chorus',
      'kind': 'chorus',
      'startMs': 2000,
      'endMs': 4000,
      'lines': <Map<String, dynamic>>[
        <String, dynamic>{
          'text': 'Sing it back',
          'startMs': 2000,
          'endMs': 4000,
          'words': <Map<String, dynamic>>[
            <String, dynamic>{
              'word': 'Sing',
              'startMs': 2000,
              'endMs': 2500,
              'syllables': 1,
            },
            <String, dynamic>{
              'word': 'it',
              'startMs': 2500,
              'endMs': 3000,
              'syllables': 1,
            },
            <String, dynamic>{
              'word': 'back',
              'startMs': 3000,
              'endMs': 4000,
              'syllables': 1,
            },
          ],
        },
      ],
    },
  ],
  'cues': <Map<String, dynamic>>[
    <String, dynamic>{
      'timeMs': 500,
      'kind': 'photo',
      'label': 'Marina Pier',
      'memoryId': 'm1',
    },
  ],
};

/// Mutates a nested key so each parser test can break one contract clause.
Map<String, dynamic> mutated(void Function(Map<String, dynamic>) change) {
  final Map<String, dynamic> json = canonicalTimelineJson();
  change(json);
  return json;
}

SongTimeline canonicalTimeline() =>
    SongTimeline.fromJson(canonicalTimelineJson());

void main() {
  group('MusicalStyle catalog', () {
    test('ships the five launch vibes', () {
      final List<String> ids = MusicalStyle.catalog
          .map((MusicalStyle s) => s.id)
          .toList();
      expect(
        ids,
        containsAll(<String>[
          'pop-punk',
          'euro-trash-synth',
          'sad-boy-indie',
          'acoustic-road-folk',
          'chaotic-rap',
        ]),
      );
      expect(ids.length, MusicalStyle.catalog.length);
    });

    test('every card carries preview metadata and a sane tempo range', () {
      for (final MusicalStyle style in MusicalStyle.catalog) {
        expect(style.label, isNotEmpty);
        expect(style.tagline, isNotEmpty);
        expect(style.mood, isNotEmpty);
        expect(style.minBpm, lessThan(style.defaultBpm));
        expect(style.defaultBpm, lessThan(style.maxBpm));
      }
    });

    test('ids are unique', () {
      final Set<String> ids = <String>{
        for (final MusicalStyle s in MusicalStyle.catalog) s.id,
      };
      expect(ids.length, MusicalStyle.catalog.length);
    });
  });

  group('countSyllables', () {
    test('single vowel-group words count one', () {
      expect(countSyllables('we'), 1);
      expect(countSyllables('road'), 1);
      expect(countSyllables('song'), 1);
      expect(countSyllables('the'), 1);
    });

    test('silent trailing e is not a syllable, but -le endings are', () {
      expect(countSyllables('make'), 1);
      expect(countSyllables('tape'), 1);
      expect(countSyllables('table'), 2);
    });

    test('adjacent vowels form one group', () {
      expect(countSyllables('seagull'), 2); // ea | u
      expect(countSyllables('laundromat'), 3); // au | o | a
      expect(countSyllables('churro'), 2);
    });

    test('vowel groups accumulate', () {
      expect(countSyllables('apology'), 4); // a | o | o | y
    });

    test('punctuation and casing do not matter', () {
      expect(countSyllables('Churro!'), 2);
      expect(countSyllables('"yeah."'), 1);
    });

    test('punctuation-only tokens count zero syllables', () {
      expect(countSyllables('—'), 0);
      expect(countSyllables(''), 0);
    });
  });

  group('DownbeatGrid', () {
    test('enumerates beats below the duration and marks every bar start', () {
      const DownbeatGrid grid = DownbeatGrid(
        beatIntervalMs: 500,
        beatsPerBar: 4,
        offsetMs: 0,
        durationMs: 4000,
      );
      expect(grid.beatTimes, <double>[
        0,
        500,
        1000,
        1500,
        2000,
        2500,
        3000,
        3500,
      ]);
      expect(grid.downbeatTimes, <double>[0, 2000]);
    });

    test('honors a non-zero offset', () {
      const DownbeatGrid grid = DownbeatGrid(
        beatIntervalMs: 500,
        beatsPerBar: 4,
        offsetMs: 250,
        durationMs: 2000,
      );
      expect(grid.beatTimes.first, 250);
      expect(grid.downbeatTimes.first, 250);
      expect(grid.beatTimes.last, lessThan(2000));
    });
  });

  group('SongTimeline.fromJson', () {
    test('parses the canonical schema', () {
      final SongTimeline timeline = canonicalTimeline();
      expect(timeline.schemaVersion, 1);
      expect(timeline.title, 'Every Wrong Turn');
      expect(timeline.styleId, 'pop-punk');
      expect(timeline.bpm, 120);
      expect(timeline.durationMs, 4000);
      expect(timeline.downbeat.beatIntervalMs, 500.0);
      expect(timeline.sections, hasLength(2));
      expect(timeline.sections[0].kind, TimelineSectionKind.intro);
      expect(timeline.sections[1].kind, TimelineSectionKind.chorus);
      expect(timeline.sections[1].lines.single.words, hasLength(3));
      expect(timeline.cues.single.kind, EvidenceCueKind.photo);
      expect(timeline.cues.single.memoryId, 'm1');
    });

    test('counts words across all sections', () {
      expect(canonicalTimeline().wordCount, 5);
    });

    test('rejects a foreign schema version', () {
      expect(
        () => SongTimeline.fromJson(
          mutated((Map<String, dynamic> j) => j['schemaVersion'] = 2),
        ),
        throwsFormatException,
      );
    });

    test('rejects missing required keys', () {
      expect(
        () => SongTimeline.fromJson(
          mutated((Map<String, dynamic> j) => j.remove('sections')),
        ),
        throwsFormatException,
      );
      expect(
        () => SongTimeline.fromJson(
          mutated((Map<String, dynamic> j) => j.remove('downbeat')),
        ),
        throwsFormatException,
      );
    });

    test('rejects non-positive bpm', () {
      expect(
        () => SongTimeline.fromJson(
          mutated((Map<String, dynamic> j) => j['bpm'] = 0),
        ),
        throwsFormatException,
      );
    });

    test('rejects unknown section kinds', () {
      expect(
        () => SongTimeline.fromJson(
          mutated(
            (Map<String, dynamic> j) =>
                j['sections'][1]['kind'] = 'guitar-solo',
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects unknown cue kinds', () {
      expect(
        () => SongTimeline.fromJson(
          mutated((Map<String, dynamic> j) => j['cues'][0]['kind'] = 'video'),
        ),
        throwsFormatException,
      );
    });

    test('rejects negative timestamps', () {
      expect(
        () => SongTimeline.fromJson(
          mutated((Map<String, dynamic> j) => j['sections'][0]['startMs'] = -1),
        ),
        throwsFormatException,
      );
    });

    test('rejects inverted line spans', () {
      expect(
        () => SongTimeline.fromJson(
          mutated(
            (Map<String, dynamic> j) =>
                j['sections'][0]['lines'][0]['startMs'] =
                    1500, // after its endMs
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects words escaping their line span', () {
      expect(
        () => SongTimeline.fromJson(
          mutated(
            (Map<String, dynamic> j) =>
                j['sections'][0]['lines'][0]['words'][1]['endMs'] =
                    1200, // line ends at 1000
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects overlapping sections', () {
      expect(
        () => SongTimeline.fromJson(
          mutated(
            (Map<String, dynamic> j) => j['sections'][1]['startMs'] = 1000,
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects overlapping sibling lines', () {
      expect(
        () => SongTimeline.fromJson(
          mutated(
            (Map<String, dynamic> j) =>
                j['sections'][0]['lines'].add(<String, dynamic>{
                  'text': 'Again',
                  'startMs': 500,
                  'endMs': 1500,
                  'words': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'word': 'Again',
                      'startMs': 500,
                      'endMs': 1500,
                      'syllables': 2,
                    },
                  ],
                }),
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects overlapping sibling words', () {
      expect(
        () => SongTimeline.fromJson(
          mutated(
            (Map<String, dynamic> j) => j['sections'][0]['lines'][0]['words']
                .insert(1, <String, dynamic>{
                  'word': 'Ghost',
                  'startMs': 400,
                  'endMs': 900,
                  'syllables': 1,
                }),
          ),
        ),
        throwsFormatException,
      );
    });
    test('rejects a non-positive beat interval', () {
      expect(
        () => SongTimeline.fromJson(
          mutated(
            (Map<String, dynamic> j) => j['downbeat']['beatIntervalMs'] = 0.0,
          ),
        ),
        throwsFormatException,
      );
    });
  });

  group('SongTimeline.toJson', () {
    test('round-trips through the canonical schema', () {
      final SongTimeline timeline = canonicalTimeline();
      final Map<String, dynamic> json = timeline.toJson();
      expect(
        json.keys,
        containsAll(<String>[
          'schemaVersion',
          'title',
          'styleId',
          'bpm',
          'durationMs',
          'downbeat',
          'sections',
          'cues',
        ]),
      );
      final SongTimeline parsed = SongTimeline.fromJson(json);
      expect(parsed.toJson(), json);
    });

    test('withCues replaces the cue list without touching sections', () {
      final SongTimeline timeline = canonicalTimeline();
      const EvidenceCue sticker = EvidenceCue(
        timeMs: 3000,
        kind: EvidenceCueKind.sticker,
        label: 'Karaoke Den',
        memoryId: 'm3',
      );
      final SongTimeline recued = timeline.withCues(const <EvidenceCue>[
        sticker,
      ]);
      expect(recued.cues, <EvidenceCue>[sticker]);
      expect(recued.sections, same(timeline.sections));
    });
  });
}
