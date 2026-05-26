import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_icon_preview.dart';
import 'avatar_icon_picker_page.dart';

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
                InkWell(
                  borderRadius: BorderRadius.circular(AppUI.radiusPill),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AvatarIconPickerPage(),
                      ),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarIconPreview(
                        index: appState.avatarProfile.avatarIconIndex,
                        size: 92,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            color: accentColor,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  DropdownButtonFormField<String>(
                    initialValue: selectedTitleKey,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '選擇稱號',
                      prefixIcon: Icon(Icons.emoji_events_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('不使用稱號')),
                      ...unlockedBadges.map(
                        (badge) => DropdownMenuItem(
                          value: badge.badgeKey,
                          child: Text(
                            badge.badgeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTitleBadgeKey = value ?? '';
                      });
                    },
                  ),
                  if (unlockedBadges.isEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: AppUI.softCardOf(context, accentColor),
                      child: Text(
                        '目前還沒有可使用的成就稱號，解鎖成就後就能放到名片上。',
                        style: TextStyle(
                          color: secondaryText,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
}
