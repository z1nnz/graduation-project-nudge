import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/avatar_profile.dart';

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

        final layers = paths.ordered
            .where(assets.contains)
            .map(
              (path) => Positioned.fill(
                child: Image.asset(path, fit: BoxFit.contain),
              ),
            )
            .toList();

        if (layers.isEmpty) {
          return _wrapCharacter(_buildPaintedCharacter());
        }

        return _wrapCharacter(Stack(clipBehavior: Clip.none, children: layers));
      },
    );
  }

  Widget _buildPaintedCharacter() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(size: Size.square(size), painter: _AvatarPainter(profile)),
        Positioned(
          top: size * 0.13,
          right: size * 0.12,
          child: _AvatarAccessory(
            accessoryIndex: profile.accessoryIndex,
            size: size,
          ),
        ),
      ],
    );
  }

  Widget _wrapCharacter(Widget character) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: showBackgroundRing ? BoxShape.circle : BoxShape.rectangle,
        color: showBackgroundRing
            ? profile.backgroundColor
            : Colors.transparent,
        border: showBackgroundRing
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.9),
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

  String get background =>
      'assets/avatar/backgrounds/background_${profile.backgroundColorIndex}.png';

  String get body =>
      'assets/avatar/base/body_skin_${profile.skinToneIndex}.png';

  String get face =>
      'assets/avatar/faces/face_${profile.faceShapeIndex}_skin_${profile.skinToneIndex}.png';

  String get hairBack =>
      'assets/avatar/hair_back/hair_${profile.hairStyleIndex}_color_${profile.hairColorIndex}.png';

  String get hairFront =>
      'assets/avatar/hair_front/hair_${profile.hairStyleIndex}_color_${profile.hairColorIndex}.png';

  String get eyes => 'assets/avatar/eyes/eyes_${profile.eyeStyleIndex}.png';

  String get eyebrows =>
      'assets/avatar/eyebrows/eyebrows_${profile.eyebrowStyleIndex}.png';

  String get mouth =>
      'assets/avatar/mouths/mouth_${profile.mouthStyleIndex}.png';

  String get outfit =>
      'assets/avatar/outfits/outfit_${profile.outfitStyleIndex}_color_${profile.outfitColorIndex}.png';

  String get accessory =>
      'assets/avatar/accessories/accessory_${profile.accessoryIndex}.png';

  List<String> get ordered {
    return [
      background,
      hairBack,
      body,
      face,
      outfit,
      eyes,
      eyebrows,
      mouth,
      hairFront,
      accessory,
    ];
  }

  List<String> get requiredLayers {
    return [hairBack, body, face, outfit, eyes, eyebrows, mouth, hairFront];
  }
}

class _AvatarPainter extends CustomPainter {
  final AvatarProfile profile;

  const _AvatarPainter(this.profile);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final skin = profile.skinTone;
    final hair = profile.hairColor;
    final outfit = profile.outfitColor;
    final pants = Color.lerp(outfit, const Color(0xFF172033), 0.52)!;
    final shoe = Color.lerp(pants, Colors.black, 0.52)!;
    final line = Color.lerp(hair, Colors.black, 0.35)!;

    canvas.save();
    canvas.scale(s / 100, s / 100);

    _drawShadow(canvas);
    _drawLegs(canvas, pants, shoe);
    _drawArms(canvas, skin, outfit);
    _drawBody(canvas, outfit);
    _drawNeck(canvas, skin);
    _drawHead(canvas, skin);
    _drawEars(canvas, skin);
    _drawHairBack(canvas, hair);
    _drawFaceFeatures(canvas, line);
    _drawHairFront(canvas, hair);
    _drawOutfitDetails(canvas, outfit);

