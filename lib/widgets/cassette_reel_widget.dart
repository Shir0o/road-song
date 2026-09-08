import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../engines/highlight_reel_engine.dart';
import '../theme.dart';

/// Tactile animated cassette / vinyl reel showing left & right spinning hubs
/// and tape spooling dynamically as song playback progresses.
class CassetteReelWidget extends StatelessWidget {
  final HighlightReelFrame frame;
  final bool isPlaying;

  const CassetteReelWidget({
    super.key,
    required this.frame,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2B231B), // Deep tape cassette plastic
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: BrutalTheme.inkBlack,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left reel (draining tape)
          _buildReel(
            angle: frame.leftReelAngle,
            tapeRadius: frame.leftReelTapeRadius,
            label: 'A',
          ),
          // Center tape window & tape bridge
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF19130D),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF4A3B2C)),
                    ),
                    child: Center(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: const Color(0xFF78350F), // Magnetic tape ribbon
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPlaying ? '● TAPE PLAYING' : '❚❚ PAUSED',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isPlaying ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right reel (filling tape)
          _buildReel(
            angle: frame.rightReelAngle,
            tapeRadius: frame.rightReelTapeRadius,
            label: 'B',
          ),
        ],
      ),
    );
  }

  Widget _buildReel({
    required double angle,
    required double tapeRadius,
    required String label,
  }) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spooled tape pack
          Container(
            width: tapeRadius * 2,
            height: tapeRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF451A03), // Wound magnetic tape
              border: Border.all(color: const Color(0xFF291002), width: 1.5),
            ),
          ),
          // White hub
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF8F2E4),
            ),
          ),
          // Spinning spokes
          Transform.rotate(
            angle: angle,
            child: SizedBox(
              width: 28,
              height: 28,
              child: CustomPaint(
                painter: _SpokePainter(),
              ),
            ),
          ),
          // Center hole
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF19130D),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpokePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = BrutalTheme.inkBlack
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final Offset center = Offset(size.width / 2, size.height / 2);
    const int spokeCount = 6;
    final double radius = size.width / 2;

    for (int i = 0; i < spokeCount; i++) {
      final double spokeAngle = i * (2 * math.pi / spokeCount);
      final Offset p2 = center + Offset(math.cos(spokeAngle) * radius, math.sin(spokeAngle) * radius);
      canvas.drawLine(center, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
