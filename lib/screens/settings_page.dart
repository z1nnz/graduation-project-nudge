import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import 'about_page.dart';
import 'account_page.dart';
import 'onboarding_page.dart';
import 'privacy_data_page.dart';
import 'reminder_center_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppUI.sectionTitleOf(context)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _themeModeOption({
    required BuildContext context,
    required String label,
    required String value,
    required String currentValue,
    required Color accentColor,
  }) {
    final isSelected = currentValue == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<AppState>().setThemeModeSetting(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? accentColor : Theme.of(context).dividerColor,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppUI.textPrimaryOf(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconColorOption({
    required BuildContext context,
    required String value,
    required Color color,
    required String currentValue,
  }) {
    final isSelected = currentValue == value;

    return GestureDetector(
      onTap: () => context.read<AppState>().setIconColorSetting(value),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? (AppUI.isDark(context) ? Colors.white : Colors.black87)
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _backgroundThemeOption({
    required BuildContext context,
    required String themeKey,
    required String currentValue,
    required bool unlocked,
  }) {
    final isSelected = currentValue == themeKey;
    final colors = AppUI.backgroundThemeColors(themeKey, AppUI.isDark(context));
    final accent = colors.length > 1 ? colors[1] : AppUI.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: unlocked
          ? () => context.read<AppState>().setBackgroundThemeSetting(themeKey)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 146,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.32),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      unlocked ? Icons.auto_awesome_outlined : Icons.lock,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppUI.backgroundThemeLabel(themeKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppUI.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unlocked ? (isSelected ? '使用中' : '已解鎖') : '商城解鎖',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: unlocked ? accent : AppUI.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          _sectionCard(
            context: context,
            title: '帳號與同步',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.account_circle_outlined, color: accentColor),
              title: Text(appState.isSignedIn ? '已登入帳號' : '登入與個人 ID'),
              subtitle: Text(
                appState.isSignedIn
                    ? '${appState.accountProviderLabel}・${appState.myNudgeId}'
                    : 'Email / Google / Apple、Nudge ID、名片同步',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountPage()),
                );
              },
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _sectionCard(
            context: context,
            title: '提醒與通知',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.notifications_active_outlined,
                color: accentColor,
              ),
              title: const Text('提醒中心'),
              subtitle: Text(
                '已開啟 ${appState.enabledReminderCount} 種提醒：任務、睡眠、自律房、截止日',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReminderCenterPage()),
                );
              },
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _sectionCard(
            context: context,
            title: '初始偏好',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.flag_circle_outlined, color: accentColor),
              title: const Text('重新查看新手引導'),
              subtitle: const Text('調整目標類型、起步任務、角色、提醒與隱私確認'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OnboardingPage()),
                );
              },
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _sectionCard(
            context: context,
            title: '外觀模式',
            child: Row(
              children: [
                _themeModeOption(
                  context: context,
                  label: '跟隨系統',
                  value: 'system',
                  currentValue: appState.themeModeSetting,
                  accentColor: accentColor,
                ),
                const SizedBox(width: 10),
                _themeModeOption(
                  context: context,
                  label: '淺色',
                  value: 'light',
                  currentValue: appState.themeModeSetting,
                  accentColor: accentColor,
                ),
                const SizedBox(width: 10),
                _themeModeOption(
                  context: context,
                  label: '深色',
                  value: 'dark',
                  currentValue: appState.themeModeSetting,
                  accentColor: accentColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _sectionCard(
            context: context,
            title: 'icon 顏色',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _iconColorOption(
                  context: context,
                  value: 'purple',
                  color: const Color(0xFF7C6AE6),
                  currentValue: appState.iconColorSetting,
                ),
                _iconColorOption(
                  context: context,
                  value: 'blue',
                  color: const Color(0xFF4F8CFF),
                  currentValue: appState.iconColorSetting,
                ),
                _iconColorOption(
                  context: context,
                  value: 'teal',
                  color: const Color(0xFF14B8A6),
                  currentValue: appState.iconColorSetting,
                ),
                _iconColorOption(
                  context: context,
                  value: 'green',
                  color: const Color(0xFF10B981),
                  currentValue: appState.iconColorSetting,
                ),
                _iconColorOption(
                  context: context,
                  value: 'orange',
                  color: const Color(0xFFF59E0B),
                  currentValue: appState.iconColorSetting,
                ),
                _iconColorOption(
                  context: context,
                  value: 'pink',
                  color: const Color(0xFFEC4899),
                  currentValue: appState.iconColorSetting,
                ),
                _iconColorOption(
                  context: context,
                  value: 'red',
                  color: const Color(0xFFEF4444),
                  currentValue: appState.iconColorSetting,
                ),
                _iconColorOption(
                  context: context,
                  value: 'indigo',
                  color: const Color(0xFF6366F1),
                  currentValue: appState.iconColorSetting,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _sectionCard(
            context: context,
            title: '背景主題',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppUI.backgroundThemeKeys.map((themeKey) {
                final index = AppUI.backgroundThemeKeys.indexOf(themeKey);
                return _backgroundThemeOption(
                  context: context,
                  themeKey: themeKey,
                  currentValue: appState.backgroundThemeSetting,
                  unlocked: appState.isAvatarItemUnlocked(
                    'appBackground',
                    index,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _sectionCard(
            context: context,
            title: '資料管理',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.verified_user_outlined,
                    color: accentColor,
                  ),
                  title: const Text('隱私與資料'),
                  subtitle: const Text('健康權限、資料刪除與跨裝置同步規劃'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyDataPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.refresh_outlined, color: accentColor),
                  title: const Text('產生測試資料'),
                  subtitle: const Text('快速建立 7 天示範紀錄'),
                  onTap: () async {
                    await context.read<AppState>().generateMockDailySummaries();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已產生 7 天測試資料')),
                      );
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: accentColor),
                  title: const Text('清除測試資料'),
                  subtitle: const Text('清除歷史資料並重建今日摘要'),
                  onTap: () async {
                    await context.read<AppState>().clearDailySummaries();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已清除歷史資料並重建今日摘要')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _sectionCard(
            context: context,
            title: '更多資訊',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline, color: accentColor),
                  title: const Text('關於我們'),
                  subtitle: const Text('查看 App 理念與功能介紹'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
