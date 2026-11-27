import '../widgets/game_pixel_switch.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character_catalog.dart';
import '../widgets/living_world/living_scene_banner.dart';
import '../models/user_notification.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../theme/game_ui.dart';
import '../widgets/cabin_mail_art.dart';

enum _PostOfficeObject { mailbox, alarms }

class ReminderCenterPage extends StatefulWidget {
  const ReminderCenterPage({super.key});

  @override
  State<ReminderCenterPage> createState() => _ReminderCenterPageState();
}

class _ReminderCenterPageState extends State<ReminderCenterPage> {
  _PostOfficeObject? _open;

  void _show(_PostOfficeObject destination) {
    setState(() => _open = destination);
  }

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
              child: Icon(Icons.alarm_outlined, color: color),
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
                      GamePixelSwitch(
                        value: setting.enabled,
                        activeThumbColor: color,
                        onChanged: appState.isSyncingNotificationPreferences
                            ? null
                            : (value) async {
                                try {
                                  await appState.setReminderEnabled(
                                    setting.key,
                                    value,
                                  );
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('通知設定同步失敗：$error')),
                                  );
                                }
                              },
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
                        enabled: !appState.isSyncingNotificationPreferences,
                        onSelected: (time) async {
                          try {
                            await appState.setReminderTime(setting.key, time);
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('通知設定同步失敗：$error')),
                            );
                          }
                        },
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
    final appState = context.read<AppState>();
    final granted = await appState.requestNotificationPermissionAndSchedule();
    if (!context.mounted) return;

    final message = !granted
        ? '尚未取得系統通知權限'
        : appState.isSignedIn &&
              appState.isDevicePushSupported &&
              !appState.isCurrentDevicePushConfigured
        ? '本機提醒已啟用；遠端推播尚未取得裝置 token，請稍後再試'
        : appState.isCurrentDevicePushConfigured
        ? '已啟用本機排程與帳號遠端推播'
        : '已啟用此裝置的本機提醒排程';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  String _formatNotificationTime(DateTime? value) {
    if (value == null) return '時間未提供';
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  Widget _buildUserNotificationCard(
    BuildContext context,
    UserNotification notification,
  ) {
    final appState = context.read<AppState>();
    final unread = notification.isUnread;
    final kind = notification.kind;
    final seal = kind.startsWith('family')
        ? GamePalette.red
        : kind.startsWith('group')
        ? GamePalette.violet
        : GamePalette.goldDeep;
    return GamePanel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(duration: Duration(milliseconds: 250)),
        key: PageStorageKey(notification.id),
        leading: ExcludeSemantics(
          child: CustomPaint(
            size: const Size.square(40),
            painter: kind == 'friend_cabin_letter'
                ? const CabinMailPainter()
                : CabinMailPainter(parcel: false, seal: seal),
          ),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontFamily: 'Cubic11', fontSize: 16),
        ),
        subtitle: Text(
          _formatNotificationTime(notification.createdAt),
          style: const TextStyle(fontSize: 14),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        children: [
          Text(notification.body, style: const TextStyle(fontSize: 14)),
          if (unread)
            Align(
              alignment: Alignment.centerRight,
              child: GameButton(
                label: '標示已讀',
                icon: Icons.done_all_rounded,
                onPressed: () async {
                  try {
                    await appState.markUserNotificationRead(notification.id);
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('更新站內通知失敗：$error')));
                  }
                },
              ),
            )
          else
            Text(
              notification.isResolved ? '邀請已處理' : '已讀',
              style: const TextStyle(fontSize: 14),
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
          LivingSceneBanner(
            art: 'assets/scenes/post_office/post_office.webp',
            aspect: 1.5,
            tallArt: 'assets/scenes/post_office/post_office_tall.webp',
            tallAspect: 2 / 3,
            tallNpcAt: const Offset(0.8, 0.8),
            tallHome: const Offset(0.45, 0.8),
            title: '提醒郵局',
            npc: GameCharacters.letty,
            npcAt: const Offset(0.5, 0.92),
            npcLine: '來信請打開信箱，要設定提醒就看看鬧鐘架。',
            spots: [
              LivingSpot(
                id: 'mailbox',
                label: '信箱',
                rect: const Rect.fromLTWH(0.1, 0.18, 0.25, 0.3),
                tallRect: const Rect.fromLTWH(0.06, 0.1, 0.34, 0.28),
                revealsBelow: true,
                change: LivingChange.open,
                onArrive: () => _show(_PostOfficeObject.mailbox),
              ),
              LivingSpot(
                id: 'alarms',
                label: '鬧鐘牆',
                rect: const Rect.fromLTWH(0.79, 0.28, 0.16, 0.36),
                tallRect: const Rect.fromLTWH(0.66, 0.24, 0.2, 0.12),
                revealsBelow: true,
                change: LivingChange.shake,
                onArrive: () => _show(_PostOfficeObject.alarms),
              ),
            ],
            objects: [
              Semantics(
                label: '打開郵局裡的信箱',
                selected: _open == _PostOfficeObject.mailbox,
                child: GameButton(
                  label: '打開信箱',
                  icon: Icons.mail_outline,
                  onPressed: () => _show(_PostOfficeObject.mailbox),
                ),
              ),
              Semantics(
                label: '查看郵局裡的鬧鐘架',
                selected: _open == _PostOfficeObject.alarms,
                child: GameButton(
                  label: '查看鬧鐘架',
                  icon: Icons.alarm_outlined,
                  onPressed: () => _show(_PostOfficeObject.alarms),
                ),
              ),
            ],
          ),
          if (_open != null) ...[
            const SizedBox(height: AppUI.cardGap),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _open = null),
                child: const Text('收起'),
              ),
            ),
          ],
          if (_open == _PostOfficeObject.alarms) ...[
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _statusChip(
                              context,
                              appState.isNotificationPreferenceCloudVerified
                                  ? 'App／Web 已同步'
                                  : appState.isSignedIn
                                  ? '等待 Cloud 同步'
                                  : '訪客：僅此裝置',
                              appState.isNotificationPreferenceCloudVerified
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_sync_outlined,
                            ),
                            _statusChip(
                              context,
                              appState.isCurrentDevicePushConfigured
                                  ? '此裝置推播已設定'
                                  : appState.isPushNotificationConfigured
                                  ? '帳號其他裝置已設定推播'
                                  : '目前為本機排程／站內通知',
                              appState.isPushNotificationConfigured
                                  ? Icons.mobile_friendly_outlined
                                  : Icons.phonelink_erase_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _enableSystemNotifications(context),
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('啟用系統提醒'),
                        ),
                        if (appState.isSignedIn &&
                            appState.isDevicePushSupported &&
                            appState.isCurrentDevicePushConfigured) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await appState.disablePushNotifications();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('已關閉此裝置的遠端推播；本機提醒排程不受影響'),
                                  ),
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('無法關閉遠端推播：$error')),
                                );
                              }
                            },
                            icon: const Icon(Icons.notifications_off_outlined),
                            label: const Text('關閉此裝置遠端推播'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_open == _PostOfficeObject.mailbox) ...[
            const SizedBox(height: AppUI.sectionGap),
            Row(
              children: [
                Expanded(
                  child: Text('站內通知', style: AppUI.sectionTitleOf(context)),
                ),
                Text(
                  '${appState.unreadUserNotificationCount} 則未讀',
                  style: TextStyle(
                    color: AppUI.textSecondaryOf(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!appState.isSignedIn)
              Card(
                shape: AppUI.cardShape(),
                child: Padding(
                  padding: const EdgeInsets.all(AppUI.innerPadding),
                  child: Text(
                    '登入後可接收家庭與團體邀請的 Cloud 站內通知。',
                    style: AppUI.bodyOf(context),
                  ),
                ),
              )
            else if (appState.userNotifications.isEmpty)
              Card(
                shape: AppUI.cardShape(),
                child: Padding(
                  padding: const EdgeInsets.all(AppUI.innerPadding),
                  child: Text(
                    '目前沒有站內通知。新的家庭／團體邀請與處理結果會由 Cloud 顯示在這裡。',
                    style: AppUI.bodyOf(context),
                  ),
                ),
              )
            else ...[
              ...appState.userNotifications
                  .where((letter) => letter.isUnread)
                  .take(20)
                  .map(
                    (letter) => Padding(
                      padding: const EdgeInsets.only(bottom: AppUI.cardGap),
                      child: _buildUserNotificationCard(context, letter),
                    ),
                  ),
              GamePanel(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  expansionAnimationStyle:
                      MediaQuery.disableAnimationsOf(context)
                      ? AnimationStyle.noAnimation
                      : const AnimationStyle(
                          duration: Duration(milliseconds: 250),
                        ),
                  title: const Text(
                    '已讀信件抽屜',
                    style: TextStyle(fontFamily: 'Cubic11', fontSize: 16),
                  ),
                  leading: const Icon(Icons.inventory_2_outlined),
                  children: appState.userNotifications
                      .where((letter) => !letter.isUnread)
                      .take(20)
                      .map(
                        (letter) => _buildUserNotificationCard(context, letter),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
          if (_open == _PostOfficeObject.alarms) ...[
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
            Text('鬧鐘架', style: AppUI.sectionTitleOf(context)),
            const SizedBox(height: 12),
            ...appState.reminderSettings.map(
              (setting) => Padding(
                padding: const EdgeInsets.only(bottom: AppUI.cardGap),
                child: _buildReminderChannel(context, setting),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
