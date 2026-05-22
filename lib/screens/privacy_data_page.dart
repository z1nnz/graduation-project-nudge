import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task_model.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class PrivacyDataPage extends StatelessWidget {
  const PrivacyDataPage({super.key});

  String _formatAcceptedAt(DateTime? value) {
    if (value == null) return '尚未同意';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}/$month/$day $hour:$minute';
  }

  Future<bool> _confirm({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final accentColor = context.read<AppState>().currentIconColor;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: destructive ? Colors.redAccent : accentColor,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Widget _card({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
    Color? iconColor,
  }) {
    final color = iconColor ?? context.watch<AppState>().currentIconColor;
    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: AppUI.softCardOf(context, color),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: AppUI.sectionTitleOf(context)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AppUI.textSecondaryOf(context))),
          Expanded(child: Text(text, style: AppUI.bodyOf(context))),
        ],
      ),
    );
  }

  Widget _metricPill({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    final accentColor = context.watch<AppState>().currentIconColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppUI.softCardOf(context, accentColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppUI.textSecondaryOf(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppUI.textPrimaryOf(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final healthTaskCount = appState.taskModels.where((task) {
      final source = task.sourceType;
      return source == TaskSourceType.sleepHours ||
          source == TaskSourceType.steps ||
          source == TaskSourceType.exerciseMinutes;
    }).length;

    return Scaffold(
      appBar: AppBar(title: const Text('隱私與資料')),
      body: AppBackground(
        themeKey: appState.backgroundThemeSetting,
        child: ListView(
          padding: const EdgeInsets.all(AppUI.pagePadding),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppUI.heroGradient(accentColor),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: Colors.white,
                    size: 36,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '健康、專注、任務與商城資料都會影響自律分數，所以需要清楚告知、可刪除、可同步。',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUI.sectionGap),
            _PrivacyConsentCard(
              accepted: appState.hasAcceptedPrivacyPolicy,
              acceptedAtText: _formatAcceptedAt(appState.privacyAcceptedAt),
              accentColor: accentColor,
            ),
            const SizedBox(height: AppUI.cardGap),
            _card(
              context: context,
              title: '健康資料權限用途',
              icon: Icons.health_and_safety_outlined,
              iconColor: AppUI.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(context, '只讀取睡眠、步數與運動分鐘，用來判定健康自動追蹤任務與自律房健康目標。'),
                  _bullet(
                    context,
                    '資料目前保存在本機，不會上傳到雲端；Android 會透過 Health Connect，iOS 會透過 Apple Health。',
                  ),
                  _bullet(context, '如果要撤銷系統授權，需到手機的健康權限設定中關閉 Nudge 的讀取權限。'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _metricPill(
                        context: context,
                        label: '連接狀態',
                        value: appState.isHealthConnected ? '已同步' : '未同步',
                      ),
                      _metricPill(
                        context: context,
                        label: '影響任務',
                        value: '$healthTaskCount 個',
                      ),
                      _metricPill(
                        context: context,
                        label: '目前步數',
                        value: '${appState.steps} 步',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUI.cardGap),
            _card(
              context: context,
              title: '隱私政策摘要',
              icon: Icons.policy_outlined,
              iconColor: AppUI.purple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(context, 'Nudge 不會販售健康資料、任務紀錄、好友資料或商城資料。'),
                  _bullet(
                    context,
                    '健康資料只用於自動追蹤任務、自律分數、統計分析與自律房進度，不會顯示給好友看原始睡眠或步數。',
                  ),
                  _bullet(context, '好友能看到的是公開名片、角色穿搭、房間狀態與你選擇展示的成就稱號。'),
                  _bullet(context, '接上後端同步後，個人資料與健康資料要分開儲存，並用帳號權限限制讀取範圍。'),
                ],
              ),
            ),
            const SizedBox(height: AppUI.cardGap),
            _card(
              context: context,
              title: '資料刪除機制',
              icon: Icons.delete_sweep_outlined,
              iconColor: Colors.redAccent,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.monitor_heart_outlined,
                      color: Colors.redAccent,
                    ),
                    title: const Text('清除健康同步資料'),
                    subtitle: const Text('清除睡眠、步數、運動分鐘，健康任務會重新判定為未完成'),
                    onTap: () async {
                      final confirmed = await _confirm(
                        context: context,
                        title: '清除健康資料？',
                        message:
                            '這會清除 App 內保存的睡眠、步數與運動資料，但不會刪除 Apple Health 或 Health Connect 原始資料。',
                        confirmLabel: '清除',
                        destructive: true,
                      );
                      if (!confirmed || !context.mounted) return;
                      await context.read<AppState>().clearHealthData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已清除健康同步資料')),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text('刪除所有本機資料'),
                    subtitle: const Text('清除任務、專注、健康、自律房、好友、商城道具與名片設定'),
                    onTap: () async {
                      final confirmed = await _confirm(
                        context: context,
                        title: '刪除所有本機資料？',
                        message:
                            '這個動作會把 Nudge 目前保存在此裝置上的資料清掉，包含任務、歷史紀錄、自律房、好友、商城與角色設定。此動作無法復原。',
                        confirmLabel: '全部刪除',
                        destructive: true,
                      );
                      if (!confirmed || !context.mounted) return;
                      await context.read<AppState>().clearAllLocalData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已刪除本機資料')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUI.cardGap),
            _card(
              context: context,
              title: '跨裝置同步範圍',
              icon: Icons.cloud_sync_outlined,
              iconColor: AppUI.blue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '目前狀態：本機保存，尚未連接雲端後端。',
                    style: TextStyle(
                      color: AppUI.textPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '等後端上線後，下面這些資料要跟帳號綁定同步，換手機才不會消失。',
                    style: AppUI.bodyOf(context),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _metricPill(
                        context: context,
                        label: '任務',
                        value: '${appState.tasks.length} 筆',
                      ),
                      _metricPill(
                        context: context,
                        label: '歷史紀錄',
                        value: '${appState.dailySummaries.length} 天',
                      ),
                      _metricPill(
                        context: context,
                        label: '自律房',
                        value: '${appState.studyRooms.length} 間',
                      ),
                      _metricPill(
                        context: context,
                        label: '商城道具',
                        value: '${appState.unlockedAvatarItemCount} 件',
                      ),
                      _metricPill(
                        context: context,
                        label: '好友',
                        value: '${appState.socialFriends.length} 位',
                      ),
                      _metricPill(
                        context: context,
                        label: '自律幣',
                        value: '${appState.disciplineCoins} 枚',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _bullet(context, '帳號資料：Nudge ID、暱稱、簽名、稱號與角色穿搭。'),
                  _bullet(context, '行為資料：任務、專注秒數、每日分數、自律幣獲取紀錄。'),
                  _bullet(context, '社交資料：好友、自律房、加入申請、鼓勵紀錄與聊天室事件。'),
                  _bullet(context, '商城資料：已購買道具、目前穿搭、背景主題與自律幣餘額。'),
                ],
              ),
            ),
            const SizedBox(height: AppUI.cardGap),
            _card(
              context: context,
              title: '後端實作提醒',
              icon: Icons.schema_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(context, '需要登入系統：Email、Google、Apple 或學校帳號擇一。'),
                  _bullet(
                    context,
                    '資料庫要分 public profile 與 private health data，健康資料不能被好友讀取。',
                  ),
                  _bullet(context, '同步時要記錄 updatedAt，避免多裝置同時修改任務造成覆蓋。'),
                  _bullet(context, '隱私政策要明確寫出讀取哪些健康項目、用途、保存位置、刪除方式。'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyConsentCard extends StatefulWidget {
  final bool accepted;
  final String acceptedAtText;
  final Color accentColor;

  const _PrivacyConsentCard({
    required this.accepted,
    required this.acceptedAtText,
    required this.accentColor,
  });

  @override
  State<_PrivacyConsentCard> createState() => _PrivacyConsentCardState();
}

class _PrivacyConsentCardState extends State<_PrivacyConsentCard> {
  bool isChecked = false;
  bool isSaving = false;

  @override
  Widget build(BuildContext context) {
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
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: AppUI.softCardOf(
                    context,
                    widget.accepted ? AppUI.green : widget.accentColor,
                  ),
                  child: Icon(
                    widget.accepted
                        ? Icons.verified_outlined
                        : Icons.privacy_tip_outlined,
                    color: widget.accepted ? AppUI.green : widget.accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.accepted ? '已同意隱私權政策' : '同意隱私權政策',
                    style: AppUI.sectionTitleOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.accepted
                  ? '同意時間：${widget.acceptedAtText}。你仍然可以撤回同意，撤回後會清除 App 內保存的健康同步資料。'
                  : '連接健康資料前，需要先確認你理解 Nudge 會讀取睡眠、步數與運動分鐘，並用於自動追蹤任務、自律分數與自律房目標判定。',
              style: TextStyle(color: secondaryText, height: 1.5),
            ),
            const SizedBox(height: 14),
            if (!widget.accepted) ...[
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => isChecked = !isChecked),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isChecked,
                      activeColor: widget.accentColor,
                      onChanged: (value) {
                        setState(() => isChecked = value ?? false);
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '我已閱讀並同意 Nudge 使用健康資料作為任務自動判定與統計分析用途。',
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: !isChecked || isSaving
                      ? null
                      : () async {
                          setState(() => isSaving = true);
                          await context.read<AppState>().acceptPrivacyPolicy();
                          if (!context.mounted) return;
                          setState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已同意隱私權政策')),
                          );
                        },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(isSaving ? '儲存中...' : '同意並儲存'),
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        await context
                            .read<AppState>()
                            .revokePrivacyPolicyConsent();
                        if (!context.mounted) return;
                        setState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已撤回同意並清除健康資料')),
                        );
                      },
                icon: const Icon(Icons.block_outlined),
                label: Text(isSaving ? '處理中...' : '撤回同意'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
