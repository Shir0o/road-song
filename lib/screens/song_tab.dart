import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../engines/lyricist_engine.dart';
import '../engines/evidence_cue_engine.dart';
import '../engines/song_synth_engine.dart';
import '../engines/timeline_aligner.dart';
import '../models/song_models.dart';
import '../models/trip_models.dart';
import '../services/audio_seam.dart';
import '../services/remote_trip_store.dart';
import '../services/trip_store.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';
import '../widgets/kinetic_player.dart';
import 'memorial_ready_screen.dart';

/// The Song tab: the songwriting stages of the zip flow — Song Start
/// ("Write our song"), the Reading progress pass, the modular lyrics view
/// with per-section rewrite/edit and the conversational refinement chat,
/// and the Choose Sound pass: vibe & tempo picker, the making-song
/// synthesis pass and the ready summary.
///
/// When [store] and [tripId] are provided (a created trip), the lyric draft
/// is loaded from and saved to the store, so hand edits and rewrites survive
/// screen changes and app restarts. Demo trips (no store) keep the draft in
/// local state.
class SongTab extends StatefulWidget {
  final String tripName;
  final List<TimelineMemory> memories;
  final List<String> participants;
  final TripStore? store;
  final String? tripId;

  /// The trip code from the session link (`roadsong.app/t/<code>`), used to
  /// build the shareable memorial link. Null for demo trips.
  final String? tripCode;

  /// The audio seam for vibe auditions and song playback. Tests inject a
  /// fake so CI never touches a real codec; production defaults to
  /// audioplayers-backed playback.
  final AudioSeam? audioSeam;

  /// Invoked by the empty-trip prompt so the user can add the first memory.
  /// When null the prompt is hidden and the tab only explains what is needed.
  final VoidCallback? onAddMemory;

  const SongTab({
    Key? key,
    required this.tripName,
    required this.memories,
    required this.participants,
    this.store,
    this.tripId,
    this.tripCode,
    this.audioSeam,
    this.onAddMemory,
  }) : super(key: key);

  @override
  _SongTabState createState() => _SongTabState();
}

enum _SongStage {
  start,
  empty,
  reading,
  lyrics,
  sound,
  making,
  ready,
  player,
  memorial,
}

class _SongTabState extends State<SongTab> {
  static const LyricistEngine _lyricist = TemplateLyricist();
  static const SongSynthEngine _synth = SimulatedSongSynth();
  static const TimelineAligner _aligner = DeterministicTimelineAligner();
  static const EvidenceCueEngine _cueEngine = KeywordEvidenceCueEngine();

  static const List<String> _readingMessages = [
    'Reading every note…',
    'Finding the funny bits…',
    'Rhyming the place names…',
    'Saving the quiet moments for the bridge…',
  ];
  static const Duration _readingDuration = Duration(milliseconds: 3200);
  static const Duration _messageInterval = Duration(milliseconds: 800);
  static const Duration _rewriteDuration = Duration(milliseconds: 950);
  static const Duration _typingDuration = Duration(milliseconds: 1100);

  _SongStage _stage = _SongStage.start;
  LyricSong? _song;

  /// Whether the current draft has been persisted through the store seam
  /// (issue #31): flips true after a save so the lyrics stage can show a
  /// visible "saved" status — edits and rewrites survive restarts and the
  /// user can see that they did.
  bool _draftSaved = false;
  // Choose Sound picker / result.
  MusicalStyle? _style;
  int _bpm = 0;
  SongTimeline? _timeline;
  // The audio seam: production plays bundled MP3s; tests inject a fake.
  late final AudioSeam _audio = widget.audioSeam ?? AudioplayersAudioSeam();

  @override
  void initState() {
    super.initState();
    // A persisted draft (created trips) resumes exactly where the user left
    // it: edits and rewrites survive screen changes and app restarts.
    final LyricSong? saved = widget.store?.songFor(widget.tripId ?? '');
    if (saved != null) {
      _song = saved;
      _draftSaved = true;
      _stage = _SongStage.lyrics;
    }
    // A finished-memorial artifact resumes the unlocked song: the vibe is
    // pre-selected and the Making Song pass is already complete, so the
    // user lands on the ready stage (lyrics stay one tap away).
    final SongArtifact? artifact = widget.store?.songArtifactFor(
      widget.tripId ?? '',
    );
    if (artifact != null) {
      _style = artifact.style;
      _bpm = artifact.bpm;
      if (_song != null) {
        _stage = _SongStage.ready;
        _resumeTimeline();
      }
    }
  }

