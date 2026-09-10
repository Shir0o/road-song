import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/song_models.dart';
import '../services/remote_trip_store.dart';
import '../services/trip_link_sharer.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';

/// The "your trip memorial is ready" moment (issue #30): surfaces after
/// Making Song completes with a share action. The shared link is the trip
/// link (`roadsong.app/t/<code>`, via [TripLinkSharer] from #27); opening it
/// on another device reaches the guest web experience where visitors listen
/// to the song and browse the diary — no app or account required.
class MemorialReadyScreen extends StatefulWidget {
  final String tripName;
  final String? tripCode;
  final SongTimeline timeline;
  final VoidCallback? onBack;
  final VoidCallback? onWatch;

  const MemorialReadyScreen({
    super.key,
    required this.tripName,
    this.tripCode,
    required this.timeline,
    this.onBack,
    this.onWatch,
  });

  @override
  State<MemorialReadyScreen> createState() => _MemorialReadyScreenState();
}

class _MemorialReadyScreenState extends State<MemorialReadyScreen> {
  static const TripLinkSharer _linkSharer = TripLinkSharer();
  bool _shared = false;

  String get _link {
    final String? code = widget.tripCode;
    if (code != null && code.isNotEmpty) return buildTripLink(code);
    return buildTripLink(widget.tripName);
  }

  Future<void> _share() async {
    await _linkSharer.share(_link);
    if (!mounted) return;
    setState(() => _shared = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BrutalTheme.primary,
        content: Text(
          'Memorial link copied — anyone with it can listen and browse.',
          style: GoogleFonts.karla(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('memorial-ready-back'),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: BrutalTheme.inkBlack,
                    ),
                    onPressed:
                        widget.onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'YOUR MEMORIAL',
                    style: GoogleFonts.spaceMono(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  const Spacer(),
                  const DymoLabel(
                    text: 'READY',
                    fontSize: 11,
                    backgroundColor: BrutalTheme.primary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Transform.rotate(
                      angle: -6 * 3.14159 / 180,
                      child: Text(
                        '♪',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.karla(
                          fontSize: 44,
                          color: BrutalTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your trip memorial is ready',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 30,
                        height: 1.15,
                        color: BrutalTheme.inkBlack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.timeline.title} · ${widget.timeline.bpm} BPM '
                      '${widget.timeline.styleId.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.caveat(
                        fontSize: 20,
                        color: BrutalTheme.graphite,
                      ),
                    ),
                    const SizedBox(height: 18),
                    BrutalCard(
                      color: BrutalTheme.card,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SHARE THE TRIP LINK',
                            style: GoogleFonts.spaceMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.4,
                              color: BrutalTheme.graphite,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Anyone with this link can listen to the song and '
                            'browse the diary — no app, no account.',
                            style: GoogleFonts.karla(
                              fontSize: 13.5,
                              height: 1.5,
                              color: BrutalTheme.inkBlack,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: BrutalTheme.paper2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFDCCDAC),
                              ),
                            ),
                            child: Text(
                              _link,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceMono(
                                fontSize: 12.5,
                                color: BrutalTheme.inkBlack,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: BrutalButton(
                        key: const ValueKey('share-memorial-link'),
                        onPressed: _share,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _shared ? Icons.check_circle : Icons.ios_share,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _shared
                                  ? 'LINK COPIED — SHARE IT'
                                  : 'Share the memorial link',
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
                        key: const ValueKey('watch-memorial-again'),
                        color: const Color(0xFF5A4938),
                        onPressed: widget.onWatch,
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
                              'Watch the memorial again',
                              style: BrutalTheme.ctaLabelStyle(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
