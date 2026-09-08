import 'package:flutter/material.dart';

import '../engines/highlight_reel_engine.dart';
import '../models/song_models.dart';
import '../theme.dart';

/// A high-performance [CustomPainter] executing 60fps kinetic Neo-Brutalist
/// typography animations:
/// - Word bounce (vertical arc translation with spring)
/// - Shake (high-frequency jitter during high energy moments like chorus)
/// - Burst (punch scale on word arrival)
/// - Karaoke fill (tactile Neo-Brutalist highlight block advancing across active words)
class KineticSubtitlePainter extends CustomPainter {
  final HighlightReelFrame frame;
  final TextStyle baseStyle;
  final TextStyle activeStyle;
  final Color highlightBlockColor;
  final Color borderColor;

  KineticSubtitlePainter({
    required this.frame,
    TextStyle? baseStyle,
    TextStyle? activeStyle,
    Color? highlightBlockColor,
    Color? borderColor,
  })  : baseStyle = baseStyle ??
            const TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.w800,
              color: BrutalTheme.inkBlack,
              letterSpacing: -0.2,
            ),
        activeStyle = activeStyle ??
            const TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.w900,
              color: BrutalTheme.primary,
              letterSpacing: -0.2,
            ),
        highlightBlockColor =
            highlightBlockColor ?? const Color(0xFFFDE047).withValues(alpha: 0.9), // Bright brutalist yellow
        borderColor = borderColor ?? BrutalTheme.inkBlack;

  @override
  void paint(Canvas canvas, Size size) {
    final TimelineLine? line = frame.activeLine;
    if (line == null || line.words.isEmpty) return;

    // Measure each word
    final List<TextPainter> wordPainters = [];
    final List<double> wordWidths = [];
    double totalWidth = 0.0;
    const double spaceWidth = 8.0;

    for (final TimelineWord word in line.words) {
      final bool isActive = word == frame.activeWord;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: word.word,
          style: isActive ? activeStyle : baseStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      wordPainters.add(tp);
      wordWidths.add(tp.width);
      totalWidth += tp.width;
    }
    totalWidth += spaceWidth * (line.words.length - 1);

    // Center horizontally, position near lower third of canvas
    double currentX = (size.width - totalWidth) / 2.0;
    final double baselineY = size.height * 0.72;

    for (int i = 0; i < line.words.length; i++) {
      final TimelineWord word = line.words[i];
      final TextPainter tp = wordPainters[i];
      final bool isActive = word == frame.activeWord;
      final double width = wordWidths[i];
      final double height = tp.height;

      canvas.save();

      if (isActive) {
        // Center of the active word
        final double centerX = currentX + width / 2.0;
        final double centerY = baselineY + height / 2.0;

        // Apply bounce Y & shake offset
        canvas.translate(
          centerX + frame.wordShakeOffset.dx,
          centerY + frame.wordBounceY + frame.wordShakeOffset.dy,
        );

        // Apply scale (burst / punch)
        canvas.scale(frame.wordScale, frame.wordScale);

        // Translate back to origin of word
        canvas.translate(-width / 2.0, -height / 2.0);

        // Draw tactile Neo-Brutalist highlight backdrop block
        final Rect blockRect = Rect.fromLTWH(-4.0, -2.0, width + 8.0, height + 4.0);
        final RRect roundedBlock = RRect.fromRectAndRadius(blockRect, const Radius.circular(4.0));

        // Karaoke fill effect: partial width fill based on karaokeFillRatio
        if (frame.kineticStyle == KineticWordEffect.karaokeFill) {
          final double fillWidth = (width + 8.0) * frame.karaokeFillRatio;
          final Rect fillRect = Rect.fromLTWH(-4.0, -2.0, fillWidth, height + 4.0);
          final Paint fillPaint = Paint()..color = highlightBlockColor;
          canvas.drawRect(fillRect, fillPaint);

          // Border around block
          final Paint borderPaint = Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawRRect(roundedBlock, borderPaint);
        } else {
          // Solid Neo-Brutalist highlight block under active word
          final Paint bgPaint = Paint()..color = highlightBlockColor;
          canvas.drawRRect(roundedBlock, bgPaint);

          final Paint borderPaint = Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawRRect(roundedBlock, borderPaint);
        }

        // Paint text
        tp.paint(canvas, Offset.zero);
      } else {
        // Inactive words rendered static
        canvas.translate(currentX, baselineY);
        tp.paint(canvas, Offset.zero);
      }

      canvas.restore();
      currentX += width + spaceWidth;
    }
  }

  @override
  bool shouldRepaint(covariant KineticSubtitlePainter oldDelegate) {
    return oldDelegate.frame.positionMs != frame.positionMs ||
        oldDelegate.frame.activeWord != frame.activeWord ||
        oldDelegate.frame.wordProgress != frame.wordProgress ||
        oldDelegate.frame.wordBounceY != frame.wordBounceY ||
        oldDelegate.frame.wordShakeOffset != frame.wordShakeOffset ||
        oldDelegate.frame.wordScale != frame.wordScale;
  }
}
