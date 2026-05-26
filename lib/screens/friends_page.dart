import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_profile.dart';
import '../models/social_friend_profile.dart';
import '../models/study_room_models.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
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

  String _formatMMSS(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<FriendListItemData> _buildFriendsFromRooms(List<StudyRoomData> rooms) {
    final Map<String, FriendListItemData> merged = {};

    for (final room in rooms) {
      for (final member in room.members) {
        if (member.memberId == 'local_user' || member.name == '老闆') continue;

        final existing = merged[member.name];
        final derivedScore = (40 + (member.todayFocusSeconds / 60 / 2))
            .clamp(0, 100)
            .round();

        final title = switch (member.status) {
          StudyMemberStatus.studying => '正在專注中',
          StudyMemberStatus.resting => '剛休息一下',
          StudyMemberStatus.offline => '今天慢慢前進',
        };

        final data = FriendListItemData(
          id: member.memberId.isEmpty ? member.name : member.memberId,
          name: member.name,
          signature: title,
          score: derivedScore,
          todayFocusSeconds: member.todayFocusSeconds,
          avatarColor: member.avatarColor,
          avatarProfile: member.avatarProfile,
          roomId: room.id,
          roomName: room.name,
          roomNickname: member.roomNickname.isEmpty
              ? member.name
              : member.roomNickname,
          memberStatus: member.status,
        );

        if (existing == null) {
          merged[member.name] = data;
        } else if (data.todayFocusSeconds > existing.todayFocusSeconds) {
          merged[member.name] = data;
        }
      }
    }

    return merged.values.toList();
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

  Color _statusColor(StudyMemberStatus status) {
    switch (status) {
      case StudyMemberStatus.studying:
        return const Color(0xFF10B981);
      case StudyMemberStatus.resting:
        return const Color(0xFFF59E0B);
      case StudyMemberStatus.offline:
        return const Color(0xFF64748B);
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

    final roomFriends = _buildFriendsFromRooms(appState.studyRooms);
    final manualFriends = _buildManualFriends(appState.socialFriends);

    final allFriendsMap = <String, FriendListItemData>{};
    for (final friend in [...roomFriends, ...manualFriends]) {
      allFriendsMap[friend.id] = friend;
    }

    final friends = allFriendsMap.values.toList()
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
            ...filteredFriends.map((friend) {
              final statusColor = _statusColor(friend.memberStatus);
              final avatarProfile =
                  friend.avatarProfile ??
                  appState.avatarVariantForSeed(friend.id.hashCode);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  shape: AppUI.cardShape(),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppUI.radiusCard),
                    onTap: () => _openPublicProfile(
                      context,
                      friendId: friend.id,
                      name: friend.name,
                      signature: friend.signature,
                      todayFocusSeconds: friend.todayFocusSeconds,
                      score: friend.score,
                      isStudying:
                          friend.memberStatus == StudyMemberStatus.studying,
                      avatarColor: friend.avatarColor,
                      roomId: friend.roomId,
                      roomName: friend.roomName,
                      roomNickname: friend.roomNickname,
                      memberStatus: friend.memberStatus,
                      avatarProfile: avatarProfile,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppUI.innerPadding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              color: avatarProfile.backgroundColor,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: AvatarPreview(
                              profile: avatarProfile,
                              size: 66,
                              showBackgroundRing: false,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  friend.name,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  friend.signature,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _SmallTag(
                                      text: _statusText(friend.memberStatus),
                                      color: statusColor,
                                    ),
                                    if (friend.roomName != null &&
                                        friend.roomName!.isNotEmpty)
                                      _SmallTag(
                                        text: friend.roomName!,
                                        color: const Color(0xFF4F8CFF),
                                      ),
                                    _SmallTag(
                                      text:
                                          '今日 ${_formatMMSS(friend.todayFocusSeconds)}',
                                      color: const Color(0xFF7C6AE6),
                                    ),
                                    _SmallTag(
                                      text: '${friend.score} 分',
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: secondaryText),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

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

class _SmallTag extends StatelessWidget {
  final String text;
  final Color color;

  const _SmallTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppUI.softCardOf(context, color),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
