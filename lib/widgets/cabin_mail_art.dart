import 'package:flutter/material.dart';

class CabinMailPainter extends CustomPainter {
  const CabinMailPainter({this.parcel = true, this.seal});

  final bool parcel;
  final Color? seal;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 10;
    void px(int x, int y, int w, int h, Color color) => canvas.drawRect(
      Rect.fromLTWH(x * c, y * c, w * c + 0.5, h * c + 0.5),
      Paint()..color = color,
    );
    const outline = Color(0xFF3A1D0C);
    const box = Color(0xFFC98B4F);
    const shade = Color(0xFFA06A35);
    final ribbon = seal ?? const Color(0xFFD6455D);
    if (!parcel) {
      px(0, 2, 10, 7, outline);
      px(1, 3, 8, 5, box);
      px(2, 4, 6, 1, shade);
      px(3, 5, 4, 1, shade);
      px(4, 5, 2, 2, ribbon);
      return;
    }
    px(1, 3, 8, 6, outline);
    px(2, 4, 6, 4, box);
    px(2, 7, 6, 1, shade);
    px(0, 2, 10, 2, outline);
    px(1, 2, 8, 1, box);
    px(4, 2, 2, 7, ribbon);
    px(2, 0, 2, 2, ribbon);
    px(6, 0, 2, 2, ribbon);
  }

  @override
  bool shouldRepaint(CabinMailPainter old) =>
      parcel != old.parcel || seal != old.seal;
}
