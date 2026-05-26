import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_ui.dart';

class ReminderCenterPage extends StatelessWidget {
  const ReminderCenterPage({super.key});

  static const List<String> _timeOptions = [
    '07:30',
    '09:00',
    '12:30',
    '18:30',
    '19:30',
    '20:30',
    '22:30',
    '23:00',
  ];

  IconData _iconForChannel(String key) {
    switch (key) {
      case 'sleep':
        return Icons.nights_stay_outlined;
      case 'rooms':
        return Icons.groups_2_outlined;
      case 'deadline':
        return Icons.flag_outlined;
      case 'tasks':
      default:
        return Icons.checklist_rtl_outlined;
    }
  }

  Color _colorForChannel(String key) {
    switch (key) {
      case 'sleep':
        return AppUI.purple;
      case 'rooms':
        return AppUI.green;
      case 'deadline':
        return AppUI.orange;
      case 'tasks':
      default:
        return AppUI.blue;
    }
  }

  Widget _buildReminderChannel(
    BuildContext context,
    ReminderChannelSetting setting,
  ) {
    final appState = context.read<AppState>();
    final color = _colorForChannel(setting.key);
    final textPrimary = AppUI.textPrimaryOf(context);
    final textSecondary = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: AppUI.softCardOf(context, color),
              child: Icon(_iconForChannel(setting.key), color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          setting.title,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Switch(
                        value: setting.enabled,
                        activeThumbColor: color,
                        onChanged: (value) =>
                            appState.setReminderEnabled(setting.key, value),
                      ),
                    ],
                  ),
                  Text(
                    setting.description,
                    style: TextStyle(
                      color: textSecondary,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: AppUI.isDark(context) ? 0.18 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(AppUI.radiusPill),
                        ),
                        child: Text(
                          setting.enabled ? '已開啟' : '已關閉',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        initialValue: setting.timeLabel,
                        onSelected: (time) =>
                            appState.setReminderTime(setting.key, time),
                        itemBuilder: (_) {
                          return _timeOptions
                              .map(
                                (time) => PopupMenuItem(
                                  value: time,
                                  child: Text(time),
                                ),
                              )
                              .toList();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppUI.radiusPill,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule, size: 18, color: color),
                              const SizedBox(width: 6),
                              Text(
                                setting.timeLabel,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.expand_more_rounded,
                                size: 18,
                                color: textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enableSystemNotifications(BuildContext context) async {
    final granted = await context
        .read<AppState>()
        .requestNotificationPermissionAndSchedule();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(granted ? '已啟用系統提醒並完成排程' : '尚未取得系統通知權限')),
    );
  }

  Widget _buildPreviewCard(BuildContext context, ReminderPreview preview) {
    final color = _colorForChannel(preview.channelKey);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: AppUI.softCardOf(context, color),
            child: Icon(_iconForChannel(preview.channelKey), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preview.title, style: AppUI.cardTitleOf(context)),
                const SizedBox(height: 4),
                Text(preview.subtitle, style: AppUI.bodyOf(context)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            preview.timeLabel,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
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
    final previews = appState.upcomingReminders;

    return Scaffold(
      appBar: AppBar(title: const Text('提醒中心')),
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
                    Icons.notifications_active_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '自律提醒排程',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '已開啟 ${appState.enabledReminderCount} 種提醒',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '任務、睡眠、自律房與截止日會依設定時間排序。',
                        style: TextStyle(color: Colors.white70, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _enableSystemNotifications(context),
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('啟用系統提醒'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          Text('即將提醒', style: AppUI.sectionTitleOf(context)),
          const SizedBox(height: 12),
          if (previews.isEmpty)
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Text(
                  '目前沒有即將提醒。你可以開啟任務、睡眠、自律房或截止日提醒。',
                  style: AppUI.bodyOf(context),
                ),
              ),
            )
          else
            ...previews.map(
              (preview) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildPreviewCard(context, preview),
              ),
            ),
          const SizedBox(height: AppUI.sectionGap),
          Text('提醒種類', style: AppUI.sectionTitleOf(context)),
          const SizedBox(height: 12),
          ...appState.reminderSettings.map(
            (setting) => Padding(
              padding: const EdgeInsets.only(bottom: AppUI.cardGap),
              child: _buildReminderChannel(context, setting),
            ),
          ),
        ],
      ),
    );
  }
}