  /// Rebuilds the alignment timeline after a restart so the ready screen and
  /// the kinetic player work without re-running the Making Song pass. The
  /// memorial is re-published to the backend so visitors keep access after
  /// the app restarts.
  Future<void> _resumeTimeline() async {
    if (_song == null || _style == null) return;
    final SongTimeline timeline = await _alignTimeline(_song!, _style!, _bpm);
    if (!mounted) return;
    setState(() => _timeline = timeline);
    await _publishMemorial(timeline);
  }

  @override
  void didUpdateWidget(SongTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The empty prompt sent the user to add memories; once the first memory
    // lands, offer the song again instead of staying stuck on the prompt.
    if (_stage == _SongStage.empty &&
        oldWidget.memories.isEmpty &&
        widget.memories.isNotEmpty) {
      setState(() => _stage = _SongStage.start);
    }
  }

  // Reading pass.
  int _readingTick = 0;
  Timer? _rotationTimer;
  Timer? _readingTimer;
  // Making-song pass: the current stage index and the timer that advances it.
  int _makingStageIndex = 0;
  Timer? _makingTimer;

  // Section rewriting / editing.
  String? _busyId;
  String? _editingId;
  final TextEditingController _editController = TextEditingController();
  Timer? _busyTimer;

  // Conversational refinement chat.
  final List<ChatMessage> _chat = [];
  final TextEditingController _chatController = TextEditingController();
  bool _aiTyping = false;
  Timer? _typingTimer;

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _readingTimer?.cancel();
    _busyTimer?.cancel();
    _makingTimer?.cancel();
    _typingTimer?.cancel();
    _editController.dispose();
    _chatController.dispose();
    // Release the audio player so no audition keeps playing after the tab
    // is left. The seam is only disposed when this state owns it.
    if (widget.audioSeam == null) {
      final AudioSeam audio = _audio;
      if (audio is AudioplayersAudioSeam) audio.dispose();
    }
    super.dispose();
  }

  int get _memoryCount => widget.memories.length;

  String get _memoryCountLine {
    final int count = _memoryCount;
    return 'written from your $count ${count == 1 ? 'memory' : 'memories'}';
  }

  Future<void> _startSong() async {
    // A trip with no memories has nothing to sing about: prompt to add
    // memories instead of generating placeholder nonsense.
    if (widget.memories.isEmpty) {
      setState(() => _stage = _SongStage.empty);
      return;
    }
    await _compose();
  }

  /// Runs the reading pass and drafts a fresh song from the latest memories.
  /// Used by the first "Write our song" action and by regeneration, so a
  /// draft always reflects the newest content.
  Future<void> _compose() async {
    setState(() {
      _stage = _SongStage.reading;
      _readingTick = 0;
    });
    _rotationTimer = Timer.periodic(_messageInterval, (_) {
      if (mounted) setState(() => _readingTick++);
    });
    _readingTimer = Timer(_readingDuration, () async {
      _rotationTimer?.cancel();
      final LyricSong song = await _lyricist.composeSong(
        tripName: widget.tripName,
        participants: widget.participants,
        memories: widget.memories,
      );
      if (!mounted) return;
      setState(() {
        _song = song;
        _stage = _SongStage.lyrics;
      });
      await _persistSong(song);
    });
  }

  /// Re-drafts the whole song from the latest memories, replacing the current
  /// draft (and its persisted copy) so regeneration reflects new content.
  Future<void> _regenerate() async {
    if (_busyId != null || _song == null) return;
    await _compose();
  }

  /// Saves the current draft through the store seam so edits and rewrites
  /// survive restarts. Demo trips (no store) keep the draft in local state.
  Future<void> _persistSong(LyricSong song) async {
    final TripStore? store = widget.store;
    final String? tripId = widget.tripId;
    if (store == null || tripId == null) return;
    await store.saveSong(tripId, song);
    if (mounted) setState(() => _draftSaved = true);
  }

  void _pickStyle(MusicalStyle style) {
    setState(() {
      _style = style;
      _bpm = style.defaultBpm;
    });
    // Audition the vibe through the audio seam: each vibe plays its own
    // bundled track, so the choice is informed before committing.
    _audio.prime(style.audioAsset);
    _audio.start();
  }

  /// Runs the staged Making Song pass: each stage shows in order with
  /// credible timing, the vibe's audio is primed during the pass (so the
  /// audible start on web can derive from a later tap), and the song is
  /// unlocked when the pass completes.
  Future<void> _makeSong() async {
    if (_style == null || _song == null) return;
    setState(() {
      _stage = _SongStage.making;
      _makingStageIndex = 0;
    });
    // Prime the chosen vibe's audio while the pass runs: loading is allowed
    // anytime and makes no sound; the audible start is gated on a tap.
    _audio.prime(_style!.audioAsset);
    _advanceMakingStage();
  }

  /// Advances the Making Song pass one stage at a time, persisting the
  /// artifact (with its stage state) after each step so an interrupted pass
  /// resumes where it left off. The final step unlocks the song.
  void _advanceMakingStage() {
    final int stageIndex = _makingStageIndex;
    if (stageIndex >= MakingSongStage.stages.length) return;
    _makingTimer = Timer(MakingSongStage.stageDurations[stageIndex], () async {
      if (!mounted) return;
      final int next = stageIndex + 1;
      setState(() => _makingStageIndex = next);
      await _persistArtifact(next);
      if (next >= MakingSongStage.stages.length) {
        final SongTimeline timeline = await _alignTimeline(
          _song!,
          _style!,
          _bpm,
        );
        if (!mounted) return;
        setState(() {
          _timeline = timeline;
          _stage = _SongStage.ready;
        });
        await _publishMemorial(timeline);
      } else {
        _advanceMakingStage();
      }
    });
  }

  /// Publishes the finished memorial to the backend when the trip is
  /// remote-backed, so visitors can listen and browse through the trip link.
  /// Local trips (in-memory / preferences) keep the memorial in-app only.
  Future<void> _publishMemorial(SongTimeline timeline) async {
    final TripStore? store = widget.store;
    final String? tripId = widget.tripId;
    if (store is! RemoteTripStore || tripId == null || _song == null) return;
    final List<String> lyrics = <String>[
      for (final LyricSection section in _song!.sections) ...section.lines,
    ];
    await store.publishMemorialSong(
      tripId,
      timeline.toMemorialSong(audioAsset: _style!.audioAsset, lyrics: lyrics),
    );
  }

  /// Persists the song artifact (vibe, audio asset, stage state) through the
  /// store seam so the unlocked song and in-progress passes survive
  /// restarts. Demo trips (no store) keep the artifact in local state.
  Future<void> _persistArtifact(int stageIndex) async {
    final TripStore? store = widget.store;
    final String? tripId = widget.tripId;
    if (store == null || tripId == null || _style == null) return;
    final SongArtifact artifact = SongArtifact(
      styleId: _style!.id,
      audioAsset: _style!.audioAsset,
      bpm: _bpm,
      stageIndex: stageIndex,
    );
    await store.saveSongArtifact(tripId, artifact);
  }

  /// Runs the full synthesis pipeline: vocal take, forced alignment against
  /// it, and the evidence cues mapped from the trip memories.
  Future<SongTimeline> _alignTimeline(
    LyricSong song,
    MusicalStyle style,
    int bpm,
  ) async {
    final SynthResult audio = await _synth.synthesize(
      song: song,
      style: style,
      bpm: bpm,
    );
    final SongTimeline timeline = await _aligner.align(
      song: song,
      style: style,
      bpm: bpm,
      audio: audio,
    );
    final List<EvidenceCue> cues = await _cueEngine.cues(
      timeline: timeline,
      memories: widget.memories,
    );
    return timeline.withCues(cues);
  }

  Future<void> _rewrite(String sectionId) async {
    if (_busyId != null || _song == null) return;
    final LyricSection? section = _song!.section(sectionId);
    if (section == null) return;
    setState(() {
      _busyId = sectionId;
      _editingId = null;
    });
    _busyTimer = Timer(_rewriteDuration, () async {
      final LyricSection rewritten = await _lyricist.rewriteSection(section);
      if (!mounted) return;
      final LyricSong updated = _song!.withSection(rewritten.id, rewritten);
      setState(() {
        _busyId = null;
        _song = updated;
      });
      await _persistSong(updated);
    });
  }

  void _edit(String sectionId) {
    if (_busyId != null || _song == null) return;
    final LyricSection? section = _song!.section(sectionId);
    if (section == null) return;
    setState(() {
      _editingId = sectionId;
      _editController.text = section.lines.join('\n');
    });
  }

  void _saveEdit() {
    if (_editingId == null || _song == null) return;
    final String id = _editingId!;
    final LyricSection? section = _song!.section(id);
    final List<String> lines = _editController.text
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    LyricSong? updated;
    setState(() {
      if (section != null && lines.isNotEmpty) {
        final List<List<String>> variants = [
          for (int i = 0; i < section.variants.length; i++)
            i == section.variantIndex ? lines : section.variants[i],
        ];
        updated = _song!.withSection(id, section.copyWith(variants: variants));
        _song = updated;
      }
      _editingId = null;
    });
    final LyricSong? saved = updated;
    if (saved != null) _persistSong(saved);
  }

  void _cancelEdit() => setState(() => _editingId = null);

  Future<void> _sendChat() async {
    final String text = _chatController.text.trim();
    if (text.isEmpty || _aiTyping || _song == null) return;
    setState(() {
      _chat.add(ChatMessage(fromMe: true, text: text));
      _chatController.clear();
      _aiTyping = true;
    });
    _typingTimer = Timer(_typingDuration, () async {
      final LyricistReply reply = await _lyricist.respondToFeedback(
        feedback: text,
        song: _song!,
      );
      if (!mounted) return;
      setState(() {
        _aiTyping = false;
        _chat.add(ChatMessage(fromMe: false, text: reply.reply));
        _song = reply.song;
      });
      await _persistSong(reply.song);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: switch (_stage) {
            _SongStage.start => _buildStart(),
            _SongStage.empty => _buildEmpty(),
            _SongStage.reading => _buildReading(),
            _SongStage.lyrics => _buildLyrics(),
            _SongStage.sound => _buildSound(),
            _SongStage.making => _buildMaking(),
            _SongStage.ready => _buildReady(),
            _SongStage.player => KineticPlayer(
              timeline: _timeline!,
              memories: widget.memories,
              audioSeam: _audio,
              autoPlay: true,
              onClose: () => setState(() => _stage = _SongStage.ready),
              onShare: () => setState(() => _stage = _SongStage.memorial),
            ),
            _SongStage.memorial => MemorialReadyScreen(
              tripName: widget.tripName,
              tripCode: widget.tripCode,
              timeline: _timeline!,
              onBack: () => setState(() => _stage = _SongStage.ready),
              onWatch: () => setState(() => _stage = _SongStage.player),
            ),
          },
        ),
        if (_stage == _SongStage.lyrics) _buildChatBar(),
      ],
    );
  }

  // ── Song Start ────────────────────────────────────────────────────────────

  Widget _buildStart() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 30),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: -6 * 3.14159 / 180,
                    child: Text(
                      '♪',
                      style: GoogleFonts.karla(
                        fontSize: 44,
                        color: BrutalTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Turn your trip\ninto a song',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.instrumentSerif(
                      fontSize: 32,
                      height: 1.15,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _memoryCountLine,
                    style: GoogleFonts.caveat(
                      fontSize: 20,
                      color: BrutalTheme.graphite,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 270),
                    child: Text(
                      "We'll read every note and photo caption, find the funny "
                      "bits and the quiet ones, and draft lyrics you can edit "
                      'line by line.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.karla(
                        fontSize: 14,
                        height: 1.6,
                        color: const Color(0xFF6E5F4A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: BrutalButton(
              onPressed: _startSong,
              child: Text('Write our song', style: BrutalTheme.ctaLabelStyle()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty trip ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 30),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: -6 * 3.14159 / 180,
                    child: Text(
                      '♪',
                      style: GoogleFonts.karla(
                        fontSize: 44,
                        color: BrutalTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No memories yet',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.instrumentSerif(
                      fontSize: 30,
                      height: 1.15,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A song needs your trip\'s moments — add a memory '
                    'first, then come back and we\'ll write it together.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.karla(
                      fontSize: 14,
                      height: 1.6,
                      color: const Color(0xFF6E5F4A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: BrutalButton(
              key: const ValueKey('empty-add-memory'),
              onPressed: widget.onAddMemory,
              child: Text('Add a memory', style: BrutalTheme.ctaLabelStyle()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reading Memories ──────────────────────────────────────────────────────

  Widget _buildReading() {
    final int messageIndex = _readingTick % _readingMessages.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBeatDots(_readingTick),
            const SizedBox(height: 22),
            Text(
              _readingMessages[messageIndex],
              textAlign: TextAlign.center,
              style: GoogleFonts.caveat(
                fontSize: 27,
                color: BrutalTheme.inkBlack,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'READING $_memoryCount MEMORIES',
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                letterSpacing: 1.4,
                color: const Color(0xFFB3A488),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lyrics ────────────────────────────────────────────────────────────────

  Widget _buildLyrics() {
    final LyricSong song = _song!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        song.title,
                        style: GoogleFonts.instrumentSerif(
                          fontSize: 30,
                          color: BrutalTheme.inkBlack,
                        ),
                      ),
                    ),
                    _buildSectionChip(
                      key: const ValueKey('regenerate-song'),
                      label: '↻ regenerate',
                      onTap: _regenerate,
                    ),
                  ],
                ),
                Text(
                  _draftSaved
                      ? 'draft 1 · $_memoryCountLine · saved ✓'
                      : 'draft 1 · $_memoryCountLine',
                  style: GoogleFonts.caveat(
                    fontSize: 18,
                    color: BrutalTheme.graphite,
                  ),
                ),
              ],
            ),
          ),
          for (final LyricSection section in song.sections)
            _buildSectionCard(section),
          if (_chat.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final ChatMessage message in _chat) _buildChatBubble(message),
          ],
          if (_aiTyping)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE5CF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '•••',
                  style: GoogleFonts.karla(
                    fontSize: 13.5,
                    letterSpacing: 2,
                    color: BrutalTheme.graphite,
                  ),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            width: double.infinity,
            child: BrutalButton(
              key: const ValueKey('choose-sound'),
              onPressed: () => setState(() => _stage = _SongStage.sound),
              child: Text(
                'The words are right — choose the sound →',
                style: BrutalTheme.ctaLabelStyle(fontSize: 15.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(LyricSection section) {
    final bool busy = _busyId == section.id;
    final bool editing = _editingId == section.id;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
      decoration: BoxDecoration(
        color: BrutalTheme.card,
        border: Border.all(color: const Color(0xFFEBDFC6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  section.label,
                  style: GoogleFonts.caveat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: BrutalTheme.primary,
                  ),
                ),
              ),
              _buildSectionChip(
                key: ValueKey('rewrite-${section.id}'),
                label: '↻ rewrite',
                onTap: () => _rewrite(section.id),
              ),
              const SizedBox(width: 8),
              _buildSectionChip(
                key: ValueKey('edit-${section.id}'),
                label: '✎ edit',
                onTap: () => _edit(section.id),
              ),
            ],
          ),
          if (busy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'rewriting this part…',
                style: GoogleFonts.karla(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFFB3A488),
                ),
              ),
            )
          else if (editing) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: BrutalTheme.paper,
                border: Border.all(color: const Color(0xFFDCCDAC)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                key: const ValueKey('edit-field'),
                controller: _editController,
                maxLines: null,
                minLines: 4,
                style: GoogleFonts.instrumentSerif(
                  fontSize: 16,
                  height: 1.55,
                  color: BrutalTheme.inkBlack,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPillButton(
                  key: const ValueKey('save-edit'),
                  label: 'Save',
                  background: BrutalTheme.inkBlack,
                  foreground: const Color(0xFFFFF8EC),
                  onTap: _saveEdit,
                ),
                const SizedBox(width: 8),
                _buildPillButton(
                  key: const ValueKey('cancel-edit'),
                  label: 'Cancel',
                  background: Colors.transparent,
                  foreground: BrutalTheme.graphite,
                  onTap: _cancelEdit,
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (final String line in section.lines)
              Text(
                line,
                style: GoogleFonts.instrumentSerif(
                  fontSize: 17.5,
                  height: 1.62,
                  color: BrutalTheme.inkBlack,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionChip({
    required Key key,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDCCDAC)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 10.5,
            color: BrutalTheme.graphite,
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required Key key,
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: const Color(0xFFDCCDAC)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.karla(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: foreground,
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final bool fromMe = message.fromMe;
    return Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: fromMe ? BrutalTheme.inkBlack : const Color(0xFFEFE5CF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.karla(
            fontSize: 13.5,
            height: 1.45,
            color: fromMe ? const Color(0xFFFFF8EC) : const Color(0xFF57493A),
          ),
        ),
      ),
    );
  }

  Widget _buildChatBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: BrutalTheme.paper2,
        border: Border(top: BorderSide(color: Color(0xFFE7DBC0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: BrutalTheme.card,
                border: Border.all(color: const Color(0xFFE1D4B6)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                key: const ValueKey('chat-input'),
                controller: _chatController,
                onSubmitted: (_) => _sendChat(),
                style: GoogleFonts.karla(
                  fontSize: 13.5,
                  color: BrutalTheme.inkBlack,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  hintText: 'Ask for changes — "make the chorus funnier"',
                  hintStyle: GoogleFonts.karla(
                    fontSize: 13.5,
                    color: BrutalTheme.graphite.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: const ValueKey('chat-send'),
            onTap: _sendChat,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: BrutalTheme.inkBlack,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '↑',
                style: GoogleFonts.karla(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFF8EC),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Choose Sound: vibe & tempo picker ─────────────────────────────────────

  Widget _buildSound() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How should it sound?',
              style: GoogleFonts.instrumentSerif(
                fontSize: 28,
                color: BrutalTheme.inkBlack,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'pick the vibe, set the tempo',
              style: GoogleFonts.caveat(
                fontSize: 19,
                color: BrutalTheme.graphite,
              ),
            ),
            const SizedBox(height: 16),
            for (final MusicalStyle style in MusicalStyle.catalog)
              _buildStyleCard(style),
            if (_style != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Tempo',
                    style: GoogleFonts.caveat(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: BrutalTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_bpm BPM',
                    style: GoogleFonts.spaceMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                ],
              ),
              Slider(
                key: const ValueKey('tempo-slider'),
                value: _bpm.toDouble(),
                min: _style!.minBpm.toDouble(),
                max: _style!.maxBpm.toDouble(),
                divisions: _style!.maxBpm - _style!.minBpm,
                activeColor: BrutalTheme.primary,
                onChanged: (double value) =>
                    setState(() => _bpm = value.round()),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: BrutalButton(
                  key: const ValueKey('audition-vibe'),
                  color: const Color(0xFF5A4938),
                  onPressed: () {
                    _audio.prime(_style!.audioAsset);
                    _audio.start();
                  },
                  child: Text(
                    '♪ Play the ${_style!.label} preview',
                    style: BrutalTheme.ctaLabelStyle(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: BrutalButton(
                key: const ValueKey('make-song'),
                onPressed: _style == null ? null : _makeSong,
                child: Text(
                  'Sounds right — make our song →',
                  style: _style == null
                      ? BrutalTheme.ctaLabelStyle(color: BrutalTheme.graphite)
                      : BrutalTheme.ctaLabelStyle(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: _backToLyrics()),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleCard(MusicalStyle style) {
    final bool selected = _style?.id == style.id;
    return GestureDetector(
      key: ValueKey('style-card-${style.id}'),
      onTap: () => _pickStyle(style),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF8EC) : BrutalTheme.card,
          border: Border.all(
            color: selected ? BrutalTheme.primary : const Color(0xFFEBDFC6),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    style.label,
                    style: GoogleFonts.instrumentSerif(
                      fontSize: 20,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                ),
                if (selected)
                  Text(
                    '♪ SELECTED',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: BrutalTheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              style.tagline,
              style: GoogleFonts.karla(
                fontSize: 13.5,
                height: 1.4,
                color: const Color(0xFF6E5F4A),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  '${style.minBpm}–${style.maxBpm} BPM',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10.5,
                    color: BrutalTheme.graphite,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    style.mood,
                    style: GoogleFonts.caveat(
                      fontSize: 15,
                      color: BrutalTheme.graphite,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Making-song pass ───────────────────────────────────────────────────────

  Widget _buildBeatDots(int tick) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            decoration: BoxDecoration(
              color: BrutalTheme.primary.withValues(
                alpha: tick % 3 == i ? 1 : 0.25,
              ),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  Widget _buildMaking() {
    final int stageIndex = _makingStageIndex.clamp(
      0,
      MakingSongStage.stages.length - 1,
    );
    final MakingSongStage current = MakingSongStage.stages[stageIndex];
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBeatDots(stageIndex),
            const SizedBox(height: 22),
            Text(
              current.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.caveat(
                fontSize: 27,
                color: BrutalTheme.inkBlack,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'MAKING ${_style!.label.toUpperCase()} AT $_bpm BPM',
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                letterSpacing: 1.4,
                color: const Color(0xFFB3A488),
              ),
            ),
            const SizedBox(height: 20),
            for (int i = 0; i < MakingSongStage.stages.length; i++)
              _buildStageRow(i, stageIndex),
          ],
        ),
      ),
    );
  }

  /// One row of the Making Song stage list: done stages are checked, the
  /// current stage pulses, upcoming stages stay muted.
  Widget _buildStageRow(int index, int currentIndex) {
    final MakingSongStage stage = MakingSongStage.stages[index];
    final bool done = index < currentIndex;
    final bool current = index == currentIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: done
                  ? BrutalTheme.primary
                  : current
                  ? BrutalTheme.card
                  : Colors.transparent,
              border: Border.all(
                color: done
                    ? BrutalTheme.primary
                    : current
                    ? BrutalTheme.primary
                    : const Color(0xFFDCCDAC),
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: done
                ? Text(
                    '✓',
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFF8EC),
                    ),
                  )
                : current
                ? Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: BrutalTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            stage.label,
            style: GoogleFonts.karla(
              fontSize: 14,
              fontWeight: current ? FontWeight.bold : FontWeight.w400,
              color: done || current
                  ? BrutalTheme.inkBlack
                  : const Color(0xFFB3A488),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ready ─────────────────────────────────────────────────────────────────

  Widget _buildReady() {
    final SongTimeline? timeline = _timeline;
    // After a restart the timeline is rebuilt in the background; show a
    // brief loading state instead of a blank screen.
    if (timeline == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Loading your song…',
            style: TextStyle(color: Color(0xFF8D7C63)),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your song is ready!',
              style: GoogleFonts.instrumentSerif(
                fontSize: 28,
                color: BrutalTheme.inkBlack,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'mastered at $_bpm BPM · ${_style!.label}',
              style: GoogleFonts.caveat(
                fontSize: 19,
                color: BrutalTheme.graphite,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 9),
              decoration: BoxDecoration(
                color: BrutalTheme.card,
                border: Border.all(color: const Color(0xFFEBDFC6)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatRow(
                    'Runtime',
                    _formatDuration(timeline.durationMs),
                  ),
                  _buildStatRow('Sections', '${timeline.sections.length}'),
                  _buildStatRow('Words aligned', '${timeline.wordCount}'),
                  _buildStatRow(
                    'Downbeats',
                    '${timeline.downbeat.downbeatTimes.length}',
                  ),
                  _buildStatRow('Evidence cues', '${timeline.cues.length}'),
                ],
              ),
            ),
            if (timeline.cues.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Pop-up moments',
                style: GoogleFonts.caveat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: BrutalTheme.primary,
                ),
              ),
              for (final EvidenceCue cue in timeline.cues.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_formatDuration(cue.timeMs)} — ${cue.label}',
                    style: GoogleFonts.karla(
                      fontSize: 13.5,
                      color: const Color(0xFF57493A),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: BrutalButton(
                key: const ValueKey('play-song'),
                onPressed: () {
                  // The audible start derives from this tap: the source was
                  // primed during the Making Song pass, so the gesture is
                  // gesture-proximate on web (iOS Safari otherwise blocks it).
                  _audio.prime(_style!.audioAsset);
                  _audio.start();
                  setState(() => _stage = _SongStage.player);
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
                      'Play the memorial',
                      style: BrutalTheme.ctaLabelStyle(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: BrutalButton(
                key: const ValueKey('share-memorial-link'),
                color: BrutalTheme.primary,
                onPressed: () => setState(() => _stage = _SongStage.memorial),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.ios_share, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Your memorial is ready — share it',
                      style: BrutalTheme.ctaLabelStyle(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: BrutalButton(
                key: const ValueKey('remix-song'),
                color: const Color(0xFF5A4938),
                onPressed: () => setState(() => _stage = _SongStage.sound),
                child: Text(
                  'Try another vibe',
                  style: BrutalTheme.ctaLabelStyle(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: _backToLyrics()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.karla(
              fontSize: 13.5,
              color: const Color(0xFF6E5F4A),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: BrutalTheme.inkBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _backToLyrics() {
    return GestureDetector(
      key: const ValueKey('sound-back'),
      onTap: () => setState(() => _stage = _SongStage.lyrics),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDCCDAC)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '← Back to the lyrics',
          style: GoogleFonts.karla(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: BrutalTheme.graphite,
          ),
        ),
      ),
    );
  }

  String _formatDuration(int ms) {
    final int seconds = ms ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
