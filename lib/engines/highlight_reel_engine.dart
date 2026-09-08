import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/song_models.dart';
import '../models/trip_models.dart';

/// Kinetic effect style applied to the active word in the highlight reel.
enum KineticWordEffect {
  bounce,
  shake,
  burst,
  karaokeFill,
}

/// A snapshot of all visual properties needed to render a single 60fps frame
/// at [positionMs] in the highlight reel player.
class HighlightReelFrame {
  final int positionMs;
  final TimelineSection? activeSection;
  final TimelineLine? activeLine;
  final TimelineWord? activeWord;

  /// Progress through the currently active word in range [0.0, 1.0].
  final double wordProgress;

  /// Kinetic style for the current section/word.
  final KineticWordEffect kineticStyle;

  /// Vertical bounce displacement in logical pixels (negative is upward).
  final double wordBounceY;

  /// Jitter shake offset for energetic moments.
  final Offset wordShakeOffset;

  /// Scale punch factor (1.0 = normal, > 1.0 = burst pop).
  final double wordScale;

  /// Karaoke fill ratio across the current word span [0.0, 1.0].
  final double karaokeFillRatio;

  /// Index of the active media memory.
  final int mediaIndex;

  /// The memory item being shown as the video/photo background.
  final TimelineMemory mediaMemory;

  /// Ken Burns pan offset in logical pixels for the active media.
  final Offset kenBurnsPan;

  /// Ken Burns zoom multiplier (e.g. 1.0 .. 1.25).
  final double kenBurnsZoom;

  /// If a lyric cue popup is active at this timestamp, points to it.
  final EvidenceCue? activeCue;

  /// Scale of the sticker popup during its spring entrance / exit.
  final double cuePopupScale;

  /// Opacity of the sticker popup [0.0, 1.0].
  final double cuePopupOpacity;

  /// Rotation angle of the sticker popup in radians.
  final double cuePopupRotation;

  /// Rotation angles of left and right cassette / vinyl reels in radians.
  final double leftReelAngle;
  final double rightReelAngle;

  /// Radii of left and right spooled tape (left drains, right fills).
  final double leftReelTapeRadius;
  final double rightReelTapeRadius;

  const HighlightReelFrame({
    required this.positionMs,
    this.activeSection,
    this.activeLine,
    this.activeWord,
    required this.wordProgress,
    required this.kineticStyle,
    required this.wordBounceY,
    required this.wordShakeOffset,
    required this.wordScale,
    required this.karaokeFillRatio,
    required this.mediaIndex,
    required this.mediaMemory,
    required this.kenBurnsPan,
    required this.kenBurnsZoom,
    this.activeCue,
    required this.cuePopupScale,
    required this.cuePopupOpacity,
    required this.cuePopupRotation,
    required this.leftReelAngle,
    required this.rightReelAngle,
    required this.leftReelTapeRadius,
    required this.rightReelTapeRadius,
  });
}

/// Pure evaluation engine for calculating highlight reel frame states at
/// arbitrary millisecond timestamps.
class HighlightReelEngine {
  /// Default duration in ms a sticker popup remains on screen.
  static const int cueDisplayDurationMs = 2400;

  /// Fallback memory if no memories exist.
  static const TimelineMemory fallbackMemory = TimelineMemory(
    id: 'fallback-mem',
    author: 'Road Song Crew',
    time: 'Now',
    text: 'On the road with the song',
  );

