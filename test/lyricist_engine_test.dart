import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/engines/lyricist_engine.dart';
import 'package:road_song/models/song_models.dart';
import 'package:road_song/models/trip_models.dart';

const TimelineMemory kChurroMemory = TimelineMemory(
  id: 'm1',
  author: '@alex',
  time: '11:42 PM',
  text: 'Alex tried to fight a seagull for the last churro. The seagull won.',
  day: 1,
  locationName: 'Marina Pier',
);

const TimelineMemory kLaundryMemory = TimelineMemory(
  id: 'm2',
  author: '@sarah',
  time: '02:15 AM',
  text: 'Ended up at a 24hr laundromat playing poker with candy wrappers.',
  day: 1,
  locationName: 'The 24hr Laundromat',
);

const TimelineMemory kKaraokeMemory = TimelineMemory(
  id: 'm3',
  author: '@group',
  time: '04:00 AM',
  text: 'Karaoke meltdown. We owe the owner an apology.',
  day: 2,
  locationName: 'Karaoke Den',
);

/// Deterministic memory fixtures (Seam B: engine tests run without UI).
const List<TimelineMemory> kCaboMemories = [
  kChurroMemory,
  kLaundryMemory,
  kKaraokeMemory,
];

const List<String> kCrew = ['Maya', 'Tom', 'Priya'];

/// Joins every lyric line of the song into one searchable string.
String _allLines(LyricSong song) =>
    [for (final LyricSection s in song.sections) ...s.lines].join('\n');

