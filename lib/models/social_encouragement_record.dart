class SocialEncouragementRecord {
  final String id;
  final String fromName;
  final String toFriendId;
  final String toFriendName;
  final String type;
  final String createdAt;

  const SocialEncouragementRecord({
    required this.id,
    required this.fromName,
    required this.toFriendId,
    required this.toFriendName,
    required this.type,
    required this.createdAt,
  });

  SocialEncouragementRecord copyWith({
    String? id,
    String? fromName,
    String? toFriendId,
    String? toFriendName,
    String? type,
    String? createdAt,
  }) {
    return SocialEncouragementRecord(
      id: id ?? this.id,
      fromName: fromName ?? this.fromName,
      toFriendId: toFriendId ?? this.toFriendId,
      toFriendName: toFriendName ?? this.toFriendName,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromName': fromName,
      'toFriendId': toFriendId,
      'toFriendName': toFriendName,
      'type': type,
      'createdAt': createdAt,
    };
  }

  factory SocialEncouragementRecord.fromJson(Map<String, dynamic> json) {
    return SocialEncouragementRecord(
      id: json['id'] as String? ?? '',
      fromName: json['fromName'] as String? ?? '',
      toFriendId: json['toFriendId'] as String? ?? '',
      toFriendName: json['toFriendName'] as String? ?? '',
      type: json['type'] as String? ?? '加油',
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}