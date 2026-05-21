class BadgeRecord {
  final String id;
  final String userId;
  final String badgeKey;
  final String badgeName;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int progress;
  final int target;
  final DateTime updatedAt;

  const BadgeRecord({
    required this.id,
    required this.userId,
    required this.badgeKey,
    required this.badgeName,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress = 0,
    this.target = 1,
    required this.updatedAt,
  });

  BadgeRecord copyWith({
    String? id,
    String? userId,
    String? badgeKey,
    String? badgeName,
    bool? isUnlocked,
    DateTime? unlockedAt,
    bool clearUnlockedAt = false,
    int? progress,
    int? target,
    DateTime? updatedAt,
  }) {
    return BadgeRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      badgeKey: badgeKey ?? this.badgeKey,
      badgeName: badgeName ?? this.badgeName,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: clearUnlockedAt ? null : (unlockedAt ?? this.unlockedAt),
      progress: progress ?? this.progress,
      target: target ?? this.target,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get progressRatio {
    if (target <= 0) return 0;
    return (progress / target).clamp(0, 1).toDouble();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'badgeKey': badgeKey,
      'badgeName': badgeName,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'progress': progress,
      'target': target,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BadgeRecord.fromJson(Map<String, dynamic> json) {
    return BadgeRecord(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      badgeKey: json['badgeKey'] as String? ?? '',
      badgeName: json['badgeName'] as String? ?? '',
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] == null
          ? null
          : DateTime.tryParse(json['unlockedAt'] as String),
      progress: json['progress'] as int? ?? 0,
      target: json['target'] as int? ?? 1,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}