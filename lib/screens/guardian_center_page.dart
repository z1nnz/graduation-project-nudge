import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/family_link_contract.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/relationship_context_switcher.dart';
import '../models/relationship_membership.dart';

class GuardianCenterPage extends StatelessWidget {
  const GuardianCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isChild = appState.isCurrentFamilyChild;
    final link = appState.familyLink;
    final activeGoal = appState.activeFamilyGoal;
    final encouragements = appState.guardianEncouragements;

    return Scaffold(
      appBar: AppBar(title: const Text('家庭連結與隱私')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppUI.heroGradient(accentColor),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.white, size: 36),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '你的資料，由你決定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '家長可以陪伴與提議，但不能替你接受目標或開啟資料權限。',
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
          const RelationshipContextSwitcher(scope: RelationshipScope.family),
          if (appState.familyLinks.isNotEmpty)
            const SizedBox(height: AppUI.sectionGap),
          if (link != null)
            _buildActiveLinkCard(context, appState, isChild, accentColor)
          else
            _buildEmptyLinkCard(context),
          if (link != null) ...[
            const SizedBox(height: AppUI.sectionGap),
            _buildFamilyTreeCard(context, appState, accentColor),
          ],
          if (activeGoal != null && isChild) ...[
            const SizedBox(height: AppUI.sectionGap),
            Text(
              '共同目標',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: AppUI.cardGap),
            _buildGoalCard(context, activeGoal, appState, accentColor),
          ],
          const SizedBox(height: AppUI.sectionGap),
          Row(
            children: [
              Text(
                '家庭鼓勵卡',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(width: 8),
              Chip(label: Text('${encouragements.length}')),
            ],
          ),
          const SizedBox(height: AppUI.cardGap),
          if (encouragements.isEmpty)
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Text(
                  '目前沒有鼓勵卡。建立家庭連結後，家長傳送的內容會同步到這裡。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryText, height: 1.4),
                ),
              ),
            )
          else
            ...encouragements.map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: AppUI.cardGap),
                child: _buildEncouragementCard(
                  context,
                  card,
                  appState,
                  accentColor,
                  isChild,
                ),
              ),
            ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildEmptyLinkCard(BuildContext context) {
    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          children: [
            const Icon(
              Icons.diversity_3_outlined,
              size: 46,
              color: AppUI.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '尚未建立家庭連結',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppUI.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '在帳號設定選擇「孩子」身分，再以 Nudge ID 與家長帳號完成雙向確認。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppUI.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLinkCard(
    BuildContext context,
    AppState appState,
    bool isChild,
    Color accentColor,
  ) {
    final consent = appState.familyLink?.consent ?? const FamilyConsentScopes();
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: AppUI.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isChild ? '孩子介面 · 已連結家長帳號' : '家長介面 · 已連結孩子帳號',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    context,
                    '目前身份',
                    isChild ? '孩子' : '家長',
                    accentColor,
                  ),
                ),
                Expanded(
                  child: _metric(
                    context,
                    '連結狀態',
                    appState.isGuardianLinked ? '有效' : '已結束',
                    accentColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              '資料分享同意',
              style: TextStyle(
                color: AppUI.textPrimaryOf(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isChild ? '你可以隨時調整；關閉後家長端會立即反映。' : '只有此連結的孩子能調整分享範圍。',
              style: TextStyle(color: secondaryText, fontSize: 12),
            ),
            _consentSwitch(
              title: '今日總覽',
              subtitle: '僅顯示整體完成率與專注摘要',
              value: consent.summary,
              onChanged: isChild
                  ? (value) => appState.updateFamilyConsent(
                      consent.copyWith(summary: value),
                    )
                  : null,
            ),
            _consentSwitch(
              title: '每週回顧',
              subtitle: '分享一週趨勢，不含逐筆紀錄',
              value: consent.weeklyReport,
              onChanged: isChild
                  ? (value) => appState.updateFamilyConsent(
                      consent.copyWith(weeklyReport: value),
                    )
                  : null,
            ),
            _consentSwitch(
              title: '任務類別',
              subtitle: '分享讀書、運動等分類彙整',
              value: consent.taskCategories,
              onChanged: isChild
                  ? (value) => appState.updateFamilyConsent(
                      consent.copyWith(taskCategories: value),
                    )
                  : null,
            ),
            _consentSwitch(
              title: '健康趨勢',
              subtitle: '分享步數與睡眠的趨勢摘要',
              value: consent.healthTrends,
              onChanged: isChild
                  ? (value) => appState.updateFamilyConsent(
                      consent.copyWith(healthTrends: value),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmRemove(context, appState),
                icon: const Icon(Icons.link_off_outlined, size: 18),
                label: const Text('解除家庭連結'),
                style: OutlinedButton.styleFrom(foregroundColor: secondaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyTreeCard(
    BuildContext context,
    AppState appState,
    Color accentColor,
  ) {
    final outcome = appState.familyRelationshipOutcome;
    final memories = appState.familyRelationshipMemories;
    final secondaryText = AppUI.textSecondaryOf(context);
    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.park_rounded, color: accentColor, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outcome?.characterTitle ?? '家庭樹尚未生成',
                        style: TextStyle(
                          color: AppUI.textPrimaryOf(context),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        outcome?.characterDescription ??
                            '由完成共同目標與雙向回應的正式紀錄生成，不使用個人 XP。',
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '重新計算家庭成果',
                  onPressed: appState.isRefreshingFamilyRelationshipOutcome
                      ? null
                      : () => _refreshFamilyTree(context, appState),
                  icon: appState.isRefreshingFamilyRelationshipOutcome
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (outcome != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: outcome.levelProgress,
                color: accentColor,
                backgroundColor: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 8),
              Text(
                outcome.nextLevelXp == null
                    ? '家庭樹 Lv.${outcome.growthLevel} · ${outcome.growthXp} 關係 XP · 已達目前最高階段'
                    : '家庭樹 Lv.${outcome.growthLevel} · ${outcome.growthXp}/${outcome.nextLevelXp} 關係 XP',
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      context,
                      '共同目標',
                      '${outcome.metric('completedGoals')}',
                      accentColor,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      context,
                      '雙向回應',
                      '${outcome.metric('acknowledgements')}',
                      accentColor,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      context,
                      '共同回憶',
                      '${outcome.metric('memoryCount')}',
                      accentColor,
                    ),
                  ),
                ],
              ),
            ],
            if (appState.familyRelationshipOutcomeError != null) ...[
              const SizedBox(height: 10),
              Text(
                appState.familyRelationshipOutcomeError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const Divider(height: 28),
            Text(
              '共同回憶',
              style: TextStyle(
                color: AppUI.textPrimaryOf(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (memories.isEmpty)
              Text(
                '完成共同目標或回應家庭鼓勵卡後，經 Cloud 驗證的事件會出現在這裡。',
                style: TextStyle(color: secondaryText, fontSize: 12),
              )
            else
              ...memories
                  .take(5)
                  .map(
                    (memory) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        memory.memoryType == 'goal_completed'
                            ? Icons.flag_circle_outlined
                            : Icons.favorite_outline_rounded,
                        color: accentColor,
                      ),
                      title: Text(memory.title),
                      subtitle: Text('+${memory.points} 關係 XP'),
                    ),
                  ),
            const SizedBox(height: 8),
            Text(
              '家庭樹與陪伴角色屬於這段關係，不會變成任一方的個人獎勵。',
              style: TextStyle(color: secondaryText, fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshFamilyTree(
    BuildContext context,
    AppState appState,
  ) async {
    try {
      await appState.refreshFamilyRelationshipOutcome();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('家庭樹與共同回憶已更新')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appState.familyRelationshipOutcomeError ?? '更新失敗'),
        ),
      );
    }
  }

  Widget _consentSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    Map<String, dynamic> goal,
    AppState appState,
    Color accentColor,
  ) {
    final status = goal['status']?.toString() ?? 'proposed';
    final goalId = goal['id']?.toString();
    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              goal['title']?.toString() ?? '未命名目標',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppUI.textPrimaryOf(context),
              ),
            ),
            if ((goal['message']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                goal['message'].toString(),
                style: TextStyle(color: AppUI.textSecondaryOf(context)),
              ),
            ],
            const SizedBox(height: 14),
            if (status == 'proposed')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: goalId == null
                          ? null
                          : () => appState.declineFamilyGoal(goalId),
                      child: const Text('婉拒'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: appState.acceptParentGoalAsTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('接受並匯入任務'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: goalId == null
                      ? null
                      : () => appState.completeFamilyGoal(goalId),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('我們完成了（+10 羈絆 XP）'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEncouragementCard(
    BuildContext context,
    Map<String, dynamic> card,
    AppState appState,
    Color accentColor,
    bool isChild,
  ) {
    final acknowledged = card['status'] == 'acknowledged';
    final id = card['id']?.toString();
    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.favorite_rounded, color: accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card['title']?.toString() ?? '今天也辛苦了',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if ((card['message']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(card['message'].toString()),
                  ],
                  const SizedBox(height: 10),
                  if (acknowledged)
                    const Text(
                      '已回應，家庭羈絆 +3 XP',
                      style: TextStyle(color: AppUI.green, fontSize: 12),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: !isChild || id == null
                          ? null
                          : () => appState.acknowledgeFamilyEncouragement(id),
                      icon: const Icon(Icons.waving_hand_outlined, size: 18),
                      label: const Text('收到，謝謝（+3 XP）'),
                    ),
                ],
              ),
            ),
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
        Text(
          label,
          style: TextStyle(color: AppUI.textSecondaryOf(context), fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _confirmRemove(BuildContext context, AppState appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('解除家庭連結'),
        content: const Text('解除後雙方不能再傳送家庭內容；既有互動紀錄會保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '確定解除',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await appState.removeGuardian();
  }
}
