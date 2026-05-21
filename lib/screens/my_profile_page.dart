import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/badge_record.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';
import 'avatar_editor_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _signatureController = TextEditingController();
  bool _initialized = false;
  String _selectedTitleBadgeKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final appState = context.read<AppState>();
    _nicknameController.text = appState.profileNickname;
    _signatureController.text = appState.profileSignature;
    _selectedTitleBadgeKey = appState.profileTitleBadgeKey;
    _initialized = true;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(BuildContext context) async {
    await context.read<AppState>().updateProfile(
      nickname: _nicknameController.text,
      signature: _signatureController.text,
      titleBadgeKey: _selectedTitleBadgeKey,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已更新個人名片')));
  }

  String _badgeTitle(AppState appState, String badgeKey) {
    if (badgeKey.isEmpty) return '不使用稱號';
    final matches = appState.badgeRecords.where(
      (badge) => badge.badgeKey == badgeKey,
    );
    return matches.isEmpty ? '不使用稱號' : matches.first.badgeName;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final unlockedBadges =
        appState.badgeRecords.where((badge) => badge.isUnlocked).toList()
          ..sort((a, b) {
            final aTime =
                a.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                b.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

    final canUseSelectedTitle =
        _selectedTitleBadgeKey.isEmpty ||
        unlockedBadges.any((badge) => badge.badgeKey == _selectedTitleBadgeKey);
    final selectedTitleKey = canUseSelectedTitle ? _selectedTitleBadgeKey : '';

    return Scaffold(
      appBar: AppBar(title: const Text('我的名片')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                AvatarPreview(
                  profile: appState.avatarProfile,
                  size: 92,
                  showBackgroundRing: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nicknameController.text.trim().isEmpty
                            ? appState.profileNickname
                            : _nicknameController.text.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppUI.radiusPill),
                        ),
                        child: Text(
                          _badgeTitle(appState, selectedTitleKey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _signatureController.text.trim().isEmpty
                            ? appState.profileSignature
                            : _signatureController.text.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.35,
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

          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '名片資訊',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nicknameController,
                    maxLength: 12,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: '暱稱',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _signatureController,
                    maxLength: 40,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: '個性簽名',
                      prefixIcon: Icon(Icons.edit_note_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AvatarEditorPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text('編輯角色外觀'),
                  ),
                ],
              ),
            ),
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
                    '名片稱號',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '只能使用已解鎖的成就名稱。這個稱號會顯示在側邊欄和自己的名片上。',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TitleOptionTile(
                    title: '不使用稱號',
                    subtitle: '名片只顯示你的暱稱與簽名',
                    selected: selectedTitleKey.isEmpty,
                    accentColor: accentColor,
                    onTap: () {
                      setState(() {
                        _selectedTitleBadgeKey = '';
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (unlockedBadges.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: AppUI.softCardOf(context, accentColor),
                      child: Text(
                        '目前還沒有可使用的成就稱號，解鎖成就後就能放到名片上。',
                        style: TextStyle(
                          color: secondaryText,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    ...unlockedBadges.map(
                      (badge) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TitleOptionTile(
                          title: badge.badgeName,
                          subtitle: _badgeSubtitle(badge),
                          selected: selectedTitleKey == badge.badgeKey,
                          accentColor: accentColor,
                          onTap: () {
                            setState(() {
                              _selectedTitleBadgeKey = badge.badgeKey;
                            });
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppUI.sectionGap),

          ElevatedButton.icon(
            onPressed: () => _saveProfile(context),
            icon: const Icon(Icons.save_outlined),
            label: const Text('儲存名片'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _badgeSubtitle(BadgeRecord badge) {
    final unlockedAt = badge.unlockedAt;
    if (unlockedAt == null) return '已解鎖';
    return '解鎖於 ${unlockedAt.month}/${unlockedAt.day}';
  }
}

class _TitleOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _TitleOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(
                  alpha: AppUI.isDark(context) ? 0.18 : 0.12,
                )
              : (AppUI.isDark(context)
                    ? const Color(0xFF1F2430)
                    : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accentColor
                : secondaryText.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.emoji_events_outlined,
              color: selected ? accentColor : secondaryText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
}
