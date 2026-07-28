import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';
import '../models/activity_ledger.dart';
import '../models/badge_record.dart';
import '../models/daily_summary.dart';
import '../models/experience_capabilities.dart';
import '../models/family_link_contract.dart';
import '../models/friend_request.dart';
import '../models/group_contract.dart';
import '../models/health_activity_snapshot.dart';
import '../models/relationship_membership.dart';
import '../models/room_activity_session.dart';
import '../models/social_encouragement_record.dart';
import '../models/social_friend_profile.dart';
import '../models/study_room_models.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/activity_ledger_outbox.dart';
import '../services/cloud_activity_ledger_gateway.dart';
import '../services/cloud_health_snapshot_gateway.dart';
import '../services/health_snapshot_outbox.dart';
import '../theme/app_ui.dart';

class ReminderChannelSetting {
  final String key;
  final String title;
  final String description;
  final String timeLabel;
  final bool enabled;

  const ReminderChannelSetting({
    required this.key,
    required this.title,
    required this.description,
    required this.timeLabel,
    required this.enabled,
  });

  ReminderChannelSetting copyWith({String? timeLabel, bool? enabled}) {
    return ReminderChannelSetting(
      key: key,
      title: title,
      description: description,
      timeLabel: timeLabel ?? this.timeLabel,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {'key': key, 'timeLabel': timeLabel, 'enabled': enabled};
  }

  static ReminderChannelSetting fromJson(
    Map<String, dynamic> json,
    ReminderChannelSetting fallback,
  ) {
    return fallback.copyWith(
      timeLabel: json['timeLabel'] as String? ?? fallback.timeLabel,
      enabled: json['enabled'] as bool? ?? fallback.enabled,
    );
  }
}

class ReminderPreview {
  final String channelKey;
  final String title;
  final String subtitle;
  final String timeLabel;

  const ReminderPreview({
    required this.channelKey,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
  });
}

class AppState extends ChangeNotifier {
  final ActivityLedgerOutbox _activityLedgerOutbox;
  final HealthSnapshotOutbox _healthSnapshotOutbox;

  AppState({
    ActivityLedgerOutbox? activityLedgerOutbox,
    HealthSnapshotOutbox? healthSnapshotOutbox,
  }) : _activityLedgerOutbox =
           activityLedgerOutbox ??
           ActivityLedgerOutbox(gateway: CloudActivityLedgerGateway.firebase()),
       _healthSnapshotOutbox =
           healthSnapshotOutbox ??
           HealthSnapshotOutbox(
             gateway: CloudHealthSnapshotGateway.firebase(),
           ) {
    _listenToAuthChanges();
  }

  bool _isGuestMode = false;
  bool get isGuestMode => _isGuestMode;

  void skipSignIn() {
    _isGuestMode = true;
    notifyListeners();
  }

  StreamSubscription? _userSubscription;
  StreamSubscription? _friendsSubscription;
  StreamSubscription? _incomingRequestsSubscription;
  StreamSubscription? _outgoingRequestsSubscription;
  StreamSubscription? _roomsSubscription;
  StreamSubscription? _roomDiscoverySubscription;
  final Map<String, StreamSubscription> _roomMemberSubscriptions = {};
  final Map<String, StreamSubscription> _roomSessionSubscriptions = {};
  final Map<String, StreamSubscription> _roomMessageSubscriptions = {};
  final Map<String, StreamSubscription> _roomEventSubscriptions = {};
  StreamSubscription? _shopSubscription;
  StreamSubscription? _incomingGuardianRequestsSubscription;
  StreamSubscription? _outgoingGuardianRequestsSubscription;
  StreamSubscription? _familyLinkSubscription;
  StreamSubscription? _familyEncouragementSubscription;
  StreamSubscription? _familyGoalSubscription;
  StreamSubscription? _familyBondEventSubscription;
  StreamSubscription? _familySummarySubscription;
  StreamSubscription? _incomingGroupRequestsSubscription;
  StreamSubscription? _groupSubscription;
  StreamSubscription? _groupChallengeSubscription;
  StreamSubscription? _groupChallengeParticipantsSubscription;
  StreamSubscription? _groupSchedulesSubscription;
  StreamSubscription? _groupTemplateSubscription;
  StreamSubscription? _groupMemberSummariesSubscription;
  String? _listeningGroupId;
  String? _projectedGroupId;
  final Set<String> _checkedLegacyGroupIds = {};
  Timer? _dailyResetTimer;
  Timer? _familySummaryPublishTimer;
  Timer? _groupResultSummaryPublishTimer;
  bool _groupChallengeProgressSyncInFlight = false;
  bool _groupChallengeProgressSyncQueued = false;
  List<StudyRoomData> _discoverableStudyRooms = [];
  final Map<String, RoomActivitySession> _roomActivitySessions = {};
  final Map<String, String> _roomActiveSessionIds = {};

  /// The current user's Firestore uid, falling back to 'local_user' when
  /// the user is not signed in (guest mode / offline).
  String get _myId => _currentUser?.id ?? 'local_user';