void main() {
  const TemplateLyricist lyricist = TemplateLyricist();

  Future<LyricSong> composeCabo() => lyricist.composeSong(
    tripName: "Cabo Fail '23",
    participants: kCrew,
    memories: kCaboMemories,
  );

  group('composeSong', () {
    test('returns the six modular sections in flow order', () async {
      final LyricSong song = await composeCabo();

      expect(
        [for (final LyricSection s in song.sections) s.id],
        ['intro', 'v1', 'ch', 'v2', 'br', 'out'],
      );
      expect(
        [for (final LyricSection s in song.sections) s.label],
        ['Intro', 'Verse 1', 'Chorus', 'Verse 2', 'Bridge', 'Outro'],
      );
    });

    test(
      'is deterministic — identical input produces identical lyrics',
      () async {
        final LyricSong a = await composeCabo();
        final LyricSong b = await composeCabo();

        expect(a.title, b.title);
        expect(
          [for (final LyricSection s in a.sections) s.lines],
          [for (final LyricSection s in b.sections) s.lines],
        );
      },
    );

    test('every section carries two non-empty line variants', () async {
      final LyricSong song = await composeCabo();

      for (final LyricSection section in song.sections) {
        expect(section.variants.length, 2, reason: section.label);
        for (final List<String> variant in section.variants) {
          expect(variant, isNotEmpty, reason: section.label);
          for (final String line in variant) {
            expect(line.trim(), isNotEmpty, reason: section.label);
          }
        }
      }
    });

    test('lyrics name the participants', () async {
      final LyricSong song = await composeCabo();
      final String lines = _allLines(song);

      expect(lines, contains('Maya'));
      expect(lines, contains('Tom'));
      expect(lines, contains('Priya'));
    });

    test("lyrics quote the trip's own moments", () async {
      final LyricSong song = await composeCabo();
      final String lines = _allLines(song);

      expect(lines, contains('seagull for the last churro'));
      expect(lines, contains('playing poker with candy'));
      expect(lines, contains('Karaoke meltdown'));
    });

    test('falls back to the photo caption when a memory has no text', () async {
      final LyricSong song = await lyricist.composeSong(
        tripName: "Cabo Fail '23",
        participants: kCrew,
        memories: const [
          kChurroMemory,
          TimelineMemory(
            id: 'm2',
            author: '@sarah',
            time: '02:15 AM',
            text: '',
            day: 1,
            photoCaption: 'the \$50 tractor',
          ),
          kKaraokeMemory,
        ],
      );
      expect(_allLines(song), contains('the \$50 tractor'));
    });

    test(
      'truncates over-long moments on a word boundary with an ellipsis',
      () async {
        final LyricSong song = await lyricist.composeSong(
          tripName: "Cabo Fail '23",
          participants: kCrew,
          memories: const [
            TimelineMemory(
              id: 'm1',
              author: '@alex',
              time: '11:42 PM',
              text:
                  'Ended up at a 24hr laundromat playing poker with candy wrappers until sunrise.',
              day: 1,
              locationName: 'The 24hr Laundromat',
            ),
            kKaraokeMemory,
          ],
        );
        expect(
          _allLines(song),
          contains(
            'Ended up at a 24hr laundromat playing poker with candy wrappers…',
          ),
        );
      },
    );

    test(
      'chorus loops a single-place trip instead of spanning places',
      () async {
        final LyricSong song = await lyricist.composeSong(
          tripName: "Cabo Fail '23",
          participants: kCrew,
          memories: const [
            kChurroMemory,
            TimelineMemory(
              id: 'm2',
              author: '@sarah',
              time: '02:15 AM',
              text: 'Ended up at a 24hr laundromat playing poker.',
              day: 1,
              locationName: 'Marina Pier',
            ),
          ],
        );
        final String chorus = song.section('ch')!.lines.join('\n');
        expect(chorus, contains('round and round Marina Pier'));
      },
    );

    test('chorus spans the pinned route from first to last place', () async {
      final LyricSong song = await composeCabo();
      final String chorus = song.section('ch')!.lines.join('\n');

      expect(chorus, contains('from Marina Pier to Karaoke Den'));
    });

    test('titles a multi-stop trip "Every Wrong Turn"', () async {
      final LyricSong song = await composeCabo();
      expect(song.title, 'Every Wrong Turn');
    });

    test('titles an unpinned trip after the trip name', () async {
      final LyricSong song = await lyricist.composeSong(
        tripName: 'Lisbon Trip',
        participants: kCrew,
        memories: const [kChurroMemory],
      );
      expect(song.title, "The Lisbon Trip Tapes");
    });

    test('handles an empty trip without names, places or moments', () async {
      final LyricSong song = await lyricist.composeSong(
        tripName: '',
        participants: const [],
        memories: const [],
      );

      expect(song.title, 'Every Wrong Turn');
      final String lines = _allLines(song);
      expect(lines, contains('the crew'));
      for (final LyricSection section in song.sections) {
        expect(section.lines, isNotEmpty);
      }
    });

    test(
      'regenerating after new memories reflects the latest content',
      () async {
        // First draft: only the churro memory exists.
        final LyricSong first = await lyricist.composeSong(
          tripName: "Cabo Fail '23",
          participants: kCrew,
          memories: const [kChurroMemory],
        );
        expect(_allLines(first), contains('seagull for the last churro'));
        expect(
          _allLines(first),
          isNot(contains('Karaoke meltdown')),
          reason: 'the karaoke memory does not exist yet',
        );

        // A new memory lands; regenerating drafts from the latest content.
        final LyricSong regenerated = await lyricist.composeSong(
          tripName: "Cabo Fail '23",
          participants: kCrew,
          memories: kCaboMemories,
        );
        final String lines = _allLines(regenerated);
        expect(lines, contains('seagull for the last churro'));
        expect(lines, contains('Karaoke meltdown'));
        expect(lines, contains('playing poker with candy'));
      },
    );
  });

  group('rewriteSection', () {
    test(
      'swaps the section to its alternate lines without mutating it',
      () async {
        final LyricSong song = await composeCabo();
        final LyricSection chorus = song.section('ch')!;
        final List<String> original = chorus.lines.toList();

        final LyricSection rewritten = await lyricist.rewriteSection(chorus);

        expect(rewritten.lines, isNot(original));
        expect(chorus.lines, original, reason: 'input section stays untouched');
      },
    );

    test('cycles back to the original lines after two rewrites', () async {
      final LyricSong song = await composeCabo();
      final LyricSection chorus = song.section('ch')!;
      final List<String> original = chorus.lines.toList();

      final LyricSection once = await lyricist.rewriteSection(chorus);
      final LyricSection twice = await lyricist.rewriteSection(once);

      expect(twice.lines, original);
    });
  });

  group('respondToFeedback', () {
    test('punches up the chorus when asked about the chorus', () async {
      final LyricSong song = await composeCabo();
      final List<String> original = song.section('ch')!.lines.toList();

      final LyricistReply reply = await lyricist.respondToFeedback(
        feedback: 'make the chorus funnier',
        song: song,
      );

      expect(reply.reply, contains('chorus'));
      expect(reply.song.section('ch')!.lines, isNot(original));
      // Other sections stay untouched.
      expect(reply.song.section('v1')!.lines, song.section('v1')!.lines);
    });

    test('routes feedback to the named section', () async {
      final LyricSong song = await composeCabo();

      final LyricistReply bridgeReply = await lyricist.respondToFeedback(
        feedback: 'rework the bridge',
        song: song,
      );
      expect(bridgeReply.reply, contains('bridge'));
      expect(
        bridgeReply.song.section('br')!.lines,
        isNot(song.section('br')!.lines),
      );

      final LyricistReply verseTwoReply = await lyricist.respondToFeedback(
        feedback: 'rewrite verse 2 please',
        song: song,
      );
      expect(
        verseTwoReply.song.section('v2')!.lines,
        isNot(song.section('v2')!.lines),
      );

      final LyricistReply outroReply = await lyricist.respondToFeedback(
        feedback: 'softer ending for the outro',
        song: song,
      );
      expect(
        outroReply.song.section('out')!.lines,
        isNot(song.section('out')!.lines),
      );
    });

    test('refining the same section repeatedly cycles its variants', () async {
      final LyricSong song = await composeCabo();
      final List<String> original = song.section('ch')!.lines.toList();

      final LyricistReply first = await lyricist.respondToFeedback(
        feedback: 'make the chorus funnier',
        song: song,
      );
      final LyricistReply second = await lyricist.respondToFeedback(
        feedback: 'make the chorus funnier again',
        song: first.song,
      );

      expect(first.song.section('ch')!.lines, isNot(original));
      expect(second.song.section('ch')!.lines, original);
    });

    test('falls back to the chorus for unrelated feedback', () async {
      final LyricSong song = await composeCabo();
      final List<String> original = song.section('ch')!.lines.toList();

      final LyricistReply reply = await lyricist.respondToFeedback(
        feedback: 'make it pop',
        song: song,
      );

      expect(reply.song.section('ch')!.lines, isNot(original));
    });
  });
}
