import '../models/song_models.dart';
import 'timeline_layout.dart';

/// Result of a vocal synthesis run: a playable track reference plus the
/// duration the forced aligner must fit the lyrics into.
class SynthResult {
  final String audioId;
  final int durationMs;

  const SynthResult({required this.audioId, required this.durationMs});
}

/// CONTEXT.md "Vocal/Music Synthesizer" seam: renders structured lyrics into
/// a vocal audio track for the chosen vibe and tempo. v1 ships the
/// deterministic [SimulatedSongSynth]; a real ElevenLabs/Suno service can
/// replace this implementation without touching the UI.
abstract class SongSynthEngine {
  Future<SynthResult> synthesize({
    required LyricSong song,
    required MusicalStyle style,
    required int bpm,
  });
}

/// Deterministic simulated renderer: derives the track length from the
/// lyric's syllable load at the chosen tempo — the same math the aligner
/// uses — so the lyrics always fit the produced audio exactly.
class SimulatedSongSynth implements SongSynthEngine {
  const SimulatedSongSynth();

  @override
  Future<SynthResult> synthesize({
    required LyricSong song,
    required MusicalStyle style,
    required int bpm,
  }) async {
    final TimelineLayout layout = planTimelineLayout(song: song, bpm: bpm);
    return SynthResult(
      audioId: 'sim://vocal/${style.id}/$bpm/${layout.totalMs}',
      durationMs: layout.totalMs,
    );
  }
}
