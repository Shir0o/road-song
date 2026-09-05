import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/trip_models.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';
import 'add_memory_sheet.dart';

const List<Color> _avatarPalette = [
  Color(0xFFC05B3E), // brick (theme primary)
  Color(0xFF7D8663), // sage
  Color(0xFFB08A3E), // tan
  Color(0xFF3E6B8A), // blue
  Color(0xFFA5586B), // plum
];

const List<Color> _photoWashPalette = [
  Color(0xFFE7D9BE),
  Color(0xFFEBD3C2),
  Color(0xFFDCE0D2),
  Color(0xFFCFDCE0),
  Color(0xFFE9D5B8),
];

const List<String> _monthAbbreviations = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

Color _authorColor(String author) {
  int hash = 0;
  for (final int code in author.codeUnits) {
    hash = (hash + code) % _avatarPalette.length;
  }
  return _avatarPalette[hash];
}

String _authorInitial(String author) {
  final String trimmed = author.trim();
  if (trimmed.isEmpty) return '?';
  final String first = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  return first.isEmpty ? '@' : first[0].toUpperCase();
}

String _formatClockTime(DateTime now) {
  final int hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final String minutes = now.minute.toString().padLeft(2, '0');
  return '$hour12:$minutes ${now.hour >= 12 ? 'PM' : 'AM'}';
}

/// Chronological, day-grouped diary feed of a trip's memories with tactile
/// polaroid photo cards, like reactions, the "make your song" banner and the
/// floating `+` memory composer.
class DiaryTab extends StatefulWidget {
  final String tripName;
  final String? tripDateRange;
  final List<TimelineMemory> memories;
  final ValueChanged<TimelineMemory> onAddMemory;
  final VoidCallback onOpenSong;
  final VoidCallback onSwitchTrip;
  final Future<Uint8List?> Function() pickPhotoBytes;

  const DiaryTab({
    Key? key,
    required this.tripName,
    this.tripDateRange,
    required this.memories,
    required this.onAddMemory,
    required this.onOpenSong,
    required this.onSwitchTrip,
    required this.pickPhotoBytes,
  }) : super(key: key);

  @override
  _DiaryTabState createState() => _DiaryTabState();
}

class _DiaryTabState extends State<DiaryTab> {
  /// +1 / -1 / 0 delta vs the memory's stored [TimelineMemory.likes].
  final Map<String, int> _likeDeltas = {};

  bool _isLiked(TimelineMemory memory) {
    final int delta = _likeDeltas[memory.id] ?? 0;
    if (delta == 1) return true;
    if (delta == -1) return false;
    return memory.likedByMe;
  }

  int _displayLikes(TimelineMemory memory) {
    return memory.likes + (_likeDeltas[memory.id] ?? 0);
  }

  void _toggleLike(TimelineMemory memory) {
    setState(() {
      final int delta = _likeDeltas[memory.id] ?? 0;
      final int next;
      if (memory.likedByMe) {
        next = delta == -1 ? 0 : -1;
      } else {
        next = delta == 1 ? 0 : 1;
      }
      _likeDeltas[memory.id] = next;
    });
  }

  int get _stopCount {
    final seen = <String>{};
    for (final memory in widget.memories) {
      if (memory.isPinned) seen.add(memory.locationName!);
    }
    return seen.length;
  }