  /// Computes the visual frame at [positionMs].
  static HighlightReelFrame computeFrame({
    required SongTimeline timeline,
    required List<TimelineMemory> memories,
    required int positionMs,
  }) {
    final int clampedMs = positionMs.clamp(0, timeline.durationMs);

    // 1. Resolve active section, line, and word.
    TimelineSection? activeSection;
    TimelineLine? activeLine;
    TimelineWord? activeWord;

    for (final TimelineSection section in timeline.sections) {
      if (clampedMs >= section.startMs && clampedMs <= section.endMs) {
        activeSection = section;
        break;
      }
    }
    // If between sections or in lead-in/tail, find closest section
    if (activeSection == null && timeline.sections.isNotEmpty) {
      if (clampedMs < timeline.sections.first.startMs) {
        activeSection = timeline.sections.first;
      } else {
        activeSection = timeline.sections.last;
      }
    }

    if (activeSection != null) {
      for (final TimelineLine line in activeSection.lines) {
        if (clampedMs >= line.startMs && clampedMs <= line.endMs) {
          activeLine = line;
          break;
        }
      }
      if (activeLine == null && activeSection.lines.isNotEmpty) {
        if (clampedMs < activeSection.lines.first.startMs) {
          activeLine = activeSection.lines.first;
        } else {
          activeLine = activeSection.lines.last;
        }
      }
    }

    if (activeLine != null) {
      for (final TimelineWord word in activeLine.words) {
        if (clampedMs >= word.startMs && clampedMs <= word.endMs) {
          activeWord = word;
          break;
        }
      }
      if (activeWord == null && activeLine.words.isNotEmpty) {
        if (clampedMs < activeLine.words.first.startMs) {
          activeWord = activeLine.words.first;
        } else {
          activeWord = activeLine.words.last;
        }
      }
    }

    // 2. Word progress and kinetic effects.
    double wordProgress = 0.0;
    if (activeWord != null) {
      final int span = activeWord.endMs - activeWord.startMs;
      if (span > 0) {
        wordProgress = ((clampedMs - activeWord.startMs) / span).clamp(0.0, 1.0);
      }
    }
    final double karaokeFillRatio = wordProgress;

    // Determine kinetic effect style based on section kind
    final TimelineSectionKind kind = activeSection?.kind ?? TimelineSectionKind.verse;
    final KineticWordEffect kineticStyle = switch (kind) {
      TimelineSectionKind.intro => KineticWordEffect.bounce,
      TimelineSectionKind.verse => KineticWordEffect.bounce,
      TimelineSectionKind.chorus => KineticWordEffect.shake,
      TimelineSectionKind.drop => KineticWordEffect.burst,
      TimelineSectionKind.bridge => KineticWordEffect.karaokeFill,
      TimelineSectionKind.outro => KineticWordEffect.bounce,
    };

    // Bounce Y: arc trajectory peaking in first half
    final double wordBounceY = switch (kineticStyle) {
      KineticWordEffect.bounce => -14.0 * math.sin(wordProgress * math.pi),
      _ => 0.0,
    };

    // Shake offset: pseudo-random high frequency jitter based on timestamp
    Offset wordShakeOffset = Offset.zero;
    if (kineticStyle == KineticWordEffect.shake) {
      final double angle = clampedMs * 0.05;
      final double intensity = 3.5 * math.sin(wordProgress * math.pi);
      wordShakeOffset = Offset(
        math.cos(angle * 3.7) * intensity,
        math.sin(angle * 2.9) * intensity,
      );
    }

    // Scale punch
    double wordScale = 1.0;
    if (kineticStyle == KineticWordEffect.shake || kineticStyle == KineticWordEffect.burst) {
      // Punch up to 1.25x on arrival, settling to 1.05x
      final double burstEnv = math.max(0.0, 1.0 - wordProgress * 1.5);
      wordScale = 1.05 + 0.20 * burstEnv;
    } else if (kineticStyle == KineticWordEffect.bounce) {
      wordScale = 1.0 + 0.08 * math.sin(wordProgress * math.pi);
    }

    // 3. Beat-synced media selection and Ken Burns pan/zoom.
    final List<TimelineMemory> validMemories =
        memories.isNotEmpty ? memories : [fallbackMemory];

    // Downbeats determine cuts. Use downbeatTimes (or bar downbeats).
    final List<double> downbeats = timeline.downbeat.downbeatTimes;
    int currentBeatIndex = 0;
    for (int i = 0; i < downbeats.length; i++) {
      if (clampedMs >= downbeats[i]) {
        currentBeatIndex = i;
      } else {
        break;
      }
    }

    final int mediaIndex = currentBeatIndex % validMemories.length;
    final TimelineMemory mediaMemory = validMemories[mediaIndex];

    // Beat interval for current cut
    final double beatStart = downbeats.isNotEmpty && currentBeatIndex < downbeats.length
        ? downbeats[currentBeatIndex]
        : 0.0;
    final double beatEnd = downbeats.isNotEmpty && (currentBeatIndex + 1) < downbeats.length
        ? downbeats[currentBeatIndex + 1]
        : timeline.durationMs.toDouble();
    final double beatSpan = math.max(1.0, beatEnd - beatStart);
    final double beatProgress = ((clampedMs - beatStart) / beatSpan).clamp(0.0, 1.0);

    // Ken Burns pan and zoom based on mediaIndex and beatProgress
    final double kenBurnsZoom = 1.05 + 0.15 * beatProgress;
    final double panDirection = (mediaIndex % 2 == 0) ? 1.0 : -1.0;
    final Offset kenBurnsPan = Offset(
      panDirection * (12.0 * beatProgress - 6.0),
      -8.0 * beatProgress + 4.0,
    );

    // 4. Evidence Cue popup calculation.
    EvidenceCue? activeCue;
    double cuePopupScale = 0.0;
    double cuePopupOpacity = 0.0;
    double cuePopupRotation = 0.0;

    for (final EvidenceCue cue in timeline.cues) {
      final int start = cue.timeMs;
      final int end = start + cueDisplayDurationMs;
      if (clampedMs >= start && clampedMs <= end) {
        activeCue = cue;
        final double elapsed = (clampedMs - start).toDouble();
        final double total = cueDisplayDurationMs.toDouble();

        // Spring pop-in during first 300ms, hold, then fade out in last 300ms
        if (elapsed < 300.0) {
          final double t = (elapsed / 300.0).clamp(0.0, 1.0);
          // Overshoot spring
          cuePopupScale = 1.15 * math.sin(t * math.pi * 0.5);
          cuePopupOpacity = math.sin(t * math.pi * 0.5).clamp(0.0, 1.0);
        } else if (elapsed > total - 300.0) {
          final double t = (total - elapsed) / 300.0;
          cuePopupScale = 1.0;
          cuePopupOpacity = t.clamp(0.0, 1.0);
        } else {
          cuePopupScale = 1.0;
          cuePopupOpacity = 1.0;
        }

        // Slight playful stamp tilt (-4 to +4 degrees)
        final double tiltDeg = (cue.timeMs % 9 - 4).toDouble();
        cuePopupRotation = tiltDeg * math.pi / 180.0;
        break;
      }
    }

    // 5. Cassette reel rotation and spooled tape radius.
    // 1 rotation every 2 seconds (~120 RPM simulation)
    final double rotSpeed = (2.0 * math.pi) / 2000.0;
    final double leftReelAngle = clampedMs * rotSpeed;
    final double rightReelAngle = clampedMs * rotSpeed;

    // Total song duration progress
    final double totalProgress = timeline.durationMs > 0
        ? (clampedMs / timeline.durationMs).clamp(0.0, 1.0)
        : 0.0;

    // Minimum hub radius = 12, max spooled tape radius = 32
    const double minRadius = 12.0;
    const double maxRadius = 32.0;
    final double leftReelTapeRadius = maxRadius - (maxRadius - minRadius) * totalProgress;
    final double rightReelTapeRadius = minRadius + (maxRadius - minRadius) * totalProgress;

    return HighlightReelFrame(
      positionMs: clampedMs,
      activeSection: activeSection,
      activeLine: activeLine,
      activeWord: activeWord,
      wordProgress: wordProgress,
      kineticStyle: kineticStyle,
      wordBounceY: wordBounceY,
      wordShakeOffset: wordShakeOffset,
      wordScale: wordScale,
      karaokeFillRatio: karaokeFillRatio,
      mediaIndex: mediaIndex,
      mediaMemory: mediaMemory,
      kenBurnsPan: kenBurnsPan,
      kenBurnsZoom: kenBurnsZoom,
      activeCue: activeCue,
      cuePopupScale: cuePopupScale,
      cuePopupOpacity: cuePopupOpacity,
      cuePopupRotation: cuePopupRotation,
      leftReelAngle: leftReelAngle,
      rightReelAngle: rightReelAngle,
      leftReelTapeRadius: leftReelTapeRadius,
      rightReelTapeRadius: rightReelTapeRadius,
    );
  }
}
