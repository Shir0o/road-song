/// Deterministic text-timing primitives shared by the vocal synth and the
/// timeline aligner so both agree on how lyric text maps to time.
library;

import '../models/song_models.dart';

final RegExp _nonLetters = RegExp('[^a-z]');

final RegExp _whitespace = RegExp(r'\s+');

/// Counts syllables in a single lyric token with a vowel-group heuristic:
/// every run of vowels (a, e, i, o, u, y) is one syllable, a silent trailing
/// "e" is dropped (kept for consonant+"le" endings), and punctuation and
/// casing are ignored. Punctuation-only tokens count zero.
int countSyllables(String token) {
  final String letters = token.toLowerCase().replaceAll(_nonLetters, '');
  if (letters.isEmpty) return 0;
  int groups = 0;
  bool inGroup = false;
  for (int i = 0; i < letters.length; i++) {
    final bool isVowel = 'aeiouy'.contains(letters[i]);
    if (isVowel && !inGroup) groups++;
    inGroup = isVowel;
  }
  if (letters.length >= 3 && letters.endsWith('e') && !letters.endsWith('le')) {
    groups--;
  }
  return groups < 1 ? 1 : groups;
}

/// Vocal pacing: two sung syllables per beat.
double _msPerSyllable(int bpm) => 30000 / bpm;

/// Instrumental breath between lyric sections: a half bar.
double _breathMs(int bpm) => 120000 / bpm;

/// Instrumental lead-in / tail: two bars each.
int _leadInOutMs(int bpm) => (2 * 240000 / bpm).round();

/// One timed lyric token on the planned vocal track.
class PlannedWord {
  final String word;
  final int startMs;
  final int endMs;
  final int syllables;

  const PlannedWord({
    required this.word,
    required this.startMs,
    required this.endMs,
    required this.syllables,
  });
}

/// One planned lyric line spanning its timed words.
class PlannedLine {
  final String text;
  final int startMs;
  final int endMs;
  final List<PlannedWord> words;

  const PlannedLine({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.words,
  });
}

/// One planned section (with its source lyric section) spanning its lines.
class PlannedSection {
  final LyricSection source;
  final int startMs;
  final int endMs;
  final List<PlannedLine> lines;

  const PlannedSection({
    required this.source,
    required this.startMs,
    required this.endMs,
    required this.lines,
  });
}

/// Natural (unscaled) timing plan for a song at a given tempo.
class TimelineLayout {
  /// Instrumental bars before the first lyric section.
  final int leadInMs;

  /// Instrumental bars after the last lyric section.
  final int tailMs;

  /// Singing window: every lyric section plus the breaths between them.
  final int windowMs;

  /// The planned sections with their timed lines and words.
  final List<PlannedSection> sections;

  const TimelineLayout({
    required this.leadInMs,
    required this.tailMs,
    required this.windowMs,
    required this.sections,
  });

  /// Whole track: lead-in + window + tail.
  int get totalMs => leadInMs + windowMs + tailMs;
}

/// Computes the natural layout of [song] at [bpm]: lead-in, per-word syllable
/// pacing, half-bar breaths between sections and a tail. The synth reports
/// this as the track duration; the aligner re-walks the same math scaled to
/// whatever audio duration it must fit.
TimelineLayout planTimelineLayout({required LyricSong song, required int bpm}) {
  final double natural = _naturalWindowMs(song, bpm);
  final int leadInMs = _leadInOutMs(bpm);
  final int tailMs = _leadInOutMs(bpm);
  final int windowMs = natural.round();
  return TimelineLayout(
    leadInMs: leadInMs,
    tailMs: tailMs,
    windowMs: windowMs,
    sections: walkTimeline(
      song: song,
      bpm: bpm,
      leadInMs: leadInMs,
      windowMs: windowMs,
    ),
  );
}

/// Walks the lyric token stream into timed sections: starts at [leadInMs],
/// spends [windowMs] of singing (scaled proportionally to the song's natural
/// pacing), with words contiguous inside lines and lines inside sections.
/// The last word ends exactly at `leadInMs + windowMs`.
List<PlannedSection> walkTimeline({
  required LyricSong song,
  required int bpm,
  required int leadInMs,
  required int windowMs,
}) {
  final double msPerSyllable = _msPerSyllable(bpm);
  final double breath = _breathMs(bpm);
  final double natural = _naturalWindowMs(song, bpm);
  final double scale = natural > 0 ? windowMs / natural : 1.0;

  double t = leadInMs.toDouble();
  final List<PlannedSection> sections = <PlannedSection>[];
  for (final LyricSection section in song.sections) {
    if (sections.isNotEmpty) t += breath * scale;
    final double sectionStart = t;
    final List<PlannedLine> lines = <PlannedLine>[];
    for (final String text in section.lines) {
      final List<PlannedWord> words = <PlannedWord>[];
      for (final String token in text.split(_whitespace)) {
        if (token.isEmpty) continue;
        final int syllables = countSyllables(token);
        final int start = t.round();
        t += syllables * msPerSyllable * scale;
        words.add(
          PlannedWord(
            word: token,
            startMs: start,
            endMs: t.round(),
            syllables: syllables,
          ),
        );
      }
      lines.add(
        PlannedLine(
          text: text,
          startMs: words.isEmpty ? t.round() : words.first.startMs,
          endMs: words.isEmpty ? t.round() : words.last.endMs,
          words: words,
        ),
      );
    }
    sections.add(
      PlannedSection(
        source: section,
        startMs: sectionStart.round(),
        endMs: t.round(),
        lines: lines,
      ),
    );
  }
  return sections;
}

/// Unscaled singing window (sections + breaths) in floating-point ms.
double _naturalWindowMs(LyricSong song, int bpm) {
  final double msPerSyllable = _msPerSyllable(bpm);
  double natural = 0.0;
  bool first = true;
  for (final LyricSection section in song.sections) {
    if (!first) natural += _breathMs(bpm);
    first = false;
    for (final String line in section.lines) {
      for (final String token in line.split(_whitespace)) {
        if (token.isEmpty) continue;
        natural += countSyllables(token) * msPerSyllable;
      }
    }
  }
  return natural;
}
