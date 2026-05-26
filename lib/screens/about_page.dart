import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Widget _aboutCard(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: AppUI.softCardOf(context, color),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryText,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.watch<AppState>().currentIconColor;

    return Scaffold(
      appBar: AppBar(title: const Text('關於我們')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nudge',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '幫助使用者建立自律節奏的生活管理 App',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          _aboutCard(
            context,
            title: 'App 理念',
            content:
                '這款 App 希望把任務管理、專注紀錄、健康同步與自律分數整合在一起，讓使用者能用更直觀的方式觀察自己的日常狀態。',
            icon: Icons.lightbulb_outline,
            color: AppUI.blue,
          ),
          const SizedBox(height: AppUI.cardGap),
          _aboutCard(
            context,
            title: '核心功能',
            content:
                '首頁儀表板、任務管理、專注模式、健康追蹤、統計分析、每日紀錄、每週報告、成就徽章、角色穿搭與社交自律房已整合成同一套自律系統。',
            icon: Icons.dashboard_customize_outlined,
            color: AppUI.blue,
          ),
          const SizedBox(height: AppUI.cardGap),
          _aboutCard(
            context,
            title: '產品重點',
            content: '任務、健康、專注與房間進度會回到分數、徽章、自律幣與角色展示，讓每一次完成都有可見回饋。',
            icon: Icons.rocket_launch_outlined,
            color: AppUI.blue,
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '版本資訊',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppUI.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppUI.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
