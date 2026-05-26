import 'package:flutter/material.dart';

class AvatarProfile {
  final int skinToneIndex;
  final int faceShapeIndex;
  final int hairStyleIndex;
  final int hairColorIndex;
  final int eyeStyleIndex;
  final int eyebrowStyleIndex;
  final int mouthStyleIndex;
  final int outfitStyleIndex;
  final int outfitColorIndex;
  final int accessoryIndex;
  final int backgroundColorIndex;
  final int avatarIconIndex;
  final bool useCustomImage;
  final String? customImagePath;

  const AvatarProfile({
    required this.skinToneIndex,
    required this.faceShapeIndex,
    required this.hairStyleIndex,
    required this.hairColorIndex,
    required this.eyeStyleIndex,
    required this.eyebrowStyleIndex,
    required this.mouthStyleIndex,
    required this.outfitStyleIndex,
    required this.outfitColorIndex,
    required this.accessoryIndex,
    required this.backgroundColorIndex,
    required this.avatarIconIndex,
    required this.useCustomImage,
    required this.customImagePath,
  });

  factory AvatarProfile.initial() {
    return const AvatarProfile(
      skinToneIndex: 0,
      faceShapeIndex: 0,
      hairStyleIndex: 0,
      hairColorIndex: 0,
      eyeStyleIndex: 0,
      eyebrowStyleIndex: 0,
      mouthStyleIndex: 0,
      outfitStyleIndex: 0,
      outfitColorIndex: 0,
      accessoryIndex: 0,
      backgroundColorIndex: 0,
      avatarIconIndex: 0,
      useCustomImage: false,
      customImagePath: null,
    );
  }

  AvatarProfile copyWith({
    int? skinToneIndex,
    int? faceShapeIndex,
    int? hairStyleIndex,
    int? hairColorIndex,
    int? eyeStyleIndex,
    int? eyebrowStyleIndex,
    int? mouthStyleIndex,
    int? outfitStyleIndex,
    int? outfitColorIndex,
    int? accessoryIndex,
    int? backgroundColorIndex,
    int? avatarIconIndex,
    bool? useCustomImage,
    String? customImagePath,
  }) {
    return AvatarProfile(
      skinToneIndex: skinToneIndex ?? this.skinToneIndex,
      faceShapeIndex: faceShapeIndex ?? this.faceShapeIndex,
      hairStyleIndex: hairStyleIndex ?? this.hairStyleIndex,
      hairColorIndex: hairColorIndex ?? this.hairColorIndex,
      eyeStyleIndex: eyeStyleIndex ?? this.eyeStyleIndex,
      eyebrowStyleIndex: eyebrowStyleIndex ?? this.eyebrowStyleIndex,
      mouthStyleIndex: mouthStyleIndex ?? this.mouthStyleIndex,
      outfitStyleIndex: outfitStyleIndex ?? this.outfitStyleIndex,
      outfitColorIndex: outfitColorIndex ?? this.outfitColorIndex,
      accessoryIndex: accessoryIndex ?? this.accessoryIndex,
      backgroundColorIndex: backgroundColorIndex ?? this.backgroundColorIndex,
      avatarIconIndex: avatarIconIndex ?? this.avatarIconIndex,
      useCustomImage: useCustomImage ?? this.useCustomImage,
      customImagePath: customImagePath ?? this.customImagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skinToneIndex': skinToneIndex,
      'faceShapeIndex': faceShapeIndex,
      'hairStyleIndex': hairStyleIndex,
      'hairColorIndex': hairColorIndex,
      'eyeStyleIndex': eyeStyleIndex,
      'eyebrowStyleIndex': eyebrowStyleIndex,
      'mouthStyleIndex': mouthStyleIndex,
      'outfitStyleIndex': outfitStyleIndex,
      'outfitColorIndex': outfitColorIndex,
      'accessoryIndex': accessoryIndex,
      'backgroundColorIndex': backgroundColorIndex,
      'avatarIconIndex': avatarIconIndex,
      'useCustomImage': useCustomImage,
      'customImagePath': customImagePath,
    };
  }

  factory AvatarProfile.fromJson(Map<String, dynamic> json) {
    return AvatarProfile(
      skinToneIndex: json['skinToneIndex'] as int? ?? 0,
      faceShapeIndex: json['faceShapeIndex'] as int? ?? 0,
      hairStyleIndex: json['hairStyleIndex'] as int? ?? 0,
      hairColorIndex: json['hairColorIndex'] as int? ?? 0,
      eyeStyleIndex: json['eyeStyleIndex'] as int? ?? 0,
      eyebrowStyleIndex: json['eyebrowStyleIndex'] as int? ?? 0,
      mouthStyleIndex: json['mouthStyleIndex'] as int? ?? 0,
      outfitStyleIndex: json['outfitStyleIndex'] as int? ?? 0,
      outfitColorIndex: json['outfitColorIndex'] as int? ?? 0,
      accessoryIndex: json['accessoryIndex'] as int? ?? 0,
      backgroundColorIndex: json['backgroundColorIndex'] as int? ?? 0,
      avatarIconIndex: json['avatarIconIndex'] as int? ?? 0,
      useCustomImage: json['useCustomImage'] as bool? ?? false,
      customImagePath: json['customImagePath'] as String?,
    );
  }

  static const List<Color> skinTones = [Color(0xFFF7D6BF)];

  static const List<Color> hairColors = [Color(0xFF1F2937)];

  static const List<Color> outfitColors = [Color(0xFFC7A6F7)];

  static const List<Color> backgroundColors = [Color(0xFFE9D7FF)];

  Color get skinTone => skinTones[skinToneIndex.clamp(0, skinTones.length - 1)];
  Color get hairColor =>
      hairColors[hairColorIndex.clamp(0, hairColors.length - 1)];
  Color get outfitColor =>
      outfitColors[outfitColorIndex.clamp(0, outfitColors.length - 1)];
  Color get backgroundColor =>
      backgroundColors[backgroundColorIndex.clamp(
        0,
        backgroundColors.length - 1,
      )];
}
