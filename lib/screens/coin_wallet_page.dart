import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_ui.dart';
import 'avatar_shop_page.dart';

class CoinWalletPage extends StatelessWidget {
  final VoidCallback onOpenTasks;

  const CoinWalletPage({super.key, required this.onOpenTasks});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final accentColor = const Color(0xFFF59E0B);
    final todayProgress = AppState.coinDailyLimit <= 0
        ? 0.0
        : (appState.todayCoinEarned / AppState.coinDailyLimit).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppUI.scaffoldBackgroundOf(context),
      appBar: AppBar(title: const Text('自律幣錢包')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppUI.pagePadding,
          8,
          AppUI.pagePadding,
          28,
        ),
        children: [
          _WalletHeroCard(
            coins: appState.disciplineCoins,
            todayEarned: appState.todayCoinEarned,
            todayRemaining: appState.todayCoinRemaining,
            dailyLimit: AppState.coinDailyLimit,
            weekEarned: appState.currentWeekCoinEarned,
            weekRemaining: appState.currentWeekCoinRemaining,
            weeklyLimit: AppState.coinWeeklyLimit,
            monthEarned: appState.currentMonthCoinEarned,
            monthRemaining: appState.currentMonthCoinRemaining,
            monthlyLimit: AppState.coinMonthlyLimit,
            progress: todayProgress,
            accentColor: accentColor,
          ),
          const SizedBox(height: AppUI.sectionGap),
          Row(
            children: [
              Expanded(
                child: _WalletActionButton(
                  icon: Icons.checklist_rounded,
                  title: '衝下一檻',
                  subtitle: '查看任務權重',
                  color: const Color(0xFF7C6AE6),
                  onTap: () {
                    Navigator.pop(context);
                    onOpenTasks();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WalletActionButton(
                  icon: Icons.checkroom_outlined,
                  title: '前往商城',
                  subtitle: '兌換造型',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AvatarShopPage()),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUI.sectionGap),
          _SectionHeader(
            title: '今日分數門檻',
            subtitle: '加權自律分數每達成 20% 一檻就領 3 枚，每天最多 15 枚，並受每週與每月上限保護。',
          ),
          const SizedBox(height: AppUI.cardGap),
          _MilestoneCard(
            score: appState.todayWeightedDisciplineScore,
            milestones: AppState.scoreCoinMilestones,
            primaryText: primaryText,
            secondaryText: secondaryText,
            accentColor: accentColor,
          ),
          const SizedBox(height: AppUI.sectionGap),
          _SectionHeader(title: '權重規則', subtitle: '越能被系統驗證、越能代表核心自律行為，任務占分越高。'),
          const SizedBox(height: AppUI.cardGap),
          const _RuleListCard(),
          const SizedBox(height: AppUI.sectionGap),
          _SectionHeader(
            title: '今天可以怎麼賺',
            subtitle: appState.nextScoreCoinMilestone == null
                ? '今天分數門檻已經全部達成，明天再繼續累積。'
                : '優先完成高權重任務，會比新增很多小任務更有效。',
          ),
          const SizedBox(height: AppUI.cardGap),
          _SuggestionCard(
            weightedScore: appState.todayWeightedDisciplineScore,
            nextMilestone: appState.nextScoreCoinMilestone,
            remainingCoins: appState.scoreCoinRemaining,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
        ],
      ),
    );
  }
}

class _WalletHeroCard extends StatelessWidget {
  final int coins;
  final int todayEarned;
  final int todayRemaining;
  final int dailyLimit;
  final int weekEarned;
  final int weekRemaining;
  final int weeklyLimit;
  final int monthEarned;
  final int monthRemaining;
  final int monthlyLimit;
  final double progress;
  final Color accentColor;

  const _WalletHeroCard({
    required this.coins,
    required this.todayEarned,
    required this.todayRemaining,
    required this.dailyLimit,
    required this.weekEarned,
    required this.weekRemaining,
    required this.weeklyLimit,
    required this.monthEarned,
    required this.monthRemaining,
    required this.monthlyLimit,
    required this.progress,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppUI.heroGradient(accentColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monetization_on_outlined,
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
                      '目前餘額',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$coins 枚',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '今日已領 $todayEarned / $dailyLimit，還能領 $todayRemaining 枚',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(text: '本週 $weekEarned / $weeklyLimit'),
              _HeroChip(text: '本月 $monthEarned / $monthlyLimit'),
              if (weekRemaining <= 0) const _HeroChip(text: '本週上限已滿'),
              if (monthRemaining <= 0) const _HeroChip(text: '本月上限已滿'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String text;

  const _HeroChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _WalletActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: AppUI.softCardOf(context, color),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: secondaryText, fontSize: 11),
                    ),
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

class _MilestoneCard extends StatelessWidget {
  final int score;
  final Map<int, int> milestones;
  final Color primaryText;
  final Color secondaryText;
  final Color accentColor;

  const _MilestoneCard({
    required this.score,
    required this.milestones,
    required this.primaryText,
    required this.secondaryText,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: milestones.entries.map((entry) {
          final reached = score >= entry.key;
          return Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == milestones.keys.last ? 0 : 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: AppUI.softCardOf(
                    context,
                    reached ? const Color(0xFF10B981) : accentColor,
                  ),
                  child: Icon(
                    reached ? Icons.check_rounded : Icons.flag_outlined,
                    color: reached ? const Color(0xFF10B981) : accentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${entry.key} 分門檻',
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '+${entry.value} 枚',
                  style: TextStyle(
                    color: reached ? const Color(0xFF10B981) : secondaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RuleListCard extends StatelessWidget {
  const _RuleListCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          _RuleRow(
            icon: Icons.favorite_border,
            title: '健康資料',
            subtitle: '睡眠、步數、運動，最高權重 4.0x',
            color: Color(0xFFEC4899),
          ),
          _RuleRow(
            icon: Icons.timer_outlined,
            title: '專注與自律房',
            subtitle: '使用 App 核心功能，權重 3.5x',
            color: Color(0xFF4F8CFF),
          ),
          _RuleRow(
            icon: Icons.event_available_outlined,
            title: '期限任務',
            subtitle: '報告、作業、考試準備，權重 2.5x',
            color: Color(0xFFF59E0B),
          ),
          _RuleRow(
            icon: Icons.edit_note_outlined,
            title: '一般手動任務',
            subtitle: '家事、喝水等自我回報，基礎權重 1.0x',
            color: Color(0xFF64748B),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLast;

  const _RuleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: AppUI.softCardOf(context, color),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final int weightedScore;
  final int? nextMilestone;
  final int remainingCoins;
  final Color primaryText;
  final Color secondaryText;

  const _SuggestionCard({
    required this.weightedScore,
    required this.nextMilestone,
    required this.remainingCoins,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final suggestion = nextMilestone == null
        ? '今天的門檻都達成了，可以把自律幣拿去商城試穿新造型。'
        : '還差 ${nextMilestone! - weightedScore} 分到下一個門檻。優先完成健康、專注或自律房任務，分數會提升比較快。';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: AppUI.softCardOf(context, const Color(0xFF7C6AE6)),
            child: const Icon(
              Icons.tips_and_updates_outlined,
              color: Color(0xFF7C6AE6),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日剩餘可領 $remainingCoins 枚',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  suggestion,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 13,
                    height: 1.45,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Column(
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
          style: TextStyle(color: secondaryText, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}
