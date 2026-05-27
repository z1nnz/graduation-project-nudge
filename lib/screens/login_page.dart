import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '請輸入電子郵件與密碼';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final appState = context.read<AppState>();
      await appState.signInWithEmailAndPassword(email, password);
      // Success will automatically update authState listener and route to home
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = '找不到該帳號，請先註冊。';
        } else if (e.code == 'wrong-password') {
          _errorMessage = '密碼輸入錯誤，請重試。';
        } else if (e.code == 'invalid-email') {
          _errorMessage = '電子郵件格式不正確。';
        } else {
          _errorMessage = e.message ?? '登入失敗，請重試。';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = '發生未知錯誤，請確認網路連線。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final accentColor = AppUI.primary;

    return Scaffold(
      backgroundColor: AppUI.scaffoldBackgroundOf(context),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // App Logo Placeholder / Icon
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: accentColor.withValues(alpha: 0.12),
                    child: Icon(Icons.auto_awesome_rounded, size: 40, color: accentColor),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '歡迎回到 Nudge',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '登入以同步你的自律數據與好友互動',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 36),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Email Field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '電子郵件',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                    decoration: const InputDecoration(
                      labelText: '密碼',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Submit Button
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '登入',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: secondaryText.withValues(alpha: 0.2))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '或第三方快速登入',
                          style: TextStyle(color: secondaryText, fontSize: 12),
                        ),
                      ),
                      Expanded(child: Divider(color: secondaryText.withValues(alpha: 0.2))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google Button
                      _SocialIconButton(
                        icon: Icons.g_mobiledata_rounded,
                        color: Colors.redAccent,
                        onTap: () async {
                          setState(() {
                            _loading = true;
                            _errorMessage = null;
                          });
                          try {
                            await context.read<AppState>().signInWithGoogle();
                          } catch (e) {
                            setState(() {
                              _errorMessage = 'Google 登入失敗：$e';
                            });
                          } finally {
                            if (mounted) {
                              setState(() {
                                _loading = false;
                              });
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      // Apple Button
                      _SocialIconButton(
                        icon: Icons.apple_rounded,
                        color: Colors.white,
                        onTap: () => _showPresentationDialog(
                          context,
                          'Apple 登入',
                          '需要配備 Apple 付費開發者帳號（年費 \$99 美元）與配置相關 App ID 與憑證金鑰。',
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Facebook Button (Real Integration)
                      _SocialIconButton(
                        icon: Icons.facebook_rounded,
                        color: Colors.blueAccent,
                        onTap: () async {
                          setState(() { _loading = true; _errorMessage = null; });
                          try {
                            await context.read<AppState>().signInWithFacebook();
                          } catch (e) {
                            setState(() { _errorMessage = 'Facebook 登入失敗：$e'; });
                          } finally {
                            if (mounted) setState(() { _loading = false; });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Switch to register / offline mode
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '還沒有帳號？',
                        style: TextStyle(color: secondaryText, fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterPage()),
                          );
                        },
                        child: Text(
                          '立即註冊',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      context.read<AppState>().skipSignIn();
                    },
                    child: Text(
                      '暫時跳過（離線模式）',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPresentationDialog(BuildContext context, String provider, String details) {
    showDialog(
      context: context,
      builder: (context) {
        final primaryText = AppUI.textPrimaryOf(context);
        final secondaryText = AppUI.textSecondaryOf(context);
        return AlertDialog(
          backgroundColor: AppUI.scaffoldBackgroundOf(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppUI.primary),
              const SizedBox(width: 10),
              Text(
                '展示環境提示',
                style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本平台在當前 Demo 展示環境中未配置 $provider 的開發者憑證。',
                style: TextStyle(color: primaryText, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                '原因：$details',
                style: TextStyle(color: secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                '此按鈕僅供 UI 介面展示，請使用「電子郵件」或「Google 帳號」進行登入！',
                style: TextStyle(color: AppUI.primary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('我知道了', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 28, color: color),
      ),
    );
  }
}
