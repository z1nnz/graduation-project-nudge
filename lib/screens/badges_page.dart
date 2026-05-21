import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/badge_record.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

enum _BadgeStatusFilter { all, unlocked, locked }

enum _BadgeSeriesFilter { all, focus, health, room }

enum _BadgeSortType { recommended, progress, unlockedFirst, lockedFirst }

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  _BadgeStatusFilter _statusFilter = _BadgeStatusFilter.all;
  _BadgeSeriesFilter _seriesFilter = _BadgeSeriesFilter.all;
  _BadgeSortType _sortType = _BadgeSortType.recommended;

  IconData _iconForBadge(String key) {
    switch (key) {
      case 'task_starter':
        return Icons.flag_outlined;
      case 'focus_beginner':
        return Icons.timer_outlined;
      case 'focus_streak':
        return Icons.local_fire_department_outlined;
      case 'task_streak':
        return Icons.task_alt_outlined;
      case 'sleep_guard':
        return Icons.bedtime_outlined;
      case 'step_master':
        return Icons.directions_walk;
      case 'steady_progress':
        return Icons.trending_up;
      case 'score_keeper':
        return Icons.emoji_events_outlined;
      case 'coin_earner':
        return Icons.monetization_on_outlined;
      case 'auto_tracker':
        return Icons.sync_outlined;
      case 'health_sync':
        return Icons.favorite_border;
      case 'health_task':
        return Icons.health_and_safety_outlined;
      case 'room_joiner':
        return Icons.groups_2_outlined;
      case 'room_focus':
        return Icons.auto_graph_outlined;
      case 'room_leader':
        return Icons.workspace_premium_outlined;
      case 'room_social':
        return Icons.forum_outlined;
      default:
        return Icons.emoji_events_outlined;
    }
  }

  String _descriptionForBadge(String key) {
    switch (key) {
      case 'task_starter':
        return '曾經完成至少 1 個任務';
      case 'focus_beginner':
        return '曾經累積專注 25 分鐘';
      case 'focus_streak':
        return '連續 3 天都有專注紀錄';
      case 'task_streak':
        return '連續 3 天都有完成任務';
      case 'sleep_guard':
        return '最近 7 天有 3 天睡眠超過 7 小時';
      case 'step_master':
        return '最近 7 天有 3 天步數超過 8000';
      case 'steady_progress':
        return '最近 7 天有 3 天分數達到 70 分';
      case 'score_keeper':
        return '最近 7 天平均分數超過 70 分';
      case 'coin_earner':
        return '最近 7 天累積獲得 80 枚自律幣';
      case 'auto_tracker':
        return '最近 7 天完成 5 個自動追蹤任務';
      case 'health_sync':
        return '成功同步健康資料';
      case 'health_task':
        return '最近 7 天完成 5 個健康自動追蹤任務';
      case 'room_joiner':
        return '至少加入 1 間自律房';
      case 'room_focus':
        return '所有自律房曾經總專注達 120 分鐘';
      case 'room_leader':
        return '成為任一自律房目前第一名';
      case 'room_social':
        return '擁有至少 1 間 3 人以上的活躍自律房';
      default:
        return '成就徽章';
    }
  }

  String _groupForBadge(String key) {
    switch (key) {
      case 'focus_beginner':
      case 'focus_streak':
      case 'task_starter':
      case 'task_streak':
      case 'steady_progress':
      case 'score_keeper':
      case 'coin_earner':
      case 'auto_tracker':
        return '專注成長';
      case 'sleep_guard':
      case 'step_master':
      case 'health_sync':
      case 'health_task':
        return '健康自律';
      case 'room_joiner':
      case 'room_focus':
      case 'room_leader':
      case 'room_social':
        return '自律房成就';
      default:
        return '其他成就';
    }
  }

  String _progressLabel(BadgeRecord record) {
    const minuteBadges = {'focus_beginner', 'room_focus'};
    const scoreBadges = {'score_keeper'};
    const coinBadges = {'coin_earner'};

    if (minuteBadges.contains(record.badgeKey)) {
      return '${record.progress} / ${record.target} 分鐘';
    }
    if (scoreBadges.contains(record.badgeKey)) {
      return '${record.progress} / ${record.target} 分';
    }
    if (coinBadges.contains(record.badgeKey)) {
      return '${record.progress} / ${record.target} 枚';
    }
    return '${record.progress} / ${record.target}';
  }

  String _remainingLabel(BadgeRecord record) {
    if (record.isUnlocked) return '已達成';

    final remain = (record.target - record.progress).clamp(0, record.target);

    switch (record.badgeKey) {
      case 'task_starter':
      case 'health_sync':
      case 'room_joiner':
      case 'room_leader':
      case 'room_social':
        return '還差 1 次';
      case 'focus_beginner':
      case 'room_focus':
        return '還差 $remain 分鐘';
      case 'score_keeper':
        return '還差 $remain 分';
      case 'coin_earner':
        return '還差 $remain 枚';
      default:
        return '還差 $remain 次';
    }
  }

  String _sourceLabel(String badgeKey) {
    if (badgeKey.contains('health') ||
        badgeKey.contains('sleep') ||
        badgeKey.contains('steps') ||
        badgeKey.contains('exercise')) {
      return '來源：健康任務';
    }
    if (badgeKey.contains('room') || badgeKey.contains('study_room')) {
      return '來源：自律房';
    }
    if (badgeKey.contains('focus')) return '來源：專注';
    if (badgeKey.contains('coin') || badgeKey.contains('score')) {
      return '來源：自律分數';
    }
    return '來源：任務完成';
  }

  String _statusFilterLabel(_BadgeStatusFilter filter) {
    switch (filter) {
      case _BadgeStatusFilter.all:
        return '全部';
      case _BadgeStatusFilter.unlocked:
        return '已解鎖';
      case _BadgeStatusFilter.locked:
        return '未解鎖';
    }
  }

  String _seriesFilterLabel(_BadgeSeriesFilter filter) {
    switch (filter) {
      case _BadgeSeriesFilter.all:
        return '全部系列';
      case _BadgeSeriesFilter.focus:
        return '專注成長';
      case _BadgeSeriesFilter.health:
        return '健康自律';
      case _BadgeSeriesFilter.room:
        return '自律房';
    }
  }

  String _sortLabel(_BadgeSortType type) {
    switch (type) {
      case _BadgeSortType.recommended:
        return '推薦排序';
      case _BadgeSortType.progress:
        return '進度最高';
      case _BadgeSortType.unlockedFirst:
        return '已解鎖優先';
      case _BadgeSortType.lockedFirst:
        return '未解鎖優先';
    }
  }

  bool _matchesSeries(BadgeRecord badge) {
    final group = _groupForBadge(badge.badgeKey);
    switch (_seriesFilter) {
      case _BadgeSeriesFilter.all:
        return true;
      case _BadgeSeriesFilter.focus:
        return group == '專注成長';
      case _BadgeSeriesFilter.health:
        return group == '健康自律';
      case _BadgeSeriesFilter.room:
        return group == '自律房成就';
    }
  }

  List<BadgeRecord> _visibleBadges(List<BadgeRecord> badges) {
    final visible = badges.where((badge) {
      switch (_statusFilter) {
        case _BadgeStatusFilter.all:
          break;
        case _BadgeStatusFilter.unlocked:
          if (!badge.isUnlocked) return false;
        case _BadgeStatusFilter.locked:
          if (badge.isUnlocked) return false;
      }
      return _matchesSeries(badge);
    }).toList();

    visible.sort((a, b) {
      switch (_sortType) {
        case _BadgeSortType.recommended:
          if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? -1 : 1;
          final groupCompare = _groupForBadge(
            a.badgeKey,
          ).compareTo(_groupForBadge(b.badgeKey));
          if (groupCompare != 0) return groupCompare;
          return b.progressRatio.compareTo(a.progressRatio);
        case _BadgeSortType.progress:
          return b.progressRatio.compareTo(a.progressRatio);
        case _BadgeSortType.unlockedFirst:
          if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? -1 : 1;
          return b.progressRatio.compareTo(a.progressRatio);
        case _BadgeSortType.lockedFirst:
          if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? 1 : -1;
          return b.progressRatio.compareTo(a.progressRatio);
      }
    });

    return visible;
  }

  String _rarityForBadge(String key) {
    if (key.contains('leader') || key.contains('social')) return '稀有';
    if (key.contains('streak') || key.contains('keeper')) return '進階';
    if (key.contains('health') || key.contains('room')) return '系列';
    return '基礎';
  }

  void _showBadgeDetailDialog(
    BuildContext context, {
    required BadgeRecord badge,
    required IconData icon,
    required String description,
    required String progressLabel,
    required String remainingLabel,
  }) {
    final sourceLabel = _sourceLabel(badge.badgeKey);
    final iconBgColor = badge.isUnlocked
        ? const Color(0xFFFFF3D6)
        : const Color(0xFFE5E7EB);
    final iconColor = badge.isUnlocked
        ? const Color(0xFFF59E0B)
        : const Color(0xFF9CA3AF);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  badge.badgeName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppUI.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: badge.isUnlocked
                      ? const Color(0xFFE8F7EC)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(AppUI.radiusPill),
                ),
                child: Text(
                  badge.isUnlocked ? '已解鎖' : '尚未解鎖',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: badge.isUnlocked
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '達成條件',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppUI.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppUI.textSecondaryOf(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: AppUI.softCardOf(context, iconColor),
                child: Text(
                  sourceLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '目前進度',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppUI.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: badge.progressRatio,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    badge.isUnlocked
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                progressLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: badge.isUnlocked
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                remainingLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: badge.isUnlocked
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final badges = appState.badgeRecords;
    final secondaryText = AppUI.textSecondaryOf(context);
    final primaryText = AppUI.textPrimaryOf(context);

    final unlockedCount = badges.where((badge) => badge.isUnlocked).length;
    final lockedCount = badges.length - unlockedCount;
    final unlockRatio = badges.isEmpty ? 0.0 : unlockedCount / badges.length;
    final visibleBadges = _visibleBadges(badges);

    return Scaffold(
      appBar: AppBar(title: const Text('成就徽章')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '成就總覽',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$unlockedCount / ${badges.length} 已解鎖',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: unlockRatio,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        '展示方式',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _BadgeStatusFilter.values.map((filter) {
                      return ChoiceChip(
                        label: Text(_statusFilterLabel(filter)),
                        selected: _statusFilter == filter,
                        onSelected: (_) {
                          setState(() {
                            _statusFilter = filter;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _BadgeSeriesFilter.values.map((filter) {
                      return ChoiceChip(
                        label: Text(_seriesFilterLabel(filter)),
                        selected: _seriesFilter == filter,
                        onSelected: (_) {
                          setState(() {
                            _seriesFilter = filter;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<_BadgeSortType>(
                    initialValue: _sortType,
                    decoration: const InputDecoration(
                      labelText: '排序',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: _BadgeSortType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(_sortLabel(type)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _sortType = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          Row(
            children: [
              Expanded(
                child: Text(
                  '徽章收藏',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${visibleBadges.length} 個',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visibleBadges.isEmpty)
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '目前沒有符合篩選條件的徽章。',
                  style: TextStyle(color: secondaryText, fontSize: 14),
                ),
              ),
            )
          else
            _BadgeGrid(
              badges: visibleBadges,
              mainAxisExtent: (width) {
                if (width < 380) return 238;
                if (width < 430) return 230;
                return 224;
              },
              iconForBadge: _iconForBadge,
              descriptionForBadge: _descriptionForBadge,
              rarityForBadge: _rarityForBadge,
              progressLabel: _progressLabel,
              remainingLabel: _remainingLabel,
              onTap: (badge) {
                _showBadgeDetailDialog(
                  context,
                  badge: badge,
                  icon: _iconForBadge(badge.badgeKey),
                  description: _descriptionForBadge(badge.badgeKey),
                  progressLabel: _progressLabel(badge),
                  remainingLabel: _remainingLabel(badge),
                );
              },
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BadgeSummaryBox(
                  title: '已解鎖',
                  value: '$unlockedCount',
                  icon: Icons.lock_open_outlined,
                  color: AppUI.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BadgeSummaryBox(
                  title: '未解鎖',
                  value: '$lockedCount',
                  icon: Icons.lock_outline,
                  color: AppUI.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BadgeSummaryBox(
                  title: '完成率',
                  value: '${(unlockRatio * 100).round()}%',
                  icon: Icons.insights_outlined,
                  color: AppUI.purple,
                ),
              ),
            ],
          ),
          Text(
            '目前成就會搭配加權任務、自律幣門檻、健康同步與自律房表現來判定。',
            style: TextStyle(fontSize: 13, color: secondaryText, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  final List<BadgeRecord> badges;
  final double Function(double) mainAxisExtent;
  final IconData Function(String) iconForBadge;
  final String Function(String) descriptionForBadge;
  final String Function(String) rarityForBadge;
  final String Function(BadgeRecord) progressLabel;
  final String Function(BadgeRecord) remainingLabel;
  final void Function(BadgeRecord) onTap;

  const _BadgeGrid({
    required this.badges,
    required this.mainAxisExtent,
    required this.iconForBadge,
    required this.descriptionForBadge,
    required this.rarityForBadge,
    required this.progressLabel,
    required this.remainingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GridView.builder(
          itemCount: badges.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: mainAxisExtent(width),
          ),
          itemBuilder: (context, index) {
            final badge = badges[index];
            return _BadgeCard(
              badge: badge,
              icon: iconForBadge(badge.badgeKey),
              description: descriptionForBadge(badge.badgeKey),
              rarity: rarityForBadge(badge.badgeKey),
              progressLabel: progressLabel(badge),
              remainingLabel: remainingLabel(badge),
              onTap: () => onTap(badge),
            );
          },
        );
      },
    );
  }
}

class _BadgeSummaryBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _BadgeSummaryBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppUI.softCardOf(context, color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: AppUI.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppUI.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeRecord badge;
  final IconData icon;
  final String description;
  final String rarity;
  final String progressLabel;
  final String remainingLabel;
  final VoidCallback onTap;

  const _BadgeCard({
    required this.badge,
    required this.icon,
    required this.description,
    required this.rarity,
    required this.progressLabel,
    required this.remainingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppUI.isDark(context);
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    final cardColor = badge.isUnlocked
        ? Theme.of(context).cardColor
        : (isDark ? const Color(0xFF202532) : const Color(0xFFF6F6FA));
    final iconColor = badge.isUnlocked ? AppUI.orange : const Color(0xFF9CA3AF);
    final titleColor = badge.isUnlocked ? primaryText : const Color(0xFF9CA3AF);
    final descColor = badge.isUnlocked
        ? secondaryText
        : const Color(0xFFB0B4BC);
    final progressColor = badge.isUnlocked
        ? AppUI.orange
        : const Color(0xFF9CA3AF);
    return Card(
      color: cardColor,
      shape: AppUI.cardShape(),
      elevation: badge.isUnlocked ? 2 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: badge.isUnlocked
                          ? const LinearGradient(
                              colors: [Color(0xFFFFF3D6), Color(0xFFFFE4A8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: badge.isUnlocked
                          ? null
                          : (isDark
                                ? const Color(0xFF2A2F3A)
                                : const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: badge.isUnlocked
                          ? const Color(0xFFE8F7EC)
                          : (isDark
                                ? const Color(0xFF2A2F3A)
                                : const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(AppUI.radiusPill),
                    ),
                    child: Text(
                      badge.isUnlocked ? rarity : '未解鎖',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badge.isUnlocked
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                badge.badgeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, height: 1.3, color: descColor),
              ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: badge.progressRatio,
                  minHeight: 7,
                  backgroundColor: isDark
                      ? const Color(0xFF2A2F3A)
                      : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progressLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: progressColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      remainingLabel,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: badge.isUnlocked
                            ? const Color(0xFF16A34A)
                            : secondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
