class UserModel {
  final String id;
  final String? email;
  final String username;
  final String nickname;
  final String signature;
  final String authProvider;
  final String? avatarProfileId;
  final String themeMode;
  final String accentColor;
  final String? timezone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.id,
    this.email,
    required this.username,
    required this.nickname,
    required this.signature,
    this.authProvider = 'local',
    this.avatarProfileId,
    this.themeMode = 'system',
    this.accentColor = 'purple',
    this.timezone,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? nickname,
    String? signature,
    String? authProvider,
    String? avatarProfileId,
    String? themeMode,
    String? accentColor,
    String? timezone,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    bool clearLastLoginAt = false,
    bool clearEmail = false,
    bool clearAvatarProfileId = false,
    bool clearTimezone = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: clearEmail ? null : (email ?? this.email),
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      signature: signature ?? this.signature,
      authProvider: authProvider ?? this.authProvider,
      avatarProfileId: clearAvatarProfileId
          ? null
          : (avatarProfileId ?? this.avatarProfileId),
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      timezone: clearTimezone ? null : (timezone ?? this.timezone),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: clearLastLoginAt ? null : (lastLoginAt ?? this.lastLoginAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'nickname': nickname,
      'signature': signature,
      'authProvider': authProvider,
      'avatarProfileId': avatarProfileId,
      'themeMode': themeMode,
      'accentColor': accentColor,
      'timezone': timezone,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String?,
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      authProvider: json['authProvider'] as String? ?? 'local',
      avatarProfileId: json['avatarProfileId'] as String?,
      themeMode: json['themeMode'] as String? ?? 'system',
      accentColor: json['accentColor'] as String? ?? 'purple',
      timezone: json['timezone'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      lastLoginAt: json['lastLoginAt'] == null
          ? null
          : DateTime.tryParse(json['lastLoginAt'] as String),
    );
  }
}
