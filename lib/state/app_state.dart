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
import '../models/badge_record.dart';
import '../models/daily_summary.dart';
import '../models/friend_request.dart';
import '../models/social_encouragement_record.dart';
import '../models/social_friend_profile.dart';
import '../models/study_room_models.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
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
  AppState() {
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
  StreamSubscription? _shopSubscription;

  /// The current user's Firestore uid, falling back to 'local_user' when
  /// the user is not signed in (guest mode / offline).
  String get _myId => _currentUser?.id ?? 'local_user';

  void _listenToAuthChanges() {
    try {
      fb_auth.FirebaseAuth.instance.authStateChanges().listen((fb_auth.User? user) async {
        if (user != null) {
          _isGuestMode = false;
          await _syncProfileFromFirebaseUser(user);
          _setupFirestoreListeners(user);
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

  void _setupFirestoreListeners(fb_auth.User user) {
    _cancelFirestoreListeners();

    // User profile listener
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((docSnap) {
      if (docSnap.exists) {
        final data = docSnap.data()!;
        _currentUser = UserModel.fromJson(data);
        _profileNickname = _currentUser!.nickname;
        _profileSignature = _currentUser!.signature;
        _myNudgeId = _currentUser!.username;
        _themeModeSetting = _currentUser!.themeMode;
        _iconColorSetting = _currentUser!.accentColor;
        _disciplineCoins = data['disciplineCoins'] as int? ?? _disciplineCoins;
        if (data['avatarProfile'] != null) {
          _avatarProfile = AvatarProfile.fromJson(Map<String, dynamic>.from(data['avatarProfile'] as Map));
        }
        if (data['unlockedAvatarItems'] != null) {
          _unlockedAvatarItemKeys = Set<String>.from(List<String>.from(data['unlockedAvatarItems']));
        }
        if (data['unlockedBadgeDates'] != null) {
          _unlockedBadgeDates = Map<String, String>.from(data['unlockedBadgeDates'] as Map);
        }
        if (data['tasks'] != null) {
          _tasks = List<Map<String, dynamic>>.from(
            (data['tasks'] as List).map((t) => Map<String, dynamic>.from(t as Map)),
          );
        }
        if (data['dailySummaries'] != null) {
          _dailySummaries = List<DailySummary>.from(
            (data['dailySummaries'] as List).map((s) => DailySummary.fromJson(Map<String, dynamic>.from(s as Map))),
          );
        }
        notifyListeners();
      }
    });

    // Friends listener
    _friendsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .snapshots()
        .listen((snapshot) {
      _socialFriends = snapshot.docs.map((doc) => SocialFriendProfile.fromJson(doc.data())).toList();
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
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
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
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
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
      _mergeFirestoreRooms(snapshot.docs);
    });

    // Shop items listener (dynamic characters)
    _shopSubscription = FirebaseFirestore.instance
        .collection('shop_items')
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] == 'event_character') {
          final name = data['name'] as String? ?? '未命名角色';
          final price = data['price'] as int? ?? 60;
          final imagePath = data['image_path'] as String? ?? '';
          
          final dynamicIndex = 18 + (name.hashCode.abs() % 1000);
          
          final stage = AvatarEvolutionStage(
            index: dynamicIndex,
            series: '活動限定角色',
            name: name,
            stage: 1,
            requiredLevel: 1,
            requiredExperience: 0,
            description: 'Web 端上架的活動限時角色。',
            characterAsset: imagePath,
            iconAsset: imagePath,
            coinPrice: price,
          );
          
          AvatarCatalog.addDynamicStage(stage);
        }
      }
      notifyListeners();
    });
  }

  /// Merges Firestore room documents into the local _studyRooms list.
  /// Local-only rooms (id starts with 'room_demo_') are kept as-is.
  void _mergeFirestoreRooms(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final remoteRooms = docs.map((doc) {
      final data = doc.data();
      return StudyRoomData.fromJson(data);
    }).toList();

    // Keep any demo/local-only rooms that aren't in Firestore.
    final demoRooms = _studyRooms.where((r) => r.id.startsWith('room_demo_')).toList();

    // Merge: remote rooms replace local copies (preserving local data for unlisted rooms).
    final remoteIds = remoteRooms.map((r) => r.id).toSet();
    final localOnlyRooms = _studyRooms.where((r) => !remoteIds.contains(r.id) && !r.id.startsWith('room_demo_')).toList();

    _studyRooms = [...remoteRooms, ...localOnlyRooms, ...demoRooms];
    _syncMyFocusSecondsAcrossRooms();
    _syncStudyRoomGoalTasks();
    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    _syncTodaySummary();
    notifyListeners();
  }

  void _cancelFirestoreListeners() {
    _userSubscription?.cancel();
    _friendsSubscription?.cancel();
    _incomingRequestsSubscription?.cancel();
    _outgoingRequestsSubscription?.cancel();
    _roomsSubscription?.cancel();
    _shopSubscription?.cancel();
    _userSubscription = null;
    _friendsSubscription = null;
    _incomingRequestsSubscription = null;
    _outgoingRequestsSubscription = null;
    _roomsSubscription = null;
    _shopSubscription = null;
  }

  Future<void> _syncProfileFromFirebaseUser(fb_auth.User user) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        _currentUser = UserModel.fromJson(data);
        _profileNickname = _currentUser!.nickname;
        _profileSignature = _currentUser!.signature;
        _myNudgeId = _currentUser!.username;
        await pullDataFromFirestore();
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

  Future<void> syncDataToFirestore() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.id);
      await docRef.set({
        'nickname': _profileNickname,
        'signature': _profileSignature,
        'myNudgeId': _myNudgeId,
        'themeMode': _themeModeSetting,
        'accentColor': _iconColorSetting,
        'disciplineCoins': _disciplineCoins,
        'planetCount': _planetCount,
        'weeklyPlanetEarned': _weeklyPlanetEarned,
        'avatarProfile': _avatarProfile.toJson(),
        'unlockedAvatarItems': _unlockedAvatarItemKeys.toList(),
        'tasks': _tasks,
        'dailySummaries': _dailySummaries.map((s) => s.toJson()).toList(),
        'unlockedBadgeDates': _unlockedBadgeDates,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to sync to Firestore: $e');
    }
  }

  Future<void> pullDataFromFirestore() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.id);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        if (data['tasks'] != null) {
          _tasks = List<Map<String, dynamic>>.from(
            (data['tasks'] as List).map((t) => Map<String, dynamic>.from(t)),
          );
        }
        _disciplineCoins = data['disciplineCoins'] as int? ?? _disciplineCoins;
        _planetCount = data['planetCount'] as int? ?? _planetCount;
        _weeklyPlanetEarned = data['weeklyPlanetEarned'] as bool? ?? _weeklyPlanetEarned;
        if (data['avatarProfile'] != null) {
          _avatarProfile = AvatarProfile.fromJson(Map<String, dynamic>.from(data['avatarProfile']));
        }
        if (data['unlockedAvatarItems'] != null) {
          _unlockedAvatarItemKeys = Set<String>.from(List<String>.from(data['unlockedAvatarItems']));
        }
        if (data['unlockedBadgeDates'] != null) {
          _unlockedBadgeDates = Map<String, String>.from(data['unlockedBadgeDates']);
        }
        if (data['dailySummaries'] != null) {
          _dailySummaries = List<DailySummary>.from(
            (data['dailySummaries'] as List).map((s) => DailySummary.fromJson(Map<String, dynamic>.from(s))),
          );
        }
        _profileNickname = data['nickname'] as String? ?? _profileNickname;
        _profileSignature = data['signature'] as String? ?? _profileSignature;
        _myNudgeId = data['myNudgeId'] as String? ?? _myNudgeId;
        _themeModeSetting = data['themeMode'] as String? ?? _themeModeSetting;
        _iconColorSetting = data['accentColor'] as String? ?? _iconColorSetting;
        notifyListeners();

        // Also save locally so that it matches
        await _saveAppearanceSettings();
        await _saveTasks();
        await _saveDailySummaries();
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
      'category': '讀書',
      'taskType': 'fixed',
      'dueDate': null,
      'priority': '高',
    },
    {
      'title': '步行超過 6000 步',
      'done': false,
      'category': '運動',
      'taskType': 'fixed',
      'dueDate': null,
      'priority': '中',
    },
    {
      'title': '運動 30 分鐘',
      'done': false,
      'category': '運動',
      'taskType': 'fixed',
      'dueDate': null,
      'priority': '中',
    },
    {
      'title': '晚上 11:30 前睡覺',
      'done': false,
      'category': '睡眠',
      'taskType': 'fixed',
      'dueDate': null,
      'priority': '高',
    },
    {
      'title': '準備期中報告',
      'done': false,
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
  static const String _weeklyPlanetEarnedKey = 'weekly_planet_earned_setting';
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
  DateTime? _lastHealthSyncTime;
  int _lastStepsCount = 0;
  List<DailySummary> _dailySummaries = [];
  int _disciplineCoins = 0;
  int _planetCount = 0;
  bool _weeklyPlanetEarned = false;
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

  List<Map<String, dynamic>> get tasks => _tasks;
  int get focusSeconds => _focusSeconds;
  int get focusMinutes => _focusSeconds ~/ 60;
  double get sleepHours => _sleepHours;
  int get steps => _steps;
  int get exerciseMinutes => _exerciseMinutes;
  bool get isHealthConnected => _isHealthConnected;
  List<DailySummary> get dailySummaries => _dailySummaries;
  DailySummary get todaySummary => _buildTodayExperienceSummary();
  int get disciplineCoins => _disciplineCoins;
  int get planetCount => _planetCount;
  bool get weeklyPlanetEarned => _weeklyPlanetEarned;
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
    switch (_currentUser?.authProvider) {
      case 'email':
        return 'Email';
      case 'google':
        return 'Google';
      case 'apple':
        return 'Apple';
      default:
        return '尚未登入';
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

  double _autoTrackedValueForTask(Map<String, dynamic> task) {
    final sourceType = _readTaskSourceType(task);
    final sourceId = task['sourceId'] as String?;

    if (sourceId != null && sourceId.isNotEmpty) {
      final room = getStudyRoomById(sourceId);
      if (room != null) {
        final me = room.members.where((m) => m.memberId == _myId || m.memberId == 'local_user');
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
      final meIndex = members.indexWhere((m) => m.memberId == _myId || m.memberId == 'local_user');
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

      if (wasDone == reached) return task;

      return {
        ...task,
        'done': reached,
        'updatedAt': now,
        'completedAt': reached ? now : null,
      };
    }).toList();
  }

  String _scoreMilestoneRewardKey(int threshold) {
    return '${_todayKey()}|score:$threshold';
  }

  double _taskRewardWeight(Map<String, dynamic> task) {
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
      _unlockCurrentAvatarProfile();
      _unlockAllAvatarItemsForPreview();
      await _saveAvatarUnlockState();
      _syncTodaySummary();
      _isHydrated = true;
      notifyListeners();
      await _rescheduleLocalReminders();
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
      _unlockCurrentAvatarProfile();
      _unlockAllAvatarItemsForPreview();
      await _saveAvatarUnlockState();
      _syncTodaySummary();
      _isHydrated = true;
      notifyListeners();
      await _rescheduleLocalReminders();
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
      faceShapeIndex: _clampAvatarIndex(
        _avatarProfile.faceShapeIndex,
        AvatarCatalog.faceShapeLabels.length,
      ),
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
      avatarIconIndex: _clampAvatarIndex(
        _avatarProfile.avatarIconIndex,
        AvatarCatalog.evolutionStages.length,
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
    _planetCount = prefs.getInt(_planetCountKey) ?? 0;
    _weeklyPlanetEarned = prefs.getBool(_weeklyPlanetEarnedKey) ?? false;
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
    await prefs.setBool(_weeklyPlanetEarnedKey, _weeklyPlanetEarned);
    await prefs.setStringList(_rewardedTaskKeysKey, _rewardedTaskKeys.toList());
    await prefs.setString(_dailyCoinEarnedKey, jsonEncode(_dailyCoinEarned));
    await prefs.setString(
      _monthlyDeadlineCoinEarnedKey,
      jsonEncode(_monthlyDeadlineCoinEarned),
    );
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
      final decoded = jsonDecode(raw) as Map;
      _avatarExperienceLedger = decoded.map((date, value) {
        final rawSeries = value is Map ? value : const <String, dynamic>{};
        final seriesMap = rawSeries.map(
          (series, experience) =>
              MapEntry(series.toString(), (experience as num?)?.round() ?? 0),
        )..removeWhere((_, experience) => experience <= 0);
        return MapEntry(date.toString(), seriesMap);
      })..removeWhere((_, seriesMap) => seriesMap.isEmpty);
    } catch (_) {
      _avatarExperienceLedger = <String, Map<String, int>>{};
      _migrateLegacyAvatarExperienceLedger();
      await _saveAvatarExperienceLedger();
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

    final batch = FirebaseFirestore.instance.batch();
    for (final room in _studyRooms) {
      // Only skip rooms that are purely demo/local placeholders
      if (room.id.startsWith('room_demo_')) continue;

      final data = room.toJson();
      // Add the memberIds array so we can query rooms by member
      final memberIds = room.members
          .where((m) => m.isApproved)
          .map((m) => (m.memberId == _myId || m.memberId == 'local_user') ? user.id : m.memberId)
          .where((id) => id.isNotEmpty && id != 'local_user')
          .toSet()
          .toList();
      // Always include the current user
      if (!memberIds.contains(user.id)) memberIds.add(user.id);
      data['memberIds'] = memberIds;
      data['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = FirebaseFirestore.instance.collection('rooms').doc(room.id);
      batch.set(docRef, data, SetOptions(merge: true));
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
        debugPrint('Failed to load rooms from Firestore, falling back to local: $e');
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
    return _formatDate(DateTime.now());
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

  Future<void> _checkAndPerformDailyResetIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastResetDate = prefs.getString(_lastDailyResetDateKey);

    if (lastResetDate == null) {
      await prefs.setString(_lastDailyResetDateKey, today);
      return;
    }

    if (lastResetDate == today) {
      return;
    }

    _resetDailyTasks();
    _resetDailyFocusAndStudyRooms();
    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    _syncTodaySummary();

    await _saveTasks();
    await _saveFocusTime();
    await _saveHealthData();
    await _saveStudyRooms();
    await _saveDailySummaries();
    await prefs.setString(_lastDailyResetDateKey, today);
  }

  void _resetDailyTasks() {
    _tasks = _tasks.map((task) {
      final taskType = (task['taskType'] ?? 'fixed') as String;

      if (taskType == 'fixed') {
        return {
          ...task,
          'done': false,
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
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    final credential = await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    if (credential.user != null) {
      await _syncProfileFromFirebaseUser(credential.user!);
    }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password, String nickname) async {
    final credential = await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
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
      final userCredential =
          await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
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
      final userCredential =
          await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);

      // Apple only provides name on first sign-in
      final displayName =
          '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
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
      final fb_auth.OAuthCredential credential =
          fb_auth.FacebookAuthProvider.credential(result.accessToken!.tokenString);
      final userCredential =
          await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
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
      final userCredential =
          await fb_auth.FirebaseAuth.instance.signInWithProvider(provider);
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
  }

  Future<void> updateAvatarIconIndex(int index) async {
    if (!isAvatarIconUnlocked(index)) return;
    _avatarProfile = _avatarProfile.copyWith(avatarIconIndex: index);
    _normalizeAvatarProfileForCatalog();
    notifyListeners();
    await _saveAppearanceSettings();
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
          .collection('users')
          .where('username', isEqualTo: queryId)
          .limit(1)
          .get();

      if (querySnap.docs.isNotEmpty) {
        final data = querySnap.docs.first.data();
        final userModel = UserModel.fromJson(data);

        AvatarProfile? avatarProfile;
        if (data['avatarProfile'] != null) {
          avatarProfile = AvatarProfile.fromJson(Map<String, dynamic>.from(data['avatarProfile'] as Map));
        }

        return SocialFriendProfile(
          id: userModel.id,
          nudgeId: userModel.username,
          name: userModel.nickname,
          signature: userModel.signature,
          todayFocusSeconds: data['focusSeconds'] as int? ?? 0,
          isStudying: data['isStudying'] as bool? ?? false,
          avatarColor: const Color(0xFF7C6AE6),
          avatarProfile: avatarProfile,
          isFollowing: false,
          encouragementCount: 0,
        );
      }
    } catch (e) {
      debugPrint('Failed to query user by Nudge ID: $e');
    }

    return findFriendCandidateByNudgeId(queryId);
  }

  SocialFriendProfile? findFriendCandidateByNudgeId(String rawId) {
    final nudgeId = rawId.trim().toUpperCase();
    if (nudgeId.isEmpty || nudgeId == _myNudgeId) return null;

    final existing = _socialFriends.where(
      (friend) => friend.nudgeId.toUpperCase() == nudgeId,
    );
    if (existing.isNotEmpty) return existing.first;

    final mockCandidates = [
      SocialFriendProfile(
        id: 'candidate_mina',
        nudgeId: 'NDG-MINA01',
        name: '小米',
        signature: '想找人一起讀書',
        todayFocusSeconds: 0,
        isStudying: false,
        avatarColor: const Color(0xFF8B5CF6),
        avatarProfile: avatarVariantForSeed(801),
        isFollowing: false,
        encouragementCount: 0,
      ),
      SocialFriendProfile(
        id: 'candidate_ray',
        nudgeId: 'NDG-RAY777',
        name: '阿睿',
        signature: '最近在挑戰每天運動',
        todayFocusSeconds: 35 * 60,
        isStudying: false,
        avatarColor: const Color(0xFF10B981),
        avatarProfile: avatarVariantForSeed(777),
        isFollowing: false,
        encouragementCount: 0,
      ),
    ];

    final match = mockCandidates.where(
      (candidate) => candidate.nudgeId.toUpperCase() == nudgeId,
    );
    return match.isEmpty ? null : match.first;
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

    final name = (uri.queryParameters['name'] ?? '').trim();
    final signature = (uri.queryParameters['signature'] ?? '').trim();

    return SocialFriendProfile(
      id: 'candidate_${nudgeId.toLowerCase().replaceAll('-', '_')}',
      nudgeId: nudgeId,
      name: name.isEmpty ? 'Nudge 好友' : name,
      signature: signature.isEmpty ? '想和你一起自律前進' : signature,
      todayFocusSeconds: 0,
      isStudying: false,
      avatarColor: const Color(0xFF4F8CFF),
      avatarProfile: avatarVariantForSeed(nudgeId.hashCode),
      isFollowing: false,
      encouragementCount: 0,
    );
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
    final docRef = FirebaseFirestore.instance.collection('friend_requests').doc(reqId);

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
      final docRef = FirebaseFirestore.instance.collection('friend_requests').doc(requestId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        final senderId = data['senderId'] as String? ?? '';
        final senderNudgeId = data['senderNudgeId'] as String? ?? '';
        final senderName = data['senderName'] as String? ?? '';
        final senderSignature = data['senderSignature'] as String? ?? '';

        await docRef.update({'status': 'accepted'});

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

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('friends')
            .doc(senderId)
            .set(myFriendProfile.toJson());

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

        await FirebaseFirestore.instance
            .collection('users')
            .doc(senderId)
            .collection('friends')
            .doc(user.id)
            .set(otherFriendProfile.toJson());
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
    _socialFriends = _socialFriends.where((f) => f.id != id).toList();
    _socialEncouragementRecords = _socialEncouragementRecords
        .where((record) => record.toFriendId != id)
        .toList();

    notifyListeners();
    await _saveSocialFriends();
    await _saveSocialEncouragementRecords();

    final user = _currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('friends')
            .doc(id)
            .delete();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .collection('friends')
            .doc(user.id)
            .delete();
      } catch (e) {
        debugPrint('Failed to delete friend from Firestore: $e');
      }
    }
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
    if (index < 0 || index >= _tasks.length) return;
    final task = _tasks[index];
    final isDeadlineTask = task['taskType'] == 'deadline';
    final wasDone = task['done'] as bool? ?? false;

    if (value && isDeadlineTask && !_isDeadlineTaskReady(task)) {
      return;
    }

    _tasks[index]['done'] = value;
    _tasks[index]['updatedAt'] = DateTime.now().toIso8601String();
    _tasks[index]['completedAt'] = value
        ? DateTime.now().toIso8601String()
        : null;
    if (value && !wasDone && isDeadlineTask) {
      _awardDeadlineTaskBonus(_tasks[index]);
    }
    _syncTaskRewards();
    _syncTodaySummary();
    notifyListeners();
    _saveTasks();
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
      'category': category,
      'taskType': taskType,
      'dueDate': taskType == 'fixed' ? null : dueDate,
      'priority': priority,
      'isSystemTask': false,
      'isAutoTracked': isAutoTracked,
      'sourceType': sourceType?.name,
      'targetValue': targetValue,
      'unitLabel': unitLabel,
      'sourceId': null,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
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

    final oldDone = _tasks[index]['done'] as bool? ?? false;

    _tasks[index] = {
      ..._tasks[index],
      'title': title,
      'done': oldDone,
      'category': category,
      'taskType': taskType,
      'dueDate': taskType == 'fixed' ? null : dueDate,
      'priority': priority,
      'isAutoTracked':
          isAutoTracked ?? (_tasks[index]['isAutoTracked'] ?? false),
      'sourceType': sourceType?.name ?? _tasks[index]['sourceType'],
      'targetValue': targetValue ?? _tasks[index]['targetValue'],
      'unitLabel': unitLabel ?? _tasks[index]['unitLabel'],
      'updatedAt': DateTime.now().toIso8601String(),
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
  }) {
    final now = DateTime.now();
    if (_lastHealthSyncTime != null && steps > _lastStepsCount) {
      final deltaSteps = steps - _lastStepsCount;
      final deltaTime = now.difference(_lastHealthSyncTime!);
      if (!validateActivityLegitimacy('steps', deltaSteps.toDouble(), deltaTime)) {
        debugPrint('Steps synchronization rejected due to velocity check.');
        return; 
      }
    }
    _lastHealthSyncTime = now;
    _lastStepsCount = steps;

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
      final meIndex = members.indexWhere((m) => m.memberId == _myId || m.memberId == 'local_user');

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

  void removeMemberFromRoom({
    required String roomId,
    required String memberName,
  }) {
    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      if (memberName == room.ownerName || memberName == _profileNickname) {
        return room;
      }

      final updatedMembers = room.members
          .where((m) => m.name != memberName)
          .toList();

      return room.copyWith(members: updatedMembers);
    }).toList();

    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
  }

  void approveStudyRoomJoinRequest({
    required String roomId,
    required String memberId,
  }) {
    final now = DateTime.now();
    StudyMemberData? approvedMember;

    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId || (room.ownerId != _myId && room.ownerId != 'local_user')) return room;
      final approvedCount = room.members
          .where((member) => member.isApproved)
          .length;
      if (approvedCount >= room.memberLimit) return room;

      final members = room.members.map((member) {
        if (member.memberId != memberId || member.isApproved) return member;
        approvedMember = member.copyWith(isApproved: true);
        return approvedMember!;
      }).toList();

      if (approvedMember == null) return room;

      return room.copyWith(
        members: members,
        events: [
          StudyRoomEvent(
            id: 'event_${now.microsecondsSinceEpoch}',
            actorId: _myId,
            actorName: _profileNickname,
            text:
                '${approvedMember!.roomNickname.isEmpty ? approvedMember!.name : approvedMember!.roomNickname} 的加入申請已通過',
            type: StudyRoomEventType.system,
            createdAt: now,
          ),
          ...room.events,
        ].take(80).toList(),
      );
    }).toList();

    if (approvedMember == null) return;

    _syncStudyRoomGoalTasks();
    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
  }

  void rejectStudyRoomJoinRequest({
    required String roomId,
    required String memberId,
  }) {
    final now = DateTime.now();
    StudyMemberData? rejectedMember;

    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId || (room.ownerId != _myId && room.ownerId != 'local_user')) return room;

      for (final member in room.members) {
        if (member.memberId == memberId && !member.isApproved) {
          rejectedMember = member;
          break;
        }
      }

      if (rejectedMember == null) return room;

      final members = room.members
          .where((member) => member.memberId != memberId)
          .toList();

      return room.copyWith(
        members: members,
        events: [
          StudyRoomEvent(
            id: 'event_${now.microsecondsSinceEpoch}',
            actorId: _myId,
            actorName: _profileNickname,
            text:
                '${rejectedMember!.roomNickname.isEmpty ? rejectedMember!.name : rejectedMember!.roomNickname} 的加入申請已拒絕',
            type: StudyRoomEventType.system,
            createdAt: now,
          ),
          ...room.events,
        ].take(80).toList(),
      );
    }).toList();

    if (rejectedMember == null) return;

    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
  }

  void addStudyRoomMessage({
    required String roomId,
    required String text,
    StudyRoomMessageType type = StudyRoomMessageType.text,
    String senderId = 'local_user',
    String? senderName,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final message = StudyRoomMessage(
      id: 'message_${now.microsecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName ?? _profileNickname,
      text: trimmed,
      type: type,
      createdAt: now,
    );

    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      return room.copyWith(
        messages: [message, ...room.messages].take(60).toList(),
      );
    }).toList();

    notifyListeners();
    _saveStudyRooms();
  }

  void addStudyRoomEvent({
    required String roomId,
    required String text,
    StudyRoomEventType type = StudyRoomEventType.system,
    String actorId = 'local_user',
    String? actorName,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final event = StudyRoomEvent(
      id: 'event_${now.microsecondsSinceEpoch}',
      actorId: actorId,
      actorName: actorName ?? _profileNickname,
      text: trimmed,
      type: type,
      createdAt: now,
    );

    _studyRooms = _studyRooms.map((room) {
      if (room.id != roomId) return room;
      return room.copyWith(events: [event, ...room.events].take(80).toList());
    }).toList();

    notifyListeners();
    _saveStudyRooms();
  }

  void leaveStudyRoom(String roomId) {
    final room = getStudyRoomById(roomId);
    if (room == null) return;

    final remainingMembers = room.members
        .where((member) => member.memberId != _myId && member.memberId != 'local_user' && member.isApproved)
        .toList();

    if ((room.ownerId == _myId || room.ownerId == 'local_user') && remainingMembers.isEmpty) {
      _studyRooms = _studyRooms.where((item) => item.id != roomId).toList();
    } else {
      final nextOwner = (room.ownerId == _myId || room.ownerId == 'local_user')
          ? remainingMembers.first
          : null;

      _studyRooms = _studyRooms.map((item) {
        if (item.id != roomId) return item;

        final updatedMembers = nextOwner == null
            ? remainingMembers
            : remainingMembers.map((member) {
                if (member.memberId != nextOwner.memberId) return member;
                return member.copyWith(role: 'owner');
              }).toList();

        final now = DateTime.now();
        return item.copyWith(
          ownerId: nextOwner?.memberId ?? item.ownerId,
          ownerName: nextOwner == null
              ? item.ownerName
              : (nextOwner.roomNickname.isEmpty
                    ? nextOwner.name
                    : nextOwner.roomNickname),
          members: updatedMembers,
          events: [
            StudyRoomEvent(
              id: 'event_${now.microsecondsSinceEpoch}',
              actorId: _myId,
              actorName: _profileNickname,
              text: '$_profileNickname 退出了房間',
              type: StudyRoomEventType.leave,
              createdAt: now,
            ),
            ...item.events,
          ].take(80).toList(),
        );
      }).toList();
    }

    _removeStudyRoomGoalTask(roomId);
    _syncStudyGoalTaskCompletion();
    _syncAutoTrackedTasks();
    _syncTaskRewards();
    notifyListeners();
    _saveStudyRooms();
    _saveTasks();
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
    final resolvedOwnerId = (ownerId == null || ownerId.trim().isEmpty)
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

  void joinStudyRoomFromDiscovery({
    required StudyRoomData room,
    bool isApproved = true,
    String joinAnswer = '',
  }) {
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
    _saveStudyRooms();
    _saveTasks();
  }

  void updateMyStudyRoomPresence({
    required String roomId,
    required StudyMemberStatus status,
    required int sessionSeconds,
  }) {
    _studyRooms = _studyRooms.map((room) {
      final members = List<StudyMemberData>.from(room.members);
      final meIndex = members.indexWhere((m) => m.memberId == _myId || m.memberId == 'local_user');
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
      final meIndex = members.indexWhere((m) => m.memberId == _myId || m.memberId == 'local_user');

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
          '- 日期: ${s.date}, 分數: ${s.disciplineScore}/100, 步數: ${s.steps}, 睡眠: ${s.sleepHours}小時, 專注時間: ${s.focusMinutes}分鐘, 運動: ${s.exerciseMinutes}分鐘, 完成任務數: ${s.completedTasks}/${s.totalTasks}'
        );
      }

      final prompt = '''
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

      final googleAI = FirebaseAI.googleAI(auth: fb_auth.FirebaseAuth.instance);
      final model = googleAI.generativeModel(
        model: 'gemini-flash-latest',
      );

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'AI 導師目前無回應，請稍後再試。';
    } catch (e) {
      debugPrint('Error calling Gemini: $e');
      return 'AI 導師連線失敗，請確認你的網路，或請先執行 `npx firebase-tools init ailogic` 初始化 AI 服務！\n詳細錯誤：$e';
    }
  }

  bool validateActivityLegitimacy(String type, double deltaValue, Duration deltaTime) {
    if (deltaTime.inSeconds <= 0) return true; // prevent division by zero or errors
    
    if (type == 'steps') {
      final stepsPerSecond = deltaValue / deltaTime.inSeconds;
      if (stepsPerSecond > 6.0) {
        debugPrint('Security warning: Step count velocity of $stepsPerSecond steps/sec exceeds human limits.');
        return false;
      }
    }
    
    if (type == 'focus') {
      final elapsedSeconds = deltaValue;
      if (elapsedSeconds > deltaTime.inSeconds + 10) {
        debugPrint('Security warning: Focus session elapsed seconds ($elapsedSeconds) exceeds actual elapsed time (${deltaTime.inSeconds} sec).');
        return false;
      }
    }
    
    return true;
  }

  bool addSecureFocusSeconds(int seconds, DateTime startTime, DateTime endTime) {
    final realDuration = endTime.difference(startTime);
    if (!validateActivityLegitimacy('focus', seconds.toDouble(), realDuration)) {
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

  Future<void> sendVoiceSdp(String roomId, String targetMemberId, String sdpType, String sdpDescription) async {
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

  Future<void> sendVoiceIceCandidate(String roomId, String targetMemberId, Map<String, dynamic> candidate) async {
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
}
