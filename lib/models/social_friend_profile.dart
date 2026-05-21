import 'package:flutter/material.dart';

import 'avatar_profile.dart';

class SocialFriendProfile {
  final String id;
  final String nudgeId;
  final String name;
  final String signature;
  final int todayFocusSeconds;
  final bool isStudying;
  final Color avatarColor;
  final AvatarProfile? avatarProfile;
  final bool isFollowing;
  final int encouragementCount;

  const SocialFriendProfile({
    required this.id,
    this.nudgeId = '',
    required this.name,
    required this.signature,
    required this.todayFocusSeconds,
    required this.isStudying,
    required this.avatarColor,
    this.avatarProfile,
    required this.isFollowing,
    required this.encouragementCount,
  });

  SocialFriendProfile copyWith({
    String? id,
    String? nudgeId,
    String? name,
    String? signature,
    int? todayFocusSeconds,
    bool? isStudying,
    Color? avatarColor,
    AvatarProfile? avatarProfile,
    bool? isFollowing,
    int? encouragementCount,
  }) {
    return SocialFriendProfile(
      id: id ?? this.id,
      nudgeId: nudgeId ?? this.nudgeId,
      name: name ?? this.name,
      signature: signature ?? this.signature,
      todayFocusSeconds: todayFocusSeconds ?? this.todayFocusSeconds,
      isStudying: isStudying ?? this.isStudying,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarProfile: avatarProfile ?? this.avatarProfile,
      isFollowing: isFollowing ?? this.isFollowing,
      encouragementCount: encouragementCount ?? this.encouragementCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nudgeId': nudgeId,
      'name': name,
      'signature': signature,
      'todayFocusSeconds': todayFocusSeconds,
      'isStudying': isStudying,
      'avatarColor': avatarColor.toARGB32(),
      'avatarProfile': avatarProfile?.toJson(),
      'isFollowing': isFollowing,
      'encouragementCount': encouragementCount,
    };
  }

  factory SocialFriendProfile.fromJson(Map<String, dynamic> json) {
    return SocialFriendProfile(
      id: json['id'] as String? ?? '',
      nudgeId: json['nudgeId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      todayFocusSeconds: json['todayFocusSeconds'] as int? ?? 0,
      isStudying: json['isStudying'] as bool? ?? false,
      avatarColor: Color(json['avatarColor'] as int? ?? 0xFF4F8CFF),
      avatarProfile: json['avatarProfile'] == null
          ? null
          : AvatarProfile.fromJson(
              Map<String, dynamic>.from(json['avatarProfile'] as Map),
            ),
      isFollowing: json['isFollowing'] as bool? ?? false,
      encouragementCount: json['encouragementCount'] as int? ?? 0,
    );
  }
}
