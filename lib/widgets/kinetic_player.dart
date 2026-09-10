import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../engines/highlight_reel_engine.dart';
import '../engines/player_renderer.dart';
import '../models/song_models.dart';
import '../models/trip_models.dart';
import '../services/audio_seam.dart';
import '../theme.dart';
import 'beat_media_canvas.dart';
import 'cassette_reel_widget.dart';
import 'evidence_sticker_overlay.dart';
import 'kinetic_subtitle_painter.dart';

/// The finished memorial playing as a kinetic player (issue #30): media
/// moving on the music, lyric cues highlighting in sync on the line-level
/// timeline (line start times over the track plus section markers), with
/// play/pause, seek and replay controls.
///
/// Audio goes through the injectable [AudioSeam] (mocked in tests); the
/// visual frame comes from the [PlayerRenderer] seam (simulated in v1). The
/// playback clock is a ticker so tests advance deterministically; the audio
/// seam's position stream corrects the clock in production so the visuals
/// stay locked to the actual audio.
class KineticPlayer extends StatefulWidget {
  final SongTimeline timeline;
  final List<TimelineMemory> memories;
  final AudioSeam audioSeam;
  final PlayerRenderer renderer;
  final VoidCallback? onClose;
  final VoidCallback? onShare;

  /// Whether playback starts immediately. The caller starts the audio seam
  /// from the user gesture that opened the player (web autoplay policy) and
  /// passes true so the player clock runs in sync.
  final bool autoPlay;

  const KineticPlayer({
    super.key,
    required this.timeline,
    required this.memories,
    required this.audioSeam,
    this.renderer = const SimulatedPlayerRenderer(),
    this.onClose,
    this.onShare,
    this.autoPlay = false,
  });

  @override
  State<KineticPlayer> createState() => _KineticPlayerState();
}

class _KineticPlayerState extends State<KineticPlayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _positionMs = 0;
  late bool _isPlaying = widget.autoPlay;
  Duration _lastElapsed = Duration.zero;
  bool _isScrubbing = false;
  late int _durationMs = widget.timeline.durationMs;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (_isPlaying) _ticker.start();
    // Prime the audio so the first play is gesture-proximate (web autoplay
    // policy) and the real duration can correct the timeline.
    widget.audioSeam.prime(
      widget.timeline.styleId == ''
          ? ''
          : _audioAssetFor(widget.timeline.styleId),
    );
    _durationSub = widget.audioSeam.durationStream.listen((Duration d) {
      if (d.inMilliseconds > 0 && mounted) {
        setState(() => _durationMs = d.inMilliseconds);
      }
    });
    _positionSub = widget.audioSeam.positionStream.listen((Duration p) {
      if (!_isScrubbing && mounted) {
        setState(() => _positionMs = p.inMilliseconds.clamp(0, _durationMs));
      }
    });
    _completeSub = widget.audioSeam.onComplete.listen((_) {
      if (mounted) _finish();
    });
  }

  String _audioAssetFor(String styleId) {
    for (final MusicalStyle style in MusicalStyle.catalog) {
      if (style.id == styleId) return style.audioAsset;
    }
    return '';
  }

  @override
  void dispose() {
    _ticker.dispose();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    super.dispose();
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
      if (_positionMs >= _durationMs) {
        _positionMs = _durationMs;
        _isPlaying = false;
        _ticker.stop();
      }
    });
  }

  void _finish() {
    setState(() {
      _positionMs = _durationMs;
      _isPlaying = false;
    });
    _ticker.stop();
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _isPlaying = false;
        _ticker.stop();
        widget.audioSeam.pause();
      } else {
        if (_positionMs >= _durationMs) {
          _positionMs = 0;
          widget.audioSeam.seek(Duration.zero);
        }
        _lastElapsed = Duration.zero;
        _isPlaying = true;
        _ticker.start();
        widget.audioSeam.start();
      }
    });
  }

  void _seekTo(int ms) {
    setState(() {
      _positionMs = ms.clamp(0, _durationMs);
    });
    widget.audioSeam.seek(Duration(milliseconds: ms.clamp(0, _durationMs)));
  }

  void _replay() {
    _seekTo(0);
    if (!_isPlaying) {
      setState(() {
        _lastElapsed = Duration.zero;
        _isPlaying = true;
      });
      _ticker.start();
      widget.audioSeam.start();
    }
  }

  void _onScrubStart(double value) {
    setState(() => _isScrubbing = true);
  }

  void _onScrubUpdate(double value) {
    setState(() {
      _positionMs = value.round().clamp(0, _durationMs);
    });
  }

  void _onScrubEnd(double value) {
    setState(() {
      _isScrubbing = false;
      _positionMs = value.round().clamp(0, _durationMs);
      _lastElapsed = Duration.zero;
    });
    widget.audioSeam.seek(Duration(milliseconds: _positionMs));
  }

  String _formatTimecode(int ms) {
    final int totalSeconds = ms ~/ 1000;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final HighlightReelFrame frame = widget.renderer.renderFrame(
      timeline: widget.timeline,
      memories: widget.memories,
      positionMs: _positionMs,
    );

    return Scaffold(
      backgroundColor: BrutalTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BrutalTheme.inkBlack, width: 2.5),
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
                      BeatMediaCanvas(frame: frame),
                      CustomPaint(
                        painter: KineticSubtitlePainter(frame: frame),
                      ),
                      EvidenceStickerOverlay(frame: frame),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CassetteReelWidget(frame: frame, isPlaying: _isPlaying),
            ),
            const SizedBox(height: 8),
            _buildLineCueStrip(),
            const SizedBox(height: 8),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('kinetic-close-button'),
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
              key: const ValueKey('kinetic-share-button'),
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
    );
  }

  /// The line-level lyric cue strip: the active section marker and the
  /// active lyric line, highlighting in sync with the line start times over
  /// the track (spec decision 12 — line-level timeline for v1).
  Widget _buildLineCueStrip() {
    final TimelineSection? section = widget.timeline.sectionAt(_positionMs);
    final TimelineLine? line = widget.timeline.lineAt(_positionMs);
    return Container(
      key: const ValueKey('line-cue-strip'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF19130D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4A3B2C)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: section == null
                  ? const Color(0xFF4A3B2C)
                  : BrutalTheme.primary,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              section?.label.toUpperCase() ?? 'INTRO',
              style: GoogleFonts.spaceMono(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: const Color(0xFFFFF8EC),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line?.text ?? '♪',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.instrumentSerif(
                fontSize: 16,
                color: const Color(0xFFFDE047),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
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
              key: const ValueKey('kinetic-scrubber-slider'),
              value: _positionMs.toDouble().clamp(0.0, _durationMs.toDouble()),
              min: 0.0,
              max: _durationMs.toDouble(),
              onChangeStart: _onScrubStart,
              onChanged: _onScrubUpdate,
              onChangeEnd: _onScrubEnd,
            ),
          ),
          Row(
            children: [
              IconButton(
                key: const ValueKey('kinetic-play-pause-button'),
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: const Color(0xFFFFF8EC),
                  size: 38,
                ),
                onPressed: _togglePlayPause,
              ),
              IconButton(
                key: const ValueKey('kinetic-replay-button'),
                icon: const Icon(
                  Icons.replay,
                  color: Color(0xFFD6BE8C),
                  size: 24,
                ),
                onPressed: _replay,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF19130D),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF4A3B2C)),
                ),
                child: Text(
                  '${_formatTimecode(_positionMs)} / ${_formatTimecode(_durationMs)}',
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
    );
  }
}
