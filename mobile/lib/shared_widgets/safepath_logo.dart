import 'package:flutter/material.dart';

/// SafePath AI logo — a shield (protection) enclosing a winding path
/// that leads to a location pin ("safe path").
///
/// Two ways to use it:
///   1. SafePathLogo(size: 64)              -> full app-icon (gradient tile + mark)
///   2. SafePathLogo(size: 40, tile: false) -> just the mark, transparent bg
///
/// No external packages required — it's pure CustomPaint. Colors are the
/// same tokens as [AppColors] (deep teal / accent mint), kept as literal
/// values here so this file has no dependency on the theme layer.
class SafePathLogo extends StatelessWidget {
  const SafePathLogo({super.key, this.size = 64, this.tile = true});

  final double size;
  final bool tile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SafePathPainter(tile: tile)),
    );
  }
}

class _SafePathPainter extends CustomPainter {
  _SafePathPainter({required this.tile});

  final bool tile;

  static const _deepTeal = Color(0xFF0C3A3F);
  static const _tealTop = Color(0xFF1FA89B);
  static const _mint = Color(0xFF5FD0C5);
  static const _mintLight = Color(0xFF9FE7DF);
  static const _pathColor = Color(0xFFEAF7F5);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width; // assume square

    if (tile) {
      final rect = Rect.fromLTWH(0, 0, s, s);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.234));
      final bg = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_tealTop, _deepTeal],
          stops: [0.0, 0.75],
        ).createShader(rect);
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRRect(rrect, bg);
    }

    final scale = tile ? s / 512 * 2.7 : s / 90;
    canvas.translate(s / 2, s / 2);
    canvas.scale(scale);

    final shield = Path()
      ..moveTo(0, -64)
      ..lineTo(28, -54)
      ..lineTo(28, 0)
      ..cubicTo(28, 18, 16, 30, 0, 36)
      ..cubicTo(-16, 30, -28, 18, -28, 0)
      ..lineTo(-28, -54)
      ..close();
    canvas.drawPath(
      shield,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      shield,
      Paint()
        ..color = _mintLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeJoin = StrokeJoin.round,
    );

    final trail = Path()
      ..moveTo(-10, 28)
      ..cubicTo(-10, 16, 12, 14, 8, 2)
      ..cubicTo(4, -10, -14, -10, -6, -19);
    canvas.drawPath(
      trail,
      Paint()
        ..color = _pathColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(const Offset(-10, 28), 4.4, Paint()..color = _mintLight);

    canvas.drawCircle(const Offset(-6, -21), 6.6, Paint()..color = _mint);
    canvas.drawCircle(
      const Offset(-6, -21),
      6.6,
      Paint()
        ..color = _deepTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );

    if (tile) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SafePathPainter old) => old.tile != tile;
}
