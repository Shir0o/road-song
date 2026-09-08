import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/video_export_controller.dart';
import '../engines/ffmpeg_export_engine.dart';
import '../models/song_models.dart';
import '../models/trip_models.dart';
import '../services/share_memorial_service.dart';
import '../theme.dart';
import '../widgets/avatar_stack.dart';
import '../widgets/brutal_widgets.dart';

/// The final Share Memorial view featuring the tape-mounted keepsake card,
/// crew avatar stacks, web preview metadata, copy link action, and 1080p MP4
/// video highlight reel export pipeline.
class ShareMemorialScreen extends StatefulWidget {
  final String tripName;
  final String? tripDateRange;
  final SongTimeline timeline;
  final List<TimelineMemory> memories;
  final List<CrewMember> crew;
  final List<String> participants;
  final VoidCallback? onBack;

  const ShareMemorialScreen({
    super.key,
    required this.tripName,
    this.tripDateRange,
    required this.timeline,
    required this.memories,
    this.crew = const [],
    this.participants = const [],
    this.onBack,
  });

  @override
  State<ShareMemorialScreen> createState() => _ShareMemorialScreenState();
}

class _ShareMemorialScreenState extends State<ShareMemorialScreen> {
  static const ShareMemorialService _shareService = ShareMemorialService();
  late final VideoExportController _exportController;

  VideoAspectRatio _aspectRatio = VideoAspectRatio.vertical9x16;
  bool _copied = false;
  Timer? _copyTimer;
  bool _copiedRecipe = false;
  Timer? _copyRecipeTimer;

  @override
  void initState() {
    super.initState();
    _exportController = VideoExportController();
    _exportController.addListener(_onExportStateChanged);
  }

