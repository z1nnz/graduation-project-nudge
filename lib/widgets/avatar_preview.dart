import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';

Widget buildAvatarImage(String path, {double? width, double? height, BoxFit fit = BoxFit.contain}) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return Image.network(path, width: width, height: height, fit: fit);
  } else if (path.startsWith('data:image') || path.contains(';base64,')) {
    final cleanBase64 = path.contains(',') ? path.split(',')[1] : path;
    try {
      return Image.memory(
        base64Decode(cleanBase64.trim()),
        width: width,
        height: height,
        fit: fit,
      );
    } catch (e) {
      debugPrint('Base64 decode error: $e');
      return const Icon(Icons.broken_image, color: Colors.red);
    }
  } else {
    return Image.asset(path, width: width, height: height, fit: fit);
  }
}

class AvatarPreview extends StatelessWidget {
  final AvatarProfile profile;
  final double size;
  final bool showBackgroundRing;
  static AssetManifest? _cachedManifest;

  const AvatarPreview({
    super.key,
    required this.profile,
    this.size = 72,
    this.showBackgroundRing = false,
  });

  Future<AssetManifest> _loadManifest() async {
    return _cachedManifest ??= await AssetManifest.loadFromAssetBundle(
      rootBundle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final characterPath = AvatarCatalog.characterAssetForIndex(profile.faceShapeIndex);
    if (characterPath.startsWith('http://') ||
        characterPath.startsWith('https://') ||
        characterPath.startsWith('data:image') ||
        characterPath.contains(';base64,')) {
      return _wrapCharacter(
        OverflowBox(
          alignment: Alignment.center,
          minWidth: 0,
          minHeight: 0,
          maxWidth: size * 1.5,
          maxHeight: size * 1.5,
          child: SizedBox(
            width: size,
            height: size * 1.5,
            child: buildAvatarImage(characterPath, fit: BoxFit.contain),
          ),
        ),
      );
    }

    return FutureBuilder<AssetManifest>(
      future: _loadManifest(),
      builder: (context, snapshot) {
        final manifest = snapshot.data;
        if (manifest == null) {
          return _wrapCharacter(_buildPaintedCharacter());
        }

        final paths = _AvatarLayerPaths(profile);
        final assets = manifest.listAssets();
        final hasRequiredLayers = paths.requiredLayers.every(assets.contains);
        if (!hasRequiredLayers) {
          return _wrapCharacter(_buildPaintedCharacter());
        }

        final layers = paths
            .orderedForAssets(assets)
            .where(assets.contains)
            .map((path) => Positioned.fill(child: _buildAssetLayer(path)))
            .toList();

        if (layers.isEmpty) {
          return _wrapCharacter(_buildPaintedCharacter());
        }

        return _wrapCharacter(Stack(clipBehavior: Clip.none, children: layers));
      },
    );
  }

  Widget _buildPaintedCharacter() {
    return CustomPaint(
      size: Size.square(size),
      painter: _NudgeAvatarPainter(profile),
    );
  }

  Widget _buildAssetLayer(String path) {
    return OverflowBox(
      alignment: Alignment.center,
      minWidth: 0,
      minHeight: 0,
      maxWidth: size * 1.5,
      maxHeight: size * 1.5,
      child: SizedBox(
        width: size,
        height: size * 1.5,
        child: Image.asset(path, fit: BoxFit.contain),
      ),
    );
  }

  Widget _wrapCharacter(Widget character) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: showBackgroundRing ? BoxShape.circle : BoxShape.rectangle,
        color: showBackgroundRing
            ? const Color(0xFFEDE9FE)
            : Colors.transparent,
        border: showBackgroundRing
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.92),
                width: size * 0.035,
              )
            : null,
      ),
      child: showBackgroundRing ? ClipOval(child: character) : character,
    );
  }
}

class _AvatarLayerPaths {
  final AvatarProfile profile;

  const _AvatarLayerPaths(this.profile);

  String get character =>
      AvatarCatalog.characterAssetForIndex(profile.faceShapeIndex);

  List<String> get ordered {
    return [character];
  }

  List<String> orderedForAssets(List<String> assets) {
    return ordered;
  }

  List<String> get requiredLayers {
    return [character];
  }
}

class _NudgeAvatarPainter extends CustomPainter {
  final AvatarProfile profile;

  const _NudgeAvatarPainter(this.profile);

