import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_ui.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isBusy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _runAuth(Future<void> Function(AppState appState) action) async {
    final appState = context.read<AppState>();
    setState(() => _isBusy = true);
    try {
      await action(appState);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('帳號狀態已更新')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('帳號與同步')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    appState.isSignedIn
                        ? Icons.verified_user_outlined
                        : Icons.account_circle_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appState.isSignedIn ? '已登入' : '尚未登入',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appState.profileNickname,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appState.isSignedIn
                            ? '${appState.accountProviderLabel} 登入，名片資料會跟帳號綁定。'
                            : '先建立帳號狀態，之後接後端時就能跨裝置同步。',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _InfoCard(
            title: 'Nudge ID',
            subtitle: '用這組 ID 或 QR Code 加好友',
            icon: Icons.badge_outlined,
            accentColor: accentColor,
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    appState.myNudgeId,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: appState.myNudgeId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已複製 ${appState.myNudgeId}')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _InfoCard(
            title: '登入方式',
            subtitle: user == null
                ? '目前是本機資料。正式接後端後，這裡會連到 Firebase / Supabase 驗證。'
                : '目前使用 ${appState.accountProviderLabel}，ID：${user.id}',
            icon: Icons.login_rounded,
            accentColor: accentColor,
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密碼',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isBusy
                        ? null
                        : () => _runAuth(
                            (state) => state.signInWithEmail(
                              email: _emailController.text,
                              password: _passwordController.text,
                            ),
                          ),
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('使用 Email 登入'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBusy
                            ? null
                            : () =>
                                  _runAuth((state) => state.signInWithGoogle()),
                        icon: const Icon(Icons.g_mobiledata_rounded),
                        label: const Text('Google'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBusy
                            ? null
                            : () =>
                                  _runAuth((state) => state.signInWithApple()),
                        icon: const Icon(Icons.apple),
                        label: const Text('Apple'),
                      ),
                    ),
                  ],
                ),
                if (appState.isSignedIn) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _isBusy
                          ? null
                          : () => _runAuth((state) => state.signOut()),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('登出'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _InfoCard(
            title: '同步範圍',
            subtitle: '這些資料已整理成帳號層資料，之後可直接接雲端。',
            icon: Icons.cloud_sync_outlined,
            accentColor: accentColor,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SyncChip(label: '個人名片', color: accentColor),
                _SyncChip(label: '使用者 ID', color: const Color(0xFF14B8A6)),
                _SyncChip(label: '角色穿搭', color: AppUI.purple),
                _SyncChip(label: '好友邀請', color: AppUI.orange),
              ],
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Text(
            '提醒：這一版先建立帳號與同步的 App 內邏輯。Google / Apple 真正登入需要後端專案、OAuth 憑證與平台簽章設定，不能只靠 Flutter 畫面完成。',
            style: TextStyle(color: secondaryText, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
                  decoration: AppUI.softCardOf(context, accentColor),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppUI.textPrimaryOf(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppUI.textSecondaryOf(context),
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
}

class _SyncChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SyncChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: AppUI.softCardOf(context, color),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
