import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Renders a real QR code from a text payload using the `qr` package.
class QrCodeView extends StatelessWidget {
  final String data;
  final double size;
  final Color darkColor;
  final Color lightColor;

  const QrCodeView({
    Key? key,
    required this.data,
    this.size = 96,
    this.darkColor = Colors.black,
    this.lightColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _QrPainter(
        data: data,
        darkColor: darkColor,
        lightColor: lightColor,
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final String data;
  final Color darkColor;
  final Color lightColor;

  _QrPainter({
    required this.data,
    required this.darkColor,
    required this.lightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode = QrCode(4, QrErrorCorrectLevel.M)..addData(data);
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;
    final moduleSize = size.width / (moduleCount + 8); // quiet zone

    // Quiet zone / background.
    canvas.drawRect(Offset.zero & size, Paint()..color = lightColor);

    final cell = moduleSize;
    final offset = 4 * cell;
    for (int x = 0; x < moduleCount; x++) {
      for (int y = 0; y < moduleCount; y++) {
        if (qrImage.isDark(y, x)) {
          canvas.drawRect(
            Rect.fromLTWH(offset + x * cell, offset + y * cell, cell, cell),
            Paint()..color = darkColor,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.darkColor != darkColor ||
        oldDelegate.lightColor != lightColor;
  }
}
