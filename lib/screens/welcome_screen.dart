import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';

/// Editorial onboarding screen with a tactile scrapbook polaroid collage
/// and a primary call-to-action to start creating a trip song.
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onStart;

  const WelcomeScreen({Key? key, required this.onStart}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 46),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.rotate(
                angle: -2 * 3.14159 / 180,
                child: Text(
                  'a scrapbook that sings ♪',
                  style: GoogleFonts.caveat(
                    fontSize: 21,
                    color: BrutalTheme.graphite,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Road\nSong',
                style: GoogleFonts.instrumentSerif(
                  fontSize: 58,
                  height: 0.98,
                  fontWeight: FontWeight.bold,
                  color: BrutalTheme.inkBlack,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      top: 24,
                      child: _PolaroidCard(
                        rotationDegrees: -5,
                        caption: 'the wrong hill, sintra',
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 90,
                      child: _PolaroidCard(
                        rotationDegrees: 4,
                        hasTape: true,
                        caption: 'tram 28, all five of us',
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 8,
                      child: Transform.rotate(
                        angle: -3 * 3.14159 / 180,
                        child: Text(
                          'every wrong turn, kept forever',
                          style: GoogleFonts.caveat(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: BrutalTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Collect the notes, photos and wrong turns from a trip with your friends — then turn them all into a song you\'ll keep forever.',
                style: GoogleFonts.karla(
                  fontSize: 15,
                  height: 1.6,
                  color: const Color(0xFF6E5F4A),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: BrutalButton(
                  onPressed: onStart,
                  child: Text(
                    'START A TRIP SONG',
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
}

class _PolaroidCard extends StatelessWidget {
  final double rotationDegrees;
  final bool hasTape;
  final String caption;

  const _PolaroidCard({
    required this.rotationDegrees,
    required this.caption,
    this.hasTape = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationDegrees * 3.14159 / 180,
      child: Container(
        width: 172,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEF9),
          border: Border.all(color: const Color(0xFFEDE3CC), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0x73433729),
              offset: const Offset(0, 14),
              blurRadius: 28,
              spreadRadius: -14,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFE7D9BE),
                border: Border.all(color: const Color(0xFFE1D4B6), width: 1),
              ),
              child: hasTape
                  ? Stack(
                      children: [
                        Positioned(
                          top: -9,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: TapeOverlay(rotationDegrees: -3),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              style: GoogleFonts.caveat(
                fontSize: 16,
                color: const Color(0xFF5D4F3C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
