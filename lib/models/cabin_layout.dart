import 'dart:convert';

import 'package:flutter/services.dart';

/// A rectangle in 0-1 coordinates of the cabin frame.
class CabinRect {
  const CabinRect(this.left, this.top, this.width, this.height);

  factory CabinRect.fromJson(Object? raw) {
    final values = (raw as List).map((v) => (v as num).toDouble()).toList();
    return CabinRect(values[0], values[1], values[2], values[3]);
  }

  final double left;
  final double top;
  final double width;
  final double height;
}

class CabinLayerSpec {
  const CabinLayerSpec({
    required this.rect,
    required this.z,
    required this.images,
    this.rects,
  });

  final CabinRect rect;

  /// Optional per-image rectangles (books stages sit on different shelves).
  final List<CabinRect>? rects;

  CabinRect rectFor(int imageIndex) {
    final list = rects;
    if (list == null || imageIndex < 0 || imageIndex >= list.length) {
      return rect;
    }
    return list[imageIndex];
  }

  final int z;

  /// Decor slots: one image per variant. Growth layers: one image per stage
  /// starting at stage 1 (stage 0 draws nothing).
  final List<String> images;
}

/// Where each pixel-art layer sits in the cabin (`assets/home/cabin_layout.json`).
class CabinLayout {
  const CabinLayout({
    required this.baseImage,
    required this.aspect,
    required this.layers,
    required this.character,
    required this.questBoard,
    required this.doors,
  });

  static const assetPath = 'assets/home/cabin_layout.json';
  static const layerIds = [
    'rug',
    'curtain',
    'lamp',
    'books',
    'plant',
    'badges',
    'globe',
  ];

  final String baseImage;

  /// Width / height of the base image.
  final double aspect;
  final Map<String, CabinLayerSpec> layers;
  final CabinRect character;
  final CabinRect questBoard;
  final Map<String, CabinRect> doors;

  factory CabinLayout.fromJson(Map<String, dynamic> json) {
    final layers = (json['layers'] as Map).cast<String, dynamic>();
    final doors = (json['doors'] as Map).cast<String, dynamic>();
    return CabinLayout(
      baseImage: json['baseImage'] as String,
      aspect: (json['aspect'] as num).toDouble(),
      layers: {
        for (final entry in layers.entries)
          entry.key: CabinLayerSpec(
            rect: CabinRect.fromJson(entry.value['rect']),
            z: entry.value['z'] as int,
            images: (entry.value['images'] as List).cast<String>(),
            rects: (entry.value['rects'] as List?)
                ?.map(CabinRect.fromJson)
                .toList(growable: false),
          ),
      },
      character: CabinRect.fromJson((json['character'] as Map)['rect']),
      questBoard: CabinRect.fromJson((json['questBoard'] as Map)['rect']),
      doors: {
        for (final entry in doors.entries)
          entry.key: CabinRect.fromJson((entry.value as Map)['rect']),
      },
    );
  }

  static Future<CabinLayout> load(AssetBundle bundle) async {
    final text = await bundle.loadString(assetPath);
    return CabinLayout.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }
}
