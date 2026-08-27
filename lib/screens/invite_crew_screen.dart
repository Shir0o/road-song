import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/trip_models.dart';
import '../services/session_ingestion_service.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';
import '../widgets/qr_code_view.dart';

/// Default friend list shown on the invite screen.
const List<CrewMember> kDefaultCrew = [
  CrewMember(
    id: 'maya',
    name: 'Maya Chen',
    handle: '@maya',
    initial: 'M',
    color: Color(0xFF7D8663),
    invited: true,
  ),
  CrewMember(
    id: 'tom',
    name: 'Tom Alvarez',
    handle: '@tomtom',
    initial: 'T',
    color: Color(0xFFB08A3E),
    invited: true,
  ),
  CrewMember(
    id: 'priya',
    name: 'Priya Nair',
    handle: '@priya.n',
    initial: 'P',
    color: Color(0xFF3E6B8A),
    invited: true,
  ),
  CrewMember(
    id: 'sam',
    name: 'Sam Okafor',
    handle: '@samo',
    initial: 'S',
    color: Color(0xFFA5586B),
    invited: false,
  ),
];

/// Screen for inviting crew via a friend checklist and a tokenized
/// session link with QR code preview.
class InviteCrewScreen extends StatefulWidget {
  final VoidCallback onBack;
  final TripDraft draft;
  final List<CrewMember> initialCrew;
  final void Function(TripDraft draft, List<CrewMember> crew) onOpenDiary;

  const InviteCrewScreen({
    Key? key,
    required this.onBack,
    required this.draft,
    required this.onOpenDiary,
    this.initialCrew = kDefaultCrew,
  }) : super(key: key);

  @override
  _InviteCrewScreenState createState() => _InviteCrewScreenState();
}

class _InviteCrewScreenState extends State<InviteCrewScreen> {
  static const SessionIngestionService _service = SessionIngestionService();

  late List<CrewMember> _crew;
  bool _copied = false;
  Timer? _copyResetTimer;

  @override
  void initState() {
    super.initState();
    _crew = List<CrewMember>.from(widget.initialCrew);
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  String get _sessionLink => _service.buildSessionLink(widget.draft.name);

  void _toggle(CrewMember member) {
    setState(() {
      _crew = _crew
          .map((m) => m.id == member.id ? m.copyWith(invited: !m.invited) : m)
          .toList();
    });
  }

  void _copyLink() {
    _copyResetTimer?.cancel();
    setState(() => _copied = true);
    _copyResetTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  void _showGuestDropSheet() {
    final invited = _crew.where((m) => m.invited).toList();
    final author = invited.isEmpty ? '@you' : invited.first.handle;
    final TextEditingController textController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: BrutalCard(
            color: BrutalTheme.card,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DymoLabel(text: 'DROP A MEMORY', fontSize: 16),
                const SizedBox(height: 12),
                Text(
                  'Guest drops land in the shared trip pool with their capture time preserved.',
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    color: BrutalTheme.graphite,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 3,
                  style: GoogleFonts.karla(color: BrutalTheme.inkBlack),
                  decoration: InputDecoration(
                    hintText: 'Write a quote, joke, or note…',
                    border: InputBorder.none,
                    filled: true,
                    fillColor: BrutalTheme.backgroundLight,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: BrutalButton(
                        color: BrutalTheme.yellow,
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(
                          'CANCEL',
                          style: GoogleFonts.karla(
                            fontWeight: FontWeight.bold,
                            color: BrutalTheme.inkBlack,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BrutalButton(
                        onPressed: () {
                          final drop = _service.createTextDrop(
                            author: author,
                            text: textController.text.trim(),
                          );
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: BrutalTheme.primary,
                              content: Text(
                                '${drop.author} dropped: ${drop.content}',
                                style: GoogleFonts.karla(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'DROP',
                          style: GoogleFonts.spaceMono(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 46),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Text(
                  '← Back',
                  style: GoogleFonts.karla(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: BrutalTheme.graphite,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Who was on the trip?',
                style: GoogleFonts.instrumentSerif(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: BrutalTheme.inkBlack,
                ),
              ),
              Transform.rotate(
                angle: -2 * 3.14159 / 180,
                child: Text(
                  'everyone adds their own memories',
                  style: GoogleFonts.caveat(
                    fontSize: 20,
                    color: BrutalTheme.graphite,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final member in _crew) _buildFriendTile(member),
                      const SizedBox(height: 18),
                      _buildShareLink(),
                      const SizedBox(height: 12),
                      _buildQrPreview(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: BrutalButton(
                          color: BrutalTheme.yellow,
                          onPressed: _showGuestDropSheet,
                          child: Text(
                            'DROP A MEMORY',
                            style: GoogleFonts.spaceMono(
                              fontWeight: FontWeight.bold,
                              color: BrutalTheme.inkBlack,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: BrutalButton(
                  onPressed: () => widget.onOpenDiary(widget.draft, _crew),
                  child: Text(
                    'OPEN THE DIARY →',
                    style: GoogleFonts.spaceMono(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendTile(CrewMember member) {
    final bool isInvited = member.invited;
    return GestureDetector(
      onTap: () => _toggle(member),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BrutalTheme.brutalDecoration(
          color: BrutalTheme.card,
          borderWidth: 1.0,
          borderColor: isInvited
              ? BrutalTheme.primary
              : const Color(0xFFEBDFC6),
          showShadow: false,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: member.color,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                member.initial,
                style: GoogleFonts.karla(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: GoogleFonts.karla(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  Text(
                    member.handle,
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      color: BrutalTheme.graphite,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isInvited ? BrutalTheme.primary : Colors.transparent,
                border: Border.all(
                  color: isInvited
                      ? BrutalTheme.primary
                      : const Color(0xFFCBBB97),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isInvited
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareLink() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBBB97), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OR SHARE THE LINK',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                    color: BrutalTheme.graphite,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _sessionLink,
                  style: GoogleFonts.spaceMono(
                    fontSize: 12.5,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _copyLink,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: BrutalTheme.inkBlack,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                _copied ? 'Copied ✓' : 'Copy',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
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

  Widget _buildQrPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BrutalTheme.brutalDecoration(
        color: BrutalTheme.card,
        borderWidth: 1.0,
        showShadow: false,
      ),
      child: Column(
        children: [
          Text(
            'SCAN TO JOIN',
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
              color: BrutalTheme.graphite,
            ),
          ),
          const SizedBox(height: 10),
          QrCodeView(
            data: _sessionLink,
            size: 84,
            darkColor: BrutalTheme.inkBlack,
            lightColor: BrutalTheme.card,
          ),
          const SizedBox(height: 6),
          Text(
            'QR code preview',
            style: GoogleFonts.karla(fontSize: 11, color: BrutalTheme.graphite),
          ),
        ],
      ),
    );
  }
}
