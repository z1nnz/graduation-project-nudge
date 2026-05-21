import 'package:flutter/material.dart';

import 'avatar_profile.dart';
import 'task_model.dart';

enum StudyMemberStatus { studying, resting, offline }

enum StudyRoomJoinMode { instant, approval }

enum StudyRoomType { study, sleep, exercise, steps, custom }

enum StudyRoomMessageType { text, sticker }

enum StudyRoomEventType {
  join,
  start,
  pause,
  complete,
  leave,
  message,
  sticker,
  system,
}

class StudyMemberData {
  final String memberId;
  final String name;
  final String roomNickname;
  final StudyMemberStatus status;
  final int sessionSeconds;
  final int todayFocusSeconds;
  final double todayMetricValue;
  final Color avatarColor;
  final AvatarProfile? avatarProfile;
  final String role;
  final int personalGoalSeconds;
  final bool hasReachedPersonalGoal;
  final bool isApproved;
  final String joinAnswer;

  const StudyMemberData({
    required this.memberId,
    required this.name,
    required this.roomNickname,
    required this.status,
    required this.sessionSeconds,
    required this.todayFocusSeconds,
    this.todayMetricValue = 0,
    required this.avatarColor,
    this.avatarProfile,
    this.role = 'member',
    this.personalGoalSeconds = 60 * 60,
    this.hasReachedPersonalGoal = false,
    this.isApproved = true,
    this.joinAnswer = '',
  });

  StudyMemberData copyWith({
    String? memberId,
    String? name,
    String? roomNickname,
    StudyMemberStatus? status,
    int? sessionSeconds,
    int? todayFocusSeconds,
    double? todayMetricValue,
    Color? avatarColor,
    AvatarProfile? avatarProfile,
    String? role,
    int? personalGoalSeconds,
    bool? hasReachedPersonalGoal,
    bool? isApproved,
    String? joinAnswer,
  }) {
    return StudyMemberData(
      memberId: memberId ?? this.memberId,
      name: name ?? this.name,
      roomNickname: roomNickname ?? this.roomNickname,
      status: status ?? this.status,
      sessionSeconds: sessionSeconds ?? this.sessionSeconds,
      todayFocusSeconds: todayFocusSeconds ?? this.todayFocusSeconds,
      todayMetricValue: todayMetricValue ?? this.todayMetricValue,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarProfile: avatarProfile ?? this.avatarProfile,
      role: role ?? this.role,
      personalGoalSeconds: personalGoalSeconds ?? this.personalGoalSeconds,
      hasReachedPersonalGoal:
          hasReachedPersonalGoal ?? this.hasReachedPersonalGoal,
      isApproved: isApproved ?? this.isApproved,
      joinAnswer: joinAnswer ?? this.joinAnswer,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'name': name,
      'roomNickname': roomNickname,
      'status': status.name,
      'sessionSeconds': sessionSeconds,
      'todayFocusSeconds': todayFocusSeconds,
      'todayMetricValue': todayMetricValue,
      'avatarColor': avatarColor.toARGB32(),
      'avatarProfile': avatarProfile?.toJson(),
      'role': role,
      'personalGoalSeconds': personalGoalSeconds,
      'hasReachedPersonalGoal': hasReachedPersonalGoal,
      'isApproved': isApproved,
      'joinAnswer': joinAnswer,
    };
  }

  factory StudyMemberData.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['status'] as String? ?? 'offline';
    final status = StudyMemberStatus.values.firstWhere(
      (e) => e.name == statusRaw,
      orElse: () => StudyMemberStatus.offline,
    );

    final name = json['name'] as String? ?? '';

    return StudyMemberData(
      memberId: json['memberId'] as String? ?? name,
      name: name,
      roomNickname: json['roomNickname'] as String? ?? name,
      status: status,
      sessionSeconds: json['sessionSeconds'] as int? ?? 0,
      todayFocusSeconds: json['todayFocusSeconds'] as int? ?? 0,
      todayMetricValue:
          (json['todayMetricValue'] as num?)?.toDouble() ??
          ((json['todayFocusSeconds'] as int? ?? 0) / 3600),
      avatarColor: Color(json['avatarColor'] as int? ?? 0xFF7C6AE6),
      avatarProfile: json['avatarProfile'] == null
          ? null
          : AvatarProfile.fromJson(
              Map<String, dynamic>.from(json['avatarProfile'] as Map),
            ),
      role: json['role'] as String? ?? 'member',
      personalGoalSeconds: json['personalGoalSeconds'] as int? ?? 60 * 60,
      hasReachedPersonalGoal: json['hasReachedPersonalGoal'] as bool? ?? false,
      isApproved: json['isApproved'] as bool? ?? true,
      joinAnswer: json['joinAnswer'] as String? ?? '',
    );
  }
}

class StudyRoomMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final StudyRoomMessageType type;
  final DateTime createdAt;

  const StudyRoomMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory StudyRoomMessage.fromJson(Map<String, dynamic> json) {
    final typeRaw = json['type'] as String? ?? 'text';
    final type = StudyRoomMessageType.values.firstWhere(
      (e) => e.name == typeRaw,
      orElse: () => StudyRoomMessageType.text,
    );

    return StudyRoomMessage(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      text: json['text'] as String? ?? '',
      type: type,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class StudyRoomEvent {
  final String id;
  final String actorId;
  final String actorName;
  final String text;
  final StudyRoomEventType type;
  final DateTime createdAt;

  const StudyRoomEvent({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.text,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actorId': actorId,
      'actorName': actorName,
      'text': text,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory StudyRoomEvent.fromJson(Map<String, dynamic> json) {
    final typeRaw = json['type'] as String? ?? 'system';
    final type = StudyRoomEventType.values.firstWhere(
      (e) => e.name == typeRaw,
      orElse: () => StudyRoomEventType.system,
    );

    return StudyRoomEvent(
      id: json['id'] as String? ?? '',
      actorId: json['actorId'] as String? ?? '',
      actorName: json['actorName'] as String? ?? '',
      text: json['text'] as String? ?? '',
      type: type,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class StudyRoomDailyRecord {
  final String date;
  final int totalFocusSeconds;
  final bool challengeCompleted;
  final String topMemberName;
  final int topMemberFocusSeconds;
  final List<StudyMemberData> memberSnapshots;

  const StudyRoomDailyRecord({
    required this.date,
    required this.totalFocusSeconds,
    required this.challengeCompleted,
    required this.topMemberName,
    required this.topMemberFocusSeconds,
    required this.memberSnapshots,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'totalFocusSeconds': totalFocusSeconds,
      'challengeCompleted': challengeCompleted,
      'topMemberName': topMemberName,
      'topMemberFocusSeconds': topMemberFocusSeconds,
      'memberSnapshots': memberSnapshots.map((e) => e.toJson()).toList(),
    };
  }

  factory StudyRoomDailyRecord.fromJson(Map<String, dynamic> json) {
    final rawSnapshots = json['memberSnapshots'] as List? ?? const [];

    return StudyRoomDailyRecord(
      date: json['date'] as String? ?? '',
      totalFocusSeconds: json['totalFocusSeconds'] as int? ?? 0,
      challengeCompleted: json['challengeCompleted'] as bool? ?? false,
      topMemberName: json['topMemberName'] as String? ?? '',
      topMemberFocusSeconds: json['topMemberFocusSeconds'] as int? ?? 0,
      memberSnapshots: rawSnapshots
          .map((e) => StudyMemberData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class StudyRoomData {
  final String id;
  final String name;
  final String description;
  final Color accentColor;
  final List<StudyMemberData> members;

  final String ownerId;
  final String ownerName;

  final String announcement;
  final List<String> tags;
  final int memberLimit;

  final String category;
  final int dailyGoalHours;
  final StudyRoomType roomType;
  final TaskSourceType goalSourceType;
  final double dailyGoalValue;
  final String goalUnitLabel;

  final StudyRoomJoinMode joinMode;
  final bool joinQuestionsEnabled;
  final List<String> joinQuestions;

  final bool nicknameRuleEnabled;
  final String nicknameRuleText;

  final String roomRules;
  final String password;

  final String challengeTitle;
  final String challengeDescription;
  final int challengeGoalSeconds;
  final String challengeDeadlineLabel;
  final bool challengeCompleted;
  final bool syncTaskEnabled;

  final List<StudyRoomDailyRecord> dailyRecords;
  final List<StudyRoomMessage> messages;
  final List<StudyRoomEvent> events;

  const StudyRoomData({
    required this.id,
    required this.name,
    required this.description,
    required this.accentColor,
    required this.members,
    this.ownerId = 'local_user',
    this.ownerName = '老闆',
    this.announcement = '',
    this.tags = const [],
    this.memberLimit = 8,
    this.category = '自訂',
    this.dailyGoalHours = 2,
    this.roomType = StudyRoomType.study,
    this.goalSourceType = TaskSourceType.studyRoom,
    this.dailyGoalValue = 2,
    this.goalUnitLabel = '小時',
    this.joinMode = StudyRoomJoinMode.instant,
    this.joinQuestionsEnabled = false,
    this.joinQuestions = const [],
    this.nicknameRuleEnabled = false,
    this.nicknameRuleText = '',
    this.roomRules = '',
    this.password = '',
    this.challengeTitle = '今日房間挑戰',
    this.challengeDescription = '一起累積專注時數',
    this.challengeGoalSeconds = 3 * 60 * 60,
    this.challengeDeadlineLabel = '今天 23:59',
    this.challengeCompleted = false,
    this.syncTaskEnabled = false,
    this.dailyRecords = const [],
    this.messages = const [],
    this.events = const [],
  });

  StudyRoomData copyWith({
    String? id,
    String? name,
    String? description,
    Color? accentColor,
    List<StudyMemberData>? members,
    String? ownerId,
    String? ownerName,
    String? announcement,
    List<String>? tags,
    int? memberLimit,
    String? category,
    int? dailyGoalHours,
    StudyRoomType? roomType,
    TaskSourceType? goalSourceType,
    double? dailyGoalValue,
    String? goalUnitLabel,
    StudyRoomJoinMode? joinMode,
    bool? joinQuestionsEnabled,
    List<String>? joinQuestions,
    bool? nicknameRuleEnabled,
    String? nicknameRuleText,
    String? roomRules,
    String? password,
    String? challengeTitle,
    String? challengeDescription,
    int? challengeGoalSeconds,
    String? challengeDeadlineLabel,
    bool? challengeCompleted,
    bool? syncTaskEnabled,
    List<StudyRoomDailyRecord>? dailyRecords,
    List<StudyRoomMessage>? messages,
    List<StudyRoomEvent>? events,
  }) {
    return StudyRoomData(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      accentColor: accentColor ?? this.accentColor,
      members: members ?? this.members,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      announcement: announcement ?? this.announcement,
      tags: tags ?? this.tags,
      memberLimit: memberLimit ?? this.memberLimit,
      category: category ?? this.category,
      dailyGoalHours: dailyGoalHours ?? this.dailyGoalHours,
      roomType: roomType ?? this.roomType,
      goalSourceType: goalSourceType ?? this.goalSourceType,
      dailyGoalValue: dailyGoalValue ?? this.dailyGoalValue,
      goalUnitLabel: goalUnitLabel ?? this.goalUnitLabel,
      joinMode: joinMode ?? this.joinMode,
      joinQuestionsEnabled: joinQuestionsEnabled ?? this.joinQuestionsEnabled,
      joinQuestions: joinQuestions ?? this.joinQuestions,
      nicknameRuleEnabled: nicknameRuleEnabled ?? this.nicknameRuleEnabled,
      nicknameRuleText: nicknameRuleText ?? this.nicknameRuleText,
      roomRules: roomRules ?? this.roomRules,
      password: password ?? this.password,
      challengeTitle: challengeTitle ?? this.challengeTitle,
      challengeDescription: challengeDescription ?? this.challengeDescription,
      challengeGoalSeconds: challengeGoalSeconds ?? this.challengeGoalSeconds,
      challengeDeadlineLabel:
          challengeDeadlineLabel ?? this.challengeDeadlineLabel,
      challengeCompleted: challengeCompleted ?? this.challengeCompleted,
      syncTaskEnabled: syncTaskEnabled ?? this.syncTaskEnabled,
      dailyRecords: dailyRecords ?? this.dailyRecords,
      messages: messages ?? this.messages,
      events: events ?? this.events,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'accentColor': accentColor.toARGB32(),
      'members': members.map((e) => e.toJson()).toList(),
      'ownerId': ownerId,
      'ownerName': ownerName,
      'announcement': announcement,
      'tags': tags,
      'memberLimit': memberLimit,
      'category': category,
      'dailyGoalHours': dailyGoalHours,
      'roomType': roomType.name,
      'goalSourceType': goalSourceType.name,
      'dailyGoalValue': dailyGoalValue,
      'goalUnitLabel': goalUnitLabel,
      'joinMode': joinMode.name,
      'joinQuestionsEnabled': joinQuestionsEnabled,
      'joinQuestions': joinQuestions,
      'nicknameRuleEnabled': nicknameRuleEnabled,
      'nicknameRuleText': nicknameRuleText,
      'roomRules': roomRules,
      'password': password,
      'challengeTitle': challengeTitle,
      'challengeDescription': challengeDescription,
      'challengeGoalSeconds': challengeGoalSeconds,
      'challengeDeadlineLabel': challengeDeadlineLabel,
      'challengeCompleted': challengeCompleted,
      'syncTaskEnabled': syncTaskEnabled,
      'dailyRecords': dailyRecords.map((e) => e.toJson()).toList(),
      'messages': messages.map((e) => e.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
    };
  }

  factory StudyRoomData.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['members'] as List? ?? [];
    final recordsRaw = json['dailyRecords'] as List? ?? [];
    final messagesRaw = json['messages'] as List? ?? [];
    final eventsRaw = json['events'] as List? ?? [];

    final joinModeRaw = json['joinMode'] as String? ?? 'instant';
    final joinMode = StudyRoomJoinMode.values.firstWhere(
      (e) => e.name == joinModeRaw,
      orElse: () => StudyRoomJoinMode.instant,
    );

    final ownerName = json['ownerName'] as String? ?? '老闆';
    final roomTypeRaw = json['roomType'] as String? ?? 'study';
    final roomType = StudyRoomType.values.firstWhere(
      (e) => e.name == roomTypeRaw,
      orElse: () => StudyRoomType.study,
    );
    final sourceRaw = json['goalSourceType'] as String? ?? 'studyRoom';
    final goalSourceType = TaskSourceType.values.firstWhere(
      (e) => e.name == sourceRaw,
      orElse: () => TaskSourceType.studyRoom,
    );
    final legacyGoalHours = json['dailyGoalHours'] as int? ?? 2;

    return StudyRoomData(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      accentColor: Color(json['accentColor'] as int? ?? 0xFF7C6AE6),
      members: membersRaw
          .map((e) => StudyMemberData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      ownerId: json['ownerId'] as String? ?? ownerName,
      ownerName: ownerName,
      announcement: json['announcement'] as String? ?? '',
      tags: (json['tags'] as List?)?.map((e) => '$e').toList() ?? const [],
      memberLimit: json['memberLimit'] as int? ?? 8,
      category: json['category'] as String? ?? '自訂',
      dailyGoalHours: legacyGoalHours,
      roomType: roomType,
      goalSourceType: goalSourceType,
      dailyGoalValue:
          (json['dailyGoalValue'] as num?)?.toDouble() ??
          legacyGoalHours.toDouble(),
      goalUnitLabel: json['goalUnitLabel'] as String? ?? '小時',
      joinMode: joinMode,
      joinQuestionsEnabled: json['joinQuestionsEnabled'] as bool? ?? false,
      joinQuestions:
          (json['joinQuestions'] as List?)?.map((e) => '$e').toList() ??
          const [],
      nicknameRuleEnabled: json['nicknameRuleEnabled'] as bool? ?? false,
      nicknameRuleText: json['nicknameRuleText'] as String? ?? '',
      roomRules: json['roomRules'] as String? ?? '',
      password: json['password'] as String? ?? '',
      challengeTitle: json['challengeTitle'] as String? ?? '今日房間挑戰',
      challengeDescription:
          json['challengeDescription'] as String? ?? '一起累積專注時數',
      challengeGoalSeconds: json['challengeGoalSeconds'] as int? ?? 3 * 60 * 60,
      challengeDeadlineLabel:
          json['challengeDeadlineLabel'] as String? ?? '今天 23:59',
      challengeCompleted: json['challengeCompleted'] as bool? ?? false,
      syncTaskEnabled: json['syncTaskEnabled'] as bool? ?? false,
      dailyRecords: recordsRaw
          .map(
            (e) => StudyRoomDailyRecord.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      messages: messagesRaw
          .map((e) => StudyRoomMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      events: eventsRaw
          .map((e) => StudyRoomEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
