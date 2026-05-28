import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class GuardianCenterPage extends StatelessWidget {
  const GuardianCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    final invite = appState.guardianInvite;
    final status = invite?['status'];
    final encouragements = appState.guardianEncouragements;

    return Scaffold(
      appBar: AppBar(
        title: const Text('家長陪伴中心'),
      ),
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
                        '家長陪伴模式',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '送鼓勵，不代替完成。透過數據建立家庭信任關係。',
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

          // ─── 邀請或連結狀態 ──────────────────────────────────────────
          if (invite == null || status == 'declined')
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Column(
                  children: [
                    const Icon(
                      Icons.diversity_3_outlined,
                      size: 48,
                      color: AppUI.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '尚未建立家長連結',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '您可以在 Web 端的「家長陪伴中心」送出陪伴邀請，App 即可即時在此接收邀請並同意連結。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (status == 'pending_child_approval')
            _buildPendingInviteCard(context, invite, appState, accentColor)
          else if (status == 'linked')
            _buildActiveLinkCard(context, invite, appState, accentColor),

          const SizedBox(height: AppUI.sectionGap),

          // ─── 鼓勵卡片紀錄 ──────────────────────────────────────────
          Row(
            children: [
              Text(
                '家長鼓勵卡紀錄',
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
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${encouragements.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUI.cardGap),

          if (encouragements.isEmpty)
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Text(
                  '目前尚未收到任何鼓勵卡。家長在 Web 端送出後，App 將會即時同步！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryText,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: encouragements.length,
              itemBuilder: (context, index) {
                final card = encouragements[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppUI.cardGap),
                  child: _buildEncouragementCard(context, card, accentColor),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPendingInviteCard(
    BuildContext context,
    Map<String, dynamic> invite,
    AppState appState,
    Color accentColor,
  ) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      color: accentColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined, color: AppUI.orange),
                const SizedBox(width: 8),
                Text(
                  '收到家長陪伴邀請',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              '設定共同目標：',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              invite['goal'] ?? '未設定目標',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '請求分享權限：',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              invite['permission'] ?? '只看總覽',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 12),
            if (invite['message'] != null && invite['message'].toString().trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Text(
                  '「${invite['message']}」',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: primaryText,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      appState.declineGuardianInvite();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已拒絕陪伴邀請')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    child: const Text('拒絕'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      appState.acceptGuardianInvite();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已成功接受家長陪伴連結！')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('同意連結'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLinkCard(
    BuildContext context,
    Map<String, dynamic> invite,
    AppState appState,
    Color accentColor,
  ) {
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
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppUI.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '已與家長建立陪伴連結',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              '共同自律目標：',
              style: TextStyle(
                fontSize: 12,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              invite['goal'] ?? '一週睡滿 49 小時',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '分享的數據權限：',
              style: TextStyle(
                fontSize: 12,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              invite['permission'] ?? '只看總覽',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('解除連結'),
                      content: const Text('確定要解除與家長的陪伴連結嗎？解除後家長將無法查看您的數據與發送目標。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            appState.removeGuardian();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已解除陪伴連結')),
                            );
                          },
                          child: const Text('確定解除', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.link_off_outlined, size: 18),
                label: const Text('解除陪伴連結'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: secondaryText,
                ),
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
    Color accentColor,
  ) {
    final title = card['title'] ?? '今天也辛苦了';
    final meta = card['meta'] ?? '剛剛';
    final message = card['message'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppUI.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      meta,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppUI.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppUI.textPrimaryOf(context).withValues(alpha: 0.85),
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