  void _onExportStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _copyRecipeTimer?.cancel();
    _exportController.removeListener(_onExportStateChanged);
    _exportController.dispose();
    super.dispose();
  }

  String get _shareUrl => _shareService.buildShareLink(
        tripName: widget.tripName,
        songTitle: widget.timeline.title,
      );

  WebCardMetadata get _previewMetadata => _shareService.generatePreviewMetadata(
        tripName: widget.tripName,
        timeline: widget.timeline,
        memories: widget.memories,
        crew: widget.crew,
      );

  void _copyShareLink() {
    Clipboard.setData(ClipboardData(text: _shareUrl));
    _copyTimer?.cancel();
    setState(() => _copied = true);
    _copyTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _startExport() {
    _exportController.startExport(
      timeline: widget.timeline,
      memories: widget.memories,
      aspectRatio: _aspectRatio,
    );
  }

  void _copyFFmpegCommand() {
    final recipe = _exportController.state.recipe ??
        FFmpegExportEngine.buildRecipe(
          timeline: widget.timeline,
          memories: widget.memories,
          aspectRatio: _aspectRatio,
        );

    Clipboard.setData(ClipboardData(text: recipe.commandString));
    _copyRecipeTimer?.cancel();
    setState(() => _copiedRecipe = true);
    _copyRecipeTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copiedRecipe = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final exportState = _exportController.state;

    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('memorial-back-button'),
                    icon: const Icon(Icons.arrow_back, color: BrutalTheme.inkBlack),
                    onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SHARE MEMORIAL',
                    style: GoogleFonts.spaceMono(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  const Spacer(),
                  const DymoLabel(
                    text: 'KEEPSAKE',
                    fontSize: 11,
                    backgroundColor: BrutalTheme.primary,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Tactile Keepsake Card with Tape Mounts & Avatars
                    _buildTactileKeepsakeCard(),

                    const SizedBox(height: 24),

                    // 2. Shareable Link Section
                    _buildShareLinkSection(),

                    const SizedBox(height: 24),

                    // 3. Web Preview Card
                    _buildWebPreviewCard(),

                    const SizedBox(height: 28),

                    // 4. Video Highlight Reel Export Section
                    _buildVideoExportSection(exportState),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Keepsake Card ──────────────────────────────────────────────────────────

  Widget _buildTactileKeepsakeCard() {
    final timeline = widget.timeline;
    final String? dateRange = widget.tripDateRange;

    return BrutalCard(
      color: BrutalTheme.card,
      hasTape: true,
      tapeRotationDegrees: -3.0,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tripName,
                      style: GoogleFonts.spaceMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: BrutalTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeline.title,
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                        color: BrutalTheme.inkBlack,
                      ),
                    ),
                    if (dateRange != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        dateRange,
                        style: GoogleFonts.karla(
                          fontSize: 13,
                          color: BrutalTheme.graphite,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Vibe Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: BrutalTheme.paper2,
                  border: Border.all(color: const Color(0xFFDCCDAC)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${timeline.bpm} BPM · ${timeline.styleId.toUpperCase()}',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFEBDFC6), height: 1),
          const SizedBox(height: 14),

          // Participants / Crew Avatar Stack
          Row(
            children: [
              AvatarStack(
                crew: widget.crew,
                fallbackNames: widget.participants,
                avatarSize: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.crew.isNotEmpty
                      ? '${widget.crew.length} road crew contributors'
                      : '${widget.memories.length} trip moments immortalized',
                  style: GoogleFonts.karla(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Lyric Teaser Quote
          if (timeline.sections.isNotEmpty &&
              timeline.sections.first.lines.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: BrutalTheme.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE1D4B6)),
              ),
              child: Text(
                '“${timeline.sections.first.lines.first.text}”',
                style: GoogleFonts.caveat(
                  fontSize: 19,
                  color: BrutalTheme.inkBlack,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Share Link Box ─────────────────────────────────────────────────────────

  Widget _buildShareLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shareable Memorial Link',
          style: GoogleFonts.spaceMono(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: BrutalTheme.graphite,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: BrutalTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDCCDAC)),
          ),
          child: Row(
            children: [
              const Icon(Icons.link, size: 20, color: BrutalTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _shareUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceMono(
                    fontSize: 13,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                key: const ValueKey('copy-share-link-button'),
                onTap: _copyShareLink,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _copied ? const Color(0xFF7D8663) : BrutalTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _copied ? 'COPIED!' : 'COPY',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Web Card Preview ───────────────────────────────────────────────────────

  Widget _buildWebPreviewCard() {
    final meta = _previewMetadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Social Web Preview Card',
              style: GoogleFonts.spaceMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: BrutalTheme.graphite,
              ),
            ),
            const Spacer(),
            Text(
              'iMessage · X · Discord',
              style: GoogleFonts.karla(
                fontSize: 11,
                color: BrutalTheme.graphite,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1A16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF382E24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover banner
              Container(
                height: 120,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF2C241C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.audiotrack, color: Color(0xFFFDE047), size: 32),
                      const SizedBox(height: 4),
                      Text(
                        '${meta.audioDurationFormatted} · ${meta.vibeLabel}',
                        style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFF8EC),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.title,
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 18,
                        color: const Color(0xFFFFF8EC),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.karla(
                        fontSize: 12,
                        color: const Color(0xFFB5A48F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'roadsong.app',
                      style: GoogleFonts.spaceMono(
                        fontSize: 10,
                        color: const Color(0xFF7A6B58),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Video Highlight Reel Export Section ────────────────────────────────────

  Widget _buildVideoExportSection(VideoExportState state) {
    final bool isExporting = state.status == VideoExportStatus.preparing ||
        state.status == VideoExportStatus.encoding;
    final bool isDone = state.status == VideoExportStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '1080p MP4 Video Export',
              style: GoogleFonts.spaceMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: BrutalTheme.graphite,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: BrutalTheme.primary,
                borderRadius: BorderRadius.circular(4),
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
        const SizedBox(height: 10),

        // Aspect Ratio Selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: BrutalTheme.paper2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDCCDAC)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildAspectToggle(
                  ratio: VideoAspectRatio.vertical9x16,
                  key: const ValueKey('aspect-vertical-button'),
                ),
              ),
              Expanded(
                child: _buildAspectToggle(
                  ratio: VideoAspectRatio.widescreen16x9,
                  key: const ValueKey('aspect-widescreen-button'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Progress bar if exporting
        if (isExporting) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BrutalTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDCCDAC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.statusMessage,
                        style: GoogleFonts.karla(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: BrutalTheme.inkBlack,
                        ),
                      ),
                    ),
                    Text(
                      '${(state.progress * 100).toInt()}%',
                      style: GoogleFonts.spaceMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: BrutalTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    backgroundColor: BrutalTheme.paper2,
                    valueColor: const AlwaysStoppedAnimation<Color>(BrutalTheme.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Success Box if done
        if (isDone) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7EE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFC0D8B4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4C7B3C), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1080p MP4 Ready for Socials',
                        style: GoogleFonts.karla(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: const Color(0xFF233B1B),
                        ),
                      ),
                      Text(
                        'Baked kinetic subtitles & downbeat audio',
                        style: GoogleFonts.karla(
                          fontSize: 12,
                          color: const Color(0xFF4A6B3D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Export Action Button
        SizedBox(
          width: double.infinity,
          child: BrutalButton(
            key: const ValueKey('export-mp4-button'),
            color: isDone ? const Color(0xFF7D8663) : BrutalTheme.primary,
            onPressed: isExporting ? null : _startExport,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isDone ? Icons.refresh : Icons.movie_creation_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isDone
                      ? 'Re-export Video'
                      : 'Export 1080p MP4 (${_aspectRatio.label})',
                  style: BrutalTheme.ctaLabelStyle(),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Copy FFmpeg Command (developer / native CLI support)
        Center(
          child: TextButton.icon(
            key: const ValueKey('copy-ffmpeg-recipe-button'),
            onPressed: _copyFFmpegCommand,
            icon: Icon(
              _copiedRecipe ? Icons.check : Icons.terminal,
              size: 16,
              color: BrutalTheme.graphite,
            ),
            label: Text(
              _copiedRecipe ? 'Command Copied to Clipboard!' : 'Copy FFmpeg Command Recipe',
              style: GoogleFonts.spaceMono(
                fontSize: 11,
                color: BrutalTheme.graphite,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAspectToggle({
    required VideoAspectRatio ratio,
    required Key key,
  }) {
    final bool selected = _aspectRatio == ratio;
    return GestureDetector(
      key: key,
      onTap: () => setState(() => _aspectRatio = ratio),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? BrutalTheme.inkBlack : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Text(
              ratio.label,
              style: GoogleFonts.spaceMono(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: selected ? const Color(0xFFFFF8EC) : BrutalTheme.inkBlack,
              ),
            ),
            Text(
              ratio.targetPlatform,
              style: GoogleFonts.karla(
                fontSize: 10,
                color: selected ? const Color(0xFFD6BE8C) : BrutalTheme.graphite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
