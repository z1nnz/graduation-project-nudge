import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/avatar_catalog.dart';
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
    final characterPath = AvatarCatalog.characterAssetForIndex(profile.faceShapeIndex);
    if (characterPath.startsWith('http://') ||
        characterPath.startsWith('https://') ||
        characterPath.startsWith('data:image') ||
        characterPath.contains(';base64,')) {
      final character = OverflowBox(
        alignment: Alignment.center,
        maxWidth: size,
        maxHeight: size * 1.5,
        child: SizedBox(
          width: size,
          height: size * 1.5,
          child: buildAvatarImage(characterPath, fit: BoxFit.contain),
        ),
      );

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
                  color: Colors.white.withValues(alpha: 0.9),
                  width: size * 0.035,
                )
              : null,
        ),
        child: showBackgroundRing ? ClipOval(child: character) : character,
      );
    }

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
                ? const Color(0xFFEDE9FE)
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
      AvatarCatalog.characterAssetForIndex(profile.faceShapeIndex);

  List<String> get ordered {
    return [character];
  }

  List<String> orderedForAssets(List<String> assets) {
    return ordered;
  }
}
