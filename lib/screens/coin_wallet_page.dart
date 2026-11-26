import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../theme/game_ui.dart';
import '../widgets/world_life.dart';
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

    final ledger = [
      for (final d in appState.dailySummaries.reversed)
        if (d.coinsEarned > 0) (d.date, d.coinsEarned),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF2A1A14),
      appBar: AppBar(title: const Text('錢箱與帳本')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppUI.pagePadding,
          8,
          AppUI.pagePadding,
          28,
        ),
        children: [
          CashBoxScene(
            coins: appState.disciplineCoins,
            todayEarned: appState.todayCoinEarned,
            dailyLimit: AppState.coinDailyLimit,
          ),
          const SizedBox(height: AppUI.sectionGap),
          LedgerBook(entries: ledger),
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

/// The cash box: the coin pile rises with the balance (the number is the
/// small label), and today's coins drop in one by one.
class CashBoxScene extends StatelessWidget {
  const CashBoxScene({
    super.key,
    required this.coins,
    required this.todayEarned,
    required this.dailyLimit,
  });
  final int coins, todayEarned, dailyLimit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '錢箱裡有 $coins 枚自律幣，今天存了 $todayEarned 枚',
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: WorldClock(
          builder: (_, f, still) => CustomPaint(
            key: const Key('wallet-cashbox'),
            painter: _CashBoxPainter(
              frame: f,
              fill: (coins / 600).clamp(0.0, 1.0),
              drops: todayEarned.clamp(0, 15),
            ),
            child: Align(
              alignment: const Alignment(0, 0.92),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                color: GamePalette.parchment,
                child: Text(
                  '$coins 枚 · 今天 +$todayEarned／$dailyLimit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: GamePalette.inkDark,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CashBoxPainter extends CustomPainter {
  _CashBoxPainter({
    required this.frame,
    required this.fill,
    required this.drops,
  });
  final int frame, drops;
  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final px = Paint()..isAntiAlias = false;
    final u = size.width / 96;
    Rect r(double x, double y, double w, double h) =>
        Rect.fromLTWH(x * u, y * u, w * u, h * u);
    void box(Rect rect, Color c) => canvas.drawRect(rect, px..color = c);
    box(Offset.zero & size, const Color(0xFF3A2216));
    for (var i = 0; i < 6; i++) {
      box(r(0, i * 11.0, 96, 1), const Color(0xFF2A1A14));
    }
    // chest body
    box(r(18, 22, 60, 36), const Color(0xFF8A5A34));
    box(r(18, 22, 60, 3), const Color(0xFFC9934F));
    box(r(46, 22, 4, 36), const Color(0xFFFFC54D));
    // coin pile height = balance
    final pileH = 4 + 22 * fill;
    for (var row = 0.0; row < pileH; row += 2) {
      final inset = (row / pileH) * 10;
      box(
        r(22 + inset, 54 - row, 52 - inset * 2, 2),
        row % 4 == 0 ? const Color(0xFFFFC54D) : const Color(0xFFC4710B),
      );
    }
    // open lid
    box(r(16, 10, 64, 8), const Color(0xFF6A4428));
    box(r(16, 10, 64, 2), const Color(0xFFC9934F));
    // falling coins (today's)
    for (var i = 0; i < drops; i++) {
      final t = ((frame + i * 7) % 24) / 24;
      final x = 28 + (i * 37 % 40).toDouble();
      final y = -4 + t * (54 - pileH);
      box(r(x, y, 3, 3), const Color(0xFFFFE08A));
      box(r(x + 1, y + 1, 1, 1), const Color(0xFFC4710B));
    }
    // wall shelf with the ledger
    box(r(4, 60, 88, 3), const Color(0xFF5A3A26));
  }

  @override
  bool shouldRepaint(_CashBoxPainter old) =>
      old.frame != frame || old.fill != fill || old.drops != drops;
}

/// The ledger: each line is one day's Cloud-confirmed coins.
class LedgerBook extends StatelessWidget {
  const LedgerBook({super.key, required this.entries});
  final List<(String, int)> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wallet-ledger'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: GamePalette.parchment,
        border: Border.all(color: GamePalette.woodDeep, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0xFF2A1A14), offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '帳本',
            style: TextStyle(
              fontFamily: 'Cubic11',
              fontSize: 20,
              color: GamePalette.inkDark,
            ),
          ),
          const Divider(color: GamePalette.woodDeep, thickness: 2),
          if (entries.isEmpty)
            const Text('還沒有入帳。完成雲端確認的任務與專注，就會一筆一筆記在這裡。')
          else
            for (final (date, coins) in entries.take(14))
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x553A2216))),
                ),
                child: Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(color: GamePalette.inkDark),
                    ),
                    const Spacer(),
                    Text(
                      '＋$coins 枚',
                      style: const TextStyle(
                        color: GamePalette.goldDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 6),
          const Text('兌換支出由雲端帳本扣款，不會在這裡重複記帳。', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