  Future<void> _openComposer() async {
    final MemoryComposeResult? result = await showAddMemorySheet(
      context,
      memories: widget.memories,
      pickPhotoBytes: widget.pickPhotoBytes,
    );
    if (result == null || !mounted) return;

    final DateTime now = DateTime.now();
    final String todayLabel =
        '${_monthAbbreviations[now.month - 1]} ${now.day}';
    final int maxDay = widget.memories.isEmpty
        ? 0
        : widget.memories.map((m) => m.day).reduce(math.max);
    // Another composition made today joins the existing day group instead of
    // spawning a duplicate "day" labelled with the same date.
    final TimelineMemory? lastMemory =
        widget.memories.isEmpty ? null : widget.memories.last;
    final int day =
        (lastMemory != null && lastMemory.dayDate == todayLabel)
            ? lastMemory.day
            : maxDay + 1;
    widget.onAddMemory(
      TimelineMemory(
        id: 'mem-${now.microsecondsSinceEpoch}',
        author: '@you',
        time: _formatClockTime(now),
        text: result.note,
        day: day,
        dayDate: todayLabel,
        locationName: result.locationName,
        photoBytes: result.photoBytes,
        rotationDegrees: (math.Random().nextDouble() * 6) - 3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      body: GrainOverlay(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Expanded(
                  child: widget.memories.isEmpty
                      ? _buildEmptyState()
                      : _buildFeed(),
                ),
              ],
            ),
            Positioned(
              right: 18,
              bottom: 24,
              child: GestureDetector(
                key: const ValueKey('add-memory-fab'),
                onTap: _openComposer,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BrutalTheme.brutalDecoration(
                    color: BrutalTheme.primary,
                    borderRadius: BorderRadius.circular(28),
                    borderColor: BrutalTheme.primary,
                    shadowColor: const Color(0xBFC05B3E),
                    shadowOffset: const Offset(0, 10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final String? dateRange = widget.tripDateRange;
    final int stops = _stopCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tripName.toUpperCase(),
                  style: GoogleFonts.instrumentSerif(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (dateRange != null && dateRange.isNotEmpty) dateRange,
                    '$stops ${stops == 1 ? 'stop' : 'stops'}',
                  ].join(' · '),
                  style: GoogleFonts.karla(
                    fontSize: 12.5,
                    color: BrutalTheme.graphite,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            key: const ValueKey('switch-trip'),
            onTap: widget.onSwitchTrip,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Text(
                'SWITCH TRIP',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: BrutalTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    final Map<int, List<TimelineMemory>> groups = {};
    for (final memory in widget.memories) {
      groups.putIfAbsent(memory.day, () => []).add(memory);
    }
    final List<int> days = groups.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.only(bottom: 140),
      children: [
        for (final int day in days) ...[
          _buildDayHeader(day, groups[day]!),
          for (final memory in groups[day]!) _buildMemoryCard(memory),
        ],
        _buildSongBanner(widget.memories.length),
      ],
    );
  }

  Widget _buildDayHeader(int day, List<TimelineMemory> entries) {
    String? place;
    String? date;
    for (final memory in entries) {
      place ??= memory.isPinned ? memory.locationName : null;
      date ??= memory.dayDate;
    }
    final List<String> subParts = [
      if (place != null) place,
      if (date != null) date,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'Day $day',
            style: GoogleFonts.caveat(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: BrutalTheme.primary,
            ),
          ),
          if (subParts.isNotEmpty) ...[
            const SizedBox(width: 9),
            Text(
              subParts.join(' · ').toUpperCase(),
              style: GoogleFonts.spaceMono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: BrutalTheme.graphite,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemoryCard(TimelineMemory memory) {
    final bool liked = _isLiked(memory);
    final Color heartColor = liked ? BrutalTheme.primary : BrutalTheme.graphite;
    return Container(
      key: ValueKey('memory-${memory.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrutalTheme.card,
        border: Border.all(color: const Color(0xFFEBDFC6), width: 1),
        borderRadius: BorderRadius.circular(10),
        boxShadow: BrutalTheme.brutalShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: memory.authorColor ?? _authorColor(memory.author),
                ),
                child: Text(
                  _authorInitial(memory.author),
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.author,
                      style: GoogleFonts.karla(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: BrutalTheme.inkBlack,
                      ),
                    ),
                    Text(
                      memory.isPinned
                          ? '${memory.time} · ⚑ ${memory.locationName}'
                          : memory.time,
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        color: BrutalTheme.graphite,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                key: ValueKey('like-${memory.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggleLike(memory),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '♥',
                        style: GoogleFonts.karla(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: heartColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_displayLikes(memory)}',
                        key: ValueKey('like-count-${memory.id}'),
                        style: GoogleFonts.karla(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: heartColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            memory.text,
            style: GoogleFonts.karla(
              fontSize: 14.5,
              height: 1.55,
              color: BrutalTheme.inkBlack,
            ),
          ),
          if (memory.hasPhoto || memory.photoCaption != null)
            _buildPolaroid(memory),
        ],
      ),
    );
  }

  Widget _buildPolaroid(TimelineMemory memory) {
    final Color wash = memory.authorColor ?? _authorColor(memory.author);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 248),
          child: Transform.rotate(
            angle: memory.rotationDegrees * math.pi / 180,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFEF9),
                    border: Border.all(
                      color: const Color(0xFFEDE3CC),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66433729),
                        offset: Offset(0, 12),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(9, 9, 9, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 148,
                        child: _buildPhoto(memory, wash),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              memory.photoCaption ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.caveat(
                                fontSize: 16.5,
                                color: const Color(0xFF5D4F3C),
                              ),
                            ),
                          ),
                          if (memory.photoCaption != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              'hd photo',
                              style: GoogleFonts.spaceMono(
                                fontSize: 8.5,
                                color: const Color(0xFFBCAD8F),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -9,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Transform.rotate(
                      angle: -2 * math.pi / 180,
                      child: Container(
                        width: 60,
                        height: 17,
                        decoration: BoxDecoration(
                          color: const Color(0x99D6BE8C),
                          border: Border.all(
                            color: const Color(0x40B49B69),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto(TimelineMemory memory, Color wash) {
    final Uint8List? bytes = memory.photoBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover);
    }
    final String? url = memory.imageUrl;
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Container(color: _photoWash(memory, wash)),
      );
    }
    return Container(color: _photoWash(memory, wash));
  }

  Color _photoWash(TimelineMemory memory, Color fallback) {
    int hash = 0;
    for (final int code in memory.id.codeUnits) {
      hash = (hash + code) % _photoWashPalette.length;
    }
    return _photoWashPalette[hash];
  }

  Widget _buildSongBanner(int memoryCount) {
    return GestureDetector(
      key: const ValueKey('song-banner'),
      onTap: widget.onOpenSong,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E5D3),
          border: Border.all(
            color: const Color(0x88C05B3E),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              '♪',
              style: GoogleFonts.karla(
                fontSize: 20,
                color: BrutalTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$memoryCount memories collected — ready to turn them into '
                'your song?',
                style: GoogleFonts.karla(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                  color: const Color(0xFF8A4630),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '→',
              style: GoogleFonts.karla(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: BrutalTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No memories yet.',
              style: GoogleFonts.instrumentSerif(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: BrutalTheme.inkBlack,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Paste the first one into the scrapbook — a note, a photo, '
              'maybe even a place worth pinning.',
              textAlign: TextAlign.center,
              style: GoogleFonts.karla(
                fontSize: 14.5,
                height: 1.5,
                color: BrutalTheme.graphite,
              ),
            ),
            const SizedBox(height: 20),
            BrutalButton(
              color: BrutalTheme.primary,
              onPressed: _openComposer,
              child: Text(
                'ADD A MEMORY',
                style: GoogleFonts.karla(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
