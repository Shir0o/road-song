import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../engines/lyricist_engine.dart';
import '../models/song_models.dart';
import '../models/trip_models.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';

/// The Song tab: the songwriting stages of the zip flow — Song Start
/// ("Write our song"), the Reading progress pass, and the modular lyrics view
/// with per-section rewrite/edit and the conversational refinement chat.
/// The Choose Sound stage is next in the flow and appears as a stub.
class SongTab extends StatefulWidget {
  final String tripName;
  final List<TimelineMemory> memories;
  final List<String> participants;

  const SongTab({
    Key? key,
    required this.tripName,
    required this.memories,
    required this.participants,
  }) : super(key: key);

  @override
  _SongTabState createState() => _SongTabState();
}

enum _SongStage { start, reading, lyrics, soundStub }

class _SongTabState extends State<SongTab> {
  static const TemplateLyricist _lyricist = TemplateLyricist();

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

  // Reading pass.
  int _readingTick = 0;
  Timer? _rotationTimer;
  Timer? _readingTimer;

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
    _typingTimer?.cancel();
    _editController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  int get _memoryCount => widget.memories.length;

  String get _memoryCountLine {
    final int count = _memoryCount;
    return 'written from your $count ${count == 1 ? 'memory' : 'memories'}';
  }

  Future<void> _startSong() async {
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
    });
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
      setState(() {
        _busyId = null;
        _song = _replaceSection(rewritten);
      });
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
    setState(() {
      if (section != null && lines.isNotEmpty) {
        final List<List<String>> variants = [
          for (int i = 0; i < section.variants.length; i++)
            i == section.variantIndex ? lines : section.variants[i],
        ];
        _song = _replaceSection(section.copyWith(variants: variants));
      }
      _editingId = null;
    });
  }

  void _cancelEdit() => setState(() => _editingId = null);

  LyricSong _replaceSection(LyricSection updated) => _song!.copyWith(
    sections: [
      for (final LyricSection s in _song!.sections)
        s.id == updated.id ? updated : s,
    ],
  );

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: switch (_stage) {
            _SongStage.start => _buildStart(),
            _SongStage.reading => _buildReading(),
            _SongStage.lyrics => _buildLyrics(),
            _SongStage.soundStub => _buildSoundStub(),
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

  // ── Reading Memories ──────────────────────────────────────────────────────

  Widget _buildReading() {
    final int messageIndex = _readingTick % _readingMessages.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 3; i++)
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    decoration: BoxDecoration(
                      color: BrutalTheme.primary.withValues(
                        alpha: _readingTick % 3 == i ? 1 : 0.25,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
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
                Text(
                  song.title,
                  style: GoogleFonts.instrumentSerif(
                    fontSize: 30,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
                Text(
                  'draft ${song.draftNumber} · $_memoryCountLine',
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
              onPressed: () => setState(() => _stage = _SongStage.soundStub),
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

  // ── Choose Sound stub ─────────────────────────────────────────────────────

  Widget _buildSoundStub() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How should it sound?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.instrumentSerif(
                      fontSize: 28,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'pick the vibe and preview the sound',
                    style: GoogleFonts.caveat(
                      fontSize: 19,
                      color: BrutalTheme.graphite,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDCCDAC)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'COMING SOON',
                      style: GoogleFonts.spaceMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: BrutalTheme.graphite,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Vibe picker, preview and the making-song pass are the '
                    'next stages on the way.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.karla(
                      fontSize: 14,
                      height: 1.55,
                      color: const Color(0xFF6E5F4A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('stub-back'),
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
          ),
        ],
      ),
    );
  }
}
