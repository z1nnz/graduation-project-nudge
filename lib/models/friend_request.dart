enum FriendRequestDirection { incoming, outgoing }

enum FriendRequestStatus { pending, accepted, declined }

class FriendRequest {
  final String id;
  final String nudgeId;
  final String name;
  final String signature;
  final FriendRequestDirection direction;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.nudgeId,
    required this.name,
    required this.signature,
    required this.direction,
    required this.status,
    required this.createdAt,
  });

  FriendRequest copyWith({
    String? id,
    String? nudgeId,
    String? name,
    String? signature,
    FriendRequestDirection? direction,
    FriendRequestStatus? status,
    DateTime? createdAt,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      nudgeId: nudgeId ?? this.nudgeId,
      name: name ?? this.name,
      signature: signature ?? this.signature,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nudgeId': nudgeId,
      'name': name,
      'signature': signature,
      'direction': direction.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String? ?? '',
      nudgeId: json['nudgeId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      direction: FriendRequestDirection.values.firstWhere(
        (item) => item.name == json['direction'],
        orElse: () => FriendRequestDirection.incoming,
      ),
      status: FriendRequestStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
