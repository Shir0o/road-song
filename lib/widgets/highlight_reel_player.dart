import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../engines/highlight_reel_engine.dart';
import '../models/song_models.dart';
import '../models/trip_models.dart';
import '../theme.dart';
import 'beat_media_canvas.dart';
import 'cassette_reel_widget.dart';
import 'evidence_sticker_overlay.dart';
import 'kinetic_subtitle_painter.dart';

/// Full interactive Highlight Reel Player executing 60fps kinetic typography,
/// beat-matched media cuts with Ken Burns pan-zoom, evidence sticker popups,
/// cassette reel animations, and full scrub / seek / timecode playback controls.
class HighlightReelPlayer extends StatefulWidget {
  final SongTimeline timeline;
  final List<TimelineMemory> memories;
  final VoidCallback? onClose;
  final VoidCallback? onShare;

  const HighlightReelPlayer({
    super.key,
    required this.timeline,
    required this.memories,
    this.onClose,
    this.onShare,
  });

  @override
  State<HighlightReelPlayer> createState() => _HighlightReelPlayerState();
}

class _HighlightReelPlayerState extends State<HighlightReelPlayer>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  int _positionMs = 0;
  bool _isPlaying = true;
  Duration _lastElapsed = Duration.zero;
  bool _isScrubbing = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (_isPlaying) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying || _isScrubbing) {
      _lastElapsed = elapsed;
      return;
    }
    final int deltaMs = (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;

    if (deltaMs <= 0) return;

    setState(() {
      _positionMs += deltaMs;
      if (_positionMs >= widget.timeline.durationMs) {
        _positionMs = widget.timeline.durationMs;
        _isPlaying = false;
        _ticker.stop();
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _isPlaying = false;
        _ticker.stop();
      } else {
        if (_positionMs >= widget.timeline.durationMs) {
          _positionMs = 0;
        }
        _lastElapsed = Duration.zero;
        _isPlaying = true;
        _ticker.start();
      }
    });
  }

  void _seekTo(int ms) {
    setState(() {
      _positionMs = ms.clamp(0, widget.timeline.durationMs);
    });
  }

  void _onScrubStart(double value) {
    setState(() {
      _isScrubbing = true;
    });
  }

  void _onScrubUpdate(double value) {
    setState(() {
      _positionMs = value.round().clamp(0, widget.timeline.durationMs);
    });
  }

  void _onScrubEnd(double value) {
    setState(() {
      _isScrubbing = false;
      _positionMs = value.round().clamp(0, widget.timeline.durationMs);
      _lastElapsed = Duration.zero;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  String _formatTimecode(int ms) {
    final int totalSeconds = ms ~/ 1000;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final HighlightReelFrame frame = HighlightReelEngine.computeFrame(
      timeline: widget.timeline,
      memories: widget.memories,
      positionMs: _positionMs,
    );

    return Scaffold(
      backgroundColor: BrutalTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Close button & Song title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('reel-close-button'),
                    icon: const Icon(Icons.close, color: Color(0xFFFFF8EC)),
                    onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.timeline.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.instrumentSerif(
                            fontSize: 22,
                            color: const Color(0xFFFFF8EC),
                          ),
                        ),
                        Text(
                          '${widget.timeline.bpm} BPM · ${widget.timeline.styleId.toUpperCase()}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: const Color(0xFFD6BE8C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onShare != null) ...[
                    IconButton(
                      key: const ValueKey('reel-share-button'),
                      icon: const Icon(Icons.share_rounded, color: Color(0xFFFFF8EC)),
                      tooltip: 'Share memorial',
                      onPressed: widget.onShare,
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BrutalTheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '60 FPS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Video Canvas Stage
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: BrutalTheme.inkBlack,
                    width: 2.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 10),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Beat-Matched media background with Ken Burns
                      BeatMediaCanvas(frame: frame),

                      // 2. Kinetic typography CustomPainter overlay
                      CustomPaint(
                        painter: KineticSubtitlePainter(frame: frame),
                      ),

                      // 3. Evidence sticker popup overlay
                      EvidenceStickerOverlay(frame: frame),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Cassette Tape Reels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CassetteReelWidget(
                frame: frame,
                isPlaying: _isPlaying,
              ),
            ),

            const SizedBox(height: 8),

            // Interactive Playback Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Scrubber slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: BrutalTheme.primary,
                      inactiveTrackColor: const Color(0xFF4A3B2C),
                      thumbColor: const Color(0xFFFDE047),
                      overlayColor: const Color(0x33FDE047),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      key: const ValueKey('reel-scrubber-slider'),
                      value: _positionMs.toDouble().clamp(0.0, widget.timeline.durationMs.toDouble()),
                      min: 0.0,
                      max: widget.timeline.durationMs.toDouble(),
                      onChangeStart: _onScrubStart,
                      onChanged: _onScrubUpdate,
                      onChangeEnd: _onScrubEnd,
                    ),
                  ),

                  // Controls Row: Play/Pause, Rewind, Timecode
                  Row(
                    children: [
                      IconButton(
                        key: const ValueKey('reel-play-pause-button'),
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: const Color(0xFFFFF8EC),
                          size: 38,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      IconButton(
                        key: const ValueKey('reel-restart-button'),
                        icon: const Icon(
                          Icons.replay,
                          color: Color(0xFFD6BE8C),
                          size: 24,
                        ),
                        onPressed: () => _seekTo(0),
                      ),
                      const Spacer(),
                      // Timecode display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF19130D),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF4A3B2C)),
                        ),
                        child: Text(
                          '${_formatTimecode(_positionMs)} / ${_formatTimecode(widget.timeline.durationMs)}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFDE047),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
