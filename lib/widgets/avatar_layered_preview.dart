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
        if (!manifest.listAssets().contains(paths.character)) {
          return AvatarPreview(
            profile: profile,
            size: size,
            showBackgroundRing: showBackgroundRing,
          );
        }

        final assets = manifest.listAssets();
        final layers = paths
            .orderedForAssets(assets)
            .where(manifest.listAssets().contains)
            .map((path) => Positioned.fill(child: _buildAssetLayer(path)))
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

  Widget _buildAssetLayer(String path) {
    return OverflowBox(
      alignment: Alignment.center,
      maxWidth: size,
      maxHeight: size * 1.5,
      child: SizedBox(
        width: size,
        height: size * 1.5,
        child: Image.asset(path, fit: BoxFit.contain),
      ),
    );
  }
}

class AvatarLayerPaths {
  final AvatarProfile profile;

  const AvatarLayerPaths(this.profile);

  String get character =>
      'assets/avatar/characters/character_${profile.faceShapeIndex}.png';

  String get outfit =>
      'assets/avatar/simple_outfits/outfit_${profile.outfitStyleIndex}.png';

  String get completeOutfit =>
      'assets/avatar/characters/character_${profile.faceShapeIndex}_outfit_${profile.outfitStyleIndex}.png';

  String get accessory =>
      'assets/avatar/accessories/accessory_${profile.accessoryIndex}.png';

  List<String> get ordered {
    return [character, outfit, accessory];
  }

  List<String> orderedForAssets(List<String> assets) {
    if (profile.outfitStyleIndex > 0 && assets.contains(completeOutfit)) {
      return [completeOutfit, accessory];
    }
    return ordered;
  }
}