    canvas.restore();
  }

  void _drawShadow(Canvas canvas) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.12);
    canvas.drawOval(const Rect.fromLTWH(31, 91, 38, 7), paint);
  }

  void _drawLegs(Canvas canvas, Color pants, Color shoe) {
    final legPaint = Paint()..color = pants;
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final shoePaint = Paint()..color = shoe;

    final leftLeg = RRect.fromRectAndRadius(
      const Rect.fromLTWH(37, 68, 10.5, 22),
      const Radius.circular(4.5),
    );
    final rightLeg = RRect.fromRectAndRadius(
      const Rect.fromLTWH(52.5, 68, 10.5, 22),
      const Radius.circular(4.5),
    );
    canvas.drawRRect(leftLeg, legPaint);
    canvas.drawRRect(rightLeg, legPaint);
    canvas.drawLine(const Offset(40.5, 70), const Offset(40.5, 86), shinePaint);
    canvas.drawLine(const Offset(56, 70), const Offset(56, 86), shinePaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(34.5, 87.5, 15, 5.5),
        const Radius.circular(3),
      ),
      shoePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(51, 87.5, 15, 5.5),
        const Radius.circular(3),
      ),
      shoePaint,
    );
  }

  void _drawArms(Canvas canvas, Color skin, Color outfit) {
    final sleevePaint = Paint()
      ..color = Color.lerp(outfit, Colors.white, 0.06)!;
    final skinPaint = Paint()..color = skin;

    final leftArm = Path()
      ..moveTo(31, 50)
      ..cubicTo(24, 54, 22, 64, 25, 73)
      ..cubicTo(27, 78, 34, 76, 33, 70)
      ..cubicTo(32, 63, 34, 57, 38, 53)
      ..close();
    final rightArm = Path()
      ..moveTo(69, 50)
      ..cubicTo(76, 54, 78, 64, 75, 73)
      ..cubicTo(73, 78, 66, 76, 67, 70)
      ..cubicTo(68, 63, 66, 57, 62, 53)
      ..close();

    canvas.drawPath(leftArm, sleevePaint);
    canvas.drawPath(rightArm, sleevePaint);
    canvas.drawCircle(const Offset(28.7, 75.5), 4.1, skinPaint);
    canvas.drawCircle(const Offset(71.3, 75.5), 4.1, skinPaint);
  }

  void _drawBody(Canvas canvas, Color outfit) {
    final body = Path()
      ..moveTo(34, 47)
      ..quadraticBezierTo(50, 40, 66, 47)
      ..lineTo(70, 71)
      ..quadraticBezierTo(70.5, 78, 63, 79)
      ..lineTo(37, 79)
      ..quadraticBezierTo(29.5, 78, 30, 71)
      ..lineTo(34, 47)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(outfit, Colors.white, 0.16)!,
          outfit,
          Color.lerp(outfit, Colors.black, 0.12)!,
        ],
      ).createShader(const Rect.fromLTWH(28, 42, 44, 40));
    canvas.drawPath(body, paint);

    final trimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(41, 47), const Offset(50, 53), trimPaint);
    canvas.drawLine(const Offset(59, 47), const Offset(50, 53), trimPaint);

    final badgePaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    switch (profile.outfitStyleIndex) {
      case 1:
        canvas.drawCircle(const Offset(50, 62), 5.5, badgePaint);
      case 2:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(42, 59, 16, 9),
            const Radius.circular(3),
          ),
          badgePaint,
        );
      case 3:
        canvas.drawPath(
          Path()
            ..moveTo(40, 59)
            ..lineTo(50, 66)
            ..lineTo(60, 59)
            ..lineTo(58, 70)
            ..lineTo(42, 70)
            ..close(),
          badgePaint,
        );
      case 4:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(39, 53, 22, 18),
            const Radius.circular(5),
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      case 5:
        canvas.drawLine(
          const Offset(50, 51),
          const Offset(50, 73),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.32)
            ..strokeWidth = 1.4,
        );
        for (final y in [56.0, 62.0, 68.0]) {
          canvas.drawCircle(Offset(50, y), 1.4, badgePaint);
        }
      case 6:
        canvas.drawPath(
          Path()
            ..moveTo(38, 58)
            ..quadraticBezierTo(50, 52, 62, 58)
            ..lineTo(62, 63)
            ..quadraticBezierTo(50, 58, 38, 63)
            ..close(),
          badgePaint,
        );
      case 7:
        canvas.drawOval(const Rect.fromLTWH(43, 56, 14, 6), badgePaint);
        canvas.drawLine(
          const Offset(43, 61),
          const Offset(57, 61),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.26)
            ..strokeWidth = 1.2,
        );
      default:
        canvas.drawCircle(const Offset(58, 58), 2.2, badgePaint);
        canvas.drawCircle(const Offset(58, 66), 2.2, badgePaint);
    }
  }

  void _drawOutfitDetails(Canvas canvas, Color outfit) {
    final pocketPaint = Paint()
      ..color = Color.lerp(outfit, Colors.black, 0.10)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      const Rect.fromLTWH(39, 64, 9, 8),
      0.1,
      2.8,
      false,
      pocketPaint,
    );
    canvas.drawArc(
      const Rect.fromLTWH(52, 64, 9, 8),
      0.25,
      2.8,
      false,
      pocketPaint,
    );
  }

  void _drawNeck(Canvas canvas, Color skin) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(45.5, 40.5, 9, 9),
        const Radius.circular(4),
      ),
      Paint()..color = Color.lerp(skin, Colors.black, 0.04)!,
    );
  }

  void _drawEars(Canvas canvas, Color skin) {
    final paint = Paint()..color = Color.lerp(skin, Colors.black, 0.02)!;
    canvas.drawOval(const Rect.fromLTWH(27.5, 27.8, 8, 12), paint);
    canvas.drawOval(const Rect.fromLTWH(64.5, 27.8, 8, 12), paint);
  }

  void _drawHead(Canvas canvas, Color skin) {
    final rect = switch (profile.faceShapeIndex) {
      1 => const Rect.fromLTWH(31, 12, 38, 39),
      2 => const Rect.fromLTWH(28.5, 15, 43, 36),
      3 => const Rect.fromLTWH(32, 15, 36, 36),
      4 => const Rect.fromLTWH(30, 13.5, 40, 38),
      5 => const Rect.fromLTWH(29, 14, 42, 37),
      _ => const Rect.fromLTWH(29.5, 13, 41, 39),
    };
    final radius = switch (profile.faceShapeIndex) {
      2 => const Radius.circular(13),
      3 => const Radius.circular(19),
      4 => const Radius.circular(24),
      5 => const Radius.circular(11),
      _ => const Radius.circular(21),
    };

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(skin, Colors.white, 0.18)!,
          skin,
          Color.lerp(skin, Colors.black, 0.06)!,
        ],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);

    final blushPaint = Paint()
      ..color = const Color(0xFFEF8F8F).withValues(alpha: 0.18);
    canvas.drawOval(const Rect.fromLTWH(34.5, 34.5, 7, 3.5), blushPaint);
    canvas.drawOval(const Rect.fromLTWH(58.5, 34.5, 7, 3.5), blushPaint);
  }

  void _drawHairBack(Canvas canvas, Color hair) {
    final paint = Paint()..color = Color.lerp(hair, Colors.black, 0.04)!;
    switch (profile.hairStyleIndex) {
      case 1:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 11, 44, 24),
            const Radius.circular(18),
          ),
          paint,
        );
      case 2:
        canvas.drawPath(
          Path()
            ..moveTo(29, 25)
            ..quadraticBezierTo(32, 6, 50, 8)
            ..quadraticBezierTo(69, 8, 72, 27)
            ..quadraticBezierTo(68, 45, 60, 51)
            ..lineTo(40, 51)
            ..quadraticBezierTo(31, 45, 29, 25)
            ..close(),
          paint,
        );
      case 3:
        canvas.drawPath(
          Path()
            ..moveTo(30, 26)
            ..quadraticBezierTo(32, 10, 48, 8)
            ..quadraticBezierTo(65, 9, 70, 24)
            ..lineTo(68, 44)
            ..quadraticBezierTo(62, 51, 51, 51)
            ..quadraticBezierTo(38, 50, 32, 43)
            ..close(),
          paint,
        );
      case 4:
        canvas.drawPath(
          Path()
            ..moveTo(31, 24)
            ..quadraticBezierTo(35, 7, 50, 7)
            ..quadraticBezierTo(66, 8, 70, 24)
            ..quadraticBezierTo(70, 39, 62, 45)
            ..lineTo(58, 36)
            ..quadraticBezierTo(50, 42, 42, 36)
            ..lineTo(38, 45)
            ..quadraticBezierTo(31, 39, 31, 24)
            ..close(),
          paint,
        );
        canvas.drawCircle(const Offset(50, 8.5), 7.5, paint);
      case 5:
        for (final x in [32.0, 38.0, 44.0, 50.0, 56.0, 62.0, 68.0]) {
          canvas.drawCircle(Offset(x, 19), 6.2, paint);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(29, 16, 42, 20),
            const Radius.circular(18),
          ),
          paint,
        );
      case 6:
        canvas.drawPath(
          Path()
            ..moveTo(29, 25)
            ..quadraticBezierTo(31, 8, 48, 8)
            ..quadraticBezierTo(67, 8, 72, 24)
            ..lineTo(71, 47)
            ..quadraticBezierTo(60, 50, 52, 43)
            ..lineTo(48, 19)
            ..quadraticBezierTo(39, 28, 29, 25)
            ..close(),
          paint,
        );
      case 7:
        canvas.drawPath(
          Path()
            ..moveTo(28, 27)
            ..quadraticBezierTo(31, 7, 50, 7)
            ..quadraticBezierTo(69, 8, 72, 27)
            ..quadraticBezierTo(74, 45, 65, 56)
            ..lineTo(58, 48)
            ..quadraticBezierTo(50, 53, 42, 48)
            ..lineTo(35, 56)
            ..quadraticBezierTo(26, 45, 28, 27)
            ..close(),
          paint,
        );
      default:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(29, 10, 42, 25),
            const Radius.circular(18),
          ),
          paint,
        );
    }
  }

  void _drawHairFront(Canvas canvas, Color hair) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(hair, Colors.white, 0.10)!,
          hair,
          Color.lerp(hair, Colors.black, 0.18)!,
        ],
      ).createShader(const Rect.fromLTWH(27, 7, 46, 31));

    switch (profile.hairStyleIndex) {
      case 1:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(28.5, 10.5, 43, 19),
            const Radius.circular(15),
          ),
          paint,
        );
        _drawHairShine(canvas, const Offset(39, 15), const Offset(49, 12));
      case 2:
        final path = Path()
          ..moveTo(29, 25)
          ..quadraticBezierTo(34, 8, 51, 8)
          ..quadraticBezierTo(66, 9, 71, 24)
          ..quadraticBezierTo(63, 20, 56, 16)
          ..quadraticBezierTo(52, 25, 43, 29)
          ..quadraticBezierTo(38, 24, 29, 25)
          ..close();
        canvas.drawPath(path, paint);
        _drawHairShine(canvas, const Offset(42, 13), const Offset(52, 11));
      case 3:
        final path = Path()
          ..moveTo(30, 27)
          ..quadraticBezierTo(33, 9, 50, 8)
          ..quadraticBezierTo(66, 9, 70, 25)
          ..lineTo(62, 21)
          ..lineTo(58, 31)
          ..quadraticBezierTo(50, 23, 43, 28)
          ..lineTo(39, 20)
          ..quadraticBezierTo(35, 25, 30, 27)
          ..close();
        canvas.drawPath(path, paint);
        final partPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(49, 10), const Offset(47, 29), partPaint);
      case 4:
        final path = Path()
          ..moveTo(33, 27)
          ..quadraticBezierTo(39, 11, 51, 10)
          ..quadraticBezierTo(62, 11, 68, 27)
          ..quadraticBezierTo(61, 23, 56, 18)
          ..quadraticBezierTo(50, 27, 40, 27)
          ..quadraticBezierTo(37, 23, 33, 27)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawCircle(const Offset(50, 10), 6.6, paint);
        _drawHairShine(canvas, const Offset(45, 10), const Offset(52, 8.5));
      case 5:
        final path = Path()
          ..moveTo(29, 26)
          ..quadraticBezierTo(33, 12, 48, 9)
          ..quadraticBezierTo(63, 9, 70, 24)
          ..quadraticBezierTo(60, 21, 56, 26)
          ..quadraticBezierTo(50, 20, 43, 27)
          ..quadraticBezierTo(37, 22, 29, 26)
          ..close();
        canvas.drawPath(path, paint);
        for (final x in [35.0, 43.0, 51.0, 59.0]) {
          canvas.drawCircle(Offset(x, 18), 3.6, paint);
        }
      case 6:
        final path = Path()
          ..moveTo(29, 26)
          ..quadraticBezierTo(32, 8, 50, 8)
          ..quadraticBezierTo(67, 8, 71, 24)
          ..quadraticBezierTo(59, 18, 48, 17)
          ..quadraticBezierTo(41, 24, 31, 28)
          ..close();
        canvas.drawPath(path, paint);
        final partPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.16)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(48, 10), const Offset(42, 26), partPaint);
      case 7:
        final path = Path()
          ..moveTo(28, 27)
          ..quadraticBezierTo(31, 8, 50, 8)
          ..quadraticBezierTo(68, 9, 72, 27)
          ..quadraticBezierTo(61, 22, 55, 17)
          ..quadraticBezierTo(48, 27, 38, 28)
          ..quadraticBezierTo(33, 24, 28, 27)
          ..close();
        canvas.drawPath(path, paint);
        _drawHairShine(canvas, const Offset(42, 13), const Offset(53, 10));
      default:
        final path = Path()
          ..moveTo(29, 26)
          ..quadraticBezierTo(31, 9, 50, 8)
          ..quadraticBezierTo(69, 9, 71, 26)
          ..lineTo(66, 23)
          ..quadraticBezierTo(60, 30, 50, 29)
          ..quadraticBezierTo(41, 30, 34, 23)
          ..close();
        canvas.drawPath(path, paint);
        _drawHairShine(canvas, const Offset(39, 14), const Offset(49, 12));
    }
  }

  void _drawHairShine(Canvas canvas, Offset from, Offset to) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
  }

  void _drawFaceFeatures(Canvas canvas, Color line) {
    _drawEyebrows(canvas, line);
    _drawEyes(canvas, line);
    _drawNose(canvas);
    _drawMouth(canvas);
  }

  void _drawEyebrows(Canvas canvas, Color line) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = profile.eyebrowStyleIndex == 1 ? 2.1 : 1.5
      ..strokeCap = StrokeCap.round;

    switch (profile.eyebrowStyleIndex) {
      case 2:
        canvas.drawLine(const Offset(37, 29), const Offset(44, 27), paint);
        canvas.drawLine(const Offset(56, 27), const Offset(63, 29), paint);
      case 3:
        canvas.drawLine(
          const Offset(37.5, 28.5),
          const Offset(44, 28.5),
          paint,
        );
        canvas.drawLine(
          const Offset(56, 28.5),
          const Offset(62.5, 28.5),
          paint,
        );
      case 4:
        canvas.drawArc(
          const Rect.fromLTWH(36.5, 26.5, 8, 5),
          3.25,
          2.2,
          false,
          paint,
        );
        canvas.drawArc(
          const Rect.fromLTWH(55.5, 26.5, 8, 5),
          3.85,
          2.2,
          false,
          paint,
        );
      case 5:
        canvas.drawLine(const Offset(37, 28), const Offset(45, 27.2), paint);
        canvas.drawLine(const Offset(55, 27.2), const Offset(63, 28), paint);
      default:
        canvas.drawLine(const Offset(37, 27.5), const Offset(44, 29), paint);
        canvas.drawLine(const Offset(56, 29), const Offset(63, 27.5), paint);
    }
  }

  void _drawEyes(Canvas canvas, Color line) {
    final paint = Paint()..color = const Color(0xFF111827);
    final shine = Paint()..color = Colors.white.withValues(alpha: 0.74);
    final stroke = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    void roundEye(double x) {
      canvas.drawOval(Rect.fromLTWH(x, 31.2, 5.2, 7.1), paint);
      canvas.drawCircle(Offset(x + 1.7, 33.2), 0.9, shine);
    }

    switch (profile.eyeStyleIndex) {
      case 1:
        canvas.drawArc(
          const Rect.fromLTWH(36.5, 31, 8, 5),
          0.15,
          2.8,
          false,
          stroke,
        );
        canvas.drawArc(
          const Rect.fromLTWH(55.5, 31, 8, 5),
          0.15,
          2.8,
          false,
          stroke,
        );
      case 2:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(36.5, 32.4, 7.5, 3.7),
            const Radius.circular(999),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(56, 32.4, 7.5, 3.7),
            const Radius.circular(999),
          ),
          paint,
        );
      case 3:
        canvas.drawOval(const Rect.fromLTWH(36, 30.8, 6.6, 8.3), paint);
        canvas.drawOval(const Rect.fromLTWH(57.4, 30.8, 6.6, 8.3), paint);
        canvas.drawCircle(const Offset(38, 33.1), 1, shine);
        canvas.drawCircle(const Offset(59.4, 33.1), 1, shine);
      case 4:
        canvas.drawPath(
          Path()
            ..moveTo(36, 34.5)
            ..lineTo(39, 31)
            ..lineTo(42, 34.5)
            ..lineTo(39, 38)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(58, 34.5)
            ..lineTo(61, 31)
            ..lineTo(64, 34.5)
            ..lineTo(61, 38)
            ..close(),
          paint,
        );
        canvas.drawCircle(const Offset(38.4, 33.5), 0.9, shine);
        canvas.drawCircle(const Offset(60.4, 33.5), 0.9, shine);
      case 5:
        canvas.drawOval(const Rect.fromLTWH(36, 32, 7, 5.5), paint);
        canvas.drawOval(const Rect.fromLTWH(57, 32, 7, 5.5), paint);
        canvas.drawLine(
          const Offset(35.5, 31.5),
          const Offset(37.5, 30),
          stroke,
        );
        canvas.drawLine(
          const Offset(64.5, 31.5),
          const Offset(62.5, 30),
          stroke,
        );
      default:
        roundEye(37);
        roundEye(57.8);
    }
  }

  void _drawNose(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF7C4A35).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(const Rect.fromLTWH(48, 35, 5, 6), -0.7, 1.6, false, paint);
  }

  void _drawMouth(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF8A2E2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = const Color(0xFFB94A48);

    switch (profile.mouthStyleIndex) {
      case 1:
        canvas.drawArc(
          const Rect.fromLTWH(44, 39.5, 12, 7),
          0.15,
          2.8,
          false,
          paint,
        );
      case 2:
        canvas.drawLine(const Offset(45.5, 43), const Offset(54.5, 43), paint);
      case 3:
        canvas.drawOval(const Rect.fromLTWH(47.2, 41, 5.6, 3.8), fill);
      case 4:
        canvas.drawArc(
          const Rect.fromLTWH(44.5, 39.2, 11, 6),
          0.1,
          2.9,
          false,
          paint,
        );
        canvas.drawCircle(const Offset(54.6, 42.7), 1, fill);
      case 5:
        canvas.drawOval(const Rect.fromLTWH(47.3, 40.2, 5.4, 6.4), fill);
        canvas.drawOval(
          const Rect.fromLTWH(48.5, 41.2, 3, 3.8),
          Paint()..color = Colors.white.withValues(alpha: 0.28),
        );
      default:
        canvas.drawArc(
          const Rect.fromLTWH(43.5, 38.5, 13, 8),
          0.1,
          2.95,
          false,
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) {
    return oldDelegate.profile != profile;
  }
}

class _AvatarAccessory extends StatelessWidget {
  final int accessoryIndex;
  final double size;

  const _AvatarAccessory({required this.accessoryIndex, required this.size});

  @override
  Widget build(BuildContext context) {
    switch (accessoryIndex) {
      case 1:
        return Icon(
          Icons.auto_awesome,
          size: size * 0.13,
          color: const Color(0xFFF59E0B),
        );
      case 2:
        return Icon(
          Icons.headphones,
          size: size * 0.15,
          color: const Color(0xFF334155),
        );
      case 3:
        return Icon(
          Icons.menu_book_rounded,
          size: size * 0.13,
          color: const Color(0xFF4F8CFF),
        );
      case 4:
        return Icon(
          Icons.star_rounded,
          size: size * 0.14,
          color: const Color(0xFFFACC15),
        );
      case 5:
        return Icon(
          Icons.remove_red_eye_outlined,
          size: size * 0.14,
          color: const Color(0xFF475569),
        );
      case 6:
        return Icon(
          Icons.local_florist_rounded,
          size: size * 0.14,
          color: const Color(0xFFEC4899),
        );
      case 7:
        return Icon(
          Icons.backpack_rounded,
          size: size * 0.14,
          color: const Color(0xFF14B8A6),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
