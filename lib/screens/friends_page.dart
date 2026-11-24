import 'package:flutter/material.dart';

import '../widgets/social_plaza_stage.dart';
import 'package:provider/provider.dart';

import '../models/avatar_profile.dart';
import '../models/social_friend_profile.dart';
import '../models/study_room_models.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../theme/game_ui.dart';
import '../widgets/avatar_preview.dart';
import 'add_friend_page.dart';
import 'friend_public_profile_page.dart';

enum SocialFriendFilter { all, studying, resting, offline, activeToday }

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  SocialFriendFilter _selectedFilter = SocialFriendFilter.all;
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FriendListItemData> _buildManualFriends(
    List<SocialFriendProfile> friends,
  ) {
    return friends
        .map(
          (f) => FriendListItemData(
            id: f.id,
            name: f.name,
            signature: f.signature,
            score: (35 + (f.todayFocusSeconds / 60 / 2)).clamp(0, 100).round(),
            todayFocusSeconds: f.todayFocusSeconds,
            avatarColor: f.avatarColor,
            avatarProfile: f.avatarProfile,
            roomId: null,
            roomName: null,
            roomNickname: f.name,
            memberStatus: f.isStudying
                ? StudyMemberStatus.studying
                : (f.todayFocusSeconds > 0
                      ? StudyMemberStatus.resting
                      : StudyMemberStatus.offline),
          ),
        )
        .toList();
  }

  List<FriendListItemData> _applyFilters(List<FriendListItemData> friends) {
    final keyword = _searchText.trim().toLowerCase();

    return friends.where((friend) {
      final matchesSearch =
          keyword.isEmpty ||
          friend.name.toLowerCase().contains(keyword) ||
          friend.signature.toLowerCase().contains(keyword) ||
          (friend.roomName?.toLowerCase().contains(keyword) ?? false);

      if (!matchesSearch) return false;

      switch (_selectedFilter) {
        case SocialFriendFilter.all:
          return true;
        case SocialFriendFilter.studying:
          return friend.memberStatus == StudyMemberStatus.studying;
        case SocialFriendFilter.resting:
          return friend.memberStatus == StudyMemberStatus.resting;
        case SocialFriendFilter.offline:
          return friend.memberStatus == StudyMemberStatus.offline;
        case SocialFriendFilter.activeToday:
          return friend.todayFocusSeconds > 0;
      }
    }).toList();
  }

  String _filterLabel(SocialFriendFilter filter) {
    switch (filter) {
      case SocialFriendFilter.all:
        return '全部';
      case SocialFriendFilter.studying:
        return '專注中';
      case SocialFriendFilter.resting:
        return '休息中';
      case SocialFriendFilter.offline:
        return '離線';
      case SocialFriendFilter.activeToday:
        return '今日活躍';
    }
  }

  String _statusText(StudyMemberStatus status) {
    switch (status) {
      case StudyMemberStatus.studying:
        return '專注中';
      case StudyMemberStatus.resting:
        return '休息中';
      case StudyMemberStatus.offline:
        return '離線';
    }
  }

  void _openAddFriendPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFriendPage()),
    );
  }

  void _openPublicProfile(
    BuildContext context, {
    required String friendId,
    required String name,
    required String signature,
    required int todayFocusSeconds,
    required int score,
    required bool isStudying,
    required Color avatarColor,
    required String? roomId,
    required String? roomName,
    required String roomNickname,
    required StudyMemberStatus memberStatus,
    bool isCurrentUser = false,
    AvatarProfile? avatarProfile,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendPublicProfilePage(
          friendId: friendId,
          name: name,
          signature: signature,
          todayFocusSeconds: todayFocusSeconds,
          score: score,
          isStudying: isStudying,
          avatarColor: avatarColor,
          isCurrentUser: isCurrentUser,
          avatarProfile: avatarProfile,
          roomId: roomId,
          roomName: roomName,
          roomNickname: roomNickname,
          memberStatus: memberStatus,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    final friends = _buildManualFriends(appState.socialFriends)
      ..sort((a, b) => b.todayFocusSeconds.compareTo(a.todayFocusSeconds));

    final filteredFriends = _applyFilters(friends);
    final studyingCount = friends
        .where((f) => f.memberStatus == StudyMemberStatus.studying)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('好友列表')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _openAddFriendPage(context),
        backgroundColor: accentColor.withValues(alpha: 0.82),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('加入好友'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          const SocialPlazaStage(title: '好友長椅'),
          const SizedBox(height: AppUI.sectionGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: AppUI.softCardOf(context, accentColor),
                    child: Icon(Icons.group_outlined, color: accentColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${friends.length} 位好友',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '目前有 $studyingCount 位好友正在專注，好友卡會同步顯示角色穿搭與公開頁狀態。',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppUI.sectionGap),

          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchText = value;
              });
            },
            decoration: InputDecoration(
              hintText: '搜尋好友、簽名或房間',
              prefixIcon: const Icon(Icons.search_outlined),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SocialFriendFilter.values.map((filter) {
              return ChoiceChip(
                label: Text(_filterLabel(filter)),
                selected: _selectedFilter == filter,
                onSelected: (_) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: AppUI.sectionGap),

          if (filteredFriends.isEmpty)
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.group_off_outlined,
                      size: 40,
                      color: secondaryText,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '目前沒有符合條件的好友',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '你可以調整篩選條件，或直接加入新的好友。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final palette = GamePalette.of(context);
                final columns = constraints.maxWidth >= 540 ? 3 : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: filteredFriends.map((friend) {
                    final avatar =
                        friend.avatarProfile ??
                        appState.avatarVariantForSeed(friend.id.hashCode);
                    return SizedBox(
                      width: width,
                      child: Semantics(
                        button: true,
                        label:
                            '${friend.name}，${_statusText(friend.memberStatus)}',
                        child: InkWell(
                          onTap: () => _openPublicProfile(
                            context,
                            friendId: friend.id,
                            name: friend.name,
                            signature: friend.signature,
                            todayFocusSeconds: friend.todayFocusSeconds,
                            score: friend.score,
                            isStudying:
                                friend.memberStatus ==
                                StudyMemberStatus.studying,
                            avatarColor: friend.avatarColor,
                            roomId: friend.roomId,
                            roomName: friend.roomName,
                            roomNickname: friend.roomNickname,
                            memberStatus: friend.memberStatus,
                            avatarProfile: avatar,
                          ),
                          child: Column(
                            children: [
                              AvatarPreview(
                                profile: avatar,
                                size: 64,
                                showBackgroundRing: false,
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: palette.wood,
                                  border: Border.all(
                                    color: palette.panelBorder,
                                    width: 2,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  child: Text(
                                    friend.name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: GamePalette.dark.ink,
                                      fontFamily: 'Cubic11',
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                _statusText(friend.memberStatus),
                                style: TextStyle(
                                  color: palette.ink,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

          const SizedBox(height: 84),
        ],
      ),
    );
  }
}

class FriendListItemData {
  final String id;
  final String name;
  final String signature;
  final int score;
  final int todayFocusSeconds;
  final Color avatarColor;
  final AvatarProfile? avatarProfile;
  final String? roomId;
  final String? roomName;
  final String roomNickname;
  final StudyMemberStatus memberStatus;

  const FriendListItemData({
    required this.id,
    required this.name,
    required this.signature,
    required this.score,
    required this.todayFocusSeconds,
    required this.avatarColor,
    this.avatarProfile,
    required this.roomId,
    required this.roomName,
    required this.roomNickname,
    required this.memberStatus,
  });
}
