import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../screens/statistics_page.dart';
import '../screens/today_advice_page.dart';
import '../screens/daily_records_page.dart';
import '../screens/weekly_report_page.dart';
import '../screens/badges_page.dart';
import '../screens/settings_page.dart';
import '../screens/about_page.dart';
import '../screens/account_page.dart';
import '../screens/avatar_shop_page.dart';
import '../screens/calendar_page.dart';
import '../screens/character_page.dart';
import '../screens/coin_wallet_page.dart';
import '../screens/my_profile_page.dart';
import '../screens/reminder_center_page.dart';
import '../widgets/avatar_icon_preview.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback? onOpenTasks;

  const AppDrawer({super.key, this.onOpenTasks});

  String _statusText(int score) {
    if (score >= 90) return '今天表現很穩定';
    if (score >= 70) return '穩定成長中';
    if (score >= 50) return '持續累積中';
    return '剛開始養成中';
  }

  String _titleText(int score) {
    if (score >= 90) return '自律達人';
    if (score >= 70) return '穩定執行者';
    if (score >= 50) return '節奏建立中';
    return '自律新手';
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _drawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    final primaryText = AppUI.textPrimaryOf(context);
    final isDark = AppUI.isDark(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark
                      ? accentColor.withValues(alpha: 0.16)
                      : accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Text(
        label,
        style: TextStyle(
          color: AppUI.textSecondaryOf(context),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _drawerSectionDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Divider(
        color: AppUI.textSecondaryOf(context).withValues(alpha: 0.18),
        height: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final totalScore = appState.todayWeightedDisciplineScore;
    final profileTitle = appState.profileTitle.isEmpty
        ? _titleText(totalScore)
        : appState.profileTitle;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppUI.radiusCard),
                onTap: () => _openPage(context, const MyProfilePage()),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: AppUI.heroGradient(accentColor),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AvatarIconPreview(
                        index: appState.avatarProfile.avatarIconIndex,
                        size: 74,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.profileNickname,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profileTitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _statusText(totalScore),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(
                                      AppUI.radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    '目前分數：$totalScore',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _drawerSectionLabel(context, '今天行動'),
                  _drawerItem(
                    context: context,
                    icon: Icons.tips_and_updates_outlined,
                    title: '今日建議',
                    onTap: () => _openPage(
                      context,
                      TodayAdvicePage(onOpenTasks: onOpenTasks),
                    ),
                    accentColor: accentColor,
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.notifications_active_outlined,
                    title: '提醒中心',
                    onTap: () => _openPage(context, const ReminderCenterPage()),
                    accentColor: accentColor,
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.calendar_today_outlined,
                    title: '每日紀錄',
                    onTap: () => _openPage(context, const DailyRecordsPage()),
                    accentColor: accentColor,
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.calendar_month_outlined,
                    title: '行事曆',
                    onTap: () => _openPage(context, const CalendarPage()),
                    accentColor: accentColor,
                  ),
                  _drawerSectionDivider(context),
                  _drawerSectionLabel(context, '回顧分析'),
                  _drawerItem(
                    context: context,
                    icon: Icons.bar_chart_rounded,
                    title: '統計分析',
                    onTap: () => _openPage(context, const StatisticsPage()),
                    accentColor: accentColor,
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.assessment_outlined,
                    title: '每週報告',
                    onTap: () => _openPage(context, const WeeklyReportPage()),
                    accentColor: accentColor,
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.emoji_events_outlined,
                    title: '成就徽章',
                    onTap: () => _openPage(context, const BadgesPage()),
                    accentColor: accentColor,
                  ),
                  _drawerSectionDivider(context),
                  _drawerSectionLabel(context, '角色與獎勵'),
                  _drawerItem(
                    context: context,
                    icon: Icons.auto_awesome_outlined,
                    title: '角色中心',
                    onTap: () => _openPage(context, const CharacterPage()),
                    accentColor: accentColor,
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.storefront_outlined,
                    title: '造型商城',
                    onTap: () => _openPage(context, const AvatarShopPage()),
                    accentColor: accentColor,
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.account_balance_wallet_outlined,
                    title: '自律幣錢包',
                    onTap: () => _openPage(
                      context,
                      CoinWalletPage(onOpenTasks: onOpenTasks ?? () {}),
                    ),
                    accentColor: accentColor,
                  ),
                  _drawerSectionDivider(context),
                  _drawerSectionLabel(context, '帳號設定'),
                  _drawerItem(
                    context: context,
                    icon: Icons.account_circle_outlined,
                    title: '帳號與同步',
                    onTap: () => _openPage(context, const AccountPage()),
                    accentColor: accentColor,
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.settings_outlined,
                    title: '設定',
                    onTap: () => _openPage(context, const SettingsPage()),
                    accentColor: accentColor,
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.info_outline,
                    title: '關於我們',
                    onTap: () => _openPage(context, const AboutPage()),
                    accentColor: accentColor,
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
