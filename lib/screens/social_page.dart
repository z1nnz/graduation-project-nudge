import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_profile.dart';
import '../models/social_friend_profile.dart';
import '../models/study_room_models.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_icon_preview.dart';
import '../widgets/avatar_preview.dart';
import 'add_friend_page.dart';
import 'encouragement_page.dart';
import 'friend_public_profile_page.dart';
import 'friends_page.dart';
import 'leaderboard_page.dart';
import 'my_profile_page.dart';
import 'study_room_list_page.dart';

class SocialPage extends StatelessWidget {
  const SocialPage({super.key});

  int _calculateMyScore(AppState appState) {
    return appState.todayWeightedDisciplineScore;
  }

  List<FriendData> _buildFriendsFromRooms(
    List<StudyRoomData> rooms,
    AppState appState,
  ) {
    final Map<String, FriendData> merged = {};

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

        final roomName = room.name;

        final data = FriendData(
          id: member.memberId.isEmpty ? member.name : member.memberId,
          name: member.name,
          title: title,
          score: derivedScore,
          todayFocusSeconds: member.todayFocusSeconds,
          isStudying: member.status == StudyMemberStatus.studying,
          avatarColor: member.avatarColor,
          avatarProfile:
              member.avatarProfile ??
              appState.avatarVariantForSeed(member.memberId.hashCode),
          roomId: room.id,
          roomName: roomName,
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

  List<FriendData> _buildManualFriends(
    List<SocialFriendProfile> friends,
    AppState appState,
  ) {
    return friends
        .map(
          (f) => FriendData(
            id: f.id,
            name: f.name,
            title: f.signature,
            score: (35 + (f.todayFocusSeconds / 60 / 2)).clamp(0, 100).round(),
            todayFocusSeconds: f.todayFocusSeconds,
            isStudying: f.isStudying,
            avatarColor: f.avatarColor,
            avatarProfile:
                f.avatarProfile ?? appState.avatarVariantForSeed(f.id.hashCode),
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

  void _openAddFriendPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFriendPage()),
    );
  }

  void _openMyProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyProfilePage()),
    );
  }

  void _openFriendsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FriendsPage()),
    );
  }

  void _openStudyRooms(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudyRoomListPage()),
    );
  }

  void _openLeaderboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeaderboardPage()),
    );
  }

  void _openEncouragement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EncouragementPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    final myScore = _calculateMyScore(appState);
    final myFocusSeconds = appState.focusSeconds;
    final myCompletedTasks = appState.todayActionableTaskCompleted;
    final myTotalTasks = appState.todayActionableTaskTotal;

    final myNickname = appState.profileNickname;
    final mySignature = appState.profileSignature;
    final myTitle = appState.profileTitle;
    final myAvatar = appState.avatarProfile;
    final myAvatarIconIndex = appState.currentAvatarIconIndex;

    final roomFriends = _buildFriendsFromRooms(appState.studyRooms, appState);
    final manualFriends = _buildManualFriends(appState.socialFriends, appState);

    final allFriendsMap = <String, FriendData>{};
    for (final friend in [...roomFriends, ...manualFriends]) {
      allFriendsMap[friend.id] = friend;
    }
    final friends = allFriendsMap.values.toList();

    final studyingFriends = friends.where((f) => f.isStudying).toList()
      ..sort((a, b) => b.todayFocusSeconds.compareTo(a.todayFocusSeconds));

    final previewStudying = studyingFriends.take(3).toList();

    final leaderboard =
        [
          FriendData(
            id: 'me',
            name: myNickname,
            title: mySignature,
            score: myScore,
            todayFocusSeconds: myFocusSeconds,
            isStudying: myFocusSeconds > 0,
            avatarColor: accentColor,
            avatarProfile: myAvatar,
            roomId: null,
            roomName: null,
            roomNickname: myNickname,
            memberStatus: myFocusSeconds > 0
                ? StudyMemberStatus.studying
                : StudyMemberStatus.offline,
            isCurrentUser: true,
          ),
          ...friends,
        ]..sort((a, b) {
          final focusCompare = b.todayFocusSeconds.compareTo(
            a.todayFocusSeconds,
          );
          if (focusCompare != 0) return focusCompare;
          return b.score.compareTo(a.score);
        });

    final previewLeaderboard = leaderboard.take(3).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('社交中心')),
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
            child: InkWell(
              borderRadius: BorderRadius.circular(AppUI.radiusCard),
              onTap: () => _openMyProfile(context),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AvatarIconPreview(index: myAvatarIconIndex, size: 84),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                myNickname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: primaryText,
                                ),
                              ),
                              if (myTitle.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: AppUI.softCardOf(
                                    context,
                                    accentColor,
                                  ),
                                  child: Text(
                                    myTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                mySignature,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryText,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SocialMiniInfo(
                            title: '今日分數',
                            value: '$myScore',
                            icon: Icons.auto_graph_outlined,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SocialMiniInfo(
                            title: '任務完成',
                            value: '$myCompletedTasks / $myTotalTasks',
                            icon: Icons.task_alt_outlined,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppUI.sectionGap),

          const _SectionHeader(title: '快速入口'),
          const SizedBox(height: AppUI.cardGap),

          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.72,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuickActionCard(
                icon: Icons.group_outlined,
                title: '好友列表',
                color: accentColor,
                onTap: () => _openFriendsPage(context),
              ),
              _QuickActionCard(
                icon: Icons.menu_book_outlined,
                title: '自律房',
                color: accentColor,
                onTap: () => _openStudyRooms(context),
              ),
              _QuickActionCard(
                icon: Icons.emoji_events_outlined,
                title: '排行榜',
                color: accentColor,
                onTap: () => _openLeaderboard(context),
              ),
              _QuickActionCard(
                icon: Icons.favorite_outline,
                title: '鼓勵紀錄',
                color: accentColor,
                onTap: () => _openEncouragement(context),
              ),
            ],
          ),

          const SizedBox(height: AppUI.sectionGap),

          const _SectionHeader(title: '今日社交摘要'),
          const SizedBox(height: AppUI.cardGap),
          _SocialSummaryCard(
            icon: Icons.dynamic_feed_outlined,
            title: previewStudying.isEmpty
                ? '目前社交動態平穩'
                : '${previewStudying.first.name} 正在專注',
            subtitle:
                '正在專注 ${studyingFriends.length} 人、自律房 ${appState.studyRooms.length} 間、好友 ${friends.length} 位。',
            actionLabel: '查看動態',
            color: accentColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _SocialActivityPage(
                    studyingFriends: previewStudying,
                    leaderboard: previewLeaderboard,
                    friends: friends,
                    roomCount: appState.studyRooms.length,
                    accentColor: accentColor,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 84),
        ],
      ),
    );
  }
}

