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

  static const _cardTemplates = [
    '今天也辛苦了',
    '休息也是自律的一部分',
    '看見你的努力，加油！',
    '保持這個專注節奏',
    '今天很棒，晚上早點休息',
  ];

  @override
  void dispose() {
    _messageCtrl.dispose();
    _goalCtrl.dispose();
    _goalMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCard(AppState appState) async {
    try {
      await appState.sendParentEncouragementCard(
        _cardTitle,
        _messageCtrl.text.trim(),
      );
      _messageCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已送出鼓勵卡「$_cardTitle」')));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _sendGoal(AppState appState) async {
    final goal = _goalCtrl.text.trim();
    if (goal.isEmpty) {
      _showError('請填寫共同自律目標');
      return;
    }
    try {
      await appState.sendParentSharedGoal(goal, _goalMsgCtrl.text.trim());
      _goalCtrl.clear();
      _goalMsgCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('共同目標已送出，等待孩子決定')));
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error.toString().replaceFirst('Bad state: ', '');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final link = appState.familyLink;
    final canInteract = appState.isCurrentFamilyGuardian;
    final activeGoal = appState.activeFamilyGoal;

    return Scaffold(
      appBar: AppBar(title: const Text('家長陪伴')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
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
                        '陪伴，不代替孩子決定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '提出共同目標、傳達鼓勵；資料分享範圍由孩子掌握。',
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
          _buildRelationshipCard(
            context,
            appState,
            link != null,
            canInteract,
            activeGoal,
            accentColor,
          ),
          const SizedBox(height: AppUI.sectionGap),
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
                    '選擇一句溫和的提醒',
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
                      return ChoiceChip(
                        label: Text(template),
                        selected: _cardTitle == template,
                        selectedColor: accentColor.withValues(alpha: 0.2),
                        checkmarkColor: accentColor,
                        onSelected: (selected) {
                          if (selected) setState(() => _cardTitle = template);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageCtrl,
                    enabled: canInteract,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '鼓勵悄悄話（選填）',
                      hintText: '例如：我有看到你的努力，照自己的節奏就好。',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: canInteract ? () => _sendCard(appState) : null,
                    icon: const Icon(Icons.favorite_rounded),
                    label: const Text('送出鼓勵卡'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          Text(
            '提出共同目標',
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
                    enabled: canInteract,
                    decoration: const InputDecoration(
                      labelText: '共同自律目標',
                      hintText: '例如：這週一起在 23:30 前準備休息',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _goalMsgCtrl,
                    enabled: canInteract,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '為什麼想一起做（選填）'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '孩子可以接受或婉拒；接受後才會匯入孩子的任務。',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: canInteract ? () => _sendGoal(appState) : null,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('送出目標提議'),
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

  Widget _buildRelationshipCard(
    BuildContext context,
    AppState appState,
    bool linked,
    bool canInteract,
    Map<String, dynamic>? activeGoal,
    Color accentColor,
  ) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final consent = appState.familyLink?.consent;
    final familySummary = appState.familySummary;
    final sharedSummary =
        consent?.summary == true && familySummary?['summary'] is Map
        ? familySummary!['summary'] as Map
        : null;
    final healthTrends =
        consent?.healthTrends == true && familySummary?['healthTrends'] is Map
        ? familySummary!['healthTrends'] as Map
        : null;
    final enabledScopes = <String>[
      if (consent?.summary == true) '今日總覽',
      if (consent?.weeklyReport == true) '週報',
      if (consent?.taskCategories == true) '任務類別',
      if (consent?.healthTrends == true) '健康趨勢',
    ];

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  linked ? Icons.link_rounded : Icons.link_off_rounded,
                  color: linked ? AppUI.green : AppUI.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    canInteract
                        ? '家庭連結已啟用'
                        : linked
                        ? '此連結的家長操作需由家長帳號使用'
                        : '尚未建立家庭連結',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!linked)
              Text(
                '請先以一個家長帳號和一個孩子帳號完成雙向綁定，才可傳送資料。',
                style: TextStyle(color: secondaryText, height: 1.4),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      context,
                      '家庭羈絆',
                      'Lv.${appState.familyBondLevel}',
                      accentColor,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      context,
                      '互動 XP',
                      '${appState.familyBondXp}',
                      accentColor,
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              Text(
                '孩子目前同意分享',
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (enabledScopes.isEmpty ? ['尚未開放'] : enabledScopes)
                    .map((label) => Chip(label: Text(label)))
                    .toList(),
              ),
              if (sharedSummary != null || healthTrends != null) ...[
                const Divider(height: 28),
                Text(
                  '孩子同意分享的最新摘要',
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    if (sharedSummary != null)
                      Text(
                        '完成 ${sharedSummary['completedTasks'] ?? 0}/${sharedSummary['totalTasks'] ?? 0}',
                        style: TextStyle(color: primaryText),
                      ),
                    if (sharedSummary != null)
                      Text(
                        '專注 ${sharedSummary['focusMinutes'] ?? 0} 分',
                        style: TextStyle(color: primaryText),
                      ),
                    if (healthTrends != null)
                      Text(
                        '睡眠 ${healthTrends['sleepHours'] ?? 0} 小時',
                        style: TextStyle(color: primaryText),
                      ),
                    if (healthTrends != null)
                      Text(
                        '步數 ${healthTrends['steps'] ?? 0}',
                        style: TextStyle(color: primaryText),
                      ),
                  ],
                ),
              ],
              if (activeGoal != null) ...[
                const Divider(height: 28),
                Text(
                  '目前共同目標',
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  activeGoal['title']?.toString() ?? '未命名目標',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activeGoal['status'] == 'accepted' ? '孩子已接受' : '等待孩子決定',
                  style: TextStyle(color: accentColor, fontSize: 12),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    String value,
    Color accentColor,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: AppUI.textSecondaryOf(context), fontSize: 12),
        ),
      ],
    );
  }
}
