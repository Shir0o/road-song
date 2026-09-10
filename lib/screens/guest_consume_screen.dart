import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/song_models.dart';
import '../models/trip_models.dart';
import '../services/audio_seam.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';
import '../widgets/kinetic_player.dart';

/// The visitor consume mode of the guest web surface (issue #30): a visitor
/// opening the trip link on another device listens to the finished song and
/// browses the diary — no app or account required. The memorial player runs
/// through the same injectable audio seam as the app (mocked in tests).
class GuestConsumeScreen extends StatefulWidget {
  final Trip trip;
  final AudioSeam audioSeam;
  final VoidCallback? onBack;

  const GuestConsumeScreen({
    super.key,
    required this.trip,
    required this.audioSeam,
    this.onBack,
  });

  @override
  State<GuestConsumeScreen> createState() => _GuestConsumeScreenState();
}

class _GuestConsumeScreenState extends State<GuestConsumeScreen> {
  bool _listening = false;

  @override
  void dispose() {
    // Release the audio player when the consume surface is left so no song
    // keeps playing after the visitor navigates away.
    final AudioSeam audio = widget.audioSeam;
    if (audio is AudioplayersAudioSeam) audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Trip trip = widget.trip;
    final MemorialSong? song = trip.memorialSong;
    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      trip.name.toUpperCase(),
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: BrutalTheme.inkBlack,
                      ),
                    ),
                    Transform.rotate(
                      angle: -2 * 3.14159 / 180,
                      child: Text(
                        'every wrong turn, kept forever',
                        style: GoogleFonts.caveat(
                          fontSize: 19,
                          color: BrutalTheme.graphite,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (song != null) _buildListenSection(song),
                    const SizedBox(height: 24),
                    _buildDiarySection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('guest-consume-back'),
            icon: const Icon(Icons.arrow_back, color: BrutalTheme.inkBlack),
            onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          Text(
            'THE MEMORIAL',
            style: GoogleFonts.spaceMono(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: BrutalTheme.inkBlack,
            ),
          ),
          const Spacer(),
          const DymoLabel(
            text: 'LISTEN · BROWSE',
            fontSize: 10,
            backgroundColor: BrutalTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildListenSection(MemorialSong song) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'LISTEN TO THE SONG',
          style: GoogleFonts.spaceMono(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
            color: BrutalTheme.graphite,
          ),
        ),
        const SizedBox(height: 8),
        BrutalCard(
          color: BrutalTheme.card,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: GoogleFonts.instrumentSerif(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: BrutalTheme.inkBlack,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${song.bpm} BPM · ${song.styleId.toUpperCase()}',
                style: GoogleFonts.spaceMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: BrutalTheme.graphite,
                ),
              ),
              const SizedBox(height: 12),
              if (!_listening)
                SizedBox(
                  width: double.infinity,
                  child: BrutalButton(
                    key: const ValueKey('guest-listen-button'),
                    onPressed: () {
                      // The audible start derives from this tap (web
                      // autoplay policy); the player clock runs in sync.
                      widget.audioSeam.prime(song.audioAsset);
                      widget.audioSeam.start();
                      setState(() => _listening = true);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Listen to the song',
                          style: BrutalTheme.ctaLabelStyle(),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildGuestPlayer(song),
            ],
          ),
        ),
      ],
    );
  }

  /// The visitor's kinetic player: the same player the creator sees, driven
  /// by the line-level timeline served by the backend. The audible start
  /// derives from the tap that opened it (web autoplay policy).
  Widget _buildGuestPlayer(MemorialSong song) {
    final SongTimeline timeline = _timelineFromMemorial(song);
    return SizedBox(
      height: 560,
      child: KineticPlayer(
        timeline: timeline,
        memories: widget.trip.memories,
        audioSeam: widget.audioSeam,
        autoPlay: true,
        onClose: () => setState(() => _listening = false),
      ),
    );
  }

  /// Rebuilds a playable line-level timeline from the wire payload: the
  /// backend serves line start times and section markers (spec decision 12),
  /// which is exactly what the kinetic subtitles need.
  SongTimeline _timelineFromMemorial(MemorialSong song) {
    final List<TimelineSection> sections = <TimelineSection>[];
    for (final MemorialSection section in song.sections) {
      final List<TimelineLine> lines = <TimelineLine>[];
      for (int i = 0; i < section.lines.length; i++) {
        final MemorialLine line = section.lines[i];
        final int endMs = i + 1 < section.lines.length
            ? section.lines[i + 1].startMs
            : section.endMs;
        lines.add(
          TimelineLine(
            text: line.text,
            startMs: line.startMs,
            endMs: endMs,
            words: <TimelineWord>[
              TimelineWord(
                word: line.text,
                startMs: line.startMs,
                endMs: endMs,
                syllables: 1,
              ),
            ],
          ),
        );
      }
      sections.add(
        TimelineSection(
          id: section.id,
          label: section.label,
          kind: _kindFor(section.kind),
          startMs: section.startMs,
          endMs: section.endMs,
          lines: lines,
        ),
      );
    }
    return SongTimeline(
      title: song.title,
      styleId: song.styleId,
      bpm: song.bpm,
      durationMs: song.durationMs,
      downbeat: DownbeatGrid(
        beatIntervalMs: 60000 / (song.bpm > 0 ? song.bpm : 120),
        beatsPerBar: 4,
        offsetMs: 0,
        durationMs: song.durationMs,
      ),
      sections: sections,
    );
  }

  TimelineSectionKind _kindFor(String kind) {
    for (final TimelineSectionKind k in TimelineSectionKind.values) {
      if (k.name == kind) return k;
    }
    return TimelineSectionKind.verse;
  }

  Widget _buildDiarySection() {
    final List<TimelineMemory> memories = widget.trip.memories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'BROWSE THE DIARY',
          style: GoogleFonts.spaceMono(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
            color: BrutalTheme.graphite,
          ),
        ),
        const SizedBox(height: 8),
        if (memories.isEmpty)
          BrutalCard(
            color: BrutalTheme.card,
            padding: const EdgeInsets.all(16),
            child: Text(
              'The diary is still filling up — memories land here as they '
              'are added.',
              style: GoogleFonts.karla(
                fontSize: 13.5,
                height: 1.5,
                color: BrutalTheme.inkBlack,
              ),
            ),
          )
        else
          for (final TimelineMemory memory in memories)
            _buildMemoryCard(memory),
      ],
    );
  }

  Widget _buildMemoryCard(TimelineMemory memory) {
    return Container(
      key: ValueKey('guest-memory-${memory.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrutalTheme.card,
        border: Border.all(color: const Color(0xFFEBDFC6), width: 1),
        borderRadius: BorderRadius.circular(10),
        boxShadow: BrutalTheme.brutalShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  memory.displayContributor,
                  style: GoogleFonts.karla(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
              ),
              if (memory.isPinned)
                Text(
                  '⚑ ${memory.locationName}',
                  style: GoogleFonts.karla(
                    fontSize: 11,
                    color: BrutalTheme.graphite,
                  ),
                ),
            ],
          ),
          if (memory.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              memory.text,
              style: GoogleFonts.karla(
                fontSize: 14.5,
                height: 1.55,
                color: BrutalTheme.inkBlack,
              ),
            ),
          ],
          if (memory.displayCaption.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              memory.displayCaption,
              style: GoogleFonts.caveat(
                fontSize: 17,
                color: const Color(0xFF5D4F3C),
              ),
            ),
          ],
          if (memory.hasPhoto || memory.hasVideo) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  memory.hasVideo
                      ? Icons.movie_outlined
                      : Icons.photo_library_outlined,
                  size: 15,
                  color: BrutalTheme.graphite,
                ),
                const SizedBox(width: 6),
                Text(
                  memory.hasVideo ? 'SHORT CLIP' : 'PHOTO',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: BrutalTheme.graphite,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
