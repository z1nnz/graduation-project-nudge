import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/avatar_profile.dart';
import 'avatar_preview.dart';

class AvatarLayeredPreview extends StatelessWidget {
  final AvatarProfile profile;
  final double size;
  final bool showBackgroundRing;

  const AvatarLayeredPreview({
    super.key,
    required this.profile,
    this.size = 72,
    this.showBackgroundRing = false,
  });

  static AssetManifest? _cachedManifest;

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
          return AvatarPreview(
            profile: profile,
            size: size,
            showBackgroundRing: showBackgroundRing,
          );
        }

        final paths = AvatarLayerPaths(profile);
        if (!manifest.listAssets().contains(paths.body)) {
          return AvatarPreview(
            profile: profile,
            size: size,
            showBackgroundRing: showBackgroundRing,
          );
        }

        final layers = paths.ordered
            .where(manifest.listAssets().contains)
            .map(
              (path) => Positioned.fill(
                child: Image.asset(path, fit: BoxFit.contain),
              ),
            )
            .toList();

        final character = Stack(clipBehavior: Clip.none, children: layers);

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
      },
    );
  }
}

class AvatarLayerPaths {
  final AvatarProfile profile;

  const AvatarLayerPaths(this.profile);

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
}
