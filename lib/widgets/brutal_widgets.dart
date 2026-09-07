import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class BrutalCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final double rotationDegrees;
  final bool showShadow;
  final bool hasTape;
  final double tapeRotationDegrees;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const BrutalCard({
    Key? key,
    required this.child,
    this.color = Colors.white,
    this.rotationDegrees = 0.0,
    this.showShadow = true,
    this.hasTape = false,
    this.tapeRotationDegrees = 3.0,
    this.borderWidth = 1.0, // Thinner border default
    this.borderRadius,
    this.padding,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      decoration: BrutalTheme.brutalDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(10.0), // Rounded corners default
        borderWidth: borderWidth,
        showShadow: showShadow,
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      card = GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    if (rotationDegrees != 0.0) {
      card = Transform.rotate(
        angle: rotationDegrees * math.pi / 180,
        child: card,
      );
    }

    if (hasTape) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            top: -12,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: tapeRotationDegrees * math.pi / 180,
                child: Container(
                  width: 60,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0x99D6BE8C), // Translucent beige tape
                    border: Border.all(
                      color: const Color(0x40B49B69), // Soft border
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return card;
  }
}

class BrutalButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final double height;
  final double? width;
  final bool fullWidth;

  const BrutalButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.color = BrutalTheme.primary, // Default to accent red
    this.height = 54.0,
    this.width,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  _BrutalButtonState createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = false);
      widget.onPressed!();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double offsetVal = _isPressed ? 2.0 : 0.0;
    
    Widget buttonContent = AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      height: widget.height,
      width: widget.fullWidth ? double.infinity : widget.width,
      transform: Matrix4.translationValues(offsetVal, offsetVal, 0.0),
      decoration: BrutalTheme.brutalDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(14.0), // Rounded corners for button
        borderWidth: 1.0,
        borderColor: const Color(0xFFE1D4B6),
        shadowOffset: const Offset(0, 8),
        shadowColor: widget.color == BrutalTheme.primary
            ? const Color(0xB2C05B3E)
            : const Color(0x59433729),
        showShadow: !_isPressed,
      ),
      alignment: Alignment.center,
      child: widget.child,
    );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
        child: buttonContent,
      ),
    );
  }
}

class DymoLabel extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color backgroundColor;
  final Color textColor;
  final EdgeInsetsGeometry padding;

  const DymoLabel({
    Key? key,
    required this.text,
    this.fontSize = 12.0,
    this.backgroundColor = BrutalTheme.inkBlack,
    this.textColor = const Color(0xFFFFF8EC),
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AFFFFFF),
            offset: Offset(1, 1),
            blurRadius: 0,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(-1, -1),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceMono(
          textStyle: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class TapeOverlay extends StatelessWidget {
  final double width;
  final double height;
  final double rotationDegrees;

  const TapeOverlay({
    Key? key,
    this.width = 60,
    this.height = 18,
    this.rotationDegrees = 3.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationDegrees * math.pi / 180,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0x99D6BE8C), // Translucent beige tape
          border: Border.all(
            color: const Color(0x40B49B69), // Soft border
            width: 1,
          ),
        ),
      ),
    );
  }
}

// Background grain/noise simulated overlay
class GrainOverlay extends StatelessWidget {
  final Widget child;
  const GrainOverlay({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // Semi-transparent overlay to mimic texture/grain
        IgnorePointer(
          child: Container(
            color: const Color(0xFF111111).withOpacity(0.02),
          ),
        ),
      ],
    );
  }
}

/// Paints diagonal scrapbook-paper stripes across its canvas, matching the
/// design comp's striped cover textures.
class DiagonalStripesPainter extends CustomPainter {
  final Color base;
  final Color stripe;

  /// On/off width of each stripe band.
  final double bandWidth;

  const DiagonalStripesPainter({
    required this.base,
    required this.stripe,
    this.bandWidth = 4.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..color = base);
    final Paint stripePaint = Paint()..color = stripe;
    // 45° bands; offset start so the first band bleeds off the top edge.
    for (
      double x = -size.height;
      x < size.width + size.height;
      x += bandWidth * 2
    ) {
      canvas.save();
      canvas.translate(x, 0);
      canvas.rotate(-math.pi / 4);
      canvas.drawRect(
        Rect.fromLTWH(0, -size.height, bandWidth, size.height * 3),
        stripePaint,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DiagonalStripesPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.stripe != stripe ||
      oldDelegate.bandWidth != bandWidth;
}

/// Paints a dashed rounded-rectangle border, for boxes the design comp shows
/// with a dashed outline (e.g. the invite share-link box).
class DashedRoundedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gapLength;

  const DashedRoundedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.radius = 12,
    this.dashLength = 6,
    this.gapLength = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final Path path = Path()..addRRect(rrect);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end =
            math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}
