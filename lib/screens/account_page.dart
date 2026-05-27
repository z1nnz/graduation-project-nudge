import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/app_state.dart';
import '../theme/app_ui.dart';

/// The Account tab — shows sign-in / sign-up UI when not logged in,
/// and account management when logged in.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

enum _AuthMode { signIn, signUp }

class _AccountPageState extends State<AccountPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    _confirmCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    if (_mode == mode) return;
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _mode = mode;
        _error = null;
      });
      _fadeCtrl.forward();
    });
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '請輸入電子郵件與密碼');
      return;
    }

    if (_mode == _AuthMode.signUp) {
      final nickname = _nicknameCtrl.text.trim();
      final confirm = _confirmCtrl.text.trim();
      if (nickname.isEmpty) {
        setState(() => _error = '請填寫自律暱稱');
        return;
      }
      if (password != confirm) {
        setState(() => _error = '兩次密碼輸入不一致');
        return;
      }
      if (password.length < 6) {
        setState(() => _error = '密碼長度需至少 6 位');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_mode == _AuthMode.signIn) {
        await appState.signInWithEmailAndPassword(email, password);
      } else {
        await appState.signUpWithEmailAndPassword(
            email, password, _nicknameCtrl.text.trim());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mode == _AuthMode.signIn ? '登入成功 🎉' : '帳號建立成功 🎉'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'user-not-found' => '找不到該帳號，請先註冊。',
          'wrong-password' || 'invalid-credential' =>
            '密碼錯誤，請重試。',
          'invalid-email' => '電子郵件格式不正確。',
          'email-already-in-use' => '此信箱已被使用，請直接登入。',
          'weak-password' => '密碼強度不足，請設定更複雜的密碼。',
          _ => e.message ?? '發生錯誤，請重試。',
        };
      });
    } catch (e) {
      setState(() => _error = '發生未知錯誤，請確認網路連線。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _socialSignIn(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('帳號'),
        centerTitle: false,
      ),
      body: AppBackground(
        child: SafeArea(
          child: appState.isSignedIn
              ? _buildSignedInView(appState)
              : _buildAuthView(appState),
        ),
      ),
    );
  }

  // ─── Signed-in state ──────────────────────────────────────────────────────
  Widget _buildSignedInView(AppState appState) {
    final accent = appState.currentIconColor;
    final user = appState.currentUser;

    return ListView(
      padding: const EdgeInsets.all(AppUI.pagePadding),
      children: [
        // Hero card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: AppUI.heroGradient(accent),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('已登入',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(appState.profileNickname,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(appState.accountProviderLabel,
                        style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppUI.cardGap),

        // Nudge ID card
        _InfoCard(
          title: 'Nudge ID',
          subtitle: '用這組 ID 讓好友搜尋並加你',
          icon: Icons.badge_outlined,
          accentColor: accent,
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  appState.myNudgeId,
                  style: TextStyle(
                    color: AppUI.textPrimaryOf(context),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
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

        // Account info
        _InfoCard(
          title: '帳號資訊',
          subtitle: user?.email ?? '—',
          icon: Icons.account_circle_outlined,
          accentColor: accent,
          child: Column(
            children: [
              _InfoRow(label: '登入方式', value: appState.accountProviderLabel),
              const SizedBox(height: 6),
              _InfoRow(label: 'UID', value: user?.id ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: AppUI.cardGap),

        // Sync scope
        _InfoCard(
          title: '雲端同步範圍',
          subtitle: '以下資料已和帳號綁定，換設備也不會遺失。',
          icon: Icons.cloud_sync_outlined,
          accentColor: accent,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SyncChip(label: '個人名片', color: accent),
              _SyncChip(label: '自律房', color: const Color(0xFF14B8A6)),
              _SyncChip(label: '角色穿搭', color: AppUI.purple),
              _SyncChip(label: '好友邀請', color: AppUI.orange),
              _SyncChip(label: '每日紀錄', color: const Color(0xFFF59E0B)),
            ],
          ),
        ),
        const SizedBox(height: AppUI.cardGap),

        // Sign out
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await appState.signOut();
                    if (mounted) setState(() => _busy = false);
                  },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('登出'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Auth form ─────────────────────────────────────────────────────────────
  Widget _buildAuthView(AppState appState) {
    final accent = AppUI.primary;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo / icon
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    size: 38, color: accent),
              ),

              // Title
              Text(
                _mode == _AuthMode.signIn ? '歡迎回到 Nudge' : '建立你的自律身分',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: primaryText,
                    fontSize: 26,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == _AuthMode.signIn
                    ? '登入以同步自律資料並與好友互動'
                    : '同步你的進度，與全球好友一同專注',
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryText, fontSize: 14),
              ),
              const SizedBox(height: 28),

              // Error banner
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.28)),
                  ),
                  child: Text(_error!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center),
                ),
              ],

              // Mode tab toggle
              Container(
                decoration: BoxDecoration(
                  color: AppUI.isDark(context)
                      ? const Color(0xFF1E2229)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _ModeTab(
                      label: '登入',
                      selected: _mode == _AuthMode.signIn,
                      accentColor: accent,
                      onTap: () => _switchMode(_AuthMode.signIn),
                    ),
                    _ModeTab(
                      label: '註冊',
                      selected: _mode == _AuthMode.signUp,
                      accentColor: accent,
                      onTap: () => _switchMode(_AuthMode.signUp),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Nickname (sign up only)
              if (_mode == _AuthMode.signUp) ...[
                _Field(
                  controller: _nicknameCtrl,
                  label: '自律暱稱',
                  icon: Icons.person_outline_rounded,
                  action: TextInputAction.next,
                ),
                const SizedBox(height: 14),
              ],

              // Email
              _Field(
                controller: _emailCtrl,
                label: '電子郵件',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                action: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              // Password
              _PasswordField(
                controller: _passwordCtrl,
                label: '密碼',
                obscure: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                action: _mode == _AuthMode.signIn
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmit: _mode == _AuthMode.signIn ? (_) => _submit() : null,
              ),

              // Confirm password (sign up only)
              if (_mode == _AuthMode.signUp) ...[
                const SizedBox(height: 14),
                _PasswordField(
                  controller: _confirmCtrl,
                  label: '確認密碼',
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  action: TextInputAction.done,
                  onSubmit: (_) => _submit(),
                ),
              ],
              const SizedBox(height: 24),

              // Submit button
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white)))
                    : Text(
                        _mode == _AuthMode.signIn ? '登入' : '建立帳號並登入',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 20),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('或使用第三方登入',
                        style: TextStyle(
                            color: secondaryText, fontSize: 12)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              // Social sign-in buttons
              Row(
                children: [
                  Expanded(
                    child: _SocialButton(
                      id: 'google_signin_btn',
                      label: 'Google',
                      icon: Icons.g_mobiledata_rounded,
                      onPressed: _busy
                          ? null
                          : () => _socialSignIn(
                              context.read<AppState>().signInWithGoogle),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SocialButton(
                      id: 'apple_signin_btn',
                      label: 'Apple',
                      icon: Icons.apple_rounded,
                      onPressed: _busy
                          ? null
                          : () => _socialSignIn(
                              context.read<AppState>().signInWithApple),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Skip / guest mode hint
              Center(
                child: TextButton(
                  onPressed: () {
                    // Simply dismiss — user stays in app (isGuestMode already true
                    // since we no longer gate the main shell on auth)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('你可以先體驗功能，稍後再登入以同步資料。'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Text(
                    '稍後再說，先體驗功能',
                    style: TextStyle(
                        color: secondaryText,
                        fontSize: 13,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable small widgets ────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? (AppUI.isDark(context)
                    ? const Color(0xFF2A2F3A)
                    : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? accentColor
                  : AppUI.textSecondaryOf(context),
              fontWeight:
                  selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final TextInputAction action;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.action = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: action,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final TextInputAction action;
  final void Function(String)? onSubmit;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.action,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: action,
      onSubmitted: onSubmit,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(
              obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SocialButton({
    required this.id,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: ValueKey(id),
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      Text(title,
                          style: TextStyle(
                              color: AppUI.textPrimaryOf(context),
                              fontSize: 17,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: AppUI.textSecondaryOf(context),
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600)),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AppUI.textSecondaryOf(context),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppUI.textPrimaryOf(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ],
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
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}
