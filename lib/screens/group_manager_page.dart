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
    _rewardCtrl.dispose();
    _scheduleTitleCtrl.dispose();
    _scheduleTimeCtrl.dispose();
    _examTypeCtrl.dispose();
    _effortCtrl.dispose();
    _strategyCtrl.dispose();
    super.dispose();
  }

  void _publishChallenge(AppState appState) async {
    final reward = _rewardCtrl.text.trim();
    if (reward.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請填寫通關獎勵'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await appState.publishGroupChallenge(
      _challengeType,
      _challengeDays,
      reward,
    );
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

  Future<void> _removeMember(AppState appState, String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除團體成員'),
        content: Text('確定要移除 $memberId？對方的團體連結與成果摘要會同時撤除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('確認移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await appState.removeGroupMember(memberId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('成員已移除')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _transferOwnership(AppState appState, String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('轉移團體管理權'),
        content: Text('確定將管理權轉移給 $memberId？完成後你會成為一般成員。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('確認轉移'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await appState.transferGroupOwnership(memberId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('管理權已轉移')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final capabilities = appState.experienceCapabilities;
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);

    if (!capabilities.canManageGroup) {
      return Scaffold(
        appBar: AppBar(title: const Text('團體管理中心')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppUI.pagePadding),
            child: Card(
              shape: AppUI.cardShape(),
              child: const Padding(
                padding: EdgeInsets.all(AppUI.innerPadding),
                child: Text(
                  '只有目前團體的管理者可以發布挑戰、共同時段與任務模板。團體成員可以在團體任務頁查看內容，並自行決定活動時間。',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('團體與教育管理端')),
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

          Text(
            '正式成員與分享狀態',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: Column(
              children: appState.canonicalGroup!.memberIds
                  .map((memberId) {
                    final isOwner =
                        memberId == appState.canonicalGroup!.ownerId;
                    final summaries = appState.groupMemberSummaries.where(
                      (summary) => summary.memberId == memberId,
                    );
                    final summary = summaries.isEmpty ? null : summaries.first;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accentColor.withValues(alpha: 0.15),
                        child: Icon(
                          isOwner
                              ? Icons.admin_panel_settings
                              : Icons.person_outline,
                          color: accentColor,
                        ),
                      ),
                      title: Text(
                        summary?.displayName ?? memberId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  subtitle: Text(
                    isOwner
                        ? '團體管理者・${summary == null ? "未分享成果" : "已同意成果摘要・${summary.disciplineScore} 分"}'
                        : '團體成員・${summary == null ? "未分享成果" : "已同意成果摘要・${summary.disciplineScore} 分"}',
                      ),
                      trailing: isOwner
                          ? const Chip(label: Text('管理者'))
                          : PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'transfer') {
                                  _transferOwnership(appState, memberId);
                                } else if (action == 'remove') {
                                  _removeMember(appState, memberId);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'transfer',
                                  child: Text('轉移管理權'),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text('移除成員'),
                                ),
                              ],
                            ),
                    );
                  })
                  .toList(growable: false),
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
                  InputDecorator(
                    decoration: const InputDecoration(labelText: '發布到團體'),
                    child: Text(
                      appState.groupName ?? '尚未連結有效團體',
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.bold,
                      ),
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