  Color get _skin => profile.skinTone;
  Color get _hair => profile.hairColor;
  Color get _outfit => profile.outfitColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 120;
    canvas.save();
    canvas.translate((size.width - size.shortestSide) / 2, 0);
    canvas.scale(scale, scale);

    _drawGroundShadow(canvas);
    _drawBackHair(canvas);
    _drawLegsAndShoes(canvas);
    _drawBodyAndOutfit(canvas);
    _drawArms(canvas);
    _drawNeck(canvas);
    _drawHead(canvas);
    _drawEars(canvas);
    _drawFrontHair(canvas);
    _drawFace(canvas);
    _drawAccessory(canvas);

    canvas.restore();
  }

  Paint _paint(Color color) => Paint()..color = color;

  Color _shade(Color color, double amount) {
    return Color.lerp(color, Colors.black, amount)!;
  }

  Color _tint(Color color, double amount) {
    return Color.lerp(color, Colors.white, amount)!;
  }

  void _drawGroundShadow(Canvas canvas) {
    canvas.drawOval(
      const Rect.fromLTWH(32, 106, 56, 8),
      _paint(Colors.black.withValues(alpha: 0.14)),
    );
  }

  void _drawLegsAndShoes(Canvas canvas) {
    final pants = _shade(_outfit, 0.48);
    final pantsDark = _shade(pants, 0.16);
    final shoe = _shade(pants, 0.58);
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final leftLeg = RRect.fromRectAndRadius(
      const Rect.fromLTWH(43, 76, 12, 28),
      const Radius.circular(6),
    );
    final rightLeg = RRect.fromRectAndRadius(
      const Rect.fromLTWH(65, 76, 12, 28),
      const Radius.circular(6),
    );
    canvas.drawRRect(leftLeg, _paint(pants));
    canvas.drawRRect(rightLeg, _paint(pantsDark));
    canvas.drawLine(const Offset(47, 79), const Offset(47, 99), shine);
    canvas.drawLine(const Offset(69, 79), const Offset(69, 99), shine);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, 101, 20, 7),
        const Radius.circular(4),
      ),
      _paint(shoe),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(62, 101, 20, 7),
        const Radius.circular(4),
      ),
      _paint(shoe),
    );
  }

  void _drawBodyAndOutfit(Canvas canvas) {
    final bodyRect = const Rect.fromLTWH(31, 52, 58, 36);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_tint(_outfit, 0.20), _outfit, _shade(_outfit, 0.16)],
      ).createShader(bodyRect);

    final body = Path()
      ..moveTo(36, 53)
      ..cubicTo(43, 47, 77, 47, 84, 53)
      ..lineTo(90, 80)
      ..cubicTo(91, 89, 82, 93, 73, 90)
      ..lineTo(47, 90)
      ..cubicTo(38, 93, 29, 89, 30, 80)
      ..close();

    canvas.drawPath(body, bodyPaint);

    final trim = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accent = _tint(_outfit, 0.35);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.24);
    final darkLine = Paint()
      ..color = _shade(_outfit, 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    switch (profile.outfitStyleIndex) {
      case 1:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(40, 56, 40, 20),
            const Radius.circular(10),
          ),
          light,
        );
        _drawHood(canvas, trim);
      case 2:
        _drawCollar(canvas, trim);
        for (final y in [61.0, 68.0, 75.0]) {
          canvas.drawCircle(Offset(60, y), 1.5, light);
        }
      case 3:
        _drawJacket(canvas, trim, light);
      case 4:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(42, 58, 36, 24),
            const Radius.circular(8),
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      case 5:
        _drawCollar(canvas, trim);
        canvas.drawLine(const Offset(60, 55), const Offset(60, 84), darkLine);
      case 6:
        canvas.drawPath(
          Path()
            ..moveTo(41, 65)
            ..quadraticBezierTo(60, 57, 79, 65)
            ..lineTo(79, 70)
            ..quadraticBezierTo(60, 63, 41, 70)
            ..close(),
          light,
        );
      case 7:
        canvas.drawOval(const Rect.fromLTWH(50, 62, 20, 8), light);
        canvas.drawLine(const Offset(50, 70), const Offset(70, 70), darkLine);
      case 8:
        _drawCape(canvas, accent);
      case 9:
        _drawJacket(canvas, trim, light);
        canvas.drawLine(const Offset(60, 55), const Offset(60, 84), darkLine);
      case 10:
        canvas.drawPath(
          Path()
            ..moveTo(43, 63)
            ..lineTo(77, 63)
            ..lineTo(73, 70)
            ..lineTo(47, 70)
            ..close(),
          light,
        );
        canvas.drawCircle(const Offset(48, 77), 2.4, light);
        canvas.drawCircle(const Offset(72, 77), 2.4, light);
      case 11:
        canvas.drawOval(const Rect.fromLTWH(43, 59, 34, 20), light);
        canvas.drawCircle(
          const Offset(60, 58),
          4,
          _paint(_tint(_outfit, 0.35)),
        );
      case 12:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(44, 60, 32, 19),
            const Radius.circular(4),
          ),
          light,
        );
        canvas.drawLine(const Offset(44, 69), const Offset(76, 69), darkLine);
      case 13:
        for (final x in [50.0, 60.0, 70.0]) {
          canvas.drawCircle(Offset(x, 69), 3, light);
        }
        canvas.drawPath(
          Path()
            ..moveTo(46, 82)
            ..quadraticBezierTo(60, 74, 74, 82),
          trim,
        );
      case 14:
        _drawJacket(canvas, trim, light);
        canvas.drawLine(
          const Offset(45, 60),
          const Offset(75, 78),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.26)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      default:
        _drawCollar(canvas, trim);
        canvas.drawCircle(const Offset(72, 66), 2.4, light);
        canvas.drawCircle(const Offset(72, 75), 2.4, light);
    }
  }

  void _drawCape(Canvas canvas, Color color) {
    final cape = Path()
      ..moveTo(37, 56)
      ..quadraticBezierTo(60, 46, 83, 56)
      ..lineTo(88, 92)
      ..quadraticBezierTo(60, 101, 32, 92)
      ..close();
    canvas.drawPath(cape, _paint(color.withValues(alpha: 0.40)));
  }

  void _drawCollar(Canvas canvas, Paint trim) {
    canvas.drawPath(
      Path()
        ..moveTo(49, 54)
        ..lineTo(60, 61)
        ..lineTo(71, 54),
      trim,
    );
  }

  void _drawHood(Canvas canvas, Paint trim) {
    canvas.drawArc(
      const Rect.fromLTWH(44, 52, 32, 22),
      math.pi,
      math.pi,
      false,
      trim,
    );
  }

  void _drawJacket(Canvas canvas, Paint trim, Paint light) {
    canvas.drawPath(
      Path()
        ..moveTo(44, 58)
        ..lineTo(58, 66)
        ..lineTo(48, 83),
      trim,
    );
    canvas.drawPath(
      Path()
        ..moveTo(76, 58)
        ..lineTo(62, 66)
        ..lineTo(72, 83),
      trim,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(47, 72, 10, 7),
        const Radius.circular(3),
      ),
      light,
    );
  }

  void _drawArms(Canvas canvas) {
    final sleeve = _tint(_outfit, 0.08);
    final sleeveDark = _shade(_outfit, 0.10);

    final leftArm = Path()
      ..moveTo(34, 57)
      ..cubicTo(23, 62, 20, 78, 26, 88)
      ..cubicTo(30, 94, 38, 89, 36, 82)
      ..cubicTo(34, 73, 37, 64, 43, 59)
      ..close();
    final rightArm = Path()
      ..moveTo(86, 57)
      ..cubicTo(97, 62, 100, 78, 94, 88)
      ..cubicTo(90, 94, 82, 89, 84, 82)
      ..cubicTo(86, 73, 83, 64, 77, 59)
      ..close();

    canvas.drawPath(leftArm, _paint(sleeve));
    canvas.drawPath(rightArm, _paint(sleeveDark));
    canvas.drawCircle(const Offset(29, 91), 5.2, _paint(_skin));
    canvas.drawCircle(const Offset(91, 91), 5.2, _paint(_skin));
  }

  void _drawNeck(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(54, 47, 12, 11),
        const Radius.circular(5),
      ),
      _paint(_shade(_skin, 0.05)),
    );
  }

  void _drawHead(Canvas canvas) {
    final rect = switch (profile.faceShapeIndex) {
      1 => const Rect.fromLTWH(35, 13, 50, 48),
      2 => const Rect.fromLTWH(32, 18, 56, 43),
      3 => const Rect.fromLTWH(38, 18, 44, 43),
      4 => const Rect.fromLTWH(34, 14, 52, 47),
      5 => const Rect.fromLTWH(33, 16, 54, 45),
      _ => const Rect.fromLTWH(34, 12, 52, 49),
    };

    final radius = switch (profile.faceShapeIndex) {
      2 => const Radius.circular(16),
      3 => const Radius.circular(24),
      4 => const Radius.circular(28),
      5 => const Radius.circular(14),
      _ => const Radius.circular(25),
    };

    final headPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_tint(_skin, 0.18), _skin, _shade(_skin, 0.05)],
      ).createShader(rect);

    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), headPaint);

    canvas.drawOval(
      const Rect.fromLTWH(40, 42, 9, 4),
      _paint(const Color(0xFFEF8F8F).withValues(alpha: 0.18)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(71, 42, 9, 4),
      _paint(const Color(0xFFEF8F8F).withValues(alpha: 0.18)),
    );
  }

  void _drawEars(Canvas canvas) {
    canvas.drawOval(
      const Rect.fromLTWH(29, 30, 8, 13),
      _paint(_shade(_skin, 0.02)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(83, 30, 8, 13),
      _paint(_shade(_skin, 0.02)),
    );
  }

  void _drawBackHair(Canvas canvas) {
    final hair = _shade(_hair, 0.04);
    switch (profile.hairStyleIndex) {
      case 2:
      case 7:
      case 11:
      case 13:
        canvas.drawPath(
          Path()
            ..moveTo(31, 35)
            ..quadraticBezierTo(35, 6, 60, 6)
            ..quadraticBezierTo(86, 7, 90, 36)
            ..quadraticBezierTo(91, 59, 78, 72)
            ..lineTo(70, 59)
            ..quadraticBezierTo(60, 67, 50, 59)
            ..lineTo(42, 72)
            ..quadraticBezierTo(29, 59, 31, 35)
            ..close(),
          _paint(hair),
        );
      case 4:
      case 10:
        canvas.drawCircle(const Offset(43, 13), 8, _paint(hair));
        canvas.drawCircle(const Offset(77, 13), 8, _paint(hair));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(32, 12, 56, 30),
            const Radius.circular(22),
          ),
          _paint(hair),
        );
      case 5:
      case 9:
        for (final x in [34.0, 42.0, 50.0, 58.0, 66.0, 74.0, 82.0]) {
          canvas.drawCircle(Offset(x, 26), 7, _paint(hair));
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(32, 17, 56, 27),
            const Radius.circular(20),
          ),
          _paint(hair),
        );
      default:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(32, 10, 56, 34),
            const Radius.circular(24),
          ),
          _paint(hair),
        );
    }
  }

  void _drawFrontHair(Canvas canvas) {
    final hairRect = const Rect.fromLTWH(29, 6, 62, 40);
    final hairPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_tint(_hair, 0.12), _hair, _shade(_hair, 0.18)],
      ).createShader(hairRect);

    switch (profile.hairStyleIndex) {
      case 1:
        _drawSmoothCap(canvas, hairPaint, lowBang: true);
      case 2:
        _drawLongBang(canvas, hairPaint);
      case 3:
        _drawCenterPart(canvas, hairPaint);
      case 4:
        _drawSmoothCap(canvas, hairPaint);
        canvas.drawCircle(const Offset(60, 9), 8, hairPaint);
      case 5:
        _drawCurlyCap(canvas, hairPaint);
      case 6:
        _drawSidePart(canvas, hairPaint);
      case 7:
        _drawLongBang(canvas, hairPaint, wave: true);
      case 8:
        _drawAirBang(canvas, hairPaint);
      case 9:
        _drawCurlyCap(canvas, hairPaint, shortCurl: true);
      case 10:
        _drawSmoothCap(canvas, hairPaint);
        canvas.drawCircle(const Offset(43, 13), 7, hairPaint);
        canvas.drawCircle(const Offset(77, 13), 7, hairPaint);
      case 11:
        _drawSidePart(canvas, hairPaint);
        canvas.drawPath(
          Path()
            ..moveTo(78, 34)
            ..quadraticBezierTo(88, 52, 74, 68),
          Paint()
            ..shader = hairPaint.shader
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round,
        );
      case 12:
        _drawCatEarHair(canvas, hairPaint);
      case 13:
        _drawAcademyBraid(canvas, hairPaint);
      default:
        _drawSmoothCap(canvas, hairPaint);
    }

    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(46, 16), const Offset(58, 12), shine);
  }

  void _drawSmoothCap(Canvas canvas, Paint paint, {bool lowBang = false}) {
    canvas.drawPath(
      Path()
        ..moveTo(31, 34)
        ..quadraticBezierTo(34, 8, 60, 7)
        ..quadraticBezierTo(86, 8, 89, 34)
        ..quadraticBezierTo(76, 28, 68, 20)
        ..quadraticBezierTo(61, 35, 48, 34)
        ..quadraticBezierTo(42, 28, 31, 34)
        ..close(),
      paint,
    );
    if (lowBang) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(32, 16, 56, 18),
          const Radius.circular(12),
        ),
        paint,
      );
    }
  }

  void _drawLongBang(Canvas canvas, Paint paint, {bool wave = false}) {
    canvas.drawPath(
      Path()
        ..moveTo(30, 36)
        ..quadraticBezierTo(34, 7, 60, 7)
        ..quadraticBezierTo(85, 8, 90, 35)
        ..quadraticBezierTo(76, 27, 67, 21)
        ..quadraticBezierTo(60, 34, 49, 37)
        ..quadraticBezierTo(43, 28, 30, 36)
        ..close(),
      paint,
    );
    if (wave) {
      canvas.drawPath(
        Path()
          ..moveTo(84, 38)
          ..quadraticBezierTo(78, 54, 66, 64),
        Paint()
          ..shader = paint.shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawCenterPart(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(31, 36)
        ..quadraticBezierTo(34, 8, 59, 7)
        ..quadraticBezierTo(84, 8, 89, 36)
        ..lineTo(78, 29)
        ..lineTo(73, 43)
        ..quadraticBezierTo(61, 29, 50, 42)
        ..lineTo(45, 28)
        ..quadraticBezierTo(38, 35, 31, 36)
        ..close(),
      paint,
    );
    canvas.drawLine(
      const Offset(60, 10),
      const Offset(58, 37),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCurlyCap(Canvas canvas, Paint paint, {bool shortCurl = false}) {
    canvas.drawPath(
      Path()
        ..moveTo(30, 35)
        ..quadraticBezierTo(34, 13, 58, 8)
        ..quadraticBezierTo(82, 9, 90, 34)
        ..quadraticBezierTo(76, 28, 70, 36)
        ..quadraticBezierTo(60, 24, 50, 36)
        ..quadraticBezierTo(42, 27, 30, 35)
        ..close(),
      paint,
    );
    for (final x
        in shortCurl
            ? [40.0, 49.0, 58.0, 67.0, 76.0]
            : [38.0, 48.0, 58.0, 68.0]) {
      canvas.drawCircle(Offset(x, 24), shortCurl ? 4 : 4.5, paint);
    }
  }

  void _drawSidePart(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(31, 35)
        ..quadraticBezierTo(34, 7, 59, 7)
        ..quadraticBezierTo(84, 8, 90, 34)
        ..quadraticBezierTo(72, 26, 58, 22)
        ..quadraticBezierTo(49, 34, 34, 38)
        ..close(),
      paint,
    );
    canvas.drawLine(
      const Offset(58, 10),
      const Offset(48, 34),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawAirBang(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(31, 34)
        ..quadraticBezierTo(35, 7, 60, 7)
        ..quadraticBezierTo(84, 8, 89, 34)
        ..quadraticBezierTo(77, 29, 69, 22)
        ..quadraticBezierTo(63, 36, 54, 36)
        ..quadraticBezierTo(52, 25, 45, 37)
        ..quadraticBezierTo(40, 29, 31, 34)
        ..close(),
      paint,
    );
  }

  void _drawCatEarHair(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(35, 19)
        ..lineTo(43, 3)
        ..lineTo(50, 19)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(70, 19)
        ..lineTo(77, 3)
        ..lineTo(85, 19)
        ..close(),
      paint,
    );
    _drawSmoothCap(canvas, paint);
  }

  void _drawAcademyBraid(Canvas canvas, Paint paint) {
    _drawSidePart(canvas, paint);
    canvas.drawPath(
      Path()
        ..moveTo(79, 35)
        ..quadraticBezierTo(72, 50, 62, 66),
      Paint()
        ..shader = paint.shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    for (final point in const [
      Offset(74, 43),
      Offset(69, 51),
      Offset(65, 59),
    ]) {
      canvas.drawCircle(point, 2.5, paint);
    }
  }

  void _drawFace(Canvas canvas) {
    _drawEyebrows(canvas);
    _drawEyes(canvas);
    _drawNose(canvas);
    _drawMouth(canvas);
  }

  void _drawEyebrows(Canvas canvas) {
    final paint = Paint()
      ..color = _shade(_hair, 0.35)
      ..strokeWidth = profile.eyebrowStyleIndex == 1 ? 2.4 : 1.8
      ..strokeCap = StrokeCap.round;

    switch (profile.eyebrowStyleIndex) {
      case 2:
        canvas.drawLine(const Offset(45, 36), const Offset(52, 33.5), paint);
        canvas.drawLine(const Offset(68, 33.5), const Offset(75, 36), paint);
      case 3:
        canvas.drawLine(const Offset(45, 35), const Offset(53, 35), paint);
        canvas.drawLine(const Offset(67, 35), const Offset(75, 35), paint);
      case 4:
        canvas.drawArc(
          const Rect.fromLTWH(44, 33, 10, 6),
          3.2,
          2.3,
          false,
          paint,
        );
        canvas.drawArc(
          const Rect.fromLTWH(66, 33, 10, 6),
          3.8,
          2.3,
          false,
          paint,
        );
      case 6:
        canvas.drawArc(
          const Rect.fromLTWH(44, 36, 10, 6),
          3.6,
          2.1,
          false,
          paint,
        );
        canvas.drawArc(
          const Rect.fromLTWH(66, 36, 10, 6),
          3.6,
          2.1,
          false,
          paint,
        );
      case 7:
        canvas.drawLine(const Offset(44, 37), const Offset(53, 33), paint);
        canvas.drawLine(const Offset(67, 33), const Offset(76, 37), paint);
      case 8:
        canvas.drawLine(const Offset(46, 35), const Offset(51, 35.3), paint);
        canvas.drawLine(const Offset(69, 35.3), const Offset(74, 35), paint);
      case 9:
        canvas.drawArc(
          const Rect.fromLTWH(44, 33, 10, 6),
          3.1,
          2.5,
          false,
          paint,
        );
        canvas.drawArc(
          const Rect.fromLTWH(66, 33, 10, 6),
          3.7,
          2.5,
          false,
          paint,
        );
      default:
        canvas.drawLine(const Offset(45, 34.5), const Offset(53, 36), paint);
        canvas.drawLine(const Offset(67, 36), const Offset(75, 34.5), paint);
    }
  }

  void _drawEyes(Canvas canvas) {
    final eye = Paint()..color = const Color(0xFF111827);
    final shine = Paint()..color = Colors.white.withValues(alpha: 0.82);
    final stroke = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    void roundEye(double x) {
      canvas.drawOval(Rect.fromLTWH(x, 38, 6.4, 8.2), eye);
      canvas.drawCircle(Offset(x + 2, 40.3), 1.1, shine);
    }

    switch (profile.eyeStyleIndex) {
      case 1:
        canvas.drawArc(
          const Rect.fromLTWH(43, 39, 11, 6),
          0.1,
          2.9,
          false,
          stroke,
        );
        canvas.drawArc(
          const Rect.fromLTWH(66, 39, 11, 6),
          0.1,
          2.9,
          false,
          stroke,
        );
      case 2:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(43, 40, 10, 4),
            const Radius.circular(999),
          ),
          eye,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(67, 40, 10, 4),
            const Radius.circular(999),
          ),
          eye,
        );
      case 3:
        canvas.drawOval(const Rect.fromLTWH(42, 37, 8, 10), eye);
        canvas.drawOval(const Rect.fromLTWH(70, 37, 8, 10), eye);
        canvas.drawCircle(const Offset(44.5, 39.7), 1.2, shine);
        canvas.drawCircle(const Offset(72.5, 39.7), 1.2, shine);
      case 4:
        _drawStarEye(canvas, const Offset(46, 42), eye, shine);
        _drawStarEye(canvas, const Offset(74, 42), eye, shine);
      case 5:
        canvas.drawOval(const Rect.fromLTWH(42, 39, 9, 6), eye);
        canvas.drawOval(const Rect.fromLTWH(69, 39, 9, 6), eye);
        canvas.drawLine(const Offset(41.5, 38), const Offset(44, 36.5), stroke);
        canvas.drawLine(const Offset(78.5, 38), const Offset(76, 36.5), stroke);
      case 6:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(42.5, 38.5, 9, 7.5),
            const Radius.circular(4),
          ),
          eye,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(68.5, 38.5, 9, 7.5),
            const Radius.circular(4),
          ),
          eye,
        );
      case 7:
        canvas.drawOval(const Rect.fromLTWH(41.5, 37, 9, 11), eye);
        canvas.drawOval(const Rect.fromLTWH(69.5, 37, 9, 11), eye);
        canvas.drawCircle(const Offset(44, 39.5), 1.6, shine);
        canvas.drawCircle(const Offset(72, 39.5), 1.6, shine);
      case 8:
        canvas.drawArc(
          const Rect.fromLTWH(42, 39.5, 10, 6),
          3.1,
          3.0,
          false,
          stroke,
        );
        canvas.drawArc(
          const Rect.fromLTWH(68, 39.5, 10, 6),
          3.1,
          3.0,
          false,
          stroke,
        );
      case 9:
        canvas.drawPath(
          Path()
            ..moveTo(41.5, 42)
            ..quadraticBezierTo(46, 36.5, 52.5, 41.8)
            ..quadraticBezierTo(46.5, 46, 41.5, 42),
          eye,
        );
        canvas.drawPath(
          Path()
            ..moveTo(78.5, 42)
            ..quadraticBezierTo(74, 36.5, 67.5, 41.8)
            ..quadraticBezierTo(73.5, 46, 78.5, 42),
          eye,
        );
      default:
        roundEye(43.5);
        roundEye(70);
    }
  }

  void _drawStarEye(Canvas canvas, Offset center, Paint eye, Paint shine) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final radius = i.isEven ? 4.2 : 1.8;
      final angle = -math.pi / 2 + i * math.pi / 4;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, eye);
    canvas.drawCircle(center.translate(-0.8, -0.8), 0.9, shine);
  }

  void _drawNose(Canvas canvas) {
    canvas.drawArc(
      const Rect.fromLTWH(57, 43, 6, 8),
      -0.7,
      1.55,
      false,
      Paint()
        ..color = const Color(0xFF7C4A35).withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawMouth(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF8A2E2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = const Color(0xFFC85A5A);

    switch (profile.mouthStyleIndex) {
      case 1:
        canvas.drawArc(
          const Rect.fromLTWH(52, 50, 16, 8),
          0.1,
          2.95,
          false,
          paint,
        );
      case 2:
        canvas.drawLine(const Offset(53, 55), const Offset(67, 55), paint);
      case 3:
        canvas.drawOval(const Rect.fromLTWH(56, 52.5, 8, 4.5), fill);
      case 4:
        canvas.drawArc(
          const Rect.fromLTWH(53, 50.5, 14, 7),
          0.1,
          2.9,
          false,
          paint,
        );
        canvas.drawCircle(const Offset(66, 54), 1.2, fill);
      case 5:
        canvas.drawOval(const Rect.fromLTWH(56.5, 51.5, 7, 7.8), fill);
        canvas.drawOval(
          const Rect.fromLTWH(58, 52.8, 3.5, 4.2),
          _paint(Colors.white.withValues(alpha: 0.24)),
        );
      case 6:
        canvas.drawArc(
          const Rect.fromLTWH(51.5, 49.5, 17, 10),
          0.05,
          3.05,
          false,
          paint..strokeWidth = 2.1,
        );
        canvas.drawLine(
          const Offset(55, 55),
          const Offset(65, 55),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.50)
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
        );
      case 7:
        canvas.drawArc(
          const Rect.fromLTWH(53, 51, 14, 7),
          0.2,
          2.7,
          false,
          paint,
        );
        canvas.drawCircle(
          const Offset(52, 53.5),
          1.3,
          _paint(const Color(0xFFEF8F8F).withValues(alpha: 0.44)),
        );
      case 8:
        canvas.drawLine(const Offset(55, 54.5), const Offset(65, 54.5), paint);
        canvas.drawCircle(const Offset(60, 54.5), 1.2, fill);
      case 9:
        canvas.drawArc(
          const Rect.fromLTWH(53.5, 51, 13, 8),
          0.2,
          2.8,
          false,
          paint,
        );
        canvas.drawLine(const Offset(63.8, 52), const Offset(67, 50.7), paint);
      default:
        canvas.drawArc(
          const Rect.fromLTWH(52, 50, 16, 9),
          0.1,
          2.95,
          false,
          paint,
        );
    }
  }

  void _drawAccessory(Canvas canvas) {
    switch (profile.accessoryIndex) {
      case 1:
        _drawSparkles(canvas, const Offset(84, 22), const Color(0xFFF59E0B));
      case 2:
        _drawHeadphones(canvas);
      case 3:
        _drawBook(canvas);
      case 4:
        _drawSparkles(
          canvas,
          const Offset(84, 22),
          const Color(0xFFFACC15),
          starOnly: true,
        );
      case 5:
        _drawGlasses(canvas);
      case 6:
        _drawBow(canvas);
      case 7:
        _drawBackpack(canvas);
      case 8:
        _drawCoffee(canvas);
      case 9:
        _drawMoonBadge(canvas);
      case 10:
        _drawTowel(canvas);
      case 11:
        _drawTimer(canvas);
      case 12:
        _drawMagicPen(canvas);
      case 13:
        _drawCrown(canvas);
    }
  }

  void _drawSparkles(
    Canvas canvas,
    Offset center,
    Color color, {
    bool starOnly = false,
  }) {
    final paint = _paint(color);
    void star(Offset c, double r) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 0.35, c.dy - r * 0.35)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx + r * 0.35, c.dy + r * 0.35)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r * 0.35, c.dy + r * 0.35)
          ..lineTo(c.dx - r, c.dy)
          ..lineTo(c.dx - r * 0.35, c.dy - r * 0.35)
          ..close(),
        paint,
      );
    }

    star(center, 5);
    if (!starOnly) {
      canvas.drawCircle(center.translate(-9, 9), 1.8, paint);
      canvas.drawCircle(center.translate(8, 12), 1.4, paint);
    }
  }

  void _drawHeadphones(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      const Rect.fromLTWH(34, 18, 52, 48),
      math.pi * 1.08,
      math.pi * 0.84,
      false,
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(31, 40, 7, 15),
        const Radius.circular(4),
      ),
      _paint(const Color(0xFF334155)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(82, 40, 7, 15),
        const Radius.circular(4),
      ),
      _paint(const Color(0xFF334155)),
    );
  }

  void _drawBook(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(82, 49, 15, 12),
        const Radius.circular(3),
      ),
      _paint(const Color(0xFF4F8CFF)),
    );
    canvas.drawLine(
      const Offset(89.5, 51),
      const Offset(89.5, 59),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.70)
        ..strokeWidth = 1,
    );
  }

  void _drawGlasses(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 38, 15, 9),
        const Radius.circular(5),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(65, 38, 15, 9),
        const Radius.circular(5),
      ),
      paint,
    );
    canvas.drawLine(const Offset(55, 42), const Offset(65, 42), paint);
  }

  void _drawBow(Canvas canvas) {
    final paint = _paint(const Color(0xFFEC4899));
    canvas.drawCircle(const Offset(80, 20), 3, paint);
    canvas.drawPath(
      Path()
        ..moveTo(80, 20)
        ..quadraticBezierTo(68, 12, 69, 24)
        ..quadraticBezierTo(74, 22, 80, 20)
        ..quadraticBezierTo(92, 12, 91, 24)
        ..quadraticBezierTo(86, 22, 80, 20),
      paint,
    );
  }

  void _drawBackpack(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(88, 59, 10, 20),
        const Radius.circular(4),
      ),
      _paint(const Color(0xFF14B8A6)),
    );
  }

  void _drawCoffee(Canvas canvas) {
    final cup = _paint(const Color(0xFF92400E));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(84, 73, 12, 10),
        const Radius.circular(3),
      ),
      cup,
    );
    canvas.drawArc(
      const Rect.fromLTWH(93, 75, 8, 6),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF92400E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawMoonBadge(Canvas canvas) {
    canvas.drawCircle(const Offset(85, 24), 6, _paint(const Color(0xFF8B5CF6)));
    canvas.drawCircle(const Offset(88, 22), 5, _paint(profile.backgroundColor));
  }

  void _drawTowel(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(78, 59, 18, 8),
        const Radius.circular(4),
      ),
      _paint(const Color(0xFF10B981)),
    );
  }

  void _drawTimer(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(const Offset(86, 24), 6, paint);
    canvas.drawLine(const Offset(86, 24), const Offset(86, 20), paint);
    canvas.drawLine(const Offset(86, 24), const Offset(90, 24), paint);
  }

  void _drawMagicPen(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF4F8CFF)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(82, 70), const Offset(94, 58), paint);
    _drawSparkles(
      canvas,
      const Offset(96, 56),
      const Color(0xFFFACC15),
      starOnly: true,
    );
  }

  void _drawCrown(Canvas canvas) {
    final paint = _paint(const Color(0xFFF59E0B));
    canvas.drawPath(
      Path()
        ..moveTo(43, 12)
        ..lineTo(50, 4)
        ..lineTo(60, 13)
        ..lineTo(70, 4)
        ..lineTo(77, 12)
        ..lineTo(75, 20)
        ..lineTo(45, 20)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _NudgeAvatarPainter oldDelegate) {
    return oldDelegate.profile != profile;
  }
}
