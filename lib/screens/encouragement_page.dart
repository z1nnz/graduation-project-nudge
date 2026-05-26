import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/social_encouragement_record.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class EncouragementPage extends StatelessWidget {
  const EncouragementPage({super.key});

  String _formatRelativeTime(String createdAt) {
    final time = DateTime.tryParse(createdAt);
    if (time == null) return '剛剛';

    final diff = DateTime.now().difference(time);

    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inHours < 1) return '${diff.inMinutes} 分鐘前';
    if (diff.inDays < 1) return '${diff.inHours} 小時前';
    return '${diff.inDays} 天前';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _todaySentCount(List<SocialEncouragementRecord> records, String myName) {
    final now = DateTime.now();
    return records.where((record) {
      final time = DateTime.tryParse(record.createdAt);
      if (time == null) return false;
      return record.fromName == myName && _isSameDay(time, now);
    }).length;
  }

  Map<String, int> _typeStats(List<SocialEncouragementRecord> records) {
    final map = <String, int>{'加油': 0, '很棒': 0, '繼續保持': 0};

    for (final record in records) {
      map[record.type] = (map[record.type] ?? 0) + 1;
    }

    return map;
  }

  String _mostFrequentEncourager(List<SocialEncouragementRecord> records) {
    final received = records.where((r) => r.toFriendId == 'me').toList();
    if (received.isEmpty) return '目前還沒有';

    final countMap = <String, int>{};
    for (final record in received) {
      countMap[record.fromName] = (countMap[record.fromName] ?? 0) + 1;
    }

    final sorted = countMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return '${sorted.first.key}（${sorted.first.value} 次）';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final records = appState.socialEncouragementRecords.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final received = records.where((r) => r.toFriendId == 'me').toList();
    final sent = records
        .where((r) => r.fromName == appState.profileNickname)
        .toList();

    final todayReceived = appState.getTodayReceivedEncouragementCount();
    final todaySent = _todaySentCount(records, appState.profileNickname);
    final typeStats = _typeStats(records);
    final topEncourager = _mostFrequentEncourager(records);
    final accentColor = appState.currentIconColor;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('鼓勵互動'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '收到的鼓勵'),
              Tab(text: '送出的鼓勵'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(AppUI.pagePadding),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppUI.heroGradient(accentColor),
                  child: const Text(
                    '看看誰最近鼓勵了你，讓互動不只是按一下而已。',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppUI.sectionGap),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('鼓勵摘要', style: AppUI.sectionTitleOf(context)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: '今天收到',
                              value: '$todayReceived 次',
                              icon: Icons.favorite,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: '今天送出',
                              value: '$todaySent 次',
                              icon: Icons.send_outlined,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _WideSummaryCard(
                        title: '最常鼓勵你的人',
                        value: topEncourager,
                        icon: Icons.people_alt_outlined,
                        color: AppUI.blue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppUI.cardGap),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('鼓勵類型統計', style: AppUI.sectionTitleOf(context)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _TypeStatChip(
                              label: '加油',
                              count: typeStats['加油'] ?? 0,
                              color: AppUI.orange,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TypeStatChip(
                              label: '很棒',
                              count: typeStats['很棒'] ?? 0,
                              color: AppUI.green,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TypeStatChip(
                              label: '繼續保持',
                              count: typeStats['繼續保持'] ?? 0,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppUI.cardGap),
                _EncouragementListView(
                  title: '收到的鼓勵紀錄',
                  records: received,
                  emptyText: '目前還沒有收到鼓勵。',
                  relativeTimeBuilder: _formatRelativeTime,
                  isReceived: true,
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(AppUI.pagePadding),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppUI.heroGradient(accentColor),
                  child: const Text(
                    '你送出去的每一句鼓勵，都會變成社交互動的一部分。',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppUI.sectionGap),
                _EncouragementListView(
                  title: '你最近送出的鼓勵',
                  records: sent,
                  emptyText: '你還沒有送出鼓勵。',
                  relativeTimeBuilder: _formatRelativeTime,
                  isReceived: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EncouragementListView extends StatelessWidget {
  final String title;
  final List<SocialEncouragementRecord> records;
  final String emptyText;
  final String Function(String) relativeTimeBuilder;
  final bool isReceived;

  const _EncouragementListView({
    required this.title,
    required this.records,
    required this.emptyText,
    required this.relativeTimeBuilder,
    required this.isReceived,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppUI.sectionTitleOf(context)),
          const SizedBox(height: 14),
          if (records.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppUI.isDark(context)
                    ? const Color(0xFF1F2430)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                emptyText,
                style: TextStyle(
                  fontSize: 13,
                  color: AppUI.textSecondaryOf(context),
                ),
              ),
            )
          else
            ...records.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EncouragementTile(
                  record: record,
                  relativeTime: relativeTimeBuilder(record.createdAt),
                  isReceived: isReceived,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EncouragementTile extends StatelessWidget {
  final SocialEncouragementRecord record;
  final String relativeTime;
  final bool isReceived;

  const _EncouragementTile({
    required this.record,
    required this.relativeTime,
    required this.isReceived,
  });

  @override
  Widget build(BuildContext context) {
    final title = isReceived
        ? '${record.fromName} 對你說 ${record.type}'
        : '你對 ${record.toFriendName} 說 ${record.type}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUI.isDark(context)
            ? const Color(0xFF1F2430)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFCE7F3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.favorite,
              color: Color(0xFFDB2777),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppUI.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  relativeTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppUI.textSecondaryOf(context),
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

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
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
            style: TextStyle(
              fontSize: 12,
              color: AppUI.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppUI.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _WideSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppUI.softCardOf(context, color),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppUI.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppUI.textPrimaryOf(context),
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

class _TypeStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _TypeStatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              color: AppUI.textPrimaryOf(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
