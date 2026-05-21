import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/avatar_profile.dart';
import '../models/social_friend_profile.dart';
import '../models/study_room_models.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';
import 'friend_public_profile_page.dart';

enum LeaderboardType { todayFocus, weekFocus, taskCompleted, disciplineScore }

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  String _formatMMSS(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _calculateMyScore(AppState appState) {
    return appState.todayWeightedDisciplineScore;
  }

  int _estimateWeeklyFocus(int todayFocusSeconds) {
    return todayFocusSeconds * 4 + 1800;
  }

  int _estimateTaskCompleted(int todayFocusSeconds) {
    final base = (todayFocusSeconds / 1800).round();
    return (base + 1).clamp(1, 8);
  }

  List<_LeaderboardEntry> _buildRoomFriends(
    List<StudyRoomData> rooms,
    AppState appState,
  ) {
    final Map<String, _LeaderboardEntry> merged = {};

    for (final room in rooms) {
      for (final member in room.members) {
        if (member.memberId == 'local_user' || member.name == '老闆') continue;

        final entry = _LeaderboardEntry(
          id: member.name,
          name: member.name,
          subtitle: switch (member.status) {
            StudyMemberStatus.studying => '正在專注中',
            StudyMemberStatus.resting => '剛休息一下',
            StudyMemberStatus.offline => '今天慢慢前進',
          },
          avatarColor: member.avatarColor,
          avatarProfile:
              member.avatarProfile ??
              appState.avatarVariantForSeed(member.memberId.hashCode),
          todayFocusSeconds: member.todayFocusSeconds,
          weekFocusSeconds: _estimateWeeklyFocus(member.todayFocusSeconds),
          completedTasks: _estimateTaskCompleted(member.todayFocusSeconds),
          disciplineScore: (40 + (member.todayFocusSeconds / 60 / 2))
              .clamp(0, 100)
              .round(),
        );

        final existing = merged[member.name];
        if (existing == null ||
            entry.todayFocusSeconds > existing.todayFocusSeconds) {
          merged[member.name] = entry;
        }
      }
    }

    return merged.values.toList();
  }

  List<_LeaderboardEntry> _buildManualFriends(
    List<SocialFriendProfile> friends,
    AppState appState,
  ) {
    return friends
        .map(
          (f) => _LeaderboardEntry(
            id: f.id,
            name: f.name,
            subtitle: f.signature,
            avatarColor: f.avatarColor,
            avatarProfile:
                f.avatarProfile ?? appState.avatarVariantForSeed(f.id.hashCode),
            todayFocusSeconds: f.todayFocusSeconds,
            weekFocusSeconds: _estimateWeeklyFocus(f.todayFocusSeconds),
            completedTasks: _estimateTaskCompleted(f.todayFocusSeconds),
            disciplineScore: (35 + (f.todayFocusSeconds / 60 / 2))
                .clamp(0, 100)
                .round(),
          ),
        )
        .toList();
  }

  void _openPublicProfile(
    BuildContext context, {
    required _LeaderboardEntry entry,
    required bool isCurrentUser,
    AvatarProfile? avatarProfile,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendPublicProfilePage(
          friendId: entry.id,
          name: entry.name,
          signature: entry.subtitle,
          todayFocusSeconds: entry.todayFocusSeconds,
          score: entry.disciplineScore,
          isStudying: entry.todayFocusSeconds > 0,
          avatarColor: entry.avatarColor,
          isCurrentUser: isCurrentUser,
          avatarProfile: avatarProfile,
        ),
      ),
    );
  }

  String _tabDescription(LeaderboardType type) {
    switch (type) {
      case LeaderboardType.todayFocus:
        return '看看今天誰最專注。';
      case LeaderboardType.weekFocus:
        return '比較這週累積的專注時數。';
      case LeaderboardType.taskCompleted:
        return '看看誰完成最多任務。';
      case LeaderboardType.disciplineScore:
        return '用綜合表現查看整體排名。';
    }
  }

  String _valueText(LeaderboardType type, _LeaderboardEntry entry) {
    switch (type) {
      case LeaderboardType.todayFocus:
        return _formatMMSS(entry.todayFocusSeconds);
      case LeaderboardType.weekFocus:
        return _formatMMSS(entry.weekFocusSeconds);
      case LeaderboardType.taskCompleted:
        return '${entry.completedTasks} 個';
      case LeaderboardType.disciplineScore:
        return '${entry.disciplineScore} 分';
    }
  }

  int _metricValue(LeaderboardType type, _LeaderboardEntry entry) {
    switch (type) {
      case LeaderboardType.todayFocus:
        return entry.todayFocusSeconds;
      case LeaderboardType.weekFocus:
        return entry.weekFocusSeconds;
      case LeaderboardType.taskCompleted:
        return entry.completedTasks;
      case LeaderboardType.disciplineScore:
        return entry.disciplineScore;
    }
  }

  String _gapText(LeaderboardType type, int gap) {
    switch (type) {
      case LeaderboardType.todayFocus:
      case LeaderboardType.weekFocus:
        return _formatMMSS(gap);
      case LeaderboardType.taskCompleted:
        return '$gap 個';
      case LeaderboardType.disciplineScore:
        return '$gap 分';
    }
  }

  String _myRankingSummary(
    LeaderboardType type,
    List<_LeaderboardEntry> sorted,
  ) {
    final myIndex = sorted.indexWhere((e) => e.isCurrentUser);
    if (myIndex == -1) return '尚未上榜';

    final myRank = myIndex + 1;
    if (myRank == 1) {
      return '你目前是第 1 名，保持領先中';
    }

    final current = sorted[myIndex];
    final previous = sorted[myIndex - 1];
    final gap = (_metricValue(type, previous) - _metricValue(type, current))
        .abs();

    return '你目前第 $myRank 名，距離前一名差 ${_gapText(type, gap)}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final myAvatar = appState.avatarProfile;
    final myCompletedTasks = appState.todayActionableTaskCompleted;

    final roomFriends = _buildRoomFriends(appState.studyRooms, appState);
    final manualFriends = _buildManualFriends(appState.socialFriends, appState);

    final merged = <String, _LeaderboardEntry>{};
    for (final entry in [...roomFriends, ...manualFriends]) {
      merged[entry.id] = entry;
    }

    final myEntry = _LeaderboardEntry(
      id: 'me',
      name: appState.profileNickname,
      subtitle: appState.profileSignature,
      avatarColor: appState.currentIconColor,
      avatarProfile: myAvatar,
      todayFocusSeconds: appState.focusSeconds,
      weekFocusSeconds: _estimateWeeklyFocus(appState.focusSeconds),
      completedTasks: myCompletedTasks,
      disciplineScore: _calculateMyScore(appState),
      isCurrentUser: true,
    );

    final entries = [myEntry, ...merged.values];

    return DefaultTabController(
      length: LeaderboardType.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('排行榜'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '今日專注'),
              Tab(text: '本週專注'),
              Tab(text: '任務完成'),
              Tab(text: '自律分數'),
            ],
          ),
        ),
        body: TabBarView(
          children: LeaderboardType.values.map((type) {
            final sorted = [...entries]
              ..sort((a, b) {
                switch (type) {
                  case LeaderboardType.todayFocus:
                    return b.todayFocusSeconds.compareTo(a.todayFocusSeconds);
                  case LeaderboardType.weekFocus:
                    return b.weekFocusSeconds.compareTo(a.weekFocusSeconds);
                  case LeaderboardType.taskCompleted:
                    return b.completedTasks.compareTo(a.completedTasks);
                  case LeaderboardType.disciplineScore:
                    return b.disciplineScore.compareTo(a.disciplineScore);
                }
              });

            final topThree = sorted.take(3).toList();
            final rest = sorted.length > 3
                ? sorted.sublist(3)
                : <_LeaderboardEntry>[];

            return ListView(
              padding: const EdgeInsets.all(AppUI.pagePadding),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppUI.heroGradient(appState.currentIconColor),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tabDescription(type),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _myRankingSummary(type, sorted),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppUI.sectionGap),
                if (topThree.isNotEmpty) ...[
                  const Text('前三名', style: AppUI.sectionTitle),
                  const SizedBox(height: 12),
                  ...topThree.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TopLeaderboardTile(
                        rank: index + 1,
                        entry: item,
                        valueText: _valueText(type, item),
                        currentUserAvatar: myAvatar,
                        onTap: () => _openPublicProfile(
                          context,
                          entry: item,
                          isCurrentUser: item.isCurrentUser,
                          avatarProfile: item.avatarProfile,
                        ),
                      ),
                    );
                  }),
                ],
                if (rest.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text('其他排名', style: AppUI.sectionTitle),
                  const SizedBox(height: 12),
                  ...rest.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final rank = index + 4;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LeaderboardTile(
                        rank: rank,
                        entry: item,
                        valueText: _valueText(type, item),
                        currentUserAvatar: myAvatar,
                        onTap: () => _openPublicProfile(
                          context,
                          entry: item,
                          isCurrentUser: item.isCurrentUser,
                          avatarProfile: item.avatarProfile,
                        ),
                      ),
                    );
                  }),
                ],
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _LeaderboardEntry {
  final String id;
  final String name;
  final String subtitle;
  final Color avatarColor;
  final AvatarProfile? avatarProfile;
  final int todayFocusSeconds;
  final int weekFocusSeconds;
  final int completedTasks;
  final int disciplineScore;
  final bool isCurrentUser;

  const _LeaderboardEntry({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.avatarColor,
    this.avatarProfile,
    required this.todayFocusSeconds,
    required this.weekFocusSeconds,
    required this.completedTasks,
    required this.disciplineScore,
    this.isCurrentUser = false,
  });
}

