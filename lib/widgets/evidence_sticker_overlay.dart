import 'package:flutter/material.dart';

import '../engines/highlight_reel_engine.dart';
import '../models/song_models.dart';
import '../theme.dart';

/// Overlay engine that pops up tactile Neo-Brutalist stickers / polaroids
/// triggered by [EvidenceCue] timestamps during vocal playback.
class EvidenceStickerOverlay extends StatelessWidget {
  final HighlightReelFrame frame;

  const EvidenceStickerOverlay({
    super.key,
    required this.frame,
  });

  @override
  Widget build(BuildContext context) {
    final EvidenceCue? cue = frame.activeCue;
    if (cue == null || frame.cuePopupOpacity <= 0.0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 36,
      right: 20,
      child: Opacity(
        opacity: frame.cuePopupOpacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: frame.cuePopupRotation,
          child: Transform.scale(
            scale: frame.cuePopupScale,
            child: _buildStickerBadge(cue),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerBadge(EvidenceCue cue) {
    final bool isPhoto = cue.kind == EvidenceCueKind.photo;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: isPhoto ? const Color(0xFFFFFDF4) : const Color(0xFFFDE047),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: BrutalTheme.inkBlack,
          width: 2.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(3, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPhoto ? Icons.photo_camera_rounded : Icons.star_rounded,
            size: 20,
            color: isPhoto ? BrutalTheme.primary : BrutalTheme.inkBlack,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              cue.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: BrutalTheme.inkBlack,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