class FriendData {
  final String id;
  final String name;
  final String title;
  final int score;
  final int todayFocusSeconds;
  final bool isStudying;
  final Color avatarColor;
  final AvatarProfile? avatarProfile;
  final String? roomId;
  final String? roomName;
  final String roomNickname;
  final StudyMemberStatus memberStatus;
  final bool isCurrentUser;

  const FriendData({
    required this.id,
    required this.name,
    required this.title,
    required this.score,
    required this.todayFocusSeconds,
    required this.isStudying,
    required this.avatarColor,
    this.avatarProfile,
    required this.roomId,
    required this.roomName,
    required this.roomNickname,
    required this.memberStatus,
    this.isCurrentUser = false,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
      ],
    );
  }
}

class _SocialSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final Color color;
  final VoidCallback onTap;

  const _SocialSummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppUI.innerPadding),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: AppUI.softCardOf(context, color),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: AppUI.softCardOf(context, color),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.chevron_right, color: color, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialActivityPage extends StatelessWidget {
  final List<FriendData> studyingFriends;
  final List<FriendData> leaderboard;
  final List<FriendData> friends;
  final int roomCount;
  final Color accentColor;

  const _SocialActivityPage({
    required this.studyingFriends,
    required this.leaderboard,
    required this.friends,
    required this.roomCount,
    required this.accentColor,
  });

  String _formatMMSS(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _openFriendsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FriendsPage()),
    );
  }

  void _openStudyRooms(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudyRoomListPage()),
    );
  }

  void _openLeaderboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeaderboardPage()),
    );
  }

  void _openEncouragement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EncouragementPage()),
    );
  }

  void _openPublicProfile(BuildContext context, FriendData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendPublicProfilePage(
          friendId: data.id,
          name: data.name,
          signature: data.title,
          todayFocusSeconds: data.todayFocusSeconds,
          score: data.score,
          isStudying: data.isStudying,
          avatarColor: data.avatarColor,
          avatarProfile: data.avatarProfile,
          roomId: data.roomId,
          roomName: data.roomName,
          roomNickname: data.roomNickname,
          memberStatus: data.memberStatus,
          isCurrentUser: data.isCurrentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('今日社交動態')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.dynamic_feed_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '最近發生什麼事',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '專注 ${studyingFriends.length} 人 · 自律房 $roomCount 間 · 好友 ${friends.length} 位',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          _ActivitySectionHeader(
            title: '正在專注',
            subtitle: studyingFriends.isEmpty ? '目前沒有好友正在專注。' : '先看現在正在努力的人。',
            actionLabel: '好友',
            onTap: () => _openFriendsPage(context),
          ),
          const SizedBox(height: AppUI.cardGap),
          if (studyingFriends.isEmpty)
            _ActivityEmptyCard(
              icon: Icons.timer_outlined,
              text: '等朋友開始專注後，這裡會優先顯示即時狀態。',
              color: accentColor,
            )
          else
            ...studyingFriends.map(
              (friend) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActivityFriendTile(
                  data: friend,
                  formatMMSS: _formatMMSS,
                  onTap: () => _openPublicProfile(context, friend),
                ),
              ),
            ),
          const SizedBox(height: AppUI.sectionGap),
          _ActivitySectionHeader(
            title: '社交入口狀態',
            subtitle: '房間、排行、好友與互動',
            actionLabel: '自律房',
            onTap: () => _openStudyRooms(context),
          ),
          const SizedBox(height: AppUI.cardGap),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _ActivityMetricCard(
                icon: Icons.menu_book_outlined,
                label: '自律房',
                value: '$roomCount 間',
                color: accentColor,
                onTap: () => _openStudyRooms(context),
              ),
              _ActivityMetricCard(
                icon: Icons.emoji_events_outlined,
                label: '排行第一',
                value: leaderboard.isEmpty ? '--' : leaderboard.first.name,
                color: AppUI.orange,
                onTap: () => _openLeaderboard(context),
              ),
              _ActivityMetricCard(
                icon: Icons.group_outlined,
                label: '好友',
                value: '${friends.length} 位',
                color: AppUI.green,
                onTap: () => _openFriendsPage(context),
              ),
              _ActivityMetricCard(
                icon: Icons.favorite_outline,
                label: '互動',
                value: '鼓勵紀錄',
                color: AppUI.purple,
                onTap: () => _openEncouragement(context),
              ),
            ],
          ),
          const SizedBox(height: AppUI.sectionGap),
          Text(
            '今日排行榜',
            style: TextStyle(
              color: primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 8),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                children: leaderboard.isEmpty
                    ? [
                        _ActivityEmptyCard(
                          icon: Icons.emoji_events_outlined,
                          text: '目前還沒有排行資料。',
                          color: AppUI.orange,
                        ),
                      ]
                    : leaderboard.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final friend = entry.value;
                        return _ActivityRankRow(
                          rank: index,
                          data: friend,
                          formatMMSS: _formatMMSS,
                        );
                      }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _ActivitySectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: secondaryText, fontSize: 13),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _ActivityFriendTile extends StatelessWidget {
  final FriendData data;
  final String Function(int) formatMMSS;
  final VoidCallback onTap;

  const _ActivityFriendTile({
    required this.data,
    required this.formatMMSS,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final avatarProfile = data.avatarProfile ?? AvatarProfile.initial();

    return Card(
      shape: AppUI.cardShape(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: onTap,
        leading: AvatarPreview(
          profile: avatarProfile,
          size: 48,
          showBackgroundRing: true,
        ),
        title: Text(
          data.name,
          style: TextStyle(color: primaryText, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '正在專注 · ${formatMMSS(data.todayFocusSeconds)}',
          style: TextStyle(color: secondaryText),
        ),
        trailing: Icon(Icons.chevron_right, color: secondaryText),
      ),
    );
  }
}

class _ActivityMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _ActivityMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(label, style: TextStyle(color: secondaryText, fontSize: 12)),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRankRow extends StatelessWidget {
  final int rank;
  final FriendData data;
  final String Function(int) formatMMSS;

  const _ActivityRankRow({
    required this.rank,
    required this.data,
    required this.formatMMSS,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank == 1 ? AppUI.orange : secondaryText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              data.name,
              style: TextStyle(
                color: primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            formatMMSS(data.todayFocusSeconds),
            style: TextStyle(
              color: secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityEmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ActivityEmptyCard({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppUI.softCardOf(context, color),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: secondaryText,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: AppUI.softCardOf(context, color),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialMiniInfo extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SocialMiniInfo({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppUI.softCardOf(context, color),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: secondaryText),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