  void _listenToAuthChanges() {
    try {
      fb_auth.FirebaseAuth.instance.authStateChanges().listen((
        fb_auth.User? user,
      ) async {
        if (user != null) {
          _isGuestMode = false;
          await _syncProfileFromFirebaseUser(user);
          _setupFirestoreListeners(user);
          unawaited(_activityLedgerOutbox.flush());
          unawaited(_healthSnapshotOutbox.flush());
        } else {
          _cancelFirestoreListeners();
          _currentUser = null;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Error listening to auth state: $e');
    }
  }

  List<FriendRequest> _incomingRequestsList = [];
  List<FriendRequest> _outgoingRequestsList = [];

  List<Map<String, dynamic>> _incomingGuardianRequests = [];
  List<Map<String, dynamic>> get incomingGuardianRequests =>
      _incomingGuardianRequests;

  List<Map<String, dynamic>> _outgoingGuardianRequests = [];
  List<Map<String, dynamic>> get outgoingGuardianRequests =>
      _outgoingGuardianRequests;

  FamilyLinkContract? _familyLink;
  List<FamilyLinkContract> _familyLinks = [];
  String? _selectedFamilyLinkId;
  String? _listeningFamilyLinkId;
  List<Map<String, dynamic>> _familyEncouragements = [];
  List<Map<String, dynamic>> _familyGoals = [];
  List<Map<String, dynamic>> _familyBondEvents = [];
  Map<String, dynamic>? _familySummary;

  List<Map<String, dynamic>> _incomingGroupRequests = [];
  List<Map<String, dynamic>> get incomingGroupRequests =>
      _incomingGroupRequests;

  void _setupFirestoreListeners(fb_auth.User user) {
    _cancelFirestoreListeners();
    unawaited(_restoreRelationshipSelections(user.uid));

    // User profile listener
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((docSnap) {
          try {
            if (docSnap.exists) {
              final data = docSnap.data()!;
              _currentUser = UserModel.fromJson(data);
              _profileNickname = _currentUser!.nickname;
              _profileSignature = _currentUser!.signature;
              _myNudgeId = _currentUser!.username;
              _themeModeSetting = _currentUser!.themeMode;
              _iconColorSetting = _currentUser!.accentColor;
              _disciplineCoins =
                  (data['disciplineCoins'] as num?)?.toInt() ??
                  _disciplineCoins;
              _unlockedPlanets = _parseUnlockedPlanets(data);
              _planetCount = _unlockedPlanets.length - 1;
              _weeklyPlanetEarned =
                  data['weeklyPlanetEarned'] as bool? ?? _weeklyPlanetEarned;
              _lastSettledWeekMonday =
                  data['lastSettledWeekMonday'] as String? ??
                  _lastSettledWeekMonday;
              if (data['rewardedTaskKeys'] != null) {
                _rewardedTaskKeys = Set<String>.from(
                  List<String>.from(data['rewardedTaskKeys']),
                );
              }
              if (data['dailyCoinEarned'] != null) {
                final Map decoded = data['dailyCoinEarned'] as Map;
                _dailyCoinEarned = decoded.map(
                  (k, v) => MapEntry(k.toString(), (v as num).toInt()),
                );
              }
              if (data['monthlyDeadlineCoinEarned'] != null) {
                final Map decoded = data['monthlyDeadlineCoinEarned'] as Map;
                _monthlyDeadlineCoinEarned = decoded.map(
                  (k, v) => MapEntry(k.toString(), (v as num).toInt()),
                );
              }
              _applyAvatarExperienceData(data);
              if (data['unlockedAvatarItems'] != null) {
                _unlockedAvatarItemKeys = Set<String>.from(
                  List<String>.from(data['unlockedAvatarItems']),
                );
              }
              if (data['unlockedBadgeDates'] != null) {
                _unlockedBadgeDates = Map<String, String>.from(
                  data['unlockedBadgeDates'] as Map,
                );
              }
              if (data['tasks'] != null) {
                _tasks = List<Map<String, dynamic>>.from(
                  (data['tasks'] as List).map(
                    (t) => Map<String, dynamic>.from(t as Map),
                  ),
                );
              }
              if (data['dailySummaries'] != null) {
                _dailySummaries = List<DailySummary>.from(
                  (data['dailySummaries'] as List).map(
                    (s) => DailySummary.fromJson(
                      Map<String, dynamic>.from(s as Map),
                    ),
                  ),
                );
              }
              if (data['webToolsState'] != null) {
                _webToolsState = Map<String, dynamic>.from(
                  data['webToolsState'] as Map,
                );
              } else {
                _webToolsState = null;
              }
              if (data['webToolsCollection'] != null) {
                _webToolsCollection = Map<String, dynamic>.from(
                  data['webToolsCollection'] as Map,
                );
              } else {
                _webToolsCollection = null;
              }
              _userRole = data['userRole'] as String? ?? _userRole;
              _groupId = data['groupId'] as String?;
              _groupName = data['groupName'] as String?;
              final projectedIsGroupOwner =
                  data['isGroupOwner'] as bool? ?? false;
              if (projectedIsGroupOwner &&
                  _groupId != null &&
                  _groupName != null) {
                unawaited(
                  _migrateLegacyGroupProjection(
                    user.uid,
                    _groupId!,
                    _groupName!,
                  ),
                );
              } else if (_groupId != null) {
                unawaited(_ensureCanonicalGroupMembership(user.uid, _groupId!));
              }
              _setupCanonicalGroupListener(user.uid, _groupId);
              _profileTitleBadgeKey =
                  data['profileTitleBadgeKey'] as String? ?? '';
              if (data['backgroundTheme'] != null) {
                final bt = data['backgroundTheme'] as String;
                if (AppUI.backgroundThemeKeys.contains(bt)) {
                  _backgroundThemeSetting = bt;
                }
              }
              if (data['focusSeconds'] != null) {
                final cloudFocusSeconds =
                    (data['focusSeconds'] as num?)?.toInt() ?? 0;
                if (cloudFocusSeconds > _focusSeconds) {
                  _focusSeconds = cloudFocusSeconds;
                }
              }
              _syncTaskRewards();
              checkWeeklyPlanetSettlement();
              notifyListeners();
            }
          } catch (e, stack) {
            debugPrint('Error inside Firestore user snapshot listener: $e');
            debugPrint('Stacktrace: $stack');
          }
        });

    // Friends listener
    _friendsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .snapshots()
        .listen((snapshot) {
          _socialFriends = snapshot.docs
              .map((doc) => SocialFriendProfile.fromJson(doc.data()))
              .toList();
          notifyListeners();
        });

    // Incoming requests listener
    _incomingRequestsSubscription = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('receiverId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          _incomingRequestsList = snapshot.docs.map((doc) {
            final data = doc.data();
            final createdAt =
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return FriendRequest(
              id: doc.id,
              nudgeId: data['senderNudgeId'] as String? ?? '',
              name: data['senderName'] as String? ?? '',
              signature: data['senderSignature'] as String? ?? '',
              direction: FriendRequestDirection.incoming,
              status: FriendRequestStatus.pending,
              createdAt: createdAt,
            );
          }).toList();
          _friendRequests = _incomingRequestsList + _outgoingRequestsList;
          notifyListeners();
        });

    // Outgoing requests listener
    _outgoingRequestsSubscription = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('senderId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          _outgoingRequestsList = snapshot.docs.map((doc) {
            final data = doc.data();
            final createdAt =
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return FriendRequest(
              id: doc.id,
              nudgeId: data['receiverNudgeId'] as String? ?? '',
              name: data['receiverName'] as String? ?? '',
              signature: data['receiverSignature'] as String? ?? '',
              direction: FriendRequestDirection.outgoing,
              status: FriendRequestStatus.pending,
              createdAt: createdAt,
            );
          }).toList();
          _friendRequests = _incomingRequestsList + _outgoingRequestsList;
          notifyListeners();
        });

    // Study rooms listener — watches every room where the user is a member
    // The room document's 'memberIds' array field tracks who's in the room.
    _roomsSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .where('memberIds', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) {
          final activeRoomDocs = snapshot.docs
              .where((doc) => doc.data()['status'] != 'closed')
              .toList(growable: false);
          _mergeFirestoreRooms(activeRoomDocs);
          _syncRoomChildListeners(
            activeRoomDocs.map((doc) => doc.id).toSet(),
            user.uid,
          );
        });
    _roomDiscoverySubscription = FirebaseFirestore.instance
        .collection('rooms')
        .where('visibility', isEqualTo: 'public')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
          final joinedIds = _studyRooms.map((room) => room.id).toSet();
          _discoverableStudyRooms = snapshot.docs
              .where((doc) => !joinedIds.contains(doc.id))
              .map((doc) => StudyRoomData.fromJson(doc.data()))
              .toList();
          notifyListeners();
        });

    // Shop items listener (dynamic character series)
    _shopSubscription = FirebaseFirestore.instance
        .collection('shop_items')
        .snapshots()
        .listen((snapshot) {
          final docs =
              snapshot.docs
                  .where((doc) => _isActiveShopItem(doc.data()))
                  .toList()
                ..sort((a, b) {
                  final aCreated = _shopTimestampSeconds(
                    a.data()['created_at'],
                  );
                  final bCreated = _shopTimestampSeconds(
                    b.data()['created_at'],
                  );
                  final createdComparison = aCreated.compareTo(bCreated);
                  if (createdComparison != 0) return createdComparison;
                  return a.id.compareTo(b.id);
                });

          final publishedSeries = <PublishedAvatarSeries>[];
          var fallbackIndex = 18;
          for (final doc in docs) {
            final data = doc.data();
            final parsedSeries = PublishedAvatarSeries.tryParseShopDocument(
              documentId: doc.id,
              data: data,
              fallbackIndex: fallbackIndex,
            );
            if (parsedSeries == null) continue;
            publishedSeries.add(parsedSeries);
            fallbackIndex =
                parsedSeries.stages
                    .map((stage) => stage.index)
                    .reduce(math.max) +
                1;
          }
          AvatarCatalog.replacePublishedSeries(publishedSeries);
          _normalizeAvatarProfileForCatalog();
          notifyListeners();
        });

    // Incoming guardian requests listener
    _incomingGuardianRequestsSubscription = FirebaseFirestore.instance
        .collection('guardian_requests')
        .where('receiverId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
          final docs = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          _incomingGuardianRequests = docs
              .where((d) => d['status'] == 'pending')
              .toList();

          // Check for accepted request to trigger local profile linkage update
          final accepted = docs
              .where((d) => d['status'] == 'accepted')
              .toList();
          if (accepted.isNotEmpty &&
              guardianInvite?['linkId'] != accepted.first['id']) {
            _autoUpdateLinkage(accepted.first, user.uid);
          } else if (accepted.isEmpty && isGuardianLinked) {
            _checkAndAutoClearLinkage(user.uid);
          }
          notifyListeners();
        });

    // Outgoing guardian requests listener
    _outgoingGuardianRequestsSubscription = FirebaseFirestore.instance
        .collection('guardian_requests')
        .where('senderId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
          final docs = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          _outgoingGuardianRequests = docs
              .where((d) => d['status'] == 'pending')
              .toList();

          // Check for accepted request to trigger local profile linkage update
          final accepted = docs
              .where((d) => d['status'] == 'accepted')
              .toList();
          if (accepted.isNotEmpty &&
              guardianInvite?['linkId'] != accepted.first['id']) {
            _autoUpdateLinkage(accepted.first, user.uid);
          } else if (accepted.isEmpty && isGuardianLinked) {
            _checkAndAutoClearLinkage(user.uid);
          }
          notifyListeners();
        });

    _setupFamilyLinkListener(user.uid);

    _incomingGroupRequestsSubscription = FirebaseFirestore.instance
        .collection('group_requests')
        .where('receiverId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
          _incomingGroupRequests = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .where((request) => request['status'] == 'pending')
              .toList(growable: false);
          notifyListeners();
        });
  }

  int _shopTimestampSeconds(dynamic value) {
    if (value is Timestamp) return value.seconds;
    if (value is DateTime) return value.millisecondsSinceEpoch ~/ 1000;
    if (value is num) return value.toInt();
    return 0;
  }

  bool _isActiveShopItem(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'published';
    if (status != 'published') return false;
    final type = data['type'] as String? ?? 'permanent';
    final expiresAt = _shopTimestampSeconds(data['expires_at']);
    if (type == 'permanent' || expiresAt == 0) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final startAt = _shopTimestampSeconds(data['start_time']);
    final endAt = _shopTimestampSeconds(data['end_time']) == 0
        ? expiresAt
        : _shopTimestampSeconds(data['end_time']);
    return startAt <= now && now <= endAt;
  }

  /// Merges Firestore room documents into the local _studyRooms list.
  /// Local-only rooms (id starts with 'room_demo_') are kept as-is.
  void _mergeFirestoreRooms(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final remoteRooms = docs
        .map((doc) => StudyRoomData.fromJson(doc.data()))
        .toList();

    // Keep any demo/local-only rooms that aren't in Firestore.
    final demoRooms = _studyRooms
        .where((r) => r.id.startsWith('room_demo_'))
        .toList();

    // Firestore membership is authoritative for signed-in rooms. Keeping only
    // explicit demo rooms prevents removed memberships from lingering locally.
    _studyRooms = [...remoteRooms, ...demoRooms];
    _syncMyFocusSecondsAcrossRooms();
    _syncStudyRoomGoalTasks();
    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    _syncTodaySummary();
    notifyListeners();
  }

  StudyMemberData _roomMemberFromProjection(
    StudyRoomData room,
    Map<String, dynamic> data,
  ) {
    final statusName = data['presenceStatus'] as String? ?? 'offline';
    final status = StudyMemberStatus.values.firstWhere(
      (item) => item.name == statusName,
      orElse: () => StudyMemberStatus.offline,
    );
    final metricValue = (data['metricValue'] as num?)?.toDouble() ?? 0;
    final isFocusMetric =
        room.goalSourceType == TaskSourceType.studyRoom ||
        room.goalSourceType == TaskSourceType.focusMinutes;
    final displayName = data['displayName'] as String? ?? '自律夥伴';
    return StudyMemberData(
      memberId: data['memberId'] as String? ?? '',
      name: displayName,
      roomNickname: displayName,
      status: status,
      sessionSeconds: (data['sessionSeconds'] as num?)?.toInt() ?? 0,
      todayFocusSeconds: isFocusMetric ? (metricValue * 60).round() : 0,
      todayMetricValue: metricValue,
      avatarColor: const Color(0xFF7C6AE6),
      role: data['role'] as String? ?? 'member',
      isApproved: data['approvalStatus'] == 'approved',
    );
  }

  void _syncRoomChildListeners(Set<String> roomIds, String userId) {
    for (final roomId
        in _roomMemberSubscriptions.keys
            .where((id) => !roomIds.contains(id))
            .toList()) {
      _roomMemberSubscriptions.remove(roomId)?.cancel();
      _roomSessionSubscriptions.remove(roomId)?.cancel();
      _roomMessageSubscriptions.remove(roomId)?.cancel();
      _roomEventSubscriptions.remove(roomId)?.cancel();
      _roomActiveSessionIds.remove(roomId);
      _roomActivitySessions.removeWhere(
        (_, session) => session.roomId == roomId,
      );
    }

    for (final roomId in roomIds) {
      if (_roomMemberSubscriptions.containsKey(roomId)) continue;
      _roomMemberSubscriptions[roomId] = FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('members')
          .snapshots()
          .listen((snapshot) {
            final roomIndex = _studyRooms.indexWhere(
              (room) => room.id == roomId,
            );
            if (roomIndex == -1) return;
            final room = _studyRooms[roomIndex];
            final members = snapshot.docs
                .map(
                  (doc) => _roomMemberFromProjection(room, {
                    ...doc.data(),
                    'memberId': doc.id,
                  }),
                )
                .toList(growable: false);
            _studyRooms[roomIndex] = room.copyWith(members: members);
            final me = members.where(
              (member) => member.memberId == userId && member.isApproved,
            );
            if (me.isNotEmpty) {
              final myProjection = snapshot.docs.where(
                (doc) => doc.id == userId,
              );
              final activeSessionId = myProjection.isEmpty
                  ? null
                  : myProjection.first.data()['activeSessionId'] as String?;
              if (activeSessionId == null || activeSessionId.isEmpty) {
                _roomActiveSessionIds.remove(roomId);
              } else {
                _roomActiveSessionIds[roomId] = activeSessionId;
              }
              _ensureRoomSessionListener(roomId);
              _ensureRoomInteractionListeners(roomId);
            } else {
              _roomActiveSessionIds.remove(roomId);
              _roomSessionSubscriptions.remove(roomId)?.cancel();
              _roomMessageSubscriptions.remove(roomId)?.cancel();
              _roomEventSubscriptions.remove(roomId)?.cancel();
              _roomActivitySessions.removeWhere(
                (_, session) => session.roomId == roomId,
              );
              _studyRooms[roomIndex] = _studyRooms[roomIndex].copyWith(
                messages: const [],
                events: const [],
              );
            }
            notifyListeners();
          });
    }
  }

  void _ensureRoomSessionListener(String roomId) {
    if (_roomSessionSubscriptions.containsKey(roomId)) return;
    _roomSessionSubscriptions[roomId] = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('activity_sessions')
        .snapshots()
        .listen((snapshot) {
          _roomActivitySessions.removeWhere(
            (_, session) => session.roomId == roomId,
          );
          for (final doc in snapshot.docs) {
            try {
              final session = RoomActivitySession.fromJson(doc.data());
              _roomActivitySessions[session.sessionId] = session;
            } catch (error) {
              debugPrint('Skipping invalid room activity session: $error');
            }
          }
          notifyListeners();
        });
  }

  void _ensureRoomInteractionListeners(String roomId) {
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    if (!_roomMessageSubscriptions.containsKey(roomId)) {
      _roomMessageSubscriptions[roomId] = roomRef
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(60)
          .snapshots()
          .listen((snapshot) {
            final roomIndex = _studyRooms.indexWhere(
              (room) => room.id == roomId,
            );
            if (roomIndex == -1) return;
            final messages =
                snapshot.docs
                    .map(
                      (doc) => StudyRoomMessage.fromJson({
                        ...doc.data(),
                        'id': doc.id,
                      }),
                    )
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _studyRooms[roomIndex] = _studyRooms[roomIndex].copyWith(
              messages: messages.take(60).toList(growable: false),
            );
            notifyListeners();
          });
    }
    if (!_roomEventSubscriptions.containsKey(roomId)) {
      _roomEventSubscriptions[roomId] = roomRef
          .collection('events')
          .orderBy('createdAt', descending: true)
          .limit(80)
          .snapshots()
          .listen((snapshot) {
            final roomIndex = _studyRooms.indexWhere(
              (room) => room.id == roomId,
            );
            if (roomIndex == -1) return;
            final events =
                snapshot.docs
                    .map(
                      (doc) => StudyRoomEvent.fromJson({
                        ...doc.data(),
                        'id': doc.id,
                      }),
                    )
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _studyRooms[roomIndex] = _studyRooms[roomIndex].copyWith(
              events: events.take(80).toList(growable: false),
            );
            notifyListeners();
          });
    }
  }

  void _setupFamilyLinkListener(String userId) {
    _familyLinkSubscription?.cancel();
    _familyLinkSubscription = FirebaseFirestore.instance
        .collection('family_links')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
          final activeLinks =
              snapshot.docs
                  .where((doc) => doc.data()['status'] == 'active')
                  .map((doc) => FamilyLinkContract.fromMap(doc.id, doc.data()))
                  .toList(growable: false)
                ..sort((a, b) {
                  final updated = b.updatedAt.compareTo(a.updatedAt);
                  return updated == 0 ? a.id.compareTo(b.id) : updated;
                });
          _familyLinks = activeLinks;
          unawaited(_syncMyRelationshipMembershipDocuments(userId));
          if (activeLinks.isEmpty) {
            _familyLink = null;
            _selectedFamilyLinkId = null;
            _clearFamilyInteractionListeners();
            notifyListeners();
            return;
          }

          _activateSelectedFamilyLink(userId);
          notifyListeners();
        });
  }

  void _setupCanonicalGroupListener(String userId, String? groupId) {
    final normalizedGroupId = groupId?.trim();
    _projectedGroupId = normalizedGroupId == null || normalizedGroupId.isEmpty
        ? null
        : normalizedGroupId;
    if (_groupSubscription != null) {
      _activateSelectedGroup(userId);
      return;
    }

    _clearGroupPublicationListeners();
    _canonicalGroup = null;
    _listeningGroupId = null;
    _groupSubscription = FirebaseFirestore.instance
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .listen(
          (snapshot) {
            final activeGroups =
                snapshot.docs
                    .map((doc) => GroupContract.fromMap(doc.id, doc.data()))
                    .where((group) => group.isMember(userId))
                    .toList(growable: false)
                  ..sort((a, b) {
                    final name = a.name.compareTo(b.name);
                    return name == 0 ? a.id.compareTo(b.id) : name;
                  });
            _canonicalGroups = activeGroups;
            unawaited(_syncMyRelationshipMembershipDocuments(userId));
            if (activeGroups.isEmpty) {
              _canonicalGroup = null;
              _selectedGroupId = null;
              _listeningGroupId = null;
              _clearGroupPublicationListeners();
              notifyListeners();
              return;
            }

            _activateSelectedGroup(userId);
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Error listening to canonical group: $error');
            _canonicalGroup = null;
            _canonicalGroups = [];
            _clearGroupPublicationListeners();
            notifyListeners();
          },
        );
  }

  String _relationshipSelectionKey(String scope, String userId) =>
      'selected_${scope}_relationship_$userId';

  Future<void> _restoreRelationshipSelections(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser?.id != userId) return;
    _selectedFamilyLinkId = prefs.getString(
      _relationshipSelectionKey('family', userId),
    );
    final groupSelectionKey = _relationshipSelectionKey('group', userId);
    final legacyGroupId = prefs.getString('group_id_setting');
    _selectedGroupId = prefs.getString(groupSelectionKey) ?? legacyGroupId;
    if (prefs.getString(groupSelectionKey) == null && legacyGroupId != null) {
      await prefs.setString(groupSelectionKey, legacyGroupId);
    }
    await prefs.remove('group_id_setting');
    await prefs.remove('group_name_setting');
    await prefs.remove('is_group_owner_setting');
    _activateSelectedFamilyLink(userId);
    _activateSelectedGroup(userId);
    notifyListeners();
  }

  void _activateSelectedFamilyLink(String userId) {
    if (_familyLinks.isEmpty) return;
    final selectedId = _selectedFamilyLinkId;
    final selected = selectedId == null
        ? _familyLinks.first
        : _familyLinks.firstWhere(
            (link) => link.id == selectedId,
            orElse: () => _familyLinks.first,
          );
    _selectedFamilyLinkId = selected.id;
    _familyLink = selected;
    if (_listeningFamilyLinkId != selected.id) {
      _setupFamilyInteractionListeners(selected.id);
    }
    unawaited(_publishFamilySummarySnapshot());
  }

  void _activateSelectedGroup(String userId) {
    if (_canonicalGroups.isEmpty) return;
    final preferredId = _selectedGroupId ?? _projectedGroupId;
    final selected = preferredId == null
        ? _canonicalGroups.first
        : _canonicalGroups.firstWhere(
            (group) => group.id == preferredId,
            orElse: () => _canonicalGroups.first,
          );
    _selectedGroupId = selected.id;
    if (_listeningGroupId != selected.id) {
      _clearGroupPublicationListeners();
      _listeningGroupId = selected.id;
      _setupGroupPublicationListeners(selected.id);
    }
    _canonicalGroup = selected;
    _groupName = selected.name;
  }

  Future<void> selectFamilyRelationship(String familyLinkId) async {
    final userId = _currentUser?.id;
    if (userId == null) throw StateError('請先登入');
    if (!_familyLinks.any((link) => link.id == familyLinkId)) {
      throw ArgumentError('目前帳號沒有這個家庭關係');
    }
    _selectedFamilyLinkId = familyLinkId;
    _activateSelectedFamilyLink(userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _relationshipSelectionKey('family', userId),
      familyLinkId,
    );
    notifyListeners();
  }

  Future<void> selectGroupRelationship(String groupId) async {
    final userId = _currentUser?.id;
    if (userId == null) throw StateError('請先登入');
    if (!_canonicalGroups.any((group) => group.id == groupId)) {
      throw ArgumentError('目前帳號不是這個團體的有效成員');
    }
    _selectedGroupId = groupId;
    _activateSelectedGroup(userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_relationshipSelectionKey('group', userId), groupId);
    notifyListeners();
  }

  Future<void> _syncMyRelationshipMembershipDocuments(String userId) async {
    if (_currentUser?.id != userId) return;
    final memberships = <RelationshipMembership>[
      ..._familyLinks.map(
        (link) =>
            RelationshipMembership.fromFamilyLink(link: link, userId: userId),
      ),
      ..._canonicalGroups.map(
        (group) =>
            RelationshipMembership.fromGroup(group: group, userId: userId),
      ),
    ];
    if (memberships.isEmpty) return;
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    final now = DateTime.now();
    for (final membership in memberships) {
      batch.set(
        firestore.collection('relationship_memberships').doc(membership.id),
        membership.toFirestoreMap(now: now),
        SetOptions(merge: true),
      );
    }
    try {
      await batch.commit();
    } catch (error) {
      debugPrint('Failed to sync formal relationship memberships: $error');
    }
  }

  void _setupGroupPublicationListeners(String groupId) {
    if (_groupChallengeSubscription != null &&
        _groupChallengeParticipantsSubscription != null &&
        _groupSchedulesSubscription != null &&
        _groupTemplateSubscription != null &&
        _groupMemberSummariesSubscription != null) {
      return;
    }
    final groupRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId);
    _groupChallengeSubscription = groupRef
        .collection('challenges')
        .doc('current')
        .snapshots()
        .listen((snapshot) {
          _groupChallengePublication = snapshot.exists
              ? {'id': snapshot.id, ...?snapshot.data()}
              : null;
          _ensureCurrentGroupChallengeTasks();
          _scheduleCurrentGroupChallengeProgressSync();
          notifyListeners();
        });
    _groupChallengeParticipantsSubscription = groupRef
        .collection('challenges')
        .doc('current')
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
          _groupChallengeParticipations = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(growable: false);
          _ensureCurrentGroupChallengeTasks();
          _scheduleCurrentGroupChallengeProgressSync();
          notifyListeners();
        });
    _groupSchedulesSubscription = groupRef
        .collection('study_schedules')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
          _groupSchedulePublications = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(growable: false);
          notifyListeners();
        });
    _groupTemplateSubscription = groupRef
        .collection('templates')
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
          _groupTemplatePublications = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(growable: false);
          notifyListeners();
        });
    _groupMemberSummariesSubscription = groupRef
        .collection('member_summaries')
        .snapshots()
        .listen((snapshot) {
          _groupMemberSummaries =
              snapshot.docs
                  .map((doc) => GroupResultSummaryContract.fromMap(doc.data()))
                  .where((summary) => summary.memberId.isNotEmpty)
                  .toList(growable: false)
                ..sort(
                  (a, b) => b.disciplineScore.compareTo(a.disciplineScore),
                );
          _groupResultSharingEnabled = _groupMemberSummaries.any(
            (summary) => summary.memberId == _currentUser?.id,
          );
          notifyListeners();
        });
  }

  void _clearGroupPublicationListeners() {
    _groupChallengeSubscription?.cancel();
    _groupChallengeParticipantsSubscription?.cancel();
    _groupSchedulesSubscription?.cancel();
    _groupTemplateSubscription?.cancel();
    _groupMemberSummariesSubscription?.cancel();
    _groupResultSummaryPublishTimer?.cancel();
    _groupChallengeSubscription = null;
    _groupChallengeParticipantsSubscription = null;
    _groupSchedulesSubscription = null;
    _groupTemplateSubscription = null;
    _groupMemberSummariesSubscription = null;
    _groupResultSummaryPublishTimer = null;
    _groupChallengePublication = null;
    _groupChallengeParticipations = [];
    _groupSchedulePublications = [];
    _groupTemplatePublications = [];
    _groupMemberSummaries = [];
    _groupResultSharingEnabled = false;
  }

  void _setupFamilyInteractionListeners(String linkId) {
    _clearFamilyInteractionListeners();
    _listeningFamilyLinkId = linkId;
    final linkRef = FirebaseFirestore.instance
        .collection('family_links')
        .doc(linkId);

    _familyEncouragementSubscription = linkRef
        .collection('encouragements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          _familyEncouragements = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(growable: false);
          notifyListeners();
        });

    _familyGoalSubscription = linkRef
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          _familyGoals = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(growable: false);
          notifyListeners();
        });

    _familyBondEventSubscription = linkRef
        .collection('bond_events')
        .snapshots()
        .listen((snapshot) {
          _familyBondEvents = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(growable: false);
          notifyListeners();
        });

    _familySummarySubscription = linkRef
        .collection('summaries')
        .doc('current')
        .snapshots()
        .listen((snapshot) {
          _familySummary = snapshot.exists ? snapshot.data() : null;
          notifyListeners();
        });
  }

  void _clearFamilyInteractionListeners() {
    _familyEncouragementSubscription?.cancel();
    _familyGoalSubscription?.cancel();
    _familyBondEventSubscription?.cancel();
    _familySummarySubscription?.cancel();
    _familySummaryPublishTimer?.cancel();
    _familyEncouragementSubscription = null;
    _familyGoalSubscription = null;
    _familyBondEventSubscription = null;
    _familySummarySubscription = null;
    _familySummaryPublishTimer = null;
    _listeningFamilyLinkId = null;
    _familyEncouragements = [];
    _familyGoals = [];
    _familyBondEvents = [];
    _familySummary = null;
  }

  void _cancelFirestoreListeners() {
    _userSubscription?.cancel();
    _friendsSubscription?.cancel();
    _incomingRequestsSubscription?.cancel();
    _outgoingRequestsSubscription?.cancel();
    _roomsSubscription?.cancel();
    _roomDiscoverySubscription?.cancel();
    for (final subscription in _roomMemberSubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _roomSessionSubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _roomMessageSubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _roomEventSubscriptions.values) {
      subscription.cancel();
    }
    _roomMemberSubscriptions.clear();
    _roomSessionSubscriptions.clear();
    _roomMessageSubscriptions.clear();
    _roomEventSubscriptions.clear();
    _shopSubscription?.cancel();
    _incomingGuardianRequestsSubscription?.cancel();
    _outgoingGuardianRequestsSubscription?.cancel();
    _familyLinkSubscription?.cancel();
    _familyEncouragementSubscription?.cancel();
    _familyGoalSubscription?.cancel();
    _familyBondEventSubscription?.cancel();
    _familySummarySubscription?.cancel();
    _familySummaryPublishTimer?.cancel();
    _groupResultSummaryPublishTimer?.cancel();
    _incomingGroupRequestsSubscription?.cancel();
    _groupSubscription?.cancel();
    _clearGroupPublicationListeners();

    _userSubscription = null;
    _friendsSubscription = null;
    _incomingRequestsSubscription = null;
    _outgoingRequestsSubscription = null;
    _roomsSubscription = null;
    _roomDiscoverySubscription = null;
    _shopSubscription = null;
    _incomingGuardianRequestsSubscription = null;
    _outgoingGuardianRequestsSubscription = null;
    _familyLinkSubscription = null;
    _familyEncouragementSubscription = null;
    _familyGoalSubscription = null;
    _familyBondEventSubscription = null;
    _familySummarySubscription = null;
    _familySummaryPublishTimer = null;
    _groupResultSummaryPublishTimer = null;
    _listeningFamilyLinkId = null;
    _familyLink = null;
    _familyLinks = [];
    _selectedFamilyLinkId = null;
    _familyEncouragements = [];
    _familyGoals = [];
    _familyBondEvents = [];
    _familySummary = null;
    _incomingGroupRequestsSubscription = null;
    _groupSubscription = null;
    _canonicalGroup = null;
    _canonicalGroups = [];
    _selectedGroupId = null;
    _listeningGroupId = null;
    _projectedGroupId = null;
    _discoverableStudyRooms = [];
    _roomActivitySessions.clear();
    _roomActiveSessionIds.clear();
  }

  @override
  void dispose() {
    _dailyResetTimer?.cancel();
    _dailyResetTimer = null;
    _familySummaryPublishTimer?.cancel();
    _familySummaryPublishTimer = null;
    _cancelFirestoreListeners();
    super.dispose();
  }

  Future<void> _autoUpdateLinkage(
    Map<String, dynamic> requestData,
    String myUid,
  ) async {
    final senderId = requestData['senderId'] as String;
    final senderNudgeId = requestData['senderNudgeId'] as String;
    final receiverNudgeId = requestData['receiverNudgeId'] as String;
    final targetNudgeId = (myUid == senderId) ? receiverNudgeId : senderNudgeId;
    final targetRole = myUid == senderId
        ? requestData['receiverRole']
        : requestData['senderRole'];

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(myUid);
      await docRef.update({
        'webToolsState.guardianInvite': {
          'linkId': requestData['id'],
          'relativeId': targetNudgeId,
          'relativeRole': targetRole,
          'goal': '共同健康與專注',
          'permission': '只看總覽',
          'message': '親屬帳號已連結。',
        },
        'webToolsState.guardianInviteStatus': {
          'status': 'linked',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      debugPrint('Failed to auto-update relative linkage: $e');
    }
  }

  Future<void> _autoClearLinkage(String myUid) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(myUid);
      await docRef.update({
        'webToolsState.guardianInvite': FieldValue.delete(),
        'webToolsState.guardianInviteStatus': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Failed to auto-clear relative linkage: $e');
    }
  }

  Future<void> _checkAndAutoClearLinkage(String myUid) async {
    if (!isGuardianLinked) return;
    try {
      final incomingAccepted = await FirebaseFirestore.instance
          .collection('guardian_requests')
          .where('receiverId', isEqualTo: myUid)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();
      if (incomingAccepted.docs.isNotEmpty) return;

      final outgoingAccepted = await FirebaseFirestore.instance
          .collection('guardian_requests')
          .where('senderId', isEqualTo: myUid)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();
      if (outgoingAccepted.docs.isNotEmpty) return;

      await _autoClearLinkage(myUid);
    } catch (e) {
      debugPrint('Failed to check and clear linkage: $e');
    }
  }

  Future<void> _syncProfileFromFirebaseUser(fb_auth.User user) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        _currentUser = UserModel.fromJson(data);
        _profileNickname = _currentUser!.nickname;
        _profileSignature = _currentUser!.signature;
        _myNudgeId = _currentUser!.username;
        await pullDataFromFirestore();
        await _syncPublicProfile();
      } else {
        final now = DateTime.now();
        _currentUser = UserModel(
          id: user.uid,
          email: user.email,
          username: 'NDG_${user.uid.substring(0, 6).toUpperCase()}',
          nickname: _profileNickname,
          signature: _profileSignature,
          authProvider: 'email',
          avatarProfileId: 'local_avatar',
          themeMode: _themeModeSetting,
          accentColor: _iconColorSetting,
          timezone: now.timeZoneName,
          isActive: true,
          createdAt: now,
          updatedAt: now,
          lastLoginAt: now,
        );
        await docRef.set(_currentUser!.toJson());
        _myNudgeId = _currentUser!.username;
        await syncDataToFirestore();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing user profile from Firebase: $e');
    }
  }

  Map<String, dynamic> _buildPublicProfilePayload() {
    final user = _currentUser!;
    final avatar = _avatarProfile;
    final familyRole = const {'guardian', 'child'}.contains(_userRole)
        ? _userRole
        : 'personal';
    return {
      'schemaVersion': 1,
      'userId': user.id,
      'username': user.username,
      'myNudgeId': _myNudgeId.isEmpty ? user.username : _myNudgeId,
      'nickname': _profileNickname.trim().isEmpty
          ? '自律使用者'
          : _profileNickname.trim(),
      'signature': _profileSignature.trim(),
      'avatarProfile': {
        'skinToneIndex': avatar.skinToneIndex,
        'faceShapeIndex': avatar.faceShapeIndex,
        'hairStyleIndex': avatar.hairStyleIndex,
        'hairColorIndex': avatar.hairColorIndex,
        'eyeStyleIndex': avatar.eyeStyleIndex,
        'eyebrowStyleIndex': avatar.eyebrowStyleIndex,
        'mouthStyleIndex': avatar.mouthStyleIndex,
        'outfitStyleIndex': avatar.outfitStyleIndex,
        'outfitColorIndex': avatar.outfitColorIndex,
        'accessoryIndex': avatar.accessoryIndex,
        'backgroundColorIndex': avatar.backgroundColorIndex,
        'avatarIconIndex': avatar.avatarIconIndex,
      },
      'accentColor':
          const {
            'purple',
            'blue',
            'teal',
            'green',
            'orange',
            'pink',
            'red',
            'indigo',
          }.contains(_iconColorSetting)
          ? _iconColorSetting
          : 'purple',
      'planetCount': math.max(0, _planetCount),
      'familyRole': familyRole,
      'profileTitleBadgeKey': _profileTitleBadgeKey,
      'unlockedBadgeDates': _unlockedBadgeDates,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> _syncPublicProfile() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('public_profiles')
          .doc(user.id)
          .set(_buildPublicProfilePayload());
    } catch (error) {
      debugPrint('Failed to sync public profile: $error');
    }
  }

  Future<void> syncDataToFirestore() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.id);
      await docRef.set({
        'nickname': _profileNickname,
        'signature': _profileSignature,
        'myNudgeId': _myNudgeId,
        'themeMode': _themeModeSetting,
        'accentColor': _iconColorSetting,
        'backgroundTheme': _backgroundThemeSetting,
        'profileTitleBadgeKey': _profileTitleBadgeKey,
        'disciplineCoins': _disciplineCoins,
        'planetCount': _planetCount,
        'unlockedPlanets': _unlockedPlanets,
        'weeklyPlanetEarned': _weeklyPlanetEarned,
        'lastSettledWeekMonday': _lastSettledWeekMonday,
        'rewardedTaskKeys': _rewardedTaskKeys.toList(),
        'dailyCoinEarned': _dailyCoinEarned,
        'monthlyDeadlineCoinEarned': _monthlyDeadlineCoinEarned,
        'focusSeconds':
            _focusSeconds, // ← synced for web dashboard real-time stats
        'avatarProfile': _avatarProfile.toJson(),
        'avatarExperienceLedger': _avatarExperienceLedger,
        'avatarExperience': avatarExperience,
        'avatarLevel': avatarLevel,
        'avatarSeries': currentAvatarSeries,
        'unlockedAvatarItems': _unlockedAvatarItemKeys.toList(),
        'tasks': _tasks,
        'dailySummaries': _dailySummaries.map((s) => s.toJson()).toList(),
        'unlockedBadgeDates': _unlockedBadgeDates,
        'userRole': _userRole,
        'webToolsState': _webToolsState,
        'webToolsCollection': _webToolsCollection,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _syncPublicProfile();
    } catch (e) {
      debugPrint('Failed to sync to Firestore: $e');
    }
  }

  Future<void> pullDataFromFirestore() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.id);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        if (data['tasks'] != null) {
          _tasks = List<Map<String, dynamic>>.from(
            (data['tasks'] as List).map((t) => Map<String, dynamic>.from(t)),
          );
        }
        _disciplineCoins =
            (data['disciplineCoins'] as num?)?.toInt() ?? _disciplineCoins;
        _unlockedPlanets = _parseUnlockedPlanets(data);
        _planetCount = _unlockedPlanets.length - 1;
        _weeklyPlanetEarned =
            data['weeklyPlanetEarned'] as bool? ?? _weeklyPlanetEarned;
        _lastSettledWeekMonday =
            data['lastSettledWeekMonday'] as String? ?? _lastSettledWeekMonday;
        if (data['rewardedTaskKeys'] != null) {
          _rewardedTaskKeys = Set<String>.from(
            List<String>.from(data['rewardedTaskKeys']),
          );
        }
        if (data['dailyCoinEarned'] != null) {
          final Map decoded = data['dailyCoinEarned'] as Map;
          _dailyCoinEarned = decoded.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          );
        }
        if (data['monthlyDeadlineCoinEarned'] != null) {
          final Map decoded = data['monthlyDeadlineCoinEarned'] as Map;
          _monthlyDeadlineCoinEarned = decoded.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          );
        }
        _applyAvatarExperienceData(data);
        if (data['unlockedAvatarItems'] != null) {
          _unlockedAvatarItemKeys = Set<String>.from(
            List<String>.from(data['unlockedAvatarItems']),
          );
        }
        if (data['unlockedBadgeDates'] != null) {
          _unlockedBadgeDates = Map<String, String>.from(
            data['unlockedBadgeDates'],
          );
        }
        if (data['dailySummaries'] != null) {
          _dailySummaries = List<DailySummary>.from(
            (data['dailySummaries'] as List).map(
              (s) => DailySummary.fromJson(Map<String, dynamic>.from(s)),
            ),
          );
        }
        if (data['webToolsState'] != null) {
          _webToolsState = Map<String, dynamic>.from(
            data['webToolsState'] as Map,
          );
        } else {
          _webToolsState = null;
        }
        if (data['webToolsCollection'] != null) {
          _webToolsCollection = Map<String, dynamic>.from(
            data['webToolsCollection'] as Map,
          );
        } else {
          _webToolsCollection = null;
        }
        _profileNickname = data['nickname'] as String? ?? _profileNickname;
        _profileSignature = data['signature'] as String? ?? _profileSignature;
        _myNudgeId = data['myNudgeId'] as String? ?? _myNudgeId;
        _themeModeSetting = data['themeMode'] as String? ?? _themeModeSetting;
        _iconColorSetting = data['accentColor'] as String? ?? _iconColorSetting;
        _profileTitleBadgeKey =
            data['profileTitleBadgeKey'] as String? ?? _profileTitleBadgeKey;
        _userRole = data['userRole'] as String? ?? _userRole;
        // Restore background theme across devices
        if (data['backgroundTheme'] != null) {
          final bt = data['backgroundTheme'] as String;
          if (AppUI.backgroundThemeKeys.contains(bt)) {
            _backgroundThemeSetting = bt;
          }
        }
        // Restore today's focus seconds
        if (data['focusSeconds'] != null) {
          final cloudFocusSeconds =
              (data['focusSeconds'] as num?)?.toInt() ?? 0;
          // Only restore if cloud data is more recent (higher value) — avoids overwriting fresh session
          if (cloudFocusSeconds > _focusSeconds) {
            _focusSeconds = cloudFocusSeconds;
          }
        }
        _syncTaskRewards();
        await checkWeeklyPlanetSettlement();
        notifyListeners();

        // Also save locally so that it matches
        await _saveAppearanceSettings();
        await _saveTasks();
        await _saveDailySummaries();
        await _saveAvatarExperienceLedger();
        await _saveAvatarUnlockState();
        await _saveRewardState();
      }
    } catch (e) {
      debugPrint('Failed to pull from Firestore: $e');
    }
  }

  static const List<ReminderChannelSetting> _defaultReminderSettings = [
    ReminderChannelSetting(
      key: 'tasks',
      title: '任務提醒',
      description: '提醒尚未完成的今日可執行任務。',
      timeLabel: '20:30',
      enabled: true,
    ),
    ReminderChannelSetting(
      key: 'sleep',
      title: '睡眠提醒',
      description: '睡前提醒，幫助健康任務穩定累積。',
      timeLabel: '23:00',
      enabled: true,
    ),
    ReminderChannelSetting(
      key: 'rooms',
      title: '自律房開始提醒',
      description: '朋友或房間開始活動時提醒你回到房間。',
      timeLabel: '19:30',
      enabled: true,
    ),
    ReminderChannelSetting(
      key: 'deadline',
      title: '截止日提醒',
      description: '截止日前提醒拆任務與驗收，不列入每日分數。',
      timeLabel: '09:00',
      enabled: true,
    ),
  ];

  final List<Map<String, dynamic>> _defaultTasks = [
    {
      'title': '完成 2 小時讀書',
      'done': false,
      'isDone': false,
      'category': '讀書',
      'taskType': 'fixed',
      'dueDate': null,
      'priority': '高',
    },
    {
      'title': '步行超過 6000 步',
      'done': false,
      'isDone': false,
      'category': '運動',
      'taskType': 'fixed',
      'dueDate': null,
      'priority': '中',
    },
    {
      'title': '運動 30 分鐘',
      'done': false,
      'isDone': false,
      'category': '運動',
      'taskType': 'fixed',
      'dueDate': null,
      'priority': '中',
    },
    {
      'title': '晚上 11:30 前睡覺',
      'done': false,
      'isDone': false,
      'category': '睡眠',
      'taskType': 'fixed',
      'dueDate': null,
      'priority': '高',
    },
    {
      'title': '準備期中報告',
      'done': false,
      'isDone': false,
      'category': '讀書',
      'taskType': 'deadline',
      'dueDate': null,
      'priority': '高',
    },
  ];

  static const String _themeModeKey = 'theme_mode_setting';
  static const String _iconColorKey = 'icon_color_setting';
  static const String _backgroundThemeKey = 'background_theme_setting';
  static const String _focusSecondsKey = 'focus_seconds_setting';
  static const String _studyRoomsKey = 'study_rooms_setting';
  static const String _profileNicknameKey = 'profile_nickname_setting';
  static const String _profileSignatureKey = 'profile_signature_setting';
  static const String _profileTitleBadgeStorageKey =
      'profile_title_badge_key_setting';
  static const String _reminderSettingsKey = 'reminder_settings';
  static const String _avatarProfileKey = 'avatar_profile_setting';
  static const String _socialFriendsKey = 'social_friends_setting';
  static const String _myNudgeIdKey = 'my_nudge_id_setting';
  static const String _friendRequestsKey = 'friend_requests_setting';
  static const String _currentUserKey = 'current_user_setting';
  static const String _privacyConsentKey = 'privacy_consent_setting';
  static const String _privacyConsentAtKey = 'privacy_consent_at_setting';
  static const String _onboardingCompletedKey = 'onboarding_completed_setting';
  static const String _seenUnlockedBadgesKey = 'seen_unlocked_badges_setting';
  static const String _unlockedBadgesKey = 'unlocked_badges_setting';
  static const String _socialEncouragementRecordsKey =
      'social_encouragement_records_setting';
  static const String _studyGoalTaskTitle = '完成今日自律房目標';
  static const String _legacyStudyGoalTaskTitle = '完成今日共讀目標';
  static const String _lastDailyResetDateKey = 'last_daily_reset_date';
  static const String _disciplineCoinsKey = 'discipline_coins_setting';
  static const String _planetCountKey = 'planet_count_setting';
  static const String _unlockedPlanetsKey = 'unlocked_planets_setting';
  static const String _weeklyPlanetEarnedKey = 'weekly_planet_earned_setting';
  static const String _lastSettledWeekMondayKey =
      'last_settled_week_monday_setting';
  static const String _rewardedTaskKeysKey = 'rewarded_task_keys_setting';
  static const String _dailyCoinEarnedKey = 'daily_coin_earned_setting';
  static const String _monthlyDeadlineCoinEarnedKey =
      'monthly_deadline_coin_earned_setting';
  static const String _unlockedAvatarItemsKey = 'unlocked_avatar_items_setting';
  static const String _avatarExperienceLedgerKey =
      'avatar_experience_ledger_setting';
  static const int coinDailyLimit = 15;
  static const int coinWeeklyLimit = 100;
  static const int coinMonthlyLimit = 400;
  static const int deadlineTaskMinLeadDays = 2;
  static const int deadlineTaskBonusCoins = 5;
  static const int deadlineTaskMonthlyCoinLimit = 15;
  static const int deadlineTaskMonthlyCreateLimit = 3;
  static const Map<int, int> scoreCoinMilestones = {
    20: 3,
    40: 3,
    60: 3,
    80: 3,
    100: 3,
  };
  static const int avatarDailyScoreExperienceCap = 400;
  static const int avatarDailyAutoExperienceCap = 100;
  static const int avatarAutoFocusFullMinutes = 60;
  static const double avatarAutoSleepFullHours = 7;
  static const int avatarAutoStepsFull = 8000;
  static const int avatarAutoExerciseFullMinutes = 30;
  static const int avatarMaxLevel = 60;
  static const double _avatarLevelCurveA = 5.454899668809663;
  static const double _avatarLevelCurveB = 186.63549581141635;

  List<Map<String, dynamic>> _tasks = [];
  int _focusSeconds = 0;
  double _sleepHours = 0.0;
  int _steps = 0;
  int _exerciseMinutes = 0;
  bool _isHealthConnected = false;
  List<DailySummary> _dailySummaries = [];
  int _disciplineCoins = 0;
  int _planetCount = 0;
  bool _weeklyPlanetEarned = false;
  List<String> _unlockedPlanets = ['新手星球'];
  List<String> get unlockedPlanets => _unlockedPlanets;
  String? _lastSettledWeekMonday;
  String? _lastResetDateInMemory;
  Set<String> _rewardedTaskKeys = <String>{};
  Map<String, int> _dailyCoinEarned = <String, int>{};
  Map<String, int> _monthlyDeadlineCoinEarned = <String, int>{};
  Set<String> _unlockedAvatarItemKeys = <String>{};
  Map<String, Map<String, int>> _avatarExperienceLedger =
      <String, Map<String, int>>{};

  String _themeModeSetting = 'system';
  String _iconColorSetting = 'purple';
  String _backgroundThemeSetting = 'softGlow';

  String _profileNickname = '老闆';
  String _profileSignature = '今天也在穩定前進';
  String _profileTitleBadgeKey = '';
  List<ReminderChannelSetting> _reminderSettings = List.of(
    _defaultReminderSettings,
  );

  AvatarProfile _avatarProfile = AvatarProfile.initial();

  List<StudyRoomData> _studyRooms = [];
  List<SocialFriendProfile> _socialFriends = [];
  List<FriendRequest> _friendRequests = [];
  String _myNudgeId = '';
  UserModel? _currentUser;
  bool _hasAcceptedPrivacyPolicy = false;
  DateTime? _privacyAcceptedAt;
  bool _hasCompletedOnboarding = false;
  bool _isHydrated = false;
  Set<String> _seenUnlockedBadgeKeys = <String>{};
  Map<String, String> _unlockedBadgeDates = <String, String>{};
  List<SocialEncouragementRecord> _socialEncouragementRecords = [];
  Map<String, dynamic>? _webToolsState;
  Map<String, dynamic>? _webToolsCollection;
  String _userRole = 'personal';
  String? _groupId;
  String? _groupName;
  GroupContract? _canonicalGroup;
  List<GroupContract> _canonicalGroups = [];
  String? _selectedGroupId;
  Map<String, dynamic>? _groupChallengePublication;
  List<Map<String, dynamic>> _groupChallengeParticipations = [];
  List<Map<String, dynamic>> _groupSchedulePublications = [];
  List<Map<String, dynamic>> _groupTemplatePublications = [];
  List<GroupResultSummaryContract> _groupMemberSummaries = [];
  bool _groupResultSharingEnabled = false;

  List<Map<String, dynamic>> get tasks => _tasks;
  Map<String, dynamic>? get webToolsState => _webToolsState;
  Map<String, dynamic>? get webToolsCollection => _webToolsCollection;
  String get userRole => _userRole;
  GroupContract? get canonicalGroup => _canonicalGroup;
  List<GroupContract> get canonicalGroups =>
      List<GroupContract>.unmodifiable(_canonicalGroups);
  String? get selectedGroupId => _selectedGroupId;
  String? get groupId => _canonicalGroup?.id;
  String? get groupName => _canonicalGroup?.name;
  bool get isGroupOwner =>
      _canonicalGroup?.isManager(_currentUser?.id ?? '') ?? false;
  bool get hasActiveGroupMembership =>
      _canonicalGroup?.isMember(_currentUser?.id ?? '') ?? false;
  List<GroupResultSummaryContract> get groupMemberSummaries =>
      List<GroupResultSummaryContract>.unmodifiable(_groupMemberSummaries);
  bool get isGroupResultSharingEnabled => _groupResultSharingEnabled;
  bool get isGuardianLinked => _familyLink?.status == FamilyLinkStatus.active;
  FamilyLinkContract? get familyLink => _familyLink;
  List<FamilyLinkContract> get familyLinks =>
      List<FamilyLinkContract>.unmodifiable(_familyLinks);
  String? get selectedFamilyLinkId => _selectedFamilyLinkId;
  bool get isCurrentFamilyGuardian =>
      _familyLink != null && _currentUser?.id == _familyLink!.guardianId;
  bool get isCurrentFamilyChild =>
      _familyLink != null && _currentUser?.id == _familyLink!.childId;
  List<RelationshipMembership> get relationshipMemberships {
    final userId = _currentUser?.id;
    if (userId == null) return const [];
    return List<RelationshipMembership>.unmodifiable([
      ..._familyLinks.map(
        (link) =>
            RelationshipMembership.fromFamilyLink(link: link, userId: userId),
      ),
      ..._canonicalGroups.map(
        (group) =>
            RelationshipMembership.fromGroup(group: group, userId: userId),
      ),
    ]);
  }

  List<Map<String, dynamic>> get familyGoals => List.unmodifiable(_familyGoals);
  Map<String, dynamic>? get activeFamilyGoal {
    for (final goal in _familyGoals) {
      if (goal['status'] == 'proposed' || goal['status'] == 'accepted') {
        return Map<String, dynamic>.unmodifiable(goal);
      }
    }
    return null;
  }

  Map<String, dynamic>? get familySummary => _familySummary == null
      ? null
      : Map<String, dynamic>.unmodifiable(_familySummary!);

  int get familyBondXp => _familyBondEvents.fold<int>(
    0,
    (total, event) => total + ((event['points'] as num?)?.toInt() ?? 0),
  );
  int get familyBondLevel => FamilyBondPolicy.levelForXp(familyBondXp);
  ExperienceCapabilities get experienceCapabilities =>
      ExperienceCapabilities.resolve(
        rawRole: _userRole,
        isGroupOwner: isGroupOwner,
        hasGroup: hasActiveGroupMembership,
        isGuardianLinked: isGuardianLinked,
        isFamilyGuardian: isCurrentFamilyGuardian,
        isFamilyChild: isCurrentFamilyChild,
      );

  Map<String, dynamic>? get guardianInvite {
    if (_webToolsState == null) return null;
    final invite = _webToolsState!['guardianInvite'];
    if (invite == null) return null;
    final status =
        _webToolsState!['guardianInviteStatus']?['status'] ??
        'pending_child_approval';
    return {...Map<String, dynamic>.from(invite as Map), 'status': status};
  }

  List<Map<String, dynamic>> get guardianEncouragements {
    return List<Map<String, dynamic>>.unmodifiable(_familyEncouragements);
  }

  List<Map<String, dynamic>> get timeCapsules {
    if (_webToolsCollection == null ||
        _webToolsCollection!['capsules'] == null) {
      return [];
    }
    return List<Map<String, dynamic>>.from(
      (_webToolsCollection!['capsules'] as List).map(
        (x) => Map<String, dynamic>.from(x as Map),
      ),
    );
  }

  Map<String, dynamic>? get futureLetter {
    if (_webToolsState == null || _webToolsState!['futureLetter'] == null) {
      return null;
    }
    return Map<String, dynamic>.from(_webToolsState!['futureLetter'] as Map);
  }

  Map<String, dynamic>? get groupChallenge {
    return _groupChallengePublication == null
        ? null
        : Map<String, dynamic>.unmodifiable(_groupChallengePublication!);
  }

  List<Map<String, dynamic>> get groupChallengeParticipations =>
      List<Map<String, dynamic>>.unmodifiable(_groupChallengeParticipations);

  Map<String, dynamic>? get currentGroupChallengeParticipation {
    final challengeId = _groupChallengePublication?['challengeId']?.toString();
    final memberId = _currentUser?.id;
    if (challengeId == null || memberId == null) return null;
    for (final participation in _groupChallengeParticipations) {
      if (participation['challengeId'] == challengeId &&
          participation['memberId'] == memberId) {
        return Map<String, dynamic>.unmodifiable(participation);
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get studySchedules {
    return List<Map<String, dynamic>>.unmodifiable(_groupSchedulePublications);
  }

  List<Map<String, dynamic>> get groupTemplates {
    return List<Map<String, dynamic>>.unmodifiable(_groupTemplatePublications);
  }

  int get focusSeconds => _focusSeconds;
  int get focusMinutes => _focusSeconds ~/ 60;
  double get sleepHours => _sleepHours;
  int get steps => _steps;
  int get exerciseMinutes => _exerciseMinutes;
  bool get isHealthConnected => _isHealthConnected;
  List<DailySummary> get dailySummaries => _dailySummaries;
  DailySummary get todaySummary => _buildTodayExperienceSummary();
  String get todayKey => _todayKey();
  int get disciplineCoins => _disciplineCoins;
  int get planetCount => _planetCount;
  bool get weeklyPlanetEarned => _weeklyPlanetEarned;
  String? get lastSettledWeekMonday => _lastSettledWeekMonday;
  int get unlockedAvatarItemCount => _unlockedAvatarItemKeys.length;
  int get todayCoinEarned => _dailyCoinEarned[_todayKey()] ?? 0;
  int get todayCoinRemaining {
    final remaining = coinDailyLimit - todayCoinEarned;
    return remaining < 0 ? 0 : remaining;
  }

  int get currentWeekCoinEarned {
    final start = _currentWeekStart();
    return _coinEarnedBetween(start, start.add(const Duration(days: 7)));
  }

  int get currentWeekCoinRemaining {
    final remaining = coinWeeklyLimit - currentWeekCoinEarned;
    return remaining < 0 ? 0 : remaining;
  }

  int get currentMonthCoinEarned {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    return _coinEarnedBetween(start, end);
  }

  int get currentMonthCoinRemaining {
    final remaining = coinMonthlyLimit - currentMonthCoinEarned;
    return remaining < 0 ? 0 : remaining;
  }

  int get scoreCoinRemaining {
    return math.min(
      todayCoinRemaining,
      math.min(currentWeekCoinRemaining, currentMonthCoinRemaining),
    );
  }

  int get currentMonthDeadlineCoinEarned =>
      _monthlyDeadlineCoinEarned[_monthKey()] ?? 0;
  int get currentMonthDeadlineCoinRemaining {
    final remaining =
        deadlineTaskMonthlyCoinLimit - currentMonthDeadlineCoinEarned;
    return remaining < 0 ? 0 : remaining;
  }

  int deadlineTaskCountForMonth(DateTime date, {int? excludingIndex}) {
    final month = _monthKeyForDate(date);
    var count = 0;
    for (var i = 0; i < _tasks.length; i++) {
      if (excludingIndex != null && i == excludingIndex) continue;
      final task = _tasks[i];
      if (task['taskType'] != 'deadline') continue;
      final dueDate = DateTime.tryParse(task['dueDate'] as String? ?? '');
      if (dueDate == null) continue;
      if (_monthKeyForDate(dueDate) == month) count++;
    }
    return count;
  }

  bool canCreateDeadlineTaskForDate(DateTime date, {int? excludingIndex}) {
    return deadlineTaskCountForMonth(date, excludingIndex: excludingIndex) <
        deadlineTaskMonthlyCreateLimit;
  }

  int get todayWeightedDisciplineScore => _weightedTaskScore();
  int? get nextScoreCoinMilestone {
    if (scoreCoinRemaining <= 0) return null;
    final score = todayWeightedDisciplineScore;
    for (final threshold in scoreCoinMilestones.keys) {
      final key = _scoreMilestoneRewardKey(threshold);
      if (score < threshold || _rewardedTaskKeys.contains(key)) continue;
      return threshold;
    }
    for (final threshold in scoreCoinMilestones.keys) {
      if (score < threshold) return threshold;
    }
    return null;
  }

  List<StudyRoomData> get studyRooms => _studyRooms;
  List<StudyRoomData> get discoverableStudyRooms =>
      List.unmodifiable(_discoverableStudyRooms);
  List<SocialFriendProfile> get socialFriends => _socialFriends;
  List<FriendRequest> get friendRequests => _friendRequests;
  String get myNudgeId => _myNudgeId;
  String get myFriendInvitePayload {
    final uri = Uri(
      scheme: 'nudge',
      host: 'friend',
      path: 'add',
      queryParameters: {
        'nudgeId': _myNudgeId,
        'name': _profileNickname,
        'signature': _profileSignature,
      },
    );
    return uri.toString();
  }

  UserModel? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get hasAcceptedPrivacyPolicy => _hasAcceptedPrivacyPolicy;
  DateTime? get privacyAcceptedAt => _privacyAcceptedAt;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get isHydrated => _isHydrated;
  String get accountProviderLabel {
    if (_currentUser == null) return '尚未登入';
    switch (_currentUser?.authProvider) {
      case 'email':
      case 'local':
        return 'Email';
      case 'google':
        return 'Google';
      case 'apple':
        return 'Apple';
      default:
        return '已登入';
    }
  }

  List<FriendRequest> get incomingFriendRequests => _friendRequests
      .where(
        (request) =>
            request.direction == FriendRequestDirection.incoming &&
            request.status == FriendRequestStatus.pending,
      )
      .toList();
  List<FriendRequest> get outgoingFriendRequests => _friendRequests
      .where(
        (request) =>
            request.direction == FriendRequestDirection.outgoing &&
            request.status == FriendRequestStatus.pending,
      )
      .toList();
  List<SocialEncouragementRecord> get socialEncouragementRecords =>
      _socialEncouragementRecords;

  String get themeModeSetting => _themeModeSetting;
  String get iconColorSetting => _iconColorSetting;
  String get backgroundThemeSetting => _backgroundThemeSetting;
  String get profileNickname => _profileNickname;
  String get profileSignature => _profileSignature;
  String get profileTitleBadgeKey => _profileTitleBadgeKey;
  List<ReminderChannelSetting> get reminderSettings =>
      List.unmodifiable(_reminderSettings);
  int get enabledReminderCount =>
      _reminderSettings.where((setting) => setting.enabled).length;
  String get profileTitle {
    if (_profileTitleBadgeKey.isEmpty) return '';

    final matches = badgeRecords.where(
      (badge) => badge.badgeKey == _profileTitleBadgeKey && badge.isUnlocked,
    );
    return matches.isEmpty ? '' : matches.first.badgeName;
  }

  AvatarProfile get avatarProfile => _avatarProfile;
  String get currentAvatarSeries {
    return AvatarCatalog.stageForIndex(_avatarProfile.faceShapeIndex).series;
  }

  int get todayAvatarExperience {
    return todayAvatarExperienceForSeries(currentAvatarSeries);
  }

  int get todayAvatarScoreExperience {
    return todayAvatarScoreExperienceForSeries(currentAvatarSeries);
  }

  int get todayAvatarAutoExperience {
    return todayAvatarAutoExperienceForSeries(currentAvatarSeries);
  }

  int get avatarExperience {
    return avatarExperienceForSeries(currentAvatarSeries);
  }

  int get avatarLevel {
    return avatarLevelForSeries(currentAvatarSeries);
  }

  int get avatarNextLevelExperience {
    if (avatarLevel >= avatarMaxLevel) {
      return avatarExperienceRequiredForLevel(avatarMaxLevel);
    }
    return avatarExperienceRequiredForLevel(avatarLevel + 1);
  }

  int get avatarExperienceToNextLevel {
    if (avatarLevel >= avatarMaxLevel) return 0;
    final remaining = avatarNextLevelExperience - avatarExperience;
    return remaining < 0 ? 0 : remaining;
  }

  int avatarExperienceForSeries(String series) {
    var total = 0;
    for (final entry in _avatarExperienceLedger.values) {
      total += entry[series] ?? 0;
    }
    return total;
  }

  int avatarExperienceForStage(int index) {
    return avatarExperienceForSeries(AvatarCatalog.stageForIndex(index).series);
  }

  int todayAvatarExperienceForSeries(String series) {
    return _avatarExperienceLedger[_todayKey()]?[series] ?? 0;
  }

  double _todayAvatarExperienceRatioForSeries(String series) {
    final summary = _buildTodayExperienceSummary();
    final totalTodayExperience = avatarExperienceForSummary(summary);
    if (totalTodayExperience <= 0) return 0;
    return (todayAvatarExperienceForSeries(series) / totalTodayExperience)
        .clamp(0, 1)
        .toDouble();
  }

  int todayAvatarScoreExperienceForSeries(String series) {
    final ratio = _todayAvatarExperienceRatioForSeries(series);
    return (avatarScoreExperienceForSummary(_buildTodayExperienceSummary()) *
            ratio)
        .round();
  }

  int todayAvatarAutoExperienceForSeries(String series) {
    final total = todayAvatarExperienceForSeries(series);
    final score = todayAvatarScoreExperienceForSeries(series);
    final auto = total - score;
    return auto < 0 ? 0 : auto;
  }

  int avatarLevelForSeries(String series) {
    final experience = avatarExperienceForSeries(series);
    var level = 1;
    for (var candidate = 2; candidate <= avatarMaxLevel; candidate++) {
      if (experience < avatarExperienceRequiredForLevel(candidate)) {
        break;
      }
      level = candidate;
    }
    return level;
  }

  int avatarLevelForStage(int index) {
    return avatarLevelForSeries(AvatarCatalog.stageForIndex(index).series);
  }

  static int avatarExperienceRequiredForLevel(int level) {
    final normalizedLevel = level.clamp(1, avatarMaxLevel).toInt();
    final levelOffset = normalizedLevel - 1;
    final required =
        (_avatarLevelCurveA * levelOffset * levelOffset) +
        (_avatarLevelCurveB * levelOffset);
    return required.round();
  }

  int get currentAvatarStageIndex => _avatarProfile.faceShapeIndex;
  int get currentAvatarIconIndex => _avatarProfile.avatarIconIndex;

  AvatarEvolutionStage _firstAvatarStageForSeries(String series) {
    return AvatarCatalog.evolutionStages.firstWhere(
      (stage) => stage.series == series && stage.stage == 1,
      orElse: () => AvatarCatalog.evolutionStages.first,
    );
  }

  bool _isAvatarSeriesPurchased(String series) {
    final firstStage = _firstAvatarStageForSeries(series);
    if (firstStage.coinPrice <= 0) return true;
    return _unlockedAvatarItemKeys.contains(
      avatarItemKey('faceShape', firstStage.index),
    );
  }

  bool isAvatarEvolutionStageUnlocked(int index) {
    final stage = AvatarCatalog.stageForIndex(index);
    if (!_isAvatarSeriesPurchased(stage.series)) return false;
    if (stage.stage == 1) return true;
    return avatarLevelForSeries(stage.series) >= stage.requiredLevel &&
        avatarExperienceForSeries(stage.series) >= stage.requiredExperience;
  }

  bool isAvatarIconUnlocked(int index) {
    return isAvatarEvolutionStageUnlocked(index);
  }

  String avatarEvolutionRequirementText(int index) {
    final stage = AvatarCatalog.stageForIndex(index);
    if (isAvatarEvolutionStageUnlocked(index)) return '已解鎖';
    final firstStage = _firstAvatarStageForSeries(stage.series);
    if (!_isAvatarSeriesPurchased(stage.series)) {
      if (stage.index == firstStage.index && firstStage.coinPrice > 0) {
        return '${firstStage.coinPrice} 自律幣購買';
      }
      return '先購買${firstStage.name}';
    }
    return 'Lv.${stage.requiredLevel} / ${stage.requiredExperience} EXP 解鎖';
  }

  int avatarExperienceForSummary(DailySummary summary) {
    return avatarScoreExperienceForSummary(summary) +
        avatarAutoExperienceForSummary(summary);
  }

  int avatarScoreExperienceForSummary(DailySummary summary) {
    if (summary.totalTasks <= 0) return 0;
    final raw = (summary.disciplineScore * 4).round();
    final multiplier = _avatarExperienceVolumeMultiplier(summary.totalTasks);
    return (raw * multiplier)
        .round()
        .clamp(0, avatarDailyScoreExperienceCap)
        .toInt();
  }

  int avatarAutoExperienceForSummary(DailySummary summary) {
    final sourceRatios = <double>[
      summary.focusMinutes / avatarAutoFocusFullMinutes,
      summary.sleepHours / avatarAutoSleepFullHours,
      summary.steps / avatarAutoStepsFull,
      summary.exerciseMinutes / avatarAutoExerciseFullMinutes,
      summary.roomCompleted > 0 ? 1 : 0,
    ];

    var bestRatio = 0.0;
    for (final ratio in sourceRatios) {
      if (ratio > bestRatio) bestRatio = ratio;
    }

    return (bestRatio.clamp(0, 1) * avatarDailyAutoExperienceCap).round();
  }

  double _avatarExperienceVolumeMultiplier(int totalTasks) {
    if (totalTasks <= 0) return 0;
    if (totalTasks == 1) return 0.35;
    if (totalTasks == 2) return 0.55;
    if (totalTasks == 3) return 0.75;
    if (totalTasks == 4) return 0.9;
    return 1.0;
  }

  AvatarProfile avatarVariantForSeed(int seed) {
    final normalizedSeed = seed.abs();
    final starterIndexes = AvatarCatalog.evolutionStages
        .where((stage) => stage.stage == 1 && stage.coinPrice <= 0)
        .map((stage) => stage.index)
        .toList(growable: false);
    return AvatarProfile.initial().copyWith(
      faceShapeIndex: starterIndexes.isEmpty
          ? 0
          : starterIndexes[normalizedSeed % starterIndexes.length],
    );
  }

  String avatarItemKey(String category, int index) {
    return '$category:$index';
  }

  bool isAvatarItemUnlocked(String category, int index) {
    if (category == 'faceShape') {
      return isAvatarEvolutionStageUnlocked(index);
    }
    if (category == 'appBackground') {
      if (index == 0) return true;
      return _unlockedAvatarItemKeys.contains(avatarItemKey(category, index));
    }
    if (index == 0) return true;
    return _unlockedAvatarItemKeys.contains(avatarItemKey(category, index));
  }

  int avatarItemPrice(String category, int index) {
    switch (category) {
      case 'faceShape':
        return AvatarCatalog.stageForIndex(index).coinPrice;
      case 'appBackground':
        if (index < 0 || index >= AppUI.backgroundThemeKeys.length) return 0;
        return AppUI.backgroundThemePrice(AppUI.backgroundThemeKeys[index]);
      default:
        return 8 + (index * 3);
    }
  }

  double taskRewardWeightForTask(TaskModel task) {
    if (task.taskType == TaskType.deadline) return 0;

    return _rewardWeightForValues(
      isAutoTracked: task.isAutoTracked,
      isSystemTask: task.isSystemTask,
      taskType: TaskModel.taskTypeToStringValue(task.taskType),
      priority: TaskModel.priorityToChinese(task.priority),
      sourceType: task.sourceType,
    );
  }

  int taskPotentialScoreForTask(TaskModel task) {
    final taskWeight = taskRewardWeightForTask(task);
    if (taskWeight <= 0) return 0;

    final allModels = taskModels;
    final totalWeight = allModels.fold<double>(
      0,
      (acc, item) => acc + taskRewardWeightForTask(item),
    );
    if (totalWeight <= 0) return 0;
    return ((taskWeight / totalWeight) * 100).round().clamp(1, 100);
  }

  String taskRewardReasonForTask(TaskModel task) {
    if (task.taskType == TaskType.deadline) {
      return '截止日驗收，不列入每日分數';
    }
    if (task.sourceType == TaskSourceType.sleepHours ||
        task.sourceType == TaskSourceType.steps ||
        task.sourceType == TaskSourceType.exerciseMinutes) {
      return '健康追蹤高權重';
    }
    if (task.sourceType == TaskSourceType.focusMinutes) {
      return '專注核心功能';
    }
    if (task.sourceType == TaskSourceType.studyRoom || task.isSystemTask) {
      return '自律房核心功能';
    }
    return '一般任務基礎權重';
  }

  bool isDeadlineTaskReady(TaskModel task) {
    if (task.taskType != TaskType.deadline) return true;
    if (task.dueDate == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      task.dueDate!.year,
      task.dueDate!.month,
      task.dueDate!.day,
    );
    return !today.isBefore(due);
  }

  String deadlineTaskStatusForTask(TaskModel task) {
    if (task.taskType != TaskType.deadline) return '';
    if (task.dueDate == null) return '請先設定截止日';
    if (isDeadlineTaskReady(task)) {
      final monthlyRemaining = currentMonthDeadlineCoinRemaining;
      if (monthlyRemaining <= 0) {
        return '已到驗收日；本月截止日任務獎勵已達上限';
      }
      final availableReward = deadlineTaskBonusCoins > monthlyRemaining
          ? monthlyRemaining
          : deadlineTaskBonusCoins;
      return '已到驗收日，完成可獲得 +$availableReward 自律幣（本月剩 $monthlyRemaining）';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      task.dueDate!.year,
      task.dueDate!.month,
      task.dueDate!.day,
    );
    final days = due.difference(today).inDays;
    return '還有 $days 天到驗收日，暫不計入每日分數';
  }

  TaskModel _taskMapToTaskModel(
    Map<String, dynamic> task, {
    required int index,
  }) {
    final title = task['title'] as String? ?? '';
    final category = task['category'] as String? ?? '自定義';
    final taskTypeRaw = task['taskType'] as String? ?? 'fixed';
    final priorityRaw = task['priority'] as String? ?? '中';
    final dueDateRaw = task['dueDate'] as String?;
    final doneValue = task['done'] as bool? ?? false;
    final isSystemTaskValue = task['isSystemTask'] as bool? ?? false;
    final isAutoTrackedValue = task['isAutoTracked'] as bool? ?? false;

    final sourceTypeRaw = task['sourceType'] as String?;
    TaskSourceType? sourceType;
    if (sourceTypeRaw != null && sourceTypeRaw.isNotEmpty) {
      sourceType = TaskSourceType.values.firstWhere(
        (e) => e.name == sourceTypeRaw,
        orElse: () => TaskSourceType.manual,
      );
    }

    final targetValueRaw = task['targetValue'];
    double? targetValue;
    if (targetValueRaw is int) {
      targetValue = targetValueRaw.toDouble();
    } else if (targetValueRaw is double) {
      targetValue = targetValueRaw;
    } else if (targetValueRaw is String) {
      targetValue = double.tryParse(targetValueRaw);
    }

    return TaskModel(
      id: task['id'] as String? ?? 'task_${index}_$title',
      userId: task['userId'] as String? ?? 'local_user',
      title: title,
      category: category,
      taskType: taskTypeRaw == 'deadline' ? TaskType.deadline : TaskType.fixed,
      priority: TaskModel.priorityFromChinese(priorityRaw),
      dueDate: dueDateRaw == null || dueDateRaw.isEmpty
          ? null
          : DateTime.tryParse(dueDateRaw),
      isDone: doneValue,
      isSystemTask: isSystemTaskValue,
      isAutoTracked: isAutoTrackedValue,
      sourceType: sourceType,
      targetValue: targetValue,
      unitLabel: task['unitLabel'] as String?,
      sourceId: task['sourceId'] as String?,
      resetDaily: taskTypeRaw == 'fixed',
      createdAt:
          DateTime.tryParse(task['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(task['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: task['completedAt'] == null
          ? null
          : DateTime.tryParse(task['completedAt'] as String),
    );
  }

  List<TaskModel> get taskModels {
    return _tasks.asMap().entries.map((entry) {
      return _taskMapToTaskModel(entry.value, index: entry.key);
    }).toList();
  }

  bool isTaskActionableToday(TaskModel task) {
    return taskRewardWeightForTask(task) > 0;
  }

  List<TaskModel> get todayActionableTaskModels {
    return taskModels.where(isTaskActionableToday).toList();
  }

  List<ReminderPreview> get upcomingReminders {
    final settingsByKey = {
      for (final setting in _reminderSettings) setting.key: setting,
    };
    final previews = <ReminderPreview>[];

    final taskSetting = settingsByKey['tasks'];
    if (taskSetting != null && taskSetting.enabled) {
      final undoneTasks = todayActionableTaskModels
          .where((task) => !task.isDone)
          .toList();
      if (undoneTasks.isNotEmpty) {
        previews.add(
          ReminderPreview(
            channelKey: 'tasks',
            title: '還有 ${undoneTasks.length} 個今日任務',
            subtitle: '下一個：${undoneTasks.first.title}',
            timeLabel: taskSetting.timeLabel,
          ),
        );
      }
    }

    final sleepSetting = settingsByKey['sleep'];
    if (sleepSetting != null && sleepSetting.enabled) {
      previews.add(
        ReminderPreview(
          channelKey: 'sleep',
          title: '睡前整理提醒',
          subtitle: '目前睡眠 ${sleepHours.toStringAsFixed(1)} 小時，今晚可以提早收尾。',
          timeLabel: sleepSetting.timeLabel,
        ),
      );
    }

    final roomSetting = settingsByKey['rooms'];
    if (roomSetting != null && roomSetting.enabled) {
      final joinedRooms = _studyRooms
          .where(
            (room) =>
                room.members.any((member) => member.name == _profileNickname),
          )
          .toList();
      if (joinedRooms.isNotEmpty) {
        previews.add(
          ReminderPreview(
            channelKey: 'rooms',
            title: '自律房活動提醒',
            subtitle: '${joinedRooms.first.name} 今天可以回房間累積進度。',
            timeLabel: roomSetting.timeLabel,
          ),
        );
      }
    }

    final deadlineSetting = settingsByKey['deadline'];
    if (deadlineSetting != null && deadlineSetting.enabled) {
      final deadlineTasks = taskModels.where((task) {
        if (task.taskType != TaskType.deadline || task.dueDate == null) {
          return false;
        }
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final due = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );
        final days = due.difference(today).inDays;
        return days >= 0 && days <= 3 && !task.isDone;
      }).toList();
      if (deadlineTasks.isNotEmpty) {
        previews.add(
          ReminderPreview(
            channelKey: 'deadline',
            title: '截止日快到了',
            subtitle: '${deadlineTasks.first.title} 已進入 3 天提醒區間。',
            timeLabel: deadlineSetting.timeLabel,
          ),
        );
      }
    }

    previews.sort((a, b) => a.timeLabel.compareTo(b.timeLabel));
    return previews;
  }

  List<LocalReminderRequest> get localReminderRequests {
    return upcomingReminders
        .map(
          (preview) => LocalReminderRequest(
            channelKey: preview.channelKey,
            title: preview.title,
            body: preview.subtitle,
            timeLabel: preview.timeLabel,
          ),
        )
        .toList(growable: false);
  }

  int get todayActionableTaskTotal => todayActionableTaskModels.length;

  int get todayActionableTaskCompleted {
    return todayActionableTaskModels.where((task) => task.isDone).length;
  }

  int _consecutiveDaysWithFocus(List<DailySummary> summaries) {
    final sorted = List<DailySummary>.from(summaries)
      ..sort((a, b) => b.date.compareTo(a.date));

    int count = 0;
    for (final day in sorted) {
      if (day.focusMinutes > 0) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  int _consecutiveDaysWithCompletedTasks(List<DailySummary> summaries) {
    final sorted = List<DailySummary>.from(summaries)
      ..sort((a, b) => b.date.compareTo(a.date));

    int count = 0;
    for (final day in sorted) {
      if (day.completedTasks > 0) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  int _daysWithHighSteps(List<DailySummary> summaries, int targetSteps) {
    return summaries.where((day) => day.steps >= targetSteps).length;
  }

  int _daysWithGoodSleep(List<DailySummary> summaries, double targetSleep) {
    return summaries.where((day) => day.sleepHours >= targetSleep).length;
  }

  int _daysWithGoodScore(List<DailySummary> summaries, int targetScore) {
    return summaries.where((day) => day.disciplineScore >= targetScore).length;
  }

  double _averageScore(List<DailySummary> summaries) {
    if (summaries.isEmpty) return 0;
    final total = summaries.fold<int>(
      0,
      (acc, day) => acc + day.disciplineScore,
    );
    return total / summaries.length;
  }

  int _totalStudyRoomFocusMinutes() {
    final totalSeconds = _studyRooms.fold<int>(
      0,
      (acc, room) =>
          acc +
          room.members.fold<int>(
            0,
            (memberSum, member) =>
                memberSum + (member.isApproved ? member.todayFocusSeconds : 0),
          ),
    );
    return totalSeconds ~/ 60;
  }

  bool _isTopMemberInAnyRoom() {
    for (final room in _studyRooms) {
      final approvedMembers = room.members
          .where((member) => member.isApproved)
          .toList();
      if (approvedMembers.isEmpty) continue;
      final sorted = [...approvedMembers]
        ..sort((a, b) => b.todayFocusSeconds.compareTo(a.todayFocusSeconds));
      final top = sorted.first;
      if (top.name == _profileNickname && top.todayFocusSeconds > 0) {
        return true;
      }
    }
    return false;
  }

  int _roomsWithAtLeastMembers(int targetMembers) {
    return _studyRooms
        .where(
          (room) =>
              room.members.where((member) => member.isApproved).length >=
              targetMembers,
        )
        .length;
  }

  BadgeRecord _buildBadge({
    required String key,
    required String name,
    required int progress,
    required int target,
  }) {
    final safeProgress = progress < 0 ? 0 : progress;
    final currentlyUnlocked = safeProgress >= target;
    if (currentlyUnlocked && !_unlockedBadgeDates.containsKey(key)) {
      _unlockedBadgeDates[key] = DateTime.now().toIso8601String();
      _saveUnlockedBadges();
    }

    final unlocked = _unlockedBadgeDates.containsKey(key);
    final unlockedAt = DateTime.tryParse(_unlockedBadgeDates[key] ?? '');
    final displayProgress = unlocked && safeProgress < target
        ? target
        : safeProgress;

    return BadgeRecord(
      id: 'badge_$key',
      userId: 'local_user',
      badgeKey: key,
      badgeName: name,
      isUnlocked: unlocked,
      unlockedAt: unlockedAt ?? (unlocked ? DateTime.now() : null),
      progress: displayProgress > target ? target : displayProgress,
      target: target,
      updatedAt: DateTime.now(),
    );
  }

  List<BadgeRecord> get badgeRecords {
    final summaries = List<DailySummary>.from(_dailySummaries)
      ..sort((a, b) => a.date.compareTo(b.date));

    final recent7Days = summaries.length > 7
        ? summaries.sublist(summaries.length - 7)
        : summaries;

    final completedTasks = _tasks.where((task) => task['done'] == true).length;
    final focusStreak = _consecutiveDaysWithFocus(summaries);
    final taskStreak = _consecutiveDaysWithCompletedTasks(summaries);
    final highStepDays = _daysWithHighSteps(recent7Days, 8000);
    final goodSleepDays = _daysWithGoodSleep(recent7Days, 7);
    final goodScoreDays = _daysWithGoodScore(recent7Days, 70);
    final avgScore = _averageScore(recent7Days).round();
    final totalCoins = recent7Days.fold<int>(
      0,
      (acc, item) => acc + item.coinsEarned,
    );
    final autoTrackedCompleted = recent7Days.fold<int>(
      0,
      (acc, item) => acc + item.autoTrackedCompleted,
    );
    final healthTaskCompleted = recent7Days.fold<int>(
      0,
      (acc, item) => acc + item.healthCompleted,
    );

    final roomFocusMinutes = _totalStudyRoomFocusMinutes();
    final isTopInRoom = _isTopMemberInAnyRoom();
    final activeRoomCount = _roomsWithAtLeastMembers(3);
    final joinedRoomCount = _studyRooms.isEmpty ? 0 : 1;

    return [
      _buildBadge(
        key: 'task_starter',
        name: '任務起步者',
        progress: completedTasks > 0 ? 1 : 0,
        target: 1,
      ),
      _buildBadge(
        key: 'focus_beginner',
        name: '專注新手',
        progress: focusMinutes,
        target: 25,
      ),
      _buildBadge(
        key: 'focus_streak',
        name: '專注連續者',
        progress: focusStreak,
        target: 3,
      ),
      _buildBadge(
        key: 'task_streak',
        name: '任務連續者',
        progress: taskStreak,
        target: 3,
      ),
      _buildBadge(
        key: 'sleep_guard',
        name: '睡眠守護者',
        progress: goodSleepDays,
        target: 3,
      ),
      _buildBadge(
        key: 'step_master',
        name: '步數達人',
        progress: highStepDays,
        target: 3,
      ),
      _buildBadge(
        key: 'steady_progress',
        name: '穩定前進',
        progress: goodScoreDays,
        target: 3,
      ),
      _buildBadge(
        key: 'score_keeper',
        name: '高分維持',
        progress: avgScore,
        target: 70,
      ),
      _buildBadge(
        key: 'coin_earner',
        name: '門檻達人',
        progress: totalCoins,
        target: 80,
      ),
      _buildBadge(
        key: 'auto_tracker',
        name: '自動追蹤者',
        progress: autoTrackedCompleted,
        target: 5,
      ),
      _buildBadge(
        key: 'health_sync',
        name: '健康同步者',
        progress: _isHealthConnected ? 1 : 0,
        target: 1,
      ),
      _buildBadge(
        key: 'health_task',
        name: '健康任務實踐者',
        progress: healthTaskCompleted,
        target: 5,
      ),
      _buildBadge(
        key: 'room_joiner',
        name: '自律房參與者',
        progress: joinedRoomCount,
        target: 1,
      ),
      _buildBadge(
        key: 'room_focus',
        name: '自律房推進者',
        progress: roomFocusMinutes,
        target: 120,
      ),
      _buildBadge(
        key: 'room_leader',
        name: '房內領先者',
        progress: isTopInRoom ? 1 : 0,
        target: 1,
      ),
      _buildBadge(
        key: 'room_social',
        name: '活躍自律房',
        progress: activeRoomCount,
        target: 1,
      ),
    ];
  }

  List<BadgeRecord> get newlyUnlockedBadges {
    return badgeRecords
        .where(
          (badge) =>
              badge.isUnlocked &&
              !_seenUnlockedBadgeKeys.contains(badge.badgeKey),
        )
        .toList();
  }

  Future<void> _loadSeenUnlockedBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_seenUnlockedBadgesKey) ?? const <String>[];
    _seenUnlockedBadgeKeys = raw.toSet();
  }

  Future<void> _loadUnlockedBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_unlockedBadgesKey);
    if (raw == null || raw.isEmpty) {
      _unlockedBadgeDates = <String, String>{};
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map;
      _unlockedBadgeDates = decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      _unlockedBadgeDates = <String, String>{};
    }
  }

  Future<void> _saveSeenUnlockedBadges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _seenUnlockedBadgesKey,
      _seenUnlockedBadgeKeys.toList()..sort(),
    );
  }

  Future<void> _saveUnlockedBadges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_unlockedBadgesKey, jsonEncode(_unlockedBadgeDates));
  }

  Future<void> markBadgeAsSeen(String badgeKey) async {
    if (_seenUnlockedBadgeKeys.contains(badgeKey)) return;
    _seenUnlockedBadgeKeys.add(badgeKey);
    notifyListeners();
    await _saveSeenUnlockedBadges();
  }

  Future<void> markAllCurrentUnlockedBadgesAsSeen() async {
    final unlocked = badgeRecords
        .where((badge) => badge.isUnlocked)
        .map((badge) => badge.badgeKey);
    _seenUnlockedBadgeKeys = unlocked.toSet();
    notifyListeners();
    await _saveSeenUnlockedBadges();
  }

  bool isCurrentUserOwner(String roomId) {
    final room = getStudyRoomById(roomId);
    if (room == null) return false;
    return room.ownerId == _myId || room.ownerName == _profileNickname;
  }

  ThemeMode get currentThemeMode {
    switch (_themeModeSetting) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Color get currentIconColor {
    if (_userRole == 'guardian') {
      return const Color(0xFFF59E0B); // 家長模式：暖橘色
    } else if (_userRole == 'group' ||
        _userRole == 'enterprise' ||
        _userRole == 'tutor' ||
        _userRole == 'school') {
      return const Color(0xFF10B981); // 團體班級模式：活力綠色
    }

    switch (_iconColorSetting) {
      case 'blue':
        return const Color(0xFF4F8CFF);
      case 'teal':
        return const Color(0xFF14B8A6);
      case 'green':
        return const Color(0xFF10B981);
      case 'orange':
        return const Color(0xFFF59E0B);
      case 'pink':
        return const Color(0xFFEC4899);
      case 'red':
        return const Color(0xFFEF4444);
      case 'indigo':
        return const Color(0xFF6366F1);
      case 'purple':
      default:
        return const Color(0xFF7C6AE6);
    }
  }

  void _ensureStudyGoalTaskExists() {
    final existingIndex = _tasks.indexWhere(
      (task) =>
          task['title'] == _studyGoalTaskTitle ||
          task['title'] == _legacyStudyGoalTaskTitle,
    );

    if (existingIndex < 0) return;

    _tasks[existingIndex] = {
      ..._tasks[existingIndex],
      'title': _studyGoalTaskTitle,
      'category': '自律房',
      'sourceType': TaskSourceType.studyRoom.name,
      'isSystemTask': true,
      'isAutoTracked': true,
    };
  }

  void _syncStudyGoalTaskCompletion() {
    _ensureStudyGoalTaskExists();

    bool reached = false;

    for (final room in _studyRooms) {
      if (room.goalSourceType != TaskSourceType.studyRoom &&
          room.goalSourceType != TaskSourceType.focusMinutes) {
        continue;
      }

      final meIndex = room.members.indexWhere(
        (m) => m.memberId == _myId || m.memberId == 'local_user',
      );
      if (meIndex == -1) continue;

      final me = room.members[meIndex];
      if (me.hasReachedPersonalGoal) {
        reached = true;
        break;
      }
    }

    final taskIndex = _tasks.indexWhere(
      (task) => task['title'] == _studyGoalTaskTitle,
    );

    if (taskIndex != -1) {
      _tasks[taskIndex]['done'] = reached;
      _tasks[taskIndex]['isDone'] = reached;
      _tasks[taskIndex]['updatedAt'] = DateTime.now().toIso8601String();
      _tasks[taskIndex]['completedAt'] = reached
          ? DateTime.now().toIso8601String()
          : null;
    }
  }

  double _autoTrackedValueForSource(TaskSourceType? sourceType) {
    switch (sourceType) {
      case TaskSourceType.focusMinutes:
        return focusMinutes.toDouble();
      case TaskSourceType.sleepHours:
        return _isHealthConnected ? _sleepHours : 0;
      case TaskSourceType.steps:
        return _isHealthConnected ? _steps.toDouble() : 0;
      case TaskSourceType.exerciseMinutes:
        return _isHealthConnected ? _exerciseMinutes.toDouble() : 0;
      case TaskSourceType.studyRoom:
        return _studyRoomPersonalFocusMinutes().toDouble();
      case TaskSourceType.manual:
      case TaskSourceType.system:
      case null:
        return 0;
    }
  }

  int _readTaskFocusStartSeconds(Map<String, dynamic> task) {
    final rawValue = task['trackingStartFocusSeconds'];
    if (rawValue is int) return rawValue;
    if (rawValue is double) return rawValue.round();
    if (rawValue is String) return int.tryParse(rawValue) ?? 0;
    return 0;
  }

  double _autoTrackedValueForTask(Map<String, dynamic> task) {
    final sourceType = _readTaskSourceType(task);
    final sourceId = task['sourceId'] as String?;

    if (sourceId != null && sourceId.isNotEmpty) {
      final room = getStudyRoomById(sourceId);
      if (room != null) {
        final me = room.members.where(
          (m) => m.memberId == _myId || m.memberId == 'local_user',
        );
        if (me.isNotEmpty) {
          final member = me.first;
          if (!member.isApproved) return 0;
          return switch (sourceType) {
            TaskSourceType.studyRoom ||
            TaskSourceType.focusMinutes => member.todayFocusSeconds / 60,
            TaskSourceType.sleepHours ||
            TaskSourceType.steps ||
            TaskSourceType.exerciseMinutes => member.todayMetricValue,
            TaskSourceType.manual || TaskSourceType.system || null => 0,
          };
        }
      }
    }

    if (sourceType == TaskSourceType.focusMinutes) {
      final trackedSeconds = _focusSeconds - _readTaskFocusStartSeconds(task);
      if (trackedSeconds <= 0) return 0;
      return trackedSeconds / 60;
    }

    return _autoTrackedValueForSource(sourceType);
  }

  String _studyRoomGoalTaskTitle(StudyRoomData room) {
    return '完成「${room.name}」今日目標';
  }

  double _studyRoomGoalTaskTargetValue(StudyRoomData room) {
    if (room.goalSourceType == TaskSourceType.studyRoom ||
        room.goalSourceType == TaskSourceType.focusMinutes) {
      return room.dailyGoalValue * 60;
    }
    return room.dailyGoalValue;
  }

  String _studyRoomGoalTaskUnitLabel(StudyRoomData room) {
    if (room.goalSourceType == TaskSourceType.studyRoom ||
        room.goalSourceType == TaskSourceType.focusMinutes) {
      return '分鐘';
    }
    return room.goalUnitLabel;
  }

  void _upsertStudyRoomGoalTask(StudyRoomData room) {
    if (!room.syncTaskEnabled) return;

    final now = DateTime.now().toIso8601String();
    final existingIndex = _tasks.indexWhere(
      (task) => task['sourceId'] == room.id,
    );
    final sourceType = room.goalSourceType;
    final task = {
      'id': existingIndex >= 0
          ? _tasks[existingIndex]['id']
          : 'task_room_${room.id}',
      'userId': 'local_user',
      'title': _studyRoomGoalTaskTitle(room),
      'done': false,
      'category': '自律房',
      'taskType': 'fixed',
      'dueDate': null,
      'priority': '中',
      'isSystemTask': false,
      'isAutoTracked': true,
      'sourceType': sourceType.name,
      'targetValue': _studyRoomGoalTaskTargetValue(room),
      'unitLabel': _studyRoomGoalTaskUnitLabel(room),
      'sourceId': room.id,
      'createdAt': existingIndex >= 0
          ? _tasks[existingIndex]['createdAt']
          : now,
      'updatedAt': now,
      'completedAt': existingIndex >= 0
          ? _tasks[existingIndex]['completedAt']
          : null,
    };

    if (existingIndex >= 0) {
      _tasks[existingIndex] = {
        ...task,
        'done': _tasks[existingIndex]['done'] ?? false,
      };
    } else {
      _tasks.add(task);
    }
  }

  void _syncStudyRoomGoalTasks() {
    for (final room in _studyRooms) {
      _upsertStudyRoomGoalTask(room);
    }

    final syncedRoomIds = _studyRooms
        .where((room) => room.syncTaskEnabled)
        .map((room) => room.id)
        .toSet();
    _tasks = _tasks.where((task) {
      final sourceId = task['sourceId'] as String?;
      if (sourceId == null || sourceId.isEmpty) return true;
      return syncedRoomIds.contains(sourceId);
    }).toList();
  }

  void _removeStudyRoomGoalTask(String roomId) {
    _tasks = _tasks.where((task) => task['sourceId'] != roomId).toList();
  }

  void _disableStudyRoomGoalTaskLink(String roomId) {
    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      return room.copyWith(syncTaskEnabled: false);
    }).toList();
    _removeStudyRoomGoalTask(roomId);
  }

  void disableStudyRoomGoalTaskSync(String roomId) {
    _disableStudyRoomGoalTaskLink(roomId);
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    _syncTodaySummary();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
  }

  int _studyRoomPersonalFocusMinutes() {
    int maxSeconds = _focusSeconds;

    for (final room in _studyRooms) {
      for (final member in room.members) {
        if ((member.memberId == _myId || member.memberId == 'local_user') &&
            member.todayFocusSeconds > maxSeconds) {
          maxSeconds = member.todayFocusSeconds;
        }
      }
    }

    return maxSeconds ~/ 60;
  }

  double _currentMetricValueForSource(TaskSourceType sourceType) {
    switch (sourceType) {
      case TaskSourceType.sleepHours:
        return _isHealthConnected ? _sleepHours : 0;
      case TaskSourceType.exerciseMinutes:
        return _isHealthConnected ? _exerciseMinutes.toDouble() : 0;
      case TaskSourceType.steps:
        return _isHealthConnected ? _steps.toDouble() : 0;
      case TaskSourceType.focusMinutes:
      case TaskSourceType.studyRoom:
        return _focusSeconds / 3600;
      case TaskSourceType.manual:
      case TaskSourceType.system:
        return 0;
    }
  }

  void _syncMyHealthMetricsAcrossRooms() {
    _studyRooms = _studyRooms.map((room) {
      if (room.goalSourceType != TaskSourceType.sleepHours &&
          room.goalSourceType != TaskSourceType.exerciseMinutes &&
          room.goalSourceType != TaskSourceType.steps) {
        return room;
      }

      final value = _currentMetricValueForSource(room.goalSourceType);
      final members = List<StudyMemberData>.from(room.members);
      final meIndex = members.indexWhere(
        (m) => m.memberId == _myId || m.memberId == 'local_user',
      );
      final reached = value >= room.dailyGoalValue;

      if (meIndex == -1) {
        members.insert(
          0,
          StudyMemberData(
            memberId: _myId,
            name: _profileNickname,
            roomNickname: _profileNickname,
            status: reached
                ? StudyMemberStatus.resting
                : StudyMemberStatus.offline,
            sessionSeconds: 0,
            todayFocusSeconds: _focusSeconds,
            todayMetricValue: value,
            avatarColor: const Color(0xFF7C6AE6),
            avatarProfile: _avatarProfile,
            role: isCurrentUserOwner(room.id) ? 'owner' : 'member',
            personalGoalSeconds: room.dailyGoalHours * 60 * 60,
            hasReachedPersonalGoal: reached,
            isApproved: true,
          ),
        );
      } else {
        final current = members[meIndex];
        members[meIndex] = current.copyWith(
          name: _profileNickname,
          roomNickname: current.roomNickname.isEmpty
              ? _profileNickname
              : current.roomNickname,
          status: reached ? StudyMemberStatus.resting : current.status,
          todayFocusSeconds: _focusSeconds,
          todayMetricValue: value,
          avatarProfile: _avatarProfile,
          hasReachedPersonalGoal: reached,
        );
      }

      return room.copyWith(members: members, challengeCompleted: reached);
    }).toList();
  }

  double? _readTaskTargetValue(Map<String, dynamic> task) {
    final rawValue = task['targetValue'];
    if (rawValue is int) return rawValue.toDouble();
    if (rawValue is double) return rawValue;
    if (rawValue is String) return double.tryParse(rawValue);
    return null;
  }

  TaskSourceType? _readTaskSourceType(Map<String, dynamic> task) {
    final rawValue = task['sourceType'] as String?;
    if (rawValue == null || rawValue.isEmpty) return null;

    return TaskSourceType.values.firstWhere(
      (sourceType) => sourceType.name == rawValue,
      orElse: () => TaskSourceType.manual,
    );
  }

  DateTime? _readTaskDueDate(Map<String, dynamic> task) {
    final raw = task['dueDate'] as String?;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool _isDeadlineTaskReady(Map<String, dynamic> task) {
    final taskType = task['taskType'] as String? ?? 'fixed';
    if (taskType != 'deadline') return true;

    final dueDate = _readTaskDueDate(task);
    if (dueDate == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return !today.isBefore(due);
  }

  String _deadlineTaskRewardKey(Map<String, dynamic> task) {
    final id = task['id'] as String? ?? task['title'] as String? ?? 'unknown';
    return 'deadline:$id';
  }

  int _awardDeadlineTaskBonus(Map<String, dynamic> task) {
    final rewardKey = _deadlineTaskRewardKey(task);
    if (_rewardedTaskKeys.contains(rewardKey)) return 0;

    final monthlyRemaining = currentMonthDeadlineCoinRemaining;
    final rewardAmount = deadlineTaskBonusCoins > monthlyRemaining
        ? monthlyRemaining
        : deadlineTaskBonusCoins;
    _rewardedTaskKeys.add(rewardKey);
    if (rewardAmount <= 0) {
      _saveRewardState();
      return 0;
    }

    final month = _monthKey();
    _disciplineCoins += rewardAmount;
    _monthlyDeadlineCoinEarned[month] =
        (_monthlyDeadlineCoinEarned[month] ?? 0) + rewardAmount;
    _saveRewardState();
    return rewardAmount;
  }

  void _syncAutoTrackedTasks() {
    final now = DateTime.now().toIso8601String();

    _tasks = _tasks.map((task) {
      final isAutoTracked = task['isAutoTracked'] as bool? ?? false;
      final isSystemTask = task['isSystemTask'] as bool? ?? false;
      if (!isAutoTracked || isSystemTask) return task;

      final sourceType = _readTaskSourceType(task);
      final targetValue = _readTaskTargetValue(task);
      if (sourceType == null || targetValue == null || targetValue <= 0) {
        return task;
      }

      final reached = _autoTrackedValueForTask(task) >= targetValue;
      final wasDone = task['done'] as bool? ?? false;
      final wasIsDone = task['isDone'] as bool? ?? wasDone;

      if (wasDone == reached && wasIsDone == reached) return task;

      return {
        ...task,
        'done': reached,
        'isDone': reached,
        'updatedAt': now,
        'completedAt': reached ? now : null,
      };
    }).toList();
  }

  String _scoreMilestoneRewardKey(int threshold) {
    return '${_todayKey()}|score:$threshold';
  }

  double _taskRewardWeight(Map<String, dynamic> task) {
    if (GroupChallengeTaskPlan.isGroupChallengeTask(task)) return 0;
    final isAutoTracked = task['isAutoTracked'] as bool? ?? false;
    final isSystemTask = task['isSystemTask'] as bool? ?? false;
    final taskType = task['taskType'] as String? ?? 'fixed';
    final priority = task['priority'] as String? ?? '中';
    final sourceType = _readTaskSourceType(task);

    return _rewardWeightForValues(
      isAutoTracked: isAutoTracked,
      isSystemTask: isSystemTask,
      taskType: taskType,
      priority: priority,
      sourceType: sourceType,
    );
  }

  bool _isTodayActionableTask(Map<String, dynamic> task) {
    return _taskRewardWeight(task) > 0;
  }

  double _rewardWeightForValues({
    required bool isAutoTracked,
    required bool isSystemTask,
    required String taskType,
    required String priority,
    required TaskSourceType? sourceType,
  }) {
    if (taskType == 'deadline') return 0;

    final baseWeight = switch (sourceType) {
      TaskSourceType.sleepHours ||
      TaskSourceType.steps ||
      TaskSourceType.exerciseMinutes => 4.0,
      TaskSourceType.focusMinutes => 3.5,
      TaskSourceType.studyRoom => 3.5,
      TaskSourceType.system => 3.0,
      TaskSourceType.manual || null => 1.0,
    };

    final systemBoost = isSystemTask ? 0.3 : 0.0;
    final autoBoost =
        isAutoTracked &&
            sourceType != TaskSourceType.sleepHours &&
            sourceType != TaskSourceType.steps &&
            sourceType != TaskSourceType.exerciseMinutes &&
            sourceType != TaskSourceType.focusMinutes &&
            sourceType != TaskSourceType.studyRoom
        ? 0.3
        : 0.0;

    final priorityModifier = switch (priority) {
      '高' => 1.12,
      '低' => 0.88,
      _ => 1.0,
    };

    return (baseWeight + systemBoost + autoBoost) * priorityModifier;
  }

  int _weightedTaskScore() {
    if (_tasks.isEmpty) return 0;

    final scoreTasks = _tasks.where((task) => _taskRewardWeight(task) > 0);
    final totalWeight = scoreTasks.fold<double>(
      0,
      (acc, task) => acc + _taskRewardWeight(task),
    );
    if (totalWeight <= 0) return 0;

    final completedWeight = scoreTasks
        .where((task) => task['done'] == true)
        .fold<double>(0, (acc, task) => acc + _taskRewardWeight(task));

    return ((completedWeight / totalWeight) * 100).round().clamp(0, 100);
  }

  void _markCompletedTasksAsRewardedForToday() {
    final score = _weightedTaskScore();
    for (final threshold in scoreCoinMilestones.keys) {
      if (score >= threshold) {
        _rewardedTaskKeys.add(_scoreMilestoneRewardKey(threshold));
      }
    }
  }

  void _syncTaskRewards() {
    bool changed = false;
    final score = _weightedTaskScore();

    for (final entry in scoreCoinMilestones.entries) {
      final threshold = entry.key;
      final coinAmount = entry.value;
      if (score < threshold) continue;

      final rewardKey = _scoreMilestoneRewardKey(threshold);
      if (_rewardedTaskKeys.contains(rewardKey)) continue;

      final remaining = scoreCoinRemaining;
      final rewardAmount = coinAmount > remaining ? remaining : coinAmount;
      _rewardedTaskKeys.add(rewardKey);
      if (rewardAmount <= 0) {
        changed = true;
        continue;
      }

      final today = _todayKey();
      _disciplineCoins += rewardAmount;
      _dailyCoinEarned[today] = (_dailyCoinEarned[today] ?? 0) + rewardAmount;
      changed = true;
    }

    if (changed) {
      _saveRewardState();
    }
  }

  void _unlockCurrentAvatarProfile() {
    _unlockedAvatarItemKeys.addAll({
      avatarItemKey('faceShape', _avatarProfile.faceShapeIndex),
      avatarItemKey('appBackground', 0),
    });
  }

  void _unlockAllAvatarItemsForPreview() {
    _unlockCurrentAvatarProfile();
  }

  Future<bool> purchaseAvatarItem(String category, int index) async {
    if (isAvatarItemUnlocked(category, index)) return true;
    if (category == 'appBackground' &&
        (index < 0 || index >= AppUI.backgroundThemeKeys.length)) {
      return false;
    }
    if (category == 'faceShape' && !isAvatarEvolutionStageUnlocked(index)) {
      final stage = AvatarCatalog.stageForIndex(index);
      if (stage.stage != 1 || stage.coinPrice <= 0) {
        return false;
      }
    }

    final price = avatarItemPrice(category, index);
    if (_disciplineCoins < price) return false;

    _disciplineCoins -= price;
    _unlockedAvatarItemKeys.add(avatarItemKey(category, index));

    notifyListeners();
    await _saveRewardState();
    await _saveAvatarUnlockState();
    return true;
  }

  Future<void> loadAllLocalData() async {
    try {
      final data = await LocalStorageService.loadAppData(
        defaultTasks: _defaultTasks,
      );

      _tasks = data.tasks
          .map(
            (task) => {
              'title': task['title'],
              'done': task['done'] ?? false,
              'category': task['category'] ?? '自定義',
              'taskType': task['taskType'] ?? 'fixed',
              'dueDate': task['dueDate'],
              'priority': task['priority'] ?? '中',
              'isSystemTask': task['isSystemTask'] ?? false,
              'isAutoTracked': task['isAutoTracked'] ?? false,
              'sourceType': task['sourceType'],
              'targetValue': task['targetValue'],
              'unitLabel': task['unitLabel'],
              'trackingStartFocusSeconds': task['trackingStartFocusSeconds'],
              'id': task['id'],
              'userId': task['userId'],
              'sourceId': task['sourceId'],
              'createdAt': task['createdAt'],
              'updatedAt': task['updatedAt'],
              'completedAt': task['completedAt'],
            },
          )
          .toList();

      _ensureStudyGoalTaskExists();

      _sleepHours = data.sleepHours;
      _steps = data.steps;
      _exerciseMinutes = data.exerciseMinutes;
      _isHealthConnected = data.isHealthConnected;
      _dailySummaries = data.dailySummaries;

      await _loadAppearanceSettings();

      final prefs = await SharedPreferences.getInstance();
      _userRole = prefs.getString('user_role_setting') ?? 'personal';
      _groupId = prefs.getString('group_id_setting');
      _groupName = prefs.getString('group_name_setting');
      if (prefs.containsKey(_focusSecondsKey)) {
        _focusSeconds = prefs.getInt(_focusSecondsKey) ?? 0;
      } else {
        _focusSeconds = data.focusMinutes * 60;
      }

      await _loadStudyRooms();
      await _loadSocialFriends();
      await _loadFriendIdentityAndRequests();
      await _loadCurrentUser();
      await _loadPrivacyConsent();
      await _loadOnboardingState();
      await _loadReminderSettings();
      await _loadSocialEncouragementRecords();
      await _loadUnlockedBadges();
      await _loadSeenUnlockedBadges();
      final hasRewardState = await _loadRewardState();
      await _loadAvatarUnlockState();
      await _loadAvatarExperienceLedger();
      _normalizeBackgroundThemeSettingForUnlocks();
      _normalizeAvatarProfileForCatalog();

      await _checkAndPerformDailyResetIfNeeded();
      _syncMyHealthMetricsAcrossRooms();
      _syncStudyRoomGoalTasks();
      _syncStudyGoalTaskCompletion();
      _syncAutoTrackedTasks();
      if (hasRewardState) {
        _syncTaskRewards();
      } else {
        _markCompletedTasksAsRewardedForToday();
        await _saveRewardState();
      }
      await checkWeeklyPlanetSettlement();
      _unlockCurrentAvatarProfile();
      _unlockAllAvatarItemsForPreview();
      await _saveAvatarUnlockState();
      _syncTodaySummary();
      _isHydrated = true;
      notifyListeners();
      await _rescheduleLocalReminders();
      _scheduleNextDailyResetTimer();
    } catch (e) {
      debugPrint('load data error: $e');
      _tasks = List<Map<String, dynamic>>.from(_defaultTasks);
      _ensureStudyGoalTaskExists();
      _focusSeconds = 0;
      await _loadAppearanceSettings();
      await _loadStudyRooms();
      await _loadSocialFriends();
      await _loadFriendIdentityAndRequests();
      await _loadCurrentUser();
      await _loadPrivacyConsent();
      await _loadOnboardingState();
      await _loadReminderSettings();
      await _loadSocialEncouragementRecords();
      await _loadUnlockedBadges();
      await _loadSeenUnlockedBadges();
      final hasRewardState = await _loadRewardState();
      await _loadAvatarUnlockState();
      await _loadAvatarExperienceLedger();
      _normalizeBackgroundThemeSettingForUnlocks();
      _normalizeAvatarProfileForCatalog();
      await _checkAndPerformDailyResetIfNeeded();
      _syncMyHealthMetricsAcrossRooms();
      _syncStudyRoomGoalTasks();
      _syncStudyGoalTaskCompletion();
      _syncAutoTrackedTasks();
      if (hasRewardState) {
        _syncTaskRewards();
      } else {
        _markCompletedTasksAsRewardedForToday();
        await _saveRewardState();
      }
      await checkWeeklyPlanetSettlement();
      _unlockCurrentAvatarProfile();
      _unlockAllAvatarItemsForPreview();
      await _saveAvatarUnlockState();
      _syncTodaySummary();
      _isHydrated = true;
      notifyListeners();
      await _rescheduleLocalReminders();
      _scheduleNextDailyResetTimer();
    }
  }

  Future<void> _loadAppearanceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeModeSetting = prefs.getString(_themeModeKey) ?? 'system';
    _iconColorSetting = prefs.getString(_iconColorKey) ?? 'purple';
    _backgroundThemeSetting =
        prefs.getString(_backgroundThemeKey) ?? 'softGlow';
    _profileNickname = prefs.getString(_profileNicknameKey) ?? '老闆';
    _profileSignature = prefs.getString(_profileSignatureKey) ?? '今天也在穩定前進';
    _profileTitleBadgeKey = prefs.getString(_profileTitleBadgeStorageKey) ?? '';

    final avatarRaw = prefs.getString(_avatarProfileKey);
    if (avatarRaw != null && avatarRaw.isNotEmpty) {
      try {
        _avatarProfile = AvatarProfile.fromJson(
          Map<String, dynamic>.from(jsonDecode(avatarRaw)),
        );
      } catch (_) {
        _avatarProfile = AvatarProfile.initial();
      }
    } else {
      _avatarProfile = AvatarProfile.initial();
    }
    _normalizeAvatarProfileForCatalog(enforceUnlocks: false);
  }

  int _clampAvatarIndex(int value, int length) {
    if (length <= 0) return 0;
    return value.clamp(0, length - 1).toInt();
  }

  void _normalizeBackgroundThemeSettingForUnlocks() {
    final index = AppUI.backgroundThemeKeys.indexOf(_backgroundThemeSetting);
    if (index < 0 || !isAvatarItemUnlocked('appBackground', index)) {
      _backgroundThemeSetting = 'softGlow';
    }
  }

  void _normalizeAvatarProfileForCatalog({bool enforceUnlocks = true}) {
    _avatarProfile = _avatarProfile.copyWith(
      skinToneIndex: _clampAvatarIndex(
        _avatarProfile.skinToneIndex,
        AvatarProfile.skinTones.length,
      ),
      faceShapeIndex: _normalizeAvatarStageIndex(_avatarProfile.faceShapeIndex),
      hairStyleIndex: _clampAvatarIndex(
        _avatarProfile.hairStyleIndex,
        AvatarCatalog.hairStyleLabels.length,
      ),
      hairColorIndex: _clampAvatarIndex(
        _avatarProfile.hairColorIndex,
        AvatarProfile.hairColors.length,
      ),
      eyeStyleIndex: _clampAvatarIndex(
        _avatarProfile.eyeStyleIndex,
        AvatarCatalog.eyeStyleLabels.length,
      ),
      eyebrowStyleIndex: _clampAvatarIndex(
        _avatarProfile.eyebrowStyleIndex,
        AvatarCatalog.eyebrowStyleLabels.length,
      ),
      mouthStyleIndex: _clampAvatarIndex(
        _avatarProfile.mouthStyleIndex,
        AvatarCatalog.mouthStyleLabels.length,
      ),
      outfitStyleIndex: _clampAvatarIndex(
        _avatarProfile.outfitStyleIndex,
        AvatarCatalog.outfitStyleLabels.length,
      ),
      outfitColorIndex: _clampAvatarIndex(
        _avatarProfile.outfitColorIndex,
        AvatarProfile.outfitColors.length,
      ),
      accessoryIndex: _clampAvatarIndex(
        _avatarProfile.accessoryIndex,
        AvatarCatalog.accessoryLabels.length,
      ),
      backgroundColorIndex: _clampAvatarIndex(
        _avatarProfile.backgroundColorIndex,
        AvatarProfile.backgroundColors.length,
      ),
      avatarIconIndex: _normalizeAvatarStageIndex(
        _avatarProfile.avatarIconIndex,
      ),
    );
    if (!enforceUnlocks) return;
    if (!isAvatarEvolutionStageUnlocked(_avatarProfile.faceShapeIndex)) {
      final series = AvatarCatalog.stageForIndex(
        _avatarProfile.faceShapeIndex,
      ).series;
      _avatarProfile = _avatarProfile.copyWith(
        faceShapeIndex: _highestUnlockedAvatarStageIndex(series: series),
      );
    }
    if (!isAvatarIconUnlocked(_avatarProfile.avatarIconIndex)) {
      final series = AvatarCatalog.stageForIndex(
        _avatarProfile.avatarIconIndex,
      ).series;
      _avatarProfile = _avatarProfile.copyWith(
        avatarIconIndex: _highestUnlockedAvatarStageIndex(series: series),
      );
    }
  }

  int _normalizeAvatarStageIndex(int index) {
    final exists = AvatarCatalog.evolutionStages.any(
      (stage) => stage.index == index,
    );
    if (exists) return index;
    return AvatarCatalog.evolutionStages.first.index;
  }

  int _highestUnlockedAvatarStageIndex({String? series}) {
    var highest = 0;
    var hasMatch = false;
    for (final stage in AvatarCatalog.evolutionStages) {
      if (series != null && stage.series != series) continue;
      hasMatch = true;
      if (isAvatarEvolutionStageUnlocked(stage.index)) {
        highest = math.max(highest, stage.index);
      }
    }
    if (hasMatch) return highest;
    return AvatarCatalog.evolutionStages.first.index;
  }

  Future<void> _saveAppearanceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeModeSetting);
    await prefs.setString(_iconColorKey, _iconColorSetting);
    await prefs.setString(_backgroundThemeKey, _backgroundThemeSetting);
    await prefs.setString(_profileNicknameKey, _profileNickname);
    await prefs.setString(_profileSignatureKey, _profileSignature);
    await prefs.setString(_profileTitleBadgeStorageKey, _profileTitleBadgeKey);
    await prefs.setString(
      _avatarProfileKey,
      jsonEncode(_avatarProfile.toJson()),
    );
    await syncDataToFirestore();
  }

  Future<void> _saveTasks() async {
    await LocalStorageService.saveTasks(_tasks);
    await syncDataToFirestore();
  }

  Future<void> _saveFocusTime() async {
    await LocalStorageService.saveFocusMinutes(focusMinutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_focusSecondsKey, _focusSeconds);
    await syncDataToFirestore();
  }

  Future<void> _saveHealthData() async {
    await LocalStorageService.saveHealthData(
      sleepHours: _sleepHours,
      steps: _steps,
      exerciseMinutes: _exerciseMinutes,
      isHealthConnected: _isHealthConnected,
    );
    await syncDataToFirestore();
  }

  Future<void> _saveDailySummaries() async {
    await LocalStorageService.saveDailySummaries(_dailySummaries);
    await syncDataToFirestore();
  }

  Future<bool> _loadRewardState() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRewardState =
        prefs.containsKey(_disciplineCoinsKey) ||
        prefs.containsKey(_rewardedTaskKeysKey) ||
        prefs.containsKey(_dailyCoinEarnedKey) ||
        prefs.containsKey(_monthlyDeadlineCoinEarnedKey);

    _disciplineCoins = prefs.getInt(_disciplineCoinsKey) ?? 0;
    _unlockedPlanets = prefs.getStringList(_unlockedPlanetsKey) ?? ['新手星球'];
    _planetCount = _unlockedPlanets.length - 1;
    _weeklyPlanetEarned = prefs.getBool(_weeklyPlanetEarnedKey) ?? false;
    _lastSettledWeekMonday = prefs.getString(_lastSettledWeekMondayKey);
    _rewardedTaskKeys =
        (prefs.getStringList(_rewardedTaskKeysKey) ?? const <String>[]).toSet();
    final dailyEarnedRaw = prefs.getString(_dailyCoinEarnedKey);
    if (dailyEarnedRaw == null || dailyEarnedRaw.isEmpty) {
      _dailyCoinEarned = <String, int>{};
    } else {
      final decoded = jsonDecode(dailyEarnedRaw) as Map;
      _dailyCoinEarned = decoded.map(
        (key, value) => MapEntry(key.toString(), (value as num).round()),
      );
    }

    final monthlyDeadlineRaw = prefs.getString(_monthlyDeadlineCoinEarnedKey);
    if (monthlyDeadlineRaw == null || monthlyDeadlineRaw.isEmpty) {
      _monthlyDeadlineCoinEarned = <String, int>{};
    } else {
      final decoded = jsonDecode(monthlyDeadlineRaw) as Map;
      _monthlyDeadlineCoinEarned = decoded.map(
        (key, value) => MapEntry(key.toString(), (value as num).round()),
      );
    }

    return hasRewardState;
  }

  Future<void> _saveRewardState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_disciplineCoinsKey, _disciplineCoins);
    await prefs.setInt(_planetCountKey, _planetCount);
    await prefs.setStringList(_unlockedPlanetsKey, _unlockedPlanets);
    await prefs.setBool(_weeklyPlanetEarnedKey, _weeklyPlanetEarned);
    await prefs.setString(
      _lastSettledWeekMondayKey,
      _lastSettledWeekMonday ?? '',
    );
    await prefs.setStringList(_rewardedTaskKeysKey, _rewardedTaskKeys.toList());
    await prefs.setString(_dailyCoinEarnedKey, jsonEncode(_dailyCoinEarned));
    await prefs.setString(
      _monthlyDeadlineCoinEarnedKey,
      jsonEncode(_monthlyDeadlineCoinEarned),
    );
    notifyListeners();
    await syncDataToFirestore();
  }

  Future<void> _loadAvatarUnlockState() async {
    final prefs = await SharedPreferences.getInstance();
    _unlockedAvatarItemKeys =
        (prefs.getStringList(_unlockedAvatarItemsKey) ?? const <String>[])
            .toSet();
  }

  Future<void> _loadAvatarExperienceLedger() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_avatarExperienceLedgerKey);
    if (raw == null || raw.isEmpty) {
      _avatarExperienceLedger = <String, Map<String, int>>{};
      _migrateLegacyAvatarExperienceLedger();
      await _saveAvatarExperienceLedger();
      return;
    }

    try {
      _avatarExperienceLedger = _parseAvatarExperienceLedger(raw);
    } catch (_) {
      _avatarExperienceLedger = <String, Map<String, int>>{};
      _migrateLegacyAvatarExperienceLedger();
      await _saveAvatarExperienceLedger();
    }
  }

  Map<String, Map<String, int>> _parseAvatarExperienceLedger(Object raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) {
      throw const FormatException('Invalid avatar experience ledger');
    }
    return decoded.map((date, value) {
      final rawSeries = value is Map ? value : const <String, dynamic>{};
      final seriesMap = rawSeries.map(
        (series, experience) =>
            MapEntry(series.toString(), (experience as num?)?.round() ?? 0),
      )..removeWhere((_, experience) => experience <= 0);
      return MapEntry(date.toString(), seriesMap);
    })..removeWhere((_, seriesMap) => seriesMap.isEmpty);
  }

  void _applyAvatarExperienceData(Map<String, dynamic> data) {
    final profile = data['avatarProfile'];
    if (profile is Map) {
      _avatarProfile = AvatarProfile.fromJson(
        Map<String, dynamic>.from(profile),
      );
    }
    final ledger = data['avatarExperienceLedger'];
    if (ledger != null) {
      _avatarExperienceLedger = _parseAvatarExperienceLedger(ledger);
    }
  }

  void _migrateLegacyAvatarExperienceLedger() {
    if (_dailySummaries.isEmpty) return;
    final series = currentAvatarSeries;
    _avatarExperienceLedger = <String, Map<String, int>>{};
    for (final summary in _dailySummaries) {
      final experience = avatarExperienceForSummary(summary);
      if (experience <= 0) continue;
      _avatarExperienceLedger[summary.date] = {series: experience};
    }
  }

  Future<void> _saveAvatarUnlockState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _unlockedAvatarItemsKey,
      _unlockedAvatarItemKeys.toList(),
    );
    await syncDataToFirestore();
  }

  Future<void> _saveAvatarExperienceLedger() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _avatarExperienceLedgerKey,
      jsonEncode(_avatarExperienceLedger),
    );
    await syncDataToFirestore();
  }

  String _roomMetricUnit(StudyRoomData room) {
    return switch (room.goalSourceType) {
      TaskSourceType.focusMinutes || TaskSourceType.studyRoom => 'minutes',
      TaskSourceType.sleepHours => 'hours',
      TaskSourceType.exerciseMinutes => 'minutes',
      TaskSourceType.steps => 'steps',
      TaskSourceType.manual || TaskSourceType.system => room.goalUnitLabel,
    };
  }

  double _roomMemberMetricValue(StudyRoomData room, StudyMemberData member) {
    return switch (room.goalSourceType) {
      TaskSourceType.focusMinutes ||
      TaskSourceType.studyRoom => member.todayFocusSeconds / 60,
      TaskSourceType.sleepHours ||
      TaskSourceType.exerciseMinutes ||
      TaskSourceType.steps => member.todayMetricValue,
      TaskSourceType.manual || TaskSourceType.system => member.todayMetricValue,
    };
  }

  Map<String, dynamic> _roomMemberProjection(
    StudyRoomData room,
    StudyMemberData member,
    String userId,
  ) {
    final memberId = member.memberId == 'local_user' ? userId : member.memberId;
    return {
      'schemaVersion': 1,
      'roomId': room.id,
      'memberId': memberId,
      'displayName': member.roomNickname.trim().isEmpty
          ? member.name
          : member.roomNickname,
      'role':
          room.ownerId == memberId ||
              (room.ownerId == 'local_user' && memberId == userId)
          ? 'owner'
          : 'member',
      'approvalStatus': member.isApproved ? 'approved' : 'pending',
      'presenceStatus': member.status.name,
      'sessionSeconds': member.sessionSeconds,
      'metricValue': _roomMemberMetricValue(room, member),
      'metricUnit': _roomMetricUnit(room),
      'activeSessionId': activeRoomActivitySession(room.id)?.sessionId,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _roomMetadataPayload(StudyRoomData room, String userId) {
    final ownerId = room.ownerId == 'local_user' ? userId : room.ownerId;
    final memberIds = room.members
        .map((member) {
          return member.memberId == 'local_user' ? userId : member.memberId;
        })
        .where((id) => id.isNotEmpty && id != 'local_user')
        .toSet()
        .toList();
    if (!memberIds.contains(ownerId)) memberIds.add(ownerId);
    final data = room.toJson()
      ..remove('members')
      ..remove('dailyRecords')
      ..remove('messages')
      ..remove('events')
      ..remove('password');
    return {
      ...data,
      'schemaVersion': 2,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'visibility': room.password.isEmpty ? 'public' : 'private',
      'status': 'active',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> _saveStudyRooms() async {
    // Always persist locally for offline access
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _studyRooms.map((room) => room.toJson()).toList(),
    );
    await prefs.setString(_studyRoomsKey, encoded);

    // Also write to Firestore when signed in
    final user = _currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    for (final room in _studyRooms) {
      // Only skip rooms that are purely demo/local placeholders
      if (room.id.startsWith('room_demo_')) continue;

      final roomRef = firestore.collection('rooms').doc(room.id);
      final ownerId = room.ownerId == 'local_user' ? user.id : room.ownerId;
      if (ownerId == user.id) {
        batch.set(
          roomRef,
          _roomMetadataPayload(room, user.id),
          SetOptions(merge: true),
        );
      }

      final me = room.members.where((member) {
        return member.memberId == user.id || member.memberId == 'local_user';
      });
      if (me.isNotEmpty) {
        batch.set(
          roomRef.collection('members').doc(user.id),
          _roomMemberProjection(room, me.first, user.id),
        );
      }
    }
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to sync rooms to Firestore: $e');
    }
  }

  Future<void> _saveSocialFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _socialFriends.map((friend) => friend.toJson()).toList(),
    );
    await prefs.setString(_socialFriendsKey, encoded);
    await syncDataToFirestore();
  }

  Future<void> _saveFriendIdentityAndRequests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_myNudgeIdKey, _myNudgeId);
    await prefs.setString(
      _friendRequestsKey,
      jsonEncode(_friendRequests.map((request) => request.toJson()).toList()),
    );
    await syncDataToFirestore();
  }

  Future<void> _saveCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _currentUser;
    if (user == null) {
      await prefs.remove(_currentUserKey);
      return;
    }
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
  }

  Future<void> _loadPrivacyConsent() async {
    final prefs = await SharedPreferences.getInstance();
    _hasAcceptedPrivacyPolicy = prefs.getBool(_privacyConsentKey) ?? false;
    final acceptedAtRaw = prefs.getString(_privacyConsentAtKey);
    _privacyAcceptedAt = acceptedAtRaw == null
        ? null
        : DateTime.tryParse(acceptedAtRaw);
  }

  Future<void> _savePrivacyConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyConsentKey, _hasAcceptedPrivacyPolicy);
    final acceptedAt = _privacyAcceptedAt;
    if (acceptedAt == null) {
      await prefs.remove(_privacyConsentAtKey);
    } else {
      await prefs.setString(_privacyConsentAtKey, acceptedAt.toIso8601String());
    }
  }

  Future<void> acceptPrivacyPolicy() async {
    _hasAcceptedPrivacyPolicy = true;
    _privacyAcceptedAt = DateTime.now();
    notifyListeners();
    await _savePrivacyConsent();
  }

  Future<void> _loadOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    _hasCompletedOnboarding = prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
  }

  Future<void> resetOnboardingForPreview() async {
    _hasCompletedOnboarding = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, false);
  }

  Future<void> revokePrivacyPolicyConsent() async {
    _hasAcceptedPrivacyPolicy = false;
    _privacyAcceptedAt = null;
    await clearHealthData();
    notifyListeners();
    await _savePrivacyConsent();
  }

  Future<void> _loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reminderSettingsKey);
    if (raw == null || raw.isEmpty) {
      _reminderSettings = List.of(_defaultReminderSettings);
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List;
      final savedByKey = <String, Map<String, dynamic>>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final key = map['key'] as String?;
        if (key == null) continue;
        savedByKey[key] = map;
      }
      _reminderSettings = _defaultReminderSettings.map((fallback) {
        final saved = savedByKey[fallback.key];
        if (saved == null) return fallback;
        return ReminderChannelSetting.fromJson(saved, fallback);
      }).toList();
    } catch (_) {
      _reminderSettings = List.of(_defaultReminderSettings);
    }
  }

  Future<void> _saveReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _reminderSettingsKey,
      jsonEncode(_reminderSettings.map((setting) => setting.toJson()).toList()),
    );
  }

  Future<void> setReminderEnabled(String key, bool enabled) async {
    _reminderSettings = _reminderSettings.map((setting) {
      if (setting.key != key) return setting;
      return setting.copyWith(enabled: enabled);
    }).toList();
    notifyListeners();
    await _saveReminderSettings();
    await _rescheduleLocalReminders();
  }

  Future<void> setReminderTime(String key, String timeLabel) async {
    _reminderSettings = _reminderSettings.map((setting) {
      if (setting.key != key) return setting;
      return setting.copyWith(timeLabel: timeLabel);
    }).toList();
    notifyListeners();
    await _saveReminderSettings();
    await _rescheduleLocalReminders();
  }

  Future<bool> requestNotificationPermissionAndSchedule() async {
    final granted = await NotificationService.requestPermission();
    if (granted) {
      await _rescheduleLocalReminders();
    }
    return granted;
  }

  Future<void> _rescheduleLocalReminders() async {
    await NotificationService.scheduleDailyReminders(localReminderRequests);
  }

  Future<void> _saveSocialEncouragementRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _socialEncouragementRecords.map((record) => record.toJson()).toList(),
    );
    await prefs.setString(_socialEncouragementRecordsKey, encoded);
  }

  Future<void> _loadStudyRooms() async {
    // Try to load from Firestore first (when signed in)
    final user = _currentUser;
    if (user != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('rooms')
            .where('memberIds', arrayContains: user.id)
            .get();
        if (snap.docs.isNotEmpty) {
          _studyRooms = snap.docs
              .map((doc) => StudyRoomData.fromJson(doc.data()))
              .toList();
          _syncMyFocusSecondsAcrossRooms();
          return;
        }
      } catch (e) {
        debugPrint(
          'Failed to load rooms from Firestore, falling back to local: $e',
        );
      }
    }

    // Fallback: load from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_studyRoomsKey);

    if (raw == null || raw.isEmpty) {
      _initDefaultStudyRooms();
      await _saveStudyRooms();
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List;
      _studyRooms = decoded
          .map((e) => StudyRoomData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _syncMyFocusSecondsAcrossRooms();
    } catch (_) {
      _initDefaultStudyRooms();
      await _saveStudyRooms();
    }
  }

  Future<void> _loadSocialFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_socialFriendsKey);

    if (raw == null || raw.isEmpty) {
      _socialFriends = [
        SocialFriendProfile(
          id: 'friend_a',
          nudgeId: 'NDG-YU4832',
          name: '小宇',
          signature: '今天慢慢前進',
          todayFocusSeconds: 48 * 60 + 35,
          isStudying: false,
          avatarColor: const Color(0xFF4F8CFF),
          avatarProfile: avatarVariantForSeed(21),
          isFollowing: true,
          encouragementCount: 2,
        ),
        SocialFriendProfile(
          id: 'friend_b',
          nudgeId: 'NDG-AN6612',
          name: '小安',
          signature: '正在專注中',
          todayFocusSeconds: 66 * 60 + 12,
          isStudying: true,
          avatarColor: const Color(0xFF10B981),
          avatarProfile: avatarVariantForSeed(38),
          isFollowing: false,
          encouragementCount: 1,
        ),
      ];
      await _saveSocialFriends();
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List;
      _socialFriends = decoded
          .map(
            (e) => SocialFriendProfile.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (_) {
      _socialFriends = [];
      await _saveSocialFriends();
    }
  }

  String _generateNudgeId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final seed = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer('NDG-');
    var value = seed;
    for (int i = 0; i < 6; i++) {
      buffer.write(chars[value % chars.length]);
      value = value ~/ chars.length;
    }
    return buffer.toString();
  }

  List<FriendRequest> _defaultIncomingFriendRequests() {
    return [
      FriendRequest(
        id: 'req_in_akari',
        nudgeId: 'NDG-AKARI8',
        name: '小璃',
        signature: '想一起養成早睡習慣',
        direction: FriendRequestDirection.incoming,
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
  }

  Future<void> _loadFriendIdentityAndRequests() async {
    final prefs = await SharedPreferences.getInstance();
    _myNudgeId = prefs.getString(_myNudgeIdKey) ?? '';
    if (_myNudgeId.isEmpty) {
      _myNudgeId = _generateNudgeId();
    }

    final raw = prefs.getString(_friendRequestsKey);
    if (raw == null || raw.isEmpty) {
      _friendRequests = _defaultIncomingFriendRequests();
      await _saveFriendIdentityAndRequests();
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List;
      _friendRequests = decoded
          .map((e) => FriendRequest.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      _friendRequests = _defaultIncomingFriendRequests();
      await _saveFriendIdentityAndRequests();
    }
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentUserKey);
    if (raw == null || raw.isEmpty) {
      _currentUser = null;
      return;
    }

    try {
      final user = UserModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw)),
      );
      _currentUser = user.copyWith(
        id: user.id.isEmpty ? _myNudgeId : user.id,
        username: user.username.isEmpty ? _myNudgeId : user.username,
        nickname: _profileNickname,
        signature: _profileSignature,
        avatarProfileId: 'local_avatar',
        updatedAt: DateTime.now(),
      );
      await _saveCurrentUser();
    } catch (_) {
      _currentUser = null;
      await _saveCurrentUser();
    }
  }

  Future<void> _loadSocialEncouragementRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_socialEncouragementRecordsKey);

    if (raw == null || raw.isEmpty) {
      _socialEncouragementRecords = [];
      await _saveSocialEncouragementRecords();
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List;
      _socialEncouragementRecords = decoded
          .map(
            (e) => SocialEncouragementRecord.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    } catch (_) {
      _socialEncouragementRecords = [];
      await _saveSocialEncouragementRecords();
    }
  }

  void _initDefaultStudyRooms() {
    _studyRooms = [
      StudyRoomData(
        id: 'room_demo_midterm',
        name: '期中衝刺房',
        description: '一起把今天最重要的進度推完',
        accentColor: const Color(0xFF7C6AE6),
        ownerId: _myId,
        ownerName: _profileNickname,
        announcement: '今晚 11 點前一起完成最重要的一項進度。',
        tags: const ['考試衝刺', '高效率'],
        memberLimit: 8,
        category: '研究所',
        dailyGoalHours: 5,
        joinMode: StudyRoomJoinMode.instant,
        joinQuestionsEnabled: false,
        joinQuestions: const [],
        nicknameRuleEnabled: false,
        nicknameRuleText: '',
        roomRules: '專注時盡量保持安靜，進房後直接開始自己的進度。',
        password: '',
        challengeTitle: '今晚衝刺挑戰',
        challengeDescription: '今天一起累積 5 小時專注',
        challengeGoalSeconds: 5 * 60 * 60,
        challengeDeadlineLabel: '今天 23:59',
        challengeCompleted: false,
        members: [
          StudyMemberData(
            memberId: _myId,
            name: _profileNickname,
            roomNickname: _profileNickname,
            status: StudyMemberStatus.offline,
            sessionSeconds: 0,
            todayFocusSeconds: _focusSeconds,
            avatarColor: const Color(0xFF7C6AE6),
            avatarProfile: _avatarProfile,
            role: 'owner',
            personalGoalSeconds: 60 * 60,
            hasReachedPersonalGoal: _focusSeconds >= 60 * 60,
          ),
          const StudyMemberData(
            memberId: 'member_xm',
            name: '小明',
            roomNickname: '小明',
            status: StudyMemberStatus.studying,
            sessionSeconds: 31 * 60 + 12,
            todayFocusSeconds: 102 * 60 + 25,
            avatarColor: Color(0xFF4F8CFF),
            role: 'member',
            personalGoalSeconds: 90 * 60,
            hasReachedPersonalGoal: true,
          ),
          const StudyMemberData(
            memberId: 'member_xh',
            name: '小華',
            roomNickname: '小華',
            status: StudyMemberStatus.resting,
            sessionSeconds: 0,
            todayFocusSeconds: 55 * 60 + 8,
            avatarColor: Color(0xFF10B981),
            role: 'member',
            personalGoalSeconds: 60 * 60,
            hasReachedPersonalGoal: false,
          ),
          const StudyMemberData(
            memberId: 'member_aj',
            name: '阿杰',
            roomNickname: '阿杰',
            status: StudyMemberStatus.offline,
            sessionSeconds: 0,
            todayFocusSeconds: 53 * 60 + 10,
            avatarColor: Color(0xFFF59E0B),
            role: 'member',
            personalGoalSeconds: 45 * 60,
            hasReachedPersonalGoal: true,
          ),
        ],
      ),
      StudyRoomData(
        id: 'room_demo_morning',
        name: '早八自律房',
        description: '早上先進入專注狀態的人都在這',
        accentColor: const Color(0xFF4F8CFF),
        ownerId: _myId,
        ownerName: _profileNickname,
        announcement: '今天早上先完成一輪 50 分鐘專注。',
        tags: const ['早起房', '晨讀'],
        memberLimit: 6,
        category: '大學生',
        dailyGoalHours: 3,
        joinMode: StudyRoomJoinMode.instant,
        joinQuestionsEnabled: false,
        joinQuestions: const [],
        nicknameRuleEnabled: false,
        nicknameRuleText: '',
        roomRules: '早晨自律房，進房後先設定今天的第一輪目標。',
        password: '',
        challengeTitle: '晨讀目標',
        challengeDescription: '今天早上一起累積 3 小時',
        challengeGoalSeconds: 3 * 60 * 60,
        challengeDeadlineLabel: '今天 12:00',
        challengeCompleted: false,
        members: [
          StudyMemberData(
            memberId: _myId,
            name: _profileNickname,
            roomNickname: _profileNickname,
            status: StudyMemberStatus.offline,
            sessionSeconds: 0,
            todayFocusSeconds: _focusSeconds,
            avatarColor: const Color(0xFF7C6AE6),
            avatarProfile: _avatarProfile,
            role: 'owner',
            personalGoalSeconds: 45 * 60,
            hasReachedPersonalGoal: _focusSeconds >= 45 * 60,
          ),
          const StudyMemberData(
            memberId: 'member_xa',
            name: '小安',
            roomNickname: '小安',
            status: StudyMemberStatus.studying,
            sessionSeconds: 42 * 60 + 8,
            todayFocusSeconds: 88 * 60 + 41,
            avatarColor: Color(0xFFEC4899),
            role: 'member',
            personalGoalSeconds: 60 * 60,
            hasReachedPersonalGoal: true,
          ),
          const StudyMemberData(
            memberId: 'member_az',
            name: '阿哲',
            roomNickname: '阿哲',
            status: StudyMemberStatus.resting,
            sessionSeconds: 0,
            todayFocusSeconds: 61 * 60 + 12,
            avatarColor: Color(0xFF14B8A6),
            role: 'member',
            personalGoalSeconds: 90 * 60,
            hasReachedPersonalGoal: false,
          ),
        ],
      ),
      StudyRoomData(
        id: 'room_demo_night',
        name: '夜讀靜音房',
        description: '晚上安靜讀書，互相盯進度',
        accentColor: const Color(0xFF10B981),
        ownerId: _myId,
        ownerName: _profileNickname,
        announcement: '靜音自習，不聊天，專心把今天收尾。',
        tags: const ['夜讀', '靜音房'],
        memberLimit: 10,
        category: '自訂',
        dailyGoalHours: 6,
        joinMode: StudyRoomJoinMode.approval,
        joinQuestionsEnabled: true,
        joinQuestions: const ['你今天想完成什麼？', '是否能遵守靜音規則？'],
        nicknameRuleEnabled: true,
        nicknameRuleText: '請使用固定暱稱，方便房內辨識。',
        roomRules: '禁止閒聊，僅以專注與進度回報為主。',
        password: '',
        challengeTitle: '夜讀累積挑戰',
        challengeDescription: '今晚一起累積 6 小時',
        challengeGoalSeconds: 6 * 60 * 60,
        challengeDeadlineLabel: '今天 23:59',
        challengeCompleted: false,
        members: [
          StudyMemberData(
            memberId: _myId,
            name: _profileNickname,
            roomNickname: _profileNickname,
            status: StudyMemberStatus.offline,
            sessionSeconds: 0,
            todayFocusSeconds: _focusSeconds,
            avatarColor: const Color(0xFF7C6AE6),
            avatarProfile: _avatarProfile,
            role: 'owner',
            personalGoalSeconds: 90 * 60,
            hasReachedPersonalGoal: _focusSeconds >= 90 * 60,
          ),
          const StudyMemberData(
            memberId: 'member_xy',
            name: '小宇',
            roomNickname: '小宇',
            status: StudyMemberStatus.studying,
            sessionSeconds: 27 * 60 + 33,
            todayFocusSeconds: 91 * 60 + 9,
            avatarColor: Color(0xFF10B981),
            role: 'member',
            personalGoalSeconds: 60 * 60,
            hasReachedPersonalGoal: true,
          ),
          const StudyMemberData(
            memberId: 'member_xk',
            name: '小可',
            roomNickname: '小可',
            status: StudyMemberStatus.studying,
            sessionSeconds: 13 * 60 + 17,
            todayFocusSeconds: 74 * 60 + 37,
            avatarColor: Color(0xFF8B5CF6),
            role: 'member',
            personalGoalSeconds: 90 * 60,
            hasReachedPersonalGoal: false,
          ),
          const StudyMemberData(
            memberId: 'member_xj',
            name: '小傑',
            roomNickname: '小傑',
            status: StudyMemberStatus.resting,
            sessionSeconds: 0,
            todayFocusSeconds: 108 * 60 + 2,
            avatarColor: Color(0xFFF97316),
            role: 'member',
            personalGoalSeconds: 120 * 60,
            hasReachedPersonalGoal: false,
          ),
        ],
      ),
    ];
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _todayKey() {
    return _formatDate(DateTime.now().subtract(const Duration(hours: 5)));
  }

  DateTime getMonday5AMOfThisWeek(DateTime time) {
    final daysToSubtract = time.weekday - 1;
    final monday = DateTime(
      time.year,
      time.month,
      time.day,
    ).subtract(Duration(days: daysToSubtract));
    return DateTime(monday.year, monday.month, monday.day, 5, 0, 0);
  }

  double calculateWeeklyAverageScore(DateTime weekStartMonday) {
    int totalScore = 0;
    for (int i = 0; i < 7; i++) {
      final date = weekStartMonday.add(Duration(days: i));
      final dateStr = _formatDate(date);
      final summary = _dailySummaries.firstWhere(
        (s) => s.date == dateStr,
        orElse: () => DailySummary(
          date: dateStr,
          completedTasks: 0,
          totalTasks: 0,
          focusMinutes: 0,
          sleepHours: 0.0,
          steps: 0,
          exerciseMinutes: 0,
          disciplineScore: 0,
        ),
      );
      totalScore += summary.disciplineScore;
    }
    return totalScore / 7.0;
  }

  double calculateWeeklyTaskCompletionRate(DateTime weekStartMonday) {
    int completed = 0;
    int total = 0;
    for (int i = 0; i < 7; i++) {
      final date = weekStartMonday.add(Duration(days: i));
      final dateStr = _formatDate(date);
      final summary = _dailySummaries.firstWhere(
        (s) => s.date == dateStr,
        orElse: () => DailySummary(
          date: dateStr,
          completedTasks: 0,
          totalTasks: 0,
          focusMinutes: 0,
          sleepHours: 0.0,
          steps: 0,
          exerciseMinutes: 0,
          disciplineScore: 0,
        ),
      );
      completed += summary.completedTasks;
      total += summary.totalTasks;
    }
    if (total == 0) return 0.0;
    return (completed / total) * 100.0;
  }

  List<String> _parseUnlockedPlanets(Map<String, dynamic> data) {
    if (data['unlockedPlanets'] != null) {
      return List<String>.from(data['unlockedPlanets']);
    }
    final count = (data['planetCount'] as num?)?.toInt() ?? 0;
    final list = <String>['新手星球'];
    final planetsPool = ["綠洲星球", "熔岩星球", "冰雪星球", "沙漠星球", "水晶星球", "暗物質星球"];
    for (int i = 0; i < count; i++) {
      final available = planetsPool.where((p) => !list.contains(p)).toList();
      if (available.isNotEmpty) {
        list.add(available[i % available.length]);
      }
    }
    return list;
  }

  Future<void> checkWeeklyPlanetSettlement() async {
    final now = DateTime.now();
    final currentMonday5AM = getMonday5AMOfThisWeek(now);

    // The target completed settlement Monday is the last Monday 5:00 AM before now
    final targetSettlementMonday = now.isBefore(currentMonday5AM)
        ? currentMonday5AM.subtract(const Duration(days: 7))
        : currentMonday5AM;

    DateTime nextWeekStartMonday;
    if (_lastSettledWeekMonday == null || _lastSettledWeekMonday!.isEmpty) {
      if (_dailySummaries.isNotEmpty) {
        final sortedSummaries = List<DailySummary>.from(_dailySummaries)
          ..sort((a, b) => a.date.compareTo(b.date));
        final firstDate = DateTime.tryParse(sortedSummaries.first.date) ?? now;
        nextWeekStartMonday = getMonday5AMOfThisWeek(firstDate);
      } else {
        nextWeekStartMonday = getMonday5AMOfThisWeek(
          now,
        ).subtract(const Duration(days: 7));
      }
    } else {
      final lastSettled = DateTime.tryParse(_lastSettledWeekMonday!);
      if (lastSettled == null) {
        nextWeekStartMonday = getMonday5AMOfThisWeek(
          now,
        ).subtract(const Duration(days: 7));
      } else {
        nextWeekStartMonday = lastSettled.add(const Duration(days: 7));
      }
    }

    bool changed = false;
    while (nextWeekStartMonday.isBefore(targetSettlementMonday) ||
        nextWeekStartMonday.isAtSameMomentAs(targetSettlementMonday)) {
      final rate = calculateWeeklyTaskCompletionRate(nextWeekStartMonday);
      if (rate >= 70.0) {
        final planetsPool = ["綠洲星球", "熔岩星球", "冰雪星球", "沙漠星球", "水晶星球", "暗物質星球"];
        final available = planetsPool
            .where((p) => !_unlockedPlanets.contains(p))
            .toList();
        if (available.isNotEmpty) {
          final randomPlanet = (available..shuffle()).first;
          _unlockedPlanets.add(randomPlanet);
        }
        _planetCount = _unlockedPlanets.length - 1;
        _weeklyPlanetEarned = true;
      } else {
        _weeklyPlanetEarned = false;
      }
      _lastSettledWeekMonday = _formatDate(nextWeekStartMonday);
      changed = true;

      nextWeekStartMonday = nextWeekStartMonday.add(const Duration(days: 7));
    }

    if (changed) {
      await _saveRewardState();
    }
  }

  DateTime _currentWeekStart() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - DateTime.monday));
  }

  int _coinEarnedBetween(DateTime start, DateTime end) {
    return _dailyCoinEarned.entries.fold<int>(0, (acc, entry) {
      final date = DateTime.tryParse(entry.key);
      if (date == null) return acc;
      final day = DateTime(date.year, date.month, date.day);
      if (day.isBefore(start) || !day.isBefore(end)) return acc;
      return acc + entry.value;
    });
  }

  String _monthKey() {
    final now = DateTime.now();
    return _monthKeyForDate(now);
  }

  String _monthKeyForDate(DateTime date) {
    final now = date;
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  void _syncSummaryForDate(String date) {
    final todayTasks = _tasks.where(_isTodayActionableTask).toList();
    final completedCount = todayTasks
        .where((task) => task['done'] == true)
        .length;
    final autoTrackedTasks = todayTasks.where((task) {
      final isAutoTracked = task['isAutoTracked'] as bool? ?? false;
      final isSystemTask = task['isSystemTask'] as bool? ?? false;
      return isAutoTracked || isSystemTask;
    }).toList();
    final healthSources = {
      TaskSourceType.sleepHours,
      TaskSourceType.steps,
      TaskSourceType.exerciseMinutes,
    };
    final focusSources = {TaskSourceType.focusMinutes};
    final roomSources = {TaskSourceType.studyRoom};

    final summary = DailySummary(
      date: date,
      completedTasks: completedCount,
      totalTasks: todayTasks.length,
      focusMinutes: focusMinutes,
      sleepHours: _sleepHours,
      steps: _steps,
      exerciseMinutes: _exerciseMinutes,
      disciplineScore: _weightedTaskScore(),
      coinsEarned: _dailyCoinEarned[date] ?? 0,
      autoTrackedCompleted: autoTrackedTasks
          .where((task) => task['done'] as bool? ?? false)
          .length,
      autoTrackedTotal: autoTrackedTasks.length,
      healthCompleted: _countTasksBySource(healthSources, completed: true),
      healthTotal: _countTasksBySource(healthSources),
      roomCompleted: _countTasksBySource(roomSources, completed: true),
      roomTotal: _countTasksBySource(roomSources),
      focusCompleted: _countTasksBySource(focusSources, completed: true),
      focusTotal: _countTasksBySource(focusSources),
      autoTrackedSources: _autoTrackedSourceLabels(),
    );

    final index = _dailySummaries.indexWhere((item) => item.date == date);

    if (index >= 0) {
      _dailySummaries[index] = summary;
    } else {
      _dailySummaries.add(summary);
    }

    _saveDailySummaries();
    _syncAvatarExperienceLedgerForSummary(summary);
  }

  void _checkDailyResetSync() {
    final today = _todayKey();
    if (_lastResetDateInMemory != null && _lastResetDateInMemory != today) {
      final lastResetDate = _lastResetDateInMemory!;
      _syncSummaryForDate(lastResetDate);

      _resetDailyTasks();
      _resetDailyFocusAndStudyRooms();
      _syncStudyGoalTaskCompletion();
      _syncAutoTrackedTasks();
      _syncTaskRewards();
      _syncTodaySummary();

      _lastResetDateInMemory = today;
      notifyListeners();

      _saveAfterReset(today);
    }
  }

  DateTime _nextDailyResetBoundary(DateTime now) {
    final todayAtFive = DateTime(now.year, now.month, now.day, 5);
    if (now.isBefore(todayAtFive)) return todayAtFive;
    return todayAtFive.add(const Duration(days: 1));
  }

  void _scheduleNextDailyResetTimer() {
    _dailyResetTimer?.cancel();

    final now = DateTime.now();
    final nextReset = _nextDailyResetBoundary(now);
    final delay = nextReset.difference(now) + const Duration(seconds: 2);

    _dailyResetTimer = Timer(delay, () {
      _checkDailyResetSync();
      _scheduleNextDailyResetTimer();
    });
  }

  Future<void> _saveAfterReset(String today) async {
    await checkWeeklyPlanetSettlement();
    await _saveRewardState();
    await _saveTasks();
    await _saveFocusTime();
    await _saveHealthData();
    await _saveStudyRooms();
    await _saveDailySummaries();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDailyResetDateKey, today);
  }

  Future<void> _checkAndPerformDailyResetIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastResetDate = prefs.getString(_lastDailyResetDateKey);

    _lastResetDateInMemory = lastResetDate ?? today;

    if (lastResetDate == null) {
      await prefs.setString(_lastDailyResetDateKey, today);
      return;
    }

    if (lastResetDate == today) {
      return;
    }

    _syncSummaryForDate(lastResetDate);
    _resetDailyTasks();
    _resetDailyFocusAndStudyRooms();
    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    _syncTodaySummary();

    _lastResetDateInMemory = today;

    await _saveAfterReset(today);
  }

  void _resetDailyTasks() {
    _tasks = _tasks.map((task) {
      final taskType = (task['taskType'] ?? 'fixed') as String;

      if (taskType == 'fixed') {
        final isFocusTask =
            (task['isAutoTracked'] as bool? ?? false) &&
            _readTaskSourceType(task) == TaskSourceType.focusMinutes &&
            (task['sourceId'] as String? ?? '').isEmpty;

        return {
          ...task,
          'done': false,
          'isDone': false,
          if (isFocusTask) 'trackingStartFocusSeconds': 0,
          'updatedAt': DateTime.now().toIso8601String(),
          'completedAt': null,
        };
      }

      return task;
    }).toList();

    _ensureStudyGoalTaskExists();
  }

  void _resetDailyFocusAndStudyRooms() {
    _focusSeconds = 0;
    _sleepHours = 0;
    _steps = 0;
    _exerciseMinutes = 0;

    _studyRooms = _studyRooms.map((room) {
      final updatedMembers = room.members.map((member) {
        return member.copyWith(
          status: StudyMemberStatus.offline,
          sessionSeconds: 0,
          todayFocusSeconds: 0,
          todayMetricValue: 0,
          hasReachedPersonalGoal: false,
        );
      }).toList();

      return room.copyWith(members: updatedMembers, challengeCompleted: false);
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _calculateDisciplineScoreFromValues({
    required int completedTasks,
    required int totalTasks,
    required int focusMinutes,
    required double sleepHours,
    required int steps,
    required int exerciseMinutes,
    required bool isHealthConnected,
  }) {
    int taskScore = 0;
    if (totalTasks > 0) {
      taskScore = ((completedTasks / totalTasks) * 30).round();
    }

    final focusScore = ((focusMinutes / 120).clamp(0, 1) * 30).round();

    int sleepScore = 0;
    int stepScore = 0;
    int exerciseScore = 0;

    if (isHealthConnected) {
      sleepScore = ((sleepHours / 8).clamp(0, 1) * 15).round();
      stepScore = ((steps / 8000).clamp(0, 1) * 15).round();
      exerciseScore = ((exerciseMinutes / 30).clamp(0, 1) * 10).round();
    }

    return taskScore + focusScore + sleepScore + stepScore + exerciseScore;
  }

  bool _isTaskSource(Map<String, dynamic> task, Set<TaskSourceType> sources) {
    final raw = task['sourceType'] as String?;
    final sourceType = raw == null
        ? null
        : TaskSourceType.values.firstWhere(
            (item) => item.name == raw,
            orElse: () => TaskSourceType.manual,
          );
    return sourceType != null && sources.contains(sourceType);
  }

  int _countTasksBySource(Set<TaskSourceType> sources, {bool? completed}) {
    return _tasks.where((task) {
      if (!_isTodayActionableTask(task)) return false;
      if (!_isTaskSource(task, sources)) return false;
      if (completed == null) return true;
      return (task['done'] as bool? ?? false) == completed;
    }).length;
  }

  List<String> _autoTrackedSourceLabels() {
    final labels = <String>{};

    for (final task in _tasks) {
      final isAutoTracked = task['isAutoTracked'] as bool? ?? false;
      final isSystemTask = task['isSystemTask'] as bool? ?? false;
      if (!isAutoTracked && !isSystemTask) continue;

      final raw = task['sourceType'] as String?;
      final sourceType = raw == null
          ? null
          : TaskSourceType.values.firstWhere(
              (item) => item.name == raw,
              orElse: () => TaskSourceType.manual,
            );
      labels.add(TaskModel.sourceTypeToChinese(sourceType));
    }

    return labels.toList()..sort();
  }

  DailySummary _buildTodayExperienceSummary() {
    final todayTasks = _tasks.where(_isTodayActionableTask).toList();
    final completedCount = todayTasks
        .where((task) => task['done'] == true)
        .length;
    final autoTrackedTasks = todayTasks.where((task) {
      final isAutoTracked = task['isAutoTracked'] as bool? ?? false;
      final isSystemTask = task['isSystemTask'] as bool? ?? false;
      return isAutoTracked || isSystemTask;
    }).toList();
    final healthSources = {
      TaskSourceType.sleepHours,
      TaskSourceType.steps,
      TaskSourceType.exerciseMinutes,
    };
    final focusSources = {TaskSourceType.focusMinutes};
    final roomSources = {TaskSourceType.studyRoom};

    return DailySummary(
      date: _todayKey(),
      completedTasks: completedCount,
      totalTasks: todayTasks.length,
      focusMinutes: focusMinutes,
      sleepHours: _sleepHours,
      steps: _steps,
      exerciseMinutes: _exerciseMinutes,
      disciplineScore: _weightedTaskScore(),
      coinsEarned: todayCoinEarned,
      autoTrackedCompleted: autoTrackedTasks
          .where((task) => task['done'] as bool? ?? false)
          .length,
      autoTrackedTotal: autoTrackedTasks.length,
      healthCompleted: _countTasksBySource(healthSources, completed: true),
      healthTotal: _countTasksBySource(healthSources),
      roomCompleted: _countTasksBySource(roomSources, completed: true),
      roomTotal: _countTasksBySource(roomSources),
      focusCompleted: _countTasksBySource(focusSources, completed: true),
      focusTotal: _countTasksBySource(focusSources),
      autoTrackedSources: _autoTrackedSourceLabels(),
    );
  }

  void _syncTodaySummary() {
    final today = _todayKey();
    final summary = _buildTodayExperienceSummary();

    final index = _dailySummaries.indexWhere((item) => item.date == today);

    if (index >= 0) {
      _dailySummaries[index] = summary;
    } else {
      _dailySummaries.add(summary);
    }

    _saveDailySummaries();
    _syncAvatarExperienceLedgerForSummary(summary);
    _scheduleFamilySummaryPublish();
    _scheduleGroupResultSummaryPublish();
  }

  void _scheduleFamilySummaryPublish() {
    _familySummaryPublishTimer?.cancel();
    _familySummaryPublishTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(_publishFamilySummarySnapshot());
    });
  }

  Future<void> _publishFamilySummarySnapshot({
    FamilyConsentScopes? consentOverride,
  }) async {
    final link = _familyLink;
    final user = _currentUser;
    if (link == null || user == null || user.id != link.childId) return;
    final consent = consentOverride ?? link.consent;
    final payload = _buildFamilySummaryPayload(
      childId: user.id,
      consent: consent,
    );

    await FirebaseFirestore.instance
        .collection('family_links')
        .doc(link.id)
        .collection('summaries')
        .doc('current')
        .set(payload);
  }

  void _scheduleGroupResultSummaryPublish() {
    if (!_groupResultSharingEnabled) return;
    _groupResultSummaryPublishTimer?.cancel();
    _groupResultSummaryPublishTimer = Timer(
      const Duration(milliseconds: 800),
      () {
        unawaited(_publishGroupResultSummarySnapshot());
      },
    );
  }

  Future<void> _publishGroupResultSummarySnapshot() async {
    final group = _canonicalGroup;
    final user = _currentUser;
    if (!_groupResultSharingEnabled ||
        group == null ||
        user == null ||
        !group.isMember(user.id)) {
      return;
    }
    final payload = GroupResultSummaryContract.buildPayload(
      group: group,
      memberId: user.id,
      displayName: _profileNickname,
      disciplineScore: todayWeightedDisciplineScore,
      completedTasks: todayActionableTaskCompleted,
      totalTasks: todayActionableTaskTotal,
      focusMinutes: focusMinutes,
      steps: steps,
      sleepHours: sleepHours,
      now: DateTime.now(),
    );
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(group.id)
        .collection('member_summaries')
        .doc(user.id)
        .set(payload);
  }

  Map<String, dynamic> _buildFamilySummaryPayload({
    required String childId,
    required FamilyConsentScopes consent,
  }) {
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'childId': childId,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    if (consent.summary) {
      payload['summary'] = {
        'disciplineScore': todayWeightedDisciplineScore,
        'completedTasks': todayActionableTaskCompleted,
        'totalTasks': todayActionableTaskTotal,
        'focusMinutes': focusMinutes,
      };
    }
    if (consent.weeklyReport) {
      final recent = _dailySummaries.length > 7
          ? _dailySummaries.sublist(_dailySummaries.length - 7)
          : _dailySummaries;
      payload['weeklyReport'] = recent
          .map(
            (summary) => {
              'date': summary.date,
              'disciplineScore': summary.disciplineScore,
              'completedTasks': summary.completedTasks,
              'totalTasks': summary.totalTasks,
              'focusMinutes': summary.focusMinutes,
            },
          )
          .toList(growable: false);
    }
    if (consent.taskCategories) {
      final categories = <String, Map<String, int>>{};
      for (final task in _tasks) {
        final category = task['category']?.toString() ?? '其他';
        final counts = categories.putIfAbsent(
          category,
          () => {'completed': 0, 'total': 0},
        );
        counts['total'] = counts['total']! + 1;
        if (task['done'] == true || task['isDone'] == true) {
          counts['completed'] = counts['completed']! + 1;
        }
      }
      payload['taskCategories'] = categories;
    }
    if (consent.healthTrends) {
      payload['healthTrends'] = {
        'sleepHours': sleepHours,
        'steps': steps,
        'exerciseMinutes': exerciseMinutes,
      };
    }
    return payload;
  }

  void _syncAvatarExperienceLedgerForSummary(DailySummary summary) {
    final expectedExperience = avatarExperienceForSummary(summary);
    final seriesExperience = Map<String, int>.from(
      _avatarExperienceLedger[summary.date] ?? const <String, int>{},
    );
    final recordedExperience = seriesExperience.values.fold<int>(
      0,
      (acc, value) => acc + value,
    );
    final delta = expectedExperience - recordedExperience;
    if (delta == 0) return;

    if (delta > 0) {
      final series = currentAvatarSeries;
      seriesExperience[series] = (seriesExperience[series] ?? 0) + delta;
    } else {
      _removeAvatarExperienceFromLedgerEntry(
        seriesExperience,
        amount: -delta,
        preferredSeries: currentAvatarSeries,
      );
    }

    seriesExperience.removeWhere((_, experience) => experience <= 0);
    if (seriesExperience.isEmpty) {
      _avatarExperienceLedger.remove(summary.date);
    } else {
      _avatarExperienceLedger[summary.date] = seriesExperience;
    }
    _saveAvatarExperienceLedger();
  }

  void _removeAvatarExperienceFromLedgerEntry(
    Map<String, int> seriesExperience, {
    required int amount,
    required String preferredSeries,
  }) {
    var remaining = amount;

    void consume(String series) {
      if (remaining <= 0) return;
      final available = seriesExperience[series] ?? 0;
      if (available <= 0) return;
      final used = math.min(available, remaining);
      seriesExperience[series] = available - used;
      remaining -= used;
    }

    consume(preferredSeries);
    for (final series in seriesExperience.keys.toList()) {
      consume(series);
    }
  }

  Future<void> setThemeModeSetting(String value) async {
    _themeModeSetting = value;
    notifyListeners();
    await _saveAppearanceSettings();
  }

  Future<void> setIconColorSetting(String value) async {
    _iconColorSetting = value;
    notifyListeners();
    await _saveAppearanceSettings();
  }

  Future<void> setBackgroundThemeSetting(String value) async {
    final index = AppUI.backgroundThemeKeys.indexOf(value);
    if (index < 0 || !isAvatarItemUnlocked('appBackground', index)) return;
    _backgroundThemeSetting = value;
    notifyListeners();
    await _saveAppearanceSettings();
  }

  Future<void> updateProfile({
    required String nickname,
    required String signature,
    String? titleBadgeKey,
  }) async {
    _profileNickname = nickname.trim().isEmpty ? '老闆' : nickname.trim();
    _profileSignature = signature.trim().isEmpty
        ? '今天也在穩定前進'
        : signature.trim();
    if (titleBadgeKey != null) {
      final canUseTitle =
          titleBadgeKey.isEmpty ||
          badgeRecords.any(
            (badge) => badge.badgeKey == titleBadgeKey && badge.isUnlocked,
          );
      if (canUseTitle) {
        _profileTitleBadgeKey = titleBadgeKey;
      }
    }

    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        nickname: _profileNickname,
        signature: _profileSignature,
        avatarProfileId: 'local_avatar',
        updatedAt: DateTime.now(),
      );
    }

    notifyListeners();
    await _saveAppearanceSettings();
    await _saveCurrentUser();
    await syncDataToFirestore();
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    final credential = await fb_auth.FirebaseAuth.instance
        .signInWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
    if (credential.user != null) {
      await _syncProfileFromFirebaseUser(credential.user!);
    }
  }

  Future<void> signUpWithEmailAndPassword(
    String email,
    String password,
    String nickname,
  ) async {
    final credential = await fb_auth.FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
    if (credential.user != null) {
      try {
        await credential.user!.sendEmailVerification();
        debugPrint('Verification email sent to ${email.trim()}');
      } catch (e) {
        debugPrint('Could not send email verification: $e');
      }
      _profileNickname = nickname.trim();
      await _syncProfileFromFirebaseUser(credential.user!);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      // google_sign_in v7: singleton instance with initialize() + authenticate()
      await GoogleSignIn.instance.initialize();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;

      final credential = fb_auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        // accessToken is no longer in authentication getter in v7
      );
      final userCredential = await fb_auth.FirebaseAuth.instance
          .signInWithCredential(credential);
      if (userCredential.user != null) {
        await _syncProfileFromFirebaseUser(userCredential.user!);
      }
    } catch (e) {
      debugPrint('Google Sign-in error: $e');
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = fb_auth.OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final userCredential = await fb_auth.FirebaseAuth.instance
          .signInWithCredential(credential);

      // Apple only provides name on first sign-in
      final displayName =
          '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
              .trim();
      if (displayName.isNotEmpty) {
        _profileNickname = displayName;
      }

      if (userCredential.user != null) {
        await _syncProfileFromFirebaseUser(userCredential.user!);
      }
    } catch (e) {
      debugPrint('Apple Sign-in error: $e');
      rethrow;
    }
  }

  Future<void> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      if (result.status != LoginStatus.success) {
        throw Exception('Facebook 登入被取消或失敗：${result.message}');
      }
      final fb_auth.OAuthCredential credential = fb_auth
          .FacebookAuthProvider.credential(result.accessToken!.tokenString);
      final userCredential = await fb_auth.FirebaseAuth.instance
          .signInWithCredential(credential);
      if (userCredential.user != null) {
        await _syncProfileFromFirebaseUser(userCredential.user!);
      }
    } catch (e) {
      debugPrint('Facebook Sign-in error: $e');
      rethrow;
    }
  }

  Future<void> signInWithMicrosoft() async {
    try {
      final provider = fb_auth.OAuthProvider('microsoft.com')
        ..setCustomParameters({'prompt': 'select_account'});
      final userCredential = await fb_auth.FirebaseAuth.instance
          .signInWithProvider(provider);
      if (userCredential.user != null) {
        await _syncProfileFromFirebaseUser(userCredential.user!);
      }
    } catch (e) {
      debugPrint('Microsoft Sign-in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await fb_auth.FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Error signing out of Firebase: $e');
    }
    _currentUser = null;
    _isGuestMode = false;
    notifyListeners();
    await _saveCurrentUser();
  }

  Future<void> updateAvatarProfile(AvatarProfile profile) async {
    _avatarProfile = profile;
    _normalizeAvatarProfileForCatalog();
    _syncMyFocusSecondsAcrossRooms();
    notifyListeners();
    await _saveAppearanceSettings();
    await _saveStudyRooms();
    await syncDataToFirestore();
  }

  Future<void> updateAvatarIconIndex(int index) async {
    if (!isAvatarIconUnlocked(index)) return;
    _avatarProfile = _avatarProfile.copyWith(avatarIconIndex: index);
    _normalizeAvatarProfileForCatalog();
    notifyListeners();
    await _saveAppearanceSettings();
    await syncDataToFirestore();
  }

  SocialFriendProfile? getSocialFriendById(String id) {
    try {
      return _socialFriends.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<SocialFriendProfile?> searchFriendByNudgeId(String rawId) async {
    final queryId = rawId.trim().toUpperCase();
    if (queryId.isEmpty || queryId == _myNudgeId) return null;

    try {
      final querySnap = await FirebaseFirestore.instance
          .collection('public_profiles')
          .where('username', isEqualTo: queryId)
          .limit(1)
          .get();

      if (querySnap.docs.isNotEmpty) {
        final data = querySnap.docs.first.data();

        AvatarProfile? avatarProfile;
        if (data['avatarProfile'] != null) {
          avatarProfile = AvatarProfile.fromJson(
            Map<String, dynamic>.from(data['avatarProfile'] as Map),
          );
        }

        return SocialFriendProfile(
          id: data['userId'] as String? ?? querySnap.docs.first.id,
          nudgeId:
              data['myNudgeId'] as String? ?? data['username'] as String? ?? '',
          name: data['nickname'] as String? ?? '自律使用者',
          signature: data['signature'] as String? ?? '',
          todayFocusSeconds: 0,
          isStudying: false,
          avatarColor: const Color(0xFF7C6AE6),
          avatarProfile: avatarProfile,
          isFollowing: false,
          encouragementCount: 0,
        );
      }
    } catch (e) {
      debugPrint('Failed to query user by Nudge ID: $e');
    }

    return null;
  }

  SocialFriendProfile? findFriendCandidateByNudgeId(String rawId) {
    final nudgeId = rawId.trim().toUpperCase();
    if (nudgeId.isEmpty || nudgeId == _myNudgeId) return null;

    final existing = _socialFriends.where(
      (friend) => friend.nudgeId.toUpperCase() == nudgeId,
    );
    if (existing.isNotEmpty) return existing.first;

    return null;
  }

  Future<SocialFriendProfile?> searchFriendFromInvite(String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty) return null;

    final directCandidate = await searchFriendByNudgeId(value);
    if (directCandidate != null) return directCandidate;

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    final nudgeId = (uri.queryParameters['nudgeId'] ?? '').trim().toUpperCase();
    if (nudgeId.isEmpty || nudgeId == _myNudgeId) return null;

    return searchFriendByNudgeId(nudgeId);
  }

  SocialFriendProfile? findFriendCandidateFromInvite(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return null;

    final directCandidate = findFriendCandidateByNudgeId(value);
    if (directCandidate != null) return directCandidate;

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    final isNudgeInvite =
        uri.scheme == 'nudge' && uri.host == 'friend' && uri.path == '/add';
    final isWebInvite =
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'friend' &&
        uri.pathSegments[1] == 'add';
    if (!isNudgeInvite && !isWebInvite) return null;

    final nudgeId = (uri.queryParameters['nudgeId'] ?? '').trim().toUpperCase();
    if (nudgeId.isEmpty || nudgeId == _myNudgeId) return null;

    final knownCandidate = findFriendCandidateByNudgeId(nudgeId);
    if (knownCandidate != null) return knownCandidate;

    return null;
  }

  Future<void> addSocialFriend({
    String? id,
    String? nudgeId,
    required String name,
    required String signature,
    required Color avatarColor,
    AvatarProfile? avatarProfile,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final trimmedNudgeId = nudgeId?.trim().toUpperCase() ?? '';
    final exists = _socialFriends.any(
      (f) =>
          f.name == trimmedName ||
          (trimmedNudgeId.isNotEmpty &&
              f.nudgeId.toUpperCase() == trimmedNudgeId),
    );
    if (exists) return;

    _socialFriends = [
      ..._socialFriends,
      SocialFriendProfile(
        id: id ?? 'friend_${DateTime.now().millisecondsSinceEpoch}',
        nudgeId: trimmedNudgeId,
        name: trimmedName,
        signature: signature.trim().isEmpty ? '今天慢慢前進' : signature.trim(),
        todayFocusSeconds: 0,
        isStudying: false,
        avatarColor: avatarColor,
        avatarProfile:
            avatarProfile ?? avatarVariantForSeed(trimmedName.hashCode),
        isFollowing: false,
        encouragementCount: 0,
      ),
    ];

    notifyListeners();
    await _saveSocialFriends();
  }

  Future<void> sendFriendRequest(SocialFriendProfile candidate) async {
    final user = _currentUser;
    if (user == null) return;

    final reqId = 'req_${user.id}_${candidate.id}';
    final docRef = FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(reqId);

    await docRef.set({
      'senderId': user.id,
      'senderNudgeId': user.username,
      'senderName': user.nickname,
      'senderSignature': user.signature,
      'receiverId': candidate.id,
      'receiverNudgeId': candidate.nudgeId,
      'receiverName': candidate.name,
      'receiverSignature': candidate.signature,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptFriendRequest(String requestId) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        final senderId = data['senderId'] as String? ?? '';
        final senderNudgeId = data['senderNudgeId'] as String? ?? '';
        final senderName = data['senderName'] as String? ?? '';
        final senderSignature = data['senderSignature'] as String? ?? '';

        final myFriendProfile = SocialFriendProfile(
          id: senderId,
          nudgeId: senderNudgeId,
          name: senderName,
          signature: senderSignature,
          todayFocusSeconds: 0,
          isStudying: false,
          avatarColor: const Color(0xFF7C6AE6),
          isFollowing: true,
          encouragementCount: 0,
        );

        final otherFriendProfile = SocialFriendProfile(
          id: user.id,
          nudgeId: user.username,
          name: user.nickname,
          signature: user.signature,
          todayFocusSeconds: 0,
          isStudying: false,
          avatarColor: const Color(0xFF7C6AE6),
          isFollowing: true,
          encouragementCount: 0,
        );

        final firestore = FirebaseFirestore.instance;
        final myFriendRef = firestore
            .collection('users')
            .doc(user.id)
            .collection('friends')
            .doc(senderId);
        final otherFriendRef = firestore
            .collection('users')
            .doc(senderId)
            .collection('friends')
            .doc(user.id);
        final batch = firestore.batch();
        batch.update(docRef, {'status': 'accepted'});
        batch.set(myFriendRef, myFriendProfile.toJson());
        batch.set(otherFriendRef, otherFriendProfile.toJson());
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Failed to accept friend request: $e');
    }
  }

  Future<void> declineFriendRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId)
          .update({'status': 'declined'});
    } catch (e) {
      debugPrint('Failed to decline friend request: $e');
    }
  }

  Future<void> removeSocialFriend(String id) async {
    final user = _currentUser;
    if (user != null) {
      try {
        final firestore = FirebaseFirestore.instance;
        final forwardRequest = firestore
            .collection('friend_requests')
            .doc('req_${user.id}_$id');
        final reverseRequest = firestore
            .collection('friend_requests')
            .doc('req_${id}_${user.id}');
        final requestSnapshots = await Future.wait([
          forwardRequest.get(),
          reverseRequest.get(),
        ]);
        DocumentReference<Map<String, dynamic>>? acceptedRequest;
        if (requestSnapshots[0].data()?['status'] == 'accepted') {
          acceptedRequest = forwardRequest;
        } else if (requestSnapshots[1].data()?['status'] == 'accepted') {
          acceptedRequest = reverseRequest;
        }
        if (acceptedRequest == null) {
          debugPrint('Failed to delete friend: accepted request not found');
          return;
        }

        final myFriendRef = firestore
            .collection('users')
            .doc(user.id)
            .collection('friends')
            .doc(id);
        final otherFriendRef = firestore
            .collection('users')
            .doc(id)
            .collection('friends')
            .doc(user.id);
        final batch = firestore.batch();
        batch.update(acceptedRequest, {'status': 'removed'});
        batch.delete(myFriendRef);
        batch.delete(otherFriendRef);
        await batch.commit();
      } catch (e) {
        debugPrint('Failed to delete friend from Firestore: $e');
        return;
      }
    }

    _socialFriends = _socialFriends.where((f) => f.id != id).toList();
    _socialEncouragementRecords = _socialEncouragementRecords
        .where((record) => record.toFriendId != id)
        .toList();

    notifyListeners();
    await _saveSocialFriends();
    await _saveSocialEncouragementRecords();
  }

  Future<void> toggleFollowFriend(String id) async {
    _socialFriends = _socialFriends.map((friend) {
      if (friend.id != id) return friend;
      return friend.copyWith(isFollowing: !friend.isFollowing);
    }).toList();

    notifyListeners();
    await _saveSocialFriends();
  }

  Future<void> setPublicProfileFollowing({
    required String id,
    required String name,
    required String signature,
    required int todayFocusSeconds,
    required bool isStudying,
    required Color avatarColor,
    required AvatarProfile? avatarProfile,
    required bool isFollowing,
  }) async {
    final index = _socialFriends.indexWhere((friend) => friend.id == id);

    if (index >= 0) {
      _socialFriends = _socialFriends.map((friend) {
        if (friend.id != id) return friend;
        return friend.copyWith(
          name: name,
          signature: signature,
          todayFocusSeconds: todayFocusSeconds,
          isStudying: isStudying,
          avatarColor: avatarColor,
          avatarProfile: avatarProfile,
          isFollowing: isFollowing,
        );
      }).toList();
    } else {
      _socialFriends = [
        ..._socialFriends,
        SocialFriendProfile(
          id: id,
          name: name.trim().isEmpty ? '好友' : name.trim(),
          signature: signature.trim().isEmpty ? '今天慢慢前進' : signature.trim(),
          todayFocusSeconds: todayFocusSeconds,
          isStudying: isStudying,
          avatarColor: avatarColor,
          avatarProfile: avatarProfile ?? avatarVariantForSeed(id.hashCode),
          isFollowing: isFollowing,
          encouragementCount: 0,
        ),
      ];
    }

    notifyListeners();
    await _saveSocialFriends();
  }

  int getTodayReceivedEncouragementCount() {
    final now = DateTime.now();
    return _socialEncouragementRecords.where((record) {
      final createdAt = DateTime.tryParse(record.createdAt);
      if (createdAt == null) return false;
      return record.toFriendId == 'me' && _isSameDay(createdAt, now);
    }).length;
  }

  List<SocialEncouragementRecord> getRecentEncouragementsForMe({
    int limit = 5,
  }) {
    final records = _socialEncouragementRecords.where((record) {
      return record.toFriendId == 'me' || record.fromName == _profileNickname;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return records.take(limit).toList();
  }

  Future<void> sendEncouragementToFriend(
    String id, {
    String type = '加油',
  }) async {
    final target = getSocialFriendById(id);
    final targetName = target?.name ?? '好友';

    _socialFriends = _socialFriends.map((friend) {
      if (friend.id != id) return friend;
      return friend.copyWith(encouragementCount: friend.encouragementCount + 1);
    }).toList();

    _socialEncouragementRecords = [
      SocialEncouragementRecord(
        id: 'enc_${DateTime.now().millisecondsSinceEpoch}',
        fromName: _profileNickname,
        toFriendId: id,
        toFriendName: targetName,
        type: type,
        createdAt: DateTime.now().toIso8601String(),
      ),
      ..._socialEncouragementRecords,
    ];

    notifyListeners();
    await _saveSocialFriends();
    await _saveSocialEncouragementRecords();
  }

  void toggleTask(int index, bool value) {
    _checkDailyResetSync();
    if (index < 0 || index >= _tasks.length) return;
    final task = _tasks[index];
    final isDeadlineTask = task['taskType'] == 'deadline';
    final wasDone = task['done'] as bool? ?? false;

    if (value && isDeadlineTask && !_isDeadlineTaskReady(task)) {
      return;
    }
    if (value &&
        GroupChallengeTaskPlan.isGroupChallengeTask(task) &&
        !GroupChallengeTaskPlan.isAvailable(task, now: DateTime.now())) {
      return;
    }

    _tasks[index]['done'] = value;
    _tasks[index]['isDone'] = value;
    _tasks[index]['updatedAt'] = DateTime.now().toIso8601String();
    _tasks[index]['completedAt'] = value
        ? DateTime.now().toIso8601String()
        : null;
    if (value && !wasDone && isDeadlineTask) {
      _awardDeadlineTaskBonus(_tasks[index]);
    }
    _syncTaskRewards();
    _syncTodaySummary();
    checkWeeklyPlanetSettlement();
    notifyListeners();
    _saveTasks();
    _scheduleCurrentGroupChallengeProgressSync();
  }

  void addTask(
    String title,
    String category, {
    required String taskType,
    String? dueDate,
    String priority = '中',
    bool isAutoTracked = false,
    TaskSourceType? sourceType,
    double? targetValue,
    String? unitLabel,
  }) {
    final now = DateTime.now().toIso8601String();
    if (taskType == 'deadline') {
      final parsedDueDate = DateTime.tryParse(dueDate ?? '');
      if (parsedDueDate != null &&
          !canCreateDeadlineTaskForDate(parsedDueDate)) {
        return;
      }
    }

    _tasks.add({
      'id': 'task_${DateTime.now().microsecondsSinceEpoch}',
      'userId': 'local_user',
      'title': title,
      'done': false,
      'isDone': false,
      'category': category,
      'taskType': taskType,
      'dueDate': taskType == 'fixed' ? null : dueDate,
      'priority': priority,
      'isSystemTask': false,
      'isAutoTracked': isAutoTracked,
      'sourceType': sourceType?.name,
      'targetValue': targetValue,
      'unitLabel': unitLabel,
      if (isAutoTracked && sourceType == TaskSourceType.focusMinutes)
        'trackingStartFocusSeconds': _focusSeconds,
      'sourceId': null,
      'createdAt': now,
      'updatedAt': now,
      'completedAt': null,
    });
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    _syncTodaySummary();
    notifyListeners();
    _saveTasks();
  }

  void setHealthTrackingTask({
    required TaskSourceType sourceType,
    required String title,
    required String category,
    required double targetValue,
    required String unitLabel,
  }) {
    final index = _tasks.indexWhere((task) {
      final isAutoTracked = task['isAutoTracked'] as bool? ?? false;
      final isSystemTask = task['isSystemTask'] as bool? ?? false;
      return isAutoTracked &&
          !isSystemTask &&
          _readTaskSourceType(task) == sourceType;
    });

    if (index == -1) {
      addTask(
        title,
        category,
        taskType: 'fixed',
        priority: '中',
        isAutoTracked: true,
        sourceType: sourceType,
        targetValue: targetValue,
        unitLabel: unitLabel,
      );
      return;
    }

    updateTask(
      index: index,
      title: title,
      category: category,
      taskType: 'fixed',
      priority: '中',
      isAutoTracked: true,
      sourceType: sourceType,
      targetValue: targetValue,
      unitLabel: unitLabel,
    );
  }

  void deleteTask(int index) {
    if (index < 0 || index >= _tasks.length) return;

    if (_tasks[index]['sourceKind'] == 'groupChallenge') {
      return;
    }
    final sourceId = _tasks[index]['sourceId'] as String?;
    if (sourceId != null && sourceId.isNotEmpty) {
      _disableStudyRoomGoalTaskLink(sourceId);
      _syncAutoTrackedTasks();
      _syncTaskRewards();
      _syncTodaySummary();
      notifyListeners();
      _saveStudyRooms();
      _saveTasks();
      return;
    }

    _tasks.removeAt(index);
    _syncTodaySummary();
    notifyListeners();
    _saveTasks();
  }

  void updateTask({
    required int index,
    required String title,
    required String category,
    required String taskType,
    String? dueDate,
    String priority = '中',
    bool? isAutoTracked,
    TaskSourceType? sourceType,
    double? targetValue,
    String? unitLabel,
  }) {
    if (index < 0 || index >= _tasks.length) return;
    if (taskType == 'deadline') {
      final parsedDueDate = DateTime.tryParse(dueDate ?? '');
      if (parsedDueDate != null &&
          !canCreateDeadlineTaskForDate(parsedDueDate, excludingIndex: index)) {
        return;
      }
    }

    final nextIsAutoTracked =
        isAutoTracked ?? (_tasks[index]['isAutoTracked'] as bool? ?? false);
    final nextSourceType = sourceType ?? _readTaskSourceType(_tasks[index]);
    final isFocusAutoTask =
        nextIsAutoTracked && nextSourceType == TaskSourceType.focusMinutes;
    final oldDone = isFocusAutoTask
        ? false
        : (_tasks[index]['done'] as bool? ?? false);
    final now = DateTime.now().toIso8601String();

    _tasks[index] = {
      ..._tasks[index],
      'title': title,
      'done': oldDone,
      'isDone': oldDone,
      'category': category,
      'taskType': taskType,
      'dueDate': taskType == 'fixed' ? null : dueDate,
      'priority': priority,
      'isAutoTracked': nextIsAutoTracked,
      'sourceType': nextSourceType?.name ?? _tasks[index]['sourceType'],
      'targetValue': targetValue ?? _tasks[index]['targetValue'],
      'unitLabel': unitLabel ?? _tasks[index]['unitLabel'],
      if (isFocusAutoTask) 'trackingStartFocusSeconds': _focusSeconds,
      'updatedAt': now,
      'completedAt': oldDone ? (_tasks[index]['completedAt'] ?? now) : null,
    };

    _syncAutoTrackedTasks();
    _syncTaskRewards();
    _syncTodaySummary();
    notifyListeners();
    _saveTasks();
  }

  void addFocusMinutes(int minutes) {
    addFocusSeconds(minutes * 60);
  }

  void addFocusSeconds(int seconds) {
    if (seconds <= 0) return;
    _checkDailyResetSync();
    _focusSeconds += seconds;
    _syncMyFocusSecondsAcrossRooms();
    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    _syncTodaySummary();
    notifyListeners();
    _saveFocusTime();
    _saveStudyRooms();
    _saveTasks();
  }

  void updateHealthData({
    required bool isConnected,
    required double sleepHours,
    required int steps,
    required int exerciseMinutes,
    List<HealthActivitySnapshot> snapshots = const [],
  }) {
    _checkDailyResetSync();

    _isHealthConnected = isConnected;
    _sleepHours = sleepHours;
    _steps = steps;
    _exerciseMinutes = exerciseMinutes;
    _syncMyHealthMetricsAcrossRooms();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    _syncTodaySummary();
    notifyListeners();
    _saveHealthData();
    _saveStudyRooms();
    _saveTasks();
    if (snapshots.isNotEmpty) {
      unawaited(_queueHealthSnapshots(snapshots));
    }
  }

  Future<void> clearHealthData() async {
    _isHealthConnected = false;
    _sleepHours = 0;
    _steps = 0;
    _exerciseMinutes = 0;

    _syncMyHealthMetricsAcrossRooms();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    _syncTodaySummary();

    notifyListeners();
    await _saveHealthData();
    await _saveStudyRooms();
    await _saveTasks();
  }

  Future<void> clearAllLocalData() async {
    await LocalStorageService.clearAll();

    _tasks = [];
    _focusSeconds = 0;
    _sleepHours = 0;
    _steps = 0;
    _exerciseMinutes = 0;
    _isHealthConnected = false;
    _dailySummaries = [];
    _disciplineCoins = 0;
    _rewardedTaskKeys = <String>{};
    _dailyCoinEarned = <String, int>{};
    _monthlyDeadlineCoinEarned = <String, int>{};
    _unlockedAvatarItemKeys = <String>{};
    _avatarExperienceLedger = <String, Map<String, int>>{};

    _themeModeSetting = 'system';
    _iconColorSetting = 'purple';
    _backgroundThemeSetting = 'softGlow';
    _profileNickname = '老闆';
    _profileSignature = '今天也在穩定前進';
    _profileTitleBadgeKey = '';
    _avatarProfile = AvatarProfile.initial();

    _studyRooms = [];
    _socialFriends = [];
    _friendRequests = [];
    _myNudgeId = _generateNudgeId();
    _currentUser = null;
    _hasAcceptedPrivacyPolicy = false;
    _privacyAcceptedAt = null;
    _hasCompletedOnboarding = false;
    _seenUnlockedBadgeKeys = <String>{};
    _unlockedBadgeDates = <String, String>{};
    _socialEncouragementRecords = [];

    _unlockCurrentAvatarProfile();
    _unlockAllAvatarItemsForPreview();
    _syncTodaySummary();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDailyResetDateKey, _todayKey());
    await _saveTasks();
    await _saveFocusTime();
    await _saveHealthData();
    await _saveDailySummaries();
    await _saveRewardState();
    await _saveAvatarUnlockState();
    await _saveAvatarExperienceLedger();
    await _saveAppearanceSettings();
    await _saveStudyRooms();
    await _saveSocialFriends();
    await _saveFriendIdentityAndRequests();
    await _saveCurrentUser();
    await _savePrivacyConsent();
    await prefs.setBool(_onboardingCompletedKey, false);
    await _saveSocialEncouragementRecords();
    await _saveUnlockedBadges();
    await _saveSeenUnlockedBadges();

    notifyListeners();
  }

  Future<void> generateMockDailySummaries() async {
    final now = DateTime.now();
    final mock = <DailySummary>[
      for (int i = 6; i >= 0; i--)
        () {
          final date = now.subtract(Duration(days: i));
          final completedTasks = (i % 5) + 1;
          const totalTasks = 5;
          final focusMinutes = 25 + (6 - i) * 20;
          final sleepHours = 5.5 + ((6 - i) * 0.4);
          final steps = 3000 + ((6 - i) * 900);
          final exerciseMinutes = 5 + ((6 - i) * 5);
          final score = _calculateDisciplineScoreFromValues(
            completedTasks: completedTasks,
            totalTasks: totalTasks,
            focusMinutes: focusMinutes,
            sleepHours: sleepHours,
            steps: steps,
            exerciseMinutes: exerciseMinutes,
            isHealthConnected: true,
          );
          final coinsEarned = AppState.scoreCoinMilestones.entries
              .where((entry) => score >= entry.key)
              .fold<int>(0, (acc, entry) => acc + entry.value)
              .clamp(0, AppState.coinDailyLimit)
              .toInt();
          final healthCompleted =
              (sleepHours >= 7 ? 1 : 0) +
              (steps >= 6000 ? 1 : 0) +
              (exerciseMinutes >= 30 ? 1 : 0);
          final focusCompleted = focusMinutes >= 30 ? 1 : 0;
          final roomCompleted = focusMinutes >= 60 ? 1 : 0;

          return DailySummary(
            date: _formatDate(date),
            completedTasks: completedTasks,
            totalTasks: totalTasks,
            focusMinutes: focusMinutes,
            sleepHours: sleepHours,
            steps: steps,
            exerciseMinutes: exerciseMinutes,
            disciplineScore: score,
            coinsEarned: coinsEarned,
            autoTrackedCompleted:
                healthCompleted + focusCompleted + roomCompleted,
            autoTrackedTotal: 5,
            healthCompleted: healthCompleted,
            healthTotal: 3,
            focusCompleted: focusCompleted,
            focusTotal: 1,
            roomCompleted: roomCompleted,
            roomTotal: 1,
            autoTrackedSources: const ['專注', '睡眠', '步數', '運動', '自律房'],
          );
        }(),
    ];

    _dailySummaries = mock;
    _avatarExperienceLedger = <String, Map<String, int>>{};
    _migrateLegacyAvatarExperienceLedger();
    notifyListeners();
    await _saveDailySummaries();
    await _saveAvatarExperienceLedger();
  }

  Future<void> clearDailySummaries() async {
    _dailySummaries = [];
    _avatarExperienceLedger = <String, Map<String, int>>{};
    _syncTodaySummary();
    notifyListeners();
    await _saveDailySummaries();
    await _saveAvatarExperienceLedger();
  }

  void _syncMyFocusSecondsAcrossRooms() {
    _studyRooms = _studyRooms.map((room) {
      final members = List<StudyMemberData>.from(room.members);
      final meIndex = members.indexWhere(
        (m) => m.memberId == _myId || m.memberId == 'local_user',
      );

      if (meIndex == -1) {
        members.insert(
          0,
          StudyMemberData(
            memberId: _myId,
            name: _profileNickname,
            roomNickname: _profileNickname,
            status: StudyMemberStatus.offline,
            sessionSeconds: 0,
            todayFocusSeconds: _focusSeconds,
            todayMetricValue: _focusSeconds / 3600,
            avatarColor: const Color(0xFF7C6AE6),
            avatarProfile: _avatarProfile,
            role: 'owner',
            personalGoalSeconds: 60 * 60,
            hasReachedPersonalGoal: _focusSeconds >= 60 * 60,
          ),
        );
      } else {
        final current = members[meIndex];
        members[meIndex] = current.copyWith(
          name: _profileNickname,
          roomNickname: current.roomNickname.isEmpty
              ? _profileNickname
              : current.roomNickname,
          todayFocusSeconds: _focusSeconds,
          todayMetricValue: _focusSeconds / 3600,
          avatarProfile: _avatarProfile,
          hasReachedPersonalGoal: _focusSeconds >= current.personalGoalSeconds,
        );
      }

      return room.copyWith(members: members);
    }).toList();
  }

  StudyRoomData? getStudyRoomById(String roomId) {
    try {
      return _studyRooms.firstWhere((room) => room.id == roomId);
    } catch (_) {
      return null;
    }
  }

  StudyRoomDailyRecord? getTodayPreviewRecord(String roomId) {
    final room = getStudyRoomById(roomId);
    final approvedMembers =
        room?.members.where((member) => member.isApproved).toList() ?? const [];
    if (room == null || approvedMembers.isEmpty) return null;

    final total = approvedMembers.fold<int>(
      0,
      (acc, member) => acc + member.todayFocusSeconds,
    );

    final sorted = [...approvedMembers]
      ..sort((a, b) => b.todayFocusSeconds.compareTo(a.todayFocusSeconds));
    final top = sorted.first;

    return StudyRoomDailyRecord(
      date: _todayKey(),
      totalFocusSeconds: total,
      challengeCompleted: room.challengeCompleted,
      topMemberName: top.name,
      topMemberFocusSeconds: top.todayFocusSeconds,
      memberSnapshots: approvedMembers,
    );
  }

  void updateRoomAnnouncement({
    required String roomId,
    required String announcement,
  }) {
    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      return room.copyWith(announcement: announcement);
    }).toList();

    notifyListeners();
    _saveStudyRooms();
  }

  void updateRoomTags({required String roomId, required List<String> tags}) {
    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      return room.copyWith(tags: tags);
    }).toList();

    notifyListeners();
    _saveStudyRooms();
  }

  void updateRoomMemberLimit({
    required String roomId,
    required int memberLimit,
  }) {
    final safeLimit = memberLimit <= 0 ? 1 : memberLimit;

    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      final approvedCount = room.members
          .where((member) => member.isApproved)
          .length;
      final adjustedLimit = safeLimit < approvedCount
          ? approvedCount
          : safeLimit;
      return room.copyWith(memberLimit: adjustedLimit);
    }).toList();

    notifyListeners();
    _saveStudyRooms();
  }

  void updateRoomRules({
    required String roomId,
    required String rules,
    required bool nicknameRuleEnabled,
    required String nicknameRuleText,
    required bool joinQuestionsEnabled,
    required List<String> joinQuestions,
  }) {
    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      return room.copyWith(
        roomRules: rules,
        nicknameRuleEnabled: nicknameRuleEnabled,
        nicknameRuleText: nicknameRuleText,
        joinQuestionsEnabled: joinQuestionsEnabled,
        joinQuestions: joinQuestions,
      );
    }).toList();

    notifyListeners();
    _saveStudyRooms();
  }

  String _studyRoomIdentityName(String roomId) {
    final room = getStudyRoomById(roomId);
    if (room != null) {
      final ownMembers = room.members.where(
        (member) => member.memberId == _myId || member.memberId == 'local_user',
      );
      if (ownMembers.isNotEmpty) {
        final ownMember = ownMembers.first;
        final displayName = ownMember.roomNickname.isEmpty
            ? ownMember.name
            : ownMember.roomNickname;
        if (displayName.trim().isNotEmpty) return displayName.trim();
      }
    }
    return _profileNickname.trim().isEmpty ? '自律夥伴' : _profileNickname.trim();
  }

  StudyRoomEvent _newStudyRoomEvent({
    required String roomId,
    required String text,
    required StudyRoomEventType type,
  }) {
    final now = DateTime.now().toUtc();
    return StudyRoomEvent(
      id: 'event_${now.microsecondsSinceEpoch}',
      actorId: _myId,
      actorName: _studyRoomIdentityName(roomId),
      text: text.trim(),
      type: type,
      createdAt: now,
    );
  }

  Map<String, dynamic> _canonicalRoomEventData(
    String roomId,
    StudyRoomEvent event,
  ) {
    return {...event.toJson(), 'roomId': roomId};
  }

  void _appendLocalStudyRoomEvent(String roomId, StudyRoomEvent event) {
    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      return room.copyWith(
        events: [
          event,
          ...room.events.where((item) => item.id != event.id),
        ].take(80).toList(),
      );
    }).toList();
  }

  Future<void> removeStudyRoomMember({
    required String roomId,
    required String memberId,
  }) async {
    final room = getStudyRoomById(roomId);
    if (room == null) throw StateError('Room not found');
    if (room.ownerId != _myId && room.ownerId != 'local_user') {
      throw StateError('Only the room owner can remove members');
    }
    final matches = room.members.where(
      (member) =>
          member.memberId == memberId &&
          member.memberId != _myId &&
          member.memberId != 'local_user' &&
          member.role != 'owner',
    );
    if (matches.isEmpty) {
      throw StateError('The selected member cannot be removed');
    }
    final removedMember = matches.first;
    final event = _newStudyRoomEvent(
      roomId: roomId,
      text:
          '${removedMember.roomNickname.isEmpty ? removedMember.name : removedMember.roomNickname} 已被移出房間',
      type: StudyRoomEventType.system,
    );
    if (_currentUser != null) {
      await _removeCanonicalRoomMember(roomId, memberId, auditEvent: event);
    }

    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      final updatedMembers = room.members
          .where((member) => member.memberId != memberId)
          .toList();
      return room.copyWith(members: updatedMembers);
    }).toList();
    _appendLocalStudyRoomEvent(roomId, event);

    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
  }

  Future<void> approveStudyRoomJoinRequest({
    required String roomId,
    required String memberId,
  }) async {
    final room = getStudyRoomById(roomId);
    if (room == null) throw StateError('Room not found');
    if (room.ownerId != _myId && room.ownerId != 'local_user') {
      throw StateError('Only the room owner can approve members');
    }
    final pendingMembers = room.members.where(
      (member) => member.memberId == memberId && !member.isApproved,
    );
    if (pendingMembers.isEmpty) {
      throw StateError('The join request no longer exists');
    }
    if (room.members.where((member) => member.isApproved).length >=
        room.memberLimit) {
      throw StateError('The room has reached its member limit');
    }
    final approvedMember = pendingMembers.first.copyWith(isApproved: true);
    final event = _newStudyRoomEvent(
      roomId: roomId,
      text:
          '${approvedMember.roomNickname.isEmpty ? approvedMember.name : approvedMember.roomNickname} 的加入申請已通過',
      type: StudyRoomEventType.system,
    );
    if (_currentUser != null) {
      final firestore = FirebaseFirestore.instance;
      final roomRef = firestore.collection('rooms').doc(roomId);
      final batch = firestore.batch();
      batch.update(roomRef.collection('members').doc(memberId), {
        'approvalStatus': 'approved',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      batch.set(
        roomRef.collection('events').doc(event.id),
        _canonicalRoomEventData(roomId, event),
      );
      await batch.commit();
    }

    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      final members = room.members.map((member) {
        if (member.memberId != memberId || member.isApproved) return member;
        return approvedMember;
      }).toList();
      return room.copyWith(members: members);
    }).toList();
    _appendLocalStudyRoomEvent(roomId, event);

    _syncStudyRoomGoalTasks();
    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
  }

  Future<void> rejectStudyRoomJoinRequest({
    required String roomId,
    required String memberId,
  }) async {
    final room = getStudyRoomById(roomId);
    if (room == null) throw StateError('Room not found');
    if (room.ownerId != _myId && room.ownerId != 'local_user') {
      throw StateError('Only the room owner can reject members');
    }
    final pendingMembers = room.members.where(
      (member) => member.memberId == memberId && !member.isApproved,
    );
    if (pendingMembers.isEmpty) {
      throw StateError('The join request no longer exists');
    }
    final rejectedMember = pendingMembers.first;
    final event = _newStudyRoomEvent(
      roomId: roomId,
      text:
          '${rejectedMember.roomNickname.isEmpty ? rejectedMember.name : rejectedMember.roomNickname} 的加入申請已拒絕',
      type: StudyRoomEventType.system,
    );
    if (_currentUser != null) {
      await _removeCanonicalRoomMember(roomId, memberId, auditEvent: event);
    }

    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      final members = room.members
          .where((member) => member.memberId != memberId)
          .toList();
      return room.copyWith(members: members);
    }).toList();
    _appendLocalStudyRoomEvent(roomId, event);

    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
  }

  Future<void> _removeCanonicalRoomMember(
    String roomId,
    String memberId, {
    StudyRoomEvent? auditEvent,
  }) async {
    if (memberId.isEmpty || memberId == _myId) return;
    final firestore = FirebaseFirestore.instance;
    final roomRef = firestore.collection('rooms').doc(roomId);
    final batch = firestore.batch();
    batch.update(roomRef, {
      'memberIds': FieldValue.arrayRemove([memberId]),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    batch.delete(roomRef.collection('members').doc(memberId));
    if (auditEvent != null) {
      batch.set(
        roomRef.collection('events').doc(auditEvent.id),
        _canonicalRoomEventData(roomId, auditEvent),
      );
    }
    await batch.commit();
  }

  Future<void> addStudyRoomMessage({
    required String roomId,
    required String text,
    StudyRoomMessageType type = StudyRoomMessageType.text,
    String senderId = 'local_user',
    String? senderName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now().toUtc();
    final resolvedSenderId = senderId == 'local_user' ? _myId : senderId;
    final message = StudyRoomMessage(
      id: 'message_${now.microsecondsSinceEpoch}',
      senderId: resolvedSenderId,
      senderName: senderName ?? _studyRoomIdentityName(roomId),
      text: trimmed,
      type: type,
      createdAt: now,
    );

    final user = _currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .doc(message.id)
          .set({...message.toJson(), 'roomId': roomId});
    }

    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      return room.copyWith(
        messages: [
          message,
          ...room.messages.where((item) => item.id != message.id),
        ].take(60).toList(),
      );
    }).toList();
    notifyListeners();
    await _saveStudyRooms();
  }

  Future<void> addStudyRoomEvent({
    required String roomId,
    required String text,
    StudyRoomEventType type = StudyRoomEventType.system,
    String actorId = 'local_user',
    String? actorName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final event = _newStudyRoomEvent(roomId: roomId, text: trimmed, type: type);
    final resolvedEvent = actorId == 'local_user' && actorName == null
        ? event
        : StudyRoomEvent(
            id: event.id,
            actorId: actorId == 'local_user' ? _myId : actorId,
            actorName: actorName ?? event.actorName,
            text: event.text,
            type: event.type,
            createdAt: event.createdAt,
          );

    final user = _currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('events')
          .doc(resolvedEvent.id)
          .set(_canonicalRoomEventData(roomId, resolvedEvent));
    }

    _appendLocalStudyRoomEvent(roomId, resolvedEvent);
    notifyListeners();
    await _saveStudyRooms();
  }

  Future<void> transferStudyRoomOwnership({
    required String roomId,
    required String newOwnerId,
  }) async {
    final room = getStudyRoomById(roomId);
    if (room == null) throw StateError('Room not found');
    if (room.ownerId != _myId && room.ownerId != 'local_user') {
      throw StateError('Only the room owner can transfer ownership');
    }
    final nextOwner = room.members.where(
      (member) =>
          member.memberId == newOwnerId &&
          member.isApproved &&
          member.role != 'owner',
    );
    if (nextOwner.isEmpty) {
      throw StateError('The new owner must be an approved member');
    }
    final selectedOwner = nextOwner.first;
    final nextOwnerName = selectedOwner.roomNickname.isEmpty
        ? selectedOwner.name
        : selectedOwner.roomNickname;
    final event = _newStudyRoomEvent(
      roomId: roomId,
      text: '${_studyRoomIdentityName(roomId)} 將房主移交給 $nextOwnerName',
      type: StudyRoomEventType.system,
    );
    final user = _currentUser;
    if (user != null) {
      final firestore = FirebaseFirestore.instance;
      final roomRef = firestore.collection('rooms').doc(roomId);
      final batch = firestore.batch();
      final now = DateTime.now().toUtc().toIso8601String();
      batch.update(roomRef, {
        'ownerId': newOwnerId,
        'ownerName': nextOwnerName,
        'updatedAt': now,
      });
      batch.update(roomRef.collection('members').doc(user.id), {
        'role': 'member',
        'updatedAt': now,
      });
      batch.update(roomRef.collection('members').doc(newOwnerId), {
        'role': 'owner',
        'updatedAt': now,
      });
      batch.set(
        roomRef.collection('events').doc(event.id),
        _canonicalRoomEventData(roomId, event),
      );
      await batch.commit();
    }

    _studyRooms = _studyRooms.map((item) {
      if (item.id != roomId) return item;
      return item.copyWith(
        ownerId: newOwnerId,
        ownerName: nextOwnerName,
        members: item.members.map((member) {
          if (member.memberId == newOwnerId) {
            return member.copyWith(role: 'owner');
          }
          if (member.memberId == _myId ||
              member.memberId == 'local_user' ||
              member.role == 'owner') {
            return member.copyWith(role: 'member');
          }
          return member;
        }).toList(),
      );
    }).toList();
    _appendLocalStudyRoomEvent(roomId, event);
    notifyListeners();
    await _saveStudyRooms();
  }

  Future<void> leaveStudyRoom(String roomId) async {
    final room = getStudyRoomById(roomId);
    if (room == null) return;

    final remainingMembers = room.members
        .where(
          (member) =>
              member.memberId != _myId && member.memberId != 'local_user',
        )
        .toList();
    final isOwner = room.ownerId == _myId || room.ownerId == 'local_user';
    if (isOwner && remainingMembers.isNotEmpty) {
      throw StateError('請先移交房主或處理其他成員');
    }

    final user = _currentUser;
    if (user != null) {
      final roomRef = FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId);
      if (isOwner) {
        await roomRef.update({
          'status': 'closed',
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        final batch = FirebaseFirestore.instance.batch();
        batch.update(roomRef, {
          'memberIds': FieldValue.arrayRemove([user.id]),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
        batch.delete(roomRef.collection('members').doc(user.id));
        await batch.commit();
      }
    }

    _studyRooms = _studyRooms.where((item) => item.id != roomId).toList();
    _removeStudyRoomGoalTask(roomId);
    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    await _saveStudyRooms();
    await _saveTasks();
  }

  Future<void> createStudyRoom({
    required String name,
    required String description,
    required Color accentColor,
    String? ownerId,
    String? ownerName,
    List<String>? tags,
    int? memberLimit,
    String category = '自訂',
    int dailyGoalHours = 2,
    StudyRoomType roomType = StudyRoomType.study,
    TaskSourceType goalSourceType = TaskSourceType.studyRoom,
    double? dailyGoalValue,
    String? goalUnitLabel,
    StudyRoomJoinMode joinMode = StudyRoomJoinMode.instant,
    bool joinQuestionsEnabled = false,
    List<String> joinQuestions = const [],
    bool nicknameRuleEnabled = false,
    String nicknameRuleText = '',
    String roomRules = '',
    String password = '',
    String challengeTitle = '今日房間挑戰',
    String challengeDescription = '一起累積自律進度',
    String challengeDeadlineLabel = '今天 23:59',
  }) async {
    // Use Firebase uid as ownerId when signed in
    final resolvedOwnerId =
        (ownerId == null ||
            ownerId.trim().isEmpty ||
            ownerId.trim() == 'local_user')
        ? _myId
        : ownerId.trim();
    final safeOwnerName = (ownerName == null || ownerName.trim().isEmpty)
        ? _profileNickname
        : ownerName.trim();

    final safeGoalHours = dailyGoalHours <= 0 ? 2 : dailyGoalHours;
    final safeGoalValue = (dailyGoalValue == null || dailyGoalValue <= 0)
        ? safeGoalHours.toDouble()
        : dailyGoalValue;
    final initialMetricValue = _currentMetricValueForSource(goalSourceType);
    final now = DateTime.now();

    final room = StudyRoomData(
      id: 'room_${now.millisecondsSinceEpoch}',
      name: name,
      description: description.isEmpty ? '新的自律房' : description,
      accentColor: accentColor,
      ownerId: resolvedOwnerId,
      ownerName: safeOwnerName,
      announcement: '',
      tags: tags ?? const [],
      memberLimit: (memberLimit == null || memberLimit <= 0) ? 8 : memberLimit,
      category: category,
      dailyGoalHours: safeGoalHours,
      roomType: roomType,
      goalSourceType: goalSourceType,
      dailyGoalValue: safeGoalValue,
      goalUnitLabel: goalUnitLabel ?? '小時',
      joinMode: joinMode,
      joinQuestionsEnabled: joinQuestionsEnabled,
      joinQuestions: joinQuestions,
      nicknameRuleEnabled: nicknameRuleEnabled,
      nicknameRuleText: nicknameRuleText,
      roomRules: roomRules,
      password: password,
      challengeTitle: challengeTitle,
      challengeDescription: challengeDescription,
      challengeGoalSeconds: safeGoalHours * 60 * 60,
      challengeDeadlineLabel: challengeDeadlineLabel,
      challengeCompleted: initialMetricValue >= safeGoalValue,
      syncTaskEnabled: true,
      members: [
        StudyMemberData(
          memberId: _myId,
          name: _profileNickname,
          roomNickname: _profileNickname,
          status: StudyMemberStatus.offline,
          sessionSeconds: 0,
          todayFocusSeconds: _focusSeconds,
          todayMetricValue: initialMetricValue,
          avatarColor: const Color(0xFF7C6AE6),
          avatarProfile: _avatarProfile,
          role: 'owner',
          personalGoalSeconds: safeGoalHours * 60 * 60,
          hasReachedPersonalGoal: initialMetricValue >= safeGoalValue,
          isApproved: true,
          joinAnswer: '',
        ),
      ],
      events: [
        StudyRoomEvent(
          id: 'event_${now.microsecondsSinceEpoch}',
          actorId: resolvedOwnerId,
          actorName: safeOwnerName,
          text: '$safeOwnerName 建立了這間自律房',
          type: StudyRoomEventType.system,
          createdAt: now,
        ),
      ],
    );

    _studyRooms = [room, ..._studyRooms];
    _syncStudyRoomGoalTasks();
    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    await _saveStudyRooms();
    await _saveTasks();
  }

  void inviteMemberToRoom({
    required String roomId,
    required String memberName,
    required Color avatarColor,
    String memberId = '',
    String roomNickname = '',
    bool isApproved = true,
    String joinAnswer = '',
  }) {
    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;

      final exists = room.members.any((m) => m.name == memberName);
      if (exists) return room;
      final approvedCount = room.members
          .where((member) => member.isApproved)
          .length;
      if (isApproved && approvedCount >= room.memberLimit) return room;

      final updatedMembers = [
        ...room.members,
        StudyMemberData(
          memberId: memberId.isEmpty ? 'member_$memberName' : memberId,
          name: memberName,
          roomNickname: roomNickname.isEmpty ? memberName : roomNickname,
          status: StudyMemberStatus.offline,
          sessionSeconds: 0,
          todayFocusSeconds: 0,
          todayMetricValue: 0,
          avatarColor: avatarColor,
          avatarProfile: avatarVariantForSeed(memberName.hashCode),
          role: 'member',
          personalGoalSeconds: room.dailyGoalHours * 60 * 60,
          hasReachedPersonalGoal: false,
          isApproved: isApproved,
          joinAnswer: joinAnswer,
        ),
      ];

      return room.copyWith(members: updatedMembers);
    }).toList();

    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
  }

  Future<void> joinStudyRoomFromDiscovery({
    required StudyRoomData room,
    bool isApproved = true,
    String joinAnswer = '',
  }) async {
    final now = DateTime.now();
    final localMember = StudyMemberData(
      memberId: _myId,
      name: _profileNickname,
      roomNickname: _profileNickname,
      status: StudyMemberStatus.offline,
      sessionSeconds: 0,
      todayFocusSeconds: _focusSeconds,
      todayMetricValue: _focusSeconds / 3600,
      avatarColor: const Color(0xFF7C6AE6),
      avatarProfile: _avatarProfile,
      role: 'member',
      personalGoalSeconds: room.dailyGoalHours * 60 * 60,
      hasReachedPersonalGoal: _focusSeconds >= room.dailyGoalHours * 60 * 60,
      isApproved: isApproved,
      joinAnswer: joinAnswer,
    );

    var changed = false;
    _studyRooms = _studyRooms.map((existingRoom) {
      if (existingRoom.id != room.id) return existingRoom;

      if (existingRoom.members.any(
        (member) => member.memberId == _myId || member.memberId == 'local_user',
      )) {
        return existingRoom;
      }
      final approvedCount = existingRoom.members
          .where((member) => member.isApproved)
          .length;
      if (isApproved && approvedCount >= existingRoom.memberLimit) {
        return existingRoom;
      }

      changed = true;
      return existingRoom.copyWith(
        members: [localMember, ...existingRoom.members],
        events: [
          StudyRoomEvent(
            id: 'event_${now.microsecondsSinceEpoch}',
            actorId: _myId,
            actorName: _profileNickname,
            text: isApproved
                ? '$_profileNickname 加入了房間'
                : '$_profileNickname 送出加入申請',
            type: StudyRoomEventType.join,
            createdAt: now,
          ),
          ...existingRoom.events,
        ],
      );
    }).toList();

    if (!changed &&
        !_studyRooms.any((existingRoom) => existingRoom.id == room.id)) {
      changed = true;
      _studyRooms = [
        room.copyWith(
          members: [localMember, ...room.members],
          events: [
            StudyRoomEvent(
              id: 'event_${now.microsecondsSinceEpoch}',
              actorId: _myId,
              actorName: _profileNickname,
              text: isApproved
                  ? '$_profileNickname 加入了房間'
                  : '$_profileNickname 送出加入申請',
              type: StudyRoomEventType.join,
              createdAt: now,
            ),
            ...room.events,
          ],
          syncTaskEnabled: isApproved,
        ),
        ..._studyRooms,
      ];
    }

    if (!changed) return;

    _syncStudyRoomGoalTasks();
    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    final joinedRoom = getStudyRoomById(room.id);
    final user = _currentUser;
    if (joinedRoom != null && user != null) {
      final member = joinedRoom.members.firstWhere(
        (item) => item.memberId == user.id || item.memberId == 'local_user',
      );
      final firestore = FirebaseFirestore.instance;
      final roomRef = firestore.collection('rooms').doc(room.id);
      final batch = firestore.batch();
      batch.update(roomRef, {
        'memberIds': FieldValue.arrayUnion([user.id]),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      batch.set(
        roomRef.collection('members').doc(user.id),
        _roomMemberProjection(joinedRoom, member, user.id),
      );
      try {
        await batch.commit();
      } catch (error) {
        debugPrint('Failed to join canonical room: $error');
        rethrow;
      }
    }
    await _saveStudyRooms();
    await _saveTasks();
  }

  void updateMyStudyRoomPresence({
    required String roomId,
    required StudyMemberStatus status,
    required int sessionSeconds,
  }) {
    _studyRooms = _studyRooms.map((room) {
      final members = List<StudyMemberData>.from(room.members);
      final meIndex = members.indexWhere(
        (m) => m.memberId == _myId || m.memberId == 'local_user',
      );
      if (room.id == roomId && meIndex != -1 && !members[meIndex].isApproved) {
        return room;
      }

      if (meIndex == -1) {
        members.insert(
          0,
          StudyMemberData(
            memberId: _myId,
            name: _profileNickname,
            roomNickname: _profileNickname,
            status: room.id == roomId ? status : StudyMemberStatus.offline,
            sessionSeconds: room.id == roomId ? sessionSeconds : 0,
            todayFocusSeconds: room.id == roomId
                ? _focusSeconds + sessionSeconds
                : _focusSeconds,
            todayMetricValue:
                (room.id == roomId
                    ? _focusSeconds + sessionSeconds
                    : _focusSeconds) /
                3600,
            avatarColor: const Color(0xFF7C6AE6),
            avatarProfile: _avatarProfile,
            role: 'owner',
            personalGoalSeconds: room.dailyGoalHours * 60 * 60,
            hasReachedPersonalGoal:
                (room.id == roomId
                    ? _focusSeconds + sessionSeconds
                    : _focusSeconds) >=
                room.dailyGoalHours * 60 * 60,
          ),
        );
      } else {
        if (room.id == roomId) {
          final current = members[meIndex];
          final nextToday = _focusSeconds + sessionSeconds;
          members[meIndex] = current.copyWith(
            name: _profileNickname,
            status: status,
            sessionSeconds: sessionSeconds,
            todayFocusSeconds: nextToday,
            todayMetricValue: nextToday / 3600,
            avatarProfile: _avatarProfile,
            hasReachedPersonalGoal: nextToday >= current.personalGoalSeconds,
          );
        } else {
          final current = members[meIndex];
          members[meIndex] = current.copyWith(
            name: _profileNickname,
            status: StudyMemberStatus.offline,
            sessionSeconds: 0,
            todayFocusSeconds: _focusSeconds,
            todayMetricValue: _focusSeconds / 3600,
            avatarProfile: _avatarProfile,
            hasReachedPersonalGoal:
                _focusSeconds >= current.personalGoalSeconds,
          );
        }
      }

      return room.copyWith(members: members);
    }).toList();

    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
  }

  List<RoomActivitySession> get roomActivitySessions =>
      List.unmodifiable(_roomActivitySessions.values);

  RoomActivitySession? activeRoomActivitySession(String roomId) {
    final activeSessionId = _roomActiveSessionIds[roomId];
    if (activeSessionId == null) return null;
    final pointedSession = _roomActivitySessions[activeSessionId];
    if (pointedSession == null || pointedSession.isTerminal) return null;
    return pointedSession;
  }

  RoomActivityKind _activityKindForRoom(StudyRoomData room) {
    return switch (room.roomType) {
      StudyRoomType.study => RoomActivityKind.focus,
      StudyRoomType.sleep => RoomActivityKind.sleep,
      StudyRoomType.exercise => RoomActivityKind.exercise,
      StudyRoomType.steps => RoomActivityKind.steps,
      StudyRoomType.custom => RoomActivityKind.custom,
    };
  }

  Future<RoomActivitySession> startRoomActivitySession({
    required String roomId,
    double? targetValue,
    RoomActivitySource source = RoomActivitySource.app,
  }) async {
    final room = getStudyRoomById(roomId);
    if (room == null) throw StateError('Room not found');
    final member = room.members.where(
      (item) =>
          (item.memberId == _myId || item.memberId == 'local_user') &&
          item.isApproved,
    );
    if (member.isEmpty) {
      throw StateError('Only an approved member can start an activity');
    }
    final existing = activeRoomActivitySession(roomId);
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    final actorId = _myId;
    final session = RoomActivitySession.start(
      sessionId: '${actorId}_${room.id}_${now.microsecondsSinceEpoch}'
          .replaceAll('/', '_'),
      roomId: room.id,
      actorId: actorId,
      activityKind: _activityKindForRoom(room),
      metricUnit: _roomMetricUnit(room),
      targetValue: targetValue ?? room.dailyGoalValue,
      source: source,
      now: now,
    );
    _roomActivitySessions[session.sessionId] = session;
    _roomActiveSessionIds[roomId] = session.sessionId;
    notifyListeners();

    final user = _currentUser;
    if (user != null) {
      try {
        final firestore = FirebaseFirestore.instance;
        final roomRef = firestore.collection('rooms').doc(roomId);
        final batch = firestore.batch();
        batch.update(roomRef.collection('members').doc(user.id), {
          'activeSessionId': session.sessionId,
          'updatedAt': now.toIso8601String(),
        });
        batch.set(
          roomRef.collection('activity_sessions').doc(session.sessionId),
          session.toJson(),
        );
        await batch.commit();
      } catch (_) {
        _roomActivitySessions.remove(session.sessionId);
        _roomActiveSessionIds.remove(roomId);
        notifyListeners();
        rethrow;
      }
    }
    await _queueRoomActivityLedgerEvent(session, ActivityEventType.started);
    return session;
  }

  Future<RoomActivitySession> transitionRoomActivitySession({
    required String sessionId,
    required RoomActivitySessionStatus status,
    required double metricValue,
  }) async {
    final current = _roomActivitySessions[sessionId];
    if (current == null) throw StateError('Room activity session not found');
    final next = current.transition(
      actorId: _myId,
      nextStatus: status,
      metricValue: metricValue,
      now: DateTime.now().toUtc(),
    );
    _roomActivitySessions[sessionId] = next;
    if (next.isTerminal) {
      _roomActiveSessionIds.remove(current.roomId);
    }
    notifyListeners();

    final user = _currentUser;
    if (user != null) {
      try {
        final firestore = FirebaseFirestore.instance;
        final roomRef = firestore.collection('rooms').doc(current.roomId);
        if (next.isTerminal) {
          final batch = firestore.batch();
          batch.update(roomRef.collection('members').doc(user.id), {
            'activeSessionId': null,
            'updatedAt': next.updatedAt.toIso8601String(),
          });
          batch.set(
            roomRef.collection('activity_sessions').doc(sessionId),
            next.toJson(),
          );
          await batch.commit();
        } else {
          await roomRef
              .collection('activity_sessions')
              .doc(sessionId)
              .set(next.toJson());
        }
      } catch (_) {
        _roomActivitySessions[sessionId] = current;
        _roomActiveSessionIds[current.roomId] = current.sessionId;
        notifyListeners();
        rethrow;
      }
    }
    await _queueRoomActivityLedgerEvent(next, switch (status) {
      RoomActivitySessionStatus.active => ActivityEventType.resumed,
      RoomActivitySessionStatus.paused => ActivityEventType.paused,
      RoomActivitySessionStatus.completed => ActivityEventType.completed,
      RoomActivitySessionStatus.cancelled => ActivityEventType.discarded,
    });
    return next;
  }

  Future<void> _queueRoomActivityLedgerEvent(
    RoomActivitySession session,
    ActivityEventType eventType,
  ) async {
    final user = _currentUser;
    if (user == null) return;
    final source = switch (session.source) {
      RoomActivitySource.app => ActivitySource.app,
      RoomActivitySource.web => ActivitySource.web,
      RoomActivitySource.health => ActivitySource.health,
      RoomActivitySource.device => ActivitySource.device,
    };
    if (source != ActivitySource.app && source != ActivitySource.web) {
      return;
    }
    final activityType = switch (session.activityKind) {
      RoomActivityKind.focus => ActivityType.focus,
      RoomActivityKind.sleep => ActivityType.sleep,
      RoomActivityKind.exercise => ActivityType.exercise,
      RoomActivityKind.steps => ActivityType.steps,
      RoomActivityKind.custom => ActivityType.custom,
    };
    final eventId = [
      session.sessionId,
      eventType.name,
      session.updatedAt.microsecondsSinceEpoch,
    ].join('_');
    await _activityLedgerOutbox.enqueue(
      ActivityEvidence(
        eventId: eventId,
        sourceRecordId: eventId,
        sessionId: session.sessionId,
        activityCorrelationId: session.sessionId,
        submittedByUserId: user.id,
        actorUserId: user.id,
        roomIds: [session.roomId],
        activityType: activityType,
        source: source,
        eventType: eventType,
        metricValue: session.metricValue,
        metricUnit: session.metricUnit,
        occurredAt: session.updatedAt,
      ),
    );
    unawaited(_activityLedgerOutbox.flush());
  }

  Future<void> queuePersonalFocusLedgerEvent({
    required String sessionId,
    required ActivityEventType eventType,
    required int elapsedSeconds,
    required DateTime occurredAt,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    final normalizedSeconds = math.max(0, elapsedSeconds);
    final eventId = [
      sessionId,
      eventType.name,
      occurredAt.toUtc().microsecondsSinceEpoch,
    ].join('_');
    await _activityLedgerOutbox.enqueue(
      ActivityEvidence(
        eventId: eventId,
        sourceRecordId: eventId,
        sessionId: sessionId,
        activityCorrelationId: sessionId,
        submittedByUserId: user.id,
        actorUserId: user.id,
        roomIds: const [],
        activityType: ActivityType.focus,
        source: ActivitySource.app,
        eventType: eventType,
        metricValue: normalizedSeconds / 60,
        metricUnit: 'minutes',
        occurredAt: occurredAt.toUtc(),
      ),
    );
    unawaited(_activityLedgerOutbox.flush());
  }

  List<String> _eligibleRoomIdsForHealthSnapshot(
    HealthActivitySnapshot snapshot,
  ) {
    final sourceType = switch (snapshot.activityType) {
      ActivityType.sleep => TaskSourceType.sleepHours,
      ActivityType.steps => TaskSourceType.steps,
      ActivityType.exercise => TaskSourceType.exerciseMinutes,
      _ => null,
    };
    if (sourceType == null) return const [];
    final userId = _currentUser?.id;
    if (userId == null) return const [];
    return _studyRooms
        .where(
          (room) =>
              room.goalSourceType == sourceType &&
              room.members.any(
                (member) =>
                    member.isApproved &&
                    (member.memberId == userId ||
                        member.memberId == 'local_user'),
              ),
        )
        .map((room) => room.id)
        .toList(growable: false);
  }

  Future<void> _queueHealthSnapshots(
    List<HealthActivitySnapshot> snapshots,
  ) async {
    if (_currentUser == null) return;
    final enriched = snapshots
        .map(
          (snapshot) => snapshot.copyWith(
            roomIds: _eligibleRoomIdsForHealthSnapshot(snapshot),
          ),
        )
        .toList(growable: false);
    await _healthSnapshotOutbox.enqueueAll(enriched);
    unawaited(_healthSnapshotOutbox.flush());
  }

  void clearMyStudyRoomPresence(String roomId) {
    updateMyStudyRoomPresence(
      roomId: roomId,
      status: StudyMemberStatus.offline,
      sessionSeconds: 0,
    );
  }

  void setRoomChallenge({
    required String roomId,
    required String title,
    required String description,
    required int goalSeconds,
    required String deadlineLabel,
  }) {
    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;

      final total = room.members.fold<int>(
        0,
        (acc, member) =>
            acc + (member.isApproved ? member.todayFocusSeconds : 0),
      );

      final safeGoal = goalSeconds <= 0 ? 60 * 60 : goalSeconds;

      return room.copyWith(
        challengeTitle: title.trim().isEmpty ? '今日房間挑戰' : title.trim(),
        challengeDescription: description.trim().isEmpty
            ? '一起累積專注時數'
            : description.trim(),
        challengeGoalSeconds: safeGoal,
        challengeDeadlineLabel: deadlineLabel.trim().isEmpty
            ? '今天 23:59'
            : deadlineLabel.trim(),
        challengeCompleted: total >= safeGoal,
      );
    }).toList();

    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
  }

  void setMyRoomPersonalGoal({
    required String roomId,
    required int goalSeconds,
  }) {
    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;

      final members = List<StudyMemberData>.from(room.members);
      final meIndex = members.indexWhere(
        (m) => m.memberId == _myId || m.memberId == 'local_user',
      );

      if (meIndex != -1) {
        final current = members[meIndex];
        final safeGoal = goalSeconds <= 0 ? 60 * 60 : goalSeconds;

        members[meIndex] = current.copyWith(
          personalGoalSeconds: safeGoal,
          hasReachedPersonalGoal: current.todayFocusSeconds >= safeGoal,
        );
      }

      return room.copyWith(members: members);
    }).toList();

    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
  }

  double getMemberContributionRatio({
    required String roomId,
    required String memberName,
  }) {
    final room = getStudyRoomById(roomId);
    if (room == null) return 0;

    final total = room.members.fold<int>(
      0,
      (acc, member) => acc + (member.isApproved ? member.todayFocusSeconds : 0),
    );

    if (total <= 0) return 0;

    final member = room.members.firstWhere(
      (m) => m.name == memberName,
      orElse: () => const StudyMemberData(
        memberId: '',
        name: '',
        roomNickname: '',
        status: StudyMemberStatus.offline,
        sessionSeconds: 0,
        todayFocusSeconds: 0,
        avatarColor: Color(0xFF7C6AE6),
      ),
    );

    return member.todayFocusSeconds / total;
  }

  Future<String> askAICoach() async {
    final user = _currentUser;
    if (user == null) {
      return '請先登入以使用 AI 智能自律導師。';
    }

    try {
      // Collect last 7 summaries
      final recentSummaries = _dailySummaries.length > 7
          ? _dailySummaries.sublist(_dailySummaries.length - 7)
          : _dailySummaries;

      final summaryBuf = StringBuffer();
      for (final s in recentSummaries) {
        summaryBuf.writeln(
          '- 日期: ${s.date}, 分數: ${s.disciplineScore}/100, 步數: ${s.steps}, 睡眠: ${s.sleepHours}小時, 專注時間: ${s.focusMinutes}分鐘, 運動: ${s.exerciseMinutes}分鐘, 完成任務數: ${s.completedTasks}/${s.totalTasks}',
        );
      }

      final prompt =
          '''
你是一位溫和且專業的「Nudge 自律導師」。請分析以下使用者過去 7 天的真實自律數據，尋找「行為盲點」與「數據關聯性」（例如：步數偏低是否影響了睡眠？專注時間和睡眠時間是否有負相關？任務完成率跟哪些因素有關？）。

使用者過去 7 天的每日自律數據：
${summaryBuf.toString()}

請務必以繁體中文 (Traditional Chinese, zh-Hant) 回覆，並格式化為以下結構：
### 📊 本週自律綜合分析
[請在此寫入 2-3 句本週整體狀態評估]

### 🔍 隱藏行為盲點剖析
- **[盲點主題 1，例如：運動與專注的關係]**：[具體說明發現的關聯，例：「當你當天走路低於 3,000 步，晚上專注力通常會下滑 30%...」]
- **[盲點主題 2，例如：睡眠對隔天任務完成率的影響]**：[說明數據關聯，例：「前一晚睡眠少於 6 小時，隔天的任務完成率會降低 25%...」]

### 💡 下週微調行動建議 (Nudge)
1. **[微行動 1]**：[具體且容易執行的精準建議]
2. **[微行動 2]**：[具體且容易執行的精準建議]
3. **[微行動 3]**：[具體且容易執行的精準建議]
''';

      final googleAI = FirebaseAI.googleAI();
      final model = googleAI.generativeModel(model: 'gemini-flash-latest');

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'AI 導師目前無回應，請稍後再試。';
    } catch (e) {
      debugPrint('Error calling Gemini: $e');
      return 'AI 導師連線失敗，請確認你的網路，或請先執行 `npx firebase-tools init ailogic` 初始化 AI 服務！\n詳細錯誤：$e';
    }
  }

  bool validateActivityLegitimacy(
    String type,
    double deltaValue,
    Duration deltaTime,
  ) {
    if (deltaTime.inSeconds <= 0) {
      return true; // prevent division by zero or errors
    }

    if (type == 'steps') {
      final stepsPerSecond = deltaValue / deltaTime.inSeconds;
      if (stepsPerSecond > 6.0) {
        debugPrint(
          'Security warning: Step count velocity of $stepsPerSecond steps/sec exceeds human limits.',
        );
        return false;
      }
    }

    if (type == 'focus') {
      final elapsedSeconds = deltaValue;
      if (elapsedSeconds > deltaTime.inSeconds + 10) {
        debugPrint(
          'Security warning: Focus session elapsed seconds ($elapsedSeconds) exceeds actual elapsed time (${deltaTime.inSeconds} sec).',
        );
        return false;
      }
    }

    return true;
  }

  bool addSecureFocusSeconds(
    int seconds,
    DateTime startTime,
    DateTime endTime,
  ) {
    final realDuration = endTime.difference(startTime);
    if (!validateActivityLegitimacy(
      'focus',
      seconds.toDouble(),
      realDuration,
    )) {
      return false;
    }
    addFocusSeconds(seconds);
    return true;
  }

  Future<void> joinVoiceRoom(String roomId) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('calls')
          .doc(user.id)
          .set({
            'memberId': user.id,
            'name': _profileNickname,
            'isVoiceActive': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Failed to join voice room: $e');
    }
  }

  Future<void> leaveVoiceRoom(String roomId) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('calls')
          .doc(user.id)
          .delete();
    } catch (e) {
      debugPrint('Failed to leave voice room: $e');
    }
  }

  Future<void> sendVoiceSdp(
    String roomId,
    String targetMemberId,
    String sdpType,
    String sdpDescription,
  ) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('calls')
          .doc(targetMemberId)
          .collection('sdpExchange')
          .doc(user.id)
          .set({
            'senderId': user.id,
            'type': sdpType,
            'sdp': sdpDescription,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Failed to send voice SDP: $e');
    }
  }

  Future<void> sendVoiceIceCandidate(
    String roomId,
    String targetMemberId,
    Map<String, dynamic> candidate,
  ) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('calls')
          .doc(targetMemberId)
          .collection('candidates')
          .add({
            'senderId': user.id,
            'candidate': candidate,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Failed to send voice ICE Candidate: $e');
    }
  }

  /// 接受家長共同目標後，自動將目標名稱匯入為每日任務
  Future<void> acceptParentGoalAsTask() async {
    final link = _familyLink;
    final familyGoal = activeFamilyGoal;
    if (link != null &&
        _currentUser?.id == link.childId &&
        familyGoal != null &&
        familyGoal['status'] == 'proposed') {
      final goalId = familyGoal['id'] as String?;
      final goal = familyGoal['title']?.toString() ?? '';
      if (goalId == null || goal.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('family_links')
          .doc(link.id)
          .collection('goals')
          .doc(goalId)
          .update({
            'status': 'accepted',
            'acceptedAt': DateTime.now().toUtc().toIso8601String(),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
      addTask('【家庭共同目標】$goal', '學習', taskType: 'flexible', priority: '高');
      return;
    }
  }

  Future<void> declineFamilyGoal(String goalId) async {
    final link = _familyLink;
    if (link == null || _currentUser?.id != link.childId) return;
    await FirebaseFirestore.instance
        .collection('family_links')
        .doc(link.id)
        .collection('goals')
        .doc(goalId)
        .update({
          'status': 'declined',
          'declinedAt': DateTime.now().toUtc().toIso8601String(),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
  }

  Future<void> completeFamilyGoal(String goalId) async {
    final link = _familyLink;
    final user = _currentUser;
    if (link == null || user == null || user.id != link.childId) return;
    final firestore = FirebaseFirestore.instance;
    final goalRef = firestore
        .collection('family_links')
        .doc(link.id)
        .collection('goals')
        .doc(goalId);
    final eventRef = firestore
        .collection('family_links')
        .doc(link.id)
        .collection('bond_events')
        .doc('goal_$goalId');
    await firestore.runTransaction((transaction) async {
      final goal = await transaction.get(goalRef);
      if (!goal.exists || goal.data()?['status'] != 'accepted') return;
      final now = DateTime.now().toUtc().toIso8601String();
      transaction.update(goalRef, {
        'status': 'completed',
        'completedAt': now,
        'updatedAt': now,
      });
      transaction.set(eventRef, {
        'schemaVersion': 1,
        'type': 'goalCompleted',
        'sourceId': goalId,
        'actorId': user.id,
        'points': FamilyBondPolicy.pointsFor(FamilyBondEvent.goalCompleted),
        'createdAt': now,
      });
    });
  }

  Future<void> acknowledgeFamilyEncouragement(String cardId) async {
    final link = _familyLink;
    final user = _currentUser;
    if (link == null || user == null || user.id != link.childId) return;
    final firestore = FirebaseFirestore.instance;
    final cardRef = firestore
        .collection('family_links')
        .doc(link.id)
        .collection('encouragements')
        .doc(cardId);
    final eventRef = firestore
        .collection('family_links')
        .doc(link.id)
        .collection('bond_events')
        .doc('encouragement_$cardId');
    await firestore.runTransaction((transaction) async {
      final card = await transaction.get(cardRef);
      if (!card.exists || card.data()?['status'] == 'acknowledged') return;
      final now = DateTime.now().toUtc().toIso8601String();
      transaction.update(cardRef, {
        'status': 'acknowledged',
        'acknowledgedAt': now,
      });
      transaction.set(eventRef, {
        'schemaVersion': 1,
        'type': 'acknowledgement',
        'sourceId': cardId,
        'actorId': user.id,
        'points': FamilyBondPolicy.pointsFor(FamilyBondEvent.acknowledgement),
        'createdAt': now,
      });
    });
  }

  Future<void> updateFamilyConsent(FamilyConsentScopes consent) async {
    final link = _familyLink;
    final user = _currentUser;
    if (link == null || user == null || user.id != link.childId) return;
    final firestore = FirebaseFirestore.instance;
    final linkRef = firestore.collection('family_links').doc(link.id);
    final summaryRef = linkRef.collection('summaries').doc('current');
    final batch = firestore.batch();
    final updatedAt = DateTime.now().toUtc().toIso8601String();

    batch.update(linkRef, {
      'consentScopes': consent.toMap(),
      'updatedAt': updatedAt,
    });
    batch.set(
      summaryRef,
      _buildFamilySummaryPayload(childId: user.id, consent: consent)
        ..['updatedAt'] = updatedAt,
    );
    await batch.commit();
  }

  void _ensureCurrentGroupChallengeTasks() {
    final challenge = _groupChallengePublication;
    final participation = currentGroupChallengeParticipation;
    final user = _currentUser;
    if (challenge == null ||
        participation == null ||
        user == null ||
        participation['status'] == 'completed') {
      return;
    }
    final challengeId = challenge['challengeId']?.toString() ?? '';
    final days = (challenge['days'] as num?)?.toInt() ?? 0;
    if (challengeId.isEmpty || days < 1) return;
    final missing = GroupChallengeTaskPlan.missingTasks(
      challengeId: challengeId,
      groupName: challenge['groupName']?.toString() ?? groupName ?? '自律團體',
      type: challenge['type']?.toString() ?? '自律挑戰',
      days: days,
      existingTasks: _tasks,
      now: DateTime.now(),
      userId: user.id,
    );
    if (missing.isEmpty) return;
    _tasks.addAll(missing);
    _syncTaskRewards();
    _syncTodaySummary();
    notifyListeners();
    _saveTasks();
  }

  Future<void> _syncCurrentGroupChallengeProgress() async {
    final challenge = _groupChallengePublication;
    final participation = currentGroupChallengeParticipation;
    final group = _canonicalGroup;
    final user = _currentUser;
    if (challenge == null ||
        participation == null ||
        group == null ||
        user == null ||
        participation['status'] == 'completed') {
      return;
    }
    final challengeId = challenge['challengeId']?.toString() ?? '';
    if (challengeId.isEmpty) return;
    final completedDays = GroupChallengeTaskPlan.completedDays(
      challengeId: challengeId,
      tasks: _tasks,
    );
    if ((participation['completedDays'] as num?)?.toInt() == completedDays) {
      return;
    }
    final payload = GroupChallengeParticipationContract.buildProgress(
      group: group,
      challenge: challenge,
      existing: participation,
      memberId: user.id,
      completedDays: completedDays,
      now: DateTime.now(),
    );
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(group.id)
        .collection('challenges')
        .doc('current')
        .collection('participants')
        .doc(user.id)
        .set(payload);
  }

  void _scheduleCurrentGroupChallengeProgressSync() {
    if (_groupChallengeProgressSyncInFlight) {
      _groupChallengeProgressSyncQueued = true;
      return;
    }
    _groupChallengeProgressSyncInFlight = true;
    unawaited(() async {
      try {
        do {
          _groupChallengeProgressSyncQueued = false;
          try {
            await _syncCurrentGroupChallengeProgress();
          } catch (error) {
            debugPrint('Failed to sync group challenge progress: $error');
          }
        } while (_groupChallengeProgressSyncQueued);
      } finally {
        _groupChallengeProgressSyncInFlight = false;
      }
    }());
  }

  /// 成員自行加入目前挑戰；參與紀錄在雲端，任務匯入具冪等性。
  Future<void> joinGroupChallengeAsTask() async {
    final challenge = _groupChallengePublication;
    final group = _canonicalGroup;
    final user = _currentUser;
    if (challenge == null || group == null || user == null) {
      throw StateError('請先加入有效團體並等待挑戰同步');
    }
    final existing = currentGroupChallengeParticipation;
    if (existing == null) {
      final payload = GroupChallengeParticipationContract.buildJoined(
        group: group,
        challenge: challenge,
        memberId: user.id,
        now: DateTime.now(),
      );
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(group.id)
          .collection('challenges')
          .doc('current')
          .collection('participants')
          .doc(user.id)
          .set(payload);
      _groupChallengeParticipations = [
        ..._groupChallengeParticipations.where(
          (item) => item['memberId'] != user.id,
        ),
        {'id': user.id, ...payload},
      ];
    }
    _ensureCurrentGroupChallengeTasks();
  }

  Future<void> removeGuardian() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.id);
      final link = _familyLink;
      if (link != null) {
        final batch = FirebaseFirestore.instance.batch();
        final now = DateTime.now().toUtc().toIso8601String();
        batch.update(
          FirebaseFirestore.instance.collection('family_links').doc(link.id),
          {
            'status': 'ended',
            'endedBy': user.id,
            'endedAt': now,
            'updatedAt': now,
          },
        );
        batch.update(
          FirebaseFirestore.instance
              .collection('guardian_requests')
              .doc(link.id),
          {'status': 'ended', 'updatedAt': now},
        );
        for (final participantId in link.participantIds) {
          final membership = RelationshipMembership.fromFamilyLink(
            link: link,
            userId: participantId,
          ).copyWith(status: RelationshipMembershipStatus.ended);
          batch.set(
            FirebaseFirestore.instance
                .collection('relationship_memberships')
                .doc(membership.id),
            membership.toFirestoreMap(
              now: DateTime.parse(now),
              endedBy: user.id,
            ),
            SetOptions(merge: true),
          );
        }
        batch.update(docRef, {
          'webToolsState.guardianInvite': FieldValue.delete(),
          'webToolsState.guardianInviteStatus': FieldValue.delete(),
        });
        await batch.commit();
        notifyListeners();
        return;
      }

      await docRef.update({
        'webToolsState.guardianInvite': FieldValue.delete(),
        'webToolsState.guardianInviteStatus': FieldValue.delete(),
      });

      // Clean up any pending/accepted requests in the collection
      final reqs1 = await FirebaseFirestore.instance
          .collection('guardian_requests')
          .where('senderId', isEqualTo: user.id)
          .get();
      for (final doc in reqs1.docs) {
        await doc.reference.delete();
      }
      final reqs2 = await FirebaseFirestore.instance
          .collection('guardian_requests')
          .where('receiverId', isEqualTo: user.id)
          .get();
      for (final doc in reqs2.docs) {
        await doc.reference.delete();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to remove guardian: $e');
    }
  }

  Future<void> saveTimeCapsule(
    String title,
    String date,
    String message,
  ) async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.id);
      final newCapsule = {
        'title': title,
        'meta': '$date 解鎖',
        'message': message,
        'createdAt': DateTime.now().toIso8601String(),
      };
      final updatedCapsules = [newCapsule, ...timeCapsules];
      await docRef.update({
        'webToolsCollection.capsules': updatedCapsules,
        'webToolsCollection.capsulesUpdatedAt': DateTime.now()
            .toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to save time capsule: $e');
    }
  }

  Future<void> deleteTimeCapsule(int index) async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.id);
      final list = [...timeCapsules];
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        await docRef.update({
          'webToolsCollection.capsules': list,
          'webToolsCollection.capsulesUpdatedAt': DateTime.now()
              .toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Failed to delete time capsule: $e');
    }
  }

  Future<void> saveFutureLetter(
    String state,
    String action,
    String note,
  ) async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.id);
      await docRef.update({
        'webToolsState.futureLetter': {
          'state': state,
          'action': action,
          'note': note,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      debugPrint('Failed to save future letter: $e');
    }
  }

  Future<String> chatWithAICoach(
    String userMessage,
    List<Map<String, dynamic>> chatHistory,
  ) async {
    final user = _currentUser;
    if (user == null) {
      return '請先登入以使用 AI 智能自律導師。';
    }

    try {
      // 1. Gather stats
      final score = todayWeightedDisciplineScore;
      final completed = todayActionableTaskCompleted;
      final total = todayActionableTaskTotal;
      final focusMin = focusMinutes;
      final sleepHr = sleepHours;
      final stepCount = steps;
      final activeRole = userRole;

      // 2. Format today's tasks
      final taskListString = _tasks
          .map((t) {
            final title = t['title'] ?? '無標題';
            final category = t['category'] ?? '其他';
            final type = t['taskType'] ?? 'fixed';
            final isDone = t['done'] == true ? '已完成' : '未完成';
            return '- [$isDone] $title ($category, $type)';
          })
          .join('\n');

      // 3. Format history
      final historyBuffer = StringBuffer();
      for (final msg in chatHistory) {
        final roleName = msg['isUser'] == true ? '使用者' : 'AI導師';
        historyBuffer.writeln('$roleName: ${msg['text']}');
      }

      // 4. Build prompt
      final prompt =
          '''
你是一位溫和、專業且極具同理心的「Nudge AI 自律導師」。使用者目前正在跟你對話，請根據以下提供的使用者「今日實時自律數據」與「對話歷史紀錄」，提供最合適的回覆。

【使用者今日自律數據】
- 目前角色身份模式: $activeRole
- 加權自律分數: $score 分 / 100
- 每日任務進度: $completed/$total (完成/總計)
- 今日專注時數: $focusMin 分鐘
- 今日健康數據: 睡眠 $sleepHr 小時, 步數 $stepCount 步
- 今日任務列表:
$taskListString

【對話歷史紀錄】
${historyBuffer.toString()}

【使用者最新訊息】
使用者: $userMessage

【回覆指南】
1. 請以繁體中文 (Traditional Chinese, zh-Hant) 回覆。
2. 請維持 Nudge 自律導師的風格：溫柔堅定、溫馨陪伴、注重微調行動（Nudge）而非強加高壓計畫。
3. 如果使用者要求「診斷我今天的自律數據」，請結合上面的分數、健康與任務完成情況，給出 2 句話的盲點剖析與一個極為具體的「微行動建議」。
4. 回覆請盡量精煉，避免過長的冗長鋪陳，排版清晰美觀，合適地使用 Emoji。
''';

      final googleAI = FirebaseAI.googleAI();
      final model = googleAI.generativeModel(model: 'gemini-flash-latest');

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'AI 導師目前無回應，請稍後再試。';
    } catch (e) {
      debugPrint('Error calling Gemini: $e');
      return 'AI 導師連線失敗，請確認您的網路！\n詳細錯誤：$e';
    }
  }

  void importExamTemplate(
    String type,
    int days,
    String effort,
    String strategy,
  ) {
    for (int d = 1; d <= days; d++) {
      String title = '';
      if (d == 1) {
        title = '[$type第$d天] 整理目標與資料';
      } else if (d == (days / 2).ceil()) {
        title = '[$type第$d天] 完成主要進度 ($effort)';
      } else if (d == days) {
        title = '[$type第$d天] 回顧、補強與提交';
      } else {
        title = '[$type第$d天] 執行進度 ($strategy)';
      }
      addTask(title, '讀書', taskType: 'fixed', priority: '高');
    }
  }

  Future<void> setUserRole(String role) async {
    _userRole = role;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role_setting', role);
    final user = _currentUser;
    if (user != null) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.id);
        await docRef.update({
          'userRole': role,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _syncPublicProfile();
      } catch (e) {
        debugPrint('Failed to update user role in Firestore: $e');
      }
    }
  }

  Future<void> sendParentEncouragementCard(String title, String message) async {
    final user = _currentUser;
    final link = _familyLink;
    if (user == null || link == null || user.id != link.guardianId) {
      throw StateError('請先以家長身分建立有效的家庭連結');
    }
    final payload = FamilyLinkContract.buildEncouragementPayload(
      guardianId: link.guardianId,
      childId: link.childId,
      title: title,
      message: message,
      now: DateTime.now(),
    );
    await FirebaseFirestore.instance
        .collection('family_links')
        .doc(link.id)
        .collection('encouragements')
        .add(payload);
  }

  Future<void> sendParentSharedGoal(String goal, String message) async {
    final user = _currentUser;
    final link = _familyLink;
    if (user == null || link == null || user.id != link.guardianId) {
      throw StateError('請先以家長身分建立有效的家庭連結');
    }
    final payload = FamilyLinkContract.buildSharedGoalPayload(
      guardianId: link.guardianId,
      childId: link.childId,
      title: goal,
      message: message,
      now: DateTime.now(),
    );
    await FirebaseFirestore.instance
        .collection('family_links')
        .doc(link.id)
        .collection('goals')
        .add(payload);
  }

  Future<void> publishGroupChallenge(
    String type,
    int days,
    String reward,
  ) async {
    final user = _currentUser;
    final group = _canonicalGroup;
    if (user == null || group == null) {
      throw StateError('請先加入有效團體');
    }
    final now = DateTime.now();
    final payload = GroupPublicationContract.buildChallenge(
      group: group,
      publisherId: user.id,
      challengeId: 'challenge_${now.toUtc().microsecondsSinceEpoch}',
      type: type,
      days: days,
      reward: reward,
      now: now,
    );
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(group.id)
        .collection('challenges')
        .doc('current')
        .set(payload);
  }

  Future<void> publishStudySchedule(String title, String meta) async {
    final user = _currentUser;
    final group = _canonicalGroup;
    if (user == null || group == null) {
      throw StateError('請先加入有效團體');
    }
    final payload = GroupPublicationContract.buildStudySchedule(
      group: group,
      publisherId: user.id,
      title: title,
      meta: meta,
      now: DateTime.now(),
    );
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(group.id)
        .collection('study_schedules')
        .add(payload);
  }

  Future<void> publishExamTemplate(
    String type,
    int days,
    String effort,
    String strategy,
  ) async {
    final user = _currentUser;
    final group = _canonicalGroup;
    if (user == null || group == null) {
      throw StateError('請先加入有效團體');
    }
    final payload = GroupPublicationContract.buildTemplate(
      group: group,
      publisherId: user.id,
      type: type,
      days: days,
      effort: effort,
      strategy: strategy,
      now: DateTime.now(),
    );
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(group.id)
        .collection('templates')
        .add(payload);
  }

  Future<void> setGroupResultSharing(bool enabled) async {
    final group = _canonicalGroup;
    final user = _currentUser;
    if (group == null || user == null || !group.isMember(user.id)) {
      throw StateError('請先加入有效團體');
    }
    final summaryRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(group.id)
        .collection('member_summaries')
        .doc(user.id);
    _groupResultSummaryPublishTimer?.cancel();
    _groupResultSummaryPublishTimer = null;

    if (!enabled) {
      await summaryRef.delete();
      _groupResultSharingEnabled = false;
      _groupMemberSummaries = _groupMemberSummaries
          .where((summary) => summary.memberId != user.id)
          .toList(growable: false);
      notifyListeners();
      return;
    }

    final payload = GroupResultSummaryContract.buildPayload(
      group: group,
      memberId: user.id,
      displayName: _profileNickname,
      disciplineScore: todayWeightedDisciplineScore,
      completedTasks: todayActionableTaskCompleted,
      totalTasks: todayActionableTaskTotal,
      focusMinutes: focusMinutes,
      steps: steps,
      sleepHours: sleepHours,
      now: DateTime.now(),
    );
    await summaryRef.set(payload);
    _groupResultSharingEnabled = true;
    notifyListeners();
  }

  Future<void> refreshGroupResultSummary() async {
    if (!_groupResultSharingEnabled) {
      throw StateError('請先開啟團體成果分享');
    }
    await _publishGroupResultSummarySnapshot();
  }

  Future<void> removeGroupMember(String memberId) async {
    final user = _currentUser;
    final group = _canonicalGroup;
    if (user == null || group == null || !group.isManager(user.id)) {
      throw StateError('只有目前團體管理者可以移除成員');
    }
    final firestore = FirebaseFirestore.instance;
    final groupRef = firestore.collection('groups').doc(group.id);
    final summaryRef = groupRef.collection('member_summaries').doc(memberId);
    final participationRef = groupRef
        .collection('challenges')
        .doc('current')
        .collection('participants')
        .doc(memberId);
    await firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) {
        throw StateError('團體資料不存在');
      }
      final currentGroup = GroupContract.fromMap(
        groupSnapshot.id,
        groupSnapshot.data()!,
      );
      final update = GroupMembershipContract.buildMemberRemoval(
        group: currentGroup,
        managerId: user.id,
        memberId: memberId,
        now: DateTime.now(),
      );
      final endedMembership = RelationshipMembership.fromGroup(
        group: currentGroup,
        userId: memberId,
      ).copyWith(status: RelationshipMembershipStatus.ended);
      transaction.update(groupRef, update);
      transaction.set(
        firestore
            .collection('relationship_memberships')
            .doc(endedMembership.id),
        endedMembership.toFirestoreMap(now: DateTime.now(), endedBy: user.id),
        SetOptions(merge: true),
      );
      transaction.delete(summaryRef);
      transaction.delete(participationRef);
    });
  }

  Future<void> transferGroupOwnership(String nextManagerId) async {
    final user = _currentUser;
    final group = _canonicalGroup;
    if (user == null || group == null || !group.isManager(user.id)) {
      throw StateError('只有目前團體管理者可以轉移管理權');
    }
    final firestore = FirebaseFirestore.instance;
    final groupRef = firestore.collection('groups').doc(group.id);
    await firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) {
        throw StateError('團體資料不存在');
      }
      final currentGroup = GroupContract.fromMap(
        groupSnapshot.id,
        groupSnapshot.data()!,
      );
      final update = GroupMembershipContract.buildOwnershipTransfer(
        group: currentGroup,
        managerId: user.id,
        nextManagerId: nextManagerId,
        now: DateTime.now(),
      );
      final currentManagerMembership = RelationshipMembership.fromGroup(
        group: currentGroup,
        userId: user.id,
      ).copyWith(role: RelationshipRole.member);
      final nextManagerMembership = RelationshipMembership.fromGroup(
        group: currentGroup,
        userId: nextManagerId,
      ).copyWith(role: RelationshipRole.manager);
      transaction.update(groupRef, update);
      transaction.set(
        firestore
            .collection('relationship_memberships')
            .doc(currentManagerMembership.id),
        currentManagerMembership.toFirestoreMap(now: DateTime.now()),
        SetOptions(merge: true),
      );
      transaction.set(
        firestore
            .collection('relationship_memberships')
            .doc(nextManagerMembership.id),
        nextManagerMembership.toFirestoreMap(now: DateTime.now()),
        SetOptions(merge: true),
      );
    });
  }

  /// 進行家長/小孩帳號雙向連結綁定
  Future<void> bindRelative(String relativeId) async {
    await sendGuardianRequest(relativeId);
  }

  /// 發送親屬綁定申請
  Future<void> sendGuardianRequest(String targetNudgeId) async {
    final user = _currentUser;
    if (user == null) return;
    final targetNudgeIdUpper = targetNudgeId.trim().toUpperCase();
    if (targetNudgeIdUpper.isEmpty) {
      throw Exception('Nudge ID 不能為空');
    }
    if (targetNudgeIdUpper == _myNudgeId.toUpperCase()) {
      throw Exception('不能與自己進行親屬綁定');
    }
    try {
      // Find the user by username
      final querySnap = await FirebaseFirestore.instance
          .collection('public_profiles')
          .where('username', isEqualTo: targetNudgeIdUpper)
          .limit(1)
          .get();
      if (querySnap.docs.isEmpty) {
        throw Exception('找不到該 Nudge ID 的使用者');
      }
      final receiverId = querySnap.docs.first.id;
      final receiverData = querySnap.docs.first.data();
      final receiverNudgeId = receiverData['username'] as String? ?? '';
      final receiverRole = receiverData['familyRole'] as String? ?? 'personal';

      FamilyLinkContract.fromAcceptedRequest(
        linkId: 'validation',
        senderId: user.id,
        senderRole: _userRole,
        receiverId: receiverId,
        receiverRole: receiverRole,
        now: DateTime.now(),
      );

      if (_familyLinks.any(
        (link) => link.participantIds.contains(receiverId),
      )) {
        throw Exception('你們已經有有效的家庭連結');
      }

      // Check if there is already a pending request between us (outgoing)
      final outgoingCheck = await FirebaseFirestore.instance
          .collection('guardian_requests')
          .where('senderId', isEqualTo: user.id)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (outgoingCheck.docs.isNotEmpty) {
        throw Exception('已發送過綁定申請，請耐心等待對方同意');
      }

      // Check if there is a pending request from them to us (incoming)
      final incomingCheck = await FirebaseFirestore.instance
          .collection('guardian_requests')
          .where('senderId', isEqualTo: receiverId)
          .where('receiverId', isEqualTo: user.id)
          .where('status', isEqualTo: 'pending')
          .get();
      if (incomingCheck.docs.isNotEmpty) {
        // Auto-approve!
        await approveGuardianRequest(incomingCheck.docs.first.id);
        return;
      }

      // Create request doc
      await FirebaseFirestore.instance.collection('guardian_requests').add({
        'senderId': user.id,
        'senderNudgeId': _myNudgeId,
        'senderNickname': user.nickname,
        'senderRole': _userRole,
        'receiverId': receiverId,
        'receiverNudgeId': receiverNudgeId,
        'receiverRole': receiverRole,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to send guardian request: $e');
      rethrow;
    }
  }

  /// 同意綁定申請
  Future<void> approveGuardianRequest(String requestId) async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final requestRef = firestore
          .collection('guardian_requests')
          .doc(requestId);
      final linkRef = firestore.collection('family_links').doc(requestId);
      await firestore.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(requestRef);
        if (!requestSnapshot.exists) {
          throw StateError('找不到親屬綁定申請');
        }
        final request = requestSnapshot.data()!;
        if (request['receiverId'] != user.id) {
          throw StateError('只有邀請接收者可以同意連結');
        }

        final contract = FamilyLinkContract.fromAcceptedRequest(
          linkId: requestId,
          senderId: request['senderId'] as String,
          senderRole: request['senderRole'] as String? ?? 'personal',
          receiverId: request['receiverId'] as String,
          receiverRole: request['receiverRole'] as String? ?? _userRole,
          now: DateTime.now(),
        );
        transaction.update(requestRef, {
          'status': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(linkRef, contract.toMap());
        for (final participantId in contract.participantIds) {
          final membership = RelationshipMembership.fromFamilyLink(
            link: contract,
            userId: participantId,
          );
          transaction.set(
            firestore.collection('relationship_memberships').doc(membership.id),
            membership.toFirestoreMap(now: DateTime.now()),
          );
        }
      });
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to approve guardian request: $e');
      rethrow;
    }
  }

  /// 拒絕綁定申請
  Future<void> declineGuardianRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('guardian_requests')
          .doc(requestId)
          .update({
            'status': 'declined',
            'updatedAt': FieldValue.serverTimestamp(),
          });
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to decline guardian request: $e');
      rethrow;
    }
  }

  Future<void> approveGroupRequest(Map<String, dynamic> request) async {
    final requestId = request['id'] as String?;
    final requestedGroupId = request['groupId'] as String?;
    if (requestId == null || requestedGroupId == null) {
      throw StateError('團體邀請資料不完整');
    }
    await joinGroup(requestedGroupId, requestId: requestId);
  }

  Future<void> declineGroupRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('group_requests')
        .doc(requestId)
        .update({
          'status': 'declined',
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _migrateLegacyGroupProjection(
    String ownerId,
    String legacyGroupId,
    String legacyGroupName,
  ) async {
    if (!_checkedLegacyGroupIds.add(legacyGroupId)) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final groupRef = firestore.collection('groups').doc(legacyGroupId);
      final groupSnapshot = await groupRef.get();
      if (groupSnapshot.exists) return;
      final group = GroupContract(
        id: legacyGroupId,
        name: legacyGroupName,
        ownerId: ownerId,
        memberIds: {ownerId},
        status: GroupStatus.active,
      );
      final membership = RelationshipMembership.fromGroup(
        group: group,
        userId: ownerId,
      );
      final batch = firestore.batch();
      batch.set(groupRef, {
        'id': legacyGroupId,
        'name': legacyGroupName,
        'ownerId': ownerId,
        'memberIds': [ownerId],
        'status': 'active',
        'migratedFromUserProjection': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        firestore.collection('relationship_memberships').doc(membership.id),
        membership.toFirestoreMap(now: DateTime.now()),
      );
      await batch.commit();
    } catch (error) {
      _checkedLegacyGroupIds.remove(legacyGroupId);
      debugPrint('Failed to migrate legacy group: $error');
    }
  }

  Future<void> _ensureCanonicalGroupMembership(
    String userId,
    String existingGroupId,
  ) async {
    try {
      final groupRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(existingGroupId);
      final groupSnapshot = await groupRef.get();
      if (!groupSnapshot.exists ||
          groupSnapshot.data()?['status'] != 'active') {
        return;
      }
      final memberIds = List<String>.from(
        groupSnapshot.data()?['memberIds'] as List? ?? const [],
      );
      final group = GroupContract.fromMap(
        groupSnapshot.id,
        groupSnapshot.data()!,
      );
      final membership = RelationshipMembership.fromGroup(
        group: group.memberIds.contains(userId)
            ? group
            : GroupContract(
                id: group.id,
                name: group.name,
                ownerId: group.ownerId,
                memberIds: {...group.memberIds, userId},
                status: group.status,
              ),
        userId: userId,
      );
      final batch = FirebaseFirestore.instance.batch();
      if (!memberIds.contains(userId)) {
        batch.update(groupRef, {
          'memberIds': FieldValue.arrayUnion([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.set(
        FirebaseFirestore.instance
            .collection('relationship_memberships')
            .doc(membership.id),
        membership.toFirestoreMap(now: DateTime.now()),
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (error) {
      debugPrint('Failed to repair group membership: $error');
    }
  }

  /// 創建新團體 (房主身份，生成唯一團體 ID)
  Future<void> createGroup(String name) async {
    final user = _currentUser;
    if (user == null) throw StateError('請先登入再建立團體');
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('團體名稱不可空白');

    final randomId =
        'GRP-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final firestore = FirebaseFirestore.instance;
    final groupRef = firestore.collection('groups').doc(randomId);
    final membership = RelationshipMembership.fromGroup(
      group: GroupContract(
        id: randomId,
        name: normalizedName,
        ownerId: user.id,
        memberIds: {user.id},
        status: GroupStatus.active,
      ),
      userId: user.id,
    );
    final batch = firestore.batch();
    batch.set(groupRef, {
      'id': randomId,
      'name': normalizedName,
      'ownerId': user.id,
      'memberIds': [user.id],
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      firestore.collection('relationship_memberships').doc(membership.id),
      membership.toFirestoreMap(now: DateTime.now()),
    );
    await batch.commit();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _relationshipSelectionKey('group', user.id),
      randomId,
    );
    _selectedGroupId = randomId;
    _groupId = randomId;
    _groupName = normalizedName;
    notifyListeners();
  }

  /// 加入已有的團體 (成員身份)
  Future<void> joinGroup(String groupIdInput, {String? requestId}) async {
    final user = _currentUser;
    if (user == null) throw StateError('請先登入再加入團體');
    final normalizedId = groupIdInput.trim().toUpperCase();
    if (normalizedId.isEmpty) throw ArgumentError('團體 ID 不可空白');

    final firestore = FirebaseFirestore.instance;
    final groupRef = firestore.collection('groups').doc(normalizedId);
    late String remoteGroupName;
    await firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) throw StateError('找不到此團體 ID');
      final data = groupSnapshot.data() ?? const <String, dynamic>{};
      if (data['status'] != 'active') throw StateError('此團體目前無法加入');
      remoteGroupName = (data['name'] as String?)?.trim() ?? '';
      if (remoteGroupName.isEmpty) throw StateError('團體資料不完整');
      final ownerId = (data['ownerId'] as String?)?.trim() ?? '';
      if (ownerId.isEmpty) throw StateError('團體管理者資料不完整');
      final joinedGroup = GroupContract(
        id: normalizedId,
        name: remoteGroupName,
        ownerId: ownerId,
        memberIds: {
          ...List<String>.from(data['memberIds'] as List? ?? const []),
          user.id,
        },
        status: GroupStatus.active,
      );
      final membership = RelationshipMembership.fromGroup(
        group: joinedGroup,
        userId: user.id,
      );
      transaction.update(groupRef, {
        'memberIds': FieldValue.arrayUnion([user.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        firestore.collection('relationship_memberships').doc(membership.id),
        membership.toFirestoreMap(now: DateTime.now()),
        SetOptions(merge: true),
      );
      if (requestId != null) {
        transaction.update(
          firestore.collection('group_requests').doc(requestId),
          {'status': 'accepted', 'updatedAt': FieldValue.serverTimestamp()},
        );
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _relationshipSelectionKey('group', user.id),
      normalizedId,
    );
    _selectedGroupId = normalizedId;
    _groupId = normalizedId;
    _groupName = remoteGroupName;
    notifyListeners();
  }

  /// 退出或解散當前團體
  Future<void> leaveGroup() async {
    final user = _currentUser;
    final currentGroup = _canonicalGroup;
    if (user == null) throw StateError('請先登入');
    if (currentGroup == null) return;
    final currentGroupId = currentGroup.id;
    final remainingGroups = _canonicalGroups
        .where((group) => group.id != currentGroupId)
        .toList(growable: false);
    final fallbackGroup = remainingGroups.isEmpty
        ? null
        : remainingGroups.first;

    final firestore = FirebaseFirestore.instance;
    final groupRef = firestore.collection('groups').doc(currentGroupId);
    final summaryRef = groupRef.collection('member_summaries').doc(user.id);
    final participationRef = groupRef
        .collection('challenges')
        .doc('current')
        .collection('participants')
        .doc(user.id);
    await firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (groupSnapshot.exists) {
        final data = groupSnapshot.data() ?? const <String, dynamic>{};
        final ownerId = data['ownerId'] as String?;
        final memberIds = List<String>.from(
          data['memberIds'] as List? ?? const [],
        );
        if (ownerId == user.id && memberIds.length > 1) {
          throw StateError('團體仍有其他成員，請先移除成員或轉移管理權');
        }
        if (ownerId == user.id) {
          transaction.delete(groupRef);
        } else {
          transaction.update(groupRef, {
            'memberIds': FieldValue.arrayRemove([user.id]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        final membership = RelationshipMembership.fromGroup(
          group: GroupContract.fromMap(groupSnapshot.id, data),
          userId: user.id,
        ).copyWith(status: RelationshipMembershipStatus.ended);
        transaction.set(
          firestore.collection('relationship_memberships').doc(membership.id),
          membership.toFirestoreMap(now: DateTime.now(), endedBy: user.id),
          SetOptions(merge: true),
        );
      }
      transaction.delete(summaryRef);
      transaction.delete(participationRef);
    });

    final prefs = await SharedPreferences.getInstance();
    if (fallbackGroup == null) {
      await prefs.remove(_relationshipSelectionKey('group', user.id));
    } else {
      await prefs.setString(
        _relationshipSelectionKey('group', user.id),
        fallbackGroup.id,
      );
    }

    _selectedGroupId = fallbackGroup?.id;
    _groupId = fallbackGroup?.id;
    _groupName = fallbackGroup?.name;
    notifyListeners();
  }
}
