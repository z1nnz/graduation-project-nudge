enum FriendRelationStatus {
  pending,
  accepted,
  blocked,
}

class FriendRelation {
  final String id;
  final String userId;
  final String friendUserId;
  final FriendRelationStatus relationStatus;
  final bool isFollowing;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FriendRelation({
    required this.id,
    required this.userId,
    required this.friendUserId,
    required this.relationStatus,
    this.isFollowing = false,
    required this.createdAt,
    required this.updatedAt,
  });

  FriendRelation copyWith({
    String? id,
    String? userId,
    String? friendUserId,
    FriendRelationStatus? relationStatus,
    bool? isFollowing,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FriendRelation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendUserId: friendUserId ?? this.friendUserId,
      relationStatus: relationStatus ?? this.relationStatus,
      isFollowing: isFollowing ?? this.isFollowing,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'friendUserId': friendUserId,
      'relationStatus': relationStatus.name,
      'isFollowing': isFollowing,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FriendRelation.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['relationStatus'] as String? ?? 'pending';

    return FriendRelation(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      friendUserId: json['friendUserId'] as String? ?? '',
      relationStatus: FriendRelationStatus.values.firstWhere(
        (e) => e.name == statusRaw,
        orElse: () => FriendRelationStatus.pending,
      ),
      isFollowing: json['isFollowing'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}