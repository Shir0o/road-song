import '../models/song_models.dart';
import '../models/trip_models.dart';
import 'highlight_reel_engine.dart';

/// CONTEXT.md "Player/Renderer" seam: renders the finished memorial as a
/// kinetic player — media moving on the music, lyric cues highlighting in
/// sync on the line-level timeline (line start times over the track plus
/// section markers). v1 ships the deterministic simulated implementation; a
/// real renderer (e.g. a video pipeline) can replace it without touching
/// the player UI.
abstract class PlayerRenderer {
  /// Computes the visual frame at [positionMs] for the given timeline and
  /// memories.
  HighlightReelFrame renderFrame({
    required SongTimeline timeline,
    required List<TimelineMemory> memories,
    required int positionMs,
  });
}

/// Deterministic simulated renderer: delegates to the highlight-reel frame
/// engine (beat-matched media cuts, kinetic typography, evidence popups).
class SimulatedPlayerRenderer implements PlayerRenderer {
  const SimulatedPlayerRenderer();

  @override
  HighlightReelFrame renderFrame({
    required SongTimeline timeline,
    required List<TimelineMemory> memories,
    required int positionMs,
  }) {
    return HighlightReelEngine.computeFrame(
      timeline: timeline,
      memories: memories,
      positionMs: positionMs,
    );
  }
}
