import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class GroupManagerPage extends StatefulWidget {
  const GroupManagerPage({super.key});

  @override
  State<GroupManagerPage> createState() => _GroupManagerPageState();
}

class _GroupManagerPageState extends State<GroupManagerPage> {
  // Challenge builder controllers
  final _groupNameCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();
  String _challengeType = '讀書專注';
  int _challengeDays = 7;

  // Study room scheduler controllers
  final _scheduleTitleCtrl = TextEditingController();
  final _scheduleTimeCtrl = TextEditingController();

  // Exam template controllers
  final _examTypeCtrl = TextEditingController();
  final _effortCtrl = TextEditingController();
  final _strategyCtrl = TextEditingController();
  int _templateDays = 7;

  final List<String> _challengeTypes = ['讀書專注', '規律作息', '運動打卡', '無手機專注'];
  final List<int> _daysOptions = [3, 7, 14, 21, 30];

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _rewardCtrl.dispose();
    _scheduleTitleCtrl.dispose();
    _scheduleTimeCtrl.dispose();
    _examTypeCtrl.dispose();
    _effortCtrl.dispose();
    _strategyCtrl.dispose();
    super.dispose();
  }

  void _publishChallenge(AppState appState) async {
    final group = _groupNameCtrl.text.trim();
    final reward = _rewardCtrl.text.trim();
    if (group.isEmpty || reward.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請填寫團體名稱與通關獎勵'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await appState.publishGroupChallenge(group, _challengeType, _challengeDays, reward);
    _groupNameCtrl.clear();
    _rewardCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('團體挑戰已成功發佈！'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _publishSchedule(AppState appState) async {
    final title = _scheduleTitleCtrl.text.trim();
    final time = _scheduleTimeCtrl.text.trim();
    if (title.isEmpty || time.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請填寫自律房名稱與開放時間說明'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await appState.publishStudySchedule(title, time);
    _scheduleTitleCtrl.clear();
    _scheduleTimeCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('自律房時段已成功發佈！'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _publishTemplate(AppState appState) async {
    final type = _examTypeCtrl.text.trim();
    final effort = _effortCtrl.text.trim();
    final strategy = _strategyCtrl.text.trim();
    if (type.isEmpty || effort.isEmpty || strategy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請完整填寫大考類型、核心任務與準備策略'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await appState.publishExamTemplate(type, _templateDays, effort, strategy);
    _examTypeCtrl.clear();
    _effortCtrl.clear();
    _strategyCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('考試模板已成功發佈！'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('團體與教育管理端'),
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
                  Icons.business_center_outlined,
                  color: Colors.white,
                  size: 36,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '團體管理中心',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '在此您可以為班級、學員或團隊成員建立大考自律計畫、自律房時段及團體挑戰。',
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

          // ─── Create Challenge Builder ─────────────────────────────────
          Text(
            '發佈團體挑戰 (Challenge)',
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
                    controller: _groupNameCtrl,
                    decoration: const InputDecoration(
                      labelText: '團體/班級名稱',
                      hintText: '例如：三年二班、卓越英文補習班',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _challengeType,
                          decoration: const InputDecoration(labelText: '挑戰類型'),
                          items: _challengeTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _challengeType = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _challengeDays,
                          decoration: const InputDecoration(labelText: '挑戰天數'),
                          items: _daysOptions.map((days) {
                            return DropdownMenuItem(
                              value: days,
                              child: Text('$days 天'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _challengeDays = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _rewardCtrl,
                    decoration: const InputDecoration(
                      labelText: '完成通關獎勵',
                      hintText: '例如：自律幣 +50枚、珍奶一杯',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _publishChallenge(appState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.rocket_launch_outlined),
                    label: const Text('發佈團體自律挑戰'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),

          // ─── Schedule Study Rooms ─────────────────────────────────────
          Text(
            '安排自律房讀書時段',
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
                    controller: _scheduleTitleCtrl,
                    decoration: const InputDecoration(
                      labelText: '自律讀書房名稱',
                      hintText: '例如：期末考衝刺自習房 A',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _scheduleTimeCtrl,
                    decoration: const InputDecoration(
                      labelText: '開放時段說明',
                      hintText: '例如：每晚 19:30 - 21:30 (共 2 小時)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _publishSchedule(appState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.meeting_room_outlined),
                    label: const Text('發佈讀書時段自律房'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),

          // ─── Exam Template Editor ─────────────────────────────────────
          Text(
            '編輯並發佈考試範本 (Exam Template)',
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _examTypeCtrl,
                          decoration: const InputDecoration(
                            labelText: '大考/挑戰類型',
                            hintText: '例如：期末大考、多益衝刺',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _templateDays,
                          decoration: const InputDecoration(labelText: '衝刺天數'),
                          items: _daysOptions.map((days) {
                            return DropdownMenuItem(
                              value: days,
                              child: Text('$days 天衝刺'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _templateDays = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _effortCtrl,
                    decoration: const InputDecoration(
                      labelText: '核心任務重點',
                      hintText: '例如：複習 3 本必考單字與模擬試題',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _strategyCtrl,
                    decoration: const InputDecoration(
                      labelText: '衝刺準備策略',
                      hintText: '例如：每日專注 2 小時，交替複習錯題',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _publishTemplate(appState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.note_alt_outlined),
                    label: const Text('發佈自律大考範本'),
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
