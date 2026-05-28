import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class GuardianParentPage extends StatefulWidget {
  const GuardianParentPage({super.key});

  @override
  State<GuardianParentPage> createState() => _GuardianParentPageState();
}

class _GuardianParentPageState extends State<GuardianParentPage> {
  final _messageCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  final _goalMsgCtrl = TextEditingController();

  String _cardTitle = '今天也辛苦了';
  String _permission = '詳細進度';

  final List<String> _cardTemplates = [
    '今天也辛苦了',
    '休息也是自律的一部分',
    '看見你的努力，加油！',
    '保持這個專注節奏',
    '今天很棒，晚上早點休息'
  ];

  final List<String> _permissions = [
    '只看總覽',
    '詳細進度',
    '完全分享'
  ];

  @override
  void dispose() {
    _messageCtrl.dispose();
    _goalCtrl.dispose();
    _goalMsgCtrl.dispose();
    super.dispose();
  }

  void _sendCard(AppState appState) async {
    final msg = _messageCtrl.text.trim();
    await appState.sendParentEncouragementCard(_cardTitle, msg);
    _messageCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功送出鼓勵卡「$_cardTitle」！'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _sendGoal(AppState appState) async {
    final goal = _goalCtrl.text.trim();
    final msg = _goalMsgCtrl.text.trim();
    if (goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請填寫共同自律目標'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await appState.sendParentSharedGoal(goal, _permission, msg);
    _goalCtrl.clear();
    _goalMsgCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('共同目標與陪伴邀請已成功送出！'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    // Mock Child Progress (using current user's data to simulate the child's synced progress)
    final childFocusMinutes = appState.focusMinutes;
    final childTasksCompleted = appState.todayActionableTaskCompleted;
    final childTasksTotal = appState.todayActionableTaskTotal;
    final invite = appState.guardianInvite;
    final status = invite?['status'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('家長陪伴端（管理模式）'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          // Hero banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppUI.heroGradient(accentColor),
            child: const Row(
              children: [
                Icon(
                  Icons.family_restroom_outlined,
                  color: Colors.white,
                  size: 36,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '家長陪伴主控台',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '在此您可以發佈陪伴邀請，送出鼓勵卡與設定共同目標。',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),

          // ─── Child Progress Summary ───────────────────────────────────
          Text(
            '孩子目前自律進度',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$childFocusMinutes',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '專注分鐘',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Theme.of(context).dividerColor,
                      ),
                      Column(
                        children: [
                          Text(
                            '$childTasksCompleted / $childTasksTotal',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '任務完成',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (status == 'linked') ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '共同自律目標',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: secondaryText,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppUI.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '已連結',
                            style: TextStyle(
                              color: AppUI.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        invite?['goal'] ?? '未設定目標',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Divider(height: 24),
                    Text(
                      status == 'pending_child_approval' ? '⏳ 等待孩子同意連結中' : '⚠️ 尚未與孩子建立陪伴連結',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppUI.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),

          // ─── Send Encouragement Card ──────────────────────────────────
          Text(
            '發送鼓勵卡',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '選擇卡片主題',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cardTemplates.map((template) {
                      final selected = _cardTitle == template;
                      return ChoiceChip(
                        label: Text(template),
                        selected: selected,
                        selectedColor: accentColor.withValues(alpha: 0.2),
                        checkmarkColor: accentColor,
                        onSelected: (val) {
                          if (val) {
                            setState(() => _cardTitle = template);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageCtrl,
                    decoration: const InputDecoration(
                      labelText: '鼓勵悄悄話 (選填)',
                      hintText: '例如：看到你今天專注了這麼久，很為你驕傲喔！',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _sendCard(appState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.favorite_rounded),
                    label: const Text('即時發送鼓勵卡'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),

          // ─── Propose Shared Goal ─────────────────────────────────────
          Text(
            '設定共同目標與邀請',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _goalCtrl,
                    decoration: const InputDecoration(
                      labelText: '共同自律目標',
                      hintText: '例如：每週規律讀書 15 小時',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '請求分享數據權限',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _permissions.map((perm) {
                      final selected = _permission == perm;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Center(child: Text(perm)),
                            selected: selected,
                            selectedColor: accentColor.withValues(alpha: 0.2),
                            checkmarkColor: accentColor,
                            onSelected: (val) {
                              if (val) {
                                setState(() => _permission = perm);
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _goalMsgCtrl,
                    decoration: const InputDecoration(
                      labelText: '邀請留言',
                      hintText: '例如：我們一起加油，達成目標週末去吃大餐！',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _sendGoal(appState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.share_arrival_time_outlined),
                    label: const Text('發送共同目標邀請'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
