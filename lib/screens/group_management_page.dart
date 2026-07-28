import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import 'study_room_list_page.dart';
import 'group_manager_page.dart';

class GroupManagementPage extends StatelessWidget {
  const GroupManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final capabilities = appState.experienceCapabilities;
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    final challenge = appState.groupChallenge;
    final schedules = appState.studySchedules;
    final templates = appState.groupTemplates;

    return Scaffold(
      appBar: AppBar(title: Text(capabilities.groupSurfaceTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                const Icon(
                  Icons.business_center_outlined,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capabilities.groupSurfaceTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        capabilities.groupSurfaceDescription,
                        style: const TextStyle(
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

          Card(
            shape: AppUI.cardShape(),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: appState.isGroupResultSharingEnabled,
                  title: const Text(
                    '分享我的團體成果摘要',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('只分享分數、任務完成數、專注、步數與睡眠摘要；關閉後會立即退出團體排行。'),
                  secondary: const Icon(Icons.verified_user_outlined),
                  onChanged: (enabled) async {
                    try {
                      await appState.setGroupResultSharing(enabled);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(enabled ? '已開啟團體成果分享' : '已撤回團體成果分享'),
                        ),
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  },
                ),
                if (appState.isGroupResultSharingEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '目前摘要：${appState.todayWeightedDisciplineScore} 分・'
                            '${appState.focusMinutes} 分鐘專注・${appState.steps} 步',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await appState.refreshGroupResultSummary();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('團體成果摘要已更新')),
                            );
                          },
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('立即更新'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),

          // ─── 房主控制台入口（僅房主可見）───────────────────────────────
          if (capabilities.canManageGroup) ...[
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GroupManagerPage()),
              ),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.25),
                      accentColor.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: accentColor,
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '管理者控制台',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '發布挑戰、讀書時段與考試模板',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryText.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: accentColor.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppUI.sectionGap),
          ],

          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: AppUI.orange),
              const SizedBox(width: 8),
              Text(
                '團體自律挑戰',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUI.cardGap),

          if (challenge == null)
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Text(
                  '目前尚未被指派團體挑戰。請在 Web 平台「挑戰建立器」中派發。',
                  style: TextStyle(fontSize: 13, color: secondaryText),
                ),
              ),
            )
          else
            _buildChallengeCard(context, challenge, accentColor),

          const SizedBox(height: AppUI.sectionGap),

          // ─── 補習班/團體讀書時段 ──────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppUI.blue),
              const SizedBox(width: 8),
              Text(
                '團體共讀/讀書時段',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppUI.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${schedules.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppUI.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUI.cardGap),

          if (schedules.isEmpty)
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Text(
                  '目前沒有共同自律時段。團體管理者可發布建議時間；成員仍自行開始與完成。',
                  style: TextStyle(fontSize: 13, color: secondaryText),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final schedule = schedules[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppUI.cardGap),
                  child: _buildStudyScheduleCard(
                    context,
                    schedule,
                    accentColor,
                  ),
                );
              },
            ),

          const SizedBox(height: AppUI.sectionGap),

          // ─── 考試/自律任務模板 ────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.assignment_outlined, color: AppUI.green),
              const SizedBox(width: 8),
              Text(
                '學業大考任務模板',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUI.cardGap),

          if (templates.isEmpty)
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Text(
                  '目前尚未發佈考試模板。請在 Web 平台「大考任務模板」中建立。',
                  style: TextStyle(fontSize: 13, color: secondaryText),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppUI.cardGap),
                  child: _buildTemplateCard(
                    context,
                    templates[index],
                    appState,
                    accentColor,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(
    BuildContext context,
    Map<String, dynamic> challenge,
    Color accentColor,
  ) {
    final group = challenge['groupName'] ?? '自律團體';
    final type = challenge['type'] ?? '專注挑戰';
    final days = (challenge['days'] as num?)?.toInt() ?? 7;
    final reward = challenge['reward'] ?? '徽章';
    final appState = context.read<AppState>();
    final challengeId = challenge['challengeId']?.toString();
    final participants = challengeId == null
        ? const <Map<String, dynamic>>[]
        : appState.groupChallengeParticipations
              .where((item) => item['challengeId'] == challengeId)
              .toList(growable: false);
    final participation = appState.currentGroupChallengeParticipation;
    final completedCount = participants
        .where((item) => item['status'] == 'completed')
        .length;
    final isLegacyChallenge =
        challenge['schemaVersion'] != 2 || challengeId == null;

    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  group,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppUI.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '進行中',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppUI.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$days 日$type',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '挑戰規則：每日任務由成員自行完成，App 與 Web 共用參與狀態。\n'
              '團體進度不另發個人 XP／自律幣；目標獎勵待團體結算：$reward。'
              '${participants.length} 人參加，$completedCount 人完成。',
              style: TextStyle(
                fontSize: 12,
                color: secondaryText,
                height: 1.45,
              ),
            ),
            const Divider(height: 24),
            if (participation != null) ...[
              LinearProgressIndicator(
                value:
                    ((participation['completedDays'] as num?)?.toDouble() ??
                        0) /
                    math.max(1, days),
              ),
              const SizedBox(height: 8),
              Text(
                participation['status'] == 'completed'
                    ? '你已完成這次挑戰'
                    : '你的進度 ${(participation['completedDays'] as num?)?.toInt() ?? 0} / $days 天；每日任務完成後會自動同步。',
                style: TextStyle(fontSize: 12, color: secondaryText),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: participation != null || isLegacyChallenge
                        ? null
                        : () async {
                            try {
                              await appState.joinGroupChallengeAsTask();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已參與挑戰，$days 天任務會同步到任務清單 🎯'),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isLegacyChallenge
                          ? '請管理者重新發布新版挑戰'
                          : participation == null
                          ? '我要參與並同步任務'
                          : participation['status'] == 'completed'
                          ? '挑戰已完成'
                          : '已參與・由我自行完成',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyScheduleCard(
    BuildContext context,
    Map<String, dynamic> schedule,
    Color accentColor,
  ) {
    final title = schedule['title'] ?? '共讀時段';
    final meta = schedule['meta'] ?? '時間與房間未定';

    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppUI.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book, color: AppUI.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudyRoomListPage(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      '進入自律房',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12, color: accentColor),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    Map<String, dynamic> template,
    AppState appState,
    Color accentColor,
  ) {
    final type = template['type'] ?? '大考';
    final days = int.tryParse(template['days']?.toString() ?? '7') ?? 7;
    final effort = template['effort'] ?? '每日投入中等';
    final strategy = template['strategy'] ?? '策略性規劃';

    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$type大考 $days 日規劃模板',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const Divider(height: 20),
            Text(
              '每日投入強度：',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: secondaryText,
              ),
            ),
            Text(effort, style: TextStyle(fontSize: 14, color: primaryText)),
            const SizedBox(height: 12),
            Text(
              '準備階段策略：',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: secondaryText,
              ),
            ),
            Text(
              strategy,
              style: TextStyle(fontSize: 14, color: primaryText, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      appState.importExamTemplate(type, days, effort, strategy);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('成功匯入 $type 的 $days 日學習任務至任務清單！'),
                          backgroundColor: AppUI.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('匯入為我的自律任務'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
