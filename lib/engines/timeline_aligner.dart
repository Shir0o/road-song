import '../models/song_models.dart';
import 'song_synth_engine.dart';
import 'timeline_layout.dart';

/// CONTEXT.md "Timeline Aligner" seam: forced-aligns finalized lyrics against
/// a rendered audio track, producing the canonical [SongTimeline] with
/// word/syllable timestamps, section spans and the downbeat grid.
abstract class TimelineAligner {
  Future<SongTimeline> align({
    required LyricSong song,
    required MusicalStyle style,
    required int bpm,
    required SynthResult audio,
  });
}

/// Deterministic forced alignment: walks the lyric token stream at the chosen
/// tempo and scales the singing window so the first word starts after the
/// instrumental lead-in and the last word ends exactly before the tail —
/// whatever audio duration the synth reports.
class DeterministicTimelineAligner implements TimelineAligner {
  const DeterministicTimelineAligner();

  /// Singing window the aligner aims for on a normally-proportioned track.
  /// Tracks too short to fit lead-in + this window + tail squeeze their
  /// instrumentals proportionally and give the lyrics whatever remains —
  /// which can land below this floor on severely short audio.
  static const int _minWindowMs = 500;

  @override
  Future<SongTimeline> align({
    required LyricSong song,
    required MusicalStyle style,
    required int bpm,
    required SynthResult audio,
  }) async {
    final TimelineLayout layout = planTimelineLayout(song: song, bpm: bpm);
    int leadInMs = layout.leadInMs;
    int tailMs = layout.tailMs;
    int windowMs = audio.durationMs - leadInMs - tailMs;
    if (windowMs < _minWindowMs) {
      // Degenerate audio: squeeze the instrumentals proportionally; the
      // singing window keeps the remainder (windowMs < _minWindowMs implies
      // the whole track is shorter than lead-in + floor + tail, so the
      // squeezed instrumentals always leave a non-negative window).
      final int minTotal = leadInMs + _minWindowMs + tailMs;
      final double factor = audio.durationMs / minTotal;
      leadInMs = (leadInMs * factor).floor();
      tailMs = (tailMs * factor).floor();
      windowMs = audio.durationMs - leadInMs - tailMs;
    }
    final List<PlannedSection> planned = walkTimeline(
      song: song,
      bpm: bpm,
      leadInMs: leadInMs,
      windowMs: windowMs,
    );

    return SongTimeline(
      title: song.title,
      styleId: style.id,
      bpm: bpm,
      durationMs: audio.durationMs,
      downbeat: DownbeatGrid(
        beatIntervalMs: 60000 / bpm,
        beatsPerBar: 4,
        offsetMs: 0,
        durationMs: audio.durationMs,
      ),
      sections: <TimelineSection>[
        for (final PlannedSection section in planned)
          TimelineSection(
            id: section.source.id,
            label: section.source.label,
            kind: _kindFor(section.source),
            startMs: section.startMs,
            endMs: section.endMs,
            lines: <TimelineLine>[
              for (final PlannedLine line in section.lines)
                TimelineLine(
                  text: line.text,
                  startMs: line.startMs,
                  endMs: line.endMs,
                  words: <TimelineWord>[
                    for (final PlannedWord word in line.words)
                      TimelineWord(
                        word: word.word,
                        startMs: word.startMs,
                        endMs: word.endMs,
                        syllables: word.syllables,
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  /// Maps the lyricist's stable section ids to musical kinds.
  TimelineSectionKind _kindFor(LyricSection section) {
    switch (section.id) {
      case 'intro':
        return TimelineSectionKind.intro;
      case 'ch':
        return TimelineSectionKind.chorus;
      case 'br':
        return TimelineSectionKind.bridge;
      case 'out':
        return TimelineSectionKind.outro;
      default:
        return TimelineSectionKind.verse;
    }
  }
}