class _TopLeaderboardTile extends StatelessWidget {
  final int rank;
  final _LeaderboardEntry entry;
  final String valueText;
  final AvatarProfile currentUserAvatar;
  final VoidCallback onTap;

  const _TopLeaderboardTile({
    required this.rank,
    required this.entry,
    required this.valueText,
    required this.currentUserAvatar,
    required this.onTap,
  });

  Color _rankColor() {
    if (rank == 1) return const Color(0xFFF59E0B);
    if (rank == 2) return const Color(0xFF94A3B8);
    return const Color(0xFFB45309);
  }

  String _rankLabel() {
    if (rank == 1) return '第 1 名';
    if (rank == 2) return '第 2 名';
    return '第 3 名';
  }

  IconData _rankIcon() {
    if (rank == 1) return Icons.emoji_events;
    if (rank == 2) return Icons.workspace_premium;
    return Icons.military_tech;
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: rankColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: rankColor.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: rankColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(_rankIcon(), color: rankColor, size: 22),
              ),
              const SizedBox(width: 12),
              AvatarPreview(
                profile: entry.avatarProfile ?? currentUserAvatar,
                size: 46,
                showBackgroundRing: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.isCurrentUser ? '${entry.name}（你）' : entry.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppUI.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppUI.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _rankLabel(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: rankColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppUI.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final _LeaderboardEntry entry;
  final String valueText;
  final AvatarProfile currentUserAvatar;
  final VoidCallback onTap;

  const _LeaderboardTile({
    required this.rank,
    required this.entry,
    required this.valueText,
    required this.currentUserAvatar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: entry.isCurrentUser
                ? entry.avatarColor.withValues(alpha: 0.08)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: entry.isCurrentUser
                  ? entry.avatarColor.withValues(alpha: 0.25)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppUI.textSecondaryOf(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AvatarPreview(
                profile: entry.avatarProfile ?? currentUserAvatar,
                size: 40,
                showBackgroundRing: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.isCurrentUser ? '${entry.name}（你）' : entry.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppUI.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppUI.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppUI.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
