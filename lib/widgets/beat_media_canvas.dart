import 'package:flutter/material.dart';

import '../engines/highlight_reel_engine.dart';
import '../models/trip_models.dart';
import '../theme.dart';

/// Canvas displaying the active memory photo or stylized visual wash
/// with Ken Burns pan and slow zoom synchronized to musical downbeats.
class BeatMediaCanvas extends StatelessWidget {
  final HighlightReelFrame frame;

  const BeatMediaCanvas({
    super.key,
    required this.frame,
  });

  @override
  Widget build(BuildContext context) {
    final TimelineMemory memory = frame.mediaMemory;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ken Burns animated layer
          Transform.translate(
            offset: frame.kenBurnsPan,
            child: Transform.scale(
              scale: frame.kenBurnsZoom,
              child: _buildMediaContent(memory),
            ),
          ),
          // Subtle warm vignette / grain overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Colors.transparent,
                  BrutalTheme.inkBlack.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
          // Subtle memory metadata tag at top left
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BrutalTheme.inkBlack.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Text(
                memory.locationName ?? memory.author,
                style: const TextStyle(
                  color: Color(0xFFFFF8EC),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(TimelineMemory memory) {
    if (memory.photoBytes != null) {
      return Image.memory(
        memory.photoBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildStylizedWash(memory),
      );
    }
    if (memory.imageUrl != null && memory.imageUrl!.isNotEmpty) {
      return Image.network(
        memory.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildStylizedWash(memory),
      );
    }
    return _buildStylizedWash(memory);
  }

  Widget _buildStylizedWash(TimelineMemory memory) {
    // Elegant warm analog palette for memories without raw image files
    final List<Color> warmPalette = [
      const Color(0xFFD97706),
      const Color(0xFFB45309),
      const Color(0xFFC05B3E),
      const Color(0xFF92400E),
      const Color(0xFF78350F),
    ];
    final Color bg = warmPalette[frame.mediaIndex % warmPalette.length];

    return Container(
      color: bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                memory.icon,
                size: 56,
                color: const Color(0xFFFFF8EC).withValues(alpha: 0.85),
              ),
              const SizedBox(height: 14),
              Text(
                memory.text,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFFFFF8EC),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
