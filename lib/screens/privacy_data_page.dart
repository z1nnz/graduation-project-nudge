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
                    '同意後，Android Health Connect／Apple Health 的每日彙整證據會送往 Cloud Activity Ledger；Nudge 不會取得其他未列出的健康類型。',
                  ),
                  _bullet(
                    context,
                    '撤回 Nudge 同意會停止後續 Cloud ingestion 並清除 App 快取；若要撤銷作業系統授權，仍需到手機健康權限設定關閉。',
                  ),
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
                        label: 'Cloud 同意',
                        value: appState.isPrivacyConsentCloudVerified
                            ? '已稽核'
                            : '未驗證',
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
                  _bullet(
                    context,
                    '個人活動、健康彙整、家庭分享與團體分享分開授權；Firestore Rules 與 Cloud callable 共同限制讀寫。',
                  ),
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
                    subtitle: const Text(
                      '清除本機睡眠、步數與運動分鐘；不等於刪除既有 Cloud Ledger 紀錄',
                    ),
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
                    subtitle: const Text(
                      '只清除此裝置快取；不會刪除帳號、Cloud Ledger 或正式關係資料',
                    ),
                    onTap: () async {
                      final confirmed = await _confirm(
                        context: context,
                        title: '刪除所有本機資料？',
                        message:
                            '這個動作只會清除此裝置的 Nudge 快取與離線資料；登入帳號、Cloud Activity Ledger、家庭／團體 Membership 與雲端商城資料不會被刪除。',
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
              title: 'Cloud 與跨裝置資料範圍',
              icon: Icons.cloud_sync_outlined,
              iconColor: AppUI.blue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '目前狀態：帳號資料、Activity Ledger、家庭／團體關係與成果已使用 Cloud；裝置仍保留離線快取。',
                    style: TextStyle(
                      color: AppUI.textPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '下列畫面數量混合 Cloud 狀態與此裝置快取；換機驗收必須以登入後重新同步的結果為準。',
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
              title: '正式資料邊界',
              icon: Icons.schema_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(
                    context,
                    '健康 Cloud ingestion 必須同時具備登入、App Check 與目前版本的正式同意。',
                  ),
                  _bullet(
                    context,
                    '公開名片與私人 Activity Ledger 分離；好友、家庭與團體只能讀取各自明確允許的投影。',
                  ),
                  _bullet(
                    context,
                    '每次健康同意或撤回都由 Cloud 寫入目前狀態與不可由客戶端偽造的 audit event。',
                  ),
                  _bullet(
                    context,
                    '撤回會停止未來 ingestion；既有 Cloud Ledger 的匯出與刪除須走正式資料權利流程，不能用「清本機」冒充。',
                  ),
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
                  ? '同意時間：${widget.acceptedAtText}。登入狀態下，這筆同意會由 Cloud 記錄版本與 audit event；你仍可隨時撤回。'
                  : '連接健康資料前，需要確認 Nudge 會把睡眠、步數與運動分鐘的每日彙整證據送往 Cloud Activity Ledger，用於自動追蹤與你加入的自律房。',
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
                          try {
                            await context
                                .read<AppState>()
                                .acceptPrivacyPolicy();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已記錄目前版本的健康資料同意')),
                            );
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('同意未完成：$error')),
                            );
                          } finally {
                            if (mounted) setState(() => isSaving = false);
                          }
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
                        try {
                          await context
                              .read<AppState>()
                              .revokePrivacyPolicyConsent();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已撤回同意、停止後續 ingestion 並清除本機健康快取'),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('本機已停止健康同步，但 Cloud 撤回尚未完成：$error'),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => isSaving = false);
                        }
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
